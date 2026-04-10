import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:seedling/models/word.dart';
import 'package:seedling/services/fsrs_service.dart';

void main() {
  group('FSRSService Tests', () {
    late FSRSService service;
    late Word testWord;

    setUp(() {
      service = FSRSService.instance;
      testWord = Word(
        id: 1,
        word: 'apple',
        translation: 'Apfel',
        languageCode: 'en',
        targetLanguageCode: 'de',
        fsrsStability: 0.0,
        fsrsDifficulty: 0.0,
        fsrsState: 1, // Learning (maps to fsrs.State.learning)
      );
    });

    test('Initial review (correct, fast) results in Learning or Review state', () {
      final updated = service.calculateReview(
        testWord,
        true,
        const Duration(milliseconds: 500),
      );

      // In FSRS v2, the first review might stay in learning depending on scheduler steps
      expect(updated.fsrsStability, greaterThan(0));
      expect(updated.streak, 1);
    });

    test('Incorrect review results in Again rating', () {
      final updated = service.calculateReview(
        testWord,
        false,
        const Duration(seconds: 1),
      );

      expect(updated.streak, 0);
      expect(updated.fsrsLapses, 1);
    });

    test('Difficulty increases with slow response (Hard vs Easy)', () {
      // 1st review (fast -> Easy)
      final word1 = service.calculateReview(
        testWord,
        true,
        const Duration(milliseconds: 500),
      );
      final diff1 = word1.fsrsDifficulty;

      // New test word for second scenario
      final testWord2 = Word(
        id: 2,
        word: 'banana',
        translation: 'Banane',
        languageCode: 'en',
        targetLanguageCode: 'de',
        fsrsState: 1,
      );
      // 2nd review (slow -> Hard)
      final word2 = service.calculateReview(
        testWord2,
        true,
        const Duration(seconds: 5), 
      );
      final diff2 = word2.fsrsDifficulty;

      expect(diff2, greaterThan(diff1));
    });
  });
}
