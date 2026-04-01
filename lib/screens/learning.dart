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
import '../services/audio_service.dart';

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
  noWordsYet,    // fresh user: plant 3 seeds before any quiz
  quiz,          // SRS review of due words
  done,          // session complete
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

class _LearningSessionScreenState
    extends ConsumerState<LearningSessionScreen> {
  _SessionPhase _phase = _SessionPhase.loading;
  List<Word> _dueWords = [];
  Word? _newWordToPlant;
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  int _cumulativeCorrect = 0;
  int _cumulativeTotal = 0;
  bool _isFirstSession = false;  // plant 3 words if garden is empty
  List<Word> _initialPlantedWords = [];
  int _batchIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final db = ref.read(databaseProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);

    // Check if user has learned any words yet (global progress for this language)
    final totalLearned = await db.getTotalWordsLearned(targetLang);
    final isBrandNew = totalLearned == 0;

    // Load one new word from the SELECTED context (category/domain/subDomain/POS)
    final newWord = await db.getNewWordToPlant(
      nativeLang,
      targetLang,
      categoryId: widget.categoryId,
      domain: widget.domain,
      subDomain: widget.subDomain,
      partOfSpeech: widget.partOfSpeech,
      microCategory: widget.microCategory,
    );

    // Load SRS-due words (mastery > 0, review overdue)
    // 🪴 CHANGE: We now pull reviews from ANY category ('alongside'),
    // even if we are currently in a specific category for the 'new' word.
    final due = await db.getSRSDueWords(
      nativeLang,
      targetLang,
      limit: 15,
      // Pass null category here to pull reviews globally as requested
      categoryId: null, 
      partOfSpeech: widget.partOfSpeech,
      microCategory: widget.microCategory,
    );

    if (!mounted) return;

    setState(() {
      _dueWords = due;
      _newWordToPlant = newWord;
      _isFirstSession = isBrandNew;

      if (isBrandNew) {
        // Brand-new user with 0 words globally: go to planting phase (will plant 3)
        _phase = _SessionPhase.noWordsYet;
      } else if (due.isEmpty && newWord == null) {
        // Nothing at all to learn/review in this context
        if (_batchIndex == 0) {
          _forceEndSession();
        } else {
          _forceEndSession();
        }
      } else {
        // Ready to quiz existing user
        _phase = _SessionPhase.quiz;
        // 🌿 Start ambient garden soundscape
        AudioService.instance.startAmbient();
      }
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
  void _forceEndSession() {
    // 🌿 Fade out ambient when session ends
    AudioService.instance.stopAmbient();
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
              const CircularProgressIndicator(color: SeedlingColors.seedlingGreen),
              const SizedBox(height: 16),
              Text('Preparing your garden...', style: SeedlingTypography.caption),
            ],
          ),
        );

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

  // ── First-session: plant 3 words (no quiz yet) ─────────────────────────

  Widget _buildFirstSessionPlanting() {
    return FutureBuilder<List<Word>>(
      future: _fetchInitialWords(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(
            color: SeedlingColors.seedlingGreen,
          ));
        }
        final words = snap.data!;
        if (words.isEmpty) {
          if (_batchIndex > 0) {
            // Reached end of indefinite play? (Should have been caught in handleBatchComplete)
            WidgetsBinding.instance.addPostFrameCallback((_) => _forceEndSession());
            return const SizedBox.shrink();
          }
          return _buildEmptyGarden();
        }
        _initialPlantedWords = words;
        return SeedPlantingScreen(
          words: words,
          initialBatchSize: 3,
          onWordPlanted: _markPlanted,
          onPlantingComplete: _onInitialPlantingComplete,
        );
      },
    );
  }

  Future<List<Word>> _fetchInitialWords() async {
    final db = ref.read(databaseProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);
    
    // Pull words for the selected context
    final candidateWords = await db.getWordsForLanguage(
      nativeLang, 
      targetLang,
      categoryId: widget.categoryId,
      partOfSpeech: widget.partOfSpeech,
      limit: 20,
    );
    
    // Filter for unlearned words and take up to 3
    final List<Word> wordsToPlant = candidateWords
        .where((w) => w.masteryLevel == 0)
        .take(3)
        .toList();
        
    return wordsToPlant;
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
            Text('Your garden is empty!',
                style: SeedlingTypography.heading2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Add a language course to start planting words.',
              style: SeedlingTypography.body
                  .copyWith(color: SeedlingColors.textSecondary),
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
    final progress = _totalQuestions > 0 ? (_correctAnswers / _totalQuestions).clamp(0.0, 1.0) : 0.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 360 || constraints.maxHeight < 620;
        final isVerySmall = constraints.maxWidth < 330;
        
        return Column(
          children: [
            _buildSessionHeader('Daily Review', totalWords, isSmall, isVerySmall, progress),
            Expanded(
              child: QuizManager(
                key: ValueKey(_batchIndex), // Force full reset of Quiz queue on new batch
                words: _dueWords,
                initialNewWords: _batchIndex == 1 ? _initialPlantedWords : const [],
                newWordToPlant: _newWordToPlant,
                onWordPlanted: _markPlanted,
                onWordAnswered: _handleWordAnswered,
                onProgressUpdate: _onProgressUpdate,
                onSessionComplete: _handleBatchComplete,
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildSessionHeader(String title, int wordCount, bool isSmall, bool isVerySmall, double progress) {
    final horizontalPadding = isVerySmall ? 6.0 : (isSmall ? 10.0 : 16.0);
    final mascotSize = isVerySmall ? 32.0 : (isSmall ? 40.0 : 52.0);
    final showPronunciation = ref.watch(showPronunciationProvider);
    
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
                  )
                ),
                StemProgressBar(
                  progress: progress, 
                  height: isSmall ? 5 : 7,
                  showLeaves: !isSmall, // Hide leaves on progress bar if very small to save space
                ),
              ],
            ),
          ),
          SizedBox(width: isVerySmall ? 4 : 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isVerySmall ? 6 : (isSmall ? 8 : 12), 
              vertical: isVerySmall ? 3 : (isSmall ? 4 : 6)
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
              ref.read(showPronunciationProvider.notifier).update((state) => !state);
              AudioService.haptic(HapticType.tap).ignore();
            },
            icon: Icon(
              showPronunciation ? Icons.record_voice_over : Icons.voice_over_off,
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
    final accuracy =
        totalQuestions > 0 ? (correctAnswers / totalQuestions * 100).toInt() : 100;
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
                style: SeedlingTypography.body
                    .copyWith(color: SeedlingColors.textSecondary),
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
                      color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('Accuracy', '$accuracy%', SeedlingColors.seedlingGreen),
                    _stat('Correct', '$correctAnswers', SeedlingColors.success),
                    _stat('XP', '+$xp', SeedlingColors.sunlight),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // SRS reminder
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                        style: SeedlingTypography.caption
                            .copyWith(color: SeedlingColors.textSecondary),
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
        Text(value,
            style:
                SeedlingTypography.heading2.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(label, style: SeedlingTypography.caption),
      ],
    );
  }
}
