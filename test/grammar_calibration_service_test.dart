import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/models/grammar_model.dart';
import 'package:seedling/services/grammar_calibration_service.dart';

void main() {
  test('calibration threshold differs by level', () {
    const service = GrammarCalibrationService();
    final a0 = service.thresholdFor(langCode: 'en', level: GrammarLevel.a0);
    final c1 = service.thresholdFor(langCode: 'en', level: GrammarLevel.c1);
    expect(c1, greaterThan(a0));
  });
}
