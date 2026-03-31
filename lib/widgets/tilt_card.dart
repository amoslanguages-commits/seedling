import 'package:flutter/material.dart';
import '../core/colors.dart';

/// A wrapping widget that applies a real-time tilt effect to any draggable card.
/// 
/// As the user drags the card horizontally, it rotates around the Z-axis
/// proportional to the drag velocity/offset, and springs back to neutral on release.
class TiltCard extends StatefulWidget {
  final Widget child;

  /// Maximum tilt angle in radians (default ≈ 15°)
  final double maxTiltAngle;

  /// How strongly velocity influences the tilt (higher = more dramatic)
  final double velocityFactor;

  const TiltCard({
    super.key,
    required this.child,
    this.maxTiltAngle = 0.26,
    this.velocityFactor = 0.0003,
  });

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  late Animation<double> _springAnimation;

  double _currentTilt = 0.0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _springAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final velocity = details.delta.dx;
    final newTilt = (_currentTilt + velocity * widget.velocityFactor)
        .clamp(-widget.maxTiltAngle, widget.maxTiltAngle);
    setState(() => _currentTilt = newTilt);
  }

  void _onDragEnd(DragEndDetails details) {
    _springAnimation = Tween<double>(
      begin: _currentTilt,
      end: 0.0,
    ).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );
    _springController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _currentTilt = 0.0);
    });
    _springAnimation.addListener(() {
      if (mounted) setState(() => _currentTilt = _springAnimation.value);
    });
    // Subtle overshoot: flick in opposite direction slightly
    final flickDirection = details.velocity.pixelsPerSecond.dx > 0 ? 1 : -1;
    _currentTilt = flickDirection * widget.maxTiltAngle * 0.35;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _springController,
        builder: (context, child) {
          final tilt = _springController.isAnimating
              ? _springAnimation.value
              : _currentTilt;
          // Subtle Y-axis perspective for 3D feel
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateZ(tilt)
            ..rotateY(tilt * 0.3); // adds 3D depth
          return Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A simpler tilt card that responds to precise dx offset values for
/// externally-driven drag (e.g., when the parent already controls the drag).
class OffsetTiltCard extends StatelessWidget {
  final Widget child;
  final double dx; // raw horizontal drag offset in pixels

  /// Screen width fraction at which we hit max tilt
  final double maxOffsetFraction;
  final double maxTiltAngle;

  const OffsetTiltCard({
    super.key,
    required this.child,
    required this.dx,
    this.maxOffsetFraction = 0.4,
    this.maxTiltAngle = 0.22,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fraction = (dx / (screenWidth * maxOffsetFraction)).clamp(-1.0, 1.0);
    final tilt = fraction * maxTiltAngle;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateZ(tilt)
      ..rotateY(tilt * 0.25);
    return Transform(
      transform: matrix,
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Drop shadow that shifts subtly with tilt to reinforce lifting-off-surface illusion.
class TiltShadow extends StatelessWidget {
  final Widget child;
  final double tiltFraction; // -1.0 to 1.0

  const TiltShadow({
    super.key,
    required this.child,
    required this.tiltFraction,
  });

  @override
  Widget build(BuildContext context) {
    final shadowX = tiltFraction * 8.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: SeedlingColors.deepRoot.withValues(alpha: 0.25 + tiltFraction.abs() * 0.15),
            blurRadius: 16 + tiltFraction.abs() * 12,
            offset: Offset(shadowX, 8 + tiltFraction.abs() * 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
