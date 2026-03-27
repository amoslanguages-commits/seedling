import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/target_word_display.dart';

// ================================================================
// SIGNATURE QUIZ UPGRADES & NEW QUIZ TYPES
// All word-focused, no sentences.
// All use Seedling color palette and CustomPainter.
// ================================================================
//
// 1. DeepRootQuiz       - upgraded GrowTheWord (roots grow from soil)
// 2. WindScatterQuiz    - upgraded CatchTheLeaf (bezier wind physics)
// 3. SeedSortQuiz       - NEW: swipe seeds into pots
// 4. BloomOrWiltQuiz    - NEW: true/false with live plant reaction
// 5. RootNetworkQuiz    - NEW: drag-to-connect root nodes
//
// ================================================================

// ── QUIZ TYPE 1: DEEP ROOT ─────────────────────────────────────
// Options displayed as roots emerging from soil.
// Correct tap → root glows gold, plant blooms.
// Wrong tap   → root wilts + shakes.

class DeepRootQuiz extends StatefulWidget {
  final Word word;
  final List<String> options;
  final Function(bool correct, int masteryGained) onAnswer;

  const DeepRootQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<DeepRootQuiz> createState() => _DeepRootQuizState();
}

class _DeepRootQuizState extends State<DeepRootQuiz>
    with TickerProviderStateMixin {
  late AnimationController _bloomController;
  late AnimationController _shakeController;
  late AnimationController _rootGrowController;
  int? _selectedIndex;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode);
    _bloomController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _rootGrowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _rootGrowController.forward();
  }

  @override
  void dispose() {
    _bloomController.dispose();
    _shakeController.dispose();
    _rootGrowController.dispose();
    super.dispose();
  }

  void _handleAnswer(int index) {
    if (_hasAnswered) return;
    setState(() {
      _selectedIndex = index;
      _hasAnswered = true;
    });
    final isCorrect = widget.options[index] == widget.word.translation;
    if (isCorrect) {
      _bloomController.forward();
      AudioService.instance.playCorrect(streak: 0);
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _shakeController.forward(from: 0);
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();
    }
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Word card
        Container(
          margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
                color: SeedlingColors.morningDew.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Text('What does this mean?',
                  style: SeedlingTypography.caption
                      .copyWith(color: SeedlingColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TargetWordDisplay(
                    word: widget.word,
                      style: SeedlingTypography.heading1
                          .copyWith(fontSize: 38, letterSpacing: 0.5)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: SeedlingColors.seedlingGreen),
                    onPressed: () => TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode),
                  ),
                ],
              ),
              if (widget.word.pronunciation != null) ...[
                const SizedBox(height: 4),
                Text(widget.word.pronunciation!,
                    style: SeedlingTypography.caption
                        .copyWith(fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),

        // Garden visualization
        Expanded(
          child: AnimatedBuilder(
            animation:
                Listenable.merge([_bloomController, _shakeController, _rootGrowController]),
            builder: (ctx, _) {
              final shake = math.sin(_shakeController.value * math.pi * 8) *
                  12 *
                  (1 - _shakeController.value);
              return Transform.translate(
                offset: Offset(shake, 0),
                child: CustomPaint(
                  size: const Size(double.infinity, double.infinity),
                  painter: DeepRootGardenPainter(
                    options: widget.options,
                    selectedIndex: _selectedIndex,
                    correctAnswer: widget.word.translation,
                    hasAnswered: _hasAnswered,
                    bloomProgress: _bloomController.value,
                    rootGrowProgress: _rootGrowController.value,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      if (_hasAnswered) return;
                      final size = context.size ?? Size.zero;
                      final idx = _getRootIndexAtOffset(
                          details.localPosition, size, widget.options.length);
                      if (idx != null) _handleAnswer(idx);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  int? _getRootIndexAtOffset(Offset pos, Size size, int count) {
    final slotW = size.width / count;
    final tapX = pos.dx;
    final tapY = pos.dy;
    if (tapY < size.height * 0.25) return null; // above roots
    final idx = (tapX / slotW).floor().clamp(0, count - 1);
    return idx;
  }
}

class DeepRootGardenPainter extends CustomPainter {
  final List<String> options;
  final int? selectedIndex;
  final String correctAnswer;
  final bool hasAnswered;
  final double bloomProgress;
  final double rootGrowProgress;

  const DeepRootGardenPainter({
    required this.options,
    required this.selectedIndex,
    required this.correctAnswer,
    required this.hasAnswered,
    required this.bloomProgress,
    required this.rootGrowProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * 0.42;

    // Sky gradient
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SeedlingColors.background,
          SeedlingColors.morningDew.withValues(alpha: 0.2),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, groundY));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, groundY), skyPaint);

    // Soil layer
    final soilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SeedlingColors.soil.withValues(alpha: 0.85),
          SeedlingColors.deepRoot.withValues(alpha: 0.95),
        ],
      ).createShader(
          Rect.fromLTWH(0, groundY, size.width, size.height - groundY));
    // Wavy ground line
    final groundPath = Path()..moveTo(0, groundY);
    for (double x = 0; x <= size.width; x += 30) {
      groundPath.quadraticBezierTo(
        x + 15, groundY + 6 * math.sin((x / size.width) * math.pi * 5),
        x + 30, groundY,
      );
    }
    groundPath
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(groundPath, soilPaint);

    // Small soil rocks/texture
    final rockPaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(alpha: 0.4);
    final rng = math.Random(7);
    for (int i = 0; i < 8; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, groundY + 10 + rng.nextDouble() * 20),
        2 + rng.nextDouble() * 4,
        rockPaint,
      );
    }

    // Draw central plant above soil
    _drawCentralPlant(canvas, size, groundY);

    // Draw roots for each option
    final count = options.length;
    for (int i = 0; i < count; i++) {
      final cx = size.width * (i + 0.5) / count;
      _drawRoot(canvas, size, cx, groundY, i);
    }
  }

  void _drawCentralPlant(Canvas canvas, Size size, double groundY) {
    final cx = size.width / 2;
    final isCorrectSelected =
        hasAnswered && selectedIndex != null && options[selectedIndex!] == correctAnswer;

    // Stem
    final stemH = 60.0 + bloomProgress * 40;
    final stemPaint = Paint()
      ..color = Color.lerp(
        SeedlingColors.seedlingGreen,
        SeedlingColors.sunlight,
        bloomProgress,
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx, groundY),
      Offset(cx, groundY - stemH * rootGrowProgress),
      stemPaint,
    );

    // Leaves
    if (rootGrowProgress > 0.5) {
      final lp = (rootGrowProgress - 0.5) / 0.5;
      final leafPaint = Paint()
        ..color = Color.lerp(
          SeedlingColors.freshSprout,
          SeedlingColors.sunlight,
          bloomProgress,
        )!
        ..style = PaintingStyle.fill;
      _drawLeaf(canvas, cx, groundY - 30 * rootGrowProgress, -0.5, 22 * lp, leafPaint);
      _drawLeaf(canvas, cx, groundY - 45 * rootGrowProgress, 0.5, 20 * lp, leafPaint);
    }

    // Bloom flower burst on correct
    if (isCorrectSelected && bloomProgress > 0.4) {
      final fp = (bloomProgress - 0.4) / 0.6;
      final flowerY = groundY - stemH;
      _drawFlowerBurst(canvas, cx, flowerY, fp);
    }
  }

  void _drawFlowerBurst(Canvas canvas, double cx, double cy, double p) {
    const petals = 8;
    final petalLen = 28.0 * p;
    final petalPaint = Paint()
      ..color = SeedlingColors.sunlight.withValues(alpha: p)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = SeedlingColors.sunlight.withValues(alpha: 0.35 * p)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(Offset(cx, cy), petalLen * 1.2, glowPaint);
    for (int i = 0; i < petals; i++) {
      final angle = (i / petals) * math.pi * 2;
      final ex = cx + math.cos(angle) * petalLen;
      final ey = cy + math.sin(angle) * petalLen;
      final path = Path()
        ..moveTo(cx, cy)
        ..quadraticBezierTo(
          cx + math.cos(angle + 0.4) * petalLen * 0.6,
          cy + math.sin(angle + 0.4) * petalLen * 0.6,
          ex, ey,
        )
        ..quadraticBezierTo(
          cx + math.cos(angle - 0.4) * petalLen * 0.6,
          cy + math.sin(angle - 0.4) * petalLen * 0.6,
          cx, cy,
        );
      canvas.drawPath(path, petalPaint);
    }
    canvas.drawCircle(
      Offset(cx, cy),
      9 * p,
      Paint()..color = SeedlingColors.deepRoot,
    );
  }

  void _drawRoot(
      Canvas canvas, Size size, double cx, double groundY, int index) {
    final isSelected = selectedIndex == index;
    final isCorrect = options[index] == correctAnswer;

    Color rootColor = SeedlingColors.soil.withValues(alpha: 0.6);
    if (hasAnswered) {
      if (isCorrect) {
        rootColor = Color.lerp(
          SeedlingColors.success,
          SeedlingColors.sunlight,
          bloomProgress,
        )!;
      } else if (isSelected) {
        rootColor = SeedlingColors.error;
      }
    } else if (isSelected) {
      rootColor = SeedlingColors.seedlingGreen;
    }

    final rootH = (size.height - groundY) * 0.45 * rootGrowProgress;
    final rootPaint = Paint()
      ..color = rootColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected || (hasAnswered && isCorrect) ? 8 : 5
      ..strokeCap = StrokeCap.round;

    // Organic winding root path
    final rootPath = Path()..moveTo(cx, groundY);
    final wave = (index % 2 == 0 ? 1 : -1) * 18.0;
    rootPath.cubicTo(
      cx + wave, groundY + rootH * 0.3,
      cx - wave, groundY + rootH * 0.6,
      cx + wave * 0.5, groundY + rootH,
    );
    canvas.drawPath(rootPath, rootPaint);

    // Glow on correct/selected
    if ((hasAnswered && isCorrect) || isSelected) {
      final glowPaint = Paint()
        ..color = rootColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(rootPath, glowPaint);
    }

    // Root tip circle
    final tipY = groundY + rootH;
    canvas.drawCircle(
      Offset(cx + wave * 0.5, tipY),
      isSelected || (hasAnswered && isCorrect) ? 8 : 5,
      Paint()..color = rootColor..style = PaintingStyle.fill,
    );

    // Touch hint circles (invisible hit zones)
    final hitPaint = Paint()
      ..color = Colors.transparent;
    canvas.drawCircle(Offset(cx, groundY + rootH / 2), 40, hitPaint);

    // Option text label in root zone
    _drawRootLabel(canvas, options[index], cx, groundY + rootH * 0.5,
        rootColor, isSelected || (hasAnswered && isCorrect));
  }

  void _drawRootLabel(Canvas canvas, String text, double cx, double cy,
      Color color, bool highlighted) {
    final bg = Paint()
      ..color = (highlighted
          ? color.withValues(alpha: 0.18)
          : SeedlingColors.cardBackground.withValues(alpha: 0.85))
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 90, height: 36),
      const Radius.circular(18),
    );
    canvas.drawRRect(rrect, bg);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: highlighted ? 0.8 : 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 2 : 1,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: SeedlingTypography.body.copyWith(
          color: highlighted ? color : SeedlingColors.textPrimary,
          fontWeight: highlighted ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout(maxWidth: 82);
    tp.paint(canvas,
        Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawLeaf(Canvas canvas, double x, double y, double angle,
      double size, Paint paint) {
    if (size <= 0) return;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-size / 2, -size / 3, 0, -size)
      ..quadraticBezierTo(size / 2, -size / 3, 0, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DeepRootGardenPainter old) =>
      old.bloomProgress != bloomProgress ||
      old.rootGrowProgress != rootGrowProgress ||
      old.selectedIndex != selectedIndex ||
      old.hasAnswered != hasAnswered;
}

// ── QUIZ TYPE 2: BLOOM OR WILT (True/False) ───────────────────
// A word + translation pair appears.
// User taps 💧 (True) or ☠️ (Wrong).
// Correct → plant blooms fully. Wrong → plant droops.

class BloomOrWiltQuiz extends StatefulWidget {
  final Word word;
  final String shownTranslation; // may be correct OR a decoy
  final bool isCorrectPair;
  final Function(bool correct, int masteryGained) onAnswer;

  const BloomOrWiltQuiz({
    super.key,
    required this.word,
    required this.shownTranslation,
    required this.isCorrectPair,
    required this.onAnswer,
  });

  @override
  State<BloomOrWiltQuiz> createState() => _BloomOrWiltQuizState();
}

class _BloomOrWiltQuizState extends State<BloomOrWiltQuiz>
    with TickerProviderStateMixin {
  late AnimationController _plantController;
  late AnimationController _resultController;
  bool? _userSaidTrue;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode);
    _plantController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
        value: 0.6);
    _resultController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _plantController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  void _handleAnswer(bool userSaidTrue) {
    if (_hasAnswered) return;
    setState(() {
      _userSaidTrue = userSaidTrue;
      _hasAnswered = true;
    });
    final isCorrect = userSaidTrue == widget.isCorrectPair;
    if (isCorrect) {
      _plantController.animateTo(1.0,
          duration: const Duration(milliseconds: 800), curve: Curves.easeOut);
      AudioService.instance.playCorrect(streak: 0);
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _plantController.animateTo(0.1,
          duration: const Duration(milliseconds: 800), curve: Curves.easeIn);
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();
    }
    _resultController.forward();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Background Plant Visualization
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_plantController, _resultController]),
              builder: (ctx, _) => CustomPaint(
                painter: BloomOrWiltPlantPainter(
                  growthLevel: _plantController.value,
                  hasAnswered: _hasAnswered,
                  isCorrect: _hasAnswered
                      ? (_userSaidTrue == widget.isCorrectPair)
                      : null,
                  resultProgress: _resultController.value,
                ),
              ),
            ),
          ),

          // Foreground UI (Card at top, Buttons at bottom)
          Column(
            children: [
              const SizedBox(height: 16),
              
              // Word + Translation card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _resultController,
                  builder: (ctx, child) {
                    Color border = SeedlingColors.morningDew.withValues(alpha: 0.4);
                    if (_hasAnswered) {
                      final isCorrect = _userSaidTrue == widget.isCorrectPair;
                      border = Color.lerp(
                        border,
                        isCorrect ? SeedlingColors.success : SeedlingColors.error,
                        _resultController.value,
                      )!;
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 24),
                      decoration: BoxDecoration(
                        color: SeedlingColors.cardBackground,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: border, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Is this correct?',
                              style: SeedlingTypography.caption
                                  .copyWith(color: SeedlingColors.textSecondary)),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TargetWordDisplay(
                                word: widget.word,
                                style: SeedlingTypography.heading1
                                    .copyWith(fontSize: 32),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded,
                                    color: SeedlingColors.seedlingGreen),
                                onPressed: () => TtsService.instance.speak(
                                    widget.word.ttsWord,
                                    widget.word.targetLanguageCode),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                              height: 1.5,
                              width: 50,
                              color: SeedlingColors.morningDew),
                          const SizedBox(height: 8),
                          Text(widget.shownTranslation,
                              style: SeedlingTypography.body.copyWith(
                                fontSize: 20,
                                color: SeedlingColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const Spacer(),

              // True / False buttons
              if (!_hasAnswered)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Row(
                    children: [
                      Expanded(child: _buildAnswerBtn(false)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildAnswerBtn(true)),
                    ],
                  ),
                )
              else
                const SizedBox(height: 96), // Space for where buttons were
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerBtn(bool isTrue) {
    return GestureDetector(
      onTap: () => _handleAnswer(isTrue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        decoration: BoxDecoration(
          color: isTrue
              ? SeedlingColors.seedlingGreen.withValues(alpha: 0.12)
              : SeedlingColors.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTrue
                ? SeedlingColors.seedlingGreen.withValues(alpha: 0.5)
                : SeedlingColors.error.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isTrue ? '💧' : '🥀',
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              isTrue ? 'Correct' : 'Wrong',
              style: SeedlingTypography.body.copyWith(
                color: isTrue
                    ? SeedlingColors.seedlingGreen
                    : SeedlingColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BloomOrWiltPlantPainter extends CustomPainter {
  final double growthLevel;
  final bool hasAnswered;
  final bool? isCorrect;
  final double resultProgress;

  const BloomOrWiltPlantPainter({
    required this.growthLevel,
    required this.hasAnswered,
    this.isCorrect,
    required this.resultProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final groundY = size.height * 0.7;

    // Soil mound
    final soilPaint = Paint()
      ..color = SeedlingColors.soil.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    final soilPath = Path()
      ..moveTo(cx - 50, groundY)
      ..quadraticBezierTo(cx, groundY - 12, cx + 50, groundY)
      ..lineTo(cx + 55, groundY + 14)
      ..lineTo(cx - 55, groundY + 14)
      ..close();
    canvas.drawPath(soilPath, soilPaint);

    final stemH = growthLevel * 130;
    final isWilting = hasAnswered && isCorrect == false;

    // Wilt droop
    final droopAngle = isWilting ? resultProgress * 1.2 : 0.0;

    // Stem
    canvas.save();
    canvas.translate(cx, groundY);
    canvas.rotate(droopAngle * -0.3);

    final stemColor = isWilting
        ? Color.lerp(SeedlingColors.seedlingGreen, SeedlingColors.error,
            resultProgress * 0.7)!
        : Color.lerp(SeedlingColors.seedlingGreen, SeedlingColors.sunlight,
            growthLevel > 0.85 ? (growthLevel - 0.85) / 0.15 : 0)!;

    final stemPaint = Paint()
      ..color = stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset.zero, Offset(0, -stemH), stemPaint);

    // Leaves
    if (growthLevel > 0.3) {
      final leafP = Paint()
        ..color = Color.lerp(
          SeedlingColors.freshSprout,
          isWilting ? SeedlingColors.error.withValues(alpha: 0.6) : SeedlingColors.sunlight,
          resultProgress * (isWilting ? 0.5 : 0),
        )!
        ..style = PaintingStyle.fill;
      _drawLeaf(canvas, 0, -stemH * 0.4, -0.55, 28 * growthLevel, leafP);
      _drawLeaf(canvas, 0, -stemH * 0.65, 0.6, 24 * growthLevel, leafP);
    }

    // Bloom petals when correct + fully grown
    if (isCorrect == true && growthLevel > 0.85) {
      final fp = (growthLevel - 0.85) / 0.15 * resultProgress;
      _drawBloom(canvas, 0, -stemH, fp);
    }

    canvas.restore();
  }

  void _drawLeaf(Canvas canvas, double x, double y, double angle,
      double size, Paint paint) {
    if (size <= 0) return;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-size / 2, -size / 3, 0, -size)
      ..quadraticBezierTo(size / 2, -size / 3, 0, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawBloom(Canvas canvas, double cx, double cy, double p) {
    if (p <= 0) return;
    const petals = 7;
    final petalLen = 24.0 * p;
    final pp = Paint()
      ..color = SeedlingColors.sunlight.withValues(alpha: p * 0.95)
      ..style = PaintingStyle.fill;
    final glow = Paint()
      ..color = SeedlingColors.sunlight.withValues(alpha: 0.3 * p)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset(cx, cy), petalLen + 8, glow);
    for (int i = 0; i < petals; i++) {
      final a = (i / petals) * math.pi * 2;
      final ex = cx + math.cos(a) * petalLen;
      final ey = cy + math.sin(a) * petalLen;
      final path = Path()
        ..moveTo(cx, cy)
        ..quadraticBezierTo(
          cx + math.cos(a + 0.4) * petalLen * 0.55,
          cy + math.sin(a + 0.4) * petalLen * 0.55,
          ex, ey,
        )
        ..quadraticBezierTo(
          cx + math.cos(a - 0.4) * petalLen * 0.55,
          cy + math.sin(a - 0.4) * petalLen * 0.55,
          cx, cy,
        );
      canvas.drawPath(path, pp);
    }
    canvas.drawCircle(Offset(cx, cy), 8 * p,
        Paint()..color = SeedlingColors.deepRoot);
  }

  @override
  bool shouldRepaint(covariant BloomOrWiltPlantPainter old) =>
      old.growthLevel != growthLevel ||
      old.hasAnswered != hasAnswered ||
      old.resultProgress != resultProgress;
}

// ── QUIZ TYPE 3: SEED SORT ────────────────────────────────────
// Seeds labeled with target-language words fall from sky.
// Two soil pots at bottom labelled with native-language choices.
// User drags seed into the correct pot.

class SeedSortQuiz extends StatefulWidget {
  final Word word;
  final List<String> potOptions; // [correct, decoy]
  final Function(bool correct, int masteryGained) onAnswer;

  const SeedSortQuiz({
    super.key,
    required this.word,
    required this.potOptions,
    required this.onAnswer,
  });

  @override
  State<SeedSortQuiz> createState() => _SeedSortQuizState();
}

class _SeedSortQuizState extends State<SeedSortQuiz>
    with TickerProviderStateMixin {
  late AnimationController _fallController;
  late AnimationController _sortController;
  Offset _dragPos = Offset.zero;
  bool _isDragging = false;
  int? _droppedPot;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode);
    _fallController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _sortController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fallController.forward();
  }

  @override
  void dispose() {
    _fallController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  void _dropOnPot(int potIndex) {
    if (_hasAnswered) return;
    setState(() {
      _hasAnswered = true;
      _droppedPot = potIndex;
      _isDragging = false;
    });
    final isCorrect = widget.potOptions[potIndex] == widget.word.translation;
    _sortController.forward();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final W = constraints.maxWidth;
        final H = constraints.maxHeight;
        final pot0Center = Offset(W * 0.25, H * 0.82);
        final pot1Center = Offset(W * 0.75, H * 0.82);

        return Stack(
          children: [
            // Background
            AnimatedBuilder(
              animation: Listenable.merge([_fallController, _sortController]),
              builder: (ctx, _) => CustomPaint(
                size: Size(W, H),
                painter: SeedSortBgPainter(
                  potOptions: widget.potOptions,
                  droppedPot: _droppedPot,
                  correctAnswer: widget.word.translation,
                  sortProgress: _sortController.value,
                  seed: widget.word.ttsWord,
                ),
              ),
            ),

            // Falling seed (draggable)
            AnimatedBuilder(
              animation: _fallController,
              builder: (ctx, _) {
                if (_hasAnswered) return const SizedBox.shrink();
                const startY = -80.0;
                final endY = H * 0.35;
                final seedY = _isDragging
                    ? _dragPos.dy - 40
                    : startY + (endY - startY) * _fallController.value;
                final seedX =
                    _isDragging ? _dragPos.dx - 40 : W / 2 - 40;

                return Positioned(
                  left: seedX,
                  top: seedY,
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onPanStart: (_fallController.isCompleted)
                        ? (d) => setState(() {
                              _isDragging = true;
                              _dragPos = d.localPosition +
                                  Offset(seedX, seedY);
                            })
                        : null,
                    onPanUpdate: _isDragging
                        ? (d) => setState(
                            () => _dragPos += d.delta)
                        : null,
                    onPanEnd: _isDragging
                        ? (_) {
                            // Detect closest pot
                            final curPos =
                                Offset(_dragPos.dx, _dragPos.dy);
                            final d0 = (curPos - pot0Center).distance;
                            final d1 = (curPos - pot1Center).distance;
                            if (d0 < 90) {
                              _dropOnPot(0);
                            } else if (d1 < 90) {
                              _dropOnPot(1);
                            } else {
                              setState(() => _isDragging = false);
                            }
                          }
                        : null,
                    child: CustomPaint(
                      painter: DraggableSeedPainter(
                          label: widget.word.ttsWord,
                          isDragging: _isDragging),
                    ),
                  ),
                );
              },
            ),

            // "Drag to sort" hint
            if (!_hasAnswered && _fallController.isCompleted && !_isDragging)
              Positioned(
                top: H * 0.46,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (ctx, v, child) => Opacity(
                    opacity: v,
                    child: child,
                  ),
                  child: Text(
                    'Drag the seed into the right pot',
                    textAlign: TextAlign.center,
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class DraggableSeedPainter extends CustomPainter {
  final String label;
  final bool isDragging;

  const DraggableSeedPainter(
      {required this.label, required this.isDragging});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = isDragging ? 1.12 : 1.0;

    // Glow
    if (isDragging) {
      canvas.drawCircle(
        Offset(cx, cy),
        42 * scale,
        Paint()
          ..color = SeedlingColors.seedlingGreen.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Seed body
    final seedPaint = Paint()
      ..color = SeedlingColors.soil
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = _seedPath(cx, cy, 36 * scale, 46 * scale);
    canvas.save();
    canvas.translate(3, 5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
    canvas.drawPath(path, seedPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
        _seedPath(cx - 8, cy - 10, 14 * scale, 18 * scale), highlightPaint);
    canvas.restore();

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: SeedlingTypography.body.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          shadows: [
            const Shadow(color: Colors.black38, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout(maxWidth: size.width - 12);
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  Path _seedPath(double cx, double cy, double rw, double rh) {
    return Path()
      ..moveTo(cx, cy - rh)
      ..cubicTo(cx + rw, cy - rh * 0.6, cx + rw * 0.8, cy + rh * 0.4, cx, cy + rh)
      ..cubicTo(cx - rw * 0.8, cy + rh * 0.4, cx - rw, cy - rh * 0.6, cx, cy - rh)
      ..close();
  }

  @override
  bool shouldRepaint(covariant DraggableSeedPainter old) =>
      old.isDragging != isDragging;
}

class SeedSortBgPainter extends CustomPainter {
  final List<String> potOptions;
  final int? droppedPot;
  final String correctAnswer;
  final double sortProgress;
  final String seed;

  const SeedSortBgPainter({
    required this.potOptions,
    required this.droppedPot,
    required this.correctAnswer,
    required this.sortProgress,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw two pots
    _drawPot(canvas, size, 0, size.width * 0.25, size.height * 0.78);
    _drawPot(canvas, size, 1, size.width * 0.75, size.height * 0.78);
  }

  void _drawPot(Canvas canvas, Size size, int idx, double cx, double cy) {
    final isDropped = droppedPot == idx;
    final isCorrect = potOptions[idx] == correctAnswer;
    final isDropCorrect = isDropped && isCorrect;
    final isDropWrong = isDropped && !isCorrect;

    Color potColor = SeedlingColors.soil;
    if (isDropCorrect) {
      potColor = Color.lerp(SeedlingColors.soil, SeedlingColors.success, sortProgress)!;
    } else if (isDropWrong) {
      potColor = Color.lerp(SeedlingColors.soil, SeedlingColors.error, sortProgress)!;
    }

    // Pot glow
    if (isDropped) {
      canvas.drawCircle(
        Offset(cx, cy),
        65,
        Paint()
          ..color = potColor.withValues(alpha: 0.25 * sortProgress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    // Pot body
    final potPaint = Paint()
      ..color = potColor
      ..style = PaintingStyle.fill;
    final potPath = Path()
      ..moveTo(cx - 38, cy)
      ..lineTo(cx - 30, cy + 50)
      ..lineTo(cx + 30, cy + 50)
      ..lineTo(cx + 38, cy)
      ..close();
    canvas.drawPath(potPath, potPaint);

    // Pot rim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 80, height: 14),
        const Radius.circular(7),
      ),
      Paint()..color = potColor.withValues(alpha: 0.8),
    );

    // Soil in pot
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy - 2), width: 74, height: 18),
      Paint()
        ..color = SeedlingColors.deepRoot.withValues(alpha: 0.9),
    );

    // Tiny sprout if correct drop
    if (isDropCorrect && sortProgress > 0.5) {
      final sp = (sortProgress - 0.5) / 0.5;
      final stemPaint = Paint()
        ..color = SeedlingColors.freshSprout
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx, cy - 8),
        Offset(cx, cy - 8 - 30 * sp),
        stemPaint,
      );
      if (sp > 0.5) {
        final lp = ((sp - 0.5) / 0.5);
        _drawLeaf(canvas, cx, cy - 8 - 20 * sp, -0.5, 14 * lp,
            Paint()
              ..color = SeedlingColors.freshSprout
              ..style = PaintingStyle.fill);
        _drawLeaf(canvas, cx, cy - 8 - 26 * sp, 0.5, 12 * lp,
            Paint()
              ..color = SeedlingColors.freshSprout
              ..style = PaintingStyle.fill);
      }
    }

    // Option label
    final tp = TextPainter(
      text: TextSpan(
        text: potOptions[idx],
        style: SeedlingTypography.body.copyWith(
          color: isDropCorrect
              ? SeedlingColors.success
              : isDropWrong
                  ? SeedlingColors.error
                  : SeedlingColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout(maxWidth: 100);
    tp.paint(canvas,
        Offset(cx - tp.width / 2, cy + 58));
  }

  void _drawLeaf(Canvas canvas, double x, double y, double angle,
      double sz, Paint paint) {
    if (sz <= 0) return;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-sz / 2, -sz / 3, 0, -sz)
      ..quadraticBezierTo(sz / 2, -sz / 3, 0, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SeedSortBgPainter old) =>
      old.droppedPot != droppedPot || old.sortProgress != sortProgress;
}

// ── QUIZ TYPE 4: ROOT NETWORK ─────────────────────────────────
// Words on left, translations on right as glowing root nodes.
// User draws roots (drag) to connect them.

class RootNetworkQuiz extends StatefulWidget {
  final List<Word> words;
  final Function(int correct, int total) onComplete;

  const RootNetworkQuiz({
    super.key,
    required this.words,
    required this.onComplete,
  });

  @override
  State<RootNetworkQuiz> createState() => _RootNetworkQuizState();
}

class _RootNetworkQuizState extends State<RootNetworkQuiz>
    with TickerProviderStateMixin {
  late List<Word> _shuffledWords;
  late List<String> _shuffledTranslations;
  final Map<int, int> _connections = {}; // wordIdx → transIdx
  int? _selectedWordIdx;
  int _correct = 0;
  late AnimationController _pulseController;
  late AnimationController _connectController;
  Offset? _dragEnd;

  @override
  void initState() {
    super.initState();
    _shuffledWords = List.from(widget.words)..shuffle();
    _shuffledTranslations =
        _shuffledWords.map((w) => w.translation).toList()..shuffle();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _connectController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _connectController.dispose();
    super.dispose();
  }

  void _tryConnect(int transIdx) {
    if (_selectedWordIdx == null) return;
    if (_connections.containsKey(_selectedWordIdx)) return;
    if (_connections.values.contains(transIdx)) return;

    final word = _shuffledWords[_selectedWordIdx!];
    final trans = _shuffledTranslations[transIdx];
    if (word.translation == trans) {
      setState(() {
        _connections[_selectedWordIdx!] = transIdx;
        _correct++;
        _selectedWordIdx = null;
        _dragEnd = null;
      });
      _connectController.forward(from: 0);
      if (_connections.length >= _shuffledWords.length) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) widget.onComplete(_correct, _shuffledWords.length);
        });
      }
    } else {
      // Wrong — flash and deselect
      setState(() {
        _selectedWordIdx = null;
        _dragEnd = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text('Connect the Roots',
                  style: SeedlingTypography.heading2
                      .copyWith(color: SeedlingColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Match each word to its meaning',
                  style: SeedlingTypography.caption),
              const SizedBox(height: 12),
              // Progress bar
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _connections.length / _shuffledWords.length,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          SeedlingColors.seedlingGreen,
                          SeedlingColors.freshSprout
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Root network area
        Expanded(
          child: AnimatedBuilder(
            animation:
                Listenable.merge([_pulseController, _connectController]),
            builder: (ctx, _) {
              return LayoutBuilder(builder: (ctx, constraints) {
                final W = constraints.maxWidth;
                final H = constraints.maxHeight;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: _selectedWordIdx != null
                      ? (d) => setState(() => _dragEnd = d.localPosition)
                      : null,
                  onPanEnd: _selectedWordIdx != null
                      ? (_) => setState(() {
                            _selectedWordIdx = null;
                            _dragEnd = null;
                          })
                      : null,
                  child: CustomPaint(
                    size: Size(W, H),
                    painter: RootNetworkPainter(
                      words: _shuffledWords.map((w) => w.word).toList(),
                      translations: _shuffledTranslations,
                      connections: _connections,
                      selectedWordIdx: _selectedWordIdx,
                      pulseValue: _pulseController.value,
                      connectProgress: _connectController.value,
                      dragEnd: _dragEnd,
                    ),
                    child: Stack(
                      children: [
                        // Word nodes
                        ..._shuffledWords.asMap().entries.map((e) {
                          final idx = e.key;
                          final isConnected = _connections.containsKey(idx);
                          final isSelected = _selectedWordIdx == idx;
                          final nodeY = 60.0 + idx * (H - 80) / _shuffledWords.length;
                          return Positioned(
                            left: 16,
                            top: nodeY - 22,
                            child: GestureDetector(
                              onTap: isConnected
                                  ? null
                                  : () {
                                      TtsService.instance.speak(e.value.word, e.value.targetLanguageCode);
                                      setState(() {
                                        _selectedWordIdx =
                                            _selectedWordIdx == idx ? null : idx;
                                        _dragEnd = null;
                                      });
                                    },
                              child: _buildNode(
                                  e.value.word, isConnected, isSelected, true),
                            ),
                          );
                        }),
                        // Translation nodes
                        ..._shuffledTranslations.asMap().entries.map((e) {
                          final idx = e.key;
                          final isConnected =
                              _connections.values.contains(idx);
                          final nodeY = 60.0 + idx * (H - 80) / _shuffledTranslations.length;
                          return Positioned(
                            right: 16,
                            top: nodeY - 22,
                            child: GestureDetector(
                              onTap: isConnected
                                  ? null
                                  : () => _tryConnect(idx),
                              child:
                                  _buildNode(e.value, isConnected, false, false),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNode(
      String text, bool connected, bool selected, bool isWordSide) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 120),
      decoration: BoxDecoration(
        color: connected
            ? SeedlingColors.success.withValues(alpha: 0.15)
            : selected
                ? SeedlingColors.seedlingGreen.withValues(alpha: 0.15)
                : SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: connected
              ? SeedlingColors.success
              : selected
                  ? SeedlingColors.seedlingGreen
                  : SeedlingColors.morningDew.withValues(alpha: 0.4),
          width: connected || selected ? 2.0 : 1.0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
                  blurRadius: 14,
                  spreadRadius: 2,
                )
              ]
            : connected
                ? [
                    BoxShadow(
                      color: SeedlingColors.success.withValues(alpha: 0.2),
                      blurRadius: 10,
                    )
                  ]
                : null,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: SeedlingTypography.body.copyWith(
          fontSize: 13,
          color: connected
              ? SeedlingColors.success
              : selected
                  ? SeedlingColors.seedlingGreen
                  : SeedlingColors.textPrimary,
          fontWeight: connected || selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class RootNetworkPainter extends CustomPainter {
  final List<String> words;
  final List<String> translations;
  final Map<int, int> connections;
  final int? selectedWordIdx;
  final double pulseValue;
  final double connectProgress;
  final Offset? dragEnd;

  const RootNetworkPainter({
    required this.words,
    required this.translations,
    required this.connections,
    required this.selectedWordIdx,
    required this.pulseValue,
    required this.connectProgress,
    this.dragEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final H = size.height;
    final nodeH = (H - 80) / words.length;

    // Draw established connections
    for (final entry in connections.entries) {
      final wIdx = entry.key;
      final tIdx = entry.value;
      final startY = 60 + wIdx * nodeH + 22;
      final endY = 60 + tIdx * nodeH + 22;
      final start = Offset(136, startY);
      final end = Offset(size.width - 136, endY);

      // Glowing root path
      final glowPaint = Paint()
        ..color = SeedlingColors.success.withValues(
            alpha: 0.2 + 0.1 * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final rootPaint = Paint()
        ..color = SeedlingColors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final path = _rootPath(start, end);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, rootPaint);

      // Node pulse circles at ends
      canvas.drawCircle(
        end,
        6 + 3 * pulseValue,
        Paint()
          ..color = SeedlingColors.success.withValues(
              alpha: 0.5 + 0.3 * pulseValue),
      );
    }

    // Draw active drag line from selected word
    if (selectedWordIdx != null && dragEnd != null) {
      final startY = 60 + selectedWordIdx! * nodeH + 22;
      final start = Offset(136, startY);
      final draftPaint = Paint()
        ..color = SeedlingColors.seedlingGreen.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(_rootPath(start, dragEnd!), draftPaint);
    }
  }

  Path _rootPath(Offset start, Offset end) {
    final wave = math.sin(pulseValue * math.pi) * 20;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + (end.dx - start.dx) * 0.3 + wave,
        start.dy + (end.dy - start.dy) * 0.3 - wave,
        end.dx - (end.dx - start.dx) * 0.3 - wave,
        end.dy - (end.dy - start.dy) * 0.3 + wave,
        end.dx,
        end.dy,
      );
  }

  @override
  bool shouldRepaint(covariant RootNetworkPainter old) =>
      old.connections != connections ||
      old.selectedWordIdx != selectedWordIdx ||
      old.pulseValue != pulseValue ||
      old.dragEnd != dragEnd;
}

// ── Enum for all quiz types ───────────────────────────────────

enum QuizTypeV2 {
  deepRoot,
  bloomOrWilt,
  seedSort,
  rootNetwork,
  // Legacy types still available:
  catchTheLeaf,
  buildTheTree,
  engraveRoot,
}

// ── QUIZ TYPE 4: ENGRAVE ROOT (True Active Recall) ─────────────
// The ultimate anti-cheating mastery test. NO DISTRACTORS.
// User must physically type the exact translation string to pass.

class EngraveRootQuiz extends StatefulWidget {
  final Word word;
  final Function(bool correct, int masteryGained) onAnswer;

  const EngraveRootQuiz({
    super.key,
    required this.word,
    required this.onAnswer,
  });

  @override
  State<EngraveRootQuiz> createState() => _EngraveRootQuizState();
}

class _EngraveRootQuizState extends State<EngraveRootQuiz>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _resultAnim;
  
  bool _hasAnswered = false;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode);
    _controller = TextEditingController();
    _focusNode = FocusNode()..requestFocus();
    _resultAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _resultAnim.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    if (_hasAnswered) return;
    
    final input = _controller.text.trim().toLowerCase();
    if (input.isEmpty) return;
    
    final target = widget.word.translation.toLowerCase();

    // Strict Anti-Cheating: exact match required (ignoring case)
    final correct = input == target;
    
    setState(() {
      _hasAnswered = true;
      _isCorrect = correct;
    });

    // Play the correct SFX immediately
    if (correct) {
      AudioService.instance.play(SFX.engraveSuccess);
      AudioService.haptic(HapticType.levelUp); // big vibration = true mastery earned
    } else {
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();
      AudioService.haptic(HapticType.wrong);
    }

    _resultAnim.forward();
    _focusNode.unfocus();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) widget.onAnswer(correct, correct ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),

        // Word card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: SeedlingColors.cardBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: SeedlingColors.morningDew.withValues(alpha: 0.4),
                  width: 2),
              boxShadow: [
                BoxShadow(
                  color: SeedlingColors.seedlingGreen.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text('Engrave the meaning',
                    style: SeedlingTypography.caption
                        .copyWith(color: SeedlingColors.textSecondary)),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TargetWordDisplay(
                    word: widget.word,
                        style: SeedlingTypography.heading1.copyWith(fontSize: 36),
                        textAlign: TextAlign.center),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: SeedlingColors.seedlingGreen),
                      onPressed: () => TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode),
                    ),
                  ],
                ),
                if (widget.word.pronunciation != null) ...[
                  const SizedBox(height: 8),
                  Text(widget.word.pronunciation!,
                      style: SeedlingTypography.caption
                          .copyWith(fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Active Recall Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AnimatedBuilder(
            animation: _resultAnim,
            builder: (ctx, child) {
              Color borderColor = SeedlingColors.morningDew;
              if (_hasAnswered) {
                borderColor = Color.lerp(
                  SeedlingColors.morningDew,
                  _isCorrect ? SeedlingColors.success : SeedlingColors.error,
                  _resultAnim.value,
                )!;
              }

              return Column(
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !_hasAnswered,
                    textAlign: TextAlign.center,
                    style: SeedlingTypography.heading2.copyWith(fontSize: 28),
                    decoration: InputDecoration(
                      hintText: 'Type translation...',
                      hintStyle: SeedlingTypography.heading2.copyWith(
                          fontSize: 24,
                          color: SeedlingColors.textSecondary.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: SeedlingColors.cardBackground,
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: SeedlingColors.sunlight, width: 3),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: SeedlingColors.morningDew, width: 2),
                      ),
                      disabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor, width: _hasAnswered ? 3 : 2),
                      ),
                    ),
                    onSubmitted: (_) => _checkAnswer(),
                  ),
                  
                  // Reveal answer if failed to enforce strict learning
                  if (_hasAnswered && !_isCorrect) ...[
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: _resultAnim.value,
                      child: Column(
                        children: [
                          Text('The correct translation is:',
                              style: SeedlingTypography.caption.copyWith(
                                  color: SeedlingColors.error)),
                          const SizedBox(height: 4),
                          Text(widget.word.translation,
                              style: SeedlingTypography.heading2.copyWith(
                                  color: SeedlingColors.success, fontSize: 28)),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),

        const Spacer(),

        // Submit Button
        if (!_hasAnswered)
          Padding(
            padding: const EdgeInsets.only(bottom: 40, left: 32, right: 32),
            child: GestureDetector(
              onTap: _checkAnswer,
              child: Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: SeedlingColors.seedlingGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.seedlingGreen.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'CHECK',
                  style: SeedlingTypography.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 100),
      ],
    );
  }
}
