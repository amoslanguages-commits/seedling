import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/gamification.dart';

class AchievementUnlockOverlay extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onComplete;
  
  const AchievementUnlockOverlay({
    super.key,
    required this.achievement,
    required this.onComplete,
  });
  
  @override
  State<AchievementUnlockOverlay> createState() => 
      _AchievementUnlockOverlayState();
}

class _AchievementUnlockOverlayState extends State<AchievementUnlockOverlay> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    
    _controller.forward().then((_) {
      widget.onComplete();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final entryProgress = (_controller.value / 0.2).clamp(0.0, 1.0);
        final exitProgress = ((_controller.value - 0.8) / 0.2).clamp(0.0, 1.0);
        final opacity = entryProgress * (1.0 - exitProgress);
        
        final scale = 0.5 + (entryProgress * 0.5) - (exitProgress * 0.3);
        
        return IgnorePointer(
          child: Container(
            color: Colors.black.withValues(alpha: opacity * 0.5),
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    margin: const EdgeInsets.all(40),
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SeedlingColors.sunlight,
                          Colors.orange.shade300,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: SeedlingColors.sunlight.withValues(alpha: 0.5),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🏆',
                          style: TextStyle(fontSize: 60),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Achievement Unlocked!',
                          style: SeedlingTypography.heading2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Text(
                                widget.achievement.icon,
                                style: const TextStyle(fontSize: 50),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.achievement.title,
                                style: SeedlingTypography.heading3.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                widget.achievement.description,
                                style: SeedlingTypography.body.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AchievementBurstPainter extends CustomPainter {
  final double progress;

  AchievementBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) return;
    
    final cx = size.width / 2;
    final cy = size.height / 2;
    
    // 1. Expanding Ring
    final ringRadius = progress * size.width;
    final ringAlpha = (1.0 - progress).clamp(0.0, 1.0);
    
    canvas.drawCircle(
      Offset(cx, cy), 
      ringRadius, 
      Paint()
        ..color = SeedlingColors.seedlingGreen.withValues(alpha: ringAlpha * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0 * ringAlpha
    );

    canvas.drawCircle(
      Offset(cx, cy), 
      ringRadius * 0.8, 
      Paint()
        ..color = const Color(0xFFFFD166).withValues(alpha: ringAlpha * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0 * ringAlpha
    );

    // 2. Rotating Rays
    if (progress > 0.1) {
      const rayCount = 12;
      final rayAlpha = math.sin((progress - 0.1) / 0.9 * math.pi) * 0.2;
      final rayLength = size.width * 0.8;
      
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(progress * math.pi * 0.5); // slow rotation
      
      final rayPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero, rayLength,
          [
            Colors.white.withValues(alpha: rayAlpha),
            Colors.white.withValues(alpha: 0.0),
          ]
        )
        ..style = PaintingStyle.fill;

      for (int i = 0; i < rayCount; i++) {
        canvas.save();
        canvas.rotate((i / rayCount) * math.pi * 2);
        
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(20, rayLength)
          ..lineTo(-20, rayLength)
          ..close();
          
        canvas.drawPath(path, rayPaint);
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant AchievementBurstPainter old) => old.progress != progress;
}
