import '../models/grammar_model.dart';
import 'grammar_calibration_service.dart';

class GrammarBenchmarkCase {
  const GrammarBenchmarkCase({
    required this.langCode,
    required this.level,
    required this.score,
    required this.expectedPass,
  });

  final String langCode;
  final GrammarLevel level;
  final double score;
  final bool expectedPass;
}

class BenchmarkResult {
  const BenchmarkResult({
    required this.precision,
    required this.recall,
    required this.recommendedThreshold,
  });

  final double precision;
  final double recall;
  final double recommendedThreshold;
}

class GrammarBenchmarkService {
  BenchmarkResult evaluate(
    List<GrammarBenchmarkCase> cases,
    double currentThreshold,
  ) {
    if (cases.isEmpty) {
      return BenchmarkResult(
        precision: 0,
        recall: 0,
        recommendedThreshold: currentThreshold,
      );
    }

    int tp = 0, fp = 0, fn = 0;
    for (final c in cases) {
      final predicted = c.score >= currentThreshold;
      if (predicted && c.expectedPass) tp++;
      if (predicted && !c.expectedPass) fp++;
      if (!predicted && c.expectedPass) fn++;
    }

    final precision = tp + fp == 0 ? 0.0 : tp / (tp + fp);
    final recall = tp + fn == 0 ? 0.0 : tp / (tp + fn);

    // Conservative threshold adjustment.
    var recommended = currentThreshold;
    if (precision < 0.75) recommended += 0.03;
    if (recall < 0.70) recommended -= 0.03;

    return BenchmarkResult(
      precision: precision,
      recall: recall,
      recommendedThreshold: recommended.clamp(0.55, 0.9),
    );
  }

  BenchmarkResult evaluateAndApply({
    required List<GrammarBenchmarkCase> cases,
    required double currentThreshold,
    required String langCode,
    double minPrecision = 0.75,
    double minRecall = 0.70,
  }) {
    final result = evaluate(cases, currentThreshold);
    final shouldApply = result.precision >= minPrecision && result.recall >= minRecall;
    if (shouldApply) {
      GrammarCalibrationService.setLangOverride(langCode, result.recommendedThreshold);
    }
    return result;
  }
}
