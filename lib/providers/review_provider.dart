import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../database/database_helper.dart';
import '../services/fsrs_service.dart';
import 'app_providers.dart';

/// TIMER SETTINGS
enum ReviewTimerMode { none, five, ten, fifteen, twenty }

extension ReviewTimerModeExt on ReviewTimerMode {
  int? get seconds {
    return switch (this) {
      ReviewTimerMode.none => null,
      ReviewTimerMode.five => 5,
      ReviewTimerMode.ten => 10,
      ReviewTimerMode.fifteen => 15,
      ReviewTimerMode.twenty => 20,
    };
  }

  String get label {
    return switch (this) {
      ReviewTimerMode.none => 'No Timer',
      ReviewTimerMode.five => '5s Blitz',
      ReviewTimerMode.ten => '10s Speed',
      ReviewTimerMode.fifteen => '15s Normal',
      ReviewTimerMode.twenty => '20s Relaxed',
    };
  }
}

final reviewTimerProvider = StateNotifierProvider<ReviewTimerNotifier, ReviewTimerMode>((ref) {
  return ReviewTimerNotifier();
});

class ReviewTimerNotifier extends StateNotifier<ReviewTimerMode> {
  ReviewTimerNotifier() : super(ReviewTimerMode.none);

  void setMode(ReviewTimerMode mode) => state = mode;
}

/// SESSION STATE
class ReviewSessionState {
  final List<Word> words;
  final int currentIndex;
  final bool isCompleted;
  final Map<int, int> results; // wordId -> rating (1-4)

  ReviewSessionState({
    this.words = const [],
    this.currentIndex = 0,
    this.isCompleted = false,
    this.results = const {},
  });

  Word? get currentWord => currentIndex < words.length ? words[currentIndex] : null;
  double get progress => words.isEmpty ? 0 : currentIndex / words.length;

  ReviewSessionState copyWith({
    List<Word>? words,
    int? currentIndex,
    bool? isCompleted,
    Map<int, int>? results,
  }) {
    return ReviewSessionState(
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      results: results ?? this.results,
    );
  }
}

final reviewSessionProvider = StateNotifierProvider<ReviewSessionNotifier, ReviewSessionState>((ref) {
  return ReviewSessionNotifier(ref);
});

class ReviewSessionNotifier extends StateNotifier<ReviewSessionState> {
  final Ref _ref;
  ReviewSessionNotifier(this._ref) : super(ReviewSessionState());

  Future<void> startSession({int limit = 15, String? subDomain}) async {
    final db = _ref.read(databaseProvider);
    final nativeLang = _ref.read(nativeLanguageProvider);
    final targetLang = _ref.read(currentLanguageProvider);

    final dueWords = await db.getSRSDueWords(
      nativeLang, 
      targetLang, 
      limit: limit,
      subDomain: subDomain,
    );
    
    // If no due words, get some random learned words as fallback
    List<Word> sessionWords = dueWords;
    if (sessionWords.isEmpty) {
      sessionWords = await db.getRandomLearnedWords(
        nativeLang, 
        targetLang, 
        limit: 10,
        subDomain: subDomain,
      );
    }

    state = ReviewSessionState(
      words: sessionWords,
      currentIndex: 0,
      isCompleted: false,
      results: {},
    );
  }

  Future<void> submitRating(bool isCorrect, Duration responseTime) async {
    final word = state.currentWord;
    if (word == null) return;

    // 1. Calculate new FSRS state
    final updatedWord = FSRSService.instance.calculateReview(word, isCorrect, responseTime);

    // 2. Persist to DB
    await _ref.read(databaseProvider).updateWordFSRS(updatedWord);

    // 3. Move to next word
    final newResults = Map<int, int>.from(state.results);
    newResults[word.id!] = isCorrect ? 3 : 1; // Good vs again

    if (state.currentIndex >= state.words.length - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        isCompleted: true,
        results: newResults,
      );
    } else {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        results: newResults,
      );
    }
  }

  void reset() {
    state = ReviewSessionState();
  }
}

/// PROVIDER FOR GROUPED TOPICS
final reviewTopicsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final native = ref.watch(nativeLanguageProvider);
  final target = ref.watch(currentLanguageProvider);
  
  return await db.getReviewTopicGroups(native, target);
});
