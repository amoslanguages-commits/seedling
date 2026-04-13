import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
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

  Map<String, dynamic> toJson() => {
        'words': words.map((w) => w.toMap()).toList(),
        'currentIndex': currentIndex,
        'isCompleted': isCompleted,
        'results': results.map((key, value) => MapEntry(key.toString(), value)),
      };

  factory ReviewSessionState.fromMap(Map<String, dynamic> map) => ReviewSessionState(
        words: (map['words'] as List).map((w) => Word.fromMap(w)).toList(),
        currentIndex: map['currentIndex'],
        isCompleted: map['isCompleted'],
        results: (map['results'] as Map).map((key, value) => MapEntry(int.parse(key.toString()), value as int)),
      );
}

final reviewSessionProvider = StateNotifierProvider<ReviewSessionNotifier, ReviewSessionState>((ref) {
  return ReviewSessionNotifier(ref);
});

/// Quiz type key for Review-tab MCQ (feeds `word_quiz_performance` / weakest-type).
const String reviewMcqQuizType = 'mcqReview';

class ReviewSessionNotifier extends StateNotifier<ReviewSessionState> {
  final Ref _ref;
  ReviewSessionNotifier(this._ref) : super(ReviewSessionState());

  Future<void> startSession({int limit = 30, String? subDomain}) async {
    final db = _ref.read(databaseProvider);
    final nativeLang = _ref.read(nativeLanguageProvider);
    final targetLang = _ref.read(currentLanguageProvider);

    // Review tab shows ALL planted words (mastery_level > 0), not just today's due.
    // Due/overdue words sort first automatically — the user naturally reviews the
    // most urgent cards but can keep going through their entire planted vocabulary.
    // FSRS scheduling continues working normally: answers in this tab update
    // next_review and stability exactly as they do in the Home tab.
    final sessionWords = await db.getSRSDueWords(
      nativeLang,
      targetLang,
      limit: limit,
      subDomain: subDomain,
      ignoreDueDate: true, // KEY: show all planted words, not only today's due
    );

    state = ReviewSessionState(
      words: sessionWords,
      currentIndex: 0,
      isCompleted: false,
      results: {},
    );
  }

  Future<void> submitRating(bool isCorrect, Duration responseTime, {String? selectedTranslation}) async {
    final word = state.currentWord;
    if (word == null) return;

    final db = _ref.read(databaseProvider);
    final nativeLang = _ref.read(nativeLanguageProvider);
    final targetLang = _ref.read(currentLanguageProvider);
    final responseMs = responseTime.inMilliseconds.clamp(0, 86400000);

    final wordId = word.id;
    if (wordId != null) {
      // 1. Calculate new FSRS state
      final updatedWord = FSRSService.instance.calculateReview(word, isCorrect, responseTime);

      // 2. Persist to DB
      await db.updateWordFSRS(updatedWord);

      // 3. Record confusion if applicable
      if (!isCorrect && selectedTranslation != null) {
        await db.recordConfusion(
          correctWordId: wordId,
          confusedTranslation: selectedTranslation,
          languageCode: nativeLang,
          targetLanguageCode: targetLang,
        );
      }

      // 4. Per-quiz analytics (parity with learning sessions)
      await db.recordQuizPerformance(
        wordId: wordId,
        quizType: reviewMcqQuizType,
        correct: isCorrect,
        responseMs: responseMs,
      );
    }

    // 5. Move to next word
    final newResults = Map<int, int>.from(state.results);
    if (wordId != null) {
      newResults[wordId] = isCorrect ? 3 : 1; // Good vs again
    }

    if (state.currentIndex >= state.words.length - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        isCompleted: true,
        results: newResults,
      );
      // Clear draft on completion
      _ref.read(usageServiceProvider).clearDraftSession();
    } else {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        results: newResults,
      );
      // Save draft for resumption
      _saveDraft();
    }
  }

  void _saveDraft() {
    _ref.read(usageServiceProvider).saveDraftSession(state);
  }

  Future<void> resumeSession(ReviewSessionState draft) async {
    state = draft;
  }

  void reset() {
    state = ReviewSessionState();
    _ref.read(usageServiceProvider).clearDraftSession();
  }
}

/// PROVIDER FOR GROUPED TOPICS
final reviewTopicsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final native = ref.watch(nativeLanguageProvider);
  final target = ref.watch(currentLanguageProvider);
  
  return await db.getReviewTopicGroups(native, target);
});
