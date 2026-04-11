class ExplanationEntry {
  const ExplanationEntry({
    required this.id,
    required this.ruleId,
    required this.levelBand,
    required this.message,
    required this.ruleVersion,
    required this.source,
    required this.examples,
    required this.counterExamples,
    required this.reviewer,
  });

  final String id;
  final String ruleId;
  final String levelBand;
  final String message;
  final String ruleVersion;
  final String source;
  final List<String> examples;
  final List<String> counterExamples;
  final String reviewer;
}

class GrammarExplanations {
  static const Map<String, ExplanationEntry> _entries = {
    'grammar.en.transform.missing': ExplanationEntry(
      id: 'grammar.en.transform.missing',
      ruleId: 'transform.missing',
      levelBand: 'A0-C1',
      message: 'Change tense/form/order from the prompt before submitting.',
      ruleVersion: 'rule-engine-v2',
      source: 'curated.en.core',
      examples: ['I go -> I went', 'She eat -> She eats'],
      counterExamples: ['Copying prompt unchanged'],
      reviewer: 'native_en_reviewer',
    ),
    'grammar.en.syntax.structure': ExplanationEntry(
      id: 'grammar.en.syntax.structure',
      ruleId: 'syntax.structure',
      levelBand: 'A0-B2',
      message: 'Use a complete clause with subject + verb + complement.',
      ruleVersion: 'rule-engine-v2',
      source: 'curated.en.core',
      examples: ['I am happy.', 'We are ready now.'],
      counterExamples: ['Very happy.'],
      reviewer: 'native_en_reviewer',
    ),
    'grammar.en.morph.verb': ExplanationEntry(
      id: 'grammar.en.morph.verb',
      ruleId: 'morph.verb',
      levelBand: 'A1-C1',
      message: 'Verb inflection/auxiliary does not match target grammar context.',
      ruleVersion: 'rule-engine-v2',
      source: 'curated.en.core',
      examples: ['He has gone.', 'They were waiting.'],
      counterExamples: ['He have go.'],
      reviewer: 'native_en_reviewer',
    ),
    'grammar.zh.syntax.order': ExplanationEntry(
      id: 'grammar.zh.syntax.order',
      ruleId: 'syntax.order',
      levelBand: 'A1-C1',
      message: 'Word order drifted from natural target structure.',
      ruleVersion: 'rule-engine-v2',
      source: 'curated.zh.core',
      examples: ['我昨天去了市场。'],
      counterExamples: ['昨天我了去市场。'],
      reviewer: 'native_zh_reviewer',
    ),
  };

  static const Map<String, ExplanationEntry> _genericBySubCode = {
    'transform.missing': ExplanationEntry(
      id: 'grammar.generic.transform.missing',
      ruleId: 'transform.missing',
      levelBand: 'A0-C1',
      message: 'Apply the requested transformation (tense/form/order) to the original sentence.',
      ruleVersion: 'rule-engine-v2',
      source: 'generic.transform',
      examples: ['Present -> past transform'],
      counterExamples: ['No transform'],
      reviewer: 'generic_review_board',
    ),
    'syntax.structure': ExplanationEntry(
      id: 'grammar.generic.syntax.structure',
      ruleId: 'syntax.structure',
      levelBand: 'A0-B2',
      message: 'Ensure the sentence has a complete clause with a clear predicate.',
      ruleVersion: 'rule-engine-v2',
      source: 'generic.syntax',
      examples: ['Subject + verb + complement'],
      counterExamples: ['Fragment only'],
      reviewer: 'generic_review_board',
    ),
    'morph.verb': ExplanationEntry(
      id: 'grammar.generic.morph.verb',
      ruleId: 'morph.verb',
      levelBand: 'A1-C1',
      message: 'Check verb inflection/aspect and auxiliary alignment for this context.',
      ruleVersion: 'rule-engine-v2',
      source: 'generic.morph',
      examples: ['Correct auxiliary and main verb form'],
      counterExamples: ['Wrong verb ending'],
      reviewer: 'generic_review_board',
    ),
    'syntax.order': ExplanationEntry(
      id: 'grammar.generic.syntax.order',
      ruleId: 'syntax.order',
      levelBand: 'A1-C1',
      message: 'Reorder constituents according to target language syntax.',
      ruleVersion: 'rule-engine-v2',
      source: 'generic.syntax',
      examples: ['SVO/SOV aligned with language'],
      counterExamples: ['Incorrect constituent order'],
      reviewer: 'generic_review_board',
    ),
    'semantics.drift': ExplanationEntry(
      id: 'grammar.generic.semantics.drift',
      ruleId: 'semantics.drift',
      levelBand: 'A2-C1',
      message: 'Keep original meaning while changing grammar form.',
      ruleVersion: 'rule-engine-v2',
      source: 'generic.semantics',
      examples: ['Meaning preserved after tense change'],
      counterExamples: ['Meaning changed entirely'],
      reviewer: 'generic_review_board',
    ),
  };

  static ExplanationEntry resolve(String langCode, String subCode) {
    final exact = 'grammar.$langCode.$subCode';
    final base = langCode.split(RegExp(r'[-_]')).first;
    final fallback = 'grammar.$base.$subCode';
    return _entries[exact] ??
        _entries[fallback] ??
        _genericBySubCode[subCode] ??
        ExplanationEntry(
          id: fallback,
          ruleId: subCode,
          levelBand: 'A0-C1',
          message: 'Review this grammar contrast and retry with a refined sentence.',
          ruleVersion: 'rule-engine-v2',
          source: 'fallback.generic',
          examples: const ['Retry with corrected structure'],
          counterExamples: const ['Uncorrected pattern repeated'],
          reviewer: 'fallback_system',
        );
  }
}
