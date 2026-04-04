import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';

// ── Stem Progress Bar ──────────────────────────────────────────────────────────
class StemProgressBar extends StatefulWidget {
  final double progress;
  final double height;
  final bool showLeaves;

  const StemProgressBar({
    super.key,
    required this.progress,
    this.height = 12,
    this.showLeaves = true,
  });

  @override
  State<StemProgressBar> createState() => _StemProgressBarState();
}

class _StemProgressBarState extends State<StemProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return CustomPaint(
          size: Size(
            double.infinity,
            widget.height + (widget.showLeaves ? 28 : 0),
          ),
          painter: StemProgressPainter(
            progress: widget.progress,
            showLeaves: widget.showLeaves,
            pulseValue: _pulseController.value,
          ),
        );
      },
    );
  }
}

class StemProgressPainter extends CustomPainter {
  final double progress;
  final bool showLeaves;
  final double pulseValue;

  StemProgressPainter({
    required this.progress,
    required this.showLeaves,
    this.pulseValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2.0 + (showLeaves ? 12.0 : 0.0);
    // 🪴 Relative horizontal padding for the stem based on available width
    final safePadding = math.min(22.0, size.width * 0.1);
    final startX = safePadding;
    final maxWidth = math.max(10.0, size.width - (safePadding * 2.0));
    final progressWidth = maxWidth * progress.clamp(0.0, 1.0);
    final progressEndX = startX + progressWidth;

    // ── Track (soil) ──────────────────────────────────────────────────
    // Two-tone track: outer glow + inner fill
    final trackGlowPaint = Paint()
      ..color = SeedlingColors.morningDew.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height + 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(startX, centerY),
      Offset(startX + maxWidth, centerY),
      trackGlowPaint,
    );

    final trackPaint = Paint()
      ..color = SeedlingColors.morningDew.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(startX, centerY),
      Offset(startX + maxWidth, centerY),
      trackPaint,
    );

    // ── Progress stem (gradient) ───────────────────────────────────────
    if (progressWidth > 0) {
      final stemPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(startX, centerY),
          Offset(progressEndX, centerY),
          [const Color(0xFF2D6A4F), const Color(0xFF74C69D)],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(progressEndX, centerY),
        stemPaint,
      );

      // Tip leaf
      if (showLeaves) {
        _drawTipLeaf(canvas, progressEndX, centerY, pulseValue);
      }
    }

    // ── Milestone markers ─────────────────────────────────────────────
    for (int i = 1; i <= 4; i++) {
      final markerX = startX + (maxWidth * i / 5.0);
      final isReached = progress >= (i / 5.0);
      _drawMilestoneMarker(canvas, markerX, centerY, isReached, size.height);
    }
  }

  // Tip leaf — grows and sways with pulse
  void _drawTipLeaf(Canvas canvas, double x, double y, double pulse) {
    canvas.save();
    canvas.translate(x, y);
    final sway = math.sin(pulse * math.pi) * 0.08;
    canvas.rotate(-math.pi / 2 + sway); // point upward

    const tipSize = 13.0;
    const backSize = 9.0;

    // Left mini-leaf
    _drawLeafShape(
      canvas,
      -3,
      0,
      -0.4,
      backSize,
      const Color(0xFF2D6A4F),
      const Color(0xFF74C69D),
    );
    // Main tip leaf
    _drawLeafShape(
      canvas,
      0,
      0,
      0.0,
      tipSize,
      const Color(0xFF40916C),
      const Color(0xFF95D5B2),
    );

    // Pulsing glow at very tip
    final glowAlpha = 0.12 + pulse * 0.18;
    final radius = 5 + pulse * 2;
    canvas.drawCircle(
      const Offset(0, -tipSize),
      radius + 4.0,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(0, -tipSize),
          radius + 4.0,
          [
            SeedlingColors.morningDew.withValues(alpha: glowAlpha),
            SeedlingColors.morningDew.withValues(alpha: 0.0),
          ],
          [0.4, 1.0],
        ),
    );

    canvas.restore();
  }

  void _drawLeafShape(
    Canvas canvas,
    double ox,
    double oy,
    double angle,
    double leafSize,
    Color base,
    Color tip,
  ) {
    canvas.save();
    canvas.translate(ox, oy);
    canvas.rotate(angle);

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-leafSize * 0.5, -leafSize * 0.35, 0, -leafSize)
      ..quadraticBezierTo(leafSize * 0.5, -leafSize * 0.35, 0, 0);

    final paint = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, -leafSize), [
        base,
        tip,
      ])
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Midrib vein
    canvas.drawLine(
      const Offset(0, 0),
      Offset(0, -leafSize),
      Paint()
        ..color = base.withValues(alpha: 0.4)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    canvas.restore();
  }

  // Milestone: small flower bud when reached, dot when not
  void _drawMilestoneMarker(
    Canvas canvas,
    double x,
    double y,
    bool reached,
    double barHeight,
  ) {
    if (reached) {
      // Full blossom marker
      final petalPaint = Paint()
        ..color = SeedlingColors.freshSprout.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;

      for (int p = 0; p < 5; p++) {
        final angle = (p / 5.0) * math.pi * 2 - math.pi / 2;
        canvas.drawCircle(
          Offset(x + math.cos(angle) * 5, y - 14 + math.sin(angle) * 3.5),
          3.2,
          petalPaint,
        );
      }
      // Center dot
      canvas.drawCircle(
        Offset(x, y - 14),
        2.8,
        Paint()
          ..color = SeedlingColors.sunlight.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill,
      );
      // Tiny stem up from bar
      canvas.drawLine(
        Offset(x, y - barHeight / 2 - 1),
        Offset(x, y - 10),
        Paint()
          ..color = SeedlingColors.seedlingGreen.withValues(alpha: 0.7)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    } else {
      // Unmet milestone: small bud outline
      canvas.drawCircle(
        Offset(x, y),
        barHeight / 2 + 2,
        Paint()
          ..color = SeedlingColors.morningDew.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, y),
        barHeight / 2 + 2,
        Paint()
          ..color = SeedlingColors.morningDew.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StemProgressPainter old) =>
      old.progress != progress || old.pulseValue != pulseValue;
}
