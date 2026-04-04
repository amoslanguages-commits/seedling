import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../widgets/mascot.dart';
import '../widgets/progress.dart';
import '../widgets/buttons.dart';
import '../providers/app_providers.dart';
import '../widgets/quizzes.dart';
import '../widgets/seed_planting.dart';
import '../models/word.dart';
import '../services/auth_service.dart';
import '../services/sync_manager.dart';
import '../services/audio_service.dart';
import '../services/intelligence_service.dart';

// ================================================================
// SESSION FLOW (the correct SRS-based loop):
//
//  1. Load SRS-due words from the garden (already planted, mastery > 0)
//  2. If due words exist → QuizManager (varied quiz types, interleaved)
//  3. After quiz ends → SeedPlantingScreen (plant 1 new word from topic)
//     • For brand-new users with 0 planted words → plant 3 seeds first
//  4. After planting → return to home (or loop again next session)
//
// Memory science applied:
//  • SRS     → resurface words at optimal SM-2 intervals
//  • Active Recall → answer without seeing translation first
//  • Interleaving → QuizManager rotates 5 different quiz types
// ================================================================

enum _SessionPhase {
  loading,
  goalSelection, // New: choose commitment (5/10/15/Endless)
  noWordsYet, // fresh user: plant 3 seeds before any quiz
  quiz, // SRS review of due words
  done, // session complete
}

class LearningSessionScreen extends ConsumerStatefulWidget {
  /// Optional category filter (e.g., 'food', 'travel').
  final String? categoryId;

  /// Optional domain filter (Theme)
  final String? domain;

  /// Optional sub-domain filter (Sub-theme)
  final String? subDomain;

  /// Optional POS filter
  final String? partOfSpeech;

  /// Optional micro-category filter (Burst Mode deep dive)
  final String? microCategory;

  const LearningSessionScreen({
    super.key,
    this.categoryId,
    this.domain,
    this.subDomain,
    this.partOfSpeech,
    this.microCategory,
  });

  @override
  ConsumerState<LearningSessionScreen> createState() =>
      _LearningSessionScreenState();
}

class _LearningSessionScreenState extends ConsumerState<LearningSessionScreen> {
  _SessionPhase _phase = _SessionPhase.loading;
  List<Word> _dueWords = [];
  Word? _newWordToPlant;
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  int _cumulativeCorrect = 0;
  int _cumulativeTotal = 0;
  bool _isFirstSession = false;
  List<Word> _initialPlantedWords = [];
  int _batchIndex = 0;
  bool _isReplenishing = false;

  // Intelligence & Settings
  List<Map<String, dynamic>> _coverageGaps = []; // domain heatmap
  String? _activeSubDomain; // contextual word grouping
  DateTime? _sessionStartTime; // session length budget
  int _sessionBudgetMins = 10; // default 10 min goal
  bool _budgetReached = false;

  // Use a key to talk to the QuizManager for dynamic refills
  final GlobalKey<QuizManagerState> _quizKey = GlobalKey<QuizManagerState>();

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final db = ref.read(databaseProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);

    // ── Mastery Decay on Silence (runs silently on every session start) ──────
    final decayed = await IntelligenceService.instance
        .detectAndApplyMasteryDecay(db, nativeLang, targetLang);
    if (decayed > 0) {
      debugPrint(
        '[LearningSession] Mastery decay applied to $decayed fragile words',
      );
    }

    // ── Domain Coverage Heatmap (loaded once per session) ───────────────
    _coverageGaps = await db.getDomainCoverageGaps(nativeLang, targetLang);

    // Check if user has learned any words yet
    final totalLearned = await db.getTotalWordsLearned(targetLang);
    final isBrandNew = totalLearned == 0;

    final int wordsToFetch = isBrandNew ? 3 : 1;
    final List<Word> newWords = [];

    for (int i = 0; i < wordsToFetch; i++) {
      final w = await db.getNewWordToPlant(
        nativeLang,
        targetLang,
        categoryId: widget.categoryId,
        domain: widget.domain,
        subDomain: widget.subDomain,
        partOfSpeech: widget.partOfSpeech,
        microCategory: widget.microCategory,
      );
      if (w != null && !newWords.any((existing) => existing.id == w.id)) {
        newWords.add(w);
      } else {
        break;
      }
    }

    // ── Forgotten Curve Detection: load critically overdue words first ──────
    final forgottenWords = await db.getForgottenWords(
      nativeLang,
      targetLang,
      limit: 3,
    );

    final due = await db.getSRSDueWords(
      nativeLang,
      targetLang,
      limit: 15,
      categoryId: null,
      partOfSpeech: widget.partOfSpeech,
      microCategory: widget.microCategory,
    );

    // Merge forgotten words at the front (they are highest priority)
    final mergedDue = <Word>[
      ...forgottenWords,
      ...due.where((w) => !forgottenWords.any((f) => f.id == w.id)),
    ];

    // Derive active sub-domain from the loaded words for contextual grouping
    _activeSubDomain = IntelligenceService.instance.getDominantSubDomain(
      mergedDue,
    );

    if (!mounted) return;

    setState(() {
      _dueWords = mergedDue;
      _newWordToPlant = isBrandNew
          ? null
          : (newWords.isNotEmpty ? newWords.first : null);
      _initialPlantedWords = isBrandNew ? newWords : [];
      _isFirstSession = isBrandNew;

      if (isBrandNew && _initialPlantedWords.isNotEmpty) {
        _phase = _SessionPhase.noWordsYet;
      } else if (mergedDue.isEmpty && _newWordToPlant == null) {
        _forceEndSession();
      } else {
        // First, choose the goal/budget for this session
        _phase = _SessionPhase.goalSelection;
        AudioService.instance.startAmbient();
      }
    });
  }

  /// Called by QuizManager when it runs out of cards.
  /// Fetches more content smartly (context + coverage bias) and injects.
  Future<void> _handleQueueDepleted() async {
    if (_isReplenishing || _budgetReached) return;

    // Check if budget is reached (If budget is -1, it's infinite)
    if (_sessionBudgetMins > 0 && _sessionStartTime != null) {
      final elapsed = DateTime.now().difference(_sessionStartTime!).inMinutes;
      if (elapsed >= _sessionBudgetMins) {
        debugPrint(
          '[LearningSession] Session goal reached ($elapsed / $_sessionBudgetMins mins). Stopping replenishment.',
        );
        setState(() => _budgetReached = true);
        return;
      }
    }

    _isReplenishing = true;

    debugPrint('[LearningSessionScreen] Replenishing session...');

    final db = ref.read(databaseProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);

    // 1. Smart new word: biased by active sub-domain + coverage gaps
    final nextNewWord = await db.getSmartNewWord(
      nativeLang,
      targetLang,
      categoryId: widget.categoryId,
      domain: widget.domain,
      subDomain: widget.subDomain,
      partOfSpeech: widget.partOfSpeech,
      microCategory: widget.microCategory,
      activeSubDomain: _activeSubDomain,
      coverageGaps: _coverageGaps,
    );

    // 2. More due reviews
    final moreDue = await db.getSRSDueWords(
      nativeLang,
      targetLang,
      limit: 10,
      categoryId: null,
      partOfSpeech: widget.partOfSpeech,
      microCategory: widget.microCategory,
    );

    if (nextNewWord == null && moreDue.isEmpty) {
      _isReplenishing = false;
      _forceEndSession();
      return;
    }

    // Update contextual sub-domain for next replenishment
    if (nextNewWord?.subDomain != null) {
      _activeSubDomain = nextNewWord!.subDomain;
    }

    // 3. Inject into the existing quiz state
    _quizKey.currentState?.replenish(
      moreReviews: moreDue,
      nextNewWord: nextNewWord,
    );

    setState(() {
      _batchIndex++;
      _isReplenishing = false;
    });
  }

  // Called continuously by QuizManager
  void _onProgressUpdate(int correct, int total) {
    if (mounted) {
      setState(() {
        _correctAnswers = correct;
        _totalQuestions = total;
      });
    }
  }

  // Called when the user clicks the exit/close button or session ends naturally
  Future<void> _forceEndSession() async {
    // 🌿 Fade out ambient when session ends
    AudioService.instance.stopAmbient();

    final db = ref.read(databaseProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final userId = AuthService().userId ?? 'guest';

    // Calculate session duration
    int durationMins = 0;
    if (_sessionStartTime != null) {
      durationMins = DateTime.now().difference(_sessionStartTime!).inMinutes;
    }

    final totalCorrect = _cumulativeCorrect + _correctAnswers;
    final totalQs = _cumulativeTotal + _totalQuestions;
    final xpGained = totalCorrect * 10;

    // Save session locally
    if (totalQs > 0) {
      await db.saveStudySession({
        'user_id': userId,
        'language_code': targetLang,
        'session_date': DateTime.now().toIso8601String(),
        'words_studied': totalQs,
        'correct_answers': totalCorrect,
        'duration_minutes': durationMins,
        'xp_gained': xpGained,
      });

      // Trigger background sync to Supabase for "real data" in social/competitions
      SyncManager().syncToCloud().ignore();
    }

    setState(() {
      _phase = _SessionPhase.done;
    });
  }

  // Called when initial 3-word SeedPlantingScreen finishes planting
  void _onInitialPlantingComplete() {
    if (_isFirstSession) {
      if (_initialPlantedWords.isEmpty) {
        // Fallback
        _loadSession();
      } else {
        // Go straight to quiz. The 3 planted words are treated as active new words!
        setState(() {
          _dueWords = []; // They are not due review words, they are brand new.
          _newWordToPlant = null;
          _isFirstSession = false;
          _phase = _SessionPhase.quiz;
          _batchIndex++;
        });
      }
    }
  }

  // Called when QuizManager finishes a batch. We reload to optionally play indefinitely.
  Future<void> _handleBatchComplete() async {
    _cumulativeCorrect += _correctAnswers;
    _cumulativeTotal += _totalQuestions;
    _correctAnswers = 0;
    _totalQuestions = 0;

    setState(() {
      _phase = _SessionPhase.loading;
      _batchIndex++;
    });
    await _loadSession();
  }

  Future<void> _markPlanted(Word word) async {
    if (word.id == null) return;
    final db = ref.read(databaseProvider);
    await db.markWordAsPlanted(word.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      // ── Loading ────────────────────────────────────────────────
      case _SessionPhase.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: SeedlingColors.seedlingGreen,
              ),
              const SizedBox(height: 16),
              Text(
                'Preparing your garden...',
                style: SeedlingTypography.caption,
              ),
            ],
          ),
        );

      // ── New: Goal Selection ────────────────────────────────────
      case _SessionPhase.goalSelection:
        return _buildGoalSelection();

      // ── First session: plant 3 seeds before quizzing ──────────
      case _SessionPhase.noWordsYet:
        return _buildFirstSessionPlanting();

      // ── SRS Quiz phase ─────────────────────────────────────────
      case _SessionPhase.quiz:
        return _buildQuizPhase();

      // ── Session done ───────────────────────────────────────────
      case _SessionPhase.done:
        return SessionSummaryScreen(
          correctAnswers: _cumulativeCorrect + _correctAnswers,
          totalQuestions: _cumulativeTotal + _totalQuestions,
          isEmbedded: true,
        );
    }
  }

  Widget _buildGoalSelection() {
    // Note: 'FadeInUp' or similar animations can be added if available,
    // or just use standard Flutter animations.
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 60,
                color: SeedlingColors.seedlingGreen,
              ),
              const SizedBox(height: 24),
              Text(
                'Nurture Your Intent',
                style: SeedlingTypography.heading1.copyWith(
                  color: SeedlingColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'How deeply do you want to grow today?',
                textAlign: TextAlign.center,
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              _buildGoalItem(
                title: '5 Min Micro-Nurture',
                subtitle: 'A quick burst for focus',
                mins: 5,
                icon: Icons.bolt,
              ),
              const SizedBox(height: 16),
              _buildGoalItem(
                title: '10 Min Daily Habit',
                subtitle: 'The golden ratio for growth',
                mins: 10,
                icon: Icons.spa,
                isRecommended: true,
              ),
              const SizedBox(height: 16),
              _buildGoalItem(
                title: '15 Min Deep Roots',
                subtitle: 'Maximum impact session',
                mins: 15,
                icon: Icons.park,
              ),
              const SizedBox(height: 16),
              _buildGoalItem(
                title: 'Endless Garden',
                subtitle: 'Learn until you are satisfied',
                mins: -1,
                icon: Icons.all_inclusive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalItem({
    required String title,
    required String subtitle,
    required int mins,
    required IconData icon,
    bool isRecommended = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _sessionBudgetMins = mins;
            _sessionStartTime = DateTime.now();
            _phase = _SessionPhase.quiz;
          });
          AudioService.haptic(HapticType.tap);
          AudioService.instance.play(SFX.buttonTap);
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isRecommended
                ? SeedlingColors.seedlingGreen
                : SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isRecommended
                  ? Colors.transparent
                  : SeedlingColors.cardBackground.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: isRecommended
                ? [
                    BoxShadow(
                      color: SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.25,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isRecommended
                      ? Colors.white.withValues(alpha: 0.2)
                      : SeedlingColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isRecommended
                      ? Colors.white
                      : SeedlingColors.seedlingGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SeedlingTypography.heading3.copyWith(
                        color: isRecommended
                            ? Colors.white
                            : SeedlingColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: SeedlingTypography.caption.copyWith(
                        color: isRecommended
                            ? Colors.white.withValues(alpha: 0.8)
                            : SeedlingColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'GOLDEN',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.seedlingGreen,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── First-session: plant 3 words (no quiz yet) ─────────────────────────

  Widget _buildFirstSessionPlanting() {
    if (_initialPlantedWords.isEmpty) {
      return _buildEmptyGarden();
    }

    return SeedPlantingScreen(
      words: _initialPlantedWords,
      initialBatchSize: _initialPlantedWords.length,
      onWordPlanted: _markPlanted,
      onPlantingComplete: _onInitialPlantingComplete,
    );
  }

  Widget _buildEmptyGarden() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SeedlingMascot(size: 100, state: MascotState.idle),
            const SizedBox(height: 24),
            Text(
              'Your garden is empty!',
              style: SeedlingTypography.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a language course to start planting words.',
              style: SeedlingTypography.body.copyWith(
                color: SeedlingColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OrganicButton(
              text: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ── SRS Quiz ─────────────────────────────────────────────────────────────

  Future<void> _handleWordAnswered(Word word, bool correct) async {
    if (word.id == null) return;
    final db = ref.read(databaseProvider);
    await db.updateWordMastery(word.id!, correct);
  }

  Widget _buildQuizPhase() {
    final totalWords = _dueWords.length + (_newWordToPlant != null ? 1 : 0);
    final progress = _totalQuestions > 0
        ? (_correctAnswers / _totalQuestions).clamp(0.0, 1.0)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall =
            constraints.maxWidth < 360 || constraints.maxHeight < 620;
        final isVerySmall = constraints.maxWidth < 330;

        return Column(
          children: [
            _buildSessionHeader(
              'Daily Review',
              totalWords,
              isSmall,
              isVerySmall,
              progress,
            ),
            Expanded(
              child: QuizManager(
                key: _quizKey,
                words: _dueWords,
                initialNewWords: _batchIndex == 0
                    ? _initialPlantedWords
                    : const [],
                newWordToPlant: _newWordToPlant,
                onWordPlanted: _markPlanted,
                onWordAnswered: _handleWordAnswered,
                onProgressUpdate: _onProgressUpdate,
                onSessionComplete: _handleBatchComplete,
                onQueueDepleted: _handleQueueDepleted,
                db: ref.read(databaseProvider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSessionHeader(
    String title,
    int wordCount,
    bool isSmall,
    bool isVerySmall,
    double progress,
  ) {
    final horizontalPadding = isVerySmall ? 6.0 : (isSmall ? 10.0 : 16.0);
    final mascotSize = isVerySmall ? 32.0 : (isSmall ? 40.0 : 52.0);
    final showPronunciation = ref.watch(showPronunciationProvider);

    // Calculate remaining time for the goal display
    String goalText = '';
    if (_sessionBudgetMins > 0 && _sessionStartTime != null) {
      final elapsed = DateTime.now().difference(_sessionStartTime!).inMinutes;
      final remaining = (_sessionBudgetMins - elapsed).clamp(
        0,
        _sessionBudgetMins,
      );
      goalText = _budgetReached ? 'Goal reached! ✨' : '$remaining mins left';
    } else if (_sessionBudgetMins < 0) {
      goalText = 'Endless Mode ♾️';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: SeedlingColors.textSecondary),
            onPressed: () {
              if (_phase == _SessionPhase.quiz) {
                _forceEndSession();
              } else {
                Navigator.of(context).pop();
              }
            },
            padding: isSmall ? EdgeInsets.zero : const EdgeInsets.all(8),
            constraints: isSmall ? const BoxConstraints() : null,
          ),
          if (isSmall) const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.textSecondary,
                    fontSize: isSmall ? 10 : 12,
                  ),
                ),
                if (goalText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      goalText,
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.seedlingGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: isSmall ? 9 : 11,
                      ),
                    ),
                  ),
                StemProgressBar(
                  progress: progress,
                  height: isSmall ? 5 : 7,
                  showLeaves:
                      !isSmall, // Hide leaves on progress bar if very small to save space
                ),
              ],
            ),
          ),
          SizedBox(width: isVerySmall ? 4 : 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isVerySmall ? 6 : (isSmall ? 8 : 12),
              vertical: isVerySmall ? 3 : (isSmall ? 4 : 6),
            ),
            decoration: BoxDecoration(
              color: SeedlingColors.seedlingGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(isSmall ? 10 : 14),
              border: Border.all(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '$wordCount words',
              style: SeedlingTypography.caption.copyWith(
                color: SeedlingColors.seedlingGreen,
                fontWeight: FontWeight.w600,
                fontSize: isSmall ? 10 : 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Pronunciation Toggle
          IconButton(
            onPressed: () {
              ref
                  .read(showPronunciationProvider.notifier)
                  .update((state) => !state);
              AudioService.haptic(HapticType.tap).ignore();
            },
            icon: Icon(
              showPronunciation
                  ? Icons.record_voice_over
                  : Icons.voice_over_off,
              color: showPronunciation
                  ? SeedlingColors.seedlingGreen
                  : SeedlingColors.textSecondary.withValues(alpha: 0.6),
              size: isSmall ? 20 : 24,
            ),
            tooltip: 'Toggle Pronunciation',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: isSmall ? 8 : 12),
          SeedlingMascot(size: mascotSize, state: MascotState.idle),
        ],
      ),
    );
  }
}

// ================================================================
// SeedPlantingScreen now accepts initialBatchSize and per-word callback
// ================================================================
// (Signature widget is updated in seed_planting.dart to support these params)

// ================================================================
// SESSION SUMMARY SCREEN
// ================================================================

class SessionSummaryScreen extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;

  /// When embedded inside LearningSessionScreen, we pop instead of pushReplacement.
  final bool isEmbedded;

  const SessionSummaryScreen({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final accuracy = totalQuestions > 0
        ? (correctAnswers / totalQuestions * 100).toInt()
        : 100;
    final xp = correctAnswers * 10;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SeedlingMascot(size: 130, state: MascotState.celebrating),
              const SizedBox(height: 28),
              Text(
                accuracy >= 80
                    ? 'Excellent Growth! 🌻'
                    : accuracy >= 50
                    ? 'Good Progress! 🌱'
                    : 'Keep Nurturing! 🌿',
                style: SeedlingTypography.heading1.copyWith(fontSize: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your roots are getting stronger.',
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // Stats row
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.1,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(
                      'Accuracy',
                      '$accuracy%',
                      SeedlingColors.seedlingGreen,
                    ),
                    _stat('Correct', '$correctAnswers', SeedlingColors.success),
                    _stat('XP', '+$xp', SeedlingColors.sunlight),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // SRS reminder
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: SeedlingColors.morningDew.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'These words will return at the perfect interval to lock them into long-term memory.',
                        style: SeedlingTypography.caption.copyWith(
                          color: SeedlingColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),
              OrganicButton(
                text: 'Back to Garden',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: SeedlingTypography.heading2.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(label, style: SeedlingTypography.caption),
      ],
    );
  }
}
