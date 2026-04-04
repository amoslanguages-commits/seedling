import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/colors.dart';
import '../core/typography.dart';
import '../core/app_utils.dart';
import '../models/word.dart';
import '../widgets/cards.dart';
import '../widgets/target_word_display.dart';
import '../widgets/example_sentence_display.dart';
import '../services/tts_service.dart';

class WordDetailScreen extends ConsumerStatefulWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  ConsumerState<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends ConsumerState<WordDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _growthController;

  @override
  void initState() {
    super.initState();
    _growthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _growthController.forward();

    // Auto-play TTS on word reveal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService.instance.speak(
        widget.word.ttsWord,
        widget.word.targetLanguageCode,
      );
    });
  }

  @override
  void dispose() {
    _growthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastSeenText = widget.word.lastReviewed != null
        ? 'Last reviewed ${relativeTime(widget.word.lastReviewed)}'
        : 'Not yet reviewed';

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: SeedlingColors.textPrimary,
        title: Text(widget.word.word, style: SeedlingTypography.heading2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Pronunciation + TTS Card
            GrowingCard(
              child: Column(
                children: [
                  // Article + Word with colored article
                  TargetWordDisplay(
                    word: widget.word,
                    style: SeedlingTypography.heading1.copyWith(
                      fontSize: 42,
                      color: SeedlingColors.deepRoot,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  // TTS replay button
                  OutlinedButton.icon(
                    onPressed: () => TtsService.instance.speak(
                      widget.word.ttsWord,
                      widget.word.targetLanguageCode,
                    ),
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      color: SeedlingColors.seedlingGreen,
                    ),
                    label: Text(
                      'Hear pronunciation',
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.seedlingGreen,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: SeedlingColors.seedlingGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lastSeenText,
                    style: SeedlingTypography.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botanical Growth Visualization
            GrowingCard(
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _growthController,
                      builder: (_, __) => CustomPaint(
                        painter: WordGrowthPainter(
                          masteryLevel: widget.word.masteryLevel,
                          growthProgress: _growthController.value,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mastery: Level ${widget.word.masteryLevel}',
                    style: SeedlingTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: SeedlingColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Meaning Card
            GrowingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meaning', style: SeedlingTypography.heading3),
                  const SizedBox(height: 8),
                  Text(
                    widget.word.translation,
                    style: SeedlingTypography.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  if (widget.word.exampleSentence != null) ...[
                    Text('Example', style: SeedlingTypography.caption),
                    const SizedBox(height: 8),
                    ExampleSentenceDisplay(word: widget.word),
                  ],
                  if (widget.word.definition != null) ...[
                    const SizedBox(height: 16),
                    Text('Definition', style: SeedlingTypography.caption),
                    const SizedBox(height: 8),
                    Text(
                      widget.word.definition!,
                      style: SeedlingTypography.body,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Mastery Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Streak',
                    '${widget.word.streak}',
                    Icons.bolt,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Reviews',
                    '${widget.word.totalReviews}',
                    Icons.remove_red_eye,
                    SeedlingColors.water,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Correct',
                    '${widget.word.timesCorrect}',
                    Icons.check_circle_outline,
                    SeedlingColors.seedlingGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return GrowingCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: SeedlingTypography.heading3),
          Text(label, style: SeedlingTypography.caption),
        ],
      ),
    );
  }
}

class WordGrowthPainter extends CustomPainter {
  final int masteryLevel;
  final double growthProgress;

  WordGrowthPainter({required this.masteryLevel, required this.growthProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottomY = size.height * 0.85;

    // 1. Draw glowing soil base
    _drawSoil(canvas, cx, bottomY);

    // 2. Determine growth stage based on mastery
    if (masteryLevel < 15) {
      _drawSeedStage(canvas, cx, bottomY);
    } else if (masteryLevel < 40) {
      _drawSproutStage(canvas, cx, bottomY, 0.4);
    } else if (masteryLevel < 70) {
      _drawPlantStage(canvas, cx, bottomY, 0.7);
    } else if (masteryLevel < 100) {
      _drawBuddingStage(canvas, cx, bottomY, 0.9);
    } else {
      _drawBloomingStage(canvas, cx, bottomY, 1.0);
    }
  }

  void _drawSoil(Canvas canvas, double cx, double gy) {
    // Soil mound
    final soilPaint = Paint()
      ..shader = ui.Gradient.linear(Offset(cx, gy - 10), Offset(cx, gy + 10), [
        const Color(0xFF6B4226),
        const Color(0xFF4A2C17),
      ])
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(cx - 30, gy)
      ..quadraticBezierTo(cx, gy - 15, cx + 30, gy)
      ..quadraticBezierTo(cx + 20, gy + 10, cx - 20, gy + 10)
      ..close();
    canvas.drawPath(path, soilPaint);

    // Ground line
    canvas.drawLine(
      Offset(cx - 50, gy),
      Offset(cx + 50, gy),
      Paint()
        ..color = const Color(0xFF6B4226).withValues(alpha: 0.4)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawSeedStage(Canvas canvas, double cx, double gy) {
    final scale = growthProgress;
    final r = 6.0 * scale;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, gy - 2),
        width: r * 2.2,
        height: r * 1.5,
      ),
      Paint()..color = const Color(0xFFA07040),
    );
  }

  void _drawSproutStage(
    Canvas canvas,
    double cx,
    double gy,
    double heightScale,
  ) {
    final stemH = 40.0 * growthProgress * heightScale;

    // Stem
    _drawStem(canvas, cx, gy, stemH, 0.1);

    // Single leaf
    _drawLeaf(
      canvas,
      cx + 2,
      gy - stemH * 0.8,
      0.4,
      12,
      const Color(0xFF74C69D),
    );
  }

  void _drawPlantStage(
    Canvas canvas,
    double cx,
    double gy,
    double heightScale,
  ) {
    final stemH = 70.0 * growthProgress * heightScale;
    _drawStem(canvas, cx, gy, stemH, 0.2);

    _drawLeaf(
      canvas,
      cx - 3,
      gy - stemH * 0.4,
      -0.5,
      15,
      const Color(0xFF52B788),
    );
    _drawLeaf(
      canvas,
      cx + 2,
      gy - stemH * 0.7,
      0.4,
      18,
      const Color(0xFF74C69D),
    );
    _drawLeaf(
      canvas,
      cx - 1,
      gy - stemH * 0.95,
      -0.2,
      14,
      const Color(0xFF95D5B2),
    );
  }

  void _drawBuddingStage(
    Canvas canvas,
    double cx,
    double gy,
    double heightScale,
  ) {
    final stemH = 100.0 * growthProgress * heightScale;
    _drawStem(canvas, cx, gy, stemH, 0.3);

    _drawLeaf(
      canvas,
      cx - 3,
      gy - stemH * 0.3,
      -0.5,
      18,
      const Color(0xFF40916C),
    );
    _drawLeaf(
      canvas,
      cx + 4,
      gy - stemH * 0.55,
      0.6,
      22,
      const Color(0xFF52B788),
    );
    _drawLeaf(
      canvas,
      cx - 2,
      gy - stemH * 0.8,
      -0.4,
      16,
      const Color(0xFF74C69D),
    );

    // Bud at top
    canvas.drawCircle(
      Offset(cx + 4, gy - stemH - 5),
      6,
      Paint()..color = SeedlingColors.freshSprout,
    );
  }

  void _drawBloomingStage(
    Canvas canvas,
    double cx,
    double gy,
    double heightScale,
  ) {
    final stemH = 120.0 * growthProgress * heightScale;
    _drawStem(canvas, cx, gy, stemH, 0.4);

    _drawLeaf(
      canvas,
      cx - 4,
      gy - stemH * 0.3,
      -0.5,
      20,
      const Color(0xFF2D6A4F),
    );
    _drawLeaf(
      canvas,
      cx + 5,
      gy - stemH * 0.5,
      0.6,
      24,
      const Color(0xFF40916C),
    );
    _drawLeaf(
      canvas,
      cx - 3,
      gy - stemH * 0.75,
      -0.45,
      18,
      const Color(0xFF52B788),
    );
    _drawLeaf(
      canvas,
      cx + 2,
      gy - stemH * 0.9,
      0.3,
      15,
      const Color(0xFF74C69D),
    );

    // Full Flower
    final fx = cx + 5.0;
    final fy = gy - stemH - 10;

    final petalPaint = Paint()
      ..color = const Color(0xFFFFD166)
      ..style = PaintingStyle.fill;

    // 5 petals
    for (int i = 0; i < 5; i++) {
      final angle = (i / 5.0) * math.pi * 2;
      canvas.drawCircle(
        Offset(fx + math.cos(angle) * 8, fy + math.sin(angle) * 8),
        7,
        petalPaint,
      );
    }

    // Flower center
    canvas.drawCircle(
      Offset(fx, fy),
      6,
      Paint()..color = const Color(0xFFFF9F1C),
    );

    // Sparkles for mastery
    _drawSparkle(canvas, fx - 20, fy - 10, 0.0);
    _drawSparkle(canvas, fx + 25, fy + 5, 0.5);
    _drawSparkle(canvas, fx - 10, fy + 20, 0.8);
  }

  void _drawStem(Canvas canvas, double cx, double gy, double h, double curve) {
    final tipX = cx + math.sin(curve) * h * 0.3;
    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset(cx, gy), Offset(tipX, gy - h), [
        const Color(0xFF2D6A4F),
        const Color(0xFF74C69D),
      ])
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(cx, gy)
      ..quadraticBezierTo(cx + curve * 20, gy - h / 2, tipX, gy - h);
    canvas.drawPath(path, paint);
  }

  void _drawLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double size,
    Color tipColor,
  ) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-size * 0.5, -size * 0.3, 0, -size)
      ..quadraticBezierTo(size * 0.5, -size * 0.3, 0, 0);

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, -size), [
          const Color(0xFF2D6A4F),
          tipColor,
        ]),
    );

    canvas.drawLine(
      const Offset(0, 0),
      Offset(0, -size * 0.9),
      Paint()
        ..color = const Color(0xFF2D6A4F).withValues(alpha: 0.4)
        ..strokeWidth = 0.8,
    );

    canvas.restore();
  }

  void _drawSparkle(Canvas canvas, double x, double y, double phase) {
    final t = (growthProgress + phase) % 1.0;
    final alpha = math.sin(t * math.pi);
    if (alpha <= 0) return;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(t * math.pi / 2);

    final r = 4.0 * math.sin(t * math.pi);
    final paint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: alpha);

    final path = Path();
    for (int i = 0; i < 4; i++) {
      final a = (i / 4.0) * math.pi * 2;
      if (i == 0) {
        path.moveTo(math.cos(a) * r, math.sin(a) * r);
      } else {
        path.lineTo(math.cos(a) * r, math.sin(a) * r);
      }
      final a2 = a + math.pi / 4;
      path.lineTo(math.cos(a2) * r * 0.3, math.sin(a2) * r * 0.3);
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WordGrowthPainter oldDelegate) =>
      oldDelegate.masteryLevel != masteryLevel ||
      oldDelegate.growthProgress != growthProgress;
}
