import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/services/grammar_linguistic_analyzer.dart';

void main() {
  test('linguistic analyzer returns dependency confidence and indices', () {
    const analyzer = GrammarLinguisticAnalyzer();
    final snap = analyzer.analyze('I have finished the task.', 'en');

    expect(snap.tokens, isNotEmpty);
    expect(snap.verbIndex, isNonNegative);
    expect(snap.dependencyConfidence, greaterThan(0));
  });
}
