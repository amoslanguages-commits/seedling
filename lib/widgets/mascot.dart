import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';

// ignore_for_file: prefer_const_constructors

enum MascotState { idle, happy, growing, sad, celebrating }

// ─────────────────────────────────────────────────────────────────────────────
//  Widget — displays the mascot PNG with a gentle bob + blink animation overlay
// ─────────────────────────────────────────────────────────────────────────────
class SeedlingMascot extends StatefulWidget {
  final double size;
  final MascotState state;
  final MascotAccessories accessories;
  final VoidCallback? onTap;

  const SeedlingMascot({
    super.key,
    this.size = 200,
    this.state = MascotState.idle,
    this.accessories = const MascotAccessories(),
    this.onTap,
  });

  static void paintForExport(Canvas canvas, Size size, {MascotState state = MascotState.idle}) {
    final painter = PuppetMascotPainter(
      state: state,
      accessories: const MascotAccessories(),
      bob: 0,
      sway: 0,
      blink: 0,
      transition: 1.0,
      squish: 0,
    );
    painter.paint(canvas, size);
  }

  @override
  State<SeedlingMascot> createState() => _SeedlingMascotState();
}

class _SeedlingMascotState extends State<SeedlingMascot>
    with TickerProviderStateMixin {
  // Core rhythmic bobbing (root motion)
  late final AnimationController _bob;
  // Foliage swaying (secondary motion)
  late final AnimationController _sway;
  // Eye blinking (autonomous motion)
  late final AnimationController _blink;
  // State transition (morphing facial expressions & poses)
  late final AnimationController _stateTransition;
  // Tap squish reaction
  late final AnimationController _squish;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _sway = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(reverse: true);
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000));
    _stateTransition = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _squish = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    // Periodic randomized blinking
    _startBlinkTimer();
  }

  void _startBlinkTimer() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 1500 + math.Random().nextInt(3000)));
      if (mounted) await _blink.forward(from: 0).then((_) => _blink.reverse());
    }
  }

  @override
  void didUpdateWidget(SeedlingMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _stateTransition.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    _sway.dispose();
    _blink.dispose();
    _stateTransition.dispose();
    _squish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _squish.forward(from: 0).then((_) => _squish.reverse());
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _sway, _blink, _stateTransition, _squish]),
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size * 1.2),
            painter: PuppetMascotPainter(
              state: widget.state,
              accessories: widget.accessories,
              bob: _bob.value,
              sway: _sway.value,
              blink: _blink.value,
              transition: _stateTransition.value,
              squish: _squish.value,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Puppet Mascot Painter — Procedural, Hierarchical Animation System
// ─────────────────────────────────────────────────────────────────────────────
class PuppetMascotPainter extends CustomPainter {
  final MascotState state;
  final MascotAccessories accessories;
  final double bob;
  final double sway;
  final double blink;
  final double transition;
  final double squish;

  PuppetMascotPainter({
    required this.state,
    required this.accessories,
    required this.bob,
    required this.sway,
    required this.blink,
    required this.transition,
    required this.squish,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final baseSize = size.width * 0.45;

    // 1. Calculate dynamic offsets based on rhythmic controllers
    final bobY = math.sin(bob * math.pi) * (baseSize * 0.08);
    final swayAngle = math.sin(sway * math.pi) * 0.045;
    final stretchY = 1.0 - (squish * 0.15) + (state == MascotState.growing ? transition * 0.12 : 0);
    final squishX = 1.0 + (squish * 0.12);

    canvas.save();
    canvas.translate(center.dx, center.dy + bobY);
    canvas.scale(squishX, stretchY);

    // 2. Body Layer (The Pot/Jar)
    _drawBody(canvas, baseSize);

    // 3. Foliage Layer (Sprouts and Leaves — Swaying)
    canvas.save();
    canvas.rotate(swayAngle);
    _drawFoliage(canvas, baseSize);
    canvas.restore();

    // 4. Facial Features (Eyes, Mouth — Blinking & States)
    _drawFace(canvas, baseSize);

    // 5. Tool Layer (The Watering Can — Animated relative to body)
    _drawWateringCan(canvas, baseSize);

    // 6. Accessory Layer (Trophy, etc.)
    _drawAccessories(canvas, baseSize);

    canvas.restore();

    // 6. Global Overlays (Celebration Sparkles)
    if (state == MascotState.celebrating) {
      _drawCelebrationEffects(canvas, size);
    }
  }

  void _drawBody(Canvas canvas, double s) {
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-s, -s), Offset(s, s),
        [SeedlingColors.cardBackground, SeedlingColors.deepRoot],
      );

    final path = Path()
      ..moveTo(-s * 0.6, -s * 0.7)
      ..lineTo(s * 0.6, -s * 0.7)
      ..quadraticBezierTo(s * 0.7, s * 0.6, 0, s * 0.8)
      ..quadraticBezierTo(-s * 0.7, s * 0.6, -s * 0.6, -s * 0.7)
      ..close();

    // Draw main body shadow
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(path, bodyPaint);

    // Rim highlight
    final rimPaint = Paint()
      ..color = SeedlingColors.morningDew.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, rimPaint);

    // Glass shine
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(-s * 0.4, -s * 0.5, s * 0.2, s * 0.4), shinePaint);
  }

  void _drawFoliage(Canvas canvas, double s) {
    // Primary Sprout
    final sproutH = s * 0.6 + (state == MascotState.growing ? transition * 20 : 0);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0), Offset(0, -sproutH),
        [SeedlingColors.seedlingGreen, SeedlingColors.freshSprout],
      )
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stem = Path()
      ..moveTo(0, -s * 0.6)
      ..quadraticBezierTo(s * 0.1, -s * 0.9, 0, -s * 0.6 - sproutH);
    canvas.drawPath(stem, paint);

    // Leaves
    _drawLeaf(canvas, 0, -s * 0.6 - sproutH, -0.4, s * 0.35, SeedlingColors.freshSprout);
    _drawLeaf(canvas, 2, -s * 0.6 - sproutH * 0.6, 0.6, s * 0.28, SeedlingColors.morningDew);

    if (state == MascotState.sad) {
      // Wilted secondary leaf
      _drawLeaf(canvas, -4, -s * 0.6 - sproutH * 0.3, -1.2, s * 0.2, SeedlingColors.textSecondary);
    }
  }

  void _drawLeaf(Canvas canvas, double x, double y, double angle, double size, Color color) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    final leafPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-size * 0.6, -size * 0.4, 0, -size)
      ..quadraticBezierTo(size * 0.6, -size * 0.4, 0, 0);

    canvas.drawPath(
      leafPath,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, -size), [SeedlingColors.seedlingGreen, color]),
    );
    canvas.restore();
  }

  void _drawFace(Canvas canvas, double s) {
    final eyeY = -s * 0.2;
    final eyeSpacing = s * 0.3;
    final eyeSize = s * 0.12;

    final eyePaint = Paint()..color = SeedlingColors.textPrimary;
    final eyeScaleY = (1.0 - blink).clamp(0.1, 1.0);

    // Adjust facial expression based on state
    double mouthWidth = s * 0.2;
    double mouthCurve = 8.0;
    if (state == MascotState.happy || state == MascotState.celebrating) {
      mouthWidth = s * 0.35;
      mouthCurve = 15.0;
    } else if (state == MascotState.sad) {
      mouthWidth = s * 0.15;
      mouthCurve = -8.0;
    }

    // Eyes
    canvas.save();
    canvas.translate(0, eyeY);
    
    // Left
    canvas.drawOval(Rect.fromCenter(center: Offset(-eyeSpacing, 0), width: eyeSize, height: eyeSize * eyeScaleY), eyePaint);
    // Right
    canvas.drawOval(Rect.fromCenter(center: Offset(eyeSpacing, 0), width: eyeSize, height: eyeSize * eyeScaleY), eyePaint);
    
    // High-gloss eye sparkles
    if (blink < 0.2) {
      canvas.drawCircle(Offset(-eyeSpacing - 2, -2), 2, Paint()..color = Colors.white.withValues(alpha: 0.8));
      canvas.drawCircle(Offset(eyeSpacing - 2, -2), 2, Paint()..color = Colors.white.withValues(alpha: 0.8));
    }
    canvas.restore();

    // Mouth
    final mouthPaint = Paint()
      ..color = SeedlingColors.textSecondary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(-mouthWidth / 2, 0)
      ..quadraticBezierTo(0, mouthCurve, mouthWidth / 2, 0);
    
    canvas.save();
    canvas.translate(0, s * 0.1);
    canvas.drawPath(mouthPath, mouthPaint);
    canvas.restore();
  }

  void _drawWateringCan(Canvas canvas, double s) {
    // Positioning the can to the side
    final canX = s * 0.7;
    final canY = s * 0.1;
    final canSize = s * 0.4;

    canvas.save();
    canvas.translate(canX, canY);

    if (state == MascotState.growing) {
      // Tilt to water its foliage
      canvas.rotate(-math.pi / 4 * transition);
    }

    final canPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-canSize, -canSize), Offset(canSize, canSize),
        [SeedlingColors.water, SeedlingColors.water.withValues(alpha: 0.7)],
      );

    // Main body of can
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: canSize, height: canSize * 0.7), const Radius.circular(8)), canPaint);
    
    // Spout
    final spout = Path()
      ..moveTo(canSize * 0.5, 0)
      ..lineTo(canSize * 1.0, -canSize * 0.4)
      ..lineTo(canSize * 1.0, -canSize * 0.2)
      ..close();
    canvas.drawPath(spout, canPaint);

    // Handle
    final handle = Path()
      ..addOval(Rect.fromLTWH(-canSize * 0.8, -canSize * 0.5, canSize * 0.6, canSize * 0.6));
    canvas.drawPath(
      handle,
      Paint()..color = SeedlingColors.water.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 4,
    );

    canvas.restore();
  }

  void _drawAccessories(Canvas canvas, double s) {
    if (accessories.holdingTrophy) {
      final tX = -s * 0.7;
      final tY = s * 0.1;
      final tSize = s * 0.45;

      canvas.save();
      canvas.translate(tX, tY);

      // Trophy
      final trophyPaint = Paint()..color = SeedlingColors.sunlight;
      canvas.drawPath(
        Path()
          ..moveTo(-tSize * 0.4, -tSize * 0.4)
          ..lineTo(tSize * 0.4, -tSize * 0.4)
          ..lineTo(tSize * 0.3, tSize * 0.1)
          ..quadraticBezierTo(0, tSize * 0.3, -tSize * 0.3, tSize * 0.1)
          ..close(),
        trophyPaint,
      );

      // Stem/Base
      canvas.drawRect(Rect.fromCenter(center: Offset(0, tSize * 0.3), width: tSize * 0.1, height: tSize * 0.2), trophyPaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(0, tSize * 0.4), width: tSize * 0.4, height: tSize * 0.1), trophyPaint);

      canvas.restore();
    }
  }

  void _drawCelebrationEffects(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final t = (bob + sway) % 1.0; // Reuse rhythmic motion for sparkles

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8.0) * math.pi * 2 + t * 0.5;
      final dist = (size.width * 0.5) * (0.8 + math.sin(t * math.pi * 2 + i) * 0.2);
      final sx = cx + math.cos(angle) * dist;
      final sy = cy + math.sin(angle) * dist;
      
      final alpha = (math.sin(t * math.pi * 2 + i) * 0.5 + 0.5);
      final r = 6.0 * alpha;

      canvas.drawCircle(
        Offset(sx, sy), r,
        Paint()..color = SeedlingColors.sunlight.withValues(alpha: alpha * 0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PuppetMascotPainter old) =>
      old.state != state || 
      old.accessories != accessories ||
      old.bob != bob || 
      old.sway != sway || 
      old.blink != blink || 
      old.transition != transition || 
      old.squish != squish;
}

class MascotAccessories {
  final bool holdingTrophy;
  const MascotAccessories({this.holdingTrophy = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MascotAccessories &&
          runtimeType == other.runtimeType &&
          holdingTrophy == other.holdingTrophy;

  @override
  int get hashCode => holdingTrophy.hashCode;
}

