import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/typography.dart';

/// Fired when a word reaches mastery level 3 (EngraveRoot spelled correctly).
/// Overlays dual confetti cannons + a celebration message, then auto-dismisses.
class MasteryCelebration extends StatefulWidget {
  final String word;
  final VoidCallback? onDismissed;

  const MasteryCelebration({
    super.key,
    required this.word,
    this.onDismissed,
  });

  /// Show the celebration as an overlay on top of the current route.
  static void show(BuildContext context, String word) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => MasteryCelebration(
        word: word,
        onDismissed: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<MasteryCelebration> createState() => _MasteryCelebrationState();
}

class _MasteryCelebrationState extends State<MasteryCelebration>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _leftCannon;
  late final ConfettiController _rightCannon;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _leftCannon = ConfettiController(duration: const Duration(seconds: 3));
    _rightCannon = ConfettiController(duration: const Duration(seconds: 3));

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Fire all guns
    Future.microtask(() {
      _leftCannon.play();
      _rightCannon.play();
      _fadeController.forward();
    });

    // Auto-dismiss after the confetti settles
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (mounted) {
        _fadeController.reverse().then((_) {
          widget.onDismissed?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _leftCannon.dispose();
    _rightCannon.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Stack(
        children: [
          // Dim background
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _fadeController.reverse().then((_) {
                  widget.onDismissed?.call();
                });
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),

          // ── Left cannon (top-left corner) ─────────────────────
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _leftCannon,
              blastDirection: -0.7, // points right-down
              emissionFrequency: 0.06,
              numberOfParticles: 14,
              maxBlastForce: 30,
              minBlastForce: 14,
              gravity: 0.3,
              particleDrag: 0.05,
              colors: const [
                Color(0xFFFFD700), // gold
                Color(0xFF4CAF50), // seedling green
                Color(0xFF81C784), // light green
                Color(0xFFFFF176), // pale yellow
                Color(0xFFFF8A65), // warm orange
              ],
              createParticlePath: _drawLeaf,
            ),
          ),

          // ── Right cannon (top-right corner) ────────────────────
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _rightCannon,
              blastDirection: -2.4, // points left-down
              emissionFrequency: 0.06,
              numberOfParticles: 14,
              maxBlastForce: 30,
              minBlastForce: 14,
              gravity: 0.3,
              particleDrag: 0.05,
              colors: const [
                Color(0xFFFFD700),
                Color(0xFF4CAF50),
                Color(0xFF81C784),
                Color(0xFFFFF176),
                Color(0xFFFF8A65),
              ],
              createParticlePath: _drawLeaf,
            ),
          ),

          // ── Celebration card ───────────────────────────────────
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _fadeController,
                curve: Curves.elasticOut,
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌳', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text(
                      'Deep Root Mastered!',
                      style: SeedlingTypography.heading2.copyWith(
                        color: SeedlingColors.seedlingGreen,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${widget.word}" is now deeply rooted\nin your memory garden 🌿',
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '⭐ Mastery Level 3 Achieved',
                        style: SeedlingTypography.caption.copyWith(
                          color: const Color(0xFFB8860B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap anywhere to continue',
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Draws a simple leaf-shaped particle path for the confetti.
  Path _drawLeaf(Size size) {
    final path = Path();
    // Simple oval leaf shape
    path.addOval(Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height * 0.55,
    ));
    return path;
  }
}
