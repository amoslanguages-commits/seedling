import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';
import '../core/typography.dart';
import '../services/audio_service.dart';
import '../widgets/mascot.dart';
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
                        // The new Mascot App Logo
                        Transform.translate(
                          // Move mascot slightly up as it scales
                          offset: Offset(0, -30 * _sproutController.value),
                          child: Transform.scale(
                            scale: 1.0 + (_sproutController.value * 1.5), // Scale up significantly
                            child: Opacity(
                              // Fade in during the first 50% of sprout animation
                              opacity: (_sproutController.value * 2).clamp(0.0, 1.0),
                              child: const SizedBox(
                                width: 140, // Baseline width, will be scaled up
                                height: 182,
                                child: SeedlingMascot(
                                  state: MascotState.happy,
                                ),
                              ),
                            ),
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
                              color: SeedlingColors.seedlingGreen,
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

// ── End of Spore particles ───────────────────────────────────────────────────
