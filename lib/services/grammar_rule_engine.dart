class GrammarValidationResult {
  const GrammarValidationResult({
    required this.score,
    required this.primaryErrorType,
    required this.feedback,
    required this.diagnostics,
  });

  final double score;
  final String primaryErrorType;
  final String feedback;
  final Map<String, double> diagnostics;
}

class GrammarRuleProfile {
  const GrammarRuleProfile({
    required this.langCode,
    required this.requiresPunctuation,
    required this.minTokens,
    required this.preferredOrder,
    required this.verbPatterns,
    required this.weights,
  });

  final String langCode;
  final bool requiresPunctuation;
  final int minTokens;
  final List<String> preferredOrder;
  final List<RegExp> verbPatterns;
  final Map<String, double> weights;
}

class GrammarRuleEngine {
  const GrammarRuleEngine({GrammarLinguisticAnalyzer? analyzer}) : _analyzer = analyzer ?? const GrammarLinguisticAnalyzer();

  final GrammarLinguisticAnalyzer _analyzer;

  GrammarValidationResult validate({
    required String promptSentence,
    required String answer,
    required String langCode,
  }) {
    final profile = _profileFor(langCode);
    final promptTokens = _tokens(promptSentence);
    final answerTokens = _tokens(answer);
    final ling = _analyzer.analyze(answer, langCode);

    final changed = answer.toLowerCase() != promptSentence.toLowerCase();
    final punctuationOk = !profile.requiresPunctuation || _hasPunctuation(answer);
    final lengthOk = answerTokens.length >= profile.minTokens;
    final overlap = _overlap(promptTokens, answerTokens);
    final verbScore = _verbScore(answerTokens, profile.verbPatterns, ling);
    final orderScore = _orderScore(answerTokens, profile.preferredOrder, ling);
    final agreementScore = _agreementScore(answerTokens, ling);

    double score = 0;
    score += (changed ? 1.0 : 0.0) * (profile.weights['changed'] ?? 0);
    score += (lengthOk ? 1.0 : 0.0) * (profile.weights['length'] ?? 0);
    score += (punctuationOk ? 1.0 : 0.0) * (profile.weights['punctuation'] ?? 0);
    score += overlap * (profile.weights['overlap'] ?? 0);
    score += verbScore * (profile.weights['verb'] ?? 0);
    score += orderScore * (profile.weights['order'] ?? 0);
    score += agreementScore * (profile.weights['agreement'] ?? 0);

    final diagnostics = {
      'changed': changed ? 1.0 : 0.0,
      'length': lengthOk ? 1.0 : 0.0,
      'punctuation': punctuationOk ? 1.0 : 0.0,
      'overlap': overlap,
      'verb': verbScore,
      'order': orderScore,
      'agreement': agreementScore,
      'dependency': ling.dependencyConfidence,
    };

    if (!changed) {
      return GrammarValidationResult(
        score: score.clamp(0, 1),
        primaryErrorType: 'No grammar change',
        feedback: 'Transform the prompt grammar (tense/order/form), not just copy it.',
        diagnostics: diagnostics,
      );
    }
    if (!lengthOk) {
      return GrammarValidationResult(
        score: score.clamp(0, 1),
        primaryErrorType: 'Sentence structure',
        feedback: 'Build a fuller sentence with core structure and detail.',
        diagnostics: diagnostics,
      );
    }
    if (verbScore < 0.4) {
      return GrammarValidationResult(
        score: score.clamp(0, 1),
        primaryErrorType: 'Verb formation',
        feedback: 'Adjust the verb form/auxiliary to match target grammar.',
        diagnostics: diagnostics,
      );
    }
    if (orderScore < 0.4) {
      return GrammarValidationResult(
        score: score.clamp(0, 1),
        primaryErrorType: 'Word order',
        feedback: 'Reorder sentence elements to fit natural syntax.',
        diagnostics: diagnostics,
      );
    }
    if (overlap < 0.2) {
      return GrammarValidationResult(
        score: score.clamp(0, 1),
        primaryErrorType: 'Meaning drift',
        feedback: 'Keep core meaning while changing grammar form.',
        diagnostics: diagnostics,
      );
    }

    return GrammarValidationResult(
      score: score.clamp(0, 1),
      primaryErrorType: 'Strong response',
      feedback: 'Great transformation with strong grammar signals.',
      diagnostics: diagnostics,
    );
  }

  GrammarRuleProfile _profileFor(String langCode) {
    final base = langCode.split(RegExp(r'[-_]')).first.toLowerCase();
    final profile = _overrides[base];
    if (profile != null) return profile;

    final cjk = {'zh', 'ja', 'ko'};
    if (cjk.contains(base)) {
      return _buildProfile(base, requiresPunctuation: false, minTokens: 3, order: ['s', 'o', 'v']);
    }
    return _buildProfile(base, requiresPunctuation: true, minTokens: 4, order: ['s', 'v', 'o']);
  }

  GrammarRuleProfile _buildProfile(
    String code, {
    required bool requiresPunctuation,
    required int minTokens,
    required List<String> order,
  }) {
    return GrammarRuleProfile(
      langCode: code,
      requiresPunctuation: requiresPunctuation,
      minTokens: minTokens,
      preferredOrder: order,
      verbPatterns: _verbPatternsFor(code),
      weights: const {
        'changed': 0.15,
        'length': 0.12,
        'punctuation': 0.07,
        'overlap': 0.20,
        'verb': 0.20,
        'order': 0.16,
        'agreement': 0.10,
      },
    );
  }

  List<RegExp> _verbPatternsFor(String code) {
    switch (code) {
      case 'en':
        return [RegExp(r'\b(am|is|are|was|were|be|been|being|do|does|did|have|has|had)\b'), RegExp(r'\b\w+(ed|ing|s)\b')];
      case 'es':
        return [RegExp(r'\b(soy|eres|es|somos|son|fui|fue|está|están|he|ha|han)\b'), RegExp(r'\b\w+(ar|er|ir|ado|ido|ando|iendo|ó|aron)\b')];
      case 'fr':
        return [RegExp(r'\b(suis|es|est|sommes|êtes|sont|ai|as|a|avons|ont|été)\b'), RegExp(r'\b\w+(er|ir|re|é|ée|és|ées|ant)\b')];
      case 'de':
        return [RegExp(r'\b(bin|bist|ist|sind|seid|war|waren|habe|hat|haben)\b'), RegExp(r'\b\w+(en|st|t|te)\b')];
      case 'ar':
        return [RegExp(r'[\u0621-\u064A]+')];
      case 'ru':
        return [RegExp(r'[\u0400-\u04FF]+')];
      case 'zh':
      case 'ja':
      case 'ko':
        return [RegExp(r'.+')];
      default:
        return [RegExp(r'\b\w{2,}\b')];
    }
  }

  bool _hasPunctuation(String answer) => answer.contains('.') || answer.contains('!') || answer.contains('?');

  List<String> _tokens(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  double _overlap(List<String> prompt, List<String> answer) {
    if (answer.isEmpty) return 0;
    return answer.where(prompt.contains).length / answer.length;
  }

  double _verbScore(List<String> tokens, List<RegExp> patterns, LinguisticSnapshot ling) {
    if (tokens.isEmpty) return 0;
    final joined = tokens.join(' ');
    final hits = patterns.where((p) => p.hasMatch(joined)).length;
    final patternScore = (hits / patterns.length).clamp(0, 1);
    final posVerb = ling.tokens.where((t) => t.pos == 'VERB' || t.pos == 'AUX').length;
    final posScore = tokens.isEmpty ? 0.0 : (posVerb / tokens.length * 3).clamp(0.0, 1.0);
    return ((patternScore * 0.65) + (posScore * 0.35)).clamp(0.0, 1.0);
  }

  double _orderScore(List<String> tokens, List<String> order, LinguisticSnapshot ling) {
    if (tokens.length < 3) return 0.4;
    if (ling.dependencyConfidence > 0) {
      return ling.dependencyConfidence;
    }
    if (order.join('-') == 's-v-o') {
      return tokens.length >= 4 ? 0.8 : 0.6;
    }
    if (order.join('-') == 's-o-v') {
      return tokens.length >= 3 ? 0.8 : 0.6;
    }
    return 0.6;
  }

  double _agreementScore(List<String> tokens, LinguisticSnapshot ling) {
    if (tokens.isEmpty) return 0;
    if (ling.morphAgreement > 0) return ling.morphAgreement;
    final uniqueRatio = tokens.toSet().length / tokens.length;
    if (uniqueRatio < 0.45) return 0.3;
    if (uniqueRatio < 0.65) return 0.6;
    return 0.9;
  }

  static final Map<String, GrammarRuleProfile> _overrides = {
    'en': const GrammarRuleProfile(
      langCode: 'en',
      requiresPunctuation: true,
      minTokens: 4,
      preferredOrder: ['s', 'v', 'o'],
      verbPatterns: [RegExp(r'\b(am|is|are|was|were|do|does|did|have|has|had)\b')],
      weights: {
        'changed': 0.14,
        'length': 0.12,
        'punctuation': 0.08,
        'overlap': 0.22,
        'verb': 0.22,
        'order': 0.14,
        'agreement': 0.08,
      },
    ),
    'zh': const GrammarRuleProfile(
      langCode: 'zh',
      requiresPunctuation: false,
      minTokens: 3,
      preferredOrder: ['s', 'v', 'o'],
      verbPatterns: [RegExp(r'.+')],
      weights: {
        'changed': 0.16,
        'length': 0.10,
        'punctuation': 0.02,
        'overlap': 0.26,
        'verb': 0.20,
        'order': 0.18,
        'agreement': 0.08,
      },
    ),
  };
}
import 'grammar_linguistic_analyzer.dart';
