import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Result of running the trained Random Forest on one check-in.
class Prediction {
  /// Predicted class: 'low' | 'moderate' | 'high' (or 'at_risk' for a binary model).
  final String label;

  /// Probability of every class (average of the trees' leaf distributions).
  final Map<String, double> probabilities;

  /// The class whose probability the contributions below explain
  /// ('high', or 'at_risk' for a binary model).
  final String focusClass;

  /// Per-feature contribution to P(focusClass), in probability units.
  /// Positive = pushes risk up, negative = pushes risk down.
  final Map<String, double> contributions;

  /// Average P(focusClass) over the training set (the starting point).
  final double baseline;

  const Prediction({
    required this.label,
    required this.probabilities,
    required this.focusClass,
    required this.contributions,
    required this.baseline,
  });
}

class _Tree {
  final List<int> left, right, feature;
  final List<double> threshold;
  final List<List<double>> value;
  _Tree(this.left, this.right, this.feature, this.threshold, this.value);
}

/// Random Forest trained in Python (scikit-learn) and exported to JSON by
/// train_model.py. Inference here is the same walk down each tree that
/// scikit-learn performs, so predictions match the Python model.
class ForestModel {
  final List<String> classes;
  final List<String> features;
  final Map<String, dynamic> meta;
  final List<_Tree> _trees;

  ForestModel._(this.classes, this.features, this.meta, this._trees);

  int get treeCount => _trees.length;
  int get trainingSamples => (meta['n_training_samples'] as num?)?.toInt() ?? 0;
  String get labelSource => (meta['label_source'] as String?) ?? 'unknown';

  static Future<ForestModel> load(
      [String asset = 'assets/model/cutmind_forest.json']) async {
    final raw = await rootBundle.loadString(asset);
    return ForestModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory ForestModel.fromJson(Map<String, dynamic> j) {
    List<double> dbls(dynamic l) =>
        (l as List).map((e) => (e as num).toDouble()).toList();
    final trees = (j['trees'] as List).map((t) {
      final m = t as Map<String, dynamic>;
      return _Tree(
        List<int>.from(m['left'] as List),
        List<int>.from(m['right'] as List),
        List<int>.from(m['feature'] as List),
        dbls(m['threshold']),
        (m['value'] as List).map(dbls).toList(),
      );
    }).toList();
    return ForestModel._(
      List<String>.from(j['classes'] as List),
      List<String>.from(j['features'] as List),
      Map<String, dynamic>.from(j['meta'] as Map? ?? {}),
      trees,
    );
  }

  /// [x] must follow [features] order: stress, anxiety, sleep, motivation, social
  /// (raw 1-5 slider values, exactly as collected in the survey).
  Prediction predict(List<double> x) {
    assert(x.length == features.length);
    final k = classes.length;
    final proba = List<double>.filled(k, 0);
    final bias = List<double>.filled(k, 0);
    final contrib =
        List.generate(features.length, (_) => List<double>.filled(k, 0));

    for (final t in _trees) {
      var node = 0;
      for (var c = 0; c < k; c++) {
        bias[c] += t.value[0][c];
      }
      // Walk root -> leaf. Each split changes the class distribution; that change
      // is credited to the feature used at the split (tree-path attribution).
      while (t.left[node] != -1) {
        final f = t.feature[node];
        final next = x[f] <= t.threshold[node] ? t.left[node] : t.right[node];
        for (var c = 0; c < k; c++) {
          contrib[f][c] += t.value[next][c] - t.value[node][c];
        }
        node = next;
      }
      for (var c = 0; c < k; c++) {
        proba[c] += t.value[node][c];
      }
    }

    final n = _trees.length.toDouble();
    for (var c = 0; c < k; c++) {
      proba[c] /= n;
      bias[c] /= n;
      for (var f = 0; f < features.length; f++) {
        contrib[f][c] /= n;
      }
    }

    var best = 0;
    for (var c = 1; c < k; c++) {
      if (proba[c] > proba[best]) best = c;
    }
    final focusClass = classes.contains('high') ? 'high' : 'at_risk';
    final fi = classes.indexOf(focusClass);

    return Prediction(
      label: classes[best],
      probabilities: {for (var c = 0; c < k; c++) classes[c]: proba[c]},
      focusClass: focusClass,
      contributions: {
        for (var f = 0; f < features.length; f++) features[f]: contrib[f][fi]
      },
      baseline: bias[fi],
    );
  }
}
