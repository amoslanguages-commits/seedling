import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';

class SeedlingMascot extends StatefulWidget {
  final double size;
  final MascotState state;
  final VoidCallback? onTap;

  const SeedlingMascot({
    super.key,
    this.size = 120,
    this.state = MascotState.idle,
    this.onTap,
  });

  @override
  State<SeedlingMascot> createState() => _SeedlingMascotState();
}

enum MascotState { idle, happy, growing, sad, celebrating }

class _SeedlingMascotState extends State<SeedlingMascot>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final AnimationController _swayController;
  late final AnimationController _growthController;
  late final AnimationController _breathController;
  late final AnimationController _blinkController;
  late final AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _growthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    if (widget.state == MascotState.growing) {
      _growthController.forward();
    }

    _scheduleBlink();
  }

  void _scheduleBlink() async {
    while (mounted) {
      final waitSeconds = 3 + math.Random().nextInt(4);
      await Future.delayed(Duration(seconds: waitSeconds));
      if (mounted) {
        await _blinkController.forward();
        await _blinkController.reverse();
      }
    }
  }

  @override
  void didUpdateWidget(SeedlingMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == MascotState.growing &&
        oldWidget.state != MascotState.growing) {
      _growthController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _swayController.dispose();
    _growthController.dispose();
    _breathController.dispose();
    _blinkController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _bounceController,
          _swayController,
          _growthController,
          _breathController,
          _blinkController,
          _sparkleController,
        ]),
        builder: (context, child) {
          final breathScale = 0.985 + _breathController.value * 0.015;
          return Transform.scale(
            scale: breathScale,
            child: CustomPaint(
              size: Size(widget.size, widget.size * 1.3),
              painter: SeedlingMascotPainter(
                bounceValue: _bounceController.value,
                swayValue: _swayController.value,
                growthValue: _growthController.value,
                blinkValue: _blinkController.value,
                sparkleValue: _sparkleController.value,
                state: widget.state,
              ),
            ),
          );
        },
      ),
    );
  }
}

class SeedlingMascotPainter extends CustomPainter {
  final double bounceValue;
  final double swayValue;
  final double growthValue;
  final double blinkValue;
  final double sparkleValue;
  final MascotState state;

  SeedlingMascotPainter({
    required this.bounceValue,
    required this.swayValue,
    required this.growthValue,
    required this.blinkValue,
    required this.sparkleValue,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.82;

    final swayAngle = math.sin(swayValue * math.pi * 2) * 0.07;
    final bounceOffset = math.sin(bounceValue * math.pi) * 2.5;

    _drawSoilMound(canvas, centerX, groundY, size.width);
    _drawRootGlow(canvas, centerX, groundY);
    _drawStem(canvas, centerX, groundY, swayAngle, bounceOffset);
    _drawLeaves(canvas, centerX, groundY, swayAngle, bounceOffset);

    final stemHeight = 50 + (growthValue * 20);
    final stemEndX = centerX + math.sin(swayAngle) * stemHeight * 0.3;
    final stemEndY = groundY - stemHeight + bounceOffset;

    if (growthValue > 0) {
      _drawSproutLeaf(canvas, stemEndX, stemEndY, swayAngle);
    }

    _drawFace(canvas, centerX, stemEndY, swayAngle);

    if (state == MascotState.happy || state == MascotState.celebrating) {
      _drawSparkles(canvas, centerX, stemEndY);
    }
  }

  // ── Soil: 3-layer mound with rich depth ─────────────────────────────
  void _drawSoilMound(Canvas canvas, double cx, double gy, double w) {
    // Bottom dark ring
    final darkPaint = Paint()
      ..color = const Color(0xFF3E2010)
      ..style = PaintingStyle.fill;
    final darkPath = Path()
      ..moveTo(cx - 42, gy + 2)
      ..quadraticBezierTo(cx, gy - 8, cx + 42, gy + 2)
      ..lineTo(cx + 47, gy + 12)
      ..lineTo(cx - 47, gy + 12)
      ..close();
    canvas.drawPath(darkPath, darkPaint);

    // Mid soil mound
    final midPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - 40, gy - 16),
        Offset(cx + 40, gy + 8),
        [const Color(0xFF6B4226), const Color(0xFF8B5E3C)],
      )
      ..style = PaintingStyle.fill;
    final midPath = Path()
      ..moveTo(cx - 38, gy)
      ..quadraticBezierTo(cx, gy - 16, cx + 38, gy)
      ..lineTo(cx + 43, gy + 10)
      ..lineTo(cx - 43, gy + 10)
      ..close();
    canvas.drawPath(midPath, midPaint);

    // Surface highlight (lighter crumble rim)
    final rimPaint = Paint()
      ..color = const Color(0xFFA07850).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final rimPath = Path()
      ..moveTo(cx - 35, gy - 1)
      ..quadraticBezierTo(cx, gy - 15, cx + 35, gy - 1);
    canvas.drawPath(rimPath, rimPaint);
  }

  // ── Root glow beneath soil ───────────────────────────────────────────
  void _drawRootGlow(Canvas canvas, double cx, double gy) {
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, gy + 8),
        38,
        [
          SeedlingColors.seedlingGreen.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(Offset(cx, gy + 8), 38, glowPaint);
  }

  // ── Stem: gradient from deep root → bright tip ───────────────────────
  void _drawStem(Canvas canvas, double cx, double gy,
      double swayAngle, double bounceOffset) {
    final stemHeight = 50 + (growthValue * 20);
    final stemEndX = cx + math.sin(swayAngle) * stemHeight * 0.3;
    final stemEndY = gy - stemHeight + bounceOffset;

    final stemPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, gy),
        Offset(stemEndX, stemEndY),
        [const Color(0xFF2D6A4F), const Color(0xFF74C69D)],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(cx, gy)
      ..quadraticBezierTo(
        cx + math.sin(swayAngle) * 10,
        gy - stemHeight / 2,
        stemEndX,
        stemEndY,
      );
    canvas.drawPath(stemPath, stemPaint);
  }

  // ── Leaves: gradient fill + midrib vein ─────────────────────────────
  void _drawLeaves(Canvas canvas, double cx, double gy,
      double swayAngle, double bounceOffset) {
    // Back-left leaf (slightly darker, smaller — depth layer)
    _drawGradientLeaf(
      canvas,
      cx - 8 + math.sin(swayAngle) * 4,
      gy - 22 + bounceOffset,
      -0.55 + swayAngle,
      15.0,
      const Color(0xFF2D6A4F),
      const Color(0xFF52B788),
      drawVein: false,
    );

    // Front-left leaf
    _drawGradientLeaf(
      canvas,
      cx - 4 + math.sin(swayAngle) * 5,
      gy - 27 + bounceOffset,
      -0.38 + swayAngle,
      20.0,
      const Color(0xFF40916C),
      const Color(0xFF74C69D),
      drawVein: true,
    );

    // Front-right leaf
    _drawGradientLeaf(
      canvas,
      cx + 5 + math.sin(swayAngle) * 8,
      gy - 36 + bounceOffset,
      0.42 + swayAngle,
      18.0,
      const Color(0xFF40916C),
      const Color(0xFF95D5B2),
      drawVein: true,
    );
  }

  void _drawGradientLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double leafSize,
    Color baseColor,
    Color tipColor, {
    required bool drawVein,
  }) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    // Leaf fill with gradient
    final leafPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-leafSize * 0.55, -leafSize * 0.35, 0, -leafSize)
      ..quadraticBezierTo(leafSize * 0.55, -leafSize * 0.35, 0, 0);

    final gradPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, -leafSize),
        [baseColor, tipColor],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(leafPath, gradPaint);

    // Leaf outline (subtle)
    final outlinePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(leafPath, outlinePaint);

    // Midrib vein
    if (drawVein) {
      final veinPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      final veinPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(0, -leafSize * 0.5, 0, -leafSize);
      canvas.drawPath(veinPath, veinPaint);

      // Two small secondary veins
      final secVein = Paint()
        ..color = baseColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(0, -leafSize * 0.35),
        Offset(-leafSize * 0.3, -leafSize * 0.52),
        secVein,
      );
      canvas.drawLine(
        Offset(0, -leafSize * 0.6),
        Offset(leafSize * 0.28, -leafSize * 0.76),
        secVein,
      );
    }

    // Gloss highlight (tiny white sheen near tip)
    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final glossPath = Path()
      ..moveTo(-leafSize * 0.12, -leafSize * 0.7)
      ..quadraticBezierTo(-leafSize * 0.22, -leafSize * 0.82,
          -leafSize * 0.08, -leafSize * 0.88)
      ..quadraticBezierTo(
          -leafSize * 0.04, -leafSize * 0.8, -leafSize * 0.12, -leafSize * 0.7);
    canvas.drawPath(glossPath, glossPaint);

    canvas.restore();
  }

  // ── Sprout tip leaf (during growth) ─────────────────────────────────
  void _drawSproutLeaf(Canvas canvas, double x, double y, double swayAngle) {
    final sproutSize = 8.0 + (growthValue * 5.0);
    _drawGradientLeaf(
      canvas, x, y, swayAngle * 1.5, sproutSize,
      const Color(0xFF52B788), SeedlingColors.morningDew,
      drawVein: false,
    );
  }

  // ── Face: eyes + expressions ─────────────────────────────────────────
  void _drawFace(Canvas canvas, double cx, double stemEndY, double swayAngle) {
    final stemHeight = 50 + (growthValue * 20);
    final faceX = cx + math.sin(swayAngle) * stemHeight * 0.3;
    final faceY = stemEndY - 16;

    // Eye parameters per state
    final bool isHappy = state == MascotState.happy ||
        state == MascotState.celebrating;
    final bool isSad = state == MascotState.sad;

    final double eyeRadius = isHappy ? 5.5 : 4.5;
    final double eyeSquish = 1.0 - blinkValue; // 0 when blink peak
    const double eyeSpacing = 8.0;

    final eyePaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.fill;

    // Left eye
    canvas.save();
    canvas.translate(faceX - eyeSpacing, faceY);
    canvas.scale(1.0, eyeSquish);

    // Eyebrow tilt for sad state
    if (isSad) {
      canvas.rotate(0.35);
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: eyeRadius * 2, height: eyeRadius * 2 * eyeSquish.clamp(0.1, 1.0)),
      eyePaint,
    );
    // White highlight
    canvas.drawCircle(Offset(eyeRadius * 0.3, -eyeRadius * 0.3),
        eyeRadius * 0.35, Paint()..color = Colors.white.withValues(alpha: 0.8));
    canvas.restore();

    // Right eye
    canvas.save();
    canvas.translate(faceX + eyeSpacing, faceY);
    canvas.scale(1.0, eyeSquish);
    if (isSad) canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: eyeRadius * 2, height: eyeRadius * 2 * eyeSquish.clamp(0.1, 1.0)),
      eyePaint,
    );
    canvas.drawCircle(Offset(eyeRadius * 0.3, -eyeRadius * 0.3),
        eyeRadius * 0.35, Paint()..color = Colors.white.withValues(alpha: 0.8));
    canvas.restore();

    // Star eyes for celebrating
    if (state == MascotState.celebrating) {
      _drawStarEye(canvas, faceX - eyeSpacing, faceY, eyeRadius + 1.5);
      _drawStarEye(canvas, faceX + eyeSpacing, faceY, eyeRadius + 1.5);
    }

    // Mouth
    final smilePaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();
    if (isHappy) {
      // Big smile
      mouthPath
        ..moveTo(faceX - 6, faceY + 8)
        ..quadraticBezierTo(faceX, faceY + 15, faceX + 6, faceY + 8);

      // Rosy cheeks
      final blushPaint = Paint()
        ..color = const Color(0xFFEF9A9A).withValues(alpha: 0.35);
      canvas.drawCircle(Offset(faceX - 10, faceY + 8), 5, blushPaint);
      canvas.drawCircle(Offset(faceX + 10, faceY + 8), 5, blushPaint);
    } else if (isSad) {
      // Small frown
      mouthPath
        ..moveTo(faceX - 5, faceY + 11)
        ..quadraticBezierTo(faceX, faceY + 7, faceX + 5, faceY + 11);
    } else {
      // Neutral slight smile
      mouthPath
        ..moveTo(faceX - 5, faceY + 9)
        ..quadraticBezierTo(faceX, faceY + 13, faceX + 5, faceY + 9);
    }
    canvas.drawPath(mouthPath, smilePaint);
  }

  void _drawStarEye(Canvas canvas, double x, double y, double r) {
    canvas.save();
    canvas.translate(x, y);
    final paint = Paint()
      ..color = SeedlingColors.sunlight.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final path = Path();
    for (int i = 0; i < 8; i++) {
      final outerRadius = r;
      final innerRadius = r * 0.45;
      final outerAngle = (i / 8.0) * math.pi * 2 - math.pi / 2;
      final innerAngle = outerAngle + math.pi / 8;
      if (i == 0) {
        path.moveTo(math.cos(outerAngle) * outerRadius,
            math.sin(outerAngle) * outerRadius);
      } else {
        path.lineTo(math.cos(outerAngle) * outerRadius,
            math.sin(outerAngle) * outerRadius);
      }
      path.lineTo(math.cos(innerAngle) * innerRadius,
          math.sin(innerAngle) * innerRadius);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  // ── Sparkles: orbiting ✦ for happy/celebrating ────────────────────────
  void _drawSparkles(Canvas canvas, double cx, double stemEndY) {
    for (int i = 0; i < 5; i++) {
      final phase = (i / 5.0) * math.pi * 2;
      final angle = phase + sparkleValue * math.pi * 2;
      final dist = 20.0 + math.sin(sparkleValue * math.pi * 3 + i) * 5.0;
      final sx = cx + math.cos(angle) * dist;
      final sy = stemEndY - 18 + math.sin(angle) * dist * 0.55;
      final t = (sparkleValue + i / 5.0) % 1.0;

      // Hue-shifted sparkle color
      final hue = (120 + i * 30.0 + sparkleValue * 60) % 360;
      final color = HSVColor.fromAHSV(0.7 + t * 0.3, hue, 0.6, 0.95).toColor();

      _drawStar(canvas, sx, sy, 3.5 + t * 2.0, color);
    }
  }

  void _drawStar(Canvas canvas, double x, double y, double r, Color color) {
    canvas.save();
    canvas.translate(x, y);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final a1 = (i / 4.0) * math.pi * 2 - math.pi / 4 +
          sparkleValue * math.pi * 0.5;
      final a2 = a1 + math.pi / 4;
      if (i == 0) {
        path.moveTo(math.cos(a1) * r, math.sin(a1) * r);
      } else {
        path.lineTo(math.cos(a1) * r, math.sin(a1) * r);
      }
      path.lineTo(math.cos(a2) * r * 0.4, math.sin(a2) * r * 0.4);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SeedlingMascotPainter oldDelegate) => true;
}
