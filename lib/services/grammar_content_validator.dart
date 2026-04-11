class GrammarContentValidationIssue {
  const GrammarContentValidationIssue(this.code, this.message);
  final String code;
  final String message;
}

class GrammarContentValidator {
  static const requiredColumns = {
    'sentence_id',
    'concept_id',
    'concept_chapter',
    'lang_code',
    'level',
    'sentence',
  };

  List<GrammarContentValidationIssue> validateHeaders(List<String> headers) {
    final normalized = headers.map((h) => h.trim().toLowerCase()).toSet();
    final issues = <GrammarContentValidationIssue>[];
    for (final col in requiredColumns) {
      if (!normalized.contains(col)) {
        issues.add(GrammarContentValidationIssue('missing_column', 'Missing required column: $col'));
      }
    }
    return issues;
  }
}
