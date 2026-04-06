import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';

// ── Floating Leaves Background ────────────────────────────────────────────────
class FloatingLeavesBackground extends StatefulWidget {
  final Widget child;

  const FloatingLeavesBackground({super.key, required this.child});

  @override
  State<FloatingLeavesBackground> createState() =>
      _FloatingLeavesBackgroundState();
}

class _FloatingLeavesBackgroundState extends State<FloatingLeavesBackground>
    with TickerProviderStateMixin {
  // Three independent controllers for parallax depth layers
  late final AnimationController _backLayer;
  late final AnimationController _midLayer;
  late final AnimationController _frontLayer;

  @override
  void initState() {
    super.initState();
    _backLayer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _midLayer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _frontLayer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _backLayer.dispose();
    _midLayer.dispose();
    _frontLayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_backLayer, _midLayer, _frontLayer]),
      builder: (context, child) {
        return CustomPaint(
          painter: FloatingLeavesPainter(
            back: _backLayer.value,
            mid: _midLayer.value,
            front: _frontLayer.value,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class FloatingLeavesPainter extends CustomPainter {
  final double back;
  final double mid;
  final double front;

  // Pre-seeded leaf configs per layer
  static final _rng = math.Random(7);
  static final List<_LeafConfig> _backLeaves = List.generate(
    10,
    (i) => _LeafConfig.random(_rng, depth: 0),
  );
  static final List<_LeafConfig> _midLeaves = List.generate(
    7,
    (i) => _LeafConfig.random(_rng, depth: 1),
  );
  static final List<_LeafConfig> _frontLeaves = List.generate(
    5,
    (i) => _LeafConfig.random(_rng, depth: 2),
  );

  FloatingLeavesPainter({
    required this.back,
    required this.mid,
    required this.front,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintLayer(canvas, size, _backLeaves, back);
    _paintLayer(canvas, size, _midLeaves, mid);
    _paintLayer(canvas, size, _frontLeaves, front);
  }

  void _paintLayer(
    Canvas canvas,
    Size size,
    List<_LeafConfig> leaves,
    double t,
  ) {
    for (final leaf in leaves) {
      // Position: drift right→left slowly, sine-wave vertical drift
      final tOffset = (t * leaf.speed + leaf.phase) % 1.0;
      final x = size.width * (1.0 - tOffset) + leaf.xBias * size.width * 0.2;
      final y =
          size.height * leaf.baseY +
          math.sin(tOffset * math.pi * 2 + leaf.sinPhase) * 8.0;

      // Alpha pulse (breathe)
      final alphaPulse =
          0.7 + math.sin(tOffset * math.pi * 3 + leaf.phase * 6) * 0.3;
      final alpha = leaf.baseAlpha * alphaPulse;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tOffset * leaf.spinRate);

      _drawLeafShape(
        canvas,
        leaf.size,
        leaf.color.withValues(alpha: alpha.clamp(0, 1)),
      );

      canvas.restore();
    }
  }

  void _drawLeafShape(Canvas canvas, double s, Color color) {
    // Gradient fill
    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, -s), [
        color,
        color.withValues(alpha: color.a * 0.45),
      ])
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-s * 0.55, -s * 0.38, 0, -s)
      ..quadraticBezierTo(s * 0.55, -s * 0.38, 0, 0);

    canvas.drawPath(path, paint);

    // Midrib vein
    final veinPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 0), Offset(0, -s), veinPaint);
  }

  @override
  bool shouldRepaint(covariant FloatingLeavesPainter old) => true;
}

class _LeafConfig {
  final double baseX,
      baseY,
      xBias,
      size,
      speed,
      phase,
      sinPhase,
      spinRate,
      baseAlpha;
  final Color color;

  const _LeafConfig({
    required this.baseX,
    required this.baseY,
    required this.xBias,
    required this.size,
    required this.speed,
    required this.phase,
    required this.sinPhase,
    required this.spinRate,
    required this.baseAlpha,
    required this.color,
  });

  factory _LeafConfig.random(math.Random rng, {required int depth}) {
    // Colors: mostly green shades, occasional gold tone
    final colorPalette = [
      SeedlingColors.freshSprout,
      SeedlingColors.morningDew,
      SeedlingColors.seedlingGreen,
      SeedlingColors.sunlight,
    ];
    final colorWeights = [0, 0, 1, 3]; // sunlight only ~25% chance
    final colorIdx = rng.nextInt(colorWeights.last + 1) < 3
        ? rng.nextInt(3)
        : 3;

    // Size and alpha per depth layer
    final sizing = [22.0, 15.0, 10.0][depth];
    final alphas = [0.08, 0.14, 0.22][depth];
    final speeds = [0.6, 0.8, 1.0][depth];

    return _LeafConfig(
      baseX: rng.nextDouble(),
      baseY: rng.nextDouble() * 0.85 + 0.05,
      xBias: rng.nextDouble() - 0.5,
      size: sizing + rng.nextDouble() * sizing * 0.5,
      speed: speeds + rng.nextDouble() * 0.3,
      phase: rng.nextDouble(),
      sinPhase: rng.nextDouble() * math.pi * 2,
      spinRate: (rng.nextDouble() - 0.5) * math.pi * 2 * (1.0 + depth * 0.5),
      baseAlpha: alphas + rng.nextDouble() * alphas * 0.5,
      color: colorPalette[colorIdx],
    );
  }
}

// ── Root Network ──────────────────────────────────────────────────────────────
class RootNetwork extends StatefulWidget {
  final List<String> words;
  final String centralWord;

  const RootNetwork({
    super.key,
    required this.words,
    required this.centralWord,
  });

  @override
  State<RootNetwork> createState() => _RootNetworkState();
}

class _RootNetworkState extends State<RootNetwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(double.infinity, 300),
          painter: RootNetworkPainter(
            words: widget.words,
            centralWord: widget.centralWord,
            pulseValue: _pulseController.value,
          ),
        );
      },
    );
  }
}

class RootNetworkPainter extends CustomPainter {
  final List<String> words;
  final String centralWord;
  final double pulseValue;

  RootNetworkPainter({
    required this.words,
    required this.centralWord,
    this.pulseValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final rng = math.Random(centralWord.hashCode);

    // Draw root connections first (below nodes)
    for (int i = 0; i < words.length; i++) {
      final angle = (i / words.length.toDouble()) * math.pi * 2.0;
      const dist = 105.0;
      final endX = cx + math.cos(angle) * dist;
      final endY = cy + math.sin(angle) * dist;

      // Organic slight curve with rng jitter
      final jX = (rng.nextDouble() - 0.5) * 30;
      final jY = (rng.nextDouble() - 0.5) * 30;

      final rootPaint = Paint()
        ..shader = ui.Gradient.linear(Offset(cx, cy), Offset(endX, endY), [
          SeedlingColors.seedlingGreen.withValues(alpha: 0.6),
          SeedlingColors.morningDew.withValues(alpha: 0.25),
        ])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(cx, cy)
        ..quadraticBezierTo(
          cx + math.cos(angle) * dist * 0.5 + jX,
          cy + math.sin(angle) * dist * 0.5 + jY,
          endX,
          endY,
        );
      canvas.drawPath(path, rootPaint);

      // Traveling light pulse along each root
      final tPulse = (pulseValue + i / words.length) % 1.0;
      final pX = cx + (endX - cx) * tPulse + (jX * tPulse * (1 - tPulse));
      final pY = cy + (endY - cy) * tPulse + (jY * tPulse * (1 - tPulse));
      final pulseAlpha = math.sin(tPulse * math.pi) * 0.7;
      canvas.drawCircle(
        Offset(pX, pY),
        6.0,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(pX, pY),
            6.0,
            [
              SeedlingColors.morningDew.withValues(alpha: pulseAlpha),
              SeedlingColors.morningDew.withValues(alpha: 0.0),
            ],
            [0.3, 1.0],
          ),
      );
    }

    // ── Word nodes ───────────────────────────────────────────────────────
    for (int i = 0; i < words.length; i++) {
      final angle = (i / words.length.toDouble()) * math.pi * 2.0;
      const dist = 105.0;
      final endX = cx + math.cos(angle) * dist;
      final endY = cy + math.sin(angle) * dist;

      // Node shadow/glow
      canvas.drawCircle(
        Offset(endX, endY),
        29,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(endX, endY),
            29.0,
            [
              SeedlingColors.seedlingGreen.withValues(alpha: 0.12),
              SeedlingColors.seedlingGreen.withValues(alpha: 0.0),
            ],
            [0.6, 1.0],
          ),
      );

      // Node gradient fill
      final nodePaint = Paint()
        ..shader = ui.Gradient.radial(Offset(endX - 5, endY - 5), 20, [
          SeedlingColors.freshSprout,
          SeedlingColors.seedlingGreen,
        ])
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(endX, endY), 20.0, nodePaint);

      // Node rim
      canvas.drawCircle(
        Offset(endX, endY),
        20.0,
        Paint()
          ..color = SeedlingColors.deepRoot.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Node gloss
      canvas.drawCircle(
        Offset(endX - 6, endY - 6),
        7,
        Paint()
          ..color = SeedlingColors.textPrimary.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Central node ─────────────────────────────────────────────────────
    final pulseRadius = 34.0 + pulseValue * 4.5;

    // Outer glow ring
    canvas.drawCircle(
      Offset(cx, cy),
      pulseRadius + 8.0,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          pulseRadius + 8.0,
          [
            SeedlingColors.seedlingGreen.withValues(
              alpha: 0.12 * (1 - pulseValue),
            ),
            SeedlingColors.seedlingGreen.withValues(alpha: 0.0),
          ],
          [0.6, 1.0],
        ),
    );

    // Main node
    final centerPaint = Paint()
      ..shader = ui.Gradient.radial(Offset(cx - 8, cy - 8), 30, [
        SeedlingColors.freshSprout,
        SeedlingColors.deepRoot,
      ])
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 30.0, centerPaint);

    // Rim
    canvas.drawCircle(
      Offset(cx, cy),
      30.0,
      Paint()
        ..color = SeedlingColors.deepRoot.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Gloss
    canvas.drawCircle(
      Offset(cx - 9, cy - 9),
      10,
      Paint()
        ..color = SeedlingColors.textPrimary.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant RootNetworkPainter old) =>
      old.pulseValue != pulseValue || old.words != words;
}
