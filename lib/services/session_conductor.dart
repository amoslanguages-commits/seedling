import 'dart:math' as math;
import '../models/word.dart';
import '../models/taxonomy.dart';
import '../database/database_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SESSION CONDUCTOR — Ultra-Smart Vocabulary Learning System (UVLS)
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │                    COMPLETE SESSION LEARNING ARC                         │
// │                                                                          │
// │  PHASE 1 — FIRST EVER SESSION (brand-new user or empty theme):           │
// │    • learning.dart detects isBrandNew → loads 3 words as initialNewWords │
// │    • SeedPlantingScreen runs first (user sees each word + plays TTS)     │
// │    • QuizManager.initState() injects all 3 via injectNewWord() bypass    │
// │    • _AdaptiveQueue runs Pimsleur 4-step intro on each in parallel       │
// │    • Steps interleave: A(0), B(0), C(0), A(1), B(1), C(1) ...           │
// │    • CLS gate is NOT consulted for initialNewWords                       │
// │    • After session: 3 words become review cards (mastery=1, FSRS=0)     │
// │                                                                          │
// │  PHASE 2 — REGULAR SESSION (has planted words):                          │
// │    • learning.dart loads up to 15 SRS-due review words + 1 new word     │
// │    • QuizManager interleaves reviews (shuffled) with the new word        │
// │    • CLS gate fires after each answer to possibly inject pendingNewWords │
// │    • New word plants ONLY when: CLS≥70 AND ≥3 turns since last plant    │
// │      AND no other new word drill is in progress                          │
// │    • Milestone quiz fires every 6th turn (buildTree, rootNetwork,        │
// │      memoryFlip) regardless of other conditions                          │
// │                                                                          │
// │  PIMSLEUR 4-STEP INTRO (for every new/relearn word):                    │
// │    Step 0 – Imprint    → growWord / picturePick   (see + hear it)        │
// │    Step 1 – Associate  → swipeNourish / bloomOrWilt (forced choice)     │
// │    Step 2 – Recall     → catchLeaf / seedSort    (active recognition)   │
// │    Step 3 – Produce    → deepRoot / engraveRoot  (active production)    │
// │    Gap schedule (correct + fast): 2 → 5 → 10 → 15 intervening cards    │
// │    Gap schedule (correct + slow): halved           (hesitation = shaky) │
// │    Gap schedule (wrong at step0): 5 cards (re-expose gently)            │
// │    Gap schedule (wrong at step1+): 1 card (near-immediate retry)        │
// │                                                                          │
// │  REVIEW QUIZ TIER SYSTEM (by FSRS stability band):                      │
// │    Tier 1  stability 0.0–3.0   → Imprint: gentle re-exposure            │
// │      bloomOrWilt, wordRain, swipeNourish, picturePick*, imageMatch*,    │
// │      growWord                                                            │
// │    Tier 2  stability 3.0–8.0   → Anchor: active recognition             │
// │      catchLeaf, deepRoot, seedSort, whatWordIsThis*, articleChallenge†  │
// │    Tier 3  stability 8.0–18.0  → Recall: active production              │
// │      gardenSort, engraveRoot, leafLetter, seedSort,                     │
// │      articleChallenge†, imageMatch*                                      │
// │    Tier 4  stability ≥18.0     → Automate: fluency / zero hints         │
// │      leafLetter, engraveRoot, gardenSort, memoryFlip                    │
// │    Milestone (every 6th turn) → buildTree, rootNetwork, memoryFlip      │
// │                                                                          │
// │    * requires word.imageId to be populated                               │
// │    † requires noun + word.hasTargetArticle                               │
// │    forestCloze: REMOVED (gate too restrictive, rarely triggered)         │
// │                                                                          │
// │  ROTATION: Within each tier, excludedTypes (recently used) are skipped  │
// │    first. When all types in a tier are excluded, picks ANY in the tier  │
// │    so the session never gets stuck. This guarantees every quiz type      │
// │    appears before any is repeated.                                       │
// └─────────────────────────────────────────────────────────────────────────┘
// ═══════════════════════════════════════════════════════════════════════════

/// Snapshot of the user's real-time mental state inside a session.
class SessionState {
  final int totalAnswered;
  final int totalCorrect;
  final int streak;
  final int reviewsDone;
  final int turnsSinceNewWord;
  final DateTime sessionStartTime;
  final List<bool> recentAnswers;
  final bool hasWiltedWord;

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
      score += 10;
    } else if (secsInSession >= 60) {
      score += 4;
    }

    // ── Micro-momentum: last answer was correct (5 pts) ───────────────────
    if (state.recentAnswers.isNotEmpty && state.recentAnswers.last) {
      score += 5;
    }

    // ── Recent struggle penalty (-15 pts) ─────────────────────────────────
    final recentWrong = state.recentAnswers.take(3).where((a) => !a).length;
    if (recentWrong >= 2) {
      score -= 15;
    }

    // ── Active re-learning penalty (-20 pts) ──────────────────────────────
    if (state.hasWiltedWord) {
      score -= 20;
    }

    // ── Candidate word difficulty (-10 to +10 pts) ───────────────────────
    if (candidateWord != null) {
      final difficultyFactor = 1.0 - (candidateWord.difficulty / 5.0);
      score += (difficultyFactor * 20) - 10;
    }

    // ── Small noise (prevents mechanical, predictable gating) ────────────
    score += (_rng.nextDouble() - 0.5) * 6;

    return score.clamp(0, 100);
  }

  // ── New Word Gate ─────────────────────────────────────────────────────────

  /// Returns true if conditions are right to introduce a new word now.
  ///
  /// This gate only applies to [pendingNewWords] (CLS-gated injection).
  /// Words passed via [initialNewWords] bypass this gate entirely and are
  /// injected immediately in QuizManager.initState().
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
    required bool slow,
    int queueLength = 10,
  }) {
    if (!correct) {
      return math.min(1, queueLength);
    }

    const baseGaps = [2, 5, 10, 15];
    final base = step < baseGaps.length ? baseGaps[step] : 15;
    final adjusted = slow ? math.max(1, (base * 0.5).round()) : base;

    return math.min(adjusted, queueLength);
  }

  // ── Smart New Word Selection ──────────────────────────────────────────────

  /// Selects the best next word to introduce.
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
      return await db.getNewWordToPlant(
        nativeLang,
        targetLang,
        categoryId: categoryId,
      );
    }
  }

  // ── Tier-Based Quiz Type Selection ───────────────────────────────────────
  //
  // Quiz type map (17 active types, forestCloze removed):
  //
  // NEW / RELEARN (Pimsleur 4-step intro):
  //   Step 0: growWord, picturePick*
  //   Step 1: swipeNourish, bloomOrWilt
  //   Step 2: catchLeaf, seedSort
  //   Step 3: deepRoot, engraveRoot
  //
  // REVIEW — Tier 1 (stability 0–3, Imprint):
  //   bloomOrWilt, wordRain, swipeNourish, picturePick*, imageMatch*, growWord
  //
  // REVIEW — Tier 2 (stability 3–8, Anchor):
  //   catchLeaf, deepRoot, seedSort, whatWordIsThis*, articleChallenge†
  //
  // REVIEW — Tier 3 (stability 8–18, Recall):
  //   gardenSort, engraveRoot, leafLetter, seedSort, articleChallenge†, imageMatch*
  //
  // REVIEW — Tier 4 (stability ≥18, Automate):
  //   leafLetter, engraveRoot, gardenSort, memoryFlip
  //
  // MILESTONE (every 6th turn):
  //   buildTree, rootNetwork, memoryFlip
  //
  // WEAKEST-TYPE fast path (dbWeakestType from IntelligenceService):
  //   Any non-forestCloze type, 65% chance, fires before tier selection

  String selectQuizType({
    required Word word,
    required int step,
    required bool isNewWord,
    required bool isRelearn,
    String? dbWeakestType,
    int turnCount = 0,
    math.Random? rng,
    List<String>? excludedTypes,
  }) {
    final r = rng ?? _rng;
    final hasImage = word.imageId != null && word.imageId!.isNotEmpty;
    final isNoun = word.primaryPOS == PartOfSpeech.noun;
    final hasArticle = word.hasTargetArticle;

    // ── Rotation helper ────────────────────────────────────────────────────
    // Prefers types not in excludedTypes (recently used for this word).
    // If all types are excluded (full rotation complete), resets and picks any —
    // so the session never gets stuck on a single type.
    String pickFrom(List<String> types) {
      if (types.isEmpty) return 'deepRoot';
      final fresh = types.where(
        (t) => !(excludedTypes?.contains(t) ?? false),
      ).toList();
      final pool = fresh.isNotEmpty ? fresh : types;
      return pool[r.nextInt(pool.length)];
    }

    // ── INTRO MODE: Pimsleur 4-step first introduction ─────────────────────
    // Applies to newly planted words AND words being re-learned after failure.
    // The 4 steps expose the word in progressively harder challenge formats,
    // interleaved with review cards via AdaptiveQueue Pimsleur gaps.
    if (isNewWord || isRelearn) {
      switch (step) {
        case 0:
          // Step 0 — Imprint: see and hear the word, passive recognition
          return pickFrom(['growWord', if (hasImage) 'picturePick']);
        case 1:
          // Step 1 — Associate: forced true/false choice to start engagement
          return pickFrom(['swipeNourish', 'bloomOrWilt']);
        case 2:
          // Step 2 — Recall: active recognition from multiple choices
          return pickFrom(['catchLeaf', 'seedSort']);
        default:
          // Step 3+ — Produce: translate without any native language prompt
          return pickFrom(['deepRoot', 'engraveRoot']);
      }
    }

    // ── MILESTONE: every 6th turn — multi-word consolidation ───────────────
    // Multi-word quizzes fire periodically regardless of stability tier.
    // buildTree: arrange words into a category tree
    // rootNetwork: connect related words in a network
    // memoryFlip: classic memory matching (FIX: was never triggered before)
    if (turnCount > 0 && turnCount % 6 == 0) {
      return pickFrom(['buildTree', 'rootNetwork', 'memoryFlip']);
    }

    // ── WEAKEST-TYPE FAST PATH ─────────────────────────────────────────────
    // IntelligenceService tracks per-word accuracy by quiz type.
    // If this word has a weak spot (e.g., always fails 'engraveRoot'),
    // prioritise that type with 65% probability to directly address the gap.
    if (dbWeakestType != null &&
        dbWeakestType != 'forestCloze' &&
        !(excludedTypes?.contains(dbWeakestType) ?? false)) {
      if (r.nextDouble() < 0.65) return dbWeakestType;
    }

    // ── STABILITY-TIER REVIEW SELECTION ────────────────────────────────────
    // As FSRS stability grows, quiz difficulty escalates automatically.
    // Each tier ensures ALL its quiz types appear before any is repeated,
    // creating maximum contextual variation for each word.
    final stability = word.fsrsStability;

    if (stability < 3.0) {
      // ── TIER 1: Imprint (stability 0–3) ──────────────────────────────────
      // The word is fragile — gentle recognition is most effective here.
      // Seeing it in varied formats strengthens the initial memory trace.
      return pickFrom([
        'bloomOrWilt',               // true/false — lowest cognitive load
        'wordRain',                  // visual multiple choice with animation
        'swipeNourish',              // swipe left/right kinesthetic response
        if (hasImage) 'picturePick', // image → word (passive)
        if (hasImage) 'imageMatch',  // match image to word from grid
        'growWord',                  // see + hear the word again (re-imprint)
      ]);
    }

    if (stability < 8.0) {
      // ── TIER 2: Anchor (stability 3–8) ───────────────────────────────────
      // The word is starting to stick. Active recognition challenges test
      // whether it can be retrieved with moderate contextual support.
      return pickFrom([
        'catchLeaf',                 // multiple choice with distractors
        'deepRoot',                  // native → target recall with context
        'seedSort',                  // drag words to correct positions
        if (hasImage) 'whatWordIsThis', // image → produce the word
        if (isNoun && hasArticle) 'articleChallenge', // test grammatical gender
      ]);
    }

    if (stability < 18.0) {
      // ── TIER 3: Recall (stability 8–18) ──────────────────────────────────
      // The word is consolidated. Production challenges (no hints) create
      // the strongest long-term memory traces via the Generation Effect.
      return pickFrom([
        'gardenSort',                // category sort with competing words
        'engraveRoot',               // fill-in-blanks / translate harder
        'leafLetter',                // spell it letter by letter
        'seedSort',                  // still valid at higher difficulty
        if (isNoun && hasArticle) 'articleChallenge',
        if (hasImage) 'imageMatch',  // image → word (now reverse direction)
      ]);
    }

    // ── TIER 4: Automate (stability ≥18) ─────────────────────────────────
    // The word is deeply encoded. Fluency drills test automatic retrieval
    // with zero scaffolding. memoryFlip adds a working-memory layer.
    return pickFrom([
      'leafLetter',                  // full spelling from memory
      'engraveRoot',                 // hardest translation recall
      'gardenSort',                  // fast recall under time pressure
      'memoryFlip',                  // memory matching (now active in Tier 4)
    ]);
  }
}
