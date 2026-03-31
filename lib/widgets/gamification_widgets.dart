import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/gamification.dart';

class StreakFlame extends StatefulWidget {
  final int streak;
  final double size;

  const StreakFlame({
    super.key,
    required this.streak,
    this.size = 60,
  });

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame> with SingleTickerProviderStateMixin {
  late final AnimationController _flameController;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flameController,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.streak > 0 
                ? SeedlingColors.sunlight.withValues(alpha: 0.1) 
                : SeedlingColors.morningDew.withValues(alpha: 0.05),
            boxShadow: widget.streak > 0 ? [
              BoxShadow(
                color: SeedlingColors.sunlight.withValues(alpha: 0.2),
                blurRadius: 12 + _flameController.value * 4,
                spreadRadius: 2,
              )
            ] : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size * 0.6, widget.size * 0.6),
                painter: FlamePainter(
                  active: widget.streak > 0,
                  streakScale: (widget.streak / 10).clamp(0.8, 1.3),
                  flicker: _flameController.value,
                ),
              ),
              if (widget.size > 50)
                Positioned(
                  bottom: widget.size * 0.1,
                  child: Text(
                    '${widget.streak}',
                    style: SeedlingTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.streak > 0 ? SeedlingColors.sunlight : SeedlingColors.textSecondary,
                      fontSize: widget.size * 0.25,
                      shadows: [
                        Shadow(
                          color: SeedlingColors.deepRoot.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class FlamePainter extends CustomPainter {
  final bool active;
  final double streakScale;
  final double flicker;

  FlamePainter({required this.active, required this.streakScale, required this.flicker});

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) {
      _drawDullFlame(canvas, size);
      return;
    }

    final cx = size.width / 2;
    final cy = size.height / 2;
    final h = size.height * streakScale;
    
    canvas.save();
    canvas.translate(cx, cy + size.height * 0.2); // ground zero
    
    final sway = math.sin(flicker * math.pi) * 3.0;

    // Outer Orange Flame
    final outerPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width * 0.45, -h * 0.4)
      ..quadraticBezierTo(size.width * 0.4, -h * 0.7, sway, -h)
      ..quadraticBezierTo(-size.width * 0.3, -h * 0.6, -size.width * 0.4, -h * 0.3)
      ..quadraticBezierTo(-size.width * 0.5, 0, 0, 0);

    canvas.drawPath(
      outerPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0), Offset(0, -h),
          const [SeedlingColors.sunlight, SeedlingColors.error],
        )
    );

    // Inner Yellow Flame
    final ih = h * 0.6;
    final innerPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width * 0.25, 0, size.width * 0.2, -ih * 0.4)
      ..quadraticBezierTo(size.width * 0.15, -ih * 0.7, -sway, -ih)
      ..quadraticBezierTo(-size.width * 0.15, -ih * 0.6, -size.width * 0.2, -ih * 0.3)
      ..quadraticBezierTo(-size.width * 0.25, 0, 0, 0);

    final flamePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, -ih), // Use -ih for height as it's drawn upwards
        [
          SeedlingColors.sunlight.withValues(alpha: 0.8),
          SeedlingColors.sunlight,
        ]
      );

    canvas.drawPath(innerPath, flamePaint); // Use innerPath here

    // Optional: Inner white hot core for high streaks
    // Assuming 'intensity' can be derived from 'flicker' or 'streakScale' for this example
    // For a direct fix, we'll use a placeholder or a simple condition.
    // Let's use flicker as a proxy for intensity for this example.
    final intensity = flicker; 
    if (intensity > 0.5) {
      final corePath = Path()
        ..moveTo(size.width * 0.5 - cx, size.height * 0.9 - (cy + size.height * 0.2)) // Adjust for canvas translation
        ..quadraticBezierTo(
          size.width * 0.35 - cx + sway * 0.5, size.height * 0.6 - (cy + size.height * 0.2),
          size.width * 0.5 - cx + sway * 0.2, size.height * 0.3 - (cy + size.height * 0.2)
        )
        ..quadraticBezierTo(
          size.width * 0.65 - cx + sway * 0.5, size.height * 0.6 - (cy + size.height * 0.2),
          size.width * 0.5 - cx, size.height * 0.9 - (cy + size.height * 0.2)
        );
        
      canvas.drawPath(corePath, Paint()
        ..color = SeedlingColors.textPrimary.withValues(alpha: 0.5)
      );
    }
    canvas.restore();
  }

  void _drawDullFlame(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.8, size.width * 0.7, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.2, size.width * 0.5, size.height * 0.1)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.3, size.width * 0.3, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.8, size.width * 0.5, size.height * 0.8);
      
    canvas.drawPath(
      path, 
      Paint()..color = Colors.grey.withValues(alpha: 0.4)
    );
  }

  @override
  bool shouldRepaint(covariant FlamePainter old) => 
      old.active != active || old.flicker != flicker || old.streakScale != streakScale;
}

class AchievementBadge extends StatefulWidget {
  final Achievement achievement;
  final double size;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.size = 80,
  });

  @override
  State<AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<AchievementBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 4)
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, _) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.achievement.isUnlocked 
                    ? RadialGradient(
                        colors: [
                          SeedlingColors.freshSprout.withValues(alpha: 0.3),
                          SeedlingColors.deepRoot.withValues(alpha: 0.1),
                        ],
                      )
                    : RadialGradient(
                        colors: [
                          SeedlingColors.morningDew.withValues(alpha: 0.05),
                          SeedlingColors.background.withValues(alpha: 0.5),
                        ],
                      ),
                border: !widget.achievement.isUnlocked ? Border.all(
                  color: SeedlingColors.morningDew.withValues(alpha: 0.1),
                  width: 2,
                ) : null,
                boxShadow: widget.achievement.isUnlocked ? [
                  BoxShadow(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ] : null,
              ),
              child: CustomPaint(
                painter: widget.achievement.isUnlocked 
                    ? BadgeRimPainter(progress: _shimmerController.value)
                    : null,
                child: Center(
                  child: ColorFiltered(
                    colorFilter: widget.achievement.isUnlocked
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                        : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                    child: Opacity(
                      opacity: widget.achievement.isUnlocked ? 1.0 : 0.4,
                      child: Text(
                        widget.achievement.icon,
                        style: TextStyle(fontSize: widget.size * 0.45),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        ),
        const SizedBox(height: 8),
        Text(
          widget.achievement.title,
          textAlign: TextAlign.center,
          style: SeedlingTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: widget.achievement.isUnlocked 
                ? SeedlingColors.textPrimary 
                : SeedlingColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class BadgeRimPainter extends CustomPainter {
  final double progress;
  BadgeRimPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 2;

    final paint = Paint()
      ..shader = ui.Gradient.sweep(
        Offset(cx, cy),
        [
          SeedlingColors.seedlingGreen,
          SeedlingColors.freshSprout.withValues(alpha: 0.8),
          SeedlingColors.seedlingGreen,
        ],
        [0.0, 0.5, 1.0],
        TileMode.clamp,
        progress * math.pi * 2,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(covariant BadgeRimPainter old) => old.progress != progress;
}
