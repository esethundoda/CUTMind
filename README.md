# CUTMind

CUTMind lets a student check in on stress, anxiety, sleep, motivation and social connection, receive a
**risk result with a reason** (Random Forest trained on 33 real, anonymous CUT responses), keep a private
journal (Claude API analysis), earn points and streaks, and find counselling support that is **always the
student's choice** (nothing is sent automatically).

Built with **Flutter** (app), **Firebase** (Authentication + Firestore) and **Python / scikit-learn** (model).

---

## 1. How to run the beta

You need the **Flutter SDK 3.24 or newer** (https://docs.flutter.dev/get-started/install) and Chrome.

```
cd cutmind
flutter pub get
flutter run -d chrome
```

The app is already connected to the project's Firebase back end (`lib/firebase_options.dart`), so no
Firebase set-up is needed.

### Logging in
- **Easiest:** tap **Sign up** on the first screen and create your own account (any email and a password
  of at least 6 characters).
- **Or** use the dedicated test account given in the eThuto submission comments.

### Journal (Claude API key)
The journal sends the entry text to the Claude API. For security, **no API key is included**.
`lib/config/api_config.dart` contains the placeholder `YOUR_API_KEY_HERE`. To try the journal, paste a key
there (https://console.anthropic.com/). Note: when the app runs in a web browser, the browser may block the
call to the Claude API, so the journal analysis is best tested on an Android/iOS emulator or device.
All other features work without a key.

---

## 2. Suggested test cases (expected results)

Open the **Check-in** tab, answer the five questions (1 to 5, in the order stress, anxiety, sleep, motivation,
social), finish, then tap **See my wellness report**. Expected results from the shipped model:

| Case | Stress | Anxiety | Sleep | Motivation | Social | Expected result |
|---|---|---|---|---|---|---|
| Healthy day | 1 | 1 | 5 | 5 | 5 | **Low risk** |
| Mixed but supported | 4 | 3 | 4 | 4 | 5 | Low risk, but close to the line |
| Struggling | 5 | 5 | 1 | 1 | 1 | **Elevated anxiety risk**, with the support card |

Things to notice:
- Each result shows **why** in plain language ("What shaped your result": areas that need care and things going well), followed by tailored wellness suggestions. No model metrics, percentages or SHAP values appear on the student interface.
- Only the **first check-in each day earns points** (+10); later ones show "points already collected".
- For an at-risk result a **support card** appears. "Contact CUT Counselling" only shows contact details.
  Nothing is sent automatically.
- **Progress** tab: points, streak, milestones and a stress trend update live (Firestore real-time updates).
- **Pause & reset** (home screen): guided breathing exercise.

---

## 3. The machine-learning model

| | |
|---|---|
| Data | 36 anonymous responses, 35 consented and aged 18+, **33 usable** after cleaning |
| Features | stress, anxiety, sleep, motivation, social (each 1 to 5) |
| Label | GAD-2 total (0 to 6); **3 or more = at risk** (17 low, 16 at risk). A screening label, not a diagnosis |
| Model | Random Forest, 100 trees, max depth 3, min leaf 2 (no tuning; n is small) |
| Testing | Cross-validated predictions for every student (no separate test set at n = 33) |
| Result (preliminary) | RF 75.8% accuracy (25 of 33); logistic regression 78.8%; old hand-written formula 72.7%; majority guess 45.5% |
| At-risk class | precision 0.83, recall 0.62, F1 0.71 (found 10 of 16, missed 6; 2 false alarms) |

All outputs are in `ml/model_output/` (`report.txt`, `confusion_matrix.png`, `shap_summary.png`,
`feature_importance.png`, `cutmind_forest.json`, `model.joblib`).

How it runs in the app: the 100 trees are exported to `assets/model/cutmind_forest.json`; the app walks each tree
on the device (`lib/services/forest_model.dart`). Technical diagnostics for the researcher can be switched on with `kShowModelDiagnostics` in `lib/config/dev_flags.dart` (off by default). Run `flutter test` to check the app reproduces the Python
predictions on 15 test vectors (`test/test_vectors.json`).

To retrain (needs `responses.csv`, **not included for privacy**; Python 3.12 or newer):
```
cd ml
pip install -r requirements.txt
py train_model.py --instrument gad2 --allow-small --deploy
```
Software versions used for the reported numbers: pandas 3.0.6, numpy 2.5.3, scikit-learn 1.9.1, shap 0.52.0.
With only 33 students, results shift by a few points across library versions; they are pilot-level figures.

---

## 4. Project structure
```
lib/main.dart                  app start, onboarding, sign-in gate
lib/auth/                      sign in / sign up screens
lib/screens/                   home, check-in, wellness report, journal, progress, support, breathing
lib/services/forest_model.dart on-device Random Forest + feature contributions
lib/theme/app_theme.dart       colours, shared widgets, asset names
lib/config/api_config.dart     Claude API key placeholder (no key included)
assets/model/                  exported forest (JSON)
assets/images, assets/animations  illustrations and animations
ml/                            Python training pipeline and results
test/                          unit tests for the on-device model
```

## 5. Scope status (beta)
Implemented: sign-up and login, five-question check-in, journal analysis (Claude API), risk result with
explanation, points/streaks/milestones, student-controlled counselling support.
Outstanding (future work): eight-question survey (five built), activity logging and multi-source fusion,
separating student identity from stored data (POPIA).

## 6. Privacy and limitations
- Survey data was voluntary and anonymous (18+). Raw responses and API keys are not part of this package.
- The result is a **screening aid, not a diagnosis**. Pilot sample: 33 students, mostly Engineering and IT.
- The app currently stores the signed-in student's email for login (to be separated before a full study).
- Journal text is sent to the Claude API, so it needs an internet connection.
