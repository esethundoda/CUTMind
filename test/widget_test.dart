import 'package:flutter_test/flutter_test.dart';
import 'package:cutmind/services/forest_model.dart';

// The default Flutter "counter" smoke test no longer applies to CUTMind
// (the app requires Firebase to start), so this checks the ML model wiring.
void main() {
  test('ForestModel parses a minimal forest and predicts', () {
    final forest = ForestModel.fromJson({
      'classes': ['low', 'high'],
      'features': ['stress'],
      'meta': {},
      'trees': [
        {
          'left': [1, -1, -1],
          'right': [2, -1, -1],
          'feature': [0, -2, -2],
          'threshold': [3.0, -2.0, -2.0],
          'value': [
            [0.5, 0.5],
            [1.0, 0.0],
            [0.0, 1.0],
          ],
        }
      ],
    });
    expect(forest.predict([1]).label, 'low');
    expect(forest.predict([5]).label, 'high');
  });
}
