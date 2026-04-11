import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/services/grammar_quality_ops_service.dart';

void main() {
  test('quality ops validates threshold range when provided', () {
    final service = GrammarQualityOpsService();
    final checks = service.validateLanguageCoverage(
      {'en', 'es'},
      activeThreshold: 0.7,
    );
    final thresholdCheck = checks.firstWhere((c) => c.name == 'threshold_range');
    expect(thresholdCheck.passed, isTrue);
  });
}
