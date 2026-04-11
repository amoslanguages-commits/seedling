import '../models/grammar_model.dart';

class GrammarCalibrationService {
  const GrammarCalibrationService();
  static final Map<String, double> _overrides = {};

  static const Map<String, double> _baseByLang = {
    'en': 0.72,
    'es': 0.71,
    'fr': 0.71,
    'de': 0.73,
    'zh': 0.68,
    'ja': 0.67,
    'ko': 0.67,
  };

  double thresholdFor({required String langCode, required GrammarLevel level}) {
    final baseCode = langCode.split(RegExp(r'[-_]')).first.toLowerCase();
    final base = _overrides[baseCode] ?? _baseByLang[baseCode] ?? 0.70;
    final levelAdjust = switch (level) {
      GrammarLevel.a0 => -0.08,
      GrammarLevel.a1 => -0.06,
      GrammarLevel.a2 => -0.03,
      GrammarLevel.b1 => 0.0,
      GrammarLevel.b2 => 0.03,
      GrammarLevel.c1 => 0.05,
    };
    return (base + levelAdjust).clamp(0.55, 0.88);
  }

  static void setLangOverride(String langCode, double threshold) {
    final baseCode = langCode.split(RegExp(r'[-_]')).first.toLowerCase();
    _overrides[baseCode] = threshold.clamp(0.55, 0.9);
  }

  static double? getLangOverride(String langCode) {
    final baseCode = langCode.split(RegExp(r'[-_]')).first.toLowerCase();
    return _overrides[baseCode];
  }

  static void clearOverrides() => _overrides.clear();
}
