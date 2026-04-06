import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/word.dart';
import '../models/taxonomy.dart';
import '../widgets/mascot.dart';
import '../services/tts_service.dart';
import '../widgets/target_word_display.dart';
import '../widgets/example_sentence_display.dart';
import '../widgets/word_image.dart';

// ================================================================
// SEED PLANTING SEQUENCE
// ================================================================
// Flow:
//   Phase 0 (seedAppear)  → Seed drops in from above, wobbles
//   Phase 1 (cracking)    → Seed cracks open, word + translation emerge
//   Phase 2 (reading)     → User reads; "Plant it ↓" CTA visible
//   Phase 3 (planting)    → Seed falls into soil with particle burst
//   Phase 4 (done)        → Next word OR start quiz if batch full
// ================================================================

const int _kDefaultBatchSize = 3; // words to plant if unspecified

class SeedPlantingScreen extends StatefulWidget {
  /// Words available for planting (ordered).
  final List<Word> words;

  /// How many to plant in this batch before calling onPlantingComplete.
  final int initialBatchSize;

  /// Called immediately after each seed is planted — use to persist to DB.
  final Future<void> Function(Word word)? onWordPlanted;

  /// Optional header label override.
  final String? headerLabel;

  /// Called when all seeds in this batch are planted.
  final VoidCallback onPlantingComplete;

  /// If true, disables the Scaffold, SafeArea, and top bar for embedding inside other screens.
  final bool isEmbedded;

  const SeedPlantingScreen({
    super.key,
    required this.words,
    required this.onPlantingComplete,
    this.initialBatchSize = _kDefaultBatchSize,
    this.onWordPlanted,
    this.headerLabel,
    this.isEmbedded = false,
  });

  @override
  State<SeedPlantingScreen> createState() => _SeedPlantingScreenState();
}

enum _PlantPhase { seedAppear, cracking, reading, planting, done }

class _SeedPlantingScreenState extends State<SeedPlantingScreen>
    with TickerProviderStateMixin {
  int _currentWordIndex = 0;
  final List<Word> _plantedWords = [];
  _PlantPhase _phase = _PlantPhase.seedAppear;

  // ── animation controllers ──────────────────────────────────────
  late AnimationController _dropController; // seed enters from top
  late AnimationController _crackController; // crack open
  late AnimationController _revealController; // word/translation fade-in
  late AnimationController _plantController; // falling into soil
  late AnimationController _particleController; // burst particles
  late AnimationController _gardenController; // planted seeds row

  // ── animations ─────────────────────────────────────────────────
  late Animation<double> _dropAnim;
  late Animation<double> _crackAnim;
  late Animation<double> _revealAnim;
  late Animation<double> _plantAnim;
  late Animation<double> _particleAnim;
  late Animation<double> _gardenAnim;

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _startSeedAppear();
  }

  void _setupControllers() {
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _crackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _plantController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _gardenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _dropAnim = CurvedAnimation(
      parent: _dropController,
      curve: Curves.bounceOut,
    );
    _crackAnim = CurvedAnimation(
      parent: _crackController,
      curve: Curves.easeInOut,
    );
    _revealAnim = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOut,
    );
    _plantAnim = CurvedAnimation(
      parent: _plantController,
      curve: Curves.easeIn,
    );
    _particleAnim = CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    );
    _gardenAnim = CurvedAnimation(
      parent: _gardenController,
      curve: Curves.elasticOut,
    );
  }

  // ── phase transitions ──────────────────────────────────────────

  void _startSeedAppear() async {
    if (!mounted) return;
    setState(() => _phase = _PlantPhase.seedAppear);

    // Reset all controllers for a clean sequence start
    _dropController.value = 0;
    _crackController.value = 0;
    _revealController.value = 0;
    _plantController.value = 0;
    _particleController.value = 0;

    await _dropController.forward();
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      _startCracking();
    }
  }

  void _startCracking() async {
    if (!mounted) return;
    setState(() => _phase = _PlantPhase.cracking);
    _crackController.value = 0;
    await _crackController.forward();
    if (mounted) {
      _revealController.value = 0;
      await _revealController.forward();
      if (mounted) {
        setState(() => _phase = _PlantPhase.reading);
        // Ultra high-end pedagogical auto-play when word is revealed
        final w = widget.words[_currentWordIndex];
        TtsService.instance.speak(w.ttsWord, w.targetLanguageCode);
      }
    }
  }

  Future<void> _plantSeed() async {
    if (!mounted) return;
    setState(() => _phase = _PlantPhase.planting);
    _plantController.value = 0;
    _particleController.value = 0;
    _gardenController.value = 0;
    unawaited(_plantController.forward());
    unawaited(_particleController.forward());
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    if (_currentWordIndex < widget.words.length) {
      final w = widget.words[_currentWordIndex];
      _plantedWords.add(w);
      if (widget.onWordPlanted != null) {
        await widget.onWordPlanted!(w);
      }
    }
    await _gardenController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final batchFull = _plantedWords.length >= widget.initialBatchSize;
    final noMoreWords = _currentWordIndex + 1 >= widget.words.length;

    if (batchFull || noMoreWords) {
      setState(() => _phase = _PlantPhase.done);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) widget.onPlantingComplete();
    } else {
      _currentWordIndex++;
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _startSeedAppear();
    }
  }

  @override
  void dispose() {
    _dropController.dispose();
    _crackController.dispose();
    _revealController.dispose();
    _plantController.dispose();
    _particleController.dispose();
    _gardenController.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentWord = widget.words.isNotEmpty
        ? widget.words[_currentWordIndex.clamp(0, widget.words.length - 1)]
        : null;

    final body = Column(
      children: [
        if (!widget.isEmbedded) _buildTopBar(),
        Expanded(
          child: _phase == _PlantPhase.done
              ? _buildCompletionView()
              : _buildPlantingView(currentWord),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(child: body),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: SeedlingColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.headerLabel ?? 'Plant Your Seeds',
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                _buildBatchProgress(),
              ],
            ),
          ),
          SeedlingMascot(
            size: 56,
            state: _phase == _PlantPhase.reading
                ? MascotState.happy
                : _phase == _PlantPhase.planting
                ? MascotState.growing
                : MascotState.idle,
          ),
        ],
      ),
    );
  }

  Widget _buildBatchProgress() {
    return Row(
      children: List.generate(widget.initialBatchSize, (i) {
        final planted = i < _plantedWords.length;
        final current = i == _plantedWords.length && _phase != _PlantPhase.done;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.only(right: 6),
          width: planted ? 28 : (current ? 22 : 18),
          height: planted ? 10 : (current ? 8 : 6),
          decoration: BoxDecoration(
            color: planted
                ? SeedlingColors.deepRoot
                : current
                ? SeedlingColors.seedlingGreen
                : SeedlingColors.morningDew.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }

  Widget _buildPlantingView(Word? word) {
    if (word == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // Soil layer at bottom
        Positioned(bottom: 0, left: 0, right: 0, child: _buildSoilLayer()),

        // Planted seeds garden (grows as we plant)
        Positioned(bottom: 60, left: 0, right: 0, child: _buildPlantedGarden()),

        // Main content — scrollable to prevent overflow on small screens with long sentences
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // The animated seed + word reveal
                      _buildSeedReveal(word),

                      const SizedBox(height: 48),

                      // CTA button — only visible in reading phase
                      _buildPlantButton(),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Particle burst (during planting)
        if (_phase == _PlantPhase.planting)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _particleAnim,
                builder: (ctx, _) => RepaintBoundary(
                  child: CustomPaint(
                    painter: SeedParticlePainter(progress: _particleAnim.value),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Seed + Crack + Reveal ───────────────────────────────────────

  Widget _buildSeedReveal(Word word) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _dropAnim,
        _crackAnim,
        _revealAnim,
        _plantAnim,
      ]),
      builder: (ctx, _) {
        // Seed falls from above
        final dropOffset = Offset(0, -250 * (1 - _dropAnim.value));

        // Seed shrinks + falls into soil during plant phase
        final plantOffset = Offset(0, 400 * _plantAnim.value);
        final plantScale = 1.0 - (_plantAnim.value * 0.5);

        return Transform.translate(
          offset: dropOffset + plantOffset,
          child: Transform.scale(
            scale: plantScale,
            child: Column(
              children: [
                // ── Seed CustomPainter ──
                SizedBox(
                  width: 180,
                  height: 180,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: SeedRevealPainter(
                        crackProgress: _crackAnim.value,
                        revealProgress: _revealAnim.value,
                        plantProgress: _plantAnim.value,
                      ),
                    ),
                  ),
                ),

                // ── Word + Translation ──
                if (_crackAnim.value > 0.5) ...[
                  const SizedBox(height: 20),
                  _buildWordReveal(word),
                  _buildIllustration(word),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordReveal(Word word) {
    return FadeTransition(
      opacity: _revealAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.seedlingGreen.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: SeedlingColors.morningDew.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            if (word.partsOfSpeech.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${word.partsOfSpeech.first.icon} ${(word.partOfSpeechRaw ?? word.partsOfSpeech.first.displayName).toUpperCase()}',
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.deepRoot,
                    fontSize: 11,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TargetWordDisplay(
                  word: word,
                  showPronunciation: true,
                  style: SeedlingTypography.heading1.copyWith(
                    fontSize: 34,
                    color: SeedlingColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: SeedlingColors.seedlingGreen,
                  ),
                  onPressed: () => TtsService.instance.speak(
                    word.ttsWord,
                    word.targetLanguageCode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(height: 1.5, width: 60, color: SeedlingColors.morningDew),
            const SizedBox(height: 8),
            Text(
              word.translation,
              style: SeedlingTypography.body.copyWith(
                color: SeedlingColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            if (word.definition != null &&
                word.definition!.isNotEmpty &&
                word.definition != word.translation) ...[
              const SizedBox(height: 12),
              Text(
                word.definition!,
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (word.exampleSentence != null &&
                word.exampleSentence!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExampleSentenceDisplay(
                word: word,
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(Word word) {
    final path = WordImage.assetPath(word.imageId);
    if (path == null) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeIn,
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              path,
              width: 160,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantButton() {
    if (_phase != _PlantPhase.reading) return const SizedBox(height: 52);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: GestureDetector(
        onTap: _plantSeed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SeedlingColors.seedlingGreen, SeedlingColors.deepRoot],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_downward_rounded,
                color: SeedlingColors.textPrimary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Plant It',
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Garden row of planted seeds ─────────────────────────────────

  Widget _buildPlantedGarden() {
    if (_plantedWords.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _gardenAnim,
      builder: (ctx, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_plantedWords.length, (i) {
            final delay = i / _plantedWords.length;
            final t = (((_gardenAnim.value - delay) / (1 - delay)).clamp(
              0.0,
              1.0,
            ));
            return Transform.scale(scale: t, child: const _PlantedSeedling());
          }),
        );
      },
    );
  }

  Widget _buildSoilLayer() {
    return SizedBox(
      height: 60,
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(double.infinity, 60),
          painter: _SoilLayerPainter(),
        ),
      ),
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SeedlingMascot(size: 100, state: MascotState.celebrating),
          const SizedBox(height: 24),
          Text(
            'Garden Ready!',
            style: SeedlingTypography.heading1.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'Time to grow your knowledge 🌱',
            style: SeedlingTypography.body.copyWith(
              color: SeedlingColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SeedRevealPainter
// ================================================================
// Draws the signature animated seed: warm brown oval, crack lines
// radiating from center, then the seed glows green as it opens.
// ================================================================

class SeedRevealPainter extends CustomPainter {
  final double crackProgress; // 0→1: cracks appear
  final double revealProgress; // 0→1: inner light glows
  final double plantProgress; // 0→1: seed fades to soil

  SeedRevealPainter({
    required this.crackProgress,
    required this.revealProgress,
    required this.plantProgress,
  });

  Path? _cachedSeedPath;
  Size? _lastSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseAlpha = (1.0 - plantProgress).clamp(0.0, 1.0);

    // ── Drop shadow ──
    final shadowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              SeedlingColors.deepRoot.withValues(alpha: 0.15 * baseAlpha),
              SeedlingColors.deepRoot.withValues(alpha: 0.0),
            ],
            stops: const [0.4, 1.0],
          ).createShader(
            Rect.fromCenter(center: Offset(cx, cy + 8), width: 110, height: 80),
          );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 8), width: 110, height: 80),
      shadowPaint,
    );

    // ── Seed body ──
    final seedPaint = Paint()
      ..color = Color.lerp(
        SeedlingColors.soil,
        SeedlingColors.deepRoot,
        crackProgress * 0.6,
      )!.withValues(alpha: baseAlpha)
      ..style = PaintingStyle.fill;

    if (_cachedSeedPath == null || _lastSize != size) {
      _cachedSeedPath = _buildSeedPath(cx, cy, 54, 72);
      _lastSize = size;
    }

    canvas.drawPath(_cachedSeedPath!, seedPaint);

    // ── Seed highlight ──
    final highlightPaint = Paint()
      ..color = SeedlingColors.morningDew.withValues(alpha: 0.22 * baseAlpha)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.clipPath(_cachedSeedPath!);
    final highlightPath = Path()
      ..addOval(Rect.fromLTWH(cx - 30, cy - 45, 60, 40));
    canvas.drawPath(highlightPath, highlightPaint);
    canvas.restore();

    // ── Crack lines ──
    if (crackProgress > 0) {
      _drawCracks(canvas, cx, cy, crackProgress, baseAlpha);
    }

    // ── Inner glow when cracking open ──
    if (revealProgress > 0) {
      final glowRadius = 30.0 + revealProgress * 20.0;
      final glowPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                SeedlingColors.freshSprout.withValues(
                  alpha: revealProgress * 0.9 * baseAlpha,
                ),
                SeedlingColors.seedlingGreen.withValues(
                  alpha: revealProgress * 0.4 * baseAlpha,
                ),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius),
            );
      canvas.save();
      canvas.clipPath(_cachedSeedPath!);
      canvas.drawCircle(Offset(cx, cy), glowRadius, glowPaint);
      canvas.restore();

      // Small sprout emerging from top of seed
      _drawEmergingSprout(canvas, cx, cy - 54, revealProgress, baseAlpha);
    }

    // ── Seed outline ──
    final outlinePaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(alpha: 0.6 * baseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(_cachedSeedPath!, outlinePaint);
  }

  Path _buildSeedPath(double cx, double cy, double rw, double rh) {
    return Path()
      ..moveTo(cx, cy - rh)
      ..cubicTo(
        cx + rw,
        cy - rh * 0.6,
        cx + rw * 0.8,
        cy + rh * 0.4,
        cx,
        cy + rh,
      )
      ..cubicTo(
        cx - rw * 0.8,
        cy + rh * 0.4,
        cx - rw,
        cy - rh * 0.6,
        cx,
        cy - rh,
      )
      ..close();
  }

  void _drawCracks(
    Canvas canvas,
    double cx,
    double cy,
    double progress,
    double alpha,
  ) {
    final crackPaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(
        alpha: 0.5 * progress * alpha,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // 4 crack lines radiating from center
    final cracks = [
      [const Offset(0, 0), const Offset(20, -30)],
      [const Offset(0, 0), const Offset(-15, -28)],
      [const Offset(0, 0), const Offset(22, 20)],
      [const Offset(0, 0), const Offset(-18, 22)],
    ];

    for (final c in cracks) {
      final start = Offset(cx + c[0].dx, cy + c[0].dy);
      final end = Offset(
        cx + c[0].dx + (c[1].dx - c[0].dx) * progress,
        cy + c[0].dy + (c[1].dy - c[0].dy) * progress,
      );
      canvas.drawLine(start, end, crackPaint);
    }
  }

  void _drawEmergingSprout(
    Canvas canvas,
    double x,
    double y,
    double progress,
    double alpha,
  ) {
    // Tiny sprout emerging upward as seed reveals
    final stemPaint = Paint()
      ..color = SeedlingColors.freshSprout.withValues(alpha: progress * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final stemHeight = 28.0 * progress;
    canvas.drawLine(Offset(x, y), Offset(x, y - stemHeight), stemPaint);

    // Tiny leaf pair at top of sprout
    if (progress > 0.5) {
      final leafProgress = (progress - 0.5) / 0.5;
      final leafPaint = Paint()
        ..color = SeedlingColors.freshSprout.withValues(
          alpha: leafProgress * alpha,
        )
        ..style = PaintingStyle.fill;

      _drawTinyLeaf(
        canvas,
        x,
        y - stemHeight,
        -0.4,
        10 * leafProgress,
        leafPaint,
      );
      _drawTinyLeaf(
        canvas,
        x,
        y - stemHeight,
        0.4,
        9 * leafProgress,
        leafPaint,
      );
    }
  }

  void _drawTinyLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double size,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-size / 2, -size / 3, 0, -size)
      ..quadraticBezierTo(size / 2, -size / 3, 0, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SeedRevealPainter old) =>
      old.crackProgress != crackProgress ||
      old.revealProgress != revealProgress ||
      old.plantProgress != plantProgress;
}

// ================================================================
// SeedParticlePainter — burst of soil particles when planting
// ================================================================

class SeedParticlePainter extends CustomPainter {
  final double progress; // 0→1

  SeedParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final rng = math.Random(42);

    for (int i = 0; i < 20; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 60 + rng.nextDouble() * 100;
      final radius = 3 + rng.nextDouble() * 5;
      final fade = (1 - progress).clamp(0.0, 1.0);

      final px = cx + math.cos(angle) * speed * progress;
      // gravity
      final py =
          cy + math.sin(angle) * speed * progress + 80 * progress * progress;

      final color = i % 2 == 0
          ? SeedlingColors.soil
          : SeedlingColors.freshSprout;

      canvas.drawCircle(
        Offset(px, py),
        radius * fade,
        Paint()..color = color.withValues(alpha: fade * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SeedParticlePainter old) =>
      old.progress != progress;
}

// ================================================================
// _PlantedSeedling — small planted seedling icon in garden row
// ================================================================

class _PlantedSeedling extends StatelessWidget {
  const _PlantedSeedling();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: 50,
        height: 70,
        child: CustomPaint(painter: _PlantedSeedlingPainter()),
      ),
    );
  }
}

class _PlantedSeedlingPainter extends CustomPainter {
  Path? _cachedSoilPath;
  Size? _lastSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final groundY = size.height * 0.7;

    // Soil mound
    final soilPaint = Paint()
      ..color = SeedlingColors.soil.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    if (_cachedSoilPath == null || _lastSize != size) {
      _cachedSoilPath = Path()
        ..moveTo(cx - 18, groundY)
        ..quadraticBezierTo(cx, groundY - 8, cx + 18, groundY)
        ..lineTo(cx + 20, groundY + 10)
        ..lineTo(cx - 20, groundY + 10)
        ..close();
      _lastSize = size;
    }
    canvas.drawPath(_cachedSoilPath!, soilPaint);

    // Stem
    final stemPaint = Paint()
      ..color = SeedlingColors.seedlingGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx, groundY), Offset(cx, groundY - 30), stemPaint);

    // Leaves
    final leafPaint = Paint()
      ..color = SeedlingColors.freshSprout
      ..style = PaintingStyle.fill;

    _drawLeaf(canvas, cx, groundY - 18, -0.5, 12, leafPaint);
    _drawLeaf(canvas, cx, groundY - 24, 0.5, 11, leafPaint);
  }

  void _drawLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double size,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-size / 2, -size / 3, 0, -size)
      ..quadraticBezierTo(size / 2, -size / 3, 0, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ================================================================
// _SoilLayerPainter — organic wavy soil strip at screen bottom
// ================================================================

class _SoilLayerPainter extends CustomPainter {
  Path? _cachedPath;
  Size? _lastSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SeedlingColors.soil.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    if (_cachedPath == null || _lastSize != size) {
      _cachedPath = Path()..moveTo(0, size.height * 0.4);

      for (double x = 0; x <= size.width; x += 40) {
        _cachedPath!.quadraticBezierTo(
          x + 20,
          size.height * 0.4 + 10 * math.sin((x / size.width) * math.pi * 3),
          x + 40,
          size.height * 0.4,
        );
      }
      _cachedPath!
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      _lastSize = size;
    }

    canvas.drawPath(_cachedPath!, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── tiny helper so we don't need dart:async import ───────────────
void unawaited(Future<void> future) {}
