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
  late AnimationController _ambientController;
  late AnimationController _fireflyController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    _sproutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _fireflyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    // 1. Initial silence, then Mascot springs up
    await Future.delayed(const Duration(milliseconds: 200));
    _sproutController.forward();
    
    // Play light haptic as mascot rises
    Future.delayed(const Duration(milliseconds: 300), () {
      AudioService.haptic(HapticType.tap);
    });
    // Play stronger haptic as bounce peaks
    Future.delayed(const Duration(milliseconds: 600), () {
      AudioService.haptic(HapticType.levelUp);
      AudioService.instance.play(SFX.splashReveal);
    });

    // 2. Logo letters ripple in
    await Future.delayed(const Duration(milliseconds: 900));
    _logoController.forward();
    _shimmerController.forward();
    HapticFeedback.mediumImpact();

    // 3. Subtitle fades in smoothly
    await Future.delayed(const Duration(milliseconds: 400));
    _subtitleController.forward();

    // 4. Hold to admire, then transition
    await Future.delayed(const Duration(milliseconds: 1800));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 1000),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sproutController.dispose();
    _logoController.dispose();
    _subtitleController.dispose();
    _ambientController.dispose();
    _fireflyController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _sproutController,
          _logoController,
          _subtitleController,
          _ambientController,
          _fireflyController,
          _shimmerController,
        ]),
        builder: (context, child) {
          // Mascot spring animation
          final sproutVal = CurvedAnimation(
            parent: _sproutController,
            curve: const ElasticOutCurve(0.85),
          ).value;
          
          final sproutOpacity = CurvedAnimation(
            parent: _sproutController,
            curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
          ).value;

          return Stack(
            children: [
              // 1. Deep Atmospheric Background
              _buildAtmosphere(size),

              // 2. Firefly Particles
              CustomPaint(
                size: size,
                painter: FireflyPainter(progress: _fireflyController.value),
              ),

              // 3. Main Centerpiece (Mascot & Typography)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Mascot Assembly ---
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Magical Backlight
                        if (sproutOpacity > 0.1)
                          Positioned(
                            bottom: 10,
                            child: Opacity(
                              opacity: sproutOpacity * 0.7,
                              child: Container(
                                width: 140 * sproutVal,
                                height: 140 * sproutVal,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: SeedlingColors.sunlight
                                          .withValues(alpha: 0.08),
                                      blurRadius: 60,
                                      spreadRadius: 10,
                                    ),
                                    BoxShadow(
                                      color: SeedlingColors.seedlingGreen
                                          .withValues(alpha: 0.15),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                        // The Mascot
                        Transform.translate(
                          // Slight drop-in feel combined with elastic scale
                          offset: Offset(0, 40 * (1 - sproutVal)),
                          child: Transform.scale(
                            scale: 0.4 + (sproutVal * 0.6),
                            child: Opacity(
                              opacity: sproutOpacity,
                              child: const SizedBox(
                                width: 220,
                                height: 260,
                                child: SeedlingMascot(
                                  state: MascotState.happy, 
                                  size: 260,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // --- Staggered Premium Logo ---
                    _buildStaggeredLogo('Seedling'),

                    const SizedBox(height: 12),

                    // --- Elegant Subtitle ---
                    Opacity(
                      opacity: CurvedAnimation(
                        parent: _subtitleController,
                        curve: Curves.easeOut,
                      ).value,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          15.0 * (1 - _subtitleController.value),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Text(
                            'Grow your vocabulary',
                            style: SeedlingTypography.bodyLarge.copyWith(
                              color: SeedlingColors.textSecondary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 2.5,
                              fontSize: 14,
                            ),
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

  /// Builds an immersive, pulsating background with blurred organic orbs
  Widget _buildAtmosphere(Size size) {
    
    return Stack(
      children: [
        // Base dark forest palette - matching the Deep Forest Canvas
        Container(
          decoration: const BoxDecoration(
            color: SeedlingColors.background,
          ),
        ),
        
        // Very subtle top-down depth gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                SeedlingColors.deepRoot.withValues(alpha: 0.3),
                Colors.transparent,
                SeedlingColors.background.withValues(alpha: 0.1),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),
        
        // Firefly particles float directly over the deep canvas
        
      ],
    );
  }


  /// Builds the "Seedling" text with staggered letter animation and a metallic/glassy shimmer
  Widget _buildStaggeredLogo(String text) {
    if (_logoController.value == 0) return const SizedBox(height: 60);

    final letters = text.split('');
    final children = <Widget>[];

    for (int i = 0; i < letters.length; i++) {
      // Calculate stagger range for this specific letter
      final start = (i * 0.08).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      
      final letterVal = CurvedAnimation(
        parent: _logoController,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      ).value;
      
      final opacityVal = CurvedAnimation(
        parent: _logoController,
        curve: Interval(start, start + 0.2, curve: Curves.easeIn),
      ).value;

      children.add(
        Opacity(
          opacity: opacityVal,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - letterVal)),
            child: Text(
              letters[i],
              style: SeedlingTypography.heading1.copyWith(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: Colors.white, // Let the shader drive the actual color
                letterSpacing: -1.5,
              ),
            ),
          ),
        ),
      );
    }

    return ShaderMask(
      shaderCallback: (bounds) {
        return ui.Gradient.linear(
          // Shimmer sweeps across the text
          Offset(-bounds.width + _shimmerController.value * bounds.width * 3, 0),
          Offset(bounds.width + _shimmerController.value * bounds.width * 3, bounds.height),
          [
            SeedlingColors.seedlingGreen,
            SeedlingColors.freshSprout,
            Colors.white,
            SeedlingColors.freshSprout,
            SeedlingColors.seedlingGreen,
          ],
          [0.0, 0.3, 0.5, 0.7, 1.0],
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// ── Firefly particles (premium enchanted forest motes) ───────────────────────
class FireflyPainter extends CustomPainter {
  final double progress;
  static final _rng = math.Random(101);
  // Generate particles with unique properties
  static final List<_Firefly> _fireflies = List.generate(45, (i) {
    return _Firefly(
      baseX: _rng.nextDouble(),
      baseY: _rng.nextDouble(),
      speedX: (_rng.nextDouble() - 0.5) * 0.05,
      speedY: 0.03 + _rng.nextDouble() * 0.07, // Move up
      radius: 0.8 + _rng.nextDouble() * 2.0,
      phase: _rng.nextDouble() * math.pi * 2,
      wobbleFrequency: 2 + _rng.nextDouble() * 5,
      wobbleAmplitude: 0.02 + _rng.nextDouble() * 0.04,
      peakAlpha: 0.3 + _rng.nextDouble() * 0.6,
      colorPick: _rng.nextDouble(),
    );
  });

  FireflyPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final fly in _fireflies) {
      // Time-based vertical ascent
      final t = (progress * fly.speedY + (fly.baseY)) % 1.0;
      final y = size.height * (1.0 - t);
      
      // Horizontal drift with wobble
      final xTime = progress + fly.phase;
      final wobble = math.sin(xTime * fly.wobbleFrequency) * fly.wobbleAmplitude;
      final x = ((fly.baseX + (progress * fly.speedX) + wobble) % 1.0) * size.width;

      // Pulse brightness
      final pulse = (math.sin(progress * 15 + fly.phase) + 1) / 2; // 0 to 1
      final fadeEdges = math.sin(t * math.pi); // Fade in at bottom, out at top
      final alpha = (fly.peakAlpha * pulse * fadeEdges).clamp(0.0, 1.0);

      // Mix yellow and green for enchanted look
      final color = Color.lerp(
        SeedlingColors.freshSprout,
        SeedlingColors.sunlight,
        fly.colorPick,
      )!.withValues(alpha: alpha);

      // Core glow
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
        
      // Inner bright spot
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), fly.radius + 1.5, paint);
      canvas.drawCircle(Offset(x, y), fly.radius * 0.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(FireflyPainter old) => old.progress != progress;
}

class _Firefly {
  final double baseX, baseY, speedX, speedY, radius;
  final double phase, wobbleFrequency, wobbleAmplitude;
  final double peakAlpha, colorPick;

  const _Firefly({
    required this.baseX,
    required this.baseY,
    required this.speedX,
    required this.speedY,
    required this.radius,
    required this.phase,
    required this.wobbleFrequency,
    required this.wobbleAmplitude,
    required this.peakAlpha,
    required this.colorPick,
  });
}

