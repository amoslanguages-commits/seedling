import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';

// ignore_for_file: prefer_const_constructors

enum MascotState { idle, happy, growing, sad, celebrating, excited, thinking }

// ─────────────────────────────────────────────────────────────────────────────
//  SeedlingMascot — The official Seedling app mascot, "Sprout"
//
//  Sprout is a cartoon-realistic plant in a terracotta pot. He has a round
//  face made from his leaf canopy, expressive anime-style eyes that blink and
//  emote, a dynamic stem/body, and reacts to every state with full-body
//  animation. Fully vector, drawn with CustomPainter, no images required.
// ─────────────────────────────────────────────────────────────────────────────
class SeedlingMascot extends StatefulWidget {
  final double size;
  final MascotState state;
  final MascotAccessories accessories;
  final VoidCallback? onTap;

  const SeedlingMascot({
    super.key,
    this.size = 200,
    this.state = MascotState.idle,
    this.accessories = const MascotAccessories(),
    this.onTap,
  });

  /// Static paint method for logo / export use.
  static void paintForExport(
    Canvas canvas,
    Size size, {
    MascotState state = MascotState.idle,
  }) {
    final painter = _SproutPainter(
      state: state,
      accessories: const MascotAccessories(),
      bob: 0,
      sway: 0,
      blink: 0,
      transition: 1.0,
      squish: 0,
      excite: 0,
      sadDroop: 0,
      sparkle: 0,
    );
    painter.paint(canvas, size);
  }

  @override
  State<SeedlingMascot> createState() => _SeedlingMascotState();
}

class _SeedlingMascotState extends State<SeedlingMascot>
    with TickerProviderStateMixin {
  /// Gentle up-down float (root motion — drives everything)
  late final AnimationController _bob;
  /// Leaf canopy arcing sway
  late final AnimationController _sway;
  /// Eye blink trigger
  late final AnimationController _blink;
  /// State-transition morphing weight (0→1 when state changes)
  late final AnimationController _stateTransition;
  /// Tap squish reaction
  late final AnimationController _squish;
  /// Excited bounce / jump
  late final AnimationController _excite;
  /// Sad wilt (leaves droop)
  late final AnimationController _sadDroop;
  /// Sparkle twinkle for celebrate
  late final AnimationController _sparkle;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _stateTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _squish = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _excite = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _sadDroop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _applyStateAnimations(widget.state);
    _startBlinkLoop();
  }

  void _applyStateAnimations(MascotState s) {
    _excite.value = 0;
    _sadDroop.value = 0;
    if (s == MascotState.excited || s == MascotState.celebrating) {
      _excite.repeat(reverse: true);
    } else if (s == MascotState.sad) {
      _sadDroop.forward();
    }
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 1800 + math.Random().nextInt(3500)),
      );
      if (!mounted) break;
      await _blink.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 80));
      await _blink.reverse();
      if (math.Random().nextBool()) {
        // Double-blink occasionally
        await Future.delayed(const Duration(milliseconds: 120));
        await _blink.forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 80));
        await _blink.reverse();
      }
    }
  }

  @override
  void didUpdateWidget(SeedlingMascot old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _stateTransition.forward(from: 0);
      _applyStateAnimations(widget.state);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    _sway.dispose();
    _blink.dispose();
    _stateTransition.dispose();
    _squish.dispose();
    _excite.dispose();
    _sadDroop.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _squish.forward(from: 0).then((_) => _squish.reverse());
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _bob, _sway, _blink, _stateTransition,
          _squish, _excite, _sadDroop, _sparkle,
        ]),
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size * 1.35),
            painter: _SproutPainter(
              state: widget.state,
              accessories: widget.accessories,
              bob: _bob.value,
              sway: _sway.value,
              blink: _blink.value,
              transition: _stateTransition.value,
              squish: _squish.value,
              excite: _excite.value,
              sadDroop: _sadDroop.value,
              sparkle: _sparkle.value,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _SproutPainter — The full layered illustration engine for Sprout
// ─────────────────────────────────────────────────────────────────────────────
class _SproutPainter extends CustomPainter {
  final MascotState state;
  final MascotAccessories accessories;
  final double bob;
  final double sway;
  final double blink;
  final double transition;
  final double squish;
  final double excite;
  final double sadDroop;
  final double sparkle;

  _SproutPainter({
    required this.state,
    required this.accessories,
    required this.bob,
    required this.sway,
    required this.blink,
    required this.transition,
    required this.squish,
    required this.excite,
    required this.sadDroop,
    required this.sparkle,
  });

  // ─── Convenience ──────────────────────────────────────────────────────────

  bool get _isHappy =>
      state == MascotState.happy ||
      state == MascotState.celebrating ||
      state == MascotState.excited;
  bool get _isSad => state == MascotState.sad;
  bool get _isThinking => state == MascotState.thinking;
  bool get _isGrowing => state == MascotState.growing;
  bool get _isCelebrating => state == MascotState.celebrating;
  bool get _isExcited => state == MascotState.excited;

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    // ➤ Layout constants relative to canvas
    final cx = W / 2;
    final groundY = H * 0.78;   // top of the pot (reference point)

    // ➤ Rhythmic offsets
    final bobOff = math.sin(bob * math.pi) * H * 0.022;
    final exciteOff = math.sin(excite * math.pi * 2) * H * 0.035;
    final swayAngle = math.sin(sway * math.pi) * 0.05 + (
      _isSad ? sadDroop * -0.06 : 0
    );
    final squishSX = 1.0 + squish * 0.12;
    final squishSY = 1.0 - squish * 0.14;

    // ─── LAYER 1: Plant Logic ─────────────────────────────────────────────
    final plantYOff = bobOff + exciteOff;

    // ─── LAYER 2+: Stem & Canopy (all sway together) ──────────────────────
    canvas.save();
    canvas.translate(cx, groundY + plantYOff);
    canvas.scale(squishSX, squishSY);

    // Pivot sway at pot collar
    canvas.save();
    canvas.rotate(swayAngle);

    _drawStem(canvas, W, H);
    _drawLeafCanopy(canvas, W, H);
    _drawFace(canvas, W, H);

    canvas.restore(); // end sway

    canvas.restore(); // end plant group

    // ─── LAYER 3: Accessories ─────────────────────────────────────────────
    if (accessories.holdingTrophy) {
      _drawTrophy(
        canvas,
        cx - W * 0.44,
        groundY - H * 0.28 + plantYOff,
        W * 0.18,
      );
    }

    // ─── LAYER 4: Global VFX ──────────────────────────────────────────────
    if (_isCelebrating) {
      _drawConfetti(canvas, size, sparkle);
    }
    if (_isGrowing) {
      _drawWaterDroplets(canvas, cx, groundY + plantYOff, W, sparkle);
    }
    if (_isThinking) {
      _drawThoughtBubbles(canvas, cx + W * 0.3, groundY - H * 0.55 + plantYOff, sparkle);
    }
  }


  // ─── STEM ─────────────────────────────────────────────────────────────────

  void _drawStem(Canvas canvas, double W, double H) {
    final stemHeight = H * (_isGrowing ? 0.34 + transition * 0.06 : 0.30);
    final stemCurve = W * 0.06;

    // Main stem — a thick, tapered bezier
    final stemPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(stemCurve, -stemHeight * 0.5, 0, -stemHeight);

    // Stem gradient: dark base to bright tip
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = W * 0.065
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, -stemHeight),
        [
          const Color(0xFF2E6B28),
          const Color(0xFF4BAE4F),
          const Color(0xFF81C784),
        ],
        [0.0, 0.5, 1.0],
      );

    canvas.drawPath(stemPath, stemPaint);

    // Stem highlight (left edge gleam)
    canvas.drawPath(
      stemPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = W * 0.018
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // Leaf nodes — small bumps along the stem
    _drawStemLeaves(canvas, W, H, stemHeight, stemCurve);
  }

  void _drawStemLeaves(Canvas canvas, double W, double H, double stemH, double curve) {
    // Two side leaves growing from the stem at different heights
    final leafPositions = [0.38, 0.65];
    final leafSides = [-1.0, 1.0];  // left, right
    final leafSizes = [W * 0.21, W * 0.18];

    for (int i = 0; i < 2; i++) {
      final t = leafPositions[i];
      final side = leafSides[i];
      // Position on the bezier curve (approximate)
      final px = curve * 2 * t * (1 - t) * side * 0.3;
      final py = -stemH * t;
      final leafAngle = side * (math.pi * 0.35 + (_isSad ? sadDroop * 0.4 : 0));

      canvas.save();
      canvas.translate(px, py);
      _drawRoundLeaf(canvas, side, leafAngle, leafSizes[i], i == 0);
      canvas.restore();
    }
  }

  void _drawRoundLeaf(Canvas canvas, double side, double angle, double size, bool primary) {
    canvas.save();
    canvas.rotate(angle);

    // Leaf silhouette
    final leafPath = Path();
    leafPath.moveTo(0, 0);
    leafPath.cubicTo(
      -size * 0.55 * side, -size * 0.2,
      -size * 0.65 * side, -size * 0.75,
      0, -size,
    );
    leafPath.cubicTo(
      size * 0.65 * side, -size * 0.75,
      size * 0.55 * side, -size * 0.2,
      0, 0,
    );

    // Leaf fill gradient
    canvas.drawPath(
      leafPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -size),
          Offset(0, 0),
          primary
              ? [
                  const Color(0xFF9CCC65),  // leaf tip bright
                  const Color(0xFF558B2F),  // leaf base deep
                ]
              : [
                  const Color(0xFF66BB6A),
                  const Color(0xFF388E3C),
                ],
        ),
    );

    // Leaf mid-vein
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(0, -size * 0.88),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // Leaf sub-veins
    for (int v = 1; v <= 3; v++) {
      final vy = -size * (v * 0.2);
      canvas.drawLine(
        Offset(0, vy),
        Offset(-size * 0.28 * side * (1 - v * 0.15), vy - size * 0.12),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..strokeWidth = 0.8,
      );
    }

    // Leaf edge highlight
    canvas.drawPath(
      leafPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.restore();
  }

  // ─── LEAF CANOPY (head) ───────────────────────────────────────────────────

  void _drawLeafCanopy(Canvas canvas, double W, double H) {
    final stemH = H * (_isGrowing ? 0.34 + transition * 0.06 : 0.30);
    final headCY = -stemH;
    final headR = W * 0.36;

    // The "head" is a large round canopy made of overlapping leaves
    // forming a rough circle — Sprout's face lives in the center

    final blobPath = _buildCanopyBlob(headCY, headR, W);

    // Deep shadow behind canopy
    canvas.drawPath(
      blobPath.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Main canopy fill — uses radial gradient from bright center to dark edge
    canvas.drawPath(
      blobPath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(0, headCY - headR * 0.1),
          headR * 1.1,
          _isGrowing
              ? [
                  const Color(0xFFCCFF90),
                  const Color(0xFF69F0AE),
                  const Color(0xFF00BCD4),
                ]
              : _isSad
                  ? [
                      const Color(0xFF8BC34A),
                      const Color(0xFF558B2F),
                      const Color(0xFF1B5E20),
                    ]
                  : [
                      const Color(0xFFC8E6C9),
                      const Color(0xFF66BB6A),
                      const Color(0xFF2E7D32),
                    ],
          const [0.0, 0.5, 1.0],
        ),
    );

    // Canopy texture — small leaf bumps on top
    _drawCanopyTexture(canvas, headCY, headR, W);

    // Canopy edge highlight (light from top-left)
    canvas.drawPath(
      blobPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Rim specular highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-headR * 0.22, headCY - headR * 0.38),
        width: headR * 0.35,
        height: headR * 0.22,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  Path _buildCanopyBlob(double cy, double r, double W) {
    final sadFlatten = _isSad ? sadDroop * 0.15 : 0.0;
    final exciteStretch = _isExcited ? excite * 0.12 : 0.0;

    final rW = r * (1.0 + exciteStretch);
    final rH = r * (1.0 - sadFlatten + exciteStretch * 0.5);

    // Paint an organic leaf-cluster blob using 8 bezier "bumps"
    final path = Path();
    const int bumps = 8;
    final List<double> bumpAmps = [
      0.10, 0.12, 0.09, 0.14, 0.10, 0.08, 0.12, 0.09
    ];

    for (int i = 0; i <= bumps; i++) {
      final angle = (i / bumps) * math.pi * 2 - math.pi / 2;
      final prevAngle = ((i - 1) / bumps) * math.pi * 2 - math.pi / 2;
      final amp = 1.0 + bumpAmps[i % bumps];
      final prevAmp = 1.0 + bumpAmps[(i - 1) % bumps];

      final x = math.cos(angle) * rW * amp;
      final y = cy + math.sin(angle) * rH * amp;
      final px = math.cos(prevAngle) * rW * prevAmp;
      final py = cy + math.sin(prevAngle) * rH * prevAmp;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final midAngle = (prevAngle + angle) / 2;
        path.quadraticBezierTo(
          math.cos(midAngle) * rW * 0.94,
          cy + math.sin(midAngle) * rH * 0.94,
          x, y,
        );
        // px/py are used implicitly via the loop's prev state — no-op check
        assert(px.isFinite && py.isFinite);
      }
    }
    path.close();
    return path;
  }

  void _drawCanopyTexture(Canvas canvas, double cy, double r, double W) {
    // Small leaf tips poking out of the canopy edge
    const tips = 6;
    for (int i = 0; i < tips; i++) {
      final angle = (i / tips) * math.pi * 2 - math.pi / 2;
      final tipX = math.cos(angle) * r * 1.02;
      final tipY = cy + math.sin(angle) * r * 1.02;

      canvas.save();
      canvas.translate(tipX, tipY);
      canvas.rotate(angle + math.pi / 2);
      _drawMiniLeaf(canvas, W * 0.09);
      canvas.restore();
    }
  }

  void _drawMiniLeaf(Canvas canvas, double size) {
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-size * 0.4, -size * 0.4, 0, -size)
      ..quadraticBezierTo(size * 0.4, -size * 0.4, 0, 0);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -size),
          Offset.zero,
          [const Color(0xFFA5D6A7), const Color(0xFF388E3C)],
        ),
    );
  }

  // ─── FACE ─────────────────────────────────────────────────────────────────

  void _drawFace(Canvas canvas, double W, double H) {
    final stemH = H * (_isGrowing ? 0.34 + transition * 0.06 : 0.30);
    final headCY = -stemH;
    final s = W * 0.36; // canopy radius — face is inscribed inside it

    canvas.save();
    canvas.translate(0, headCY);

    // Eye parameters
    final eyeR = s * 0.15;
    final eyeY = s * 0.04;
    final eyeX = s * 0.33;

    // ─ Eyebrow ─
    if (!_isThinking) _drawEyebrows(canvas, eyeX, eyeY, eyeR, s);

    // ─ Eyes ─
    _drawEyes(canvas, eyeX, eyeY, eyeR, s);

    // ─ Cheeks ─
    if (_isHappy) _drawCheeks(canvas, eyeX, s);

    // ─ Mouth ─
    _drawMouth(canvas, s);

    // ─ Thinking dots ─
    if (_isThinking) _drawThinkingDots(canvas, s);

    canvas.restore();
  }

  void _drawEyebrows(Canvas canvas, double eyeX, double eyeY, double eyeR, double s) {
    final Paint paint = Paint()
      ..color = const Color(0xFF33691E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round;

    double leftBrowTilt = 0;
    double rightBrowTilt = 0;
    double browY = eyeY - eyeR * 1.6;

    if (_isSad) {
      leftBrowTilt = sadDroop * 0.4;
      rightBrowTilt = -sadDroop * 0.4;
      browY -= sadDroop * s * 0.03;
    } else if (_isHappy) {
      leftBrowTilt = -0.2;
      rightBrowTilt = 0.2;
    }

    // Left brow
    canvas.save();
    canvas.translate(-eyeX, browY);
    canvas.rotate(leftBrowTilt);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: eyeR * 2.4, height: eyeR * 1.0),
      math.pi * 1.15, math.pi * 0.65,
      false, paint,
    );
    canvas.restore();

    // Right brow
    canvas.save();
    canvas.translate(eyeX, browY);
    canvas.rotate(rightBrowTilt);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: eyeR * 2.4, height: eyeR * 1.0),
      math.pi * 1.2, math.pi * 0.65,
      false, paint,
    );
    canvas.restore();
  }

  void _drawEyes(Canvas canvas, double eyeX, double eyeY, double eyeR, double s) {
    final blinkScale = (1.0 - blink * 0.95).clamp(0.05, 1.0);

    for (final side in [-1.0, 1.0]) {
      final ex = side * eyeX;

      // Eye white
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ex, eyeY),
          width: eyeR * 2.1,
          height: eyeR * 2.2 * blinkScale,
        ),
        Paint()..color = Colors.white,
      );

      // Iris
      if (blinkScale > 0.3) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(ex + side * 1.5, eyeY + 1.5),
            width: eyeR * 1.35,
            height: eyeR * 1.5 * blinkScale,
          ),
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(ex + side * 1.5, eyeY),
              eyeR * 0.9,
              [
                _isThinking
                    ? const Color(0xFF4A148C)
                    : _isSad
                        ? const Color(0xFF1A237E)
                        : const Color(0xFF1B5E20),
                Colors.black,
              ],
            ),
        );

        // Pupil shine — two sparkles
        canvas.drawCircle(
          Offset(ex + side * 2 - 2, eyeY - 2),
          eyeR * 0.28,
          Paint()..color = Colors.white.withValues(alpha: 0.95),
        );
        canvas.drawCircle(
          Offset(ex + side * 2 + 1.5, eyeY + 1.5),
          eyeR * 0.14,
          Paint()..color = Colors.white.withValues(alpha: 0.6),
        );
      }

      // Eyelid (for blink and sad droop)
      final lidAmount = blink + (_isSad ? sadDroop * 0.25 : 0);
      if (lidAmount > 0.02) {
        canvas.drawOval(
          Rect.fromLTRB(
            ex - eyeR * 1.05,
            eyeY - eyeR * 1.1,
            ex + eyeR * 1.05,
            eyeY - eyeR * 1.1 + eyeR * 2.2 * lidAmount,
          ),
          Paint()..color = const Color(0xFF388E3C),
        );
      }

      // Bottom lash line
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(ex, eyeY),
          width: eyeR * 2.1,
          height: eyeR * 2.2 * blinkScale,
        ),
        0, math.pi,
        false,
        Paint()
          ..color = const Color(0xFF1B5E20).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawCheeks(Canvas canvas, double eyeX, double s) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-eyeX - s * 0.08, s * 0.26),
        width: s * 0.38,
        height: s * 0.20,
      ),
      Paint()
        ..color = const Color(0xFFFF8A80).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(eyeX + s * 0.08, s * 0.26),
        width: s * 0.38,
        height: s * 0.20,
      ),
      Paint()
        ..color = const Color(0xFFFF8A80).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  void _drawMouth(Canvas canvas, double s) {
    double mouthW, curveH;
    bool isOpen = false;

    if (_isSad) {
      mouthW = s * 0.28;
      curveH = -s * 0.10 * sadDroop;
    } else if (state == MascotState.celebrating || _isExcited) {
      mouthW = s * 0.52;
      curveH = s * 0.22;
      isOpen = true;
    } else if (_isHappy) {
      mouthW = s * 0.42;
      curveH = s * 0.18;
    } else if (_isThinking) {
      mouthW = s * 0.18;
      curveH = s * 0.03;
    } else {
      mouthW = s * 0.32;
      curveH = s * 0.10;
    }

    final mouthPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(-mouthW / 2, s * 0.3)
      ..quadraticBezierTo(0, s * 0.3 + curveH, mouthW / 2, s * 0.3);

    if (isOpen) {
      // Open mouth with small teeth
      final openPath = Path()
        ..moveTo(-mouthW / 2, s * 0.3)
        ..quadraticBezierTo(0, s * 0.3 + curveH, mouthW / 2, s * 0.3)
        ..quadraticBezierTo(0, s * 0.3 + curveH * 0.6, -mouthW / 2, s * 0.3)
        ..close();
      canvas.drawPath(
        openPath,
        Paint()..color = const Color(0xFF1B5E20),
      );
      // Teeth
      canvas.drawRect(
        Rect.fromCenter(center: Offset(-mouthW * 0.15, s * 0.3 + curveH * 0.1), width: mouthW * 0.22, height: s * 0.07),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(mouthW * 0.15, s * 0.3 + curveH * 0.1), width: mouthW * 0.22, height: s * 0.07),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    } else {
      canvas.drawPath(mouthPath, mouthPaint);
    }
  }

  void _drawThinkingDots(Canvas canvas, double s) {
    for (int i = 0; i < 3; i++) {
      final phase = math.sin(sparkle * math.pi * 2 + i * 0.8);
      canvas.drawCircle(
        Offset(s * (0.42 + i * 0.22), s * (-0.38 - phase * 0.06)),
        s * 0.05,
        Paint()
          ..color = const Color(0xFF9C27B0).withValues(alpha: 0.7 + phase * 0.3),
      );
    }
  }

  // ─── ACCESSORIES ──────────────────────────────────────────────────────────

  void _drawTrophy(Canvas canvas, double x, double y, double size) {
    canvas.save();
    canvas.translate(x, y);

    // Cup
    final cupPath = Path()
      ..moveTo(-size * 0.7, -size * 0.8)
      ..lineTo(size * 0.7, -size * 0.8)
      ..lineTo(size * 0.5, 0)
      ..quadraticBezierTo(0, size * 0.3, -size * 0.5, 0)
      ..close();

    canvas.drawPath(
      cupPath.shift(const Offset(2, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawPath(
      cupPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-size, -size),
          Offset(size, size),
          [const Color(0xFFFFD54F), const Color(0xFFFF6F00)],
        ),
    );

    // Stem
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, size * 0.45), width: size * 0.2, height: size * 0.4),
      Paint()..color = const Color(0xFFFFB300),
    );

    // Base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, size * 0.7), width: size * 0.8, height: size * 0.2),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFFF8F00),
    );

    // Star
    canvas.drawCircle(Offset.zero, size * 0.22, Paint()..color = const Color(0xFFFFF9C4));

    canvas.restore();
  }

  // ─── VFX ──────────────────────────────────────────────────────────────────


  void _drawConfetti(Canvas canvas, Size size, double t) {
    final rand = math.Random(42); // fixed seed for determinism
    final colors = [
      SeedlingColors.sunlight,
      SeedlingColors.water,
      SeedlingColors.freshSprout,
      SeedlingColors.warning,
      Colors.pinkAccent,
    ];

    for (int i = 0; i < 22; i++) {
      final angle = (i / 22.0) * math.pi * 2 + t * 0.8;
      final dist = size.width * (0.35 + rand.nextDouble() * 0.4);
      final phase = rand.nextDouble();
      final alpha = (math.sin(t * math.pi * 2 + phase * math.pi) * 0.5 + 0.5).clamp(0.0, 1.0);
      final cx = size.width / 2 + math.cos(angle) * dist;
      final cy = size.height / 2 + math.sin(angle) * dist * 0.6;

      final useRect = rand.nextBool();
      final color = colors[rand.nextInt(colors.length)];
      final paint = Paint()..color = color.withValues(alpha: alpha * 0.85);

      if (useRect) {
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(angle * 3);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 8, height: 5), paint);
        canvas.restore();
      } else {
        canvas.drawCircle(Offset(cx, cy), 4.5, paint);
      }
    }
  }

  void _drawWaterDroplets(Canvas canvas, double cx, double groundY, double W, double t) {
    final stemH = W * 0.30;
    final tipX = cx;
    final tipY = groundY - stemH;

    for (int i = 0; i < 5; i++) {
      final phase = (t + i * 0.2) % 1.0;
      final dropX = tipX + math.sin(i * 1.3) * W * 0.08;
      final dropY = tipY - phase * stemH * 0.6;
      final alpha = (1.0 - phase).clamp(0.0, 1.0);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dropX, dropY),
          width: 7,
          height: 10,
        ),
        Paint()
          ..color = SeedlingColors.water.withValues(alpha: alpha * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }
  }

  void _drawThoughtBubbles(Canvas canvas, double x, double y, double t) {
    for (int i = 0; i < 3; i++) {
      final phase = (t + i * 0.33) % 1.0;
      final r = 5.0 + i * 4.0;
      final bx = x + i * 10.0;
      final by = y - phase * 22 - i * 18;
      final alpha = (1.0 - phase).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(bx, by),
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SproutPainter old) =>
      old.state != state ||
      old.accessories != accessories ||
      old.bob != bob ||
      old.sway != sway ||
      old.blink != blink ||
      old.transition != transition ||
      old.squish != squish ||
      old.excite != excite ||
      old.sadDroop != sadDroop ||
      old.sparkle != sparkle;
}

// Suppress "unused" warnings from path operations
// ignore: unused_element
dynamic get _ => null;

// ─────────────────────────────────────────────────────────────────────────────
//  MascotAccessories
// ─────────────────────────────────────────────────────────────────────────────
class MascotAccessories {
  final bool holdingTrophy;
  const MascotAccessories({this.holdingTrophy = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MascotAccessories &&
          runtimeType == other.runtimeType &&
          holdingTrophy == other.holdingTrophy;

  @override
  int get hashCode => holdingTrophy.hashCode;
}
