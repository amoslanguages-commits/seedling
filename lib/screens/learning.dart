import 'package:flutter/material.dart';
import 'dart:math' as math;
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
import '../services/usage_service.dart';
import '../widgets/premium_gate.dart';
import '../database/database_helper.dart';
import '../widgets/readiness_hud.dart';
import '../services/fsrs_service.dart';

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
  List<Word> _pendingNewWords = [];
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  int _cumulativeCorrect = 0;
  int _cumulativeTotal = 0;
  bool _isFirstSession = false;
  List<Word> _initialPlantedWords = [];
  int _batchIndex = 0;
  bool _isReplenishing = false;
  bool _isLimitReached = false;

  // Intelligence & Settings
  List<Map<String, dynamic>> _coverageGaps = []; // domain heatmap
  String? _activeSubDomain; // contextual word grouping
  DateTime? _sessionStartTime; // session length budget
  int _sessionBudgetMins = 10; // default 10 min goal
  bool _budgetReached = false;

  // Thematic Progress Tracking
  int _themeLearnedCount = 0;
  int _themeTotalCount = 0;
  bool _isIsolatedSession = false;

  // Use a key to talk to the QuizManager for dynamic refills
  final GlobalKey<QuizManagerState> _quizKey = GlobalKey<QuizManagerState>();

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
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

      // ── Sub-theme Isolation Logic ───────────────────────────────────
      _isIsolatedSession = widget.subDomain != null && widget.subDomain!.isNotEmpty;
      
      final int totalLearnedOverall = await db.getTotalWordsLearned(targetLang);
      _themeLearnedCount = await db.getTotalWordsLearned(
        targetLang,
        subDomain: widget.subDomain,
      );
      _themeTotalCount = _isIsolatedSession
          ? await db.getTotalWordsInSubDomain(targetLang, widget.subDomain!)
          : 0;

      // If in an isolated theme session, we treat it as brand new if the theme is empty
      final isBrandNew = _isIsolatedSession ? (_themeLearnedCount == 0) : (totalLearnedOverall == 0);

      final bool canPlant = await UsageService().canPlantWord();
      final int wordsToFetch = isBrandNew ? 3 : (canPlant ? 1 : 0);
      final List<Word> newWords = [];
      bool limitReached = false;

      if (wordsToFetch > 0) {
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
      } else if (!isBrandNew) {
        // Check if there WOULD have been a word to plant
        final possibleWord = await db.getNewWordToPlant(
          nativeLang,
          targetLang,
          categoryId: widget.categoryId,
        );
        if (possibleWord != null) {
          limitReached = true;
        }
      }

      // ── Forgotten Curve Detection: load critically overdue words first ──────
      final forgottenWords = await db.getForgottenWords(
        nativeLang,
        targetLang,
        limit: 3,
        subDomain: widget.subDomain, // Strict theme filter
      );

      final due = await db.getSRSDueWords(
        nativeLang,
        targetLang,
        limit: 15,
        categoryId: widget.categoryId, // Ensure category matches if provided
        subDomain: widget.subDomain, // Strict theme filter
        partOfSpeech: widget.partOfSpeech,
        microCategory: widget.microCategory,
      );

      // ── SILE: Cross-Subtheme Reviews (Disabled for isolated sessions) ──────
      final List<Word> crossReviews = _isIsolatedSession
          ? []
          : await db.getCrossSubthemeReviews(
              nativeLang,
              targetLang,
              limit: 5, // up to 5 interleaves
              excludeSubDomain: widget.subDomain ?? _activeSubDomain,
            );

      // Merge forgotten, theme due, and cross-subtheme (shuffle cross reviews)
      final mergedDue = <Word>[
        ...forgottenWords,
        ...due.where((w) => !forgottenWords.any((f) => f.id == w.id)),
        ...crossReviews,
      ];
      // We could shuffle mergedDue slightly, but QuizManager _AdaptiveQueue will shuffle anyway.

      // ── SILE: Fetch additional new word candidates for pending queue ──────────
      if (!isBrandNew && canPlant && newWords.isNotEmpty) {
        final moreCandidates = await db.getSmartNewWordCandidates(
          nativeLang,
          targetLang,
          limit: 2,
          categoryId: widget.categoryId,
          domain: widget.domain,
          subDomain: widget.subDomain,
          activeSubDomain: _activeSubDomain,
          coverageGaps: _coverageGaps,
        );
        for (final mw in moreCandidates) {
          if (!newWords.any((w) => w.id == mw.id)) {
            newWords.add(mw);
          }
        }
      }

      // Derive active sub-domain from the loaded words for contextual grouping
      _activeSubDomain = IntelligenceService.instance.getDominantSubDomain(
        mergedDue,
      );

      if (!mounted) return;

      setState(() {
        _dueWords = mergedDue;
        _pendingNewWords = isBrandNew ? [] : newWords;
        _initialPlantedWords = isBrandNew ? newWords : [];
        _isFirstSession = isBrandNew;
        _isLimitReached = limitReached;

        if (isBrandNew && _initialPlantedWords.isNotEmpty) {
          _phase = _SessionPhase.noWordsYet;
        } else if (mergedDue.isEmpty && _pendingNewWords.isEmpty) {
          // If we have no more reviews AND we can't plant new words, end session
          if (_isLimitReached) {
            _showPremiumForPlanting();
          } else {
            _forceEndSession();
          }
        } else {
          // First, choose the goal/budget for this session
          _phase = _SessionPhase.goalSelection;
          AudioService.instance.startAmbient();
        }
      });
    } catch (e, stack) {
      debugPrint('[LearningSession] FATAL: Failed to load session: $e\n$stack');
      if (mounted) {
        setState(() {
          _phase = _SessionPhase.goalSelection; // Transition anyway to allow UI to recover
        });
      }
    }
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
        _forceEndSession();
        return;
      }
    }

    _isReplenishing = true;

    try {
      debugPrint('[LearningSessionScreen] Replenishing session...');

      final db = ref.read(databaseProvider);
      final targetLang = ref.read(currentLanguageProvider);
      final nativeLang = ref.read(nativeLanguageProvider);

      // Get existing IDs to avoid duplicates
      final existingIds = _quizKey.currentState?.allWordIds ?? [];

      // 1. SILE: Intelligent candidate fetching (with timeout)
      final results = await Future.wait([
        UsageService().canPlantWord().timeout(const Duration(seconds: 5)),
        db
            .getSmartNewWordCandidates(
              nativeLang,
              targetLang,
              limit: 2,
              categoryId: widget.categoryId,
              domain: widget.domain,
              subDomain: widget.subDomain,
              activeSubDomain: _activeSubDomain,
              partOfSpeech: widget.partOfSpeech,
              microCategory: widget.microCategory,
              coverageGaps: _coverageGaps,
            )
            .timeout(const Duration(seconds: 5)),
        db
            .getSRSDueWords(
              nativeLang,
              targetLang,
              limit: 10,
              categoryId: widget.categoryId,
              subDomain: widget.subDomain, // Strict theme filter
              partOfSpeech: widget.partOfSpeech,
              microCategory: widget.microCategory,
            )
            .timeout(const Duration(seconds: 5)),
        (_isIsolatedSession
                ? Future.value(<Word>[])
                : db.getCrossSubthemeReviews(
                    nativeLang,
                    targetLang,
                    limit: 3,
                    excludeSubDomain: widget.subDomain ?? _activeSubDomain,
                  ))
            .timeout(const Duration(seconds: 5)),
      ]);

      final bool canPlant = results[0] as bool;
      if (!canPlant) {
        _isLimitReached = true;
      }

      final List<Word> nextNewWords = (results[1] as List<Word>)
          .where((w) => !existingIds.contains(w.id.toString()))
          .toList();
      final List<Word> moreDue = results[2] as List<Word>;
      final List<Word> moreCrossReviews = results[3] as List<Word>;

      final combinedDue = [...moreDue, ...moreCrossReviews]
          .where((w) => !existingIds.contains(w.id.toString()))
          .toList();

      if (nextNewWords.isEmpty && combinedDue.isEmpty) {
        // Fallback: Unlimited Smart Reviews
        final randomLearned = await db.getRandomLearnedWords(
          nativeLang,
          targetLang,
          limit: 10,
          subDomain: widget.subDomain, // Ensure isolated fallback
        );
        
        final filteredRandom = randomLearned
            .where((w) => !existingIds.contains(w.id.toString()))
            .toList();

        if (filteredRandom.isEmpty) {
          // No content anywhere. Only end if QuizManager is also empty.
          final hasActiveContent = _quizKey.currentState?.hasContent ?? false;
          if (!hasActiveContent) {
            if (_isLimitReached) {
              _showPremiumForPlanting();
            } else {
              _forceEndSession();
            }
          }
          return;
        }

        // Inject fallback smart reviews
        _quizKey.currentState?.replenish(
          moreReviews: filteredRandom,
          moreNewWords: const [],
        );
      } else {
        // 3. Inject into the existing quiz state
        _quizKey.currentState?.replenish(
          moreReviews: combinedDue,
          moreNewWords: nextNewWords,
        );
      }

      if (mounted) {
        setState(() {
          _batchIndex++;
        });
      }
    } catch (e) {
      debugPrint('[LearningSession] Replenishment error/timeout: $e');
      // If we timed out or crashed, and the queue is empty, end the session
      if (mounted && (_quizKey.currentState?.allWordIds.isEmpty ?? true)) {
        _forceEndSession();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReplenishing = false;
        });
      }
    }
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

  void _showPremiumForPlanting() {
    PremiumGateDialog.show(
      context,
      title: 'Daily Seed Limit Reached',
      message:
          'You\'ve planted 5 seeds today. Free accounts can plant up to 5 words daily to ensure steady growth. Upgrade to plant unlimited seeds!',
    );
  }

  // Called when the user clicks the exit/close button or session ends naturally
  Future<void> _forceEndSession() async {
    // 🌿 Fade out ambient when session ends
    AudioService.instance.stopAmbient();

    final db = ref.read(databaseProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final userId = AuthService().userId ?? 'guest';

    // Calculate session duration (round up to nearest minute so it's not 0 for quick sessions)
    int durationMins = 0;
    if (_sessionStartTime != null) {
      final secs = DateTime.now().difference(_sessionStartTime!).inSeconds;
      if (secs > 0) {
        durationMins = (secs / 60).ceil();
        if (durationMins < 1) durationMins = 1; // minimum 1 min if they did anything
      }
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

      // Refresh Home Tab stats immediately
      ref.invalidate(userStatsProvider);

      // Log session activity for Garden Journal
      await DatabaseHelper().logActivity(
        type: 'review',
        description: 'Completed a ${durationMins}m $targetLang review session',
        xp: xpGained,
      );
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
          _pendingNewWords = [];
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
    await UsageService().logWordPlanted();

    // Log planting activity for Garden Journal
    await DatabaseHelper().logActivity(
      type: 'planting',
      description: 'Planted "${word.translation}" in your garden',
      xp: 25,
    );
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

  Future<void> _handleWordAnswered(Word word, bool correct, int responseMs) async {
    if (word.id == null) return;
    final db = ref.read(databaseProvider);

    // ── FSRS Intelligence Engine ──────────────────────────────────────────
    // The "Ultra-Smart" heart: we calculate the new memory state
    // based on speed and accuracy.
    final updatedWord = FSRSService.instance.calculateReview(
      word,
      correct,
      Duration(milliseconds: responseMs),
    );

    // Save back to DB (this also handles the botanical stage derivation)
    await db.updateWordFSRS(updatedWord);
  }

  Widget _buildQuizPhase() {
    final totalWords = _dueWords.length + (_pendingNewWords.isNotEmpty ? 1 : 0);
    final progress = _totalQuestions > 0
        ? (_correctAnswers / _totalQuestions).clamp(0.0, 1.0)
        : 0.0;

    // ── UVLS: derive live CLS proxy from available session stats ──────────
    // We proxy CLS as a 0-100 number using accuracy + streak from QuizManager.
    final accuracyPct = _totalQuestions > 0
        ? (_correctAnswers / _totalQuestions)
        : 0.0;
    final streakFromQueue = _quizKey.currentState?.streak ?? 0;
    final wordsMasteredToday = _quizKey.currentState?.wordsMastered ?? 0;

    // Simple proxy for HUD (real CLS is inside QuizManagerState)
    final realCls = _quizKey.currentState?.currentCls ?? 50.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall =
            constraints.maxWidth < 360 || constraints.maxHeight < 620;
        final isVerySmall = constraints.maxWidth < 330;

        return Column(
          children: [
            _buildSessionHeader(
              _isIsolatedSession ? (widget.subDomain ?? 'Topic Review') : 'Daily Review',
              totalWords,
              isSmall,
              isVerySmall,
              progress,
            ),
            // ── UVLS: Garden Pulse HUD ─────────────────────────────────
            if (!isVerySmall)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: ReadinessHUD(
                  clsScore: realCls,
                  streak: streakFromQueue,
                  accuracy: accuracyPct,
                  wordsMastered: wordsMasteredToday,
                ),
              ),
            Expanded(
              child: QuizManager(
                key: _quizKey,
                words: _dueWords,
                initialNewWords: _initialPlantedWords,
                pendingNewWords: _pendingNewWords,
                onWordPlanted: _markPlanted,
                onWordAnswered: _handleWordAnswered,
                onProgressUpdate: _onProgressUpdate,
                onSessionComplete: _handleBatchComplete,
                onQueueDepleted: _handleQueueDepleted,
                db: ref.read(databaseProvider),
                activeSubDomain: widget.subDomain,
                strictDistractors: _isIsolatedSession,
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
                if (_isIsolatedSession)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$_themeLearnedCount / $_themeTotalCount theme words learned',
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.textSecondary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
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
// SESSION SUMMARY SCREEN  (animated — confetti + counting stats)
// ================================================================

class SessionSummaryScreen extends StatefulWidget {
  final int correctAnswers;
  final int totalQuestions;
  final bool isEmbedded;

  const SessionSummaryScreen({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    this.isEmbedded = false,
  });

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _confettiController;
  late AnimationController _counterController;
  late List<_ConfettiParticle> _particles;

  late Animation<double> _slideIn;
  late Animation<double> _fadeIn;
  int _displayedAccuracy = 0;
  int _displayedCorrect = 0;
  int _displayedXP = 0;

  int get _accuracy => widget.totalQuestions > 0
      ? (widget.correctAnswers / widget.totalQuestions * 100).toInt()
      : 100;
  int get _xp => widget.correctAnswers * 10;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideIn = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _fadeIn = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _counterController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
        )..addListener(() {
          setState(() {
            _displayedAccuracy = (_accuracy * _counterController.value).toInt();
            _displayedCorrect =
                (widget.correctAnswers * _counterController.value).toInt();
            _displayedXP = (_xp * _counterController.value).toInt();
          });
        });

    final rng = math.Random();
    _particles = List.generate(55, (_) => _ConfettiParticle(rng));

    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _counterController.forward(from: 0);
        _confettiController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _confettiController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = _accuracy;
    final String headline = accuracy >= 80
        ? 'Excellent Growth! 🌻'
        : accuracy >= 50
        ? 'Good Progress! 🌱'
        : 'Keep Nurturing! 🌿';

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: Stack(
        children: [
          // ── Confetti layer ───────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (_, __) => CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                ),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: AnimatedBuilder(
                animation: _slideIn,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _slideIn.value),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SeedlingMascot(
                        size: 130,
                        state: MascotState.celebrating,
                      ),
                      const SizedBox(height: 22),

                      Text(
                        headline,
                        style: SeedlingTypography.heading1.copyWith(
                          fontSize: 26,
                        ),
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
                      const SizedBox(height: 28),

                      // ── Animated stats card ──────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: SeedlingColors.cardBackground,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: SeedlingColors.seedlingGreen.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: SeedlingColors.seedlingGreen.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _animatedStat(
                              '🎯',
                              '$_displayedAccuracy%',
                              'Accuracy',
                              SeedlingColors.seedlingGreen,
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: SeedlingColors.textSecondary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                            _animatedStat(
                              '✅',
                              '$_displayedCorrect',
                              'Correct',
                              SeedlingColors.success,
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: SeedlingColors.textSecondary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                            _animatedStat(
                              '⚡',
                              '+$_displayedXP',
                              'XP',
                              SeedlingColors.sunlight,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── Animated accuracy bar ────────────────────
                      _buildAccuracyBar(accuracy),

                      const SizedBox(height: 22),

                      // SRS reminder pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: SeedlingColors.morningDew.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: SeedlingColors.morningDew.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🌿', style: TextStyle(fontSize: 18)),
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

                      const SizedBox(height: 30),
                      OrganicButton(
                        text: 'Back to Garden',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedStat(String emoji, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(
          value,
          style: SeedlingTypography.heading2.copyWith(
            color: color,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: SeedlingTypography.caption.copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _buildAccuracyBar(int accuracy) {
    final Color barColor = accuracy >= 80
        ? SeedlingColors.success
        : accuracy >= 50
        ? SeedlingColors.sunlight
        : SeedlingColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Session accuracy',
              style: SeedlingTypography.caption.copyWith(
                color: SeedlingColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              '$_displayedAccuracy%',
              style: SeedlingTypography.caption.copyWith(
                color: barColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AnimatedBuilder(
            animation: _counterController,
            builder: (_, __) => LinearProgressIndicator(
              value: (_accuracy / 100) * _counterController.value,
              backgroundColor: SeedlingColors.textSecondary.withValues(
                alpha: 0.1,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 10,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Confetti Particle System ──────────────────────────────────────

class _ConfettiParticle {
  final double x;
  final double speed;
  final double angle;
  final double rotSpeed;
  final Color color;
  final double size;
  final double xDrift;
  final double phase;

  _ConfettiParticle(math.Random rng)
    : x = rng.nextDouble(),
      speed = 0.3 + rng.nextDouble() * 0.5,
      angle = rng.nextDouble() * math.pi * 2,
      rotSpeed = (rng.nextDouble() - 0.5) * 8,
      size = 6 + rng.nextDouble() * 8,
      xDrift = 0.02 + rng.nextDouble() * 0.04,
      phase = rng.nextDouble() * math.pi * 2,
      color = _kConfettiColors[rng.nextInt(_kConfettiColors.length)];

  static const _kConfettiColors = [
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFFFEB3B),
    Color(0xFFFF9800),
    Color(0xFF03A9F4),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
  ];
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    for (final p in particles) {
      final t = (progress * p.speed).clamp(0.0, 1.0);
      final y = t * size.height * 1.2;
      final x =
          p.x * size.width +
          math.sin(progress * math.pi * 4 + p.phase) * p.xDrift * size.width;
      final opacity = t > 0.7 ? (1.0 - (t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity * 0.85)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + p.rotSpeed * progress);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.55,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}
