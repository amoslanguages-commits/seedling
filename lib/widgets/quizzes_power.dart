import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';

// ================================================================
// POWER LEARNING QUIZZES (ACTIVE PRODUCTION)
// ================================================================
//
// 1. LeafLetterQuiz    - Spell the target word by tapping letters
// 2. ForestClozeQuiz   - Fill in the blank for the example sentence
//
// ================================================================

class LeafLetterQuiz extends StatefulWidget {
  final Word word;
  final Function(
    bool correct,
    int masteryGained, [
    String? chosenWrongTranslation,
  ])
  onAnswer;

  const LeafLetterQuiz({super.key, required this.word, required this.onAnswer});

  @override
  State<LeafLetterQuiz> createState() => _LeafLetterQuizState();
}

class _LeafLetterQuizState extends State<LeafLetterQuiz>
    with TickerProviderStateMixin {
  late List<String> _targetLetters;
  late List<String> _bankLetters;
  late List<String?> _slottedLetters;
  late List<int?> _slottedFromIndex;

  late AnimationController _shakeController;
  late AnimationController _bloomController;

  bool _hasAnswered = false;
  int _mistakes = 0;

  @override
  void initState() {
    super.initState();
    TtsService.instance.speak(
      widget.word.translation,
      widget.word.languageCode,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final cleanWord = widget.word.word.trim();
    _targetLetters = cleanWord.split('');
    _slottedLetters = List.filled(_targetLetters.length, null);
    _slottedFromIndex = List.filled(_targetLetters.length, null);

    _bankLetters = List.from(_targetLetters);
    // Add some random distractor letters to make it harder (if small word)
    final random = math.Random();
    const alphabet = 'abcdefghijklmnopqrstuvwxyz';
    int distractorsToAdd = math.max(0, 8 - _targetLetters.length);
    for (int i = 0; i < distractorsToAdd; i++) {
      _bankLetters.add(alphabet[random.nextInt(alphabet.length)]);
    }
    _bankLetters.shuffle(random);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _bloomController.dispose();
    super.dispose();
  }

  void _tapBankLetter(int index) {
    if (_hasAnswered) return;
    if (_bankLetters[index].isEmpty) return; // already used

    final emptySlot = _slottedLetters.indexWhere((l) => l == null);
    if (emptySlot != -1) {
      setState(() {
        _slottedLetters[emptySlot] = _bankLetters[index];
        _slottedFromIndex[emptySlot] = index;
        _bankLetters[index] = ''; // clear from bank
      });
      AudioService.haptic(HapticType.tap).ignore();
    }

    _checkWinCondition();
  }

  void _tapSlottedLetter(int slotIndex) {
    if (_hasAnswered) return;
    if (_slottedLetters[slotIndex] == null) return;

    setState(() {
      final bankIndex = _slottedFromIndex[slotIndex]!;
      _bankLetters[bankIndex] = _slottedLetters[slotIndex]!;
      _slottedLetters[slotIndex] = null;
      _slottedFromIndex[slotIndex] = null;
    });
    AudioService.haptic(HapticType.tap).ignore();
  }

  void _checkWinCondition() {
    if (_slottedLetters.contains(null)) return; // not full

    final currentSpelling = _slottedLetters.join('');
    final targetSpelling = _targetLetters.join('');

    if (currentSpelling.toLowerCase() == targetSpelling.toLowerCase()) {
      _hasAnswered = true;
      _bloomController.forward();
      AudioService.instance.playCorrect(streak: 0);
      AudioService.haptic(HapticType.correct).ignore();

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          widget.onAnswer(true, _mistakes == 0 ? 1 : 0);
        }
      });
    } else {
      _mistakes++;
      _shakeController.forward(from: 0);
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();

      // Auto return all letters after a delay
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_hasAnswered) {
          setState(() {
            for (int i = 0; i < _slottedLetters.length; i++) {
              if (_slottedLetters[i] != null) {
                final bankIndex = _slottedFromIndex[i]!;
                _bankLetters[bankIndex] = _slottedLetters[i]!;
                _slottedLetters[i] = null;
                _slottedFromIndex[i] = null;
              }
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Target Meaning Card
        Container(
          margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: SeedlingColors.morningDew.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Spell the translation:',
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.word.translation,
                style: SeedlingTypography.heading2.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const Spacer(flex: 2),

        // Slots
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final dx = math.sin(_shakeController.value * math.pi * 4) * 8;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_slottedLetters.length, (index) {
              final letter = _slottedLetters[index];
              return GestureDetector(
                onTap: () => _tapSlottedLetter(index),
                child: Container(
                  width: 44,
                  height: 54,
                  decoration: BoxDecoration(
                    color: letter != null
                        ? SeedlingColors.seedlingGreen
                        : SeedlingColors.soil.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: letter != null
                          ? SeedlingColors.freshSprout
                          : SeedlingColors.soil.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    boxShadow: letter != null
                        ? [
                            BoxShadow(
                              color: SeedlingColors.seedlingGreen.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letter?.toUpperCase() ?? '',
                    style: SeedlingTypography.heading2.copyWith(
                      color: SeedlingColors.textPrimary,
                      fontSize: 24,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const Spacer(flex: 3),

        // Letter Bank
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 16,
            children: List.generate(_bankLetters.length, (index) {
              final letter = _bankLetters[index];
              if (letter.isEmpty) {
                return const SizedBox(
                  width: 48,
                  height: 56,
                ); // empty placeholder
              }
              return GestureDetector(
                onTap: () => _tapBankLetter(index),
                child: Container(
                  width: 48,
                  height: 56,
                  decoration: BoxDecoration(
                    color: SeedlingColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SeedlingColors.morningDew),
                    boxShadow: [
                      BoxShadow(
                        color: SeedlingColors.soil.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letter.toUpperCase(),
                    style: SeedlingTypography.heading3.copyWith(
                      color: SeedlingColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ForestClozeQuiz extends StatefulWidget {
  final Word word;
  final List<String> options;
  final Function(
    bool correct,
    int masteryGained, [
    String? chosenWrongTranslation,
  ])
  onAnswer;

  const ForestClozeQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<ForestClozeQuiz> createState() => _ForestClozeQuizState();
}

class _ForestClozeQuizState extends State<ForestClozeQuiz>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _bloomController;
  bool _hasAnswered = false;
  int? _selectedIndex;

  late String _clozedSentence;
  late String _clozedTranslation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final sentence = widget.word.exampleSentence ?? '';
    final translation = widget.word.exampleSentenceTranslation ?? '';
    final target = widget.word.word;

    // Try to replace the target word with blanks (case insensitive)
    _clozedSentence = sentence.replaceAll(
      RegExp(target, caseSensitive: false),
      '________',
    );
    _clozedTranslation = translation;

    TtsService.instance.speak(sentence, widget.word.targetLanguageCode);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _bloomController.dispose();
    super.dispose();
  }

  void _handleAnswer(int index) {
    if (_hasAnswered) return;
    setState(() {
      _selectedIndex = index;
      _hasAnswered = true;
    });

    final isCorrect = widget.options[index] == widget.word.word;

    if (isCorrect) {
      _bloomController.forward();
      AudioService.instance.playCorrect(streak: 0);
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _shakeController.forward(from: 0);
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sentence Card
        Container(
          margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: SeedlingColors.morningDew.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Fill in the blank:',
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final dx = math.sin(_shakeController.value * math.pi * 4) * 8;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: Text(
                  _hasAnswered &&
                          _selectedIndex != null &&
                          widget.options[_selectedIndex!] == widget.word.word
                      ? widget.word.exampleSentence ?? ''
                      : _clozedSentence,
                  style: SeedlingTypography.heading3.copyWith(height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _clozedTranslation,
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const Spacer(),

        // Options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: List.generate(widget.options.length, (index) {
              final isSelected = _selectedIndex == index;
              final isCorrectOption = widget.options[index] == widget.word.word;

              Color bgColor = SeedlingColors.cardBackground;
              Color borderColor = SeedlingColors.morningDew;
              Color textColor = SeedlingColors.textPrimary;

              if (_hasAnswered) {
                if (isCorrectOption) {
                  bgColor = SeedlingColors.seedlingGreen.withValues(alpha: 0.1);
                  borderColor = SeedlingColors.seedlingGreen;
                  textColor = SeedlingColors.seedlingGreen;
                } else if (isSelected) {
                  bgColor = SeedlingColors.deepRoot.withValues(alpha: 0.5);
                  borderColor = SeedlingColors.deepRoot;
                  textColor = SeedlingColors.textSecondary;
                }
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _handleAnswer(index),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: isSelected || (_hasAnswered && isCorrectOption)
                            ? 2
                            : 1,
                      ),
                      boxShadow: [
                        if (!isSelected && !_hasAnswered)
                          BoxShadow(
                            color: SeedlingColors.soil.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Text(
                      widget.options[index],
                      style: SeedlingTypography.body.copyWith(
                        color: textColor,
                        fontWeight:
                            isSelected || (_hasAnswered && isCorrectOption)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
