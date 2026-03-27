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
  /// Optional POS filter
  final String? partOfSpeech;

  const LearningSessionScreen({super.key, this.categoryId, this.partOfSpeech});

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

    // Load SRS-due words (mastery > 0, review overdue)
    final due = await db.getSRSDueWords(
      nativeLang,
      targetLang,
      limit: 15,
      categoryId: widget.categoryId,
      partOfSpeech: widget.partOfSpeech,
    );

    // Load one new word to plant after the session
    final newWord = await db.getNewWordToPlant(
      nativeLang,
      targetLang,
      categoryId: widget.categoryId,
      partOfSpeech: widget.partOfSpeech,
    );

    if (!mounted) return;

    setState(() {
      _dueWords = due;
      _newWordToPlant = newWord;

      if (due.isEmpty && newWord == null) {
        // Nothing at all to learn/review in this context
        if (_batchIndex == 0) { // First time loading
           _isFirstSession = true;
           _phase = _SessionPhase.noWordsYet;
        } else {
           _forceEndSession();
        }
      } else if (due.isEmpty && _batchIndex == 0) {
        // Brand-new user or complete completely empty due queue — go straight to planting (plant 3 words first)
        _isFirstSession = true;
        _phase = _SessionPhase.noWordsYet;
      } else {
        // Ready to quiz
        _phase = _SessionPhase.quiz;
        // 🌿 Start ambient garden soundscape for the quiz session
        AudioService.instance.startAmbient();
      }
    });
  }

  // Called continuously by QuizManager
  void _onProgressUpdate(int correct, int total) {
    _correctAnswers = correct;
    _totalQuestions = total;
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
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: SeedlingColors.seedlingGreen),
              SizedBox(height: 16),
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
    return db.getNewWordToPlant(nativeLang, targetLang,
            categoryId: widget.categoryId, partOfSpeech: widget.partOfSpeech)
        .then((w) async {
      // Need 3 words for initial planting — pull them one by one
      final words = <Word>[];
      var remaining = await db.getWordsForLanguage(
        nativeLang, targetLang,
        categoryId: widget.categoryId,
        partOfSpeech: widget.partOfSpeech,
        limit: 10,
      );
      for (final word in remaining) {
        if (word.masteryLevel == 0) words.add(word);
        if (words.length >= 3) break;
      }
      return words;
    });
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
            const Text('Your garden is empty!',
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

  Widget _buildQuizPhase() {
    final totalWords = _dueWords.length + (_newWordToPlant != null ? 1 : 0);
    return Column(
      children: [
        _buildSessionHeader('Daily Review', totalWords),
        Expanded(
          child: QuizManager(
            key: ValueKey(_batchIndex), // Force full reset of Quiz queue on new batch
            words: _dueWords,
            initialNewWords: _batchIndex == 1 ? _initialPlantedWords : const [],
            newWordToPlant: _newWordToPlant,
            onWordPlanted: _markPlanted,
            onProgressUpdate: _onProgressUpdate,
            onSessionComplete: _handleBatchComplete,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionHeader(String title, int wordCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SeedlingTypography.caption
                    .copyWith(color: SeedlingColors.textSecondary)),
                const StemProgressBar(progress: 0, height: 7),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SeedlingColors.seedlingGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '$wordCount words',
              style: SeedlingTypography.caption.copyWith(
                color: SeedlingColors.seedlingGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const SeedlingMascot(size: 52, state: MascotState.idle),
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
