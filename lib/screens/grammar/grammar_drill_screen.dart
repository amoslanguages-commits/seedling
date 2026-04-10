import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/grammar_model.dart';
import '../../services/grammar_service.dart';
import '../../services/haptic_service.dart';

class GrammarDrillScreen extends ConsumerStatefulWidget {
  final GrammarConcept concept;
  final String mode;
  final String langCode;

  const GrammarDrillScreen({
    super.key,
    required this.concept,
    required this.mode,
    required this.langCode,
  });

  @override
  ConsumerState<GrammarDrillScreen> createState() => _GrammarDrillScreenState();
}

class _GrammarDrillScreenState extends ConsumerState<GrammarDrillScreen> {
  List<GrammarSentence> _sentences = [];
  bool _isLoading = true;
  String _error = '';
  
  int _currentIndex = 0;
  int _correct = 0;
  bool _isSessionComplete = false;

  final fsrs.Scheduler _scheduler = fsrs.Scheduler();

  @override
  void initState() {
    super.initState();
    _loadSentences();
  }

  Future<void> _loadSentences() async {
    try {
      final sentences = await GrammarService.instance.getSentencesForConcept(
        widget.concept.conceptId,
        widget.langCode,
      );

      setState(() {
        _sentences = sentences..shuffle();
        // Limit to 10 for a standard drill
        if (_sentences.length > 10) {
          _sentences = _sentences.sublist(0, 10);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleAnswer(bool isCorrect, {Duration duration = const Duration(seconds: 2)}) async {
    final current = _sentences[_currentIndex];
    
    // Simplistic FSRS progression
    // In a real flow, you'd fetch the previous state from db.
    final card = fsrs.Card(
      cardId: current.sentenceId,
    );
    
    fsrs.Rating rating;
    if (!isCorrect) {
      rating = fsrs.Rating.again;
    } else {
      rating = fsrs.Rating.good;
      _correct++;
    }

    final result = _scheduler.reviewCard(
      card,
      rating,
      reviewDateTime: DateTime.now().toUtc(),
      reviewDuration: duration.inMilliseconds,
    );

    // Save progress to grammar DB
    final updatedCard = result.card;
    final newMastery = rating == fsrs.Rating.again ? 0.0 : min(1.0, (updatedCard.stability ?? 0.0) / 10.0);
    
    await GrammarService.instance.recordReview(
      sentenceId: current.sentenceId,
      conceptId: current.conceptId,
      langCode: current.langCode,
      mastery: newMastery,
      stability: updatedCard.stability ?? 1.0,
      difficulty: updatedCard.difficulty ?? 5.0,
      reps: 1, // Just a placeholder for reps since it's mock
      dueDate: updatedCard.due,
    );

    if (_currentIndex < _sentences.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      setState(() {
        _isSessionComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: SeedlingColors.background,
        body: const Center(child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen)),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: SeedlingColors.background,
        appBar: AppBar(backgroundColor: SeedlingColors.background),
        body: Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.white))),
      );
    }

    if (_sentences.isEmpty) {
      return Scaffold(
        backgroundColor: SeedlingColors.background,
        appBar: AppBar(backgroundColor: SeedlingColors.background),
        body: const Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'No sentences available for this concept yet. check back soon!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    if (_isSessionComplete) {
      return Scaffold(
        backgroundColor: SeedlingColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('Session Complete!', style: SeedlingTypography.heading1.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text('Accuracy: ${(_correct / _sentences.length * 100).toStringAsFixed(0)}%', style: SeedlingTypography.body.copyWith(color: Colors.white70)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SeedlingColors.seedlingGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text('Continue', style: SeedlingTypography.body.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final progress = (_currentIndex) / _sentences.length;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: SizedBox(
          height: 8,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            color: widget.concept.level.color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 48),
              Expanded(
                child: _buildDrillContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = '';
    switch (widget.mode) {
      case 'fill': title = 'Fill the Gap'; break;
      case 'transform': title = 'Syntax Scramble'; break;
      case 'target': title = 'Target Word'; break;
      case 'recall': title = 'Recall'; break;
    }

    return Column(
      children: [
        Text(title, style: SeedlingTypography.heading3.copyWith(color: widget.concept.level.color)),
        const SizedBox(height: 8),
        Text('Concept ${widget.concept.conceptId} · ${widget.concept.displayName}', style: SeedlingTypography.caption.copyWith(color: Colors.white54)),
      ],
    );
  }

  Widget _buildDrillContent() {
    final sentence = _sentences[_currentIndex];
    
    switch (widget.mode) {
      case 'fill': return _FillTheGap(sentence: sentence, onAnswer: _handleAnswer);
      case 'transform': return _SyntaxScramble(sentence: sentence, onAnswer: _handleAnswer);
      case 'target': return _TargetWord(sentence: sentence, onAnswer: _handleAnswer);
      case 'recall': return _RecallFlashcard(sentence: sentence, onAnswer: _handleAnswer);
      default: return const Center(child: Text('Unknown mode'));
    }
  }
}

// ─── DRILL MODES ────────────────────────────────────────────────────────────

class _FillTheGap extends StatelessWidget {
  final GrammarSentence sentence;
  final Function(bool) onAnswer;

  const _FillTheGap({required this.sentence, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final words = sentence.sentence.split(' ');
    final gapIndex = words.length > 1 ? Random().nextInt(words.length) : 0;
    final targetWord = words[gapIndex];
    
    // Create distractors (mocking logic)
    final allDistractors = ['el', 'la', 'un', 'una', 'es', 'son', 'está', 'están', 'voy', 'vas', 'hola', 'adiós'];
    allDistractors.removeWhere((w) => w.toLowerCase() == targetWord.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase());
    allDistractors.shuffle();
    final options = [targetWord, allDistractors[0], allDistractors[1], allDistractors[2]]..shuffle();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(words.length, (i) {
            if (i == gapIndex) {
              return Container(
                width: 60,
                height: 30,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
                ),
              );
            }
            return Text(words[i], style: SeedlingTypography.heading2.copyWith(color: Colors.white));
          }),
        ),
        if (sentence.notes != null) ...[
          const SizedBox(height: 16),
          Text(sentence.notes!, style: SeedlingTypography.body.copyWith(color: Colors.white54)),
        ],
        const Spacer(),
        ...options.map((opt) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ElevatedButton(
            onPressed: () => onAnswer(opt == targetWord),
            style: ElevatedButton.styleFrom(
              backgroundColor: SeedlingColors.cardBackground,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(opt, style: SeedlingTypography.body),
          ),
        )),
      ],
    );
  }
}

class _SyntaxScramble extends StatefulWidget {
  final GrammarSentence sentence;
  final Function(bool) onAnswer;

  const _SyntaxScramble({required this.sentence, required this.onAnswer});

  @override
  State<_SyntaxScramble> createState() => _SyntaxScrambleState();
}

class _SyntaxScrambleState extends State<_SyntaxScramble> {
  late List<String> _shuffledWords;
  List<String> _selectedWords = [];

  @override
  void initState() {
    super.initState();
    _shuffledWords = widget.sentence.sentence.split(' ')..shuffle();
  }

  void _checkAnswer() {
    final correct = _selectedWords.join(' ') == widget.sentence.sentence;
    widget.onAnswer(correct);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.sentence.notes != null)
          Text(widget.sentence.notes!, style: SeedlingTypography.body.copyWith(color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        Container(
          constraints: const BoxConstraints(minHeight: 100),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedWords.map((w) => ActionChip(
              label: Text(w, style: const TextStyle(color: Colors.white)),
              backgroundColor: SeedlingColors.cardBackground,
              onPressed: () {
                setState(() {
                  _selectedWords.remove(w);
                  _shuffledWords.add(w);
                });
                HapticService.selection();
              },
            )).toList(),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _shuffledWords.map((w) => ActionChip(
            label: Text(w, style: const TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
            onPressed: () {
              setState(() {
                _shuffledWords.remove(w);
                _selectedWords.add(w);
              });
              HapticService.selection();
            },
          )).toList(),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _shuffledWords.isEmpty ? _checkAnswer : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: SeedlingColors.seedlingGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Check Answer'),
        )
      ],
    );
  }
}

class _TargetWord extends StatelessWidget {
  final GrammarSentence sentence;
  final Function(bool) onAnswer;

  const _TargetWord({required this.sentence, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final words = sentence.sentence.split(' ');
    // Random target word to select (mocking target recognition)
    final targetIndex = words.length > 1 ? Random().nextInt(words.length) : 0;
    final targetWord = words[targetIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Which word translates to this idea?",
          style: SeedlingTypography.body.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 16),
        Text("🎯 Target", style: SeedlingTypography.heading1.copyWith(color: SeedlingColors.water)),
        const SizedBox(height: 48),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: words.map((w) => OutlinedButton(
            onPressed: () => onAnswer(w == targetWord),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(w, style: SeedlingTypography.heading3),
          )).toList(),
        ),
      ],
    );
  }
}

class _RecallFlashcard extends StatefulWidget {
  final GrammarSentence sentence;
  final Function(bool) onAnswer;

  const _RecallFlashcard({required this.sentence, required this.onAnswer});

  @override
  State<_RecallFlashcard> createState() => _RecallFlashcardState();
}

class _RecallFlashcardState extends State<_RecallFlashcard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Translate to Target Language", style: SeedlingTypography.body.copyWith(color: Colors.white54)),
        const SizedBox(height: 24),
        Text(widget.sentence.notes ?? 'No translation available', style: SeedlingTypography.heading1.copyWith(color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 48),
        if (!_revealed)
          ElevatedButton(
            onPressed: () {
              setState(() => _revealed = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SeedlingColors.cardBackground,
              minimumSize: const Size(double.infinity, 56),
            ),
            child: Text('Reveal Answer', style: SeedlingTypography.body.copyWith(color: Colors.white)),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: SeedlingColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SeedlingColors.seedlingGreen),
            ),
            child: Text(widget.sentence.sentence, style: SeedlingTypography.heading2.copyWith(color: SeedlingColors.seedlingGreen), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onAnswer(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                    minimumSize: const Size(0, 56),
                  ),
                  child: const Text('Again', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onAnswer(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SeedlingColors.seedlingGreen,
                    minimumSize: const Size(0, 56),
                  ),
                  child: const Text('Good', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ]
      ],
    );
  }
}
