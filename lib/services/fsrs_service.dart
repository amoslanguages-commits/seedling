import 'package:fsrs/fsrs.dart' as fsrs;
import '../models/word.dart';

class FSRSService {
  static final FSRSService _instance = FSRSService._internal();
  factory FSRSService() => _instance;
  FSRSService._internal();

  static FSRSService get instance => _instance;

  // The new scheduler from fsrs v2.0.1
  final _scheduler = fsrs.Scheduler();

  /// Processes a word review and returns the updated Word with FSRS card data.
  Word calculateReview(Word word, bool isCorrect, Duration duration) {
    // 1. Create a Card from the Word's current FSRS state
    final card = fsrs.Card(
      cardId: word.id ?? DateTime.now().millisecondsSinceEpoch,
      due: word.nextReview ?? DateTime.now().toUtc(),
      stability: word.fsrsStability > 0 ? word.fsrsStability : null,
      difficulty: word.fsrsDifficulty > 0 ? word.fsrsDifficulty : null,
      // Map state (0: New, 1: Learning, 2: Review, 3: Relearning)
      // Package uses State enum: learning(1), review(2), relearning(3)
      state: _mapToFsrsState(word.fsrsState),
      lastReview: word.lastReviewed,
    );

    // 2. Determine Rating based on performance
    fsrs.Rating rating;
    if (!isCorrect) {
      rating = fsrs.Rating.again;
    } else {
      final ms = duration.inMilliseconds;
      if (ms < 1500) {
        rating = fsrs.Rating.easy;
      } else if (ms < 4000) {
        rating = fsrs.Rating.good;
      } else {
        rating = fsrs.Rating.hard;
      }
    }

    // 3. Review the card using the scheduler
    final result = _scheduler.reviewCard(
      card,
      rating,
      reviewDateTime: DateTime.now().toUtc(),
      reviewDuration: duration.inMilliseconds,
    );

    final updatedCard = result.card;

    // 4. Sync results back to Word object
    word.fsrsStability = updatedCard.stability ?? 0.0;
    word.fsrsDifficulty = updatedCard.difficulty ?? 0.0;
    word.fsrsState = updatedCard.state.value; // Use enum value (1, 2, or 3)
    
    // Elapsed days calculation (approximation or from package if available)
    if (word.lastReviewed != null) {
      word.fsrsElapsedDays = DateTime.now().difference(word.lastReviewed!).inDays;
    }
    word.fsrsScheduledDays = updatedCard.due.difference(DateTime.now()).inDays;
    
    word.fsrsReps += 1;
    if (!isCorrect) {
      word.fsrsLapses += 1;
      word.streak = 0;
    } else {
      word.streak += 1;
      word.timesCorrect += 1;
    }
    
    word.lastReviewed = updatedCard.lastReview;
    word.nextReview = updatedCard.due;
    word.totalReviews += 1;

    return word;
  }

  /// Initial card state for a brand new word.
  Word initNewWord(Word word) {
    word.fsrsStability = 0.0;
    word.fsrsDifficulty = 0.0;
    word.fsrsReps = 0;
    word.fsrsLapses = 0;
    word.fsrsState = 1; // Start in Learning
    word.nextReview = DateTime.now();
    return word;
  }

  /// Calculates Retrievability (probability of recall) for a word.
  double getRetrievability(Word word) {
    if (word.fsrsStability <= 0 || word.lastReviewed == null) return 0.0;
    
    // Create temp card for calculation
    final card = fsrs.Card(
      cardId: word.id ?? 0,
      stability: word.fsrsStability,
      difficulty: word.fsrsDifficulty,
      lastReview: word.lastReviewed,
      state: _mapToFsrsState(word.fsrsState),
    );
    
    return _scheduler.getCardRetrievability(card);
  }

  fsrs.State _mapToFsrsState(int value) {
    try {
      return fsrs.State.fromValue(value);
    } catch (_) {
      return fsrs.State.learning;
    }
  }
}
