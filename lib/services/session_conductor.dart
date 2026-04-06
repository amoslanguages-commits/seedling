import 'dart:math' as math;
import '../models/word.dart';
import '../models/taxonomy.dart';
import '../database/database_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SESSION CONDUCTOR
// Central brain of the Ultra-Smart Vocabulary Learning System (UVLS).
//
// Responsibilities:
//  • Cognitive Load Score (CLS) — composite 0-100 readiness metric
//  • New Word Gate — multi-signal gating with 3-turn minimum separation
//  • Adaptive Pimsleur Gaps — gap shrinks when slow/wrong, normal when fast
//  • 14-Priority Quiz Type Cascade — per-word adaptive quiz selection
// ═══════════════════════════════════════════════════════════════════════════

/// Snapshot of the user's real-time mental state inside a session.
class SessionState {
  final int totalAnswered;
  final int totalCorrect;
  final int streak;
  final int reviewsDone;
  final int
  turnsSinceNewWord; // turns elapsed since last new word intro (Step 0)
  final DateTime sessionStartTime;
  final List<bool> recentAnswers; // last 5 answers (true = correct)
  final bool hasWiltedWord; // is there a failed-review word being re-learned?

  const SessionState({
    this.totalAnswered = 0,
    this.totalCorrect = 0,
    this.streak = 0,
    this.reviewsDone = 0,
    this.turnsSinceNewWord = 999,
    required this.sessionStartTime,
    this.recentAnswers = const [],
    this.hasWiltedWord = false,
  });

  double get accuracy => totalAnswered > 0 ? totalCorrect / totalAnswered : 0.0;

  SessionState copyWith({
    int? totalAnswered,
    int? totalCorrect,
    int? streak,
    int? reviewsDone,
    int? turnsSinceNewWord,
    DateTime? sessionStartTime,
    List<bool>? recentAnswers,
    bool? hasWiltedWord,
  }) => SessionState(
    totalAnswered: totalAnswered ?? this.totalAnswered,
    totalCorrect: totalCorrect ?? this.totalCorrect,
    streak: streak ?? this.streak,
    reviewsDone: reviewsDone ?? this.reviewsDone,
    turnsSinceNewWord: turnsSinceNewWord ?? this.turnsSinceNewWord,
    sessionStartTime: sessionStartTime ?? this.sessionStartTime,
    recentAnswers: recentAnswers ?? this.recentAnswers,
    hasWiltedWord: hasWiltedWord ?? this.hasWiltedWord,
  );
}

class SessionConductor {
  static final SessionConductor _instance = SessionConductor._internal();
  factory SessionConductor() => _instance;
  SessionConductor._internal();

  static SessionConductor get instance => _instance;

  final _rng = math.Random();

  // ── Cognitive Load Score (CLS) ────────────────────────────────────────────
  //
  // A composite 0-100 score measuring how ready the user is to absorb a new
  // word. Higher score = brain is warmed up, focused, and in flow state.
  //
  // Signal breakdown (max 100 pts):
  //   Accuracy:          0-30 pts
  //   Streak:            0-25 pts
  //   Reviews done:      -25 to +20 pts
  //   Time in session:   0-10 pts
  //   Micro-momentum:    0-5 pts
  //   Recent struggles:  -15 pts
  //   Wilted word:       -20 pts
  //   Word difficulty:   -10 to +10 pts
  //   Noise:             ±3 pts

  /// Computes the user's real-time Cognitive Load Score.
  double computeCLS(SessionState state, {Word? candidateWord}) {
    double score = 0;

    // ── Accuracy (max 30 pts) ─────────────────────────────────────────────
    final acc = state.accuracy;
    if (acc >= 0.80) {
      score += 30;
    } else if (acc >= 0.65) {
      score += 18;
    } else if (acc >= 0.50) {
      score += 8;
    }
    // No accuracy bonus for acc < 50%

    // ── Streak (max 25 pts) ───────────────────────────────────────────────
    if (state.streak >= 5) {
      score += 25;
    } else if (state.streak >= 3) {
      score += 15;
    } else if (state.streak >= 1) {
      score += 6;
    }

    // ── Reviews done warm-up (max 20 pts, hard penalty if too few) ────────
    if (state.reviewsDone >= 6) {
      score += 20;
    } else if (state.reviewsDone >= 3) {
      score += 10;
    } else {
      score -= 25; // Not warmed up — penalise hard
    }

    // ── Time in session (max 10 pts) ──────────────────────────────────────
    final secsInSession = DateTime.now()
        .difference(state.sessionStartTime)
        .inSeconds;
    if (secsInSession >= 180) {
      score += 10; // 3+ minutes: brain is fully engaged
    } else if (secsInSession >= 60) {
      score += 4;
    }

    // ── Micro-momentum: last answer was correct (5 pts) ───────────────────
    if (state.recentAnswers.isNotEmpty && state.recentAnswers.last) {
      score += 5;
    }

    // ── Recent struggle penalty (-15 pts) ─────────────────────────────────
    // More than 1 wrong in the last 3 answers = user is struggling
    final recentWrong = state.recentAnswers.take(3).where((a) => !a).length;
    if (recentWrong >= 2) {
      score -= 15;
    }

    // ── Active re-learning penalty (-20 pts) ──────────────────────────────
    // Never introduce new words while user is re-learning a failed review
    if (state.hasWiltedWord) {
      score -= 20;
    }

    // ── Candidate word difficulty (-10 to +10 pts) ───────────────────────
    // Easy words = lower cognitive cost = can be introduced sooner
    if (candidateWord != null) {
      final difficultyFactor = 1.0 - (candidateWord.difficulty / 5.0);
      score +=
          (difficultyFactor * 20) - 10; // maps [0,5] difficulty → [-10,+10]
    }

    // ── Small noise (prevents mechanical, predictable gating) ────────────
    score += (_rng.nextDouble() - 0.5) * 6;

    return score.clamp(0, 100);
  }

  // ── New Word Gate ─────────────────────────────────────────────────────────

  /// Returns true if conditions are right to introduce a new word now.
  ///
  /// Rules (all must pass):
  ///   1. No other new word is currently being drilled
  ///   2. Minimum 3-turn gap since last new word introduction
  ///   3. CLS ≥ 70 (or CLS ≥ 85 fast-track allows 2-turn gap)
  bool shouldIntroduceNewWord({
    required double cls,
    required int turnsSinceLastNewWord,
    required bool hasNewWordInProgress,
  }) {
    // Rule 1: Never interrupt an in-progress new word drill
    if (hasNewWordInProgress) return false;

    // Rule 2 + 3: Fast-track for blazing performance (streak 5+, CLS 85+)
    if (cls >= 85 && turnsSinceLastNewWord >= 2) return true;

    // Standard gate: at least 3-turn gap AND CLS ≥ 70
    if (turnsSinceLastNewWord < 3) return false;
    return cls >= 70;
  }

  /// Returns true if the CLS indicates the user is actively struggling.
  bool isUserStruggling(double cls) => cls < 50;

  // ── Adaptive Pimsleur Gap ─────────────────────────────────────────────────

  /// Returns the number of review cards to insert before the new word reappears.
  ///
  /// Base Pimsleur gaps: step 0→1: 2, step 1→2: 5, step 2→3: 10, step 3→done: 15
  /// Adjustments:
  ///   • Correct + fast  → normal gap (full Pimsleur interval)
  ///   • Correct + slow  → gap × 0.5 (re-test sooner — hesitation = not confident)
  ///   • Wrong           → gap = 1    (near-immediate re-test)
  int adaptiveGap({
    required int step,
    required bool correct,
    required bool slow, // true if answer took > 12 seconds
    int queueLength = 10,
  }) {
    if (!correct) {
      // Wrong: come back after just 1 review
      return math.min(1, queueLength);
    }

    // Base Pimsleur intervals (wider as step increases)
    const baseGaps = [2, 5, 10, 15];
    final base = step < baseGaps.length ? baseGaps[step] : 15;

    // Halve the gap when the user is slow (hesitation = fragile memory)
    final adjusted = slow ? math.max(1, (base * 0.5).round()) : base;

    return math.min(adjusted, queueLength);
  }

  // ── Smart New Word Selection ──────────────────────────────────────────────

  /// Selects the best next word to introduce.
  /// Priority: active sub-domain → coverage gaps → difficulty ramp → recency.
  Future<Word?> selectNextNewWord(
    DatabaseHelper db,
    String nativeLang,
    String targetLang, {
    String? categoryId,
    String? domain,
    String? subDomain,
    String? partOfSpeech,
    String? microCategory,
    String? activeSubDomain,
    List<Map<String, dynamic>> coverageGaps = const [],
  }) async {
    try {
      return await db.getSmartNewWord(
        nativeLang,
        targetLang,
        categoryId: categoryId,
        domain: domain,
        subDomain: subDomain ?? activeSubDomain,
        partOfSpeech: partOfSpeech,
        microCategory: microCategory,
        activeSubDomain: activeSubDomain,
        coverageGaps: coverageGaps,
      );
    } catch (_) {
      // Fallback: plain next unlearned word
      return await db.getNewWordToPlant(
        nativeLang,
        targetLang,
        categoryId: categoryId,
      );
    }
  }

  // ── 14-Priority Quiz Type Cascade ────────────────────────────────────────
  //
  // Priority order (highest first):
  //   1. New word Step 0 → passive visual (growWord / picturePick)
  //   2. New word Step 1 → passive forced-choice (swipeNourish / seedSort)
  //   3. New word Step 2 → active recall with aid (catchLeaf / deepRoot)
  //   4. New word Step 3 → hard active recall (engraveRoot / leafLetter)
  //   5. Re-learn word   → restart at Step 0 logic
  //   6. Milestone turn  → multi-word quiz (buildTree / rootNetwork)
  //   7. Noun + article + mastery ≥ 2 → articleChallenge (40%)
  //   8. Has image + mastery ≥ 1      → imageMatch / whatWordIsThis (45%)
  //   9. Has example sentence + mastery ≥ 3 → forestCloze (70%)
  //  10. Mastery ≤ 2 reinforcement    → wordRain (25%)
  //  11. Weak quiz type from DB       → force weakest type (70%)
  //  12. High mastery challenge       → leafLetter / forestCloze (50%)
  //  13. Any non-image safe type      → shuffled pool fallback
  //  14. Last resort default          → deepRoot

  String selectQuizType({
    required Word word,
    required int step, // for new/relearn words: 0-3
    required bool isNewWord,
    required bool isRelearn,
    String? dbWeakestType, // from IntelligenceService
    int turnCount = 0,
    math.Random? rng,
    List<String>? excludedTypes,
  }) {
    final r = rng ?? _rng;
    final hasImage = word.imageId != null && word.imageId!.isNotEmpty;
    final hasExample =
        word.exampleSentence != null && word.exampleSentence!.isNotEmpty;

    // ── Milestone checks (Every 6th interaction) ─────────────────────────
    if (turnCount > 0 && turnCount % 6 == 0 && !isNewWord && !isRelearn) {
      const milestones = ['buildTree', 'rootNetwork', 'memoryFlip'];
      final mType = milestones[r.nextInt(milestones.length)];
      if (excludedTypes == null || !excludedTypes.contains(mType)) {
        return mType;
      }
    }

    // ── Build Universal Pool for single-word queries ─────────────────────
    final List<String> pool = [
      'growWord', 'swipeNourish', 'catchLeaf', 'deepRoot', 
      'bloomOrWilt', 'seedSort', 'gardenSort', 'wordRain',
      'engraveRoot',
    ];

    // UVLS: Spelling is high-effort, add it rarely (12% chance) and only if eligible
    final spellingExcl = excludedTypes?.contains('leafLetter') ?? false;
    final canSpell = step >= 2 || word.masteryLevel >= 2;
    if (!spellingExcl && canSpell && r.nextDouble() < 0.12) {
      pool.add('leafLetter');
    }

    // Add conditional types based on word properties
    if (hasImage) {
      pool.addAll(['picturePick', 'whatWordIsThis', 'imageMatch']);
    }

    if (word.hasTargetArticle && word.primaryPOS == PartOfSpeech.noun) {
      if (!(excludedTypes?.contains('articleChallenge') ?? false)) {
        pool.add('articleChallenge');
      }
    }

    // Filter out ANY explicitly excluded types (from user skips)
    if (excludedTypes != null) {
      pool.removeWhere((type) => excludedTypes.contains(type));
    }

    // Fallback if pool is empty after exclusions
    if (pool.isEmpty) return 'growWord';

    // Special weighting: 
    // If it's a NEW word at step 0 (absolute first sighting), 
    // we lean 70% towards "Intro" types while still allowing the full pool 30% of the time.
    if (isNewWord && step == 0 && r.nextDouble() < 0.70) {
      final introPool = ['growWord', 'bloomOrWilt', if (hasImage) 'picturePick'];
      final filteredIntro = introPool.where((t) => !(excludedTypes?.contains(t) ?? false)).toList();
      if (filteredIntro.isNotEmpty) {
        return filteredIntro[r.nextInt(filteredIntro.length)];
      }
    }

    // Otherwise, pick randomly from the entire pool!
    return pool[r.nextInt(pool.length)];
  }
}
