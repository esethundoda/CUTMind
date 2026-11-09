# CUTMind ML pipeline (PyCharm)

## One-time setup
1. PyCharm: **File > Open** the whole `cutmind_source` folder (or just `ml/`).
2. **Settings > Project > Python Interpreter > Add Interpreter > Virtualenv**, then open the PyCharm
   Terminal and run: `cd ml` then `pip install -r requirements.txt`
3. Put your Google Forms export at `ml/data/responses.csv`.

## Run (Terminal, inside `ml/`)
    python train_model.py --instrument gad2 --allow-small --deploy   # CURRENT form data (see note)
    python train_model.py --instrument gad2 --deploy                   # once you have 40 or more
    (add --binary if a class has too few students)

Or: **Run > Edit Configurations > + Python**, Script = `ml/train_model.py`,
Parameters = `--instrument gad2 --allow-small --deploy`, Working directory = `ml/`.

## Output (ml/model_output/)
report.txt, metrics.json, cleaned_dataset.csv, confusion_matrix.png, feature_importance.png,
label_distribution.png, shap_summary.png, model.joblib, cutmind_forest.json, test_vectors.json

`--deploy` copies cutmind_forest.json to `assets/model/` and test_vectors.json to `test/`
in the Flutter app. Then in the project root: `flutter pub get`, `flutter test`, `flutter run`.
