import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/services/grammar_parser_service.dart';

void main() {
  test('parser emits explanation id and sub-error', () {
    final parser = GrammarParserService();
    final result = parser.evaluate(
      promptSentence: 'I go there.',
      answer: 'I go there.',
      langCode: 'en',
    );

    expect(result.explanationId, isNotEmpty);
    expect(result.subErrorCode, isNotEmpty);
    expect(result.modelVersion, isNotEmpty);
  });
}
