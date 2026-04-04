import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/target_word_display.dart';
import '../widgets/word_image.dart';

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

// â”€â”€ QUIZ TYPE 1: DEEP ROOT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Options displayed as roots emerging from soil.
// Correct tap â†’ root glows gold, plant blooms.
// Wrong tap   â†’ root wilts + shakes.

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
  bool _usedHint = false;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.speak(
      widget.word.ttsWord,
      widget.word.targetLanguageCode,
    );
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rootGrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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
      if (mounted) {
        if (!isCorrect) {
          widget.onAnswer(false, 0);
        } else {
          widget.onAnswer(true, _usedHint ? 0 : 1);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 620;

        return Column(
          children: [
            // Word card
            Container(
              margin: EdgeInsets.fromLTRB(24, isSmallScreen ? 12 : 24, 24, 0),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 28,
                vertical: isSmallScreen ? 14 : 22,
              ),
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
                  color: SeedlingColors.morningDew.withValues(alpha: 0.4),
                ),
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
                        color: SeedlingColors.sunlight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: SeedlingColors.sunlight.withValues(alpha: 0.4),
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
                      color: SeedlingColors.textSecondary,
                      fontSize: isSmallScreen ? 11 : 12,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 6 : 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TargetWordDisplay(
                        word: widget.word,
                        style: SeedlingTypography.heading1.copyWith(
                          fontSize: isSmallScreen ? 30 : 38,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.volume_up_rounded,
                          color: SeedlingColors.seedlingGreen,
                          size: isSmallScreen ? 22 : 24,
                        ),
                        onPressed: () => TtsService.instance.speak(
                          widget.word.ttsWord,
                          widget.word.targetLanguageCode,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      // Lifeline hint button
                      if (widget.word.definition != null && !_hasAnswered) ...[
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

            // Garden visualization
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _bloomController,
                  _shakeController,
                  _rootGrowController,
                ]),
                builder: (ctx, _) {
                  final shake =
                      math.sin(_shakeController.value * math.pi * 8) *
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
                        isSmallScreen: isSmallScreen,
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) {
                          if (_hasAnswered) return;
                          final size = context.size ?? Size.zero;
                          final idx = _getRootIndexAtOffset(
                            details.localPosition,
                            size,
                            widget.options.length,
                          );
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
      },
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
  final bool isSmallScreen;

  DeepRootGardenPainter({
    required this.options,
    required this.selectedIndex,
    required this.correctAnswer,
    required this.hasAnswered,
    required this.bloomProgress,
    required this.rootGrowProgress,
    this.isSmallScreen = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * (isSmallScreen ? 0.35 : 0.42);

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
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SeedlingColors.soil.withValues(alpha: 0.85),
              SeedlingColors.deepRoot.withValues(alpha: 0.95),
            ],
          ).createShader(
            Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
          );
    // Wavy ground line
    final groundPath = Path()..moveTo(0, groundY);
    for (double x = 0; x <= size.width; x += 30) {
      groundPath.quadraticBezierTo(
        x + 15,
        groundY + 6 * math.sin((x / size.width) * math.pi * 5),
        x + 30,
        groundY,
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
        Offset(
          rng.nextDouble() * size.width,
          groundY + 10 + rng.nextDouble() * 20,
        ),
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
        hasAnswered &&
        selectedIndex != null &&
        options[selectedIndex!] == correctAnswer;

    // Stem
    final stemH =
        (isSmallScreen ? 40.0 : 60.0) +
        bloomProgress * (isSmallScreen ? 30 : 40);
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
      _drawLeaf(
        canvas,
        cx,
        groundY - 30 * rootGrowProgress,
        -0.5,
        22 * lp,
        leafPaint,
      );
      _drawLeaf(
        canvas,
        cx,
        groundY - 45 * rootGrowProgress,
        0.5,
        20 * lp,
        leafPaint,
      );
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
      ..shader =
          RadialGradient(
            colors: [
              SeedlingColors.sunlight.withValues(alpha: 0.35 * p),
              SeedlingColors.sunlight.withValues(alpha: 0.0),
            ],
            stops: const [0.5, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(cx, cy),
              radius: petalLen * 1.2 + 16,
            ),
          );
    canvas.drawCircle(Offset(cx, cy), petalLen * 1.2 + 16, glowPaint);
    for (int i = 0; i < petals; i++) {
      final angle = (i / petals) * math.pi * 2;
      final ex = cx + math.cos(angle) * petalLen;
      final ey = cy + math.sin(angle) * petalLen;
      final path = Path()
        ..moveTo(cx, cy)
        ..quadraticBezierTo(
          cx + math.cos(angle + 0.4) * petalLen * 0.6,
          cy + math.sin(angle + 0.4) * petalLen * 0.6,
          ex,
          ey,
        )
        ..quadraticBezierTo(
          cx + math.cos(angle - 0.4) * petalLen * 0.6,
          cy + math.sin(angle - 0.4) * petalLen * 0.6,
          cx,
          cy,
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
    Canvas canvas,
    Size size,
    double cx,
    double groundY,
    int index,
  ) {
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
      cx + wave,
      groundY + rootH * 0.3,
      cx - wave,
      groundY + rootH * 0.6,
      cx + wave * 0.5,
      groundY + rootH,
    );
    canvas.drawPath(rootPath, rootPaint);

    // Glow on correct/selected
    if ((hasAnswered && isCorrect) || isSelected) {
      final glowPaint1 = Paint()
        ..color = rootColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round;
      final glowPaint2 = Paint()
        ..color = rootColor.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(rootPath, glowPaint2);
      canvas.drawPath(rootPath, glowPaint1);
    }

    // Root tip circle
    final tipY = groundY + rootH;
    canvas.drawCircle(
      Offset(cx + wave * 0.5, tipY),
      isSelected || (hasAnswered && isCorrect) ? 8 : 5,
      Paint()
        ..color = rootColor
        ..style = PaintingStyle.fill,
    );

    // Touch hint circles (invisible hit zones)
    final hitPaint = Paint()..color = Colors.transparent;
    canvas.drawCircle(Offset(cx, groundY + rootH / 2), 40, hitPaint);

    // Option text label in root zone
    // Calculate responsive label width to prevent overflow
    final labelWidth = math.min(90.0, (size.width / options.length) - 4.0);
    final labelHeight = isSmallScreen ? 28.0 : 36.0;

    _drawRootLabel(
      canvas,
      options[index],
      cx,
      groundY + rootH * 0.5,
      rootColor,
      isSelected || (hasAnswered && isCorrect),
      labelWidth,
      labelHeight,
    );
  }

  void _drawRootLabel(
    Canvas canvas,
    String text,
    double cx,
    double cy,
    Color color,
    bool highlighted,
    double labelWidth,
    double labelHeight,
  ) {
    final bg = Paint()
      ..color = (highlighted
          ? color.withValues(alpha: 0.18)
          : SeedlingColors.cardBackground.withValues(alpha: 0.85))
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: labelWidth,
        height: labelHeight,
      ),
      Radius.circular(labelHeight / 2),
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
          fontSize: isSmallScreen ? 11 : 13,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout(maxWidth: labelWidth - 8);
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double size,
    Paint paint,
  ) {
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

// â”€â”€ QUIZ TYPE 3: SEED SORT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    TtsService.instance.speak(
      widget.word.ttsWord,
      widget.word.targetLanguageCode,
    );
    _fallController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sortController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
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
        final isSmallScreen = H < 620 || W < 360;
        final pot0Center = Offset(W * 0.25, H * (isSmallScreen ? 0.85 : 0.82));
        final pot1Center = Offset(W * 0.75, H * (isSmallScreen ? 0.85 : 0.82));

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
                final seedX = _isDragging ? _dragPos.dx - 40 : W / 2 - 40;

                return Positioned(
                  left: seedX,
                  top: seedY,
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onPanStart: (_fallController.isCompleted)
                        ? (d) => setState(() {
                            _isDragging = true;
                            _dragPos = d.localPosition + Offset(seedX, seedY);
                          })
                        : null,
                    onPanUpdate: _isDragging
                        ? (d) => setState(() => _dragPos += d.delta)
                        : null,
                    onPanEnd: _isDragging
                        ? (_) {
                            // Detect closest pot
                            final curPos = Offset(_dragPos.dx, _dragPos.dy);
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
                        isDragging: _isDragging,
                      ),
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
                  builder: (ctx, v, child) => Opacity(opacity: v, child: child),
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

  DraggableSeedPainter({required this.label, required this.isDragging});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = isDragging ? 1.12 : 1.0;

    // Glow
    if (isDragging) {
      final glowRadius = 42 * scale;
      final glowPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                SeedlingColors.seedlingGreen.withValues(alpha: 0.25),
                SeedlingColors.seedlingGreen.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius + 14),
            );
      canvas.drawCircle(Offset(cx, cy), glowRadius + 14, glowPaint);
    }

    // Seed body
    final seedPaint = Paint()
      ..color = SeedlingColors.soil
      ..style = PaintingStyle.fill;

    final path = _seedPath(cx, cy, 36 * scale, 46 * scale);

    canvas.save();
    canvas.translate(3, 5);
    canvas.drawShadow(
      path,
      SeedlingColors.deepRoot.withValues(alpha: 0.25),
      6.0,
      false,
    );
    canvas.restore();

    canvas.drawPath(path, seedPaint);

    final highlightPaint = Paint()
      ..color = SeedlingColors.morningDew.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      _seedPath(cx - 8, cy - 10, 14 * scale, 18 * scale),
      highlightPaint,
    );
    canvas.restore();

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: SeedlingTypography.body.copyWith(
          color: SeedlingColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          shadows: [
            const Shadow(color: SeedlingColors.deepRoot, blurRadius: 4),
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
      ..cubicTo(
        cx + rw,
        cy - rh * 0.6,
        cx + rw * 0.8,
        cy + rh * 0.4,
        cx,
        cy + rh,
      )
      ..cubicTo(
        cx - rw * 0.8,
        cy + rh * 0.4,
        cx - rw,
        cy - rh * 0.6,
        cx,
        cy - rh,
      )
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

  SeedSortBgPainter({
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
      potColor = Color.lerp(
        SeedlingColors.soil,
        SeedlingColors.success,
        sortProgress,
      )!;
    } else if (isDropWrong) {
      potColor = Color.lerp(
        SeedlingColors.soil,
        SeedlingColors.error,
        sortProgress,
      )!;
    }

    // Pot glow
    if (isDropped) {
      final glowPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                potColor.withValues(alpha: 0.25 * sortProgress),
                potColor.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx, cy),
                radius: 85, // 65 + 20
              ),
            );
      canvas.drawCircle(Offset(cx, cy), 85, glowPaint);
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
      Rect.fromCenter(center: Offset(cx, cy - 2), width: 74, height: 18),
      Paint()..color = SeedlingColors.deepRoot.withValues(alpha: 0.9),
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
        _drawLeaf(
          canvas,
          cx,
          cy - 8 - 20 * sp,
          -0.5,
          14 * lp,
          Paint()
            ..color = SeedlingColors.freshSprout
            ..style = PaintingStyle.fill,
        );
        _drawLeaf(
          canvas,
          cx,
          cy - 8 - 26 * sp,
          0.5,
          12 * lp,
          Paint()
            ..color = SeedlingColors.freshSprout
            ..style = PaintingStyle.fill,
        );
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
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 58));
  }

  void _drawLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double sz,
    Paint paint,
  ) {
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

// â”€â”€ QUIZ TYPE 4: ROOT NETWORK â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
  final Map<int, int> _connections = {}; // wordIdx â†’ transIdx
  int? _selectedWordIdx;
  int _correct = 0;
  late AnimationController _pulseController;
  late AnimationController _connectController;
  Offset? _dragEnd;

  @override
  void initState() {
    super.initState();
    _shuffledWords = List.from(widget.words)..shuffle();
    _shuffledTranslations = _shuffledWords.map((w) => w.translation).toList()
      ..shuffle();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _connectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
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
      // Wrong â€” flash and deselect
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
              Text(
                'Connect the Roots',
                style: SeedlingTypography.heading2.copyWith(
                  color: SeedlingColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Match each word to its meaning',
                style: SeedlingTypography.caption,
              ),
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
                          SeedlingColors.freshSprout,
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
            animation: Listenable.merge([_pulseController, _connectController]),
            builder: (ctx, _) {
              return LayoutBuilder(
                builder: (ctx, constraints) {
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
                            final isSmall = H < 500;
                            final isConnected = _connections.containsKey(idx);
                            final isSelected = _selectedWordIdx == idx;
                            final topMargin = isSmall ? 30.0 : 60.0;
                            final bottomPadding = isSmall ? 40.0 : 80.0;
                            final nodeY =
                                topMargin +
                                idx *
                                    (H - bottomPadding) /
                                    _shuffledWords.length;
                            return Positioned(
                              left: isSmall ? 8 : 16,
                              top: nodeY - (isSmall ? 18 : 22),
                              child: GestureDetector(
                                onTap: isConnected
                                    ? null
                                    : () {
                                        TtsService.instance.speak(
                                          e.value.word,
                                          e.value.targetLanguageCode,
                                        );
                                        setState(() {
                                          _selectedWordIdx =
                                              _selectedWordIdx == idx
                                              ? null
                                              : idx;
                                          _dragEnd = null;
                                        });
                                      },
                                child: _buildNode(
                                  e.value.word,
                                  isConnected,
                                  isSelected,
                                  true,
                                  isSmall,
                                ),
                              ),
                            );
                          }),
                          // Translation nodes
                          ..._shuffledTranslations.asMap().entries.map((e) {
                            final idx = e.key;
                            final isSmall = H < 500;
                            final isConnected = _connections.values.contains(
                              idx,
                            );
                            final topMargin = isSmall ? 30.0 : 60.0;
                            final bottomPadding = isSmall ? 40.0 : 80.0;
                            final nodeY =
                                topMargin +
                                idx *
                                    (H - bottomPadding) /
                                    _shuffledTranslations.length;
                            return Positioned(
                              right: isSmall ? 8 : 16,
                              top: nodeY - (isSmall ? 18 : 22),
                              child: GestureDetector(
                                onTap: isConnected
                                    ? null
                                    : () => _tryConnect(idx),
                                child: _buildNode(
                                  e.value,
                                  isConnected,
                                  false,
                                  false,
                                  isSmall,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
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

  Widget _buildNode(
    String text,
    bool connected,
    bool selected,
    bool isWordSide,
    bool isSmall,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 10 : 14,
        vertical: isSmall ? 6 : 10,
      ),
      constraints: BoxConstraints(maxWidth: isSmall ? 100 : 120),
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
                ),
              ]
            : connected
            ? [
                BoxShadow(
                  color: SeedlingColors.success.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: SeedlingTypography.body.copyWith(
          fontSize: isSmall ? 11 : 13,
          color: connected
              ? SeedlingColors.success
              : selected
              ? SeedlingColors.seedlingGreen
              : SeedlingColors.textPrimary,
          fontWeight: connected || selected
              ? FontWeight.bold
              : FontWeight.normal,
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

  RootNetworkPainter({
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
    final isSmall = H < 500;
    final topMargin = isSmall ? 30.0 : 60.0;
    final bottomPadding = isSmall ? 40.0 : 80.0;
    final nodeH = (H - bottomPadding) / words.length;

    // Draw established connections
    for (final entry in connections.entries) {
      final wIdx = entry.key;
      final tIdx = entry.value;
      final startY = topMargin + wIdx * nodeH + (isSmall ? 15 : 22);
      final endY = topMargin + tIdx * nodeH + (isSmall ? 15 : 22);
      final start = Offset(isSmall ? 90 : 136, startY);
      final end = Offset(size.width - (isSmall ? 90 : 136), endY);

      // Glowing root path
      final glowPaint1 = Paint()
        ..color = SeedlingColors.success.withValues(
          alpha: 0.15 + 0.05 * pulseValue,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      final glowPaint2 = Paint()
        ..color = SeedlingColors.success.withValues(
          alpha: 0.1 + 0.05 * pulseValue,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      final rootPaint = Paint()
        ..color = SeedlingColors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final path = _rootPath(start, end);
      canvas.drawPath(path, glowPaint2);
      canvas.drawPath(path, glowPaint1);
      canvas.drawPath(path, rootPaint);

      // Node pulse circles at ends
      canvas.drawCircle(
        end,
        6 + 3 * pulseValue,
        Paint()
          ..color = SeedlingColors.success.withValues(
            alpha: 0.5 + 0.3 * pulseValue,
          ),
      );
    }

    // Draw active drag line from selected word
    if (selectedWordIdx != null && dragEnd != null) {
      final startY = topMargin + selectedWordIdx! * nodeH + (isSmall ? 15 : 22);
      final start = Offset(isSmall ? 90 : 136, startY);
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

// â”€â”€ Enum for all quiz types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€ QUIZ TYPE 4: ENGRAVE ROOT (True Active Recall) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    TtsService.instance.speak(
      widget.word.ttsWord,
      widget.word.targetLanguageCode,
    );
    _controller = TextEditingController();
    _focusNode = FocusNode()..requestFocus();
    _resultAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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
      AudioService.haptic(
        HapticType.levelUp,
      ); // big vibration = true mastery earned
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 620;

        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: isSmallScreen ? 16 : 30),

              // Word card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 28,
                    vertical: isSmallScreen ? 16 : 24,
                  ),
                  decoration: BoxDecoration(
                    color: SeedlingColors.cardBackground,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: SeedlingColors.morningDew.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SeedlingColors.seedlingGreen.withValues(
                          alpha: 0.12,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Engrave the meaning',
                        style: SeedlingTypography.caption.copyWith(
                          color: SeedlingColors.textSecondary,
                          fontSize: isSmallScreen ? 11 : 12,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TargetWordDisplay(
                            word: widget.word,
                            style: SeedlingTypography.heading1.copyWith(
                              fontSize: isSmallScreen ? 28 : 36,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.volume_up_rounded,
                              color: SeedlingColors.seedlingGreen,
                              size: isSmallScreen ? 22 : 24,
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

              SizedBox(height: isSmallScreen ? 24 : 40),

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
                        _isCorrect
                            ? SeedlingColors.success
                            : SeedlingColors.error,
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
                          style: SeedlingTypography.heading2.copyWith(
                            fontSize: isSmallScreen ? 22 : 28,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type translation...',
                            hintStyle: SeedlingTypography.heading2.copyWith(
                              fontSize: isSmallScreen ? 20 : 24,
                              color: SeedlingColors.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            filled: true,
                            fillColor: SeedlingColors.cardBackground,
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: SeedlingColors.sunlight,
                                width: 3,
                              ),
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: SeedlingColors.morningDew,
                                width: 2,
                              ),
                            ),
                            disabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: borderColor,
                                width: _hasAnswered ? 3 : 2,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _checkAnswer(),
                        ),

                        // Reveal answer if failed to enforce strict learning
                        if (_hasAnswered && !_isCorrect) ...[
                          const SizedBox(height: 16),
                          Opacity(
                            opacity: _resultAnim.value,
                            child: Column(
                              children: [
                                Text(
                                  'The correct translation is:',
                                  style: SeedlingTypography.caption.copyWith(
                                    color: SeedlingColors.error,
                                    fontSize: isSmallScreen ? 10 : 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.word.translation,
                                  style: SeedlingTypography.heading2.copyWith(
                                    color: SeedlingColors.success,
                                    fontSize: isSmallScreen ? 22 : 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

              SizedBox(height: isSmallScreen ? 32 : 60),

              // Submit Button
              if (!_hasAnswered)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: isSmallScreen ? 20 : 40,
                    left: 32,
                    right: 32,
                  ),
                  child: GestureDetector(
                    onTap: _checkAnswer,
                    child: Container(
                      height: isSmallScreen ? 54 : 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: SeedlingColors.seedlingGreen,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: SeedlingColors.seedlingGreen.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'CHECK',
                        style: SeedlingTypography.bodyLarge.copyWith(
                          color: SeedlingColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(height: isSmallScreen ? 60 : 100),
            ],
          ),
        );
      },
    );
  }
}

// ================================================================
// IMAGE QUIZ TYPE 6: PICTURE PICK
// Show the foreign word at top. Display a 2×2 image grid.
// Tap the picture that matches the word.
// ================================================================

class PicturePickQuiz extends StatefulWidget {
  final Word word;
  final List<Word> options; // 4 words total — 1 correct + 3 distractors
  final Function(bool correct, int masteryGained) onAnswer;

  const PicturePickQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<PicturePickQuiz> createState() => _PicturePickQuizState();
}

class _PicturePickQuizState extends State<PicturePickQuiz>
    with TickerProviderStateMixin {
  int? _selectedIndex;
  bool _answered = false;
  late AnimationController _feedbackController;
  late Animation<double> _feedbackAnim;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _feedbackAnim = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (_answered) return;
    final correct = widget.options[index].id == widget.word.id;
    setState(() {
      _selectedIndex = index;
      _answered = true;
    });
    _feedbackController.forward();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onAnswer(correct, correct ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 360;
        return Padding(
          padding: EdgeInsets.all(isSmall ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // -- Prompt: foreign word --
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: SeedlingColors.morningDew.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.12,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '??? Which picture matches?',
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.textSecondary,
                        fontSize: isSmall ? 11 : 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TargetWordDisplay(
                      word: widget.word,
                      style: SeedlingTypography.heading1.copyWith(
                        fontSize: isSmall ? 26 : 32,
                        color: SeedlingColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmall ? 16 : 24),

              // -- 2×2 Image Grid --
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(widget.options.length, (i) {
                    final opt = widget.options[i];
                    final isCorrect = opt.id == widget.word.id;
                    final isSelected = _selectedIndex == i;
                    final showResult = _answered && isSelected;

                    Color borderColor = SeedlingColors.morningDew.withValues(
                      alpha: 0.3,
                    );
                    if (showResult) {
                      borderColor = isCorrect
                          ? SeedlingColors.success
                          : SeedlingColors.error;
                    } else if (_answered && isCorrect) {
                      borderColor = SeedlingColors.success;
                    }

                    return GestureDetector(
                      onTap: () => _onTap(i),
                      child: AnimatedBuilder(
                        animation: _feedbackAnim,
                        builder: (_, child) {
                          final scale = (showResult && isCorrect)
                              ? (1.0 +
                                    0.06 *
                                        math.sin(_feedbackAnim.value * math.pi))
                              : 1.0;
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor, width: 2.5),
                            boxShadow: [
                              if (_answered && isCorrect)
                                BoxShadow(
                                  color: SeedlingColors.success.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _ImageOrPlaceholder(opt: opt),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: AnimatedOpacity(
                                    opacity: _answered ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              bottom: Radius.circular(16),
                                            ),
                                      ),
                                      child: Text(
                                        opt.translation,
                                        style: const TextStyle(
                                          color: SeedlingColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                if (showResult)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: ScaleTransition(
                                      scale: _feedbackAnim,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isCorrect
                                              ? SeedlingColors.success
                                              : SeedlingColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isCorrect
                                              ? Icons.check_rounded
                                              : Icons.close_rounded,
                                          color: SeedlingColors.textPrimary,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImageOrPlaceholder extends StatelessWidget {
  final Word opt;
  const _ImageOrPlaceholder({required this.opt});

  static final Map<String, String> _categoryEmoji = {
    'food': '??',
    'animals': '??',
    'nature': '??',
    'body': '???',
    'clothing': '??',
    'colors': '??',
    'numbers': '??',
    'time': '?',
    'travel': '??',
    'family': '????????',
    'house': '??',
    'work': '??',
    'sports': '?',
    'weather': '???',
    'tools': '??',
  };

  String get _emoji {
    final cat = opt.category.toLowerCase();
    for (final key in _categoryEmoji.keys) {
      if (cat.contains(key)) return _categoryEmoji[key]!;
    }
    return '??';
  }

  @override
  Widget build(BuildContext context) {
    final path = WordImage.assetPath(opt.imageId);
    if (path != null) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildEmoji(),
      );
    }
    return _buildEmoji();
  }

  Widget _buildEmoji() {
    return Container(
      color: SeedlingColors.morningDew.withValues(alpha: 0.15),
      child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 52))),
    );
  }
}

// ================================================================
// IMAGE QUIZ TYPE 7: WHAT WORD IS THIS?
// Show a large image (top 55%). Pick the correct word from 4 options.
// ================================================================

class WhatWordIsThisQuiz extends StatefulWidget {
  final Word word;
  final List<String> options; // 4 translation strings
  final Function(bool correct, int masteryGained) onAnswer;

  const WhatWordIsThisQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<WhatWordIsThisQuiz> createState() => _WhatWordIsThisQuizState();
}

class _WhatWordIsThisQuizState extends State<WhatWordIsThisQuiz>
    with SingleTickerProviderStateMixin {
  int? _selected;
  bool _answered = false;
  late AnimationController _sparkleCtrl;

  @override
  void initState() {
    super.initState();
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _sparkleCtrl.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (_answered) return;
    final correct = widget.options[index] == widget.word.translation;
    setState(() {
      _selected = index;
      _answered = true;
    });
    if (correct) _sparkleCtrl.forward();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onAnswer(correct, correct ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = WordImage.assetPath(widget.word.imageId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 360;
        final imageH = constraints.maxHeight * 0.45;

        return Column(
          children: [
            SizedBox(
              height: imageH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                    child: path != null
                        ? Image.asset(
                            path,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          '?? What word is this?',
                          style: TextStyle(
                            color: SeedlingColors.textPrimary,
                            fontSize: isSmall ? 12 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_answered)
                    AnimatedBuilder(
                      animation: _sparkleCtrl,
                      builder: (_, __) => CustomPaint(
                        painter: _SparklePainter(_sparkleCtrl.value),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isSmall ? 10 : 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(widget.options.length, (i) {
                    final opt = widget.options[i];
                    final isCorrect = opt == widget.word.translation;
                    final isSelected = _selected == i;

                    Color bg = SeedlingColors.cardBackground;
                    Color textColor = SeedlingColors.textPrimary;
                    if (_answered) {
                      if (isCorrect) {
                        bg = SeedlingColors.success.withValues(alpha: 0.15);
                        textColor = SeedlingColors.success;
                      } else if (isSelected) {
                        bg = SeedlingColors.error.withValues(alpha: 0.1);
                        textColor = SeedlingColors.error;
                      }
                    }

                    return GestureDetector(
                      onTap: () => _onTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmall ? 10 : 14,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _answered && isCorrect
                                ? SeedlingColors.success
                                : SeedlingColors.morningDew.withValues(
                                    alpha: 0.4,
                                  ),
                            width: _answered && isCorrect ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          opt,
                          style: SeedlingTypography.body.copyWith(
                            fontSize: isSmall ? 14 : 16,
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: SeedlingColors.morningDew.withValues(alpha: 0.18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('??', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(
              widget.word.word,
              style: SeedlingTypography.heading2.copyWith(
                color: SeedlingColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// IMAGE QUIZ TYPE 8: GARDEN SORT
// Two image cards shown at top. Two labeled soil pots at bottom.
// Drag each image into the correct pot.
// ================================================================

class GardenSortQuiz extends StatefulWidget {
  final Word word;
  final Word decoyWord;
  final Function(bool correct, int masteryGained) onAnswer;

  const GardenSortQuiz({
    super.key,
    required this.word,
    required this.decoyWord,
    required this.onAnswer,
  });

  @override
  State<GardenSortQuiz> createState() => _GardenSortQuizState();
}

class _GardenSortQuizState extends State<GardenSortQuiz>
    with TickerProviderStateMixin {
  int? _correctCardPot;
  bool _answered = false;

  late AnimationController _bounceCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  late List<String> _potLabels;
  late int _correctPotIndex;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    final rng = math.Random();
    _correctPotIndex = rng.nextBool() ? 0 : 1;
    if (_correctPotIndex == 0) {
      _potLabels = [widget.word.translation, widget.decoyWord.translation];
    } else {
      _potLabels = [widget.decoyWord.translation, widget.word.translation];
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDropped(int potIndex) {
    if (_answered) return;
    final correct = potIndex == _correctPotIndex;
    setState(() {
      _correctCardPot = potIndex;
      _answered = true;
    });
    if (correct) {
      _bounceCtrl.forward();
    } else {
      _shakeCtrl.forward();
    }
    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) widget.onAnswer(correct, correct ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetPath = WordImage.assetPath(widget.word.imageId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 360;
        final cardW = isSmall ? 140.0 : 170.0;
        final cardH = cardW;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, isSmall ? 12 : 20, 16, 0),
              child: Text(
                '?? Drop the image into the right pot',
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                  fontSize: isSmall ? 13 : 15,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              flex: 2,
              child: Center(
                child: _answered
                    ? const SizedBox.shrink()
                    : Draggable<bool>(
                        data: true,
                        feedback: _buildCard(
                          targetPath,
                          cardW,
                          cardH,
                          shadow: true,
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.25,
                          child: _buildCard(targetPath, cardW, cardH),
                        ),
                        child: _buildCard(targetPath, cardW, cardH),
                      ),
              ),
            ),

            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(2, (potIndex) {
                  return _buildPot(
                    potIndex: potIndex,
                    label: _potLabels[potIndex],
                    cardW: cardW,
                    cardH: cardH,
                    targetPath: targetPath,
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(String? path, double w, double h, {bool shadow = false}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: SeedlingColors.deepRoot.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: path != null
            ? Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderCard(),
              )
            : _placeholderCard(),
      ),
    );
  }

  Widget _placeholderCard() {
    return Container(
      color: SeedlingColors.morningDew.withValues(alpha: 0.2),
      child: const Center(child: Text('??', style: TextStyle(fontSize: 48))),
    );
  }

  Widget _buildPot({
    required int potIndex,
    required String label,
    required double cardW,
    required double cardH,
    String? targetPath,
  }) {
    final isTarget = potIndex == _correctPotIndex;
    final hasDrop = _answered && _correctCardPot == potIndex;
    final isWrongDrop = hasDrop && !isTarget;

    Color potBg = SeedlingColors.cardBackground;
    if (_answered) {
      if (isTarget) potBg = SeedlingColors.success.withValues(alpha: 0.13);
      if (isWrongDrop) potBg = SeedlingColors.error.withValues(alpha: 0.10);
    }

    return DragTarget<bool>(
      onAcceptWithDetails: (_) => _onDropped(potIndex),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) {
            final dx = isWrongDrop
                ? 8 * math.sin(_shakeAnim.value * math.pi * 3)
                : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: cardW + 16,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHovering
                  ? SeedlingColors.seedlingGreen.withValues(alpha: 0.15)
                  : potBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHovering
                    ? SeedlingColors.seedlingGreen
                    : _answered && isTarget
                    ? SeedlingColors.success
                    : SeedlingColors.morningDew.withValues(alpha: 0.4),
                width: isHovering || (_answered && isTarget) ? 2.5 : 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('??', style: TextStyle(fontSize: cardW * 0.25)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _answered && isTarget
                        ? SeedlingColors.success
                        : _answered && isWrongDrop
                        ? SeedlingColors.error
                        : SeedlingColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasDrop) ...[
                  const SizedBox(height: 6),
                  Icon(
                    isTarget
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: isTarget
                        ? SeedlingColors.success
                        : SeedlingColors.error,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double progress;
  _SparklePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 18; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final dist = progress * (size.width * 0.45);
      final x = size.width / 2 + math.cos(angle) * dist;
      final y = size.height * 0.45 + math.sin(angle) * dist * 0.6;
      final r = (3 + rng.nextDouble() * 5) * (1 - progress);
      final hue = 80 + rng.nextDouble() * 80;
      paint.color = HSLColor.fromAHSL(1 - progress, hue, 0.85, 0.55).toColor();
      canvas.drawCircle(Offset(x, y), r.clamp(0, 8), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.progress != progress;
}

// ================================================================
// BLOOM OR WILT QUIZ (Feature 4: True/False with Reaction)
// ================================================================
// Shows a word + a proposed translation.
// "BLOOM" if correct, "WILT" if incorrect.
// ================================================================

class BloomOrWiltQuiz extends StatefulWidget {
  final Word word;
  final String proposedTranslation;
  final bool isActuallyCorrect;
  final Function(bool correct, int masteryGained) onAnswer;

  const BloomOrWiltQuiz({
    super.key,
    required this.word,
    required this.proposedTranslation,
    required this.isActuallyCorrect,
    required this.onAnswer,
  });

  @override
  State<BloomOrWiltQuiz> createState() => _BloomOrWiltQuizState();
}

class _BloomOrWiltQuizState extends State<BloomOrWiltQuiz>
    with TickerProviderStateMixin {
  late AnimationController _reactionController;
  late AnimationController _entryController;
  bool _hasAnswered = false;
  bool? _selectedCorrect;

  @override
  void initState() {
    super.initState();
    _reactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _reactionController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _handleAnswer(bool userSaidCorrect) {
    if (_hasAnswered) return;
    final isCorrect = userSaidCorrect == widget.isActuallyCorrect;
    setState(() {
      _hasAnswered = true;
      _selectedCorrect = userSaidCorrect;
    });

    if (isCorrect) {
      _reactionController.forward(); // Bloom
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _reactionController.forward(); // Wilt (handled by painter state)
      AudioService.haptic(HapticType.wrong).ignore();
    }

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect =
        _hasAnswered && _selectedCorrect == widget.isActuallyCorrect;

    return FadeTransition(
      opacity: _entryController,
      child: Column(
        children: [
          const SizedBox(height: 40),
          // ── Plant Reaction Area ──────────────────────────────────
          SizedBox(
            height: 240,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _reactionController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _PlantReactionPainter(
                    progress: _reactionController.value,
                    isCorrect: isCorrect,
                    hasAnswered: _hasAnswered,
                  ),
                );
              },
            ),
          ),

          const Spacer(),

          // ── Statement Card ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: SeedlingColors.cardBackground,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: _hasAnswered
                      ? (isCorrect
                                ? SeedlingColors.success
                                : SeedlingColors.error)
                            .withValues(alpha: 0.4)
                      : SeedlingColors.morningDew.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    widget.word.word,
                    style: SeedlingTypography.heading1.copyWith(
                      color: SeedlingColors.textPrimary,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'means',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.proposedTranslation,
                    style: SeedlingTypography.heading2.copyWith(
                      color: SeedlingColors.seedlingGreen,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // ── Choice Buttons ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Row(
              children: [
                // WILT (False)
                Expanded(
                  child: _ChoiceButton(
                    label: 'WILT',
                    icon: Icons.close_rounded,
                    color: SeedlingColors.error,
                    isSelected: _hasAnswered && _selectedCorrect == false,
                    isAnswered: _hasAnswered,
                    onTap: () => _handleAnswer(false),
                  ),
                ),
                const SizedBox(width: 16),
                // BLOOM (True)
                Expanded(
                  child: _ChoiceButton(
                    label: 'BLOOM',
                    icon: Icons.local_florist_rounded,
                    color: SeedlingColors.seedlingGreen,
                    isSelected: _hasAnswered && _selectedCorrect == true,
                    isAnswered: _hasAnswered,
                    onTap: () => _handleAnswer(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isAnswered;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isAnswered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = isAnswered && !isSelected
        ? SeedlingColors.textSecondary.withValues(alpha: 0.3)
        : color;

    return GestureDetector(
      onTap: isAnswered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : SeedlingColors.morningDew.withValues(alpha: 0.2),
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 15)]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: displayColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: SeedlingTypography.caption.copyWith(
                color: displayColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantReactionPainter extends CustomPainter {
  final double progress;
  final bool isCorrect;
  final bool hasAnswered;

  _PlantReactionPainter({
    required this.progress,
    required this.isCorrect,
    required this.hasAnswered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw Stem
    final stemPath = Path();
    stemPath.moveTo(center.dx, size.height);

    double droop = 0;
    if (hasAnswered && !isCorrect) {
      droop = progress * 40; // Wilt droop
    }

    stemPath.quadraticBezierTo(
      center.dx + (hasAnswered && !isCorrect ? progress * 20 : 0),
      size.height * 0.7,
      center.dx,
      center.dy - droop,
    );

    paint.color = hasAnswered && !isCorrect
        ? Color.lerp(SeedlingColors.seedlingGreen, Colors.brown, progress)!
        : SeedlingColors.seedlingGreen;
    paint.strokeWidth = 6;
    canvas.drawPath(stemPath, paint);

    // Draw Leaves
    final leafPaint = Paint()..style = PaintingStyle.fill;
    leafPaint.color = paint.color.withValues(alpha: 0.8);

    // Simple leaf shapes
    _drawLeaf(canvas, center + const Offset(-15, 20), -0.5, leafPaint);
    _drawLeaf(canvas, center + const Offset(15, 10), 0.5, leafPaint);

    // Draw Flower/Bud at top
    final flowerCenter = Offset(center.dx, center.dy - droop);
    if (!hasAnswered || (hasAnswered && isCorrect)) {
      // Blooming logic
      const petalCount = 6;
      final bloomProgress = hasAnswered ? progress : 0.2;
      final petalColor = Color.lerp(
        SeedlingColors.freshSprout,
        SeedlingColors.hibiscusRed,
        bloomProgress,
      )!;

      for (int i = 0; i < petalCount; i++) {
        final angle = (i * 2 * math.pi / petalCount) + (bloomProgress * 0.5);
        final petalDist = 10 + (bloomProgress * 25);
        final petalSize = 8 + (bloomProgress * 15);

        final petalPos = Offset(
          flowerCenter.dx + math.cos(angle) * petalDist,
          flowerCenter.dy + math.sin(angle) * petalDist,
        );

        canvas.drawCircle(
          petalPos,
          petalSize,
          Paint()..color = petalColor.withValues(alpha: 0.7),
        );
      }
      canvas.drawCircle(
        flowerCenter,
        10 + bloomProgress * 5,
        Paint()..color = Colors.amber,
      );
    } else {
      // Wilting logic
      canvas.drawCircle(
        flowerCenter,
        12 * (1 - progress * 0.5),
        Paint()..color = Colors.brown.withValues(alpha: 0.6),
      );
    }
  }

  void _drawLeaf(Canvas canvas, Offset pos, double angle, Paint paint) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(10, -10, 20, 0);
    path.quadraticBezierTo(10, 10, 0, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlantReactionPainter old) =>
      old.progress != progress || old.isCorrect != isCorrect;
}

// ================================================================
// IMAGE MATCH QUIZ (Feature 6: Image-First Learning)
// ================================================================
// Shows one large image + 2-4 text translation buttons.
// Tests the visual → word memory pathway (Picture Superiority Effect).
//
// Only used when word.imageId != null.
// ================================================================

class ImageMatchQuiz extends StatefulWidget {
  final Word word;
  final List<String> options; // translation strings from QuizManager
  final Function(bool correct, int masteryGained) onAnswer;

  const ImageMatchQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<ImageMatchQuiz> createState() => _ImageMatchQuizState();
}

class _ImageMatchQuizState extends State<ImageMatchQuiz>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _shakeController;
  late AnimationController _bloomController;
  int? _selectedIndex;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _shakeController.dispose();
    _bloomController.dispose();
    super.dispose();
  }

  void _handleAnswer(int index) {
    if (_hasAnswered) return;
    final isCorrect = widget.options[index] == widget.word.translation;
    setState(() {
      _selectedIndex = index;
      _hasAnswered = true;
    });
    if (isCorrect) {
      _bloomController.forward();
      AudioService.haptic(HapticType.correct).ignore();
      // Speak the word AFTER answering as reinforcement
      TtsService.instance.speak(
        widget.word.ttsWord,
        widget.word.targetLanguageCode,
      );
    } else {
      _shakeController.forward(from: 0);
      AudioService.haptic(HapticType.wrong).ignore();
    }
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 620;
        final imageSize = isSmall ? 160.0 : 220.0;

        return FadeTransition(
          opacity: _entryController,
          child: Column(
            children: [
              // ── Instruction label ───────────────────────────────────
              Padding(
                padding: EdgeInsets.only(top: isSmall ? 16 : 28, bottom: 8),
                child: Text(
                  'What do you see?',
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.textSecondary,
                    fontSize: isSmall ? 12 : 13,
                  ),
                ),
              ),

              // ── Image ───────────────────────────────────────────────
              AnimatedBuilder(
                animation: Listenable.merge([
                  _bloomController,
                  _shakeController,
                ]),
                builder: (_, __) {
                  final shake =
                      math.sin(_shakeController.value * math.pi * 8) *
                      10 *
                      (1 - _shakeController.value);
                  final scale = 1.0 + (_bloomController.value * 0.06);
                  return Transform.translate(
                    offset: Offset(shake, 0),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: imageSize,
                        height: imageSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: SeedlingColors.seedlingGreen.withValues(
                                alpha: _hasAnswered ? 0.3 : 0.15,
                              ),
                              blurRadius: _hasAnswered ? 28 : 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: _hasAnswered
                              ? Border.all(
                                  color:
                                      _selectedIndex != null &&
                                          widget.options[_selectedIndex!] ==
                                              widget.word.translation
                                      ? SeedlingColors.success
                                      : SeedlingColors.error,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/images/words/${widget.word.imageId}.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: SeedlingColors.cardBackground,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: SeedlingColors.textSecondary,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Correct word reveal (after answering wrong) ─────────
              if (_hasAnswered &&
                  _selectedIndex != null &&
                  widget.options[_selectedIndex!] !=
                      widget.word.translation) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: SeedlingColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: SeedlingColors.success.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: SeedlingColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.word.translation,
                        style: SeedlingTypography.bodyLarge.copyWith(
                          color: SeedlingColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // ── Answer buttons ──────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, isSmall ? 20 : 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = _selectedIndex == index;
                    final isCorrect = option == widget.word.translation;

                    Color bgColor = SeedlingColors.cardBackground;
                    Color borderColor = SeedlingColors.morningDew.withValues(
                      alpha: 0.35,
                    );

                    if (_hasAnswered) {
                      if (isCorrect) {
                        bgColor = SeedlingColors.success.withValues(
                          alpha: 0.18,
                        );
                        borderColor = SeedlingColors.success;
                      } else if (isSelected && !isCorrect) {
                        bgColor = SeedlingColors.error.withValues(alpha: 0.15);
                        borderColor = SeedlingColors.error;
                      }
                    } else if (isSelected) {
                      bgColor = SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.1,
                      );
                      borderColor = SeedlingColors.seedlingGreen;
                    }

                    return Padding(
                      padding: EdgeInsets.only(bottom: isSmall ? 8 : 11),
                      child: GestureDetector(
                        onTap: () => _handleAnswer(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          padding: EdgeInsets.symmetric(
                            vertical: isSmall ? 13 : 17,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: borderColor,
                              width: isSelected || (_hasAnswered && isCorrect)
                                  ? 2.0
                                  : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: SeedlingTypography.bodyLarge.copyWith(
                                    fontSize: isSmall ? 14 : 16,
                                  ),
                                ),
                              ),
                              if (_hasAnswered && isCorrect)
                                const Icon(
                                  Icons.check_circle,
                                  color: SeedlingColors.success,
                                  size: 20,
                                ),
                              if (_hasAnswered && isSelected && !isCorrect)
                                const Icon(
                                  Icons.cancel,
                                  color: SeedlingColors.error,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
