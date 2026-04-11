import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/services/grammar_rule_engine.dart';

void main() {
  test('rule engine returns structured diagnostics', () {
    const engine = GrammarRuleEngine();
    final result = engine.validate(
      promptSentence: 'Yesterday I go to school.',
      answer: 'Yesterday I went to school.',
      langCode: 'en',
    );

    expect(result.score, greaterThan(0));
    expect(result.diagnostics.containsKey('verb'), isTrue);
  });
}
