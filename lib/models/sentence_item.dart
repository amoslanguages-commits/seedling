/// A single item for sentence-based quizzes.
/// Completely independent from the vocabulary [Word] model —
/// will be backed by a separate sentences database in the future.
class SentenceItem {
  final String id;

  /// Full sentence in the TARGET language (e.g. Spanish).
  final String targetSentence;

  /// Full sentence in the NATIVE language (e.g. English).
  final String nativeSentence;

  /// The target-language word that is tested / blanked.
  final String targetWord;

  /// Native-language translation of [targetWord].
  final String nativeWord;

  final String targetLangCode;
  final String nativeLangCode;

  const SentenceItem({
    required this.id,
    required this.targetSentence,
    required this.nativeSentence,
    required this.targetWord,
    required this.nativeWord,
    this.targetLangCode = 'es',
    this.nativeLangCode = 'en',
  });

  /// Returns [targetSentence] with [targetWord] replaced by "___".
  String get gappedSentence {
    return targetSentence.replaceFirst(
      RegExp(
        r'\b' + RegExp.escape(targetWord) + r'\b',
        caseSensitive: false,
        unicode: true,
      ),
      '___',
    );
  }
}
