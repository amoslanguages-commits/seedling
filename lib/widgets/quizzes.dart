import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'dart:collection';
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/word.dart';
import '../widgets/progress.dart';
import 'quizzes_v2.dart';
import 'quizzes_gender.dart';
import 'quizzes_power.dart';
import 'seed_planting.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../services/intelligence_service.dart';
import '../services/session_conductor.dart';
import '../widgets/readiness_hud.dart';
import '../database/database_helper.dart';
import '../widgets/target_word_display.dart';
import '../widgets/mastery_celebration.dart';
import '../widgets/tilt_card.dart';
import '../widgets/speaker_button.dart';

// ================ QUIZ TYPE 1: GROW THE WORD ================
// Correct answer = plant grows visually

class GrowTheWordQuiz extends StatefulWidget {
  final Word word;
  final List<String> options;
  final void Function(
    bool correct,
    int masteryGained, [
    String? chosenWrongTranslation,
  ])
  onAnswer;

  const GrowTheWordQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<GrowTheWordQuiz> createState() => _GrowTheWordQuizState();
}

class _GrowTheWordQuizState extends State<GrowTheWordQuiz>
    with TickerProviderStateMixin {
  late AnimationController _plantGrowthController;
  late AnimationController _shakeController;
  late AnimationController _entryController;
  late Animation<double> _entryFade;
  late Animation<double> _entrySlide;
  int? _selectedIndex;
  bool _hasAnswered = false;
  double _currentGrowth = 0.0;
  bool _usedHint = false;
  bool _showHint = false;

  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();

    TtsService.instance.speak(
      widget.word.ttsWord,
      widget.word.targetLanguageCode,
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entrySlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();

    _plantGrowthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _plantGrowthController.dispose();
    _shakeController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _handleAnswer(int index) {
    if (_hasAnswered) return;

    // Immediate tactile pop — fires before correct/wrong verdict
    AudioService.instance.play(SFX.answerSelect);

    setState(() {
      _selectedIndex = index;
      _hasAnswered = true;
    });

    final isCorrect = widget.options[index] == widget.word.translation;

    if (isCorrect) {
      _plantGrowthController.forward();
      setState(() => _currentGrowth = 1.0);
      Future.delayed(const Duration(milliseconds: 120), () {
        AudioService.instance.playCorrect();
      });
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _shakeController.forward(from: 0);
      setState(() => _currentGrowth = 0.3);
      Future.delayed(const Duration(milliseconds: 120), () {
        AudioService.instance.play(SFX.wrongAnswer);
      });
      AudioService.haptic(HapticType.wrong).ignore();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _plantGrowthController.animateTo(0.3);
      });
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      // If hint was used and answer is correct: neutral (mastery=0, not wrong queue advance)
      // If answer is wrong: normal wrong (mastery=0, requires re-learning)
      // If no hint and correct: full mastery=1
      if (!mounted) return;

      if (!isCorrect) {
        widget.onAnswer(false, 0);
      } else {
        widget.onAnswer(true, _usedHint ? 0 : 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryFade,
      child: AnimatedBuilder(
        animation: _entrySlide,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _entrySlide.value.roundToDouble()),
          child: child,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxHeight < 620;
            final plantFlex = isSmallScreen ? 1 : 2;
            final spacing = isSmallScreen ? 16.0 : 30.0;

            return Column(
              children: [
                // Growing Plant Visualization
                Expanded(
                  flex: plantFlex,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _plantGrowthController,
                      _shakeController,
                    ]),
                    builder: (context, child) {
                      final shakeOffset = _shakeController.isAnimating
                          ? (math.sin(_shakeController.value * math.pi * 8.0) *
                                    10.0 *
                                    (1.0 - _shakeController.value))
                                .roundToDouble()
                          : 0.0;

                      return Transform.translate(
                        offset: Offset(shakeOffset, 0),
                        child: CustomPaint(
                          size: Size(
                            double.infinity,
                            isSmallScreen ? 140 : 250,
                          ),
                          painter: GrowingPlantPainter(
                            growthProgress:
                                _currentGrowth +
                                (_plantGrowthController.value * 0.7),
                            isWilting:
                                _selectedIndex != null &&
                                widget.options[_selectedIndex!] !=
                                    widget.word.translation,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Word Display
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: isSmallScreen ? 12 : 20,
                  ),
                  decoration: BoxDecoration(
                    color: SeedlingColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hint panel
                      if (_showHint && widget.word.definition != null) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: SeedlingColors.sunlight.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: SeedlingColors.sunlight.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.word.definition!,
                                  style: SeedlingTypography.body.copyWith(
                                    fontSize: 13,
                                    color: SeedlingColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Text(
                        'What does this mean?',
                        style: SeedlingTypography.caption.copyWith(
                          fontSize: isSmallScreen ? 11 : 12,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TargetWordDisplay(
                            word: widget.word,
                            style: SeedlingTypography.heading1.copyWith(
                              fontSize: isSmallScreen ? 28 : 36,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SeedlingSpeakerButton(
                            text: widget.word.ttsWord,
                            languageCode: widget.word.targetLanguageCode,
                            iconSize: 24,
                          ),
                          // Lifeline hint button — only if definition exists
                          if (widget.word.definition != null &&
                              !_hasAnswered) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _usedHint = true;
                                  _showHint = true;
                                });
                                AudioService.haptic(HapticType.tap).ignore();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _usedHint
                                      ? SeedlingColors.sunlight.withValues(
                                          alpha: 0.25,
                                        )
                                      : SeedlingColors.textSecondary.withValues(
                                          alpha: 0.08,
                                        ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 18,
                                  color: _usedHint
                                      ? SeedlingColors.sunlight
                                      : SeedlingColors.textSecondary.withValues(
                                          alpha: 0.5,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: spacing),

                // Options list fitted perfectly to screen
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.options.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          final isSelected = _selectedIndex == index;
                          final isCorrect = option == widget.word.translation;

                          Color bgColor = SeedlingColors.cardBackground;
                          Color borderColor = SeedlingColors.morningDew
                              .withValues(alpha: 0.3);

                          if (_hasAnswered) {
                            if (isCorrect) {
                              bgColor = SeedlingColors.success.withValues(
                                alpha: 0.2,
                              );
                              borderColor = SeedlingColors.success;
                            } else if (isSelected && !isCorrect) {
                              bgColor = SeedlingColors.error.withValues(
                                alpha: 0.2,
                              );
                              borderColor = SeedlingColors.error;
                            }
                          } else if (isSelected) {
                            bgColor = SeedlingColors.seedlingGreen.withValues(
                              alpha: 0.1,
                            );
                            borderColor = SeedlingColors.seedlingGreen;
                          }

                          final label = index < _labels.length
                              ? _labels[index]
                              : '${index + 1}';
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: isSmallScreen ? 8 : 12,
                              ),
                              child: GestureDetector(
                                onTap: () => _handleAnswer(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: borderColor,
                                    width:
                                        isSelected ||
                                            (_hasAnswered && isCorrect)
                                        ? 2.0
                                        : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: SeedlingColors.seedlingGreen
                                                .withValues(alpha: 0.2),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    // Letter label badge
                                    Container(
                                      width: isSmallScreen ? 22 : 26,
                                      height: isSmallScreen ? 22 : 26,
                                      margin: EdgeInsets.only(
                                        right: isSmallScreen ? 10 : 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _hasAnswered
                                            ? (isCorrect
                                                  ? SeedlingColors.success
                                                        .withValues(alpha: 0.3)
                                                  : isSelected
                                                  ? SeedlingColors.error
                                                        .withValues(alpha: 0.3)
                                                  : SeedlingColors.textSecondary
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ))
                                            : isSelected
                                            ? SeedlingColors.seedlingGreen
                                                  .withValues(alpha: 0.2)
                                            : SeedlingColors.textSecondary
                                                  .withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        label,
                                        style: SeedlingTypography.caption
                                            .copyWith(
                                              fontSize: isSmallScreen ? 10 : 11,
                                              fontWeight: FontWeight.bold,
                                              color: _hasAnswered
                                                  ? (isCorrect
                                                        ? SeedlingColors.success
                                                        : isSelected
                                                        ? SeedlingColors.error
                                                        : SeedlingColors
                                                              .textSecondary)
                                                  : isSelected
                                                  ? SeedlingColors.seedlingGreen
                                                  : SeedlingColors
                                                        .textSecondary,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: SeedlingTypography.bodyLarge
                                            .copyWith(
                                              fontSize: isSmallScreen ? 14 : 16,
                                              color:
                                                  _hasAnswered &&
                                                      !isCorrect &&
                                                      isSelected
                                                  ? SeedlingColors.error
                                                  : SeedlingColors.textPrimary,
                                            ),
                                      ),
                                    ),
                                    if (_hasAnswered && isCorrect)
                                      const Icon(
                                        Icons.check_circle,
                                        color: SeedlingColors.success,
                                        size: 20,
                                      ),
                                    if (_hasAnswered &&
                                        isSelected &&
                                        !isCorrect)
                                      const Icon(
                                        Icons.cancel,
                                        color: SeedlingColors.error,
                                        size: 20,
                                      ),
                                  ],
                                ),
                               ),
                            ),
                          ),
                        );
                      }).toList(),
                      ),
                    ),
                  ),
                if (!isSmallScreen) const Spacer(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GrowingPlantPainter extends CustomPainter {
  final double growthProgress;
  final bool isWilting;

  GrowingPlantPainter({required this.growthProgress, required this.isWilting});

  // Convenience colour helpers
  Color get _green => isWilting
      ? SeedlingColors.error.withValues(alpha: 0.75)
      : SeedlingColors.seedlingGreen;
  Color get _leafGreen => isWilting
      ? SeedlingColors.error.withValues(alpha: 0.45)
      : SeedlingColors.freshSprout;

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = (size.width / 2.0).roundToDouble();
    final baseY = (size.height - 20.0).roundToDouble();
    final p     = growthProgress.clamp(0.0, 1.0);

    // ── Pot ──────────────────────────────────────────────────────────────
    _drawPot(canvas, cx, baseY);

    if (p <= 0) return;

    // ── Stem ─────────────────────────────────────────────────────────────
    final maxStemH  = size.height * 0.65;
    final stemH     = (maxStemH * p).roundToDouble();
    final tipX      = cx;
    final tipY      = (baseY - stemH).roundToDouble();

    // Gentle natural sway using a quadratic bezier
    final ctrlX = (cx + 8.0 * math.sin(p * math.pi)).roundToDouble();
    final ctrlY = (baseY - stemH * 0.55).roundToDouble();

    final stemPath = Path()
      ..moveTo(cx, baseY - 10)
      ..quadraticBezierTo(ctrlX, ctrlY, tipX, tipY);

    final stemPaint = Paint()
      ..color  = _green
      ..style  = PaintingStyle.stroke
      ..strokeWidth = (5.0 * p).clamp(2.0, 5.0)
      ..strokeCap   = StrokeCap.round;

    canvas.drawPath(stemPath, stemPaint);

    // ── Leaves — appear after 30% growth ─────────────────────────────────
    if (p > 0.3) {
      final leafP = ((p - 0.3) / 0.7).clamp(0.0, 1.0);
      // Left leaf ~ 40% up the stem
      final leaf1Y = (baseY - stemH * 0.42).roundToDouble();
      _drawOvalLeaf(canvas, cx, leaf1Y, leafP, isLeft: true);
      // Right leaf ~ 65% up
      if (leafP > 0.35) {
        final leaf2P = ((leafP - 0.35) / 0.65).clamp(0.0, 1.0);
        final leaf2Y = (baseY - stemH * 0.68).roundToDouble();
        _drawOvalLeaf(canvas, cx, leaf2Y, leaf2P, isLeft: false);
      }
    }

    // ── Sprout tip — two tiny leaves at the very top ─────────────────────
    if (p > 0.7) {
      final sproutP = ((p - 0.7) / 0.3).clamp(0.0, 1.0);
      _drawSproutTip(canvas, tipX, tipY, sproutP);
    }
  }

  void _drawPot(Canvas canvas, double cx, double ground) {
    // Pot body (trapezoid)
    const potW  = 44.0;
    const potH  = 28.0;
    const rimW  = potW + 10.0;

    final potPaint = Paint()
      ..color = SeedlingColors.soil
      ..style = PaintingStyle.fill;

    final rimPaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // Rim strip
    final rimPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, ground + 3), width: rimW, height: 8),
          const Radius.circular(4),
        ),
      );
    canvas.drawPath(rimPath, rimPaint);

    // Trapezoidal pot
    final potPath = Path()
      ..moveTo(cx - rimW / 2, ground + 3)
      ..lineTo(cx - potW / 2, ground + potH)
      ..lineTo(cx + potW / 2, ground + potH)
      ..lineTo(cx + rimW / 2, ground + 3)
      ..close();
    canvas.drawPath(potPath, potPaint);

    // Soil at top of pot
    final soilPaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, ground + 2), width: rimW, height: 10),
      soilPaint,
    );
  }

  void _drawOvalLeaf(Canvas canvas, double stemX, double leafY, double t, {required bool isLeft}) {
    if (t <= 0) return;
    final side   = isLeft ? -1.0 : 1.0;
    final angle  = side * (0.6 + 0.1 * t);
    final leafW  = (22.0 * t).roundToDouble();
    final leafH  = (11.0 * t).roundToDouble();

    canvas.save();
    canvas.translate(stemX, leafY);
    canvas.rotate(angle);

    final paint = Paint()
      ..color = _leafGreen.withValues(alpha: t.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * leafW * 0.45, 0),
        width: leafW,
        height: leafH,
      ),
      paint,
    );

    canvas.restore();
  }

  void _drawSproutTip(Canvas canvas, double tipX, double tipY, double t) {
    if (t <= 0) return;
    final h = (16.0 * t).roundToDouble();
    final w = (7.0  * t).roundToDouble();

    final paint = Paint()
      ..color = _green.withValues(alpha: t.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    // Left sprout arc
    canvas.save();
    canvas.translate(tipX - 3, tipY);
    canvas.rotate(-0.45);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -h / 2), width: w, height: h), paint);
    canvas.restore();

    // Right sprout arc
    canvas.save();
    canvas.translate(tipX + 3, tipY);
    canvas.rotate(0.45);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -h / 2), width: w, height: h), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GrowingPlantPainter oldDelegate) =>
      oldDelegate.growthProgress != growthProgress ||
      oldDelegate.isWilting != isWilting;
}


// ================ QUIZ TYPE 2: SWIPE TO NOURISH ================
// Swipe correct meaning into the plant

class SwipeToNourishQuiz extends StatefulWidget {
  final Word word;
  final List<String> options;
  final void Function(
    bool correct,
    int masteryGained, [
    String? chosenWrongTranslation,
  ])
  onAnswer;

  const SwipeToNourishQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<SwipeToNourishQuiz> createState() => _SwipeToNourishQuizState();
}

class _SwipeToNourishQuizState extends State<SwipeToNourishQuiz>
    with TickerProviderStateMixin {
  late AnimationController _absorbController;
  late AnimationController _rejectController;
  late AnimationController _entryController;
  late Animation<double> _entryFade;
  late Animation<double> _entrySlide;
  String? _draggedOption;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();

    // Auto-play ultra high-end TTS on initial appearance
    TtsService.instance.speak(
      widget.word.ttsWord,
      widget.word.targetLanguageCode,
    );

    _absorbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _rejectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entrySlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _absorbController.dispose();
    _rejectController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _handleAccept(String option) {
    if (_hasAnswered) return;

    final isCorrect = option == widget.word.translation;

    setState(() {
      _hasAnswered = true;
      _draggedOption = option;
    });

    if (isCorrect) {
      _absorbController.forward(from: 0);
      AudioService.instance.playCorrect();
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _rejectController.forward(from: 0);
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isVerySmall = screenSize.height < 620;

    return FadeTransition(
      opacity: _entryFade,
      child: AnimatedBuilder(
        animation: _entrySlide,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _entrySlide.value.roundToDouble()),
          child: child,
        ),
        child: Stack(
          children: [
            // Plant Container (Drop Target)
            Positioned(
              top: screenSize.height * (isVerySmall ? 0.08 : 0.15),
              left: 0,
              right: 0,
              child: DragTarget<String>(
                onWillAcceptWithDetails: (_) => !_hasAnswered,
                onAcceptWithDetails: (details) => _handleAccept(details.data),
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;

                  return AnimatedBuilder(
                    animation: Listenable.merge([
                      _absorbController,
                      _rejectController,
                    ]),
                    builder: (context, child) {
                      final hoverScale = isHovering && !_hasAnswered
                          ? 0.05
                          : 0.0;
                      final scale =
                          1.0 +
                          hoverScale +
                          (_absorbController.value * 0.2) -
                          (_rejectController.value * 0.1);
                      final shake = _rejectController.value > 0
                          ? (math.sin(
                                      _rejectController.value * math.pi * 10.0,
                                    ) *
                                    10.0)
                                .roundToDouble()
                          : 0.0;

                      return Transform.translate(
                        offset: Offset(shake, 0),
                        child: Transform.scale(
                          scale: scale,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Glow indicator when hovering over plant
                              if (isHovering && !_hasAnswered)
                                Positioned(
                                  top: 20,
                                  child: Container(
                                    width: isVerySmall ? 100 : 140,
                                    height: isVerySmall ? 100 : 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: SeedlingColors.water.withValues(
                                        alpha: 0.1,
                                      ),
                                      border: Border.all(
                                        color: SeedlingColors.water.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                ),
                              CustomPaint(
                                size: Size(
                                  screenSize.width,
                                  isVerySmall ? 150 : 200,
                                ),
                                painter: NourishPlantPainter(
                                  nourishmentLevel: isHovering && !_hasAnswered
                                      ? math.max(0.15, _absorbController.value)
                                      : _absorbController.value,
                                  isRejecting: _rejectController.value > 0,
                                  isVerySmall: isVerySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Word Display
            Positioned(
              top: screenSize.height * (isVerySmall ? 0.01 : 0.02),
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(isVerySmall ? 12 : 20),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.1,
                      ),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Drag the meaning to nourish',
                      style: SeedlingTypography.caption.copyWith(
                        fontSize: isVerySmall ? 10 : 12,
                      ),
                    ),
                    SizedBox(height: isVerySmall ? 4 : 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TargetWordDisplay(
                          word: widget.word,
                          style: SeedlingTypography.heading1.copyWith(
                            fontSize: isVerySmall ? 26 : 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.volume_up_rounded,
                            color: SeedlingColors.seedlingGreen,
                            size: isVerySmall ? 22 : 24,
                          ),
                          onPressed: () => TtsService.instance.speak(
                            widget.word.ttsWord,
                            widget.word.targetLanguageCode,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Draggable Options
            Positioned(
              bottom: isVerySmall ? 20 : 100,
              left: 20,
              right: 20,
              child: Column(
                children: widget.options.map((option) {
                  final isDragged = _draggedOption == option;
                  final isDraggingAny = _draggedOption != null;

                  if (isDragged && _hasAnswered) {
                    return SizedBox(height: isVerySmall ? 50 : 60);
                  }

                  return Draggable<String>(
                    data: option,
                    onDragStarted: () {
                      setState(() => _draggedOption = option);
                    },
                    onDraggableCanceled: (_, __) {
                      if (!_hasAnswered) {
                        setState(() => _draggedOption = null);
                      }
                    },
                    onDragEnd: (details) {
                      if (!_hasAnswered && !details.wasAccepted) {
                        setState(() => _draggedOption = null);
                      }
                    },
                    feedback: Material(
                      color: Colors.transparent,
                      child: TiltCard(
                        maxTiltAngle: 0.20,
                        child: Transform.scale(
                          scale: 1.06,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isVerySmall ? 20 : 30,
                              vertical: isVerySmall ? 10 : 15,
                            ),
                            decoration: BoxDecoration(
                              color: SeedlingColors.seedlingGreen,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: SeedlingColors.seedlingGreen
                                      .withValues(alpha: 0.5),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Text(
                              option,
                              style: SeedlingTypography.bodyLarge.copyWith(
                                color: SeedlingColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: isVerySmall ? 14 : 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.0,
                      child: _buildOptionCard(option, isVerySmall),
                    ),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: (isDraggingAny && !isDragged) ? 0.0 : 1.0,
                      child: _buildOptionCard(option, isVerySmall),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(String option, bool isVerySmall) {
    return Container(
      margin: EdgeInsets.only(bottom: isVerySmall ? 8 : 12),
      padding: EdgeInsets.symmetric(
        vertical: isVerySmall ? 12 : 18,
        horizontal: isVerySmall ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drag_indicator,
            color: SeedlingColors.textSecondary,
            size: isVerySmall ? 18 : 20,
          ),
          SizedBox(width: isVerySmall ? 8 : 10),
          Text(
            option,
            style: SeedlingTypography.bodyLarge.copyWith(
              fontSize: isVerySmall ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }
}

class NourishPlantPainter extends CustomPainter {
  final double nourishmentLevel;
  final bool isRejecting;
  final bool isVerySmall;

  NourishPlantPainter({
    required this.nourishmentLevel,
    required this.isRejecting,
    this.isVerySmall = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = (size.width / 2.0).roundToDouble();
    final groundY = (size.height - 30.0).roundToDouble();

    // Draw glow effect when nourished
    if (nourishmentLevel > 0) {
      final radius = (60.0 + (nourishmentLevel * 20.0)).roundToDouble();
      final glowPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                SeedlingColors.sunlight.withValues(
                  alpha: nourishmentLevel * 0.3,
                ),
                SeedlingColors.sunlight.withValues(alpha: 0.0),
              ],
              stops: const [0.5, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: Offset(centerX, (groundY - 60.0).roundToDouble()),
                radius: radius + 20.0,
              ),
            );

      canvas.drawCircle(
        Offset(centerX, (groundY - 60.0).roundToDouble()),
        radius + 20.0,
        glowPaint,
      );
    }

    // ── Pot ──────────────────────────────────────────────────────────────
    _drawPot(canvas, centerX, groundY);

    if (nourishmentLevel <= 0) return;

    // ── Plant Sprout ───────────────────────────────────────────────────
    final stemHeight = (100.0 * (0.4 + nourishmentLevel * 0.6)).roundToDouble();
    final tipX = centerX;
    final tipY = (groundY - stemHeight).roundToDouble();

    final stemPaint = Paint()
      ..color = isRejecting ? SeedlingColors.error : SeedlingColors.seedlingGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(centerX, groundY - 10)
      ..quadraticBezierTo(
        centerX + 5,
        groundY - stemHeight * 0.5,
        tipX,
        tipY,
      );
    canvas.drawPath(stemPath, stemPaint);

    // Leaves
    final leafPaint = Paint()
      ..color = isRejecting ? SeedlingColors.error.withValues(alpha: 0.5) : SeedlingColors.freshSprout
      ..style = PaintingStyle.fill;

    if (nourishmentLevel > 0.2) {
      _drawSimpleLeaf(canvas, centerX, groundY - stemHeight * 0.4, -0.6, 20, leafPaint);
      _drawSimpleLeaf(canvas, centerX, groundY - stemHeight * 0.7, 0.6, 16, leafPaint);
    }
  }

  void _drawPot(Canvas canvas, double cx, double ground) {
    const potW = 44.0;
    const potH = 28.0;
    const rimW = potW + 10.0;
    final potPaint = Paint()..color = SeedlingColors.soil;
    final rimPaint = Paint()..color = SeedlingColors.deepRoot.withValues(alpha: 0.4);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, ground + 3), width: rimW, height: 8), const Radius.circular(4)), rimPaint);
    final potPath = Path()
      ..moveTo(cx - rimW / 2, ground + 3)
      ..lineTo(cx - potW / 2, ground + potH)
      ..lineTo(cx + potW / 2, ground + potH)
      ..lineTo(cx + rimW / 2, ground + 3)
      ..close();
    canvas.drawPath(potPath, potPaint);
  }

  void _drawSimpleLeaf(Canvas canvas, double x, double y, double angle, double size, Paint paint) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.drawOval(Rect.fromCenter(center: Offset(size * 0.45 * (angle < 0 ? -1 : 1), 0), width: size, height: size * 0.5), paint);
    canvas.restore();
  }


  @override
  bool shouldRepaint(covariant NourishPlantPainter oldDelegate) =>
      oldDelegate.nourishmentLevel != nourishmentLevel ||
      oldDelegate.isRejecting != isRejecting;
}

// ================ QUIZ TYPE 3: CATCH THE RIGHT LEAF ================
// Tap the right option before it fades

class CatchTheLeafQuiz extends StatefulWidget {
  final Word word;
  final List<String> options;
  final void Function(
    bool correct,
    int masteryGained, [
    String? chosenWrongTranslation,
  ])
  onAnswer;

  const CatchTheLeafQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<CatchTheLeafQuiz> createState() => _CatchTheLeafQuizState();
}

class _CatchTheLeafQuizState extends State<CatchTheLeafQuiz>
    with TickerProviderStateMixin {
  late List<AnimationController> _floatControllers;
  late List<Offset> _positions;
  late List<Offset> _velocities;
  late AnimationController _entryController;
  late Animation<double> _entryFade;
  late Animation<double> _entrySlide;
  bool _hasAnswered = false;
  int? _caughtIndex;
  Timer? _gameTimer;

  @override
  void initState() {
    super.initState();

    // Auto-play ultra high-end TTS on initial appearance
    TtsService.instance.speak(
      widget.word.ttsWord,
      widget.word.targetLanguageCode,
    );

    _floatControllers = List.generate(
      widget.options.length,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2000 + (index * 500)),
      )..repeat(),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entrySlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();

    // Fading and timer logic removed for a more relaxed experience.

    // Random positions and velocities
    final random = math.Random();
    _positions = List.generate(
      widget.options.length,
      (index) => Offset(
        0.2 + (random.nextDouble() * 0.6),
        0.3 + (random.nextDouble() * 0.4),
      ),
    );

    _velocities = List.generate(
      widget.options.length,
      (index) => Offset(
        (random.nextDouble() - 0.5) * 0.006,
        (random.nextDouble() - 0.5) * 0.006,
      ),
    );

    // Game loop for movement only
    _gameTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          // Update positions
          for (int i = 0; i < _positions.length; i++) {
            _positions[i] = Offset(
              (_positions[i].dx + _velocities[i].dx).clamp(0.1, 0.9),
              (_positions[i].dy + _velocities[i].dy).clamp(0.2, 0.8),
            );

            // Bounce off edges
            if (_positions[i].dx <= 0.1 || _positions[i].dx >= 0.9) {
              _velocities[i] = Offset(-_velocities[i].dx, _velocities[i].dy);
            }
            if (_positions[i].dy <= 0.2 || _positions[i].dy >= 0.8) {
              _velocities[i] = Offset(_velocities[i].dx, -_velocities[i].dy);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _floatControllers) {
      controller.dispose();
    }
    _gameTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  void _handleCatch(int index) {
    if (_hasAnswered) return;

    _gameTimer?.cancel();

    final isCorrect = widget.options[index] == widget.word.translation;

    setState(() {
      _hasAnswered = true;
      _caughtIndex = index;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 2 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isVerySmall = size.height < 620;

    return FadeTransition(
      opacity: _entryFade,
      child: AnimatedBuilder(
        animation: _entrySlide,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _entrySlide.value.roundToDouble()),
          child: child,
        ),
        child: Column(
          children: [
            SizedBox(height: isVerySmall ? 10 : 20),

            // Word Display
            Container(
              padding: EdgeInsets.all(isVerySmall ? 12 : 20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: SeedlingColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'Catch the meaning!',
                    style: SeedlingTypography.caption.copyWith(
                      fontSize: isVerySmall ? 10 : 12,
                    ),
                  ),
                  SizedBox(height: isVerySmall ? 4 : 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TargetWordDisplay(
                        word: widget.word,
                        style: SeedlingTypography.heading1.copyWith(
                          fontSize: isVerySmall ? 28 : 36,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.volume_up_rounded,
                          color: SeedlingColors.seedlingGreen,
                          size: isVerySmall ? 22 : 24,
                        ),
                        onPressed: () => TtsService.instance.speak(
                          widget.word.ttsWord,
                          widget.word.targetLanguageCode,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: isVerySmall ? 10 : 20),

            // Game Area
            Expanded(
              child: Stack(
                children: [
                  // Background wind effect
                  CustomPaint(
                    size: Size(size.width, size.height * 0.6),
                    painter: WindEffectPainter(
                      progress: _floatControllers[0].value,
                    ),
                  ),

                  // Floating Leaves
                  ...widget.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final position = _positions[index];

                    return AnimatedBuilder(
                      animation: _floatControllers[index],
                      builder: (context, child) {
                        final floatOffset =
                            math.sin(
                              _floatControllers[index].value * math.pi * 2.0,
                            ) *
                            4.0;

                        const opacity = 1.0;

                        final isCaught = _caughtIndex == index;
                        final isCorrect = option == widget.word.translation;

                        Color leafColor = SeedlingColors.freshSprout;
                        if (_hasAnswered) {
                          if (isCorrect) {
                            leafColor = SeedlingColors.success;
                          } else if (isCaught && !isCorrect) {
                            leafColor = SeedlingColors.error;
                          }
                        }

                        return Positioned(
                          left:
                              (position.dx * size.width -
                                      (isVerySmall ? 50.0 : 60.0))
                                  .roundToDouble(),
                          top: (position.dy * size.height * 0.5 + floatOffset)
                              .roundToDouble(),
                          child: GestureDetector(
                            onTap: () => _handleCatch(index),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isCaught ? 0.0 : opacity,
                              child: Transform.scale(
                                scale: isCaught ? 1.5 : 1.0,
                                child: SizedBox(
                                  width: isVerySmall ? 100 : 120,
                                  height: isVerySmall ? 66 : 80,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.rotate(
                                        angle:
                                            _floatControllers[index].value *
                                            0.05,
                                        child: RepaintBoundary(
                                          child: CustomPaint(
                                            size: Size(
                                              isVerySmall ? 100 : 120,
                                              isVerySmall ? 66 : 80,
                                            ),
                                            painter: FloatingWordLeafPainter(
                                              color: leafColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        option,
                                        textAlign: TextAlign.center,
                                        style: SeedlingTypography.bodyLarge
                                            .copyWith(
                                              color: SeedlingColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: isVerySmall ? 12 : 14,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WindEffectPainter extends CustomPainter {
  final double progress;

  WindEffectPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SeedlingColors.morningDew.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      final y = (size.height * (0.2 + i * 0.3)).roundToDouble();
      final path = Path();

      path.moveTo(0, y);
      for (double x = 0.0; x < size.width; x += 50.0) {
        path.quadraticBezierTo(
          (x + 25.0).roundToDouble(),
          (y + math.sin((x / size.width + progress) * math.pi * 2.0) * 10.0).roundToDouble(),
          (x + 50.0).roundToDouble(),
          y,
        );
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WindEffectPainter oldDelegate) => true;
}

class FloatingWordLeafPainter extends CustomPainter {
  final Color color;

  FloatingWordLeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate((size.width / 2.0).roundToDouble(), (size.height / 2.0).roundToDouble());

    // Draw leaf shape
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, (-size.height / 2.0).roundToDouble())
      ..quadraticBezierTo(
        (-size.width / 2.0).roundToDouble(),
        (-size.height / 4.0).roundToDouble(),
        (-size.width / 3.0).roundToDouble(),
        0,
      )
      ..quadraticBezierTo(
        (-size.width / 4.0).roundToDouble(),
        (size.height / 4.0).roundToDouble(),
        0,
        (size.height / 2.0).roundToDouble(),
      )
      ..quadraticBezierTo(
        (size.width / 4.0).roundToDouble(),
        (size.height / 4.0).roundToDouble(),
        (size.width / 3.0).roundToDouble(),
        0,
      )
      ..quadraticBezierTo(
        (size.width / 2.0).roundToDouble(),
        (-size.height / 4.0).roundToDouble(),
        0,
        (-size.height / 2.0).roundToDouble(),
      );

    // Hardware-accelerated Shadow
    canvas.save();
    canvas.translate(4, 4);
    canvas.drawShadow(
      path,
      SeedlingColors.deepRoot.withValues(alpha: 0.35),
      6.0,
      false,
    );
    canvas.restore();

    // Leaf
    canvas.drawPath(path, paint);

    // Vein
    final veinPaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(0, (-size.height / 2.0 + 10.0).roundToDouble()),
      Offset(0, (size.height / 2.0 - 10.0).roundToDouble()),
      veinPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FloatingWordLeafPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ================ QUIZ TYPE 4: BUILD THE TREE ================
// Connect words into meaning clusters

class BuildTheTreeQuiz extends StatefulWidget {
  final List<Word> words;
  final void Function(int correctConnections, int totalConnections) onComplete;

  const BuildTheTreeQuiz({
    super.key,
    required this.words,
    required this.onComplete,
  });

  @override
  State<BuildTheTreeQuiz> createState() => _BuildTheTreeQuizState();
}

class _BuildTheTreeQuizState extends State<BuildTheTreeQuiz>
    with TickerProviderStateMixin {
  late List<Word> _shuffledWords;
  late List<String> _shuffledTranslations;
  final List<int> _connections = [];
  int? _selectedWordIndex;
  int _correctConnections = 0;
  late AnimationController _growController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _shuffledWords = List.from(widget.words)..shuffle();
    _shuffledTranslations = _shuffledWords.map((w) => w.translation).toList()
      ..shuffle();

    _growController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _growController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleWordTap(int index) {
    setState(() {
      // Always play TTS if tapping a translation's target word node (left side)
      if (index < _shuffledWords.length) {
        final w = _shuffledWords[index];
        TtsService.instance.speak(w.word, w.targetLanguageCode);
      }

      if (_selectedWordIndex == null) {
        _selectedWordIndex = index;
      } else if (_selectedWordIndex == index) {
        _selectedWordIndex = null;
      } else {
        // Try to connect (if one is from left and one from right side)
        final isLeft1 = _selectedWordIndex! < _shuffledWords.length;
        final isLeft2 = index < _shuffledWords.length;

        if (isLeft1 != isLeft2) {
          final wordIdx = isLeft1 ? _selectedWordIndex! : index;
          final transIdx = isLeft1
              ? index - _shuffledWords.length
              : _selectedWordIndex! - _shuffledWords.length;
          _attemptConnection(wordIdx, transIdx);
        }
        _selectedWordIndex = null;
      }
    });
  }

  void _attemptConnection(int wordIndex, int translationIndex) {
    final word = _shuffledWords[wordIndex];
    final translation = _shuffledTranslations[translationIndex];

    if (word.translation == translation) {
      // Check if already connected
      if (_connections.contains(wordIndex) ||
          _connections.contains(translationIndex + _shuffledWords.length)) {
        return;
      }

      setState(() {
        _connections.add(wordIndex);
        _connections.add(translationIndex + _shuffledWords.length);
        _correctConnections++;
      });

      _growController.forward(from: 0);

      if (_correctConnections >= widget.words.length) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            widget.onComplete(_correctConnections, widget.words.length);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                'Build the Knowledge Tree',
                style: SeedlingTypography.heading2,
              ),
              const SizedBox(height: 5),
              Text(
                'Connect words to their meanings',
                style: SeedlingTypography.caption,
              ),
              const SizedBox(height: 15),
              StemProgressBar(
                progress: _correctConnections / widget.words.length,
                height: 8,
              ),
            ],
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxHeight < 500;
              final nodeCount = _shuffledWords.length;
              final spacing =
                  (constraints.maxHeight - 120) / (nodeCount - 1).clamp(1, 10);
              final itemSpacing = spacing.clamp(50.0, 110.0);
              final startTop = isSmallScreen ? 20.0 : 40.0;

              return AnimatedBuilder(
                animation: Listenable.merge([
                  _growController,
                  _pulseController,
                ]),
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: KnowledgeTreePainter(
                      words: _shuffledWords.map((w) => w.word).toList(),
                      translations: _shuffledTranslations,
                      connections: _connections,
                      selectedIndex: _selectedWordIndex,
                      growthProgress: _growController.value,
                      pulseValue: _pulseController.value,
                      isSmallScreen: isSmallScreen,
                      itemSpacing: itemSpacing,
                      startTop: startTop,
                    ),
                    child: Stack(
                      children: [
                        // Word nodes (left side)
                        ..._shuffledWords.asMap().entries.map((entry) {
                          final index = entry.key;
                          final word = entry.value;
                          final isConnected = _connections.contains(index);
                          final isSelected = _selectedWordIndex == index;

                          return Positioned(
                            left: isSmallScreen ? 15 : 30,
                            top: startTop + (index * itemSpacing),
                            child: GestureDetector(
                              onTap: () => _handleWordTap(index),
                              child: _buildTreeNode(
                                word.word,
                                isConnected,
                                isSelected,
                                true,
                                isSmallScreen,
                              ),
                            ),
                          );
                        }),

                        // Translation nodes (right side)
                        ..._shuffledTranslations.asMap().entries.map((entry) {
                          final index = entry.key + _shuffledWords.length;
                          final translation = entry.value;
                          final isConnected = _connections.contains(index);
                          final isSelected = _selectedWordIndex == index;

                          return Positioned(
                            right: isSmallScreen ? 15 : 30,
                            top:
                                startTop +
                                ((index - _shuffledWords.length) * itemSpacing),
                            child: GestureDetector(
                              onTap: () => _handleWordTap(index),
                              child: _buildTreeNode(
                                translation,
                                isConnected,
                                isSelected,
                                false,
                                isSmallScreen,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTreeNode(
    String text,
    bool isConnected,
    bool isSelected,
    bool isLeft,
    bool isSmallScreen,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 20,
        vertical: isSmallScreen ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: isConnected
            ? SeedlingColors.success.withValues(alpha: 0.2)
            : isSelected
            ? SeedlingColors.seedlingGreen.withValues(alpha: 0.2)
            : SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 20),
        border: Border.all(
          color: isConnected
              ? SeedlingColors.success
              : isSelected
              ? SeedlingColors.seedlingGreen
              : SeedlingColors.morningDew.withValues(alpha: 0.3),
          width: isConnected || isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: SeedlingTypography.body.copyWith(
          fontSize: isSmallScreen ? 13 : 15,
          fontWeight: isConnected || isSelected
              ? FontWeight.w600
              : FontWeight.normal,
          color: isConnected
              ? SeedlingColors.success
              : isSelected
              ? SeedlingColors.seedlingGreen
              : SeedlingColors.textPrimary,
        ),
      ),
    );
  }
}

class KnowledgeTreePainter extends CustomPainter {
  final List<String> words;
  final List<String> translations;
  final List<int> connections;
  final int? selectedIndex;
  final double growthProgress;
  final double pulseValue;
  final bool isSmallScreen;
  final double itemSpacing;
  final double startTop;

  KnowledgeTreePainter({
    required this.words,
    required this.translations,
    required this.connections,
    required this.selectedIndex,
    required this.growthProgress,
    required this.pulseValue,
    this.isSmallScreen = false,
    this.itemSpacing = 100.0,
    this.startTop = 80.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeCenterOffset = (isSmallScreen ? 15.0 : 20.0).roundToDouble();

    // Draw connections
    for (int i = 0; i < connections.length; i += 2) {
      final wordIndex = connections[i];
      final transIndex = connections[i + 1];

      final startX = ((isSmallScreen ? 15.0 : 30.0) + 60.0).roundToDouble();
      final startY = (startTop + (wordIndex * itemSpacing) + nodeCenterOffset).roundToDouble();
      final endX = (size.width - ((isSmallScreen ? 15.0 : 30.0) + 60.0)).roundToDouble();
      final endY =
          (startTop +
          ((transIndex - words.length) * itemSpacing) +
          nodeCenterOffset).roundToDouble();

      // Animate growth
      final progress = (growthProgress + (i / connections.length) * 0.3).clamp(
        0.0,
        1.0,
      );
      final currentEndX = (startX + (endX - startX) * progress).roundToDouble();
      final currentEndY = (startY + (endY - startY) * progress).roundToDouble();

      final paint = Paint()
        ..color = SeedlingColors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      // Draw root-like connection
      final path = Path()
        ..moveTo(startX, startY)
        ..cubicTo(
          (startX + 50.0).roundToDouble(),
          startY,
          (currentEndX - 50.0).roundToDouble(),
          currentEndY,
          currentEndX,
          currentEndY,
        );

      canvas.drawPath(path, paint);

      // Draw glow at connection point
      if (progress >= 1.0) {
        final glowPaint = Paint()
          ..shader =
              RadialGradient(
                colors: [
                  SeedlingColors.success.withValues(alpha: 0.3 * pulseValue),
                  SeedlingColors.success.withValues(alpha: 0.0),
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(currentEndX, currentEndY),
                  radius: 20.0,
                ),
              );

        canvas.drawCircle(Offset(currentEndX, currentEndY), 20.0, glowPaint);
      }
    }

    // Draw selection preview line
    if (selectedIndex != null) {
      final isWordSide = selectedIndex! < words.length;
      final offset = (isSmallScreen ? 15.0 : 30.0) + 60.0;
      final startX = isWordSide ? offset : size.width - offset;
      final startY =
          startTop +
          ((isWordSide ? selectedIndex! : selectedIndex! - words.length) *
              itemSpacing) +
          nodeCenterOffset;

      final paint = Paint()
        ..color = SeedlingColors.seedlingGreen.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      // Dashed line effect
      const totalDashes = 10;

      for (int i = 0; i < totalDashes; i++) {
        final t = i / totalDashes;
        final nextT = (i + 0.5) / totalDashes;

        final x1 = startX + (isWordSide ? 1 : -1) * t * 100;
        final y1 = startY;
        final x2 = startX + (isWordSide ? 1 : -1) * nextT * 100;
        final y2 = startY;

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant KnowledgeTreePainter oldDelegate) =>
      oldDelegate.connections != connections ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.growthProgress != growthProgress ||
      oldDelegate.pulseValue != pulseValue;
}

// ================================================================
// ADAPTIVE LEARNING ENGINE
// ================================================================
// Design principles:
//  • All 8 quiz types rotate using a Fisher-Yates shuffled pool.
//  • NEW words appear up to 4×: they're re-inserted at increasing
//    intervals (Leitner-within-session). Wrong answers bring any
//    word back sooner for immediate reinforcement.
//  • Planting moment is adaptive: a ReadinessScore (0-100) is
//    calculated per-turn from accuracy, streak, difficulty, and
//    words-completed. Word is introduced when score >= 60.
//  • Multi-word milestone quizzes (BuildTheTree, RootNetwork) fire
//    every 6th quiz turn, consuming up to 4 words at once.
// ================================================================

// ---------- Data model ----------

enum _CardKind {
  reviewWord, // SRS-due word (appears once unless wrong)
  newWordRound, // New word's scheduled appearance (up to 4 total)
}

class _SessionCard {
  final String
  sessionId; // Unique for THIS session instance to prevent widget state reuse
  final Word word;
  final _CardKind kind;
  int step; // for newWordRound: 0-3; for reviewWord: always 0

  _SessionCard({
    required this.sessionId,
    required this.word,
    required this.kind,
    this.step = 0,
  });
}

// ---------- Adaptive Queue ----------

class _AdaptiveQueue {
  final List<_SessionCard> _queue = [];

  /// Returns all unique words currently being reviewed or pending (queued).
  List<Word> get allWords {
    final activeWords = _queue.map((c) => c.word).toList();
    return [...activeWords, ...pendingNewWords];
  }

  final math.Random _rng = math.Random();

  int totalAnswered = 0;
  int totalCorrect = 0;
  int streak = 0; // consecutive correct answers
  int reviewDone = 0; // number of review words completed

  // ── SILE: Pending new-word candidate queue ────────────────────────────────
  // Pre-loaded from the session conductor. Words are popped one at a time
  // when the CLS gate passes. Only ONE new word drills at a time.
  final Queue<Word> pendingNewWords = Queue<Word>();
  // Tracks the number of new-word drills currently in steps 0-3.
  // Using a counter (not a bool) ensures that graduating one word out of
  // three simultaneous drills does NOT prematurely open the CLS gate.
  int _activeNewWordCount = 0;

  /// True while any new-word Pimsleur drill is in progress.
  bool get newWordInProgress => _activeNewWordCount > 0;

  /// Allows legacy direct assignment (e.g., safety reset in _checkDone).
  set newWordInProgress(bool value) {
    _activeNewWordCount = value ? math.max(1, _activeNewWordCount) : 0;
  }

  int _nextCardId = 0;
  String _generateId() => 'card_${_nextCardId++}';

  _SessionCard _createCard({
    required Word word,
    required _CardKind kind,
    int step = 0,
  }) {
    return _SessionCard(
      sessionId: _generateId(),
      word: word,
      kind: kind,
      step: step,
    );
  }

  // ── UVLS: CLS tracking state ─────────────────────────────────────────────
  DateTime? sessionStartTime; // set by QuizManager when session begins
  final List<bool> _recentAnswers = []; // ring-buffer of last 5 answers
  int _turnsSinceNewWord = 999; // how many turns since last Step-0 injection
  bool hasWiltedWord = false; // true while a re-learn card is in the queue
  int wordsMastered = 0; // words that completed all 4 steps this session

  // ── Queue management ─────────────────────────────────────────────

  void seedReviewWords(List<Word> words) {
    if (words.isEmpty) return;

    final newCards = words
        .map((w) => _createCard(word: w, kind: _CardKind.reviewWord))
        .toList();
    newCards.shuffle(_rng);

    _queue.addAll(newCards);
  }

  /// Schedule the new word at step 0. True Pimsleur spacing happens progressively
  /// as the user answers correctly in `advance`.
  void injectNewWord(Word word) {
    // Insert immediately at a close position (e.g. index 1 or 2).
    // The very first injection is step 0.
    final pos = math.min(1, _queue.length);
    _queue.insert(
      pos,
      _createCard(word: word, kind: _CardKind.newWordRound, step: 0),
    );
    _activeNewWordCount++; // One more new-word drill is in flight
  }

  /// Pop the next pending new word if one exists.
  Word? popPendingNewWord() {
    if (pendingNewWords.isEmpty) return null;
    return pendingNewWords.removeFirst();
  }

  /// Add new-word candidates to the pre-load queue.
  void enqueuePendingNewWords(List<Word> words) {
    for (final w in words) {
      // Don't add duplicates
      if (!pendingNewWords.any((p) => p.id == w.id)) {
        pendingNewWords.add(w);
      }
    }
  }

  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;

  /// Cards waiting to be shown (used by milestone FSRS + [advanceMultiple]).
  int get length => _queue.length;

  _SessionCard? get current => _queue.isEmpty ? null : _queue.first;

  /// Call after answering the current card.
  void advance({required bool correct, required int timeTakenMs}) {
    if (_queue.isEmpty) return;
    final card = _queue.removeAt(0);

    totalAnswered++;
    if (correct) {
      totalCorrect++;
      streak++;
    } else {
      streak = 0;
    }

    // ── UVLS: Track CLS signals ───────────────────────────────────────────
    _recentAnswers.add(correct);
    if (_recentAnswers.length > 5) _recentAnswers.removeAt(0);
    _turnsSinceNewWord++;

    final isSlow = timeTakenMs > 13000; // 12s + ~1s for animation delays

    if (card.kind == _CardKind.newWordRound) {
      // New-word progressive intervals — UVLS adaptive Pimsleur gaps
      if (correct) {
        if (!isSlow && card.step >= 3) {
          // All 4 passes done — graduated! 🎉
          wordsMastered++;
          // FIX: Decrement counter, not clear flag — other words may still be
          // in progress. CLS gate only opens when ALL drills are done.
          _activeNewWordCount = math.max(0, _activeNewWordCount - 1);
          hasWiltedWord = false; // UVLS: Clear wilted flag on graduation!
          return;
        }

        // Advance step (speed decay: slow → same step number, just smaller gap)
        final nextStep = isSlow ? card.step : card.step + 1;

        // UVLS: adaptive gap (SessionConductor decides the interval)
        final gap = SessionConductor.instance.adaptiveGap(
          step: nextStep < 4 ? nextStep : 3,
          correct: true,
          slow: isSlow,
          queueLength: _queue.length,
        );

        _queue.insert(
          gap,
          _createCard(
            word: card.word,
            kind: _CardKind.newWordRound,
            step: nextStep,
          ),
        );
      } else {
        // Wrong at Step 0: UVLS failure delay — use a longer gap (5) so
        // the system doesn't immediately spam the user with the same word.
        final failureGap = card.step == 0
            ? math.min(5, _queue.length)
            : SessionConductor.instance.adaptiveGap(
                step: card.step,
                correct: false,
                slow: false,
                queueLength: _queue.length,
              );
        _queue.insert(
          failureGap,
          _createCard(
            word: card.word,
            kind: _CardKind.newWordRound,
            step: card.step,
          ),
        );
      }
    } else {
      // Review word logic (Leitner + UVLS wilted-word tracking)
      if (!correct) {
        // Fail-State Regression: re-learn the word from scratch
        hasWiltedWord = true;
        final gap = math.min(1, _queue.length);
        _queue.insert(
          gap,
          _createCard(word: card.word, kind: _CardKind.newWordRound, step: 0),
        );
      } else {
        if (isSlow) {
          // Speed penalty: show once more soon
          final gap = math.min(5, _queue.length);
          _queue.insert(
            gap,
            _createCard(word: card.word, kind: _CardKind.reviewWord),
          );
        } else {
          reviewDone++;
        }
      }
    }
  }

  /// Advance by N cards (used after multi-word milestone quizzes).
  void advanceMultiple(int count, {required int correctCount}) {
    int remainingErrors = count - correctCount;
    // We must collect the words to advance first so we don't accidentally
    // advance a re-inserted word during the loop.
    int limit = math.min(count, _queue.length);
    for (int i = 0; i < limit; i++) {
        // distribute the failures mostly at the beginning
        bool isCorrect = i >= remainingErrors;
        // Delegate to standard advance to ensure UVLS/Pimsleur flags stay pure
        advance(correct: isCorrect, timeTakenMs: 6000);
    }
  }

  /// First [n] cards in the queue (for milestone FSRS — must match [advanceMultiple]).
  List<_SessionCard> snapshotHead(int n) {
    if (n <= 0) return <_SessionCard>[];
    final take = math.min(n, _queue.length);
    return List<_SessionCard>.from(_queue.sublist(0, take));
  }

  /// Returns the card at the given offset from the queue head without removing it.
  _SessionCard? peek(int offset) {
    if (offset >= 0 && offset < _queue.length) {
      return _queue[offset];
    }
    return null;
  }

  // ── UVLS: CLS-based Readiness (replaces old simple score) ──────────────

  /// Returns the Cognitive Load Score (0-100) for the current session state.
  /// Delegates to SessionConductor.computeCLS() for the full 12-signal model.
  double readinessScore(Word candidateWord) {
    final state = SessionState(
      totalAnswered: totalAnswered,
      totalCorrect: totalCorrect,
      streak: streak,
      reviewsDone: reviewDone,
      turnsSinceNewWord: _turnsSinceNewWord,
      sessionStartTime: sessionStartTime ?? DateTime.now(),
      recentAnswers: List<bool>.from(_recentAnswers),
      hasWiltedWord: hasWiltedWord,
    );
    return SessionConductor.instance.computeCLS(
      state,
      candidateWord: candidateWord,
    );
  }

  /// Records that a new word was injected at Step 0. Resets the turn counter.
  void onNewWordInjected() {
    _turnsSinceNewWord = 0;
  }

  /// Clears wilted-word flag after re-planting is complete.
  void clearWiltedWord() {
    hasWiltedWord = false;
  }
}

// ---------- QuizManager Widget ----------

class QuizManager extends StatefulWidget {
  final List<Word> words;
  final List<Word> initialNewWords;

  /// SILE: Pre-loaded new-word candidates. The queue pops one at a time
  /// based on the CLS gate, so multiple words can be pre-loaded each session.
  final List<Word> pendingNewWords;
  final Future<void> Function(Word)? onWordPlanted;
  final void Function(int totalCorrect, int totalQuestions) onProgressUpdate;
  final void Function(Word word, bool correct, int responseMs)? onWordAnswered;
  final VoidCallback onSessionComplete;
  final VoidCallback? onQueueDepleted; // Signal for more words
  final DatabaseHelper? db;
  final String? activeSubDomain;
  final bool strictDistractors;

  const QuizManager({
    super.key,
    required this.words,
    this.initialNewWords = const [],
    this.pendingNewWords = const [],
    this.onWordPlanted,
    required this.onProgressUpdate,
    this.onWordAnswered,
    required this.onSessionComplete,
    this.onQueueDepleted,
    this.db,
    this.activeSubDomain,
    this.strictDistractors = false,
  });

  @override
  State<QuizManager> createState() => QuizManagerState();
}

class QuizManagerState extends State<QuizManager> {
  late final _AdaptiveQueue _queue;
  String _currentQuizType = 'deepRoot';
  // Cache: which word id was the quiz type last determined for.
  int? _lastDeterminedCardId;

  // Cached options to prevent flickering Shuffle-on-Build.
  List<String>? _cachedOptions;
  List<Word>? _cachedObjOptions;
  bool? _cachedShowCorrect;
  String? _cachedDecoy;
  List<String>? _cachedPotOptions;
  List<Word>? _cachedBatchWords;
  String? _cachedCardId; // sessionId of the card used for these options
  String? _cachedQuizTypeGenerated; // type for which options were generated

  // SILE: track planting state per-word (no longer a single flag)
  bool _showPlanting = false;
  Word? _wiltedWordToReplant;
  // The word currently being shown in the planting screen
  Word? _plantingWord;

  // Performance & Distractor Caches
  final Map<int, List<String>> _confusionCache = {};
  final Map<int, List<Word>> _distractorWordCache = {};
  final Map<int, String?> _weakestTypeCache = {};
  final Map<int, Set<String>> _skippedTypesForWord = {}; // wordId -> {quizTypes}

  // Generic fallback distractors — used only when the session pool has zero
  // available distractors (e.g. brand-new first session). These are
  // intentionally diverse common concepts with no phonetic similarity.
  static const List<String> _fallbackDistractors = [
    'always', 'never', 'everywhere', 'nothing',
    'beautiful', 'different', 'important', 'possible',
    'quickly', 'carefully', 'already', 'almost',
    'together', 'outside', 'beneath', 'beyond',
  ];

  late final Stopwatch _stopwatch;
  bool _isFetchingIntelligence = false;
  bool _isProcessingAnswer = false; // Re-entrancy guard

  // ── UVLS: session-level UI state ─────────────────────────────────────────
  bool _showUnlockBanner = false; // show the "New Word Unlocked!" banner
  int _streakMilestoneShown =
      0; // last milestone streak for which overlay shown
  bool _showStreakMilestone = false;
  DateTime? _sessionStartTime;

  /// Returns the current real-time Cognitive Load Score (CLS).


  int get streak => _queue.streak;
  int get wordsMastered => _queue.wordsMastered;
  int get totalCorrect => _queue.totalCorrect;
  int get totalAnswered => _queue.totalAnswered;

  double get currentCls {
    final candidate = _queue.pendingNewWords.isNotEmpty
        ? _queue.pendingNewWords.first
        : null;
    if (candidate == null) return 50.0;
    return _queue.readinessScore(candidate);
  }

  /// Returns all unique words currently in the session (active + pending)
  List<Word> get allWords => _queue.allWords;

  /// Returns all unique word IDs currently in the session
  List<String> get allWordIds => allWords.map((w) => w.id.toString()).toList();

  /// Returns true if the session has any active or pending content.
  bool get hasContent => 
      _queue.isNotEmpty || 
      _queue.pendingNewWords.isNotEmpty || 
      _showPlanting ||
      _plantingWord != null;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _sessionStartTime = DateTime.now();
    _queue = _AdaptiveQueue();

    // ── UVLS: pass session start time to the queue for CLS time-signal ───
    _queue.sessionStartTime = _sessionStartTime;

    // ── SILE: Pre-load new-word candidates into the queue ───────────────
    // Any initial new words (first session: 3 planted words) are injected
    // immediately. Pending candidates are loaded into the FIFO queue and
    // revealed progressively as CLS gates pass.
    for (final initialWord in widget.initialNewWords) {
      _queue.injectNewWord(initialWord);
    }
    _queue.enqueuePendingNewWords(widget.pendingNewWords);

    // ── Warm-Up Ramp: sort review words easiest-first for session warm-up ──
    final orderedWords = IntelligenceService.instance.getSessionWordOrder(
      widget.words,
    );
    _queue.seedReviewWords(orderedWords);

    _currentQuizType = _determineQuizType();

    _preFetchIntelligence(); // Start async intelligence fetch immediately

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeInjectNewWord();
        // Only check for depletion if we actually started with zero words.
        // This prevents immediate replenishment calls during initial loading.
        if (_queue.isEmpty && _queue.pendingNewWords.isEmpty) {
          _checkDone();
        }
      }
    });

    AudioService.instance.play(SFX.quizStart);
    AudioService.haptic(HapticType.tap);
    AudioService.instance.startAmbient();
  }

  /// Fetches best quiz types and confusion records for the next few words in queue
  Future<void> _preFetchIntelligence() async {
    if (widget.db == null || _isFetchingIntelligence) return;
    _isFetchingIntelligence = true;

    try {
      final currentWord = _queue.current?.word;
      if (currentWord != null && currentWord.id != null) {
        // Snapshot the card's session ID before any awaits.
        // After each await we verify the same card is still showing, so a
        // stale async result can never flip the quiz type mid-question.
        final capturedSessionId = _queue.current?.sessionId;

        // Fetch confusion distractors for current word if not cached
        if (!_confusionCache.containsKey(currentWord.id)) {
          final distractors = await widget.db!.getConfusionDistractors(
            currentWord,
            limit: 3,
          );
          _confusionCache[currentWord.id!] = distractors
              .map((w) => w.translation)
              .toList();
        }

        // PRE-FETCH: Intelligent distractors (semantic/POS matched)
        if (!_distractorWordCache.containsKey(currentWord.id)) {
          final distractors = await widget.db!.getIntelligentDistractors(
            currentWord,
            limit: 3,
            strictSubDomain: widget.strictDistractors,
          );
          _distractorWordCache[currentWord.id!] = distractors;
        }

        // Smartly determine the quiz type for THIS specific word based on performance
        final bestType = await IntelligenceService.instance
            .getBestQuizTypeForWord(
              currentWord.id!,
              widget.db!,
              fallbackType: _determineQuizType(),
            );

        // STABILITY FIX: Only apply the new quiz type if the user has not
        // already moved on to a different card while the DB was querying.
        if (mounted &&
            bestType != null &&
            bestType != _currentQuizType &&
            _queue.current?.sessionId == capturedSessionId) {
          setState(() => _currentQuizType = bestType);
        }
      }

      // Lookahead: pre-fetch for the next word too
      final next = _queue.peek(1);
      if (next != null && next.word.id != null) {
        if (!_confusionCache.containsKey(next.word.id)) {
          final distractors = await widget.db!.getConfusionDistractors(
            next.word,
            limit: 3,
          );
          _confusionCache[next.word.id!] = distractors
              .map((w) => w.translation)
              .toList();
        }
        if (!_distractorWordCache.containsKey(next.word.id)) {
          final distractors = await widget.db!.getIntelligentDistractors(
            next.word,
            limit: 3,
            strictSubDomain: widget.strictDistractors,
          );
          _distractorWordCache[next.word.id!] = distractors;
        }
      }
    } finally {
      _isFetchingIntelligence = false;
    }
  }

  Future<void> _updateQuizType() async {
    await _preFetchIntelligence();
  }

  /// Externally push more words and new-word candidates into the active session.
  /// Called by LearningSessionScreen when the queue gets low.
  void replenish({
    required List<Word> moreReviews,
    List<Word> moreNewWords = const [],
  }) {
    if (!mounted) return;
    // STABILITY FIX: Only re-determine the quiz type when the queue was empty
    // before this replenishment. If a question is already on screen, changing
    // _currentQuizType would instantly swap the visible quiz widget.
    final wasEmpty = _queue.isEmpty;
    setState(() {
      if (moreReviews.isNotEmpty) {
        _queue.seedReviewWords(moreReviews);
      }
      // SILE: enqueue additional new-word candidates
      if (moreNewWords.isNotEmpty) {
        _queue.enqueuePendingNewWords(moreNewWords);
      }
      if (wasEmpty) {
        _currentQuizType = _determineQuizType();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeInjectNewWord();
        _checkDone();
      }
    });
  }

  String _determineQuizType() {
    if (_queue.isEmpty) return 'deepRoot';
    final card = _queue.current!;

    // ── DETERMINISM: Only re-roll when the card actually changes ─────────
    final cardId = card.word.id ?? card.word.hashCode;
    if (_lastDeterminedCardId == cardId && _currentQuizType.isNotEmpty) {
      return _currentQuizType;
    }
    _lastDeterminedCardId = cardId;

    // Use a seeded random for deterministic type per word+step in this session
    final rng = math.Random(cardId ^ card.step);

    final isNewWord = card.kind == _CardKind.newWordRound;

    // ── UVLS: Fetch weakest quiz type from cache (if available) ──────────
    final wordId = card.word.id;
    String? weakestType;

    if (wordId != null) {
      if (_weakestTypeCache.containsKey(wordId)) {
        weakestType = _weakestTypeCache[wordId];
      } else {
        // Asynchronously fetch it, but don't block. Will be populated for next turn.
        _weakestTypeCache[wordId] = null; // mark as fetched while pending
        widget.db?.getWeakestQuizType(wordId).then((type) {
          if (mounted && type != null) {
            _weakestTypeCache[wordId] = type;
            // Optionally, we could setState here to force picking it later
          }
        });
      }
    }

    final excluded = (wordId != null) 
        ? _skippedTypesForWord[wordId]?.toList() 
        : null;

    final type = SessionConductor.instance.selectQuizType(
      word: card.word,
      step: card.step,
      isNewWord: isNewWord,
      isRelearn: false, // all re-learn words use newWordRound kind
      dbWeakestType: weakestType,
      turnCount: _queue.totalAnswered,
      rng: rng,
      excludedTypes: excluded,
    );

    debugPrint(
      '[QuizManager] UVLS type for ${card.word.ttsWord}: $type '
      '(mastery:${card.word.masteryLevel} step:${card.step} kind:${card.kind.name})',
    );
    return type;
  }

  // ── SILE: Readiness check ────────────────────────────────────────────────

  void _maybeInjectNewWord() {
    // Nothing to do if no pending words or one is already being drilled
    if (_queue.pendingNewWords.isEmpty || _queue.newWordInProgress) return;

    // ── CLS gate: 3-turn minimum + score >= 70 ───────────────────────────
    final candidateWord = _queue.pendingNewWords.first;
    final cls = _queue.readinessScore(candidateWord);
    final shouldIntroduce = _queue.isEmpty || SessionConductor.instance.shouldIntroduceNewWord(
      cls: cls,
      turnsSinceLastNewWord: _queue._turnsSinceNewWord,
      hasNewWordInProgress: _queue.newWordInProgress,
    );

    debugPrint(
      '[QuizManager] CLS=$cls turns=${_queue._turnsSinceNewWord} introduce=$shouldIntroduce',
    );

    if (shouldIntroduce) {
      final wordToPlant = _queue.popPendingNewWord();
      if (wordToPlant == null) return;

      _queue.onNewWordInjected();
      _plantingWord = wordToPlant;

      setState(() => _showUnlockBanner = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _showUnlockBanner = false;
            _showPlanting = true;
          });
        }
      });
    }
  }

  void _onPlantingComplete() {
    AudioService.instance.play(SFX.wordPlanted);
    AudioService.haptic(HapticType.plant);
    final planted = _plantingWord;
    setState(() {
      _showPlanting = false;
      _plantingWord = null;
            if (planted != null) {
        _queue.injectNewWord(planted);
      }
    });
    widget.onProgressUpdate(_queue.totalCorrect, _queue.totalAnswered);
    _checkDone();
  }

  void _checkDone() {
    final queueEmpty = _queue.isEmpty;
    if (queueEmpty) {
      if (_queue.newWordInProgress || _queue.hasWiltedWord) {
        debugPrint('[QuizManager] Safety mechanism: clearing stuck drill flags.');
        _queue.newWordInProgress = false;
        _queue.clearWiltedWord();
      }
    }
    
    final wPlantingDone = _wiltedWordToReplant == null;
    // SILE: session is "content complete" when queue is empty AND
    // no more pending words AND no word is currently being drilled.
    final noMoreContent =
        queueEmpty &&
        _queue.pendingNewWords.isEmpty &&
        !_queue.newWordInProgress;

    // ── 3-Word Minimum: trigger early replenish before distractors run dry ─
    final uniqueWords = _getAllSessionWords();
    if (uniqueWords.length < 3 &&
        widget.onQueueDepleted != null &&
        !queueEmpty) {
      debugPrint('[QuizManager] <3 session words — pre-emptive replenish');
      widget.onQueueDepleted!();
    }

    if (noMoreContent && wPlantingDone) {
      if (widget.onQueueDepleted != null) {
        debugPrint('[QuizManager] Queue depleted, requesting more words...');
        widget.onQueueDepleted!();
      } else {
        AudioService.instance.stopAmbient();
        AudioService.instance.play(SFX.sessionComplete);
        AudioService.haptic(HapticType.sessionComplete);
        widget.onSessionComplete();
      }
    } else if (queueEmpty &&
        _queue.pendingNewWords.isNotEmpty &&
        wPlantingDone) {
      // Queue is empty but we have pending words — inject now
      _maybeInjectNewWord();
    }
  }

  void _checkStreakMilestones(int streak) {
    if (!mounted) return;

    // Milestones: 3 (Growth), 5 (Fire), 10 (Gold)
    final milestones = {3, 5, 10};
    if (milestones.contains(streak) && streak != _streakMilestoneShown) {
      setState(() {
        _streakMilestoneShown = streak;
        _showStreakMilestone = true;
      });

      // Additional haptics for big milestones
      if (streak >= 5) {
        AudioService.haptic(HapticType.tap).ignore();
      }
    }
  }

  void _onWiltedPlantingComplete() {
    AudioService.instance.play(SFX.wordPlanted);
    AudioService.haptic(HapticType.plant);
    setState(() {
      _showPlanting = false;
      _wiltedWordToReplant = null;
      _queue.clearWiltedWord(); // UVLS: clear wilted flag so CLS recovers
      _currentQuizType = _determineQuizType();
    });
    _checkDone();
  }

  Future<void> _showWrongAnswerReview(BuildContext context, Word word) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: SeedlingColors.background.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pull Bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: SeedlingColors.seedlingGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LEARNING MOMENT',
                        style: SeedlingTypography.caption.copyWith(
                          color: SeedlingColors.seedlingGreen,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // The Word Details
                Text(
                  word.word,
                  style: SeedlingTypography.heading1.copyWith(fontSize: 40),
                  textAlign: TextAlign.center,
                ),
                if (word.pronunciation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      word.pronunciation!,
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  word.translation,
                  style: SeedlingTypography.heading3.copyWith(
                    color: SeedlingColors.seedlingGreen,
                  ),
                ),

                const SizedBox(height: 32),

                // 1. Definition Section
                _buildReviewSection(
                  'The Meaning',
                  (word.definition != null && word.definition!.isNotEmpty)
                      ? word.definition!
                      : 'Understanding the core meaning of "${word.word}" is essential for fluency. This term is a vital part of your current learning path.',
                  icon: Icons.lightbulb_outline_rounded,
                ),
                const SizedBox(height: 16),

                // 2. Example Section
                _buildExampleReviewSection(word),

                if (word.etymology != null && word.etymology!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildReviewSection(
                    'Deep Roots',
                    word.etymology!,
                    icon: Icons.history_edu_rounded,
                  ),
                ],

                const SizedBox(height: 32),

                // Action Row
                Row(
                  children: [
                    // TTS Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          TtsService.instance.speak(
                            word.word,
                            word.targetLanguageCode,
                          );
                          AudioService.haptic(HapticType.tap);
                        },
                        iconSize: 28,
                        color: SeedlingColors.seedlingGreen,
                        icon: const Icon(Icons.volume_up_rounded),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Continue Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AudioService.haptic(HapticType.tap);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                SeedlingColors.seedlingGreen,
                                Color(0xFF4CAF50),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: SeedlingColors.seedlingGreen.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Continue Session',
                            style: SeedlingTypography.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, String content, {IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: SeedlingColors.seedlingGreen.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title.toUpperCase(),
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.textSecondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: SeedlingTypography.body.copyWith(
              height: 1.5,
              color: SeedlingColors.textPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleReviewSection(Word word) {
    final hasExample =
        word.exampleSentence != null && word.exampleSentence!.isNotEmpty;
    final hasTranslation =
        word.exampleSentenceTranslation != null &&
        word.exampleSentenceTranslation!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: SeedlingColors.seedlingGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'EXAMPLE USAGE',
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.textSecondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Target Language Example
          Text(
            hasExample
                ? word.exampleSentence!
                : 'Seeing words in sentences helps build fluency. We are gathering contextual examples for this specific term.',
            style: SeedlingTypography.body.copyWith(
              height: 1.5,
              fontSize: 15,
              fontStyle: hasExample ? FontStyle.normal : FontStyle.italic,
              color: hasExample
                  ? SeedlingColors.textPrimary
                  : SeedlingColors.textSecondary,
            ),
          ),
          if (hasTranslation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NATIVE TRANSLATION',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.seedlingGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.exampleSentenceTranslation!,
                    style: SeedlingTypography.body.copyWith(
                      height: 1.4,
                      color: SeedlingColors.textPrimary.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAnswer(
    bool correct,
    int mastery, [
    String? chosenWrongTranslation,
    bool isSkip = false,
  ]) async {
    if (!mounted || _isProcessingAnswer) return;

    // Lock the session during async review transitions
    _isProcessingAnswer = true;

    try {
      debugPrint(
        '[QuizManager] Word Answered: ${correct ? 'CORRECT' : 'WRONG'} (mastery gain: $mastery, skip: $isSkip)',
      );

      final elapsedMs = _stopwatch.elapsedMilliseconds;
      _stopwatch.stop();
      _stopwatch.reset();

      final currentCard = _queue.current;
      if (isSkip && currentCard != null && currentCard.word.id != null) {
        _skippedTypesForWord
            .putIfAbsent(currentCard.word.id!, () => {})
            .add(_currentQuizType);
      }
      if (currentCard != null) {
        widget.onWordAnswered?.call(currentCard.word, correct, elapsedMs);

        // ── Record quiz performance (adaptive quiz type tracking) ──────────
        if (widget.db != null && currentCard.word.id != null) {
          widget.db!
              .recordQuizPerformance(
                wordId: currentCard.word.id!,
                quizType: _currentQuizType,
                correct: correct,
                responseMs: elapsedMs,
              )
              .ignore();
        }

        // ── Record confusion (confusion graph) ────────────────────────────
        if (!correct && chosenWrongTranslation != null && widget.db != null) {
          final confusedWord = _getAllSessionWords()
              .where(
                (w) =>
                    w.translation == chosenWrongTranslation &&
                    w.id != currentCard.word.id,
              )
              .firstOrNull;
          if (confusedWord?.id != null) {
            widget.db!
                .recordConfusion(
                  correctWordId: currentCard.word.id!,
                  confusedTranslation: confusedWord!.translation,
                  languageCode: currentCard.word.languageCode,
                  targetLanguageCode: currentCard.word.targetLanguageCode,
                )
                .ignore();
          }
        }
      }

      if (correct) {
        final streak = _queue.streak;
        if (streak > 0 && streak % 3 == 0) {
          AudioService.instance.play(SFX.streakBonus);
          AudioService.haptic(HapticType.levelUp);
        } else {
          AudioService.instance.playCorrect();
          AudioService.haptic(HapticType.correct);
        }

        _checkStreakMilestones(streak);

        if (_currentQuizType == 'engraveRoot' && mastery >= 1) {
          final word = currentCard?.word;
          if (word != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) MasteryCelebration.show(context, word.ttsWord);
            });
          }
        }
      } else {
        AudioService.instance.play(SFX.wrongAnswer);
        AudioService.haptic(HapticType.wrong).ignore();

        if (currentCard != null) {
          // Pedagogical Pause: show review sheet for ALL wrong answers
          // This stops the session from advancing until the user acknowledges their mistake
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) await _showWrongAnswerReview(context, currentCard.word);
        }
      }

      if (!mounted) return;

      setState(() {
        _queue.advance(correct: correct, timeTakenMs: elapsedMs);
        widget.onProgressUpdate(_queue.totalCorrect, _queue.totalAnswered);

        if (!correct &&
            currentCard != null &&
            currentCard.kind == _CardKind.reviewWord) {
          if (currentCard.word.masteryLevel <= 1) {
            _wiltedWordToReplant = currentCard.word;
            _showPlanting = true;
          }
        }

        _maybeInjectNewWord();
        if (!_showPlanting) {
          // Reset the determinism cache so the new card gets a fresh type pick
          _lastDeterminedCardId = null;
          _currentQuizType = _determineQuizType();
        }
        _checkDone();
        _stopwatch.start();
      });
      // STABILITY FIX: Run the async intelligence pre-fetch AFTER the setState
      // frame commits. Calling it inside setState could trigger a second
      // setState from within an async callback before the first frame lands.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showPlanting) _updateQuizType();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAnswer = false; // Unlock
        });
      }
    }
  }

  /// Multi-word milestones bypass [_handleAnswer]; mirror [advanceMultiple]'s
  /// per-card correctness split so FSRS and quiz stats stay aligned.
  void _onMilestoneComplete(int correct, int total) {
    if (!mounted) return;

    const responseMs = 6000; // matches [_AdaptiveQueue.advance] in advanceMultiple
    final remainingErrors = math.max(0, total - correct);
    final limit = math.min(total, _queue.length);

    final head = _queue.snapshotHead(limit);
    var simStreak = _queue.streak;

    for (var i = 0; i < head.length; i++) {
      final isCorrect = i >= remainingErrors;
      final word = head[i].word;

      widget.onWordAnswered?.call(word, isCorrect, responseMs);

      if (widget.db != null && word.id != null) {
        widget.db!
            .recordQuizPerformance(
              wordId: word.id!,
              quizType: _currentQuizType,
              correct: isCorrect,
              responseMs: responseMs,
            )
            .ignore();
      }

      // Match [_handleAnswer] audio/haptics + streak milestones (pre-advance streak).
      if (isCorrect) {
        final streakBefore = simStreak;
        if (streakBefore > 0 && streakBefore % 3 == 0) {
          AudioService.instance.play(SFX.streakBonus);
          AudioService.haptic(HapticType.levelUp);
        } else {
          AudioService.instance.playCorrect();
          AudioService.haptic(HapticType.correct);
        }
        _checkStreakMilestones(streakBefore);
        simStreak = streakBefore + 1;
      } else {
        AudioService.instance.play(SFX.wrongAnswer);
        AudioService.haptic(HapticType.wrong).ignore();
        simStreak = 0;
      }
    }

    _queue.advanceMultiple(total, correctCount: correct);

    _stopwatch
      ..reset()
      ..start();

    widget.onProgressUpdate(_queue.totalCorrect, _queue.totalAnswered);
    _maybeInjectNewWord();
    if (!_showPlanting) {
      setState(() {
        _lastDeterminedCardId = null;
        _currentQuizType = _determineQuizType();
      });
    }
    _checkDone();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_showPlanting) _updateQuizType();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Planting overlay ──────────────────────────────────────────
    if (_showPlanting &&
        (_wiltedWordToReplant != null || _plantingWord != null)) {
      final wordToPlant = _wiltedWordToReplant ?? _plantingWord!;
      final isWilted = _wiltedWordToReplant != null;
      return SeedPlantingScreen(
        words: [wordToPlant],
        initialBatchSize: 1,
        headerLabel: isWilted
            ? 'Wilted Seed: Re-Plant 🌱'
            : 'Plant Something New 🌱',
        isEmbedded: true,
        onWordPlanted: isWilted ? null : widget.onWordPlanted,
        onPlantingComplete: isWilted
            ? _onWiltedPlantingComplete
            : _onPlantingComplete,
      );
    }

    // ── UVLS: Unlock banner + streak milestone overlay (Stack wrapper) ────
    // These are positioned overlays above the quiz card.
    final rawQuizContent = _buildQuizContent(context);
    final quizContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInQuad,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isIncoming = child.key == rawQuizContent.key;
        return SlideTransition(
            position: Tween<Offset>(
                begin: isIncoming ? const Offset(-0.15, 0) : const Offset(0.35, 0.05),
                end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(
              opacity: animation,
              child: RotationTransition(
                turns: Tween<double>(
                  begin: isIncoming ? 0.0 : 0.015,
                  end: 0.0,
                ).animate(animation),
                child: child,
              ),
            ),
        );
      },
      child: rawQuizContent,
    );

    if (_showUnlockBanner || _showStreakMilestone) {
      return Stack(
        alignment: Alignment.topCenter,
        children: [
          quizContent,
          if (_showUnlockBanner)
            Positioned(
              top: 12,
              child: NewWordUnlockBanner(
                onDismissed: () {
                  if (mounted) setState(() => _showUnlockBanner = false);
                },
              ),
            ),
          if (_showStreakMilestone)
            Positioned(
              top: 60,
              child: StreakMilestoneOverlay(
                streak: _streakMilestoneShown,
                onDismissed: () {
                  if (mounted) setState(() => _showStreakMilestone = false);
                },
              ),
            ),
        ],
      );
    }
    return quizContent;
  }

  Widget _buildQuizContent(BuildContext context) {
    // ── Session complete spinner (briefly shown) ──────────────────
    // ── Transition state or Empty check ─────────────────────────
    if (_queue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: SeedlingColors.seedlingGreen,
              ),
              const SizedBox(height: 24),
              Text(
                'Nurturing your session...',
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final card = _queue.current!;
    final current = card.word;

    // ── UVLS Stable Option Memoization ──────────────────────────
    // Regenerate options only if the card or quiz type has changed.
    // This prevents the "dancing text" shimmer caused by re-shuffling on every frame/rebuild.
    final needsRefresh =
        _cachedCardId != card.sessionId ||
        _cachedQuizTypeGenerated != _currentQuizType;

    if (needsRefresh) {
      _cachedOptions = _generateOptions(current);
      _cachedObjOptions = _getObjOptions(current);
      // STABILITY FIX: Seed from the card's session ID so the correct/decoy
      // split is deterministic for this card. Using math.Random().nextBool()
      // would re-roll on every rebuild, causing BloomOrWilt/SeedSort to flip
      // their presented translation if a repaint is triggered mid-question.
      final cardRng = math.Random(card.sessionId.hashCode);
      _cachedShowCorrect = cardRng.nextBool();
      _cachedDecoy = _getDecoy(current);
      _cachedPotOptions = [current.translation, _cachedDecoy!]..shuffle(cardRng);

      // Batch words for milestone quizzes
      final batchSize = math.min(4, _queue._queue.length + 1);
      final batch = <Word>[current];
      for (
        var i = 0;
        i < _queue._queue.length && batch.length < batchSize;
        i++
      ) {
        final w = _queue._queue[i].word;
        if (!batch.any((x) => x.id == w.id)) batch.add(w);
      }
      _cachedBatchWords = batch;

      _cachedCardId = card.sessionId;
      _cachedQuizTypeGenerated = _currentQuizType;

      // ── PRE-SYNTHESIS PREFETCH ──────────────────────────────
      // Pre-synthesize the current word to ensure 0ms playback latency.
      TtsService.instance.preSynthesize(
        current.ttsWord,
        current.targetLanguageCode,
      );

      // Proactively look ahead 1 card in the queue and prefetch that too.
      // This is the "God Move" for perceived performance.
      if (_queue.length > 1) {
        final nextCard = _queue._queue[0]; // _queue.current is removed/shifted? 
                                          // Let's check how _queue works.
                                          // Looking at the code, it seems _queue is a custom list.
        TtsService.instance.preSynthesize(
          nextCard.word.ttsWord,
          nextCard.word.targetLanguageCode,
        );
      }
    }

    final options = _cachedOptions!;

    // ── Pick quiz widget ──────────────────────────────────────────
    switch (_currentQuizType) {
      // ── Original: Grow The Word ─────────────────────────────────
      case 'growWord':
        return GrowTheWordQuiz(
          key: ValueKey('growWord_${card.sessionId}'),
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      // ── Original: Swipe To Nourish ──────────────────────────────
      case 'swipeNourish':
        return SwipeToNourishQuiz(
          key: ValueKey('swipeNourish_${card.sessionId}'),
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      // ── Original: Catch The Leaf ────────────────────────────────
      case 'catchLeaf':
        return CatchTheLeafQuiz(
          key: ValueKey('catchLeaf_${card.sessionId}'),
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      // ── Original: Build The Tree (milestone) ────────────────────
      case 'buildTree':
        return BuildTheTreeQuiz(
          key: ValueKey('buildTree_${card.sessionId}'),
          words: _cachedBatchWords!,
          onComplete: _onMilestoneComplete,
        );

      // ── V2: Deep Root ───────────────────────────────────────────
      case 'deepRoot':
        return DeepRootQuiz(
          key: ValueKey('deepRoot_${card.sessionId}'),
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      // ── V2: Engrave Root (Anti-Cheating Mastery) ────────────────
      case 'engraveRoot':
        return EngraveRootQuiz(
          key: ValueKey('engraveRoot_${card.sessionId}'),
          word: current,
          onAnswer: _handleAnswer,
        );

      // ── V2 Image: Picture Pick ──────────────────────────────────
      case 'picturePick':
        return PicturePickQuiz(
          key: ValueKey('${_currentQuizType}_${card.sessionId}'),
          word: current,
          options: _cachedObjOptions!,
          onAnswer: _handleAnswer,
        );

      // ── V2 Image: What Word Is This? ────────────────────────────
      case 'whatWordIsThis':
        return WhatWordIsThisQuiz(
          key: ValueKey('whatWordIsThis_${card.sessionId}'),
          word: current,
          options: options, // uses the same string distractors
          onAnswer: _handleAnswer,
        );

      // ── V2 Image: Garden Sort ───────────────────────────────────
      case 'gardenSort':
        final decoyStr = _getDecoy(current);
        var decoyWord = _getWordFromTranslation(decoyStr);
        if (decoyWord == null || decoyWord.id == current.id || decoyWord.translation == current.translation) {
           // Find ANY other word in session that isn't this one
           final all = _getAllSessionWords();
           decoyWord = all.firstWhere((w) => w.id != current.id && w.translation != current.translation, orElse: () => current);
        }
        return GardenSortQuiz(
          key: ValueKey('gardenSort_${card.sessionId}'),
          word: current,
          decoyWord: decoyWord, // Use the safe decoy
          onAnswer: _handleAnswer,
        );

      // ── V2: Bloom Or Wilt ───────────────────────────────────────
      case 'bloomOrWilt':
        return BloomOrWiltQuiz(
          key: ValueKey('bloomOrWilt_${card.sessionId}'),
          word: current,
          proposedTranslation: _cachedShowCorrect!
              ? current.translation
              : _cachedDecoy!,
          isActuallyCorrect: _cachedShowCorrect!,
          onAnswer: _handleAnswer,
        );

      // ── V2: Seed Sort ───────────────────────────────────────────
      case 'seedSort':
        return SeedSortQuiz(
          key: ValueKey('seedSort_${card.sessionId}'),
          word: current,
          potOptions: _cachedPotOptions!,
          onAnswer: _handleAnswer,
        );

      // ── V2: Root Network (milestone) ────────────────────────────
      case 'rootNetwork':
        return RootNetworkQuiz(
          key: ValueKey('rootNetwork_${card.sessionId}'),
          words: _cachedBatchWords!,
          onComplete: _onMilestoneComplete,
        );

      // ── Gender: Article Choice ───────────────────────────────────
      case 'articleChallenge':
        return ArticleChoiceQuiz(
          key: ValueKey('articleChallenge_${card.sessionId}'),
          word: current,
          onAnswer: _handleAnswer,
        );

      // ── Image-First: Image Match ─────────────────────────────────
      case 'imageMatch':
        return ImageMatchQuiz(
          key: ValueKey('imageMatch_${card.sessionId}'),
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      // ── Power Learning: Leaf Letter Quiz ─────────────────────────
      case 'leafLetter':
        return LeafLetterQuiz(
          key: ValueKey('leafLetter_${card.sessionId}'),
          word: current,
          onAnswer: _handleAnswer,
        );

      // forestCloze removed from conductor — falls through to deepRoot.
      // The ForestClozeQuiz class is kept in quizzes_power.dart for future use.
      case 'forestCloze':

      // ── New: Memory Flip (milestone) ────────────────────────────
      case 'memoryFlip':
        return MemoryFlipQuiz(
          key: ValueKey(
            'memoryFlip_${_cachedBatchWords!.map((w) => w.id ?? "").join("_")}',
          ),
          words: _cachedBatchWords!,
          onComplete: _onMilestoneComplete,
        );

      // ── New: Word Rain ───────────────────────────────────────────
      case 'wordRain':
        return WordRainQuiz(
          key: ValueKey('wordRain_${current.id}'),
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      default:
        return DeepRootQuiz(
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  // _levenshtein removed: orthographic similarity is a poor proxy for
  // pedagogical distractor quality. Distractors are now selected by semantic
  // tier (confusion graph → POS match → domain match → global) and shuffled
  // randomly within each tier for unbiased, varied quiz experiences.

  List<Word> _getAllSessionWords() {
    final list = List<Word>.from(widget.words);
    list.addAll(widget.initialNewWords);
    if (_plantingWord != null) list.add(_plantingWord!);
    return list;
  }

  List<String> _generateOptions(Word correctWord) {
    final rng = math.Random();
    final allSessionWords = _getAllSessionWords();

    // ── Tier 0: Confusion Graph (most important — words user always confuses) ─
    final confusedTranslations = _confusionCache[correctWord.id] ?? [];
    List<String> distractors = confusedTranslations
        .where((t) => t != correctWord.translation)
        .take(3)
        .toList();

    // ── Tier 1–4: POS-Aware Session Words ────────────────────────────────────
    if (distractors.length < 3) {
      final others = allSessionWords
          .where((w) => w.id != correctWord.id)
          .toList();
      List<String> pool = [];

      // Try cached intelligent distractors from DB first if session is small
      final cachedDistractors = _distractorWordCache[correctWord.id] ?? [];
      for (final w in cachedDistractors) {
        if (!distractors.contains(w.translation)) {
          distractors.add(w.translation);
          if (distractors.length >= 3) break;
        }
      }

      if (distractors.length < 3) {
        pool = others
            .where(
              (w) =>
                  w.id != correctWord.id &&
                  (!widget.strictDistractors || w.subDomain == correctWord.subDomain),
            )
            .where((w) => w.primaryPOS == correctWord.primaryPOS)
            .map((w) => w.translation)
            .toSet()
            .toList();

        if (pool.length < 3 && !widget.strictDistractors) {
          pool = others
              .where(
                (w) =>
                    w.primaryPOS == correctWord.primaryPOS &&
                    w.domain != null &&
                    w.domain == correctWord.domain,
              )
              .map((w) => w.translation)
              .toSet()
              .toList();
        }

        if (pool.length < 3 && !widget.strictDistractors) {
          pool = others
              .where((w) => w.primaryPOS == correctWord.primaryPOS)
              .map((w) => w.translation)
              .toSet()
              .toList();
        }

        if (pool.length < 3 && !widget.strictDistractors) {
          pool = others.map((w) => w.translation).toSet().toList();
        }

        // Filter out identical translation (strict string check)
        final targetT = correctWord.translation.trim().toLowerCase();
        pool.removeWhere((t) => t.trim().toLowerCase() == targetT);

        // Shuffle within tier for random but stable distractor selection
        final candidates =
            pool.where((t) => !distractors.contains(t)).toList()
              ..shuffle(rng);
        distractors.addAll(candidates.take(3 - distractors.length));
      }
    }

    // GUARANTEE: Never show less than 2 options (1 correct + 1 distractor)
    // For strict isolated sessions, we prefer returning fewer distractors than leaking global ones.
    if (distractors.isEmpty && !widget.strictDistractors) {
      // Emergency fallbacks for very fresh sessions or empty databases
      final emergencyDefaults = ['Yes', 'No', 'Wait', 'Go', 'Tree', 'Leaf'];
      final fallback = emergencyDefaults.firstWhere(
        (e) => e != correctWord.translation,
      );
      distractors.add(fallback);
    }

    return [correctWord.translation, ...distractors.take(3)]..shuffle(rng);
  }

  String _getDecoy(Word word) {
    final allSessionWords = _getAllSessionWords();
    final others = allSessionWords.where((w) => w.id != word.id).toList();
    if (others.isEmpty) {
      // SILE: Use a fallback word instead of "—" to satisfy user requirements
      final rng = math.Random();
      return _fallbackDistractors[rng.nextInt(_fallbackDistractors.length)];
    }

    // POS-first: prefer same POS + domain for realistic decoys
    List<Word> pool = others
        .where(
          (w) => w.primaryPOS == word.primaryPOS && w.domain == word.domain,
        )
        .toList();

    if (pool.isEmpty) {
      pool = others.where((w) => w.primaryPOS == word.primaryPOS).toList();
    }
    if (pool.isEmpty) pool = others;

    final validPool = pool.map((w) => w.translation).toSet().toList();
    final targetT = word.translation.trim().toLowerCase();
    validPool.removeWhere((t) => t.trim().toLowerCase() == targetT);
    
    // Shuffle for unbiased decoy selection within the chosen tier
    final rng = math.Random();
    validPool.shuffle(rng);
    if (validPool.isEmpty) {
      return _fallbackDistractors[rng.nextInt(_fallbackDistractors.length)];
    }
    return validPool.first;
  }

  Word? _getWordFromTranslation(String translation) {
    if (translation == '—' || _fallbackDistractors.contains(translation)) return null;
    final all = _getAllSessionWords();
    try {
      return all.firstWhere((w) => w.translation == translation);
    } catch (_) {
      return null;
    }
  }

  List<Word> _getObjOptions(Word correctWord) {
    final rng = math.Random();
    final allSessionWords = _getAllSessionWords();

    final List<Word> pool = [];
    // 1. Session words
    pool.addAll(allSessionWords.where((w) => w.id != correctWord.id));

    // 2. Intelligent distractors
    final cached = _distractorWordCache[correctWord.id] ?? [];
    for (final w in cached) {
      if (!pool.any((x) => x.id == w.id)) pool.add(w);
    }

    pool.removeWhere((w) => w.word == correctWord.word || w.translation == correctWord.translation);

    // Shuffle within the session pool for unbiased distractor selection
    final candidates = pool.toList()..shuffle(rng);

    // Take up to 3 distractors for 3-4 options total
    final wrong = candidates.take(3).toList();

    // EMERGENCY: Ensure at least one distractor
    if (wrong.isEmpty) {
      // Just some dummy word if session is totally empty (shouldn't happen with smarter fetch)
      wrong.add(
        Word(
          word: '...',
          translation: '...',
          languageCode: correctWord.languageCode,
          targetLanguageCode: correctWord.targetLanguageCode,
        ),
      );
    }

    return [correctWord, ...wrong]..shuffle(rng);
  }
}
