import '../models/grammar_model.dart';
import 'grammar_explanations.dart';

class QualityCheckResult {
  const QualityCheckResult({
    required this.name,
    required this.passed,
    required this.message,
  });

  final String name;
  final bool passed;
  final String message;
}

class GrammarQualityOpsService {
  List<QualityCheckResult> validateLanguageCoverage(
    Set<String> langCodes, {
    double? activeThreshold,
  }) {
    final checks = <QualityCheckResult>[];
    checks.add(
      QualityCheckResult(
        name: 'language_count',
        passed: langCodes.length >= 121,
        message: 'Detected ${langCodes.length} languages (target >=121).',
      ),
    );
    checks.add(
      QualityCheckResult(
        name: 'concept_catalog',
        passed: GrammarConcept.allConcepts.length == 121,
        message: 'Concept catalog size ${GrammarConcept.allConcepts.length}.',
      ),
    );
    checks.add(
      QualityCheckResult(
        name: 'explanation_seed',
        passed: GrammarExplanations.resolve('en', 'syntax.structure').source.isNotEmpty,
        message: 'Explanation KB seed available.',
      ),
    );
    final explanation = GrammarExplanations.resolve('en', 'syntax.structure');
    checks.add(
      QualityCheckResult(
        name: 'explanation_metadata',
        passed: explanation.ruleId.isNotEmpty &&
            explanation.levelBand.isNotEmpty &&
            explanation.examples.isNotEmpty &&
            explanation.counterExamples.isNotEmpty &&
            explanation.reviewer.isNotEmpty,
        message: 'Explanation metadata fields are populated.',
      ),
    );
    if (activeThreshold != null) {
      checks.add(
        QualityCheckResult(
          name: 'threshold_range',
          passed: activeThreshold >= 0.55 && activeThreshold <= 0.9,
          message: 'Active threshold ${activeThreshold.toStringAsFixed(2)} within [0.55, 0.90].',
        ),
      );
    }
    return checks;
  }
}
