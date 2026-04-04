import 'package:flutter/material.dart';
import 'dart:math';
import '../core/colors.dart';

/// A premium, immersive background environment for Seedling.
/// Features a 3-orb mesh gradient, floating botanical particles,
/// and optional timer-reactive intensity.
class PremiumEnvironment extends StatefulWidget {
  final Widget? child;
  final double timerProgress; // 0.0 (calm) to 1.0 (high intensity)
  final bool showParticles;

  const PremiumEnvironment({
    super.key,
    this.child,
    this.timerProgress = 0.0,
    this.showParticles = true,
  });

  @override
  State<PremiumEnvironment> createState() => _PremiumEnvironmentState();
}

class _PremiumEnvironmentState extends State<PremiumEnvironment>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _particleController;
  final List<_EnvironmentParticle> _particles = List.generate(
    15,
    (i) => _EnvironmentParticle(),
  );

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Faster rotation/pulse as timer nears end
    final speedMultiplier = 1.0 + (widget.timerProgress * 3.0);

    return Stack(
      children: [
        // 1. Deep Canvas
        Container(color: SeedlingColors.background),

        // 2. Mesh Orbs
        AnimatedBuilder(
          animation: _orbController,
          builder: (context, child) {
            final t = _orbController.value * speedMultiplier;

            // Pulse colors based on timer
            final orb1Color = Color.lerp(
              SeedlingColors.seedlingGreen.withValues(alpha: 0.12),
              SeedlingColors.hibiscusRed.withValues(alpha: 0.2),
              widget.timerProgress,
            )!;

            final orb2Color = Color.lerp(
              SeedlingColors.autumnGold.withValues(alpha: 0.08),
              SeedlingColors.warning.withValues(alpha: 0.15),
              widget.timerProgress,
            )!;

            final orb3Color = Color.lerp(
              SeedlingColors.water.withValues(alpha: 0.1),
              SeedlingColors.hibiscusRed.withValues(alpha: 0.15),
              widget.timerProgress,
            )!;

            return Stack(
              children: [
                // Orb 1: Mossy Deep
                Positioned(
                  top: -100 + (sin(t * pi * 2) * 80),
                  left: -150 + (cos(t * pi * 1.5) * 60),
                  child: _Orb(size: 600, color: orb1Color),
                ),
                // Orb 2: Autumn Glow
                Positioned(
                  bottom: -150 + (cos(t * pi * 2.5) * 100),
                  right: -100 + (sin(t * pi * 1.8) * 70),
                  child: _Orb(size: 550, color: orb2Color),
                ),
                // Orb 3: Water Vitality
                Positioned(
                  top: 100 + (sin(t * pi * 1.2) * 120),
                  right: -200 + (cos(t * pi * 2.2) * 90),
                  child: _Orb(size: 500, color: orb3Color),
                ),
              ],
            );
          },
        ),

        // 3. Floating Particles
        if (widget.showParticles)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _EnvironmentParticlePainter(
                    _particles,
                    _particleController.value,
                  ),
                );
              },
            ),
          ),

        // 4. Content
        if (widget.child != null) Positioned.fill(child: widget.child!),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.3, 1.0],
        ),
      ),
    );
  }
}

class _EnvironmentParticle {
  late double x, y, size, speed, angle, drift;
  late Color color;
  late bool isLeaf;

  _EnvironmentParticle() {
    _reset();
  }

  void _reset() {
    x = Random().nextDouble();
    y = 1.1; // Start below
    size = Random().nextDouble() * 12 + 4;
    speed = Random().nextDouble() * 0.02 + 0.01;
    drift = (Random().nextDouble() - 0.5) * 0.05;
    angle = Random().nextDouble() * pi * 2;
    isLeaf = Random().nextBool();
    color = [
      SeedlingColors.seedlingGreen,
      SeedlingColors.freshSprout,
      SeedlingColors.morningDew,
      SeedlingColors.autumnGold,
    ][Random().nextInt(4)].withValues(alpha: 0.3);
  }

  void update() {
    y -= speed * 0.1;
    x += drift * 0.1;
    angle += 0.005;
    if (y < -0.1 || x < -0.1 || x > 1.1) _reset();
  }
}

class _EnvironmentParticlePainter extends CustomPainter {
  final List<_EnvironmentParticle> particles;
  final double progress;

  _EnvironmentParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      p.update();
      paint.color = p.color;

      final cx = p.x * size.width;
      final cy = p.y * size.height;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(p.angle);

      if (p.isLeaf) {
        // Draw a simple leaf shape
        final path = Path();
        path.moveTo(0, -p.size);
        path.quadraticBezierTo(p.size, 0, 0, p.size);
        path.quadraticBezierTo(-p.size, 0, 0, -p.size);
        canvas.drawPath(path, paint);
      } else {
        // Draw a spore circle
        canvas.drawCircle(Offset.zero, p.size / 3, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
