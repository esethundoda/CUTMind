import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmind/services/forest_model.dart'; // <-- change 'cutmind' to your package name in pubspec.yaml

/// Checks the Dart forest gives the same answers as scikit-learn.
/// Needs: assets/model/cutmind_forest.json and test/test_vectors.json
/// (both produced by train_model.py in model_output/).
void main() {
  test('Dart forest matches scikit-learn on exported test vectors', () {
    final forest = ForestModel.fromJson(
        jsonDecode(File('assets/model/cutmind_forest.json').readAsStringSync())
            as Map<String, dynamic>);
    final vectors = jsonDecode(File('test/test_vectors.json').readAsStringSync()) as List;

    for (final v in vectors) {
      final input = (v['input'] as List).map((e) => (e as num).toDouble()).toList();
      final pred = forest.predict(input);
      final classes = List<String>.from(v['classes'] as List);
      final expected = (v['proba'] as List).map((e) => (e as num).toDouble()).toList();
      for (var i = 0; i < classes.length; i++) {
        expect(pred.probabilities[classes[i]]!, closeTo(expected[i], 0.001),
            reason: 'input $input class ${classes[i]}');
      }
      expect(pred.label, v['predicted']);
    }
  });

  test('baseline + contributions = probability of focus class', () {
    final forest = ForestModel.fromJson(
        jsonDecode(File('assets/model/cutmind_forest.json').readAsStringSync())
            as Map<String, dynamic>);
    final p = forest.predict([4, 5, 2, 2, 2]);
    final sum = p.baseline + p.contributions.values.reduce((a, b) => a + b);
    expect(sum, closeTo(p.probabilities[p.focusClass]!, 1e-6));
  });
}
