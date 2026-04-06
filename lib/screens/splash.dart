import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late AnimationController _subtitleController;
  late AnimationController _sporeController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _sproutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _sporeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _startAnimation();
  }

  void _startAnimation() async {
    // 1. Mascot reveals with a bounce
    await _sproutController.forward();
    HapticFeedback.lightImpact();

    // 2. Wait a beat, then reveal logo
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    _shimmerController.forward();
    AudioService.instance.play(SFX.splashReveal);
    HapticFeedback.mediumImpact();

    // 3. Reveal subtitle slightly after logo
    await Future.delayed(const Duration(milliseconds: 150));
    _subtitleController.forward();

    // 4. Hold for a moment then transition
    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sproutController.dispose();
    _logoController.dispose();
    _subtitleController.dispose();
    _sporeController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
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
          _subtitleController,
          _sporeController,
          _shimmerController,
          _pulseController,
        ]),
        builder: (context, child) {
          final sproutVal = CurvedAnimation(
            parent: _sproutController,
            curve: Curves.easeOutBack,
          ).value;

          return Stack(
            children: [
              // Pulse Background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8 + (_pulseController.value * 0.4),
                      colors: [
                        SeedlingColors.water.withValues(
                          alpha: 0.05 * _pulseController.value,
                        ),
                        SeedlingColors.background,
                      ],
                    ),
                  ),
                ),
              ),

              // Spore particle layer (behind everything)
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: SporePainter(progress: _sporeController.value),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mascot Container
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Root glow beneath plant
                        if (sproutVal > 0.4)
                          Positioned(
                            bottom: 20,
                            child: Opacity(
                              opacity: ((sproutVal - 0.4) / 0.6).clamp(
                                0.0,
                                0.6,
                              ),
                              child: Container(
                                width: 120,
                                height: 30,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: SeedlingColors.seedlingGreen
                                          .withValues(alpha: 0.4),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                          ),
                        // Mascot with elastic reveal
                        Transform.scale(
                          scale: 0.5 + (sproutVal * 1.0),
                          child: Opacity(
                            opacity: _sproutController.value.clamp(0.0, 1.0),
                            child: const SizedBox(
                              width: 160,
                              height: 200,
                              child: SeedlingMascot(state: MascotState.happy),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // App name with shimmer
                    Opacity(
                      opacity: _logoController.value,
                      child: Transform.translate(
                        offset: Offset(0, 20.0 * (1 - _logoController.value)),
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return ui.Gradient.linear(
                              Offset(
                                -bounds.width +
                                    _shimmerController.value * bounds.width * 3,
                                0,
                              ),
                              Offset(
                                bounds.width * 2 +
                                    _shimmerController.value * bounds.width * 3,
                                0,
                              ),
                              [
                                SeedlingColors.deepRoot,
                                SeedlingColors.deepRoot,
                                Colors.white.withValues(alpha: 0.9),
                                SeedlingColors.deepRoot,
                                SeedlingColors.deepRoot,
                              ],
                              [0.0, 0.4, 0.5, 0.6, 1.0],
                            );
                          },
                          child: Text(
                            'Seedling',
                            style: SeedlingTypography.heading1.copyWith(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: SeedlingColors.seedlingGreen,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Opacity(
                      opacity: _subtitleController.value,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          10.0 * (1 - _subtitleController.value),
                        ),
                        child: Text(
                          'Grow your vocabulary',
                          style: SeedlingTypography.bodyLarge.copyWith(
                            color: SeedlingColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          ),
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
        ..color = SeedlingColors.freshSprout.withValues(
          alpha: alpha.clamp(0, 1),
        )
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
    required this.baseX,
    required this.baseY,
    required this.speed,
    required this.radius,
    required this.phase,
    required this.drift,
    required this.alpha,
  });
}

// ── End of Spore particles ───────────────────────────────────────────────────
