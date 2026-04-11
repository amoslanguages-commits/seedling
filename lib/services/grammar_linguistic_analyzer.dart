class MorphToken {
  const MorphToken({required this.surface, required this.pos});
  final String surface;
  final String pos;
}

class LinguisticSnapshot {
  const LinguisticSnapshot({
    required this.tokens,
    required this.subjectIndex,
    required this.verbIndex,
    required this.objectIndex,
    required this.morphAgreement,
    required this.dependencyConfidence,
  });

  final List<MorphToken> tokens;
  final int subjectIndex;
  final int verbIndex;
  final int objectIndex;
  final double morphAgreement;
  final double dependencyConfidence;
}

class GrammarLinguisticAnalyzer {
  const GrammarLinguisticAnalyzer();

  LinguisticSnapshot analyze(String sentence, String langCode) {
    final base = langCode.split(RegExp(r'[-_]')).first.toLowerCase();
    final rawTokens = sentence
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    final tokens = rawTokens.map((t) => MorphToken(surface: t, pos: _pos(base, t))).toList();

    final subject = tokens.indexWhere((t) => t.pos == 'PRON' || t.pos == 'NOUN');
    final verb = tokens.indexWhere((t) => t.pos == 'VERB' || t.pos == 'AUX');
    final object = tokens.lastIndexWhere((t) => t.pos == 'NOUN' || t.pos == 'PRON');

    final agreement = _agreement(tokens, base);
    final dep = _dependencyConfidence(subject, verb, object, tokens.length);

    return LinguisticSnapshot(
      tokens: tokens,
      subjectIndex: subject,
      verbIndex: verb,
      objectIndex: object,
      morphAgreement: agreement,
      dependencyConfidence: dep,
    );
  }

  String _pos(String lang, String token) {
    final pronouns = {
      'i', 'you', 'he', 'she', 'we', 'they', 'yo', 'tu', 'él', 'ella', 'nosotros',
      'je', 'tu', 'il', 'elle', 'nous', 'vous', 'ich', 'du', 'er', 'sie',
    };
    if (pronouns.contains(token)) return 'PRON';

    if (_verbLike(lang, token)) return 'VERB';
    if (token.length <= 2) return 'PART';
    return 'NOUN';
  }

  bool _verbLike(String lang, String token) {
    switch (lang) {
      case 'en':
        return RegExp(r'(am|is|are|was|were|have|has|had|do|does|did|ed|ing|s)$').hasMatch(token);
      case 'es':
        return RegExp(r'(ar|er|ir|ado|ido|ando|iendo|é|ó|aron|aba)$').hasMatch(token);
      case 'fr':
        return RegExp(r'(er|ir|re|é|ée|ait|aient|ons)$').hasMatch(token);
      default:
        return RegExp(r'.{3,}').hasMatch(token);
    }
  }

  double _agreement(List<MorphToken> tokens, String lang) {
    if (tokens.isEmpty) return 0;
    final pron = tokens.where((t) => t.pos == 'PRON').length;
    final verb = tokens.where((t) => t.pos == 'VERB' || t.pos == 'AUX').length;
    if (pron == 0 || verb == 0) return 0.5;
    final ratio = (verb / pron).clamp(0.0, 1.5);
    return (1.0 - (ratio - 1.0).abs()).clamp(0.0, 1.0);
  }

  double _dependencyConfidence(int s, int v, int o, int len) {
    if (len < 2 || s < 0 || v < 0) return 0.35;
    if (o >= 0 && s < v && v <= o) return 0.9;
    if (s < v) return 0.75;
    return 0.45;
  }
}
