import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/colors.dart';

/// A completely custom botanical pull-to-refresh indicator.
///
/// Shows a seedling being pulled out of the ground. When released,
/// it blooms into a flower then shrinks away gracefully.
///
/// Usage: wrap your `CustomScrollView` with `BotanicalRefreshWrapper`.
class BotanicalRefreshWrapper extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const BotanicalRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<BotanicalRefreshWrapper> createState() =>
      _BotanicalRefreshWrapperState();
}

class _BotanicalRefreshWrapperState extends State<BotanicalRefreshWrapper>
    with TickerProviderStateMixin {
  static const double _triggerDistance = 80.0;
  static const double _maxDragDistance = 130.0;

  double _dragOffset = 0.0;
  bool _isRefreshing = false;

  late final AnimationController _bloomController;
  late final AnimationController _dismissController;

  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _bloomController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(OverscrollNotification notification) {
    if (_isRefreshing) return;
    if (notification.overscroll < 0) {
      setState(() {
        _dragOffset = (_dragOffset - notification.overscroll).clamp(
          0.0,
          _maxDragDistance,
        );
        _triggered = _dragOffset >= _triggerDistance;
      });
    }
  }

  Future<void> _handleDragEnd() async {
    if (_dragOffset < _triggerDistance || _isRefreshing) {
      setState(() => _dragOffset = 0.0);
      return;
    }

    setState(() {
      _isRefreshing = true;
      _dragOffset = _triggerDistance;
    });

    await _bloomController.forward();
    await widget.onRefresh();
    await _dismissController.forward();

    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _dragOffset = 0.0;
        _triggered = false;
      });
      _bloomController.reset();
      _dismissController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification) {
          _handleDragUpdate(notification);
        } else if (notification is ScrollEndNotification && !_isRefreshing) {
          if (_dragOffset > 0) _handleDragEnd();
        }
        return false;
      },
      child: Stack(
        children: [
          // ── Botanical indicator ──────────────────────────────
          if (_dragOffset > 0 || _isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _dismissController.drive(
                  Tween<double>(begin: 1.0, end: 0.0),
                ),
                child: SizedBox(
                  height: _dragOffset.clamp(0.0, _triggerDistance),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _bloomController,
                        _dismissController,
                      ]),
                      builder: (ctx, _) {
                        final pullProgress = (_dragOffset / _triggerDistance)
                            .clamp(0.0, 1.0);
                        return CustomPaint(
                          size: const Size(80, 80),
                          painter: _SeedlingPainter(
                            pullProgress: _isRefreshing ? 1.0 : pullProgress,
                            bloomProgress: _bloomController.value,
                            isTriggered: _triggered,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          // ── Actual scrollable content ─────────────────────────
          widget.child,
        ],
      ),
    );
  }
}

/// Paints the seedling animation: seed → sprout → bloom
class _SeedlingPainter extends CustomPainter {
  final double pullProgress; // 0.0 → 1.0 (pull phase)
  final double bloomProgress; // 0.0 → 1.0 (bloom phase)
  final bool isTriggered;

  _SeedlingPainter({
    required this.pullProgress,
    required this.bloomProgress,
    required this.isTriggered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;

    final stemColor = isTriggered
        ? SeedlingColors.seedlingGreen
        : SeedlingColors.freshSprout;
    const groundColor = Color(0xFF8D6E63);

    // ── Ground line ──────────────────────────────────────────────
    final groundPaint = Paint()
      ..color = groundColor.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 30, cy), Offset(cx + 30, cy), groundPaint);

    // ── Stem ─────────────────────────────────────────────────────
    final stemHeight = pullProgress * size.height * 0.7;
    if (stemHeight > 2) {
      final stemPaint = Paint()
        ..color = stemColor
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx, cy), Offset(cx, cy - stemHeight), stemPaint);
    }

    // ── Seed / bud ───────────────────────────────────────────────
    if (pullProgress < 0.5) {
      final seedRadius = 7.0 * pullProgress.clamp(0.4, 1.0) * 2.0;
      final seedPaint = Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy - stemHeight), seedRadius, seedPaint);
    } else if (bloomProgress == 0) {
      // Sprout / bud phase
      final budPaint = Paint()
        ..color = SeedlingColors.freshSprout
        ..style = PaintingStyle.fill;
      final budPath = Path()
        ..moveTo(cx, cy - stemHeight - 12)
        ..quadraticBezierTo(
          cx + 10,
          cy - stemHeight - 8,
          cx + 4,
          cy - stemHeight,
        )
        ..quadraticBezierTo(
          cx - 10,
          cy - stemHeight - 8,
          cx,
          cy - stemHeight - 12,
        );
      canvas.drawPath(budPath, budPaint);
    }

    // ── Bloom (flower petals) ─────────────────────────────────────
    if (bloomProgress > 0) {
      final bloomScale = bloomProgress;
      final flowerCenter = Offset(cx, cy - stemHeight - 6);
      const numPetals = 6;
      final petalRadius = 9.0 * bloomScale;
      final orbitRadius = 10.0 * bloomScale;

      for (int i = 0; i < numPetals; i++) {
        final angle = (i / numPetals) * 2 * math.pi;
        final px = flowerCenter.dx + math.cos(angle) * orbitRadius;
        final py = flowerCenter.dy + math.sin(angle) * orbitRadius;
        // Alternate colors for premium feel
        final petalPaint = Paint()
          ..color = (i % 2 == 0)
              ? SeedlingColors.sunlight.withValues(alpha: 0.9 * bloomScale)
              : SeedlingColors.seedlingGreen.withValues(
                  alpha: 0.85 * bloomScale,
                )
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), petalRadius, petalPaint);
      }

      // Center dot
      final centerPaint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: bloomScale)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(flowerCenter, 6 * bloomScale, centerPaint);
    }
  }

  @override
  bool shouldRepaint(_SeedlingPainter old) =>
      old.pullProgress != pullProgress ||
      old.bloomProgress != bloomProgress ||
      old.isTriggered != isTriggered;
}
