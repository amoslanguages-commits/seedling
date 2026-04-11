import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/services/grammar_observability_service.dart';

void main() {
  test('observability summarizes events', () {
    final obs = GrammarObservabilityService.instance;
    obs.reset();
    obs.logEvaluation(langCode: 'en', errorType: 'x', score: 0.8, threshold: 0.7, confidence: 0.9);
    obs.logEvaluation(langCode: 'en', errorType: 'x', score: 0.4, threshold: 0.7, confidence: 0.6);
    final summary = obs.qualitySummary(langCode: 'en');
    expect(summary['count'], isNotNull);
    final breakdown = summary['error_breakdown'] as Map<String, int>;
    expect(breakdown['x'], 2);
  });
}
