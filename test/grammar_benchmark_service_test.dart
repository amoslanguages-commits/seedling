import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/models/grammar_model.dart';
import 'package:seedling/services/grammar_benchmark_service.dart';
import 'package:seedling/services/grammar_calibration_service.dart';

void main() {
  test('benchmark recommends threshold adjustment', () {
    final service = GrammarBenchmarkService();
    final cases = [
      const GrammarBenchmarkCase(langCode: 'en', level: GrammarLevel.a1, score: 0.8, expectedPass: true),
      const GrammarBenchmarkCase(langCode: 'en', level: GrammarLevel.a1, score: 0.82, expectedPass: false),
      const GrammarBenchmarkCase(langCode: 'en', level: GrammarLevel.a1, score: 0.4, expectedPass: false),
    ];
    final result = service.evaluate(cases, 0.7);
    expect(result.recommendedThreshold, greaterThanOrEqualTo(0.55));
  });

  test('benchmark can apply override when quality gates pass', () {
    GrammarCalibrationService.clearOverrides();
    final service = GrammarBenchmarkService();
    final cases = [
      const GrammarBenchmarkCase(
        langCode: 'en',
        level: GrammarLevel.b1,
        score: 0.9,
        expectedPass: true,
      ),
      const GrammarBenchmarkCase(
        langCode: 'en',
        level: GrammarLevel.b1,
        score: 0.86,
        expectedPass: true,
      ),
      const GrammarBenchmarkCase(
        langCode: 'en',
        level: GrammarLevel.b1,
        score: 0.3,
        expectedPass: false,
      ),
    ];
    service.evaluateAndApply(
      cases: cases,
      currentThreshold: 0.7,
      langCode: 'en',
    );
    expect(GrammarCalibrationService.getLangOverride('en'), isNotNull);
  });
}
