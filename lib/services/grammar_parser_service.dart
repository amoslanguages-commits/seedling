import 'dart:convert';

import 'grammar_explanations.dart';
import 'grammar_rule_engine.dart';

class ParserFeedback {
  const ParserFeedback({
    required this.score,
    required this.errorType,
    required this.subErrorCode,
    required this.explanationId,
    required this.feedback,
    required this.confidence,
    required this.featureScores,
    required this.ruleTrace,
    required this.modelVersion,
  });

  final double score;
  final String errorType;
  final String subErrorCode;
  final String explanationId;
  final String feedback;
  final double confidence;
  final Map<String, double> featureScores;
  final List<String> ruleTrace;
  final String modelVersion;

  String featureScoresJson() => jsonEncode(featureScores);
}

class GrammarParserService {
  GrammarParserService({GrammarRuleEngine? engine}) : _engine = engine ?? const GrammarRuleEngine();

  final GrammarRuleEngine _engine;

  ParserFeedback evaluate({
    required String promptSentence,
    required String answer,
    required String langCode,
  }) {
    final v = _engine.validate(
      promptSentence: promptSentence,
      answer: answer,
      langCode: langCode,
    );

    final subCode = _subCodeFor(v.primaryErrorType);
    final explanation = GrammarExplanations.resolve(langCode, subCode);
    final confidence = (0.55 + (v.score * 0.4)).clamp(0.0, 0.98);
    final ruleTrace = _buildRuleTrace(v);

    return ParserFeedback(
      score: v.score,
      errorType: v.primaryErrorType,
      subErrorCode: subCode,
      explanationId: explanation.id,
      feedback: '${v.feedback} ${explanation.message}',
      confidence: confidence,
      featureScores: v.diagnostics,
      ruleTrace: ruleTrace,
      modelVersion: explanation.ruleVersion,
    );
  }

  String _subCodeFor(String errorType) {
    switch (errorType) {
      case 'No grammar change':
        return 'transform.missing';
      case 'Sentence structure':
        return 'syntax.structure';
      case 'Verb formation':
        return 'morph.verb';
      case 'Word order':
        return 'syntax.order';
      case 'Meaning drift':
        return 'semantics.drift';
      case 'Strong response':
        return 'ok.strong';
      default:
        return 'unknown';
    }
  }

  List<String> _buildRuleTrace(GrammarValidationResult result) {
    final trace = <String>[];
    result.diagnostics.forEach((key, value) {
      trace.add('$key=${value.toStringAsFixed(2)}');
    });
    trace.add('decision=${result.primaryErrorType}');
    return trace;
  }
}
