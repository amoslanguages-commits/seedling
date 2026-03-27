import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';
import '../core/typography.dart';
import '../services/audio_service.dart';
import 'onboarding.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _sproutController;
  late AnimationController _logoController;
  late AnimationController _sporeController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    _sproutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _sporeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    await _sproutController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    await _logoController.forward();
    _shimmerController.forward();
    AudioService.instance.play(SFX.splashReveal);
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OnboardingGate(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sproutController.dispose();
    _logoController.dispose();
    _sporeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _sproutController,
          _logoController,
          _sporeController,
          _shimmerController,
        ]),
        builder: (context, child) {
          return Stack(
            children: [
              // Spore particle layer (behind everything)
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: SporePainter(progress: _sporeController.value),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Seedling with root glow
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Root glow beneath plant
                        if (_sproutController.value > 0.4)
                          Positioned(
                            bottom: 0,
                            child: Opacity(
                              opacity:
                                  ((_sproutController.value - 0.4) / 0.6)
                                      .clamp(0.0, 0.5),
                              child: Container(
                                width: 80,
                                height: 20,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      SeedlingColors.seedlingGreen
                                          .withValues(alpha: 0.35),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        CustomPaint(
                          size: const Size(160, 186),
                          painter: SproutingSeedPainter(
                            progress: _sproutController.value,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // App name with shimmer
                    Opacity(
                      opacity: _logoController.value,
                      child: Transform.translate(
                        offset: Offset(0, 18.0 * (1 - _logoController.value)),
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return ui.Gradient.linear(
                              Offset(-bounds.width + _shimmerController.value * bounds.width * 3, 0),
                              Offset(bounds.width * 2 + _shimmerController.value * bounds.width * 3, 0),
                              [
                                SeedlingColors.deepRoot,
                                SeedlingColors.deepRoot,
                                Colors.white.withValues(alpha: 0.85),
                                SeedlingColors.deepRoot,
                                SeedlingColors.deepRoot,
                              ],
                              [0.0, 0.35, 0.5, 0.65, 1.0],
                            );
                          },
                          child: Text(
                            'Seedling',
                            style: SeedlingTypography.heading1.copyWith(
                              fontSize: 42,
                              color: SeedlingColors.deepRoot,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Opacity(
                      opacity: (_logoController.value * 0.8),
                      child: Text(
                        'Grow your vocabulary',
                        style: SeedlingTypography.body.copyWith(
                          color: SeedlingColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Spore particles (firefly-like dots rising slowly upward) ─────────────────
class SporePainter extends CustomPainter {
  final double progress;
  static final _rng = math.Random(42);
  static final List<_Spore> _spores = List.generate(40, (i) {
    return _Spore(
      baseX: _rng.nextDouble(),
      baseY: _rng.nextDouble(),
      speed: 0.04 + _rng.nextDouble() * 0.08,
      radius: 1.2 + _rng.nextDouble() * 2.2,
      phase: _rng.nextDouble(),
      drift: (_rng.nextDouble() - 0.5) * 0.04,
      alpha: 0.08 + _rng.nextDouble() * 0.2,
    );
  });

  SporePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final spore in _spores) {
      final t = (progress * spore.speed + spore.phase) % 1.0;
      final x = (spore.baseX + spore.drift * t) * size.width;
      final y = size.height * (1.0 - t);
      final alpha = math.sin(t * math.pi) * spore.alpha;

      final paint = Paint()
        ..color = SeedlingColors.freshSprout.withValues(alpha: alpha.clamp(0, 1))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), spore.radius, paint);
    }
  }

  @override
  bool shouldRepaint(SporePainter old) => old.progress != progress;
}

class _Spore {
  final double baseX, baseY, speed, radius, phase, drift, alpha;
  const _Spore({
    required this.baseX, required this.baseY, required this.speed,
    required this.radius, required this.phase, required this.drift,
    required this.alpha,
  });
}

// ── The main sprout animation painter ────────────────────────────────────────
class SproutingSeedPainter extends CustomPainter {
  final double progress;

  SproutingSeedPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final groundY = size.height * 0.75;

    _drawGroundLine(canvas, cx, groundY, size.width);

    if (progress < 0.4) {
      _drawSeed(canvas, cx, groundY, progress / 0.4);
    }

    if (progress > 0.3 && progress < 0.8) {
      _drawSeed(canvas, cx, groundY, 1.0);
      _drawSprout(canvas, cx, groundY, (progress - 0.3) / 0.5);
    }

    if (progress > 0.7) {
      _drawSeed(canvas, cx, groundY, 1.0);
      _drawSprout(canvas, cx, groundY, 1.0);
      _drawFullPlant(canvas, cx, groundY, (progress - 0.7) / 0.3);
    }
  }

  // Subtle ground horizon line
  void _drawGroundLine(Canvas canvas, double cx, double gy, double w) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, gy),
        Offset(w, gy),
        [
          Colors.transparent,
          const Color(0xFF6B4226).withValues(alpha: 0.55),
          const Color(0xFF6B4226).withValues(alpha: 0.55),
          Colors.transparent,
        ],
        [0.0, 0.2, 0.8, 1.0],
      )
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, gy), Offset(w, gy), paint);
  }

  void _drawSeed(Canvas canvas, double x, double y, double prog) {
    final scale = 0.4 + prog * 0.6;

    // Seed shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFF3E2010).withValues(alpha: 0.3 * prog)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x, y + 2), width: 18 * scale, height: 6 * scale),
      shadowPaint,
    );

    // Seed body gradient
    final seedPath = Path()
      ..moveTo(x, y - 10.0 * scale)
      ..quadraticBezierTo(x + 11 * scale, y - 4 * scale, x, y + 9 * scale)
      ..quadraticBezierTo(x - 11 * scale, y - 4 * scale, x, y - 10 * scale);

    final seedPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(x - 3 * scale, y - 3 * scale),
        12 * scale,
        [const Color(0xFFA07040), const Color(0xFF5D3A1A)],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(seedPath, seedPaint);

    // Gloss on seed
    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 * prog)
      ..style = PaintingStyle.fill;
    final glossPath = Path()
      ..moveTo(x - 3 * scale, y - 6 * scale)
      ..quadraticBezierTo(
          x, y - 9 * scale, x + 2 * scale, y - 5 * scale)
      ..quadraticBezierTo(x - 1 * scale, y - 4 * scale, x - 3 * scale, y - 6 * scale);
    canvas.drawPath(glossPath, glossPaint);

    // Crack effect
    if (prog > 0.7) {
      final crackAlpha = (prog - 0.7) / 0.3;
      final crackPaint = Paint()
        ..color = const Color(0xFF52B788).withValues(alpha: crackAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(x - 1, y - 5), Offset(x + 3, y + 1), crackPaint);
      canvas.drawLine(
          Offset(x + 1, y - 3), Offset(x - 2, y + 3), crackPaint);
    }
  }

  void _drawSprout(Canvas canvas, double x, double y, double prog) {
    final stemHeight = 50.0 * prog;
    final curve = math.sin(prog * math.pi) * 6.0;
    final tipX = x + curve * 0.3;
    final tipY = y - stemHeight;

    // Stem gradient
    final stemPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x, y),
        Offset(tipX, tipY),
        [const Color(0xFF2D6A4F), const Color(0xFF74C69D)],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(x + curve, y - stemHeight / 2.0, tipX, tipY);
    canvas.drawPath(stemPath, stemPaint);

    // Leaves emerging from stem
    if (prog > 0.5) {
      final leafProg = (prog - 0.5) / 0.5;
      _drawSplashLeaf(canvas, x - 2, y - stemHeight * 0.58,
          -0.42, 12.0 * leafProg,
          const Color(0xFF40916C), const Color(0xFF95D5B2));
      _drawSplashLeaf(canvas, x + 2, y - stemHeight * 0.78,
          0.42, 11.0 * leafProg,
          const Color(0xFF40916C), const Color(0xFF74C69D));
    }
  }

  void _drawSplashLeaf(Canvas canvas, double x, double y, double angle,
      double leafSize, Color base, Color tip) {
    if (leafSize < 1) return;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    final leafPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-leafSize * 0.55, -leafSize * 0.38, 0, -leafSize)
      ..quadraticBezierTo(leafSize * 0.55, -leafSize * 0.38, 0, 0);

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0), Offset(0, -leafSize), [base, tip])
      ..style = PaintingStyle.fill;
    canvas.drawPath(leafPath, paint);

    // Vein
    final veinPaint = Paint()
      ..color = base.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    final veinPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(0, -leafSize * 0.5, 0, -leafSize);
    canvas.drawPath(veinPath, veinPaint);

    canvas.restore();
  }

  void _drawFullPlant(Canvas canvas, double x, double y, double prog) {
    // Sparkle burst
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8.0) * math.pi * 2.0 + prog * math.pi;
      final dist = 22.0 + math.sin(prog * math.pi * 3.0 + i) * 7.0;
      final sx = x + math.cos(angle) * dist;
      final sy = y - 38 + math.sin(angle) * dist * 0.55;
      final t = ((prog * 3.0 + i / 4.0) % 1.0);
      final alpha = math.sin(t * math.pi) * 0.75 * prog;

      // Alternating sparkle colors
      final color = i.isEven
          ? SeedlingColors.sunlight.withValues(alpha: alpha)
          : SeedlingColors.freshSprout.withValues(alpha: alpha);

      _drawSparkStar(canvas, sx, sy, 3.2 * prog, color, prog);
    }
  }

  void _drawSparkStar(
      Canvas canvas, double x, double y, double r, Color color, double rot) {
    if (r < 0.5) return;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot * math.pi);
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final a1 = (i / 4.0) * math.pi * 2 - math.pi / 4;
      final a2 = a1 + math.pi / 4;
      if (i == 0) {
        path.moveTo(math.cos(a1) * r, math.sin(a1) * r);
      } else {
        path.lineTo(math.cos(a1) * r, math.sin(a1) * r);
      }
      path.lineTo(math.cos(a2) * r * 0.35, math.sin(a2) * r * 0.35);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SproutingSeedPainter old) =>
      old.progress != progress;
}
