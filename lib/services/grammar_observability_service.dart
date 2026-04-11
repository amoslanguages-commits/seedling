class GrammarObservabilityService {
  GrammarObservabilityService._();
  static final GrammarObservabilityService instance = GrammarObservabilityService._();

  final List<Map<String, Object?>> _events = [];

  void logEvaluation({
    required String langCode,
    required String errorType,
    required double score,
    required double threshold,
    required double confidence,
  }) {
    _events.add({
      'ts': DateTime.now().toIso8601String(),
      'lang': langCode,
      'error_type': errorType,
      'score': score,
      'threshold': threshold,
      'confidence': confidence,
      'passed': score >= threshold,
    });
    if (_events.length > 2000) {
      _events.removeRange(0, _events.length - 2000);
    }
  }

  List<Map<String, Object?>> recent({int count = 100}) {
    if (_events.length <= count) return List.unmodifiable(_events);
    return List.unmodifiable(_events.sublist(_events.length - count));
  }

  void reset() => _events.clear();

  Map<String, int> errorBreakdown({String? langCode}) {
    final scope = langCode == null
        ? _events
        : _events.where((e) => e['lang'] == langCode).toList();
    final counts = <String, int>{};
    for (final e in scope) {
      final key = (e['error_type'] as String?) ?? 'unknown';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, Object> qualitySummary({String? langCode}) {
    final scope = langCode == null
        ? _events
        : _events.where((e) => e['lang'] == langCode).toList();
    if (scope.isEmpty) {
      return {'count': 0, 'pass_rate': 0.0, 'avg_confidence': 0.0, 'avg_margin': 0.0};
    }
    final passed = scope.where((e) => e['passed'] == true).length;
    final avgConfidence = scope
            .map((e) => (e['confidence'] as num?)?.toDouble() ?? 0.0)
            .fold<double>(0, (a, b) => a + b) /
        scope.length;
    final avgMargin = scope
            .map((e) {
              final score = (e['score'] as num?)?.toDouble() ?? 0.0;
              final threshold = (e['threshold'] as num?)?.toDouble() ?? 0.0;
              return (score - threshold);
            })
            .fold<double>(0, (a, b) => a + b) /
        scope.length;
    return {
      'count': scope.length,
      'pass_rate': passed / scope.length,
      'avg_confidence': avgConfidence,
      'avg_margin': avgMargin,
      'error_breakdown': errorBreakdown(langCode: langCode),
    };
  }
}
