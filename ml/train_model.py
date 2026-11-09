#!/usr/bin/env python3
"""
CUTMind - model training pipeline
=================================
Trains a Random Forest on REAL CUT student survey data.

  X (features) : 5 app check-in sliders (stress, anxiety, sleep, motivation, social), each 1-5
  y (label)    : risk class derived from a validated screening questionnaire
                 --instrument phq4  (DEFAULT, 4 items, ~1 min)
                     total 0-2 -> low, 3-5 -> moderate (mild distress), 6-12 -> high
                 --instrument dass21 (21 items, ~5 min)
                     worst subscale band: Normal/Mild -> low, Moderate -> moderate, Severe+ -> high

Usage
-----
  pip install pandas numpy scikit-learn matplotlib joblib
  pip install shap            # optional, for SHAP plots
  python train_model.py --csv responses.csv                       # short form (PHQ-4)
  python train_model.py --csv responses.csv --instrument dass21   # long form

  # If there are too few 'high' cases for a 3-class model:
  python train_model.py --csv responses.csv --binary

Outputs (in ./model_output/)
  cleaned_dataset.csv        cleaned data + DASS scores + labels (for your appendix)
  metrics.json / report.txt  all numbers to quote in your report and video
  confusion_matrix.png, feature_importance.png, label_distribution.png, shap_summary.png
  model.joblib               the trained scikit-learn model
  cutmind_forest.json        the forest exported for the Flutter app
  test_vectors.json          inputs + expected outputs to verify the Dart implementation
"""
import argparse
import json
import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, classification_report,
                             confusion_matrix, f1_score, recall_score)
from sklearn.model_selection import (GridSearchCV, RepeatedStratifiedKFold,
                                     StratifiedKFold, cross_validate,
                                     train_test_split)
from sklearn.inspection import permutation_importance
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

SEED = 42
FEATURES = ["stress", "anxiety", "sleep", "motivation", "social"]
DASS_ITEMS = [f"q{i}" for i in range(1, 22)]
# DASS-21 item numbers (1-based) for each subscale
STRESS_ITEMS = [1, 6, 8, 11, 12, 14, 18]
ANXIETY_ITEMS = [2, 4, 7, 9, 15, 19, 20]
DEPRESSION_ITEMS = [3, 5, 10, 13, 16, 17, 21]

PHQ_ITEMS = ["p1", "p2", "p3", "p4"]   # p1-p2 = GAD-2 (anxiety), p3-p4 = PHQ-2 (depression)
BASE_COLS = ["timestamp", "consent", "over18", "age_group", "faculty", "year"] + FEATURES


def items_for(instrument: str) -> list[str]:
    """Items that must be complete for a response to be usable."""
    return {"phq4": PHQ_ITEMS, "gad2": ["p1", "p2"], "dass21": DASS_ITEMS}[instrument]


def canonical_cols(instrument: str) -> list[str]:
    """Column layout of the Google Forms export (gad2 uses the PHQ-4 form layout)."""
    return BASE_COLS + (DASS_ITEMS if instrument == "dass21" else PHQ_ITEMS)


PHQ_TEXT = {"not at all": 0, "several days": 1,
            "more than half the days": 2, "nearly every day": 3}


def text_to_number(col: pd.Series, mapping: dict) -> pd.Series:
    """Google Forms exports multiple-choice answers as TEXT. Convert known labels to numbers."""
    def f(v):
        if pd.isna(v):
            return np.nan
        t = "".join(ch for ch in str(v).lower() if ch.isalnum() or ch == " ").strip()
        for k, num in mapping.items():
            if t == k or t.startswith(k):
                return num
        return v                       # already a number (or unknown text -> becomes NaN later)
    return col.map(f)

# DASS-21 severity cut-offs (subscale sum x 2). Upper bound of each band:
# Normal, Mild, Moderate, Severe, (Extremely severe = above)
CUTS = {
    "depression": [9, 13, 20, 27],
    "anxiety":    [7, 9, 14, 19],
    "stress":     [14, 18, 25, 33],
}
SEVERITY_NAMES = ["normal", "mild", "moderate", "severe", "extremely_severe"]


# --------------------------------------------------------------------------- #
# 1. Load + clean
# --------------------------------------------------------------------------- #
def load_and_clean(path: str, instrument: str) -> tuple[pd.DataFrame, dict]:
    raw = pd.read_csv(path)
    ITEMS = items_for(instrument)
    CANONICAL_COLS = canonical_cols(instrument)
    log = {"rows_in_csv": int(len(raw))}

    # Google Forms exports long question text as headers -> replace by position.
    if raw.shape[1] == len(CANONICAL_COLS):
        raw.columns = CANONICAL_COLS
    elif raw.shape[1] == len(CANONICAL_COLS) - 1:      # no timestamp column
        raw.columns = CANONICAL_COLS[1:]
    else:
        sys.exit(f"ERROR: expected {len(CANONICAL_COLS)} columns for --instrument {instrument} "
                 f"but found {raw.shape[1]}. Check you used the right --instrument and "
                 "did not add/remove/reorder questions in the form.")
    df = raw.copy()

    # Consent / age filters (people who said 'No' end the form with blank rows)
    df["consent"] = df["consent"].astype(str).str.lower()
    df["over18"] = df["over18"].astype(str).str.lower()
    df = df[df["consent"].str.startswith("yes") & df["over18"].str.startswith("yes")]
    log["after_consent_age_filter"] = int(len(df))

    # Text answers -> numbers (PHQ answers; the social slider if it was exported as labels)
    for c in PHQ_ITEMS:
        df[c] = text_to_number(df[c], PHQ_TEXT)
    soc_text = pd.to_numeric(df["social"], errors="coerce").isna() & df["social"].notna()
    log["social_answers_exported_as_text"] = int(soc_text.sum())
    df["social"] = text_to_number(df["social"], {"very isolated": 1, "very connected": 5})

    # Numeric + range validation
    for c in FEATURES + PHQ_ITEMS:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    if instrument == "dass21":
        for c in DASS_ITEMS:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    df = df.dropna(subset=FEATURES + ITEMS)
    log["after_dropping_missing"] = int(len(df))
    ok = (((df[FEATURES] >= 1) & (df[FEATURES] <= 5)).all(axis=1)
          & ((df[ITEMS] >= 0) & (df[ITEMS] <= 3)).all(axis=1))
    df = df[ok]
    log["after_range_check"] = int(len(df))

    # Exact duplicate submissions (same timestamp-free answers AND same demographics)
    before = len(df)
    df = df.drop_duplicates(subset=["age_group", "faculty", "year"] + FEATURES + ITEMS)
    log["duplicates_removed"] = int(before - len(df))

    # Straight-liners: identical answer to all 21 DASS items AND all 5 sliders
    # (flagged and removed: indicates not reading the questions)
    straight = (df[ITEMS].nunique(axis=1) == 1) & (df[FEATURES].nunique(axis=1) == 1)
    log["straight_liners_removed"] = int(straight.sum())
    df = df[~straight].reset_index(drop=True)
    log["final_n"] = int(len(df))
    return df, log


# --------------------------------------------------------------------------- #
# 2. DASS-21 scoring -> label
# --------------------------------------------------------------------------- #
def band(score: float, cuts: list[int]) -> int:
    for i, c in enumerate(cuts):
        if score <= c:
            return i
    return len(cuts)          # extremely severe


def add_phq4_labels(df: pd.DataFrame, binary: bool) -> pd.DataFrame:
    """PHQ-4 total (0-12). Published bands: 0-2 normal, 3-5 mild, 6-8 moderate, 9-12 severe.
    Mapping used here: 0-2 low | 3-5 moderate | 6-12 high (>=6 = moderate/severe distress)."""
    df = df.copy()
    df["phq_anxiety"] = df[["p1", "p2"]].sum(axis=1)
    df["phq_depression"] = df[["p3", "p4"]].sum(axis=1)
    df["phq4_total"] = df[PHQ_ITEMS].sum(axis=1)
    df["risk"] = pd.cut(df["phq4_total"], bins=[-1, 2, 5, 12],
                        labels=["low", "moderate", "high"]).astype(str)
    if binary:
        df["risk"] = df["risk"].replace({"moderate": "at_risk", "high": "at_risk"})
    return df


def add_gad2_labels(df: pd.DataFrame, binary: bool) -> pd.DataFrame:
    """GAD-2 = PHQ-4 items 1+2 (range 0-6). Published screening cut-off: total >= 3 means a
    positive anxiety screen (Kroenke et al., 2007). Always a 2-class label: low / at_risk."""
    df = df.copy()
    df["gad2_total"] = df[["p1", "p2"]].sum(axis=1)
    df["risk"] = np.where(df["gad2_total"] >= 3, "at_risk", "low")
    return df


def add_dass_labels(df: pd.DataFrame, binary: bool) -> pd.DataFrame:
    df = df.copy()
    df["dass_stress"] = df[[f"q{i}" for i in STRESS_ITEMS]].sum(axis=1) * 2
    df["dass_anxiety"] = df[[f"q{i}" for i in ANXIETY_ITEMS]].sum(axis=1) * 2
    df["dass_depression"] = df[[f"q{i}" for i in DEPRESSION_ITEMS]].sum(axis=1) * 2
    for s in ["stress", "anxiety", "depression"]:
        df[f"band_{s}"] = df[f"dass_{s}"].apply(lambda v: band(v, CUTS[s]))
    worst = df[["band_stress", "band_anxiety", "band_depression"]].max(axis=1)
    df["worst_band"] = worst.map(dict(enumerate(SEVERITY_NAMES)))

    def to_risk(b: int) -> str:
        if b <= 1:
            return "low"           # normal / mild
        if b == 2:
            return "moderate"
        return "high"              # severe / extremely severe

    df["risk"] = worst.apply(to_risk)
    if binary:
        df["risk"] = df["risk"].replace({"moderate": "at_risk", "high": "at_risk"})
    return df


# --------------------------------------------------------------------------- #
# 3. Baseline: the OLD hard-coded formula from the first prototype
# --------------------------------------------------------------------------- #
def old_formula_predict(X: pd.DataFrame, binary: bool) -> np.ndarray:
    w = (X["stress"] * 0.30 + X["anxiety"] * 0.25 + (6 - X["sleep"]) * 0.20
         + (6 - X["motivation"]) * 0.15 + (6 - X["social"]) * 0.10)
    if binary:
        return np.where(w >= 2.2, "at_risk", "low")
    return np.where(w >= 3.5, "high", np.where(w >= 2.2, "moderate", "low"))


# --------------------------------------------------------------------------- #
# 4. Export forest for Flutter
# --------------------------------------------------------------------------- #
def export_forest(rf: RandomForestClassifier, path: Path, meta: dict):
    trees = []
    for est in rf.estimators_:
        t = est.tree_
        val = t.value[:, 0, :]
        val = val / val.sum(axis=1, keepdims=True)       # class probabilities per node
        trees.append({
            "left": t.children_left.tolist(),
            "right": t.children_right.tolist(),
            "feature": t.feature.tolist(),
            "threshold": [round(float(x), 6) for x in t.threshold],
            "value": [[round(float(p), 5) for p in row] for row in val],
        })
    out = {"classes": [str(c) for c in rf.classes_], "features": FEATURES,
           "n_trees": len(trees), "trees": trees, "meta": meta}
    path.write_text(json.dumps(out, separators=(",", ":")))


def forest_predict_proba(forest: dict, x: list[float]) -> list[float]:
    """Pure-python re-implementation of what the Dart code must do."""
    n_cls = len(forest["classes"])
    acc = [0.0] * n_cls
    for t in forest["trees"]:
        node = 0
        while t["left"][node] != -1:
            node = t["left"][node] if x[t["feature"][node]] <= t["threshold"][node] else t["right"][node]
        for k in range(n_cls):
            acc[k] += t["value"][node][k]
    return [a / forest["n_trees"] for a in acc]


# --------------------------------------------------------------------------- #
# 5. Main
# --------------------------------------------------------------------------- #
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="data/responses.csv")
    ap.add_argument("--out", default="model_output")
    ap.add_argument("--deploy", action="store_true",
                    help="after training, copy the model + test vectors into the Flutter project "
                         "(assets/model/ and test/) one folder above this script")
    ap.add_argument("--instrument", choices=["phq4", "gad2", "dass21"], default="phq4")
    ap.add_argument("--binary", action="store_true",
                    help="merge moderate+high into 'at_risk' (use if <10 high cases)")
    ap.add_argument("--allow-small", action="store_true",
                    help="PRELIMINARY mode for n<40: no hold-out set, no tuning, "
                         "results from cross-validated predictions only")
    ap.add_argument("--test-size", type=float, default=0.2)
    args = ap.parse_args()

    here = Path(__file__).resolve().parent          # paths are relative to this script's folder
    if not Path(args.csv).is_absolute():
        args.csv = str(here / args.csv)
    out = Path(args.out) if Path(args.out).is_absolute() else here / args.out
    out.mkdir(exist_ok=True)
    report = []

    def say(s=""):
        print(s)
        report.append(s)

    # ---- data
    df, log = load_and_clean(args.csv, args.instrument)
    labeller = {"phq4": add_phq4_labels, "gad2": add_gad2_labels, "dass21": add_dass_labels}
    if args.instrument == "gad2":
        args.binary = True
    df = labeller[args.instrument](df, args.binary)
    df.to_csv(out / "cleaned_dataset.csv", index=False)

    say("=" * 64)
    say("CUTMind model training report")
    say("=" * 64)
    say("\n[1] DATA CLEANING")
    for k, v in log.items():
        say(f"  {k:28s}: {v}")
    n = len(df)
    counts = df["risk"].value_counts()
    say(f"\n[2] CLASS DISTRIBUTION (label derived from {args.instrument.upper()})")
    for c, v in counts.items():
        say(f"  {c:10s}: {v:4d}  ({v / n:.1%})")
    say("\n  Demographics:")
    for col in ["age_group", "faculty", "year"]:
        say(f"  {col}: " + ", ".join(f"{k}={v}" for k, v in df[col].value_counts().items()))
    if args.instrument == "gad2":
        say(f"\n  Mean GAD-2 total: {df.gad2_total.mean():.2f} / 6")
    elif args.instrument == "phq4":
        say(f"\n  Mean PHQ-4 total: {df.phq4_total.mean():.2f} "
            f"(anxiety {df.phq_anxiety.mean():.2f}/6, depression {df.phq_depression.mean():.2f}/6)")
    else:
        say("\n  Mean DASS scores (x2): "
            f"stress={df.dass_stress.mean():.1f}, anxiety={df.dass_anxiety.mean():.1f}, "
            f"depression={df.dass_depression.mean():.1f}")

    plt.figure(figsize=(5, 3.5))
    counts.reindex(["low", "moderate", "high", "at_risk"]).dropna().plot.bar(color="#2E7D9A")
    plt.title(f"Label distribution (n={n})"); plt.ylabel("students"); plt.tight_layout()
    plt.savefig(out / "label_distribution.png", dpi=150); plt.close()

    small = bool(args.allow_small and n < 40)
    if n < 40 and not args.allow_small:
        sys.exit(f"\nERROR: only {n} usable responses. Collect more data (aim for 100+), "
                 "or add --allow-small for a clearly-labelled PRELIMINARY run.")
    if n < 15:
        sys.exit(f"\nERROR: only {n} usable responses; not enough even for a preliminary run.")
    min_cls = counts.min()
    if min_cls < (3 if small else 5):
        sys.exit(f"\nERROR: class '{counts.idxmin()}' has only {min_cls} cases. "
                 "Re-run with --binary, or collect more data.")
    if n < 100:
        say(f"\n  WARNING: n={n} is small. Treat results as preliminary and say so.")
    if min_cls < 10:
        say(f"  WARNING: smallest class has {min_cls} cases; per-class metrics will be unstable.")

    X, y = df[FEATURES], df["risk"]
    labels = sorted(y.unique(), key=lambda c: ["low", "moderate", "high", "at_risk"].index(c))

    # ---- split
    if small:
        X_tr, y_tr = X, y
        say("\n[3] PRELIMINARY MODE (n<40): NO hold-out test set and NO hyper-parameter tuning.\n"
            "    All reported metrics come from cross-validated predictions on every student.\n"
            "    Treat everything below as a pilot, not as evidence of accuracy.")
    else:
        X_tr, X_te, y_tr, y_te = train_test_split(
            X, y, test_size=args.test_size, stratify=y, random_state=SEED)
        say(f"\n[3] SPLIT: train={len(X_tr)}, test={len(X_te)} (stratified, seed={SEED})")

    n_splits = int(min(5, y_tr.value_counts().min()))
    cv = RepeatedStratifiedKFold(n_splits=max(n_splits, 2), n_repeats=5, random_state=SEED)

    # ---- model comparison (cross-validation on TRAIN set only)
    candidates = {
        "Majority-class baseline": DummyClassifier(strategy="most_frequent"),
        "Logistic Regression": make_pipeline(StandardScaler(),
                                             LogisticRegression(max_iter=1000, class_weight="balanced")),
        "Random Forest (default)": RandomForestClassifier(
            n_estimators=100, class_weight="balanced", random_state=SEED),
    }
    scoring = {"acc": "accuracy", "f1": "f1_macro", "recall": "recall_macro"}
    say(f"\n[4] CROSS-VALIDATION on training set ({cv.get_n_splits()} folds, mean +/- sd)")
    say(f"  {'model':28s} {'accuracy':>14s} {'macro-F1':>14s} {'macro-recall':>14s}")
    cv_results = {}
    for name, mdl in candidates.items():
        r = cross_validate(mdl, X_tr, y_tr, cv=cv, scoring=scoring)
        cv_results[name] = {k: [float(r[f"test_{k}"].mean()), float(r[f"test_{k}"].std())] for k in scoring}
        say(f"  {name:28s} " + " ".join(
            f"{cv_results[name][k][0]:.3f}+/-{cv_results[name][k][1]:.3f}" for k in ["acc", "f1", "recall"]))

    # ---- tune RF
    grid = {"n_estimators": [50, 100],
            "max_depth": [3, 4, 5, 6, None],
            "min_samples_leaf": [1, 2, 4, 8]}
    if small:
        best_params = {"n_estimators": 100, "max_depth": 3, "min_samples_leaf": 2}
        best_score = cv_results["Random Forest (default)"]["f1"][0]
        rf = RandomForestClassifier(**best_params, class_weight="balanced", random_state=SEED)
        say(f"\n[5] RANDOM FOREST (fixed shallow settings, no tuning at this sample size)\n  params: {best_params}")
    else:
        gs = GridSearchCV(RandomForestClassifier(class_weight="balanced", random_state=SEED),
                          grid, scoring="f1_macro",
                          cv=StratifiedKFold(max(n_splits, 2), shuffle=True, random_state=SEED), n_jobs=-1)
        gs.fit(X_tr, y_tr)
        rf = gs.best_estimator_
        best_params, best_score = gs.best_params_, gs.best_score_
        say(f"\n[5] RANDOM FOREST TUNING (grid search, macro-F1)\n  best params: {best_params}"
            f"\n  best CV macro-F1: {best_score:.3f}")

    # ---- final evaluation on untouched test set
    say("\n[6] " + ("CROSS-VALIDATED PREDICTIONS (all students, each predicted by a model that never saw them)"
                   if small else "HELD-OUT TEST SET RESULTS (used once)"))
    rows = {}
    def evaluate(name, pred):
        rows[name] = {
            "accuracy": accuracy_score(y_te, pred),
            "macro_f1": f1_score(y_te, pred, average="macro", zero_division=0),
        }
        if "high" in labels:
            rows[name]["high_recall"] = recall_score(y_te, pred, labels=["high"], average="macro", zero_division=0)
        elif "at_risk" in labels:
            rows[name]["at_risk_recall"] = recall_score(y_te, pred, labels=["at_risk"], average="macro", zero_division=0)
    if small:
        from sklearn.model_selection import cross_val_predict
        skf = StratifiedKFold(max(n_splits, 2), shuffle=True, random_state=SEED)
        X_te, y_te = X, y
        def pred_of(mdl):
            return cross_val_predict(mdl, X, y, cv=skf)
        rf_pred = pred_of(rf)
        rf.fit(X, y)                       # fitted on everything only for importance/SHAP below
    else:
        def pred_of(mdl):
            return mdl.fit(X_tr, y_tr).predict(X_te)
        rf_pred = rf.predict(X_te)
    evaluate("Majority-class baseline", pred_of(candidates["Majority-class baseline"]))
    evaluate("OLD hard-coded formula", old_formula_predict(X_te, args.binary))
    evaluate("Logistic Regression", pred_of(candidates["Logistic Regression"]))
    evaluate("Random Forest" + (" (fixed)" if small else " (tuned)"), rf_pred)
    for name, m in rows.items():
        say(f"  {name:28s} " + "  ".join(f"{k}={v:.3f}" for k, v in m.items()))

    pred = rf_pred
    say("\n  Classification report (Random Forest):")
    say(classification_report(y_te, pred, labels=labels, zero_division=0))
    cm = confusion_matrix(y_te, pred, labels=labels)
    say(f"  Confusion matrix (rows=true, cols=predicted; order={labels}):\n{cm}")
    say(f"\n  NOTE: evaluation uses only {len(X_te)} students, so these numbers are noisy. "
        "Quote the cross-validation figures alongside them." if not small else
        f"\n  NOTE: PRELIMINARY. n={len(X_te)}. Report these as pilot results only.")

    fig, ax = plt.subplots(figsize=(4.5, 4))
    ax.imshow(cm, cmap="Blues")
    ax.set_xticks(range(len(labels))); ax.set_xticklabels(labels)
    ax.set_yticks(range(len(labels))); ax.set_yticklabels(labels)
    ax.set_xlabel("Predicted"); ax.set_ylabel("Actual"); ax.set_title("Confusion matrix (CV predictions)" if small else "Confusion matrix (test set)")
    for i in range(len(labels)):
        for j in range(len(labels)):
            ax.text(j, i, cm[i, j], ha="center", va="center",
                    color="white" if cm[i, j] > cm.max() / 2 else "black")
    fig.tight_layout(); fig.savefig(out / "confusion_matrix.png", dpi=150); plt.close(fig)

    # ---- feature importance
    perm = permutation_importance(rf, X_te, y_te, n_repeats=30, random_state=SEED, scoring="f1_macro")
    imp = pd.DataFrame({"feature": FEATURES, "gini_importance": rf.feature_importances_,
                        "permutation_importance": perm.importances_mean}).sort_values(
                            "permutation_importance", ascending=False)
    say("\n[7] FEATURE IMPORTANCE\n" + imp.to_string(index=False, float_format=lambda v: f"{v:.3f}"))
    imp.set_index("feature")[["gini_importance", "permutation_importance"]].plot.barh(figsize=(6, 3.5))
    plt.title("Feature importance"); plt.tight_layout()
    plt.savefig(out / "feature_importance.png", dpi=150); plt.close()

    # ---- SHAP (optional)
    try:
        import shap
        expl = shap.TreeExplainer(rf)
        sv = expl.shap_values(X_te)
        focus = "high" if "high" in rf.classes_ else "at_risk"
        fi = list(rf.classes_).index(focus)
        if isinstance(sv, list):                      # older SHAP: list of (n, features) per class
            sv = sv[fi]
        elif getattr(sv, "ndim", 2) == 3:             # newer SHAP: (n, features, classes)
            sv = sv[:, :, fi]
        plt.figure()
        shap.summary_plot(sv, X_te, show=False)
        plt.title(f"SHAP: effect of each feature on P({focus})")
        plt.tight_layout(); plt.savefig(out / "shap_summary.png", dpi=150, bbox_inches="tight"); plt.close()
        say("\n[8] SHAP summary saved to shap_summary.png")
    except Exception as e:                                   # noqa: BLE001
        say(f"\n[8] SHAP skipped ({type(e).__name__}); run 'pip install shap' for SHAP plots.")

    # ---- refit on ALL data for deployment, then export
    rf_final = RandomForestClassifier(**{**best_params, "class_weight": "balanced",
                                         "random_state": SEED}).fit(X, y)
    joblib.dump(rf_final, out / "model.joblib")
    meta = {"n_training_samples": int(n), "label_source": {"gad2": "GAD-2", "phq4": "PHQ-4", "dass21": "DASS-21"}[args.instrument],
            "binary": bool(args.binary), "best_params": dict(best_params),
            "cv_macro_f1": float(best_score), "preliminary": small}
    export_forest(rf_final, out / "cutmind_forest.json", meta)

    # test vectors so the Dart port can be checked against sklearn
    forest = json.loads((out / "cutmind_forest.json").read_text())
    rng = np.random.RandomState(SEED)
    vecs = rng.randint(1, 6, size=(15, 5)).tolist()
    tv = []
    for v in vecs:
        p_sk = rf_final.predict_proba(pd.DataFrame([v], columns=FEATURES))[0]
        p_py = forest_predict_proba(forest, [float(a) for a in v])
        assert np.allclose(p_sk, p_py, atol=1e-3), "Export mismatch!"
        tv.append({"input": v, "classes": forest["classes"], "proba": [round(float(p), 4) for p in p_sk],
                   "predicted": str(rf_final.classes_[int(np.argmax(p_sk))])})
    (out / "test_vectors.json").write_text(json.dumps(tv, indent=1))
    size_kb = (out / "cutmind_forest.json").stat().st_size / 1024
    say(f"\n[9] EXPORT: cutmind_forest.json ({size_kb:.0f} KB) verified against scikit-learn on 15 test vectors.")

    metrics = {"n": int(n), "cleaning": log, "class_counts": {k: int(v) for k, v in counts.items()},
               "cv": cv_results, "test": rows, "best_params": best_params,
               "feature_importance": imp.to_dict(orient="records")}
    (out / "metrics.json").write_text(json.dumps(metrics, indent=1, default=float))
    (out / "report.txt").write_text("\n".join(report))
    if args.deploy:
        import shutil
        app = here.parent
        if not (app / "pubspec.yaml").exists():
            print(f"\n--deploy: no pubspec.yaml found in {app}; copy the files manually.")
        else:
            (app / "assets" / "model").mkdir(parents=True, exist_ok=True)
            (app / "test").mkdir(exist_ok=True)
            shutil.copy(out / "cutmind_forest.json", app / "assets" / "model" / "cutmind_forest.json")
            shutil.copy(out / "test_vectors.json", app / "test" / "test_vectors.json")
            print(f"\n--deploy: model copied into the Flutter app ({app}).")
    print(f"\nDone. Everything is in {out}")


if __name__ == "__main__":
    main()
