import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twemoji/twemoji.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/grammar_model.dart';
import '../../providers/grammar_provider.dart';
import '../../providers/course_provider.dart';
import '../../services/haptic_service.dart';
import 'concept_detail_screen.dart';

class GrammarScreen extends ConsumerStatefulWidget {
  const GrammarScreen({super.key});

  @override
  ConsumerState<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends ConsumerState<GrammarScreen>
    with TickerProviderStateMixin {
  late AnimationController _ambientController;
  late AnimationController _pulseController;
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;
  late ScrollController _scrollController;

  // Node layout constants
  static const double _nodeSpacing = 82.0;
  static const double _levelPadding = 52.0;
  static const double _soilHeight = 200.0;
  static const double _topPadding = 160.0;
  static const double _branchOffset = 108.0;
  static const double _nodeRadius = 28.0;

  // Level transition indices (concept index after which extra spacing applies)
  static const Map<int, GrammarLevel> _levelStartIndex = {
    0: GrammarLevel.a0,   // index 0  = concept 1
    19: GrammarLevel.a1,  // index 19 = concept 20
    48: GrammarLevel.a2,  // index 48 = concept 49
    72: GrammarLevel.b1,  // index 72 = concept 73
    90: GrammarLevel.b2,  // index 90 = concept 91
    108: GrammarLevel.c1, // index 108 = concept 109
  };

  late List<Offset> _nodePositions;
  late double _canvasHeight;
  late double _canvasWidth;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _entranceFade = CurvedAnimation(parent: _entranceController, curve: Curves.easeIn);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));
    _scrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _computeLayout(MediaQuery.of(context).size.width);
  }

  void _computeLayout(double screenWidth) {
    _canvasWidth = screenWidth;
    final centerX = screenWidth / 2;

    // Calculate accumulated level extra spacing at each index
    double extraY = 0;
    final positions = <Offset>[];

    for (int i = 0; i < GrammarConcept.allConcepts.length; i++) {
      if (i > 0 && _levelStartIndex.containsKey(i)) {
        extraY += _levelPadding;
      }

      final y = _topPadding + (i * _nodeSpacing) + extraY;

      double x;
      if (i == 0) {
        x = centerX; // seed at center
      } else if (i % 2 == 0) {
        x = centerX - _branchOffset;
      } else {
        x = centerX + _branchOffset;
      }

      positions.add(Offset(x, y));
    }

    _nodePositions = positions;
    // Canvas grows top→bottom, but conceptually soil is at bottom.
    // We flip: index 0 = bottom, index 120 = top.
    // To flip, invert Y:
    final maxY = positions.last.dy + _nodeSpacing;
    _canvasHeight = maxY + _soilHeight;

    // Re-map all positions so index 0 is near the bottom
    for (int i = 0; i < _nodePositions.length; i++) {
      final flipped = _canvasHeight - _soilHeight - _nodePositions[i].dy;
      _nodePositions[i] = Offset(_nodePositions[i].dx, flipped);
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _pulseController.dispose();
    _entranceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── SCROLL TO FRONTIER ────────────────────────────────────────────────────

  void _scrollToFrontier(int frontierConceptId) {
    final conceptIndex = GrammarConcept.allConcepts
        .indexWhere((c) => c.conceptId == frontierConceptId);
    if (conceptIndex < 0 || conceptIndex >= _nodePositions.length) return;

    final nodeY = _nodePositions[conceptIndex].dy;
    final screenH = MediaQuery.of(context).size.height;
    // Scroll so the frontier node is ~60% up the screen
    final targetScroll = (nodeY - screenH * 0.6).clamp(0.0, _canvasHeight);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(grammarStatsProvider);
    final progressAsync = ref.watch(allConceptProgressProvider);
    final frontierAsync = ref.watch(frontierConceptIdProvider);

    frontierAsync.whenData((id) => _scrollToFrontier(id));

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: Stack(
        children: [
          // ── Ambient background orbs ──────────────────────────────────────
          _buildAmbientBackground(),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: Column(
                  children: [
                    // Sticky header
                    _buildHeader(statsAsync),

                    // Scrollable roadmap
                    Expanded(
                      child: progressAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: SeedlingColors.seedlingGreen,
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Text('Error: $e',
                              style: const TextStyle(color: SeedlingColors.error)),
                        ),
                        data: (progressMap) => _buildRoadmap(progressMap),
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

  // ─── AMBIENT BACKGROUND ───────────────────────────────────────────────────

  Widget _buildAmbientBackground() {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (_, __) {
        final t = _ambientController.value;
        return Stack(
          children: [
            // Layer 1: Deep Distant Orbs
            Positioned(
              top: -100 + math.sin(t * math.pi * 2) * 40,
              right: -80 + math.cos(t * math.pi * 2) * 30,
              child: _orb(400, SeedlingColors.seedlingGreen, 0.08),
            ),
            // Layer 2: Midground Atmosphere
            Positioned(
              top: 350 + math.cos(t * math.pi * 2) * 50,
              left: -120 + math.sin(t * math.pi * 2) * 35,
              child: _orb(480, const Color(0xFF1B5E20), 0.05),
            ),
            // Layer 3: Accent Glows
            Positioned(
              bottom: 120 + math.sin(t * math.pi) * 25,
              right: -100,
              child: _orb(360, SeedlingColors.sunlight, 0.04),
            ),
            // Layer 4: Frosted Blur Overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _orb(double size, Color color, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: alpha),
            Colors.transparent,
          ]),
        ),
      );

  // ─── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader(AsyncValue<GrammarStats> statsAsync) {
    return statsAsync.when(
      loading: () => _buildHeaderShell(null),
      error: (_, __) => _buildHeaderShell(null),
      data: _buildHeaderShell,
    );
  }

  Widget _buildHeaderShell(GrammarStats? stats) {
    final activeCourse = ref.watch(courseProvider).activeCourse;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: SeedlingColors.background.withValues(alpha: 0.65),
        border: Border(
          bottom: BorderSide(
            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Level badge
                  _LevelBadge(level: stats?.currentLevel ?? GrammarLevel.a0),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _ShimmerTitle('Grammar Conservatory'),
                            const SizedBox(width: 8),
                            if (activeCourse != null)
                              Twemoji(
                                emoji: activeCourse.targetLanguage.flag,
                                height: 16,
                                width: 16,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stats != null
                              ? '${stats.masteredConcepts} mastered · ${stats.inProgressConcepts} growing · ${stats.dueCount} due'
                              : 'Loading your garden…',
                          style: SeedlingTypography.caption.copyWith(
                            color: SeedlingColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stats != null && stats.dueCount > 0)
                    _ReviewBadge(count: stats.dueCount),
                ],
              ),
              const SizedBox(height: 16),
              // Overall mastery bar
              if (stats != null) _OverallMasteryBar(mastery: stats.overallMastery),
            ],
          ),
        ),
      ),
    );
  }

  // ─── ROADMAP ──────────────────────────────────────────────────────────────

  Widget _buildRoadmap(Map<int, ConceptProgress> progressMap) {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: _canvasWidth,
        height: _canvasHeight,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Botanical painter (background) ──────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_ambientController, _pulseController]),
                builder: (_, __) => RepaintBoundary(
                  child: CustomPaint(
                    painter: BotanicalRoadmapPainter(
                      nodePositions: _nodePositions,
                      concepts: GrammarConcept.allConcepts,
                      progressMap: progressMap,
                      ambientValue: _ambientController.value,
                      pulseValue: _pulseController.value,
                      canvasHeight: _canvasHeight,
                      soilHeight: _soilHeight,
                      nodeRadius: _nodeRadius,
                      branchOffset: _branchOffset,
                    ),
                    size: Size(_canvasWidth, _canvasHeight),
                  ),
                ),
              ),
            ),

            // ── Level zone labels ──────────────────────────────────────
            ..._buildLevelLabels(progressMap),

            // ── Concept nodes (tappable widgets) ───────────────────────
            ..._buildConceptNodes(progressMap),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLevelLabels(Map<int, ConceptProgress> progressMap) {
    final labels = <Widget>[];
    for (final entry in _levelStartIndex.entries) {
      final idx = entry.key;
      final level = entry.value;
      if (idx >= _nodePositions.length) continue;

      final nodeY = _nodePositions[idx].dy;
      final labelY = nodeY + _nodeRadius + 8;

      labels.add(
        Positioned(
          left: 0,
          right: 0,
          top: labelY,
          child: _LevelZoneLabel(level: level),
        ),
      );
    }
    return labels;
  }

  List<Widget> _buildConceptNodes(Map<int, ConceptProgress> progressMap) {
    final nodes = <Widget>[];
    for (int i = 0; i < GrammarConcept.allConcepts.length; i++) {
      final concept = GrammarConcept.allConcepts[i];
      final pos = _nodePositions[i];
      final progress = progressMap[concept.conceptId] ??
          ConceptProgress.empty(concept.conceptId);

      nodes.add(
        Positioned(
          left: pos.dx - 80, // Expand width to 160 to prevent text wrapping too early
          top: pos.dy - _nodeRadius - 8,
          width: 160,
          child: _ConceptNodeWidget(
            concept: concept,
            progress: progress,
            nodeRadius: _nodeRadius,
            pulseValue: _pulseController.value,
            onTap: () => _openConceptDetail(concept, progress),
          ),
        ),
      );
    }
    return nodes;
  }

  void _openConceptDetail(GrammarConcept concept, ConceptProgress progress) {
    if (!progress.isUnlocked) {
      HapticService.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Master earlier concepts to unlock ${concept.displayName}',
            style: SeedlingTypography.body.copyWith(color: Colors.white),
          ),
          backgroundColor: SeedlingColors.soil,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    HapticService.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            ConceptDetailScreen(concept: concept, initialProgress: progress),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }
}

// ─── BOTANICAL ROADMAP PAINTER ────────────────────────────────────────────────

class BotanicalRoadmapPainter extends CustomPainter {
  final List<Offset> nodePositions;
  final List<GrammarConcept> concepts;
  final Map<int, ConceptProgress> progressMap;
  final double ambientValue;
  final double pulseValue;
  final double canvasHeight;
  final double soilHeight;
  final double nodeRadius;
  final double branchOffset;

  BotanicalRoadmapPainter({
    required this.nodePositions,
    required this.concepts,
    required this.progressMap,
    required this.ambientValue,
    required this.pulseValue,
    required this.canvasHeight,
    required this.soilHeight,
    required this.nodeRadius,
    required this.branchOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawGodRays(canvas, size);
    _drawSoil(canvas, size);
    _drawRoots(canvas, size);
    _drawMainStem(canvas, size);
    _drawBranches(canvas, size);
    _drawLevelZoneHalos(canvas, size);
    _drawNodeBackgrounds(canvas, size);
    _drawParticles(canvas, size);
  }

  // ── God Rays ──────────────────────────────────────────────────────────────

  void _drawGodRays(Canvas canvas, Size size) {
    final rayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.03 + (0.02 * math.sin(ambientValue * math.pi * 2))),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.4, 0)
      ..lineTo(size.width * 0.8, size.height * 0.6)
      ..lineTo(size.width * 0.2, size.height * 0.6)
      ..close();

    canvas.drawPath(path, rayPaint);
  }

  // ── Sky gradient ──────────────────────────────────────────────────────────

  void _drawSky(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A1F12), // deep canopy night
          Color(0xFF0B1910), // mid forest
          Color(0xFF0C1A10), // near soil
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  // ── Soil layer ────────────────────────────────────────────────────────────

  void _drawSoil(Canvas canvas, Size size) {
    final soilTop = canvasHeight - soilHeight;
    final soilRect = Rect.fromLTWH(0, soilTop, size.width, soilHeight);

    // Rich soil gradient
    final soilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1A0E08).withValues(alpha: 0.0),
          const Color(0xFF2E1A0F),
          const Color(0xFF3E2010),
          const Color(0xFF1C0E07),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(soilRect);
    // Soil surface organic curves
    final surfaceY = soilTop;
    final surfacePath = Path()
      ..moveTo(0, surfaceY + 15)
      ..quadraticBezierTo(size.width * 0.25, surfaceY - 15, size.width * 0.5, surfaceY + 5)
      ..quadraticBezierTo(size.width * 0.75, surfaceY + 25, size.width, surfaceY - 10)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
      
    canvas.drawPath(surfacePath, soilPaint);

    final surfaceLinePaint = Paint()
      ..color = const Color(0xFF6D4C41)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    // Draw only the top curve of the soil as the surface line
    final topCurve = Path()
      ..moveTo(0, surfaceY + 15)
      ..quadraticBezierTo(size.width * 0.25, surfaceY - 15, size.width * 0.5, surfaceY + 5)
      ..quadraticBezierTo(size.width * 0.75, surfaceY + 25, size.width, surfaceY - 10);
    canvas.drawPath(topCurve, surfaceLinePaint);

    // Soil pebble texture dots
    final rand = math.Random(42);
    final pebblePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 60; i++) {
      final px = rand.nextDouble() * size.width;
      final py = soilTop + 8 + rand.nextDouble() * (soilHeight - 20);
      final pr = 1.5 + rand.nextDouble() * 2.5;
      final alpha = 0.08 + rand.nextDouble() * 0.12;
      pebblePaint.color = const Color(0xFF8D6E63).withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), pr, pebblePaint);
    }
  }

  // ── Root network ──────────────────────────────────────────────────────────

  void _drawRoots(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final soilTop = canvasHeight - soilHeight;
    final rootPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4E342E).withValues(alpha: 0.75);

    void drawTaperedRoot(Offset start, Offset control, Offset end, double startWidth, double endWidth) {
       final path = Path()..moveTo(start.dx, start.dy)..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
       final metrics = path.computeMetrics().first;
       final length = metrics.length;
       for (double d = 0; d < length; d += 2.0) {
         final t = d / length;
         final width = lerpDouble(startWidth, endWidth, t)!;
         final segment = metrics.extractPath(d, d + 2.0);
         rootPaint.strokeWidth = width;
         canvas.drawPath(segment, rootPaint);
       }
    }

    // Left main taproot + secondary
    drawTaperedRoot(Offset(centerX, soilTop + 10), Offset(centerX - 60, soilTop + 60), Offset(centerX - 120, soilTop + 140), 5.0, 0.5);
    drawTaperedRoot(Offset(centerX - 40, soilTop + 45), Offset(centerX - 90, soilTop + 80), Offset(centerX - 80, soilTop + 150), 3.0, 0.5);
    drawTaperedRoot(Offset(centerX - 70, soilTop + 80), Offset(centerX - 130, soilTop + 90), Offset(centerX - 150, soilTop + 160), 2.0, 0.2);

    // Right main taproot + secondary
    drawTaperedRoot(Offset(centerX, soilTop + 10), Offset(centerX + 60, soilTop + 65), Offset(centerX + 110, soilTop + 150), 6.0, 0.5);
    drawTaperedRoot(Offset(centerX + 40, soilTop + 45), Offset(centerX + 100, soilTop + 100), Offset(centerX + 80, soilTop + 180), 3.5, 0.5);
    drawTaperedRoot(Offset(centerX + 80, soilTop + 90), Offset(centerX + 140, soilTop + 110), Offset(centerX + 160, soilTop + 160), 1.8, 0.2);

    // Center deep root
    drawTaperedRoot(Offset(centerX, soilTop + 10), Offset(centerX + 15, soilTop + 80), Offset(centerX - 10, soilTop + 200), 5.5, 0.5);
    drawTaperedRoot(Offset(centerX + 5, soilTop + 60), Offset(centerX - 20, soilTop + 110), Offset(centerX - 50, soilTop + 180), 2.5, 0.3);
  }

  // ── Main stem ─────────────────────────────────────────────────────────────

  void _drawMainStem(Canvas canvas, Size size) {
    if (nodePositions.isEmpty) return;
    final centerX = size.width / 2;
    final soilSurface = canvasHeight - soilHeight;
    final stemTop = nodePositions.last.dy;

    // Build organic stem path with slight sinusoidal wiggle
    final stemPoints = <Offset>[];
    const segments = 40;
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final y = soilSurface - t * (soilSurface - stemTop);
      final wiggle = math.sin(t * math.pi * 3.5) * 5.0;
      stemPoints.add(Offset(centerX + wiggle, y));
    }

    // Draw the stem in tapered segments
    int numSegments = stemPoints.length - 1;
    for (int i = 0; i < numSegments; i++) {
      final t = i / numSegments;
      final strokeW = lerpDouble(11.0, 2.5, t)!;
      final alpha = lerpDouble(0.85, 0.5, t)!;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeW
        ..color = const Color(0xFF2E7D32).withValues(alpha: alpha);

      canvas.drawLine(stemPoints[i], stemPoints[i + 1], paint);
    }

    // Stem highlight (right edge)
    for (int i = 0; i < numSegments; i++) {
      final t = i / numSegments;
      final strokeW = lerpDouble(3.0, 0.8, t)!;
      final alpha = lerpDouble(0.25, 0.08, t)!;
      final offset = lerpDouble(3.0, 1.0, t)!;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeW
        ..color = const Color(0xFF81C784).withValues(alpha: alpha);

      canvas.drawLine(
        Offset(stemPoints[i].dx + offset, stemPoints[i].dy),
        Offset(stemPoints[i + 1].dx + offset, stemPoints[i + 1].dy),
        paint,
      );
    }

    // Realistic bark texture lines
    final barkRand = math.Random(88);
    for (int bark = 0; bark < 5; bark++) {
      final offsetX = (barkRand.nextDouble() - 0.5); // -0.5 to 0.5
      final path = Path();
      for (int i = 0; i < numSegments; i++) {
        final t = i / numSegments;
        final w = lerpDouble(11.0, 2.5, t)! * 0.7; // Keep texture inside the stem
        final barkX = stemPoints[i].dx + (offsetX * w);
        if (i == 0) {
          path.moveTo(barkX, stemPoints[i].dy);
        } else {
          path.lineTo(barkX, stemPoints[i].dy);
        }
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + barkRand.nextDouble()
        ..color = const Color(0xFF143015).withValues(alpha: 0.3 + barkRand.nextDouble() * 0.2);
      canvas.drawPath(path, paint);
    }
  }

  // ── Branch connections ────────────────────────────────────────────────────

  void _drawBranches(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    for (int i = 1; i < nodePositions.length; i++) {
      final nodePos = nodePositions[i];
      final concept = concepts[i];
      final progress = progressMap[concept.conceptId];
      final isUnlocked = progress?.isUnlocked ?? false;

      // Branch origin point on the stem (same Y as the node, but at centerX with wiggle)
      final t = (i / nodePositions.length);
      final stemWiggle = math.sin(t * math.pi * 3.5) * 5.0;
      final stemX = centerX + stemWiggle;
      final originY = nodePos.dy;

      final isLeft = nodePos.dx < centerX;
      final controlX = isLeft ? stemX - 40 : stemX + 40;

      final branchPath = Path()
        ..moveTo(stemX, originY)
        ..quadraticBezierTo(controlX, originY, nodePos.dx, nodePos.dy);

      final branchColor = isUnlocked
          ? _nodeColor(progress, concept.level).withValues(alpha: 0.5)
          : const Color(0xFF3E4F3E).withValues(alpha: 0.3);

      final branchPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = branchColor;

      // Draw tapered branch
      final metrics = branchPath.computeMetrics().first;
      final length = metrics.length;
      for (double d = 0; d < length; d += 2.0) {
         final segment = metrics.extractPath(d, d + 2.0);
         // Thicker near stem (3.5 or 2.5 locked), thinner near node (1.2)
         final startWidth = isUnlocked ? 3.5 : 2.5;
         branchPaint.strokeWidth = lerpDouble(startWidth, 1.2, d / length)!;
         canvas.drawPath(segment, branchPaint);
      }

      // Small leaf decoration along the branch midpoint
      if (isUnlocked && i % 3 == 0) {
        final midX = (stemX + nodePos.dx) / 2;
        final midY = (originY + nodePos.dy) / 2;
        _drawLeaf(canvas, Offset(midX, midY), isLeft, concept.level, 0.4);
      }
    }
  }

  // ── Level zone halos ──────────────────────────────────────────────────────

  void _drawLevelZoneHalos(Canvas canvas, Size size) {
    final levelBoundaries = {
      0: GrammarLevel.a0,
      19: GrammarLevel.a1,
      48: GrammarLevel.a2,
      72: GrammarLevel.b1,
      90: GrammarLevel.b2,
      108: GrammarLevel.c1,
    };

    for (final entry in levelBoundaries.entries) {
      final idx = entry.key;
      final level = entry.value;
      if (idx >= nodePositions.length) continue;

      final y = nodePositions[idx].dy;
      final glowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            level.glowColor.withValues(alpha: 0.06 + 0.03 * pulseValue),
            level.glowColor.withValues(alpha: 0.10 + 0.04 * pulseValue),
            level.glowColor.withValues(alpha: 0.06 + 0.03 * pulseValue),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, y - 30, size.width, 60));

      canvas.drawRect(
        Rect.fromLTWH(0, y - 30, size.width, 60),
        glowPaint,
      );
    }
  }

  // ── Node backgrounds ──────────────────────────────────────────────────────

  void _drawNodeBackgrounds(Canvas canvas, Size size) {
    for (int i = 0; i < nodePositions.length; i++) {
      final pos = nodePositions[i];
      final concept = concepts[i];
      final progress = progressMap[concept.conceptId];
      final state = progress?.nodeState ?? ConceptNodeState.locked;
      final isUnlocked = progress?.isUnlocked ?? false;

      if (!isUnlocked) {
        _drawLockedNode(canvas, pos, concept);
      } else {
        _drawActiveNode(canvas, pos, concept, state, progress?.mastery ?? 0.0);
      }
    }
  }

  void _drawLockedNode(Canvas canvas, Offset pos, GrammarConcept concept) {
    // Faint outer ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF2E3A2E).withValues(alpha: 0.5);
    canvas.drawCircle(pos, nodeRadius, ringPaint);

    // Dark fill
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF111E13).withValues(alpha: 0.8);
    canvas.drawCircle(pos, nodeRadius - 2, fillPaint);
  }

  void _drawActiveNode(
    Canvas canvas,
    Offset pos,
    GrammarConcept concept,
    ConceptNodeState state,
    double mastery,
  ) {
    final color = _nodeColor(
        progressMap[concept.conceptId], concept.level);

    // Outer glow
    final glowAlpha = state == ConceptNodeState.available
        ? 0.25 + 0.15 * pulseValue
        : state == ConceptNodeState.mastered
            ? 0.35 + 0.15 * pulseValue
            : 0.20;

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = color.withValues(alpha: glowAlpha);
    canvas.drawCircle(pos, nodeRadius + 8, glowPaint);

    // Background circle
    final bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.35),
          const Color(0xFF14261A),
        ],
      ).createShader(Rect.fromCircle(center: pos, radius: nodeRadius));
    canvas.drawCircle(pos, nodeRadius, bgPaint);

    // Mastery Bloom (Petals)
    if (state == ConceptNodeState.mastered) {
      final petalPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.25 + (0.1 * pulseValue));
      
      for (int i = 0; i < 5; i++) {
        final angle = (i * 72) * math.pi / 180;
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle + (pulseValue * 0.1));
        
        final petalPath = Path()
          ..moveTo(0, -nodeRadius - 2)
          ..quadraticBezierTo(8, -nodeRadius - 10, 0, -nodeRadius - 18)
          ..quadraticBezierTo(-8, -nodeRadius - 10, 0, -nodeRadius - 2)
          ..close();
        
        canvas.drawPath(petalPath, petalPaint);
        canvas.restore();
      }
    }

    // Progress arc
    if (state == ConceptNodeState.inProgress || state == ConceptNodeState.mastered) {
      final arcRect =
          Rect.fromCircle(center: pos, radius: nodeRadius - 3);
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.85);
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        mastery * 2 * math.pi,
        false,
        arcPaint,
      );
    }

    // Border ring
    final borderAlpha = state == ConceptNodeState.mastered ? 0.95 : 0.65;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = state == ConceptNodeState.mastered ? 2.5 : 1.8
      ..color = color.withValues(alpha: borderAlpha);
    canvas.drawCircle(pos, nodeRadius, borderPaint);

    // Mastered shimmer inner ring
    if (state == ConceptNodeState.mastered) {
      final shimmerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(
            alpha: 0.15 + 0.15 * pulseValue);
      canvas.drawCircle(pos, nodeRadius - 6, shimmerPaint);
    }
  }

  // ── Decorative leaf ───────────────────────────────────────────────────────

  void _drawLeaf(
      Canvas canvas, Offset pos, bool facingLeft, GrammarLevel level, double alpha) {
    final color = level.color.withValues(alpha: alpha);
    final leafPaint = Paint()..color = color..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    if (!facingLeft) canvas.scale(-1, 1);
    canvas.rotate(-math.pi / 6);

    final leafPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-8, -10, 0, -20)
      ..quadraticBezierTo(8, -10, 0, 0);
    canvas.drawPath(leafPath, leafPaint);
    canvas.restore();
  }

  // ── Floating particles ────────────────────────────────────────────────────

  void _drawParticles(Canvas canvas, Size size) {
    final rand = math.Random(99);
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 28; i++) {
      final baseX = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * canvasHeight;
      final floatOffset = math.sin((ambientValue + i * 0.23) * math.pi * 2) * 12;
      final opacity = 0.04 + rand.nextDouble() * 0.1;
      final radius = 1.0 + rand.nextDouble() * 2.0;

      particlePaint.color = SeedlingColors.seedlingGreen.withValues(alpha: opacity);
      canvas.drawCircle(Offset(baseX, baseY + floatOffset), radius, particlePaint);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _nodeColor(ConceptProgress? progress, GrammarLevel level) {
    if (progress == null) return const Color(0xFF2E3A2E);
    switch (progress.nodeState) {
      case ConceptNodeState.locked:
        return const Color(0xFF2E3A2E);
      case ConceptNodeState.available:
        return level.color;
      case ConceptNodeState.inProgress:
        return level.color;
      case ConceptNodeState.mastered:
        return SeedlingColors.sunlight;
    }
  }

  @override
  bool shouldRepaint(BotanicalRoadmapPainter oldDelegate) {
    return oldDelegate.ambientValue != ambientValue ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.progressMap != progressMap;
  }
}

// ─── CONCEPT NODE WIDGET (Tappable overlay) ───────────────────────────────────

class _ConceptNodeWidget extends StatefulWidget {
  final GrammarConcept concept;
  final ConceptProgress progress;
  final double nodeRadius;
  final double pulseValue;
  final VoidCallback onTap;

  const _ConceptNodeWidget({
    required this.concept,
    required this.progress,
    required this.nodeRadius,
    required this.pulseValue,
    required this.onTap,
  });

  @override
  State<_ConceptNodeWidget> createState() => _ConceptNodeWidgetState();
}

class _ConceptNodeWidgetState extends State<_ConceptNodeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.progress.nodeState;
    final color = widget.concept.level.color;
    final isLocked = state == ConceptNodeState.locked;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Vessel (Rounded Square)
            Container(
              width: widget.nodeRadius * 2,
              height: widget.nodeRadius * 2,
              decoration: BoxDecoration(
                color: SeedlingColors.cardBackground.withValues(
                  alpha: isLocked ? 0.4 : 0.85,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLocked
                      ? Colors.white12
                      : color.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: isLocked
                    ? []
                    : [
                        BoxShadow(
                          color: color.withValues(
                            alpha: 0.15 + (0.1 * widget.pulseValue),
                          ),
                          blurRadius: 12 + (8 * widget.pulseValue),
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Center(
                child: Opacity(
                  opacity: isLocked ? 0.35 : 1.0,
                  child: Text(
                    widget.concept.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title text
            Text(
              widget.concept.displayName.toUpperCase(),
              textAlign: TextAlign.center,
              style: SeedlingTypography.caption.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: isLocked ? Colors.white24 : Colors.white70,
                shadows: [
                  Shadow(
                    blurRadius: 4.0,
                    color: Colors.black.withValues(alpha: 0.5),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LEVEL ZONE LABEL ────────────────────────────────────────────────────────

class _LevelZoneLabel extends StatelessWidget {
  final GrammarLevel level;
  const _LevelZoneLabel({required this.level});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: level.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: level.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(level.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              level.fullLabel.toUpperCase(),
              style: SeedlingTypography.caption.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: level.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SHIMMER TITLE ────────────────────────────────────────────────────────────

class _ShimmerTitle extends StatefulWidget {
  final String text;
  const _ShimmerTitle(this.text);

  @override
  State<_ShimmerTitle> createState() => _ShimmerTitleState();
}

class _ShimmerTitleState extends State<_ShimmerTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: const [
            Color(0xFFF5F5DC),
            SeedlingColors.freshSprout,
            Color(0xFFF5F5DC),
          ],
          stops: [
            (_ctrl.value - 0.35).clamp(0.0, 1.0),
            _ctrl.value.clamp(0.0, 1.0),
            (_ctrl.value + 0.35).clamp(0.0, 1.0),
          ],
        ).createShader(bounds),
        child: Text(
          widget.text,
          style: SeedlingTypography.heading3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── LEVEL BADGE ──────────────────────────────────────────────────────────────

class _LevelBadge extends StatelessWidget {
  final GrammarLevel level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          level.color.withValues(alpha: 0.25),
          level.color.withValues(alpha: 0.08),
        ]),
        border: Border.all(color: level.color.withValues(alpha: 0.45), width: 1.8),
      ),
      child: Center(
        child: Text(level.emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

// ─── REVIEW BADGE ─────────────────────────────────────────────────────────────

class _ReviewBadge extends StatelessWidget {
  final int count;
  const _ReviewBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SeedlingColors.water.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: SeedlingColors.water.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_drop_rounded,
              color: SeedlingColors.water, size: 13),
          const SizedBox(width: 4),
          Text(
            '$count due',
            style: SeedlingTypography.caption.copyWith(
              color: SeedlingColors.water,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OVERALL MASTERY BAR ──────────────────────────────────────────────────────

class _OverallMasteryBar extends StatelessWidget {
  final double mastery;
  const _OverallMasteryBar({required this.mastery});

  @override
  Widget build(BuildContext context) {
    final pct = (mastery * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'OVERALL MASTERY',
              style: SeedlingTypography.caption.copyWith(
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: SeedlingColors.textSecondary,
              ),
            ),
            Text(
              '$pct%',
              style: SeedlingTypography.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: SeedlingColors.seedlingGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: SeedlingColors.cardBackground,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: mastery.clamp(0.0, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [
                      SeedlingColors.seedlingGreen,
                      SeedlingColors.sunlight,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          SeedlingColors.seedlingGreen.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
