import '../models/sentence_item.dart';

/// Placeholder sentences for Spanish → English.
/// Replace this with a real sentences database later.
class PlaceholderSentences {
  static const List<SentenceItem> esEn = [
    SentenceItem(
      id: 'ps_001',
      targetSentence: 'La manzana es roja y dulce.',
      nativeSentence: 'The apple is red and sweet.',
      targetWord: 'manzana',
      nativeWord: 'apple',
    ),
    SentenceItem(
      id: 'ps_002',
      targetSentence: 'El perro corre por el parque.',
      nativeSentence: 'The dog runs through the park.',
      targetWord: 'perro',
      nativeWord: 'dog',
    ),
    SentenceItem(
      id: 'ps_003',
      targetSentence: 'El gato duerme en el sofá.',
      nativeSentence: 'The cat sleeps on the sofa.',
      targetWord: 'gato',
      nativeWord: 'cat',
    ),
    SentenceItem(
      id: 'ps_004',
      targetSentence: 'Me gusta el café por la mañana.',
      nativeSentence: 'I like coffee in the morning.',
      targetWord: 'café',
      nativeWord: 'coffee',
    ),
    SentenceItem(
      id: 'ps_005',
      targetSentence: 'La casa tiene un jardín bonito.',
      nativeSentence: 'The house has a beautiful garden.',
      targetWord: 'casa',
      nativeWord: 'house',
    ),
    SentenceItem(
      id: 'ps_006',
      targetSentence: 'El agua del río es muy fría.',
      nativeSentence: 'The river water is very cold.',
      targetWord: 'agua',
      nativeWord: 'water',
    ),
    SentenceItem(
      id: 'ps_007',
      targetSentence: 'El sol brilla con fuerza hoy.',
      nativeSentence: 'The sun shines brightly today.',
      targetWord: 'sol',
      nativeWord: 'sun',
    ),
    SentenceItem(
      id: 'ps_008',
      targetSentence: 'El libro está encima de la mesa.',
      nativeSentence: 'The book is on top of the table.',
      targetWord: 'libro',
      nativeWord: 'book',
    ),
    SentenceItem(
      id: 'ps_009',
      targetSentence: 'Las flores del jardín son hermosas.',
      nativeSentence: 'The garden flowers are beautiful.',
      targetWord: 'flores',
      nativeWord: 'flowers',
    ),
    SentenceItem(
      id: 'ps_010',
      targetSentence: 'El niño come una naranja.',
      nativeSentence: 'The child eats an orange.',
      targetWord: 'naranja',
      nativeWord: 'orange',
    ),
  ];

  /// Returns the sentence list for a given language pair.
  /// Currently always returns [esEn] — extend when adding more pairs.
  static List<SentenceItem> getForLanguagePair(
      String nativeLang, String targetLang) {
    // Future: query from a real sentences table filtered by lang pair.
    return List.of(esEn);
  }
}
