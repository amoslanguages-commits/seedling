import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/grammar_model.dart';
import '../../providers/grammar_provider.dart';
import '../../services/haptic_service.dart';
import 'grammar_drill_screen.dart';

class ConceptDetailScreen extends ConsumerStatefulWidget {
  final GrammarConcept concept;
  final ConceptProgress initialProgress;

  const ConceptDetailScreen({
    super.key,
    required this.concept,
    required this.initialProgress,
  });

  @override
  ConsumerState<ConceptDetailScreen> createState() =>
      _ConceptDetailScreenState();
}

class _ConceptDetailScreenState extends ConsumerState<ConceptDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  int _selectedCategory = 0; // 0 = Overview, 1 = Sentences, 2 = Drill
  final List<String> _tabs = ['Overview', 'Sentences', 'Drill'];

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentencesAsync =
        ref.watch(conceptSentencesProvider(widget.concept.conceptId));
    final progressAsync =
        ref.watch(conceptProgressProvider(widget.concept.conceptId));

    final progress = progressAsync.maybeWhen(
      data: (p) => p,
      orElse: () => widget.initialProgress,
    );

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Stack(
            children: [
              _buildBackground(),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(progress),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _buildTabBar(),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (_selectedCategory == 0)
                    _buildOverviewSliver(progress)
                  else if (_selectedCategory == 1)
                    sentencesAsync.when(
                      loading: () => const SliverToBoxAdapter(
                        child: Center(
                          child: CircularProgressIndicator(
                              color: SeedlingColors.seedlingGreen),
                        ),
                      ),
                      error: (e, _) => SliverToBoxAdapter(
                        child: Center(
                            child: Text('Error: $e',
                                style:
                                    const TextStyle(color: SeedlingColors.error))),
                      ),
                      data: (sentences) =>
                          _buildSentencesSliver(sentences, progress),
                    )
                  else
                    _buildDrillSliver(progress),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(progress),
    );
  }

  // ─── BACKGROUND ────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  widget.concept.level.glowColor
                      .withValues(alpha: 0.09 + 0.04 * _pulseController.value),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  SeedlingColors.seedlingGreen
                      .withValues(alpha: 0.05 + 0.03 * _pulseController.value),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SLIVER APP BAR ────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(ConceptProgress progress) {
    final levelColor = widget.concept.level.color;
    final state = progress.nodeState;

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 220,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: SeedlingColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Level color header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    levelColor.withValues(alpha: 0.18),
                    SeedlingColors.background,
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: levelColor.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.concept.level.emoji,
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 5),
                              Text(
                                widget.concept.level.fullLabel.toUpperCase(),
                                style: SeedlingTypography.caption.copyWith(
                                  fontSize: 9,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w900,
                                  color: levelColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // State badge
                        _buildStateBadge(state, levelColor),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Concept emoji + name
                    Row(
                      children: [
                        Text(widget.concept.emoji,
                            style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (_, __) => ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  SeedlingColors.textPrimary,
                                  levelColor,
                                  SeedlingColors.textPrimary,
                                ],
                                stops: [
                                  (_shimmerController.value - 0.3)
                                      .clamp(0.0, 1.0),
                                  _shimmerController.value.clamp(0.0, 1.0),
                                  (_shimmerController.value + 0.3)
                                      .clamp(0.0, 1.0),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                widget.concept.displayName,
                                style: SeedlingTypography.heading1.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Mastery bar
                    _buildMasteryRow(progress, levelColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBadge(ConceptNodeState state, Color levelColor) {
    String label;
    Color color;
    IconData icon;
    switch (state) {
      case ConceptNodeState.mastered:
        label = 'MASTERED';
        color = SeedlingColors.sunlight;
        icon = Icons.auto_awesome_rounded;
        break;
      case ConceptNodeState.inProgress:
        label = 'GROWING';
        color = SeedlingColors.seedlingGreen;
        icon = Icons.trending_up_rounded;
        break;
      case ConceptNodeState.available:
        label = 'READY';
        color = levelColor;
        icon = Icons.play_circle_outline_rounded;
        break;
      case ConceptNodeState.locked:
        label = 'LOCKED';
        color = SeedlingColors.textSecondary;
        icon = Icons.lock_outline_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: SeedlingTypography.caption.copyWith(
              fontSize: 9,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryRow(ConceptProgress progress, Color levelColor) {
    final pct = (progress.mastery * 100).toStringAsFixed(0);
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.mastery.clamp(0.0, 1.0),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [levelColor, SeedlingColors.sunlight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: levelColor.withValues(alpha: 0.4),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$pct%',
          style: SeedlingTypography.caption.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: levelColor,
          ),
        ),
      ],
    );
  }

  // ─── TAB BAR ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final isSelected = i == _selectedCategory;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticService.selectionClick();
                setState(() => _selectedCategory = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.concept.level.color.withValues(alpha: 0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                          color: widget.concept.level.color
                              .withValues(alpha: 0.40),
                          width: 1.2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _tabs[i],
                  style: SeedlingTypography.body.copyWith(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? widget.concept.level.color
                        : SeedlingColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── OVERVIEW ─────────────────────────────────────────────────────────────

  Widget _buildOverviewSliver(ConceptProgress progress) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Concept chapter info
          _InfoCard(
            icon: '🌱',
            title: 'What You\'ll Learn',
            body: _conceptDescription(widget.concept.conceptChapter),
            levelColor: widget.concept.level.color,
          ),
          const SizedBox(height: 12),
          // Stats row
          _buildStatsRow(progress),
          const SizedBox(height: 12),
          // How it works
          _InfoCard(
            icon: '⚡',
            title: 'How Growth Works',
            body:
                'Each concept contains sentences across 10 micro-categories (ca1–ca10). '
                'You grow through them one small step at a time. '
                'The FSRS memory engine schedules reviews at the perfect moment.',
            levelColor: widget.concept.level.color,
          ),
          const SizedBox(height: 12),
          // Connection note
          _InfoCard(
            icon: '🔗',
            title: 'Cross-Pollination',
            body:
                'Sentences you master here feed directly into your Sentence sessions. '
                'Your vocabulary and grammar grow together.',
            levelColor: widget.concept.level.color,
          ),
        ]),
      ),
    );
  }

  String _conceptDescription(String chapter) {
    // Human-readable explanation for each concept chapter type
    if (chapter.contains('greeting')) return 'How to greet people naturally in this language — formal, informal, and time-of-day variations.';
    if (chapter.contains('farewell')) return 'How to say goodbye gracefully — permanent farewells, temporary see-you-laters, and polite closings.';
    if (chapter.contains('thanks')) return 'Expressing gratitude at different levels of warmth and formality.';
    if (chapter.contains('yes_no')) return 'The basic building blocks of agreement and disagreement.';
    if (chapter.contains('identity')) return 'Introducing yourself and describing who you are.';
    if (chapter.contains('possess')) return 'How ownership and belonging are expressed — "my", "your", "his", "theirs".';
    if (chapter.contains('want')) return 'Expressing desires and wishes clearly and naturally.';
    if (chapter.contains('need')) return 'Expressing necessity — what you must have or must do.';
    if (chapter.contains('location')) return 'Where people and things are in relation to each other.';
    if (chapter.contains('description')) return 'Describing qualities, sizes, colors, and states of things and people.';
    if (chapter.contains('time')) return 'How language handles time — past, present, and future expressions.';
    if (chapter.contains('question')) return 'Forming questions to get the information you need.';
    if (chapter.contains('negat')) return 'Saying no, not, and nothing — the art of negation.';
    if (chapter.contains('habit')) return 'Things you do regularly, routinely, or repeatedly.';
    if (chapter.contains('ability')) return 'What you can, could, or are able to do.';
    if (chapter.contains('condition')) return 'If-then relationships — real and hypothetical.';
    if (chapter.contains('passive')) return 'When the focus is on what happened, not who did it.';
    if (chapter.contains('embed') || chapter.contains('clause')) return 'Building complex multi-part sentences with embedded information.';
    return 'Mastering the natural patterns of this concept in your target language.';
  }

  Widget _buildStatsRow(ConceptProgress progress) {
    final levelColor = widget.concept.level.color;
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'SENTENCES',
            value: '${progress.totalSentences}',
            icon: Icons.format_list_numbered_rounded,
            color: levelColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'COMPLETED',
            value: '${progress.completedSentences}',
            icon: Icons.check_circle_outline_rounded,
            color: SeedlingColors.seedlingGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'MASTERY',
            value: '${(progress.mastery * 100).toStringAsFixed(0)}%',
            icon: Icons.auto_awesome_rounded,
            color: SeedlingColors.sunlight,
          ),
        ),
      ],
    );
  }

  // ─── SENTENCES TAB ────────────────────────────────────────────────────────

  Widget _buildSentencesSliver(
      List<GrammarSentence> sentences, ConceptProgress progress) {
    if (sentences.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Text('🌱', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'No sentences yet',
                style: SeedlingTypography.heading3.copyWith(
                  color: SeedlingColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sentences for ${widget.concept.displayName} will appear\nhere once you add your CSV data.',
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group by category
    final grouped = <String, List<GrammarSentence>>{};
    for (final s in sentences) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }
    final categories = grouped.keys.toList()..sort();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final cat = categories[i];
            final catSentences = grouped[cat]!;
            return _CategorySection(
              category: cat,
              sentences: catSentences,
              levelColor: widget.concept.level.color,
            );
          },
          childCount: categories.length,
        ),
      ),
    );
  }

  // ─── DRILL TAB ────────────────────────────────────────────────────────────

  Widget _buildDrillSliver(ConceptProgress progress) {
    final levelColor = widget.concept.level.color;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Text(
            'Choose Your Drill',
            style: SeedlingTypography.heading3.copyWith(
              color: SeedlingColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Each mode targets a different growth dimension.',
            style: SeedlingTypography.body.copyWith(
              color: SeedlingColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          _DrillCard(
            icon: '🌱',
            title: 'Fill the Gap',
            subtitle: 'Complete a sentence with the missing word',
            difficulty: 1,
            levelColor: levelColor,
            onTap: () => _startDrill('fill_gap'),
          ),
          const SizedBox(height: 10),
          _DrillCard(
            icon: '🔄',
            title: 'Transform',
            subtitle: 'Convert the sentence to a different form',
            difficulty: 2,
            levelColor: levelColor,
            onTap: () => _startDrill('transform'),
          ),
          const SizedBox(height: 10),
          _DrillCard(
            icon: '🎯',
            title: 'Target Word',
            subtitle: 'Identify the key grammar element in context',
            difficulty: 2,
            levelColor: levelColor,
            onTap: () => _startDrill('target'),
          ),
          const SizedBox(height: 10),
          _DrillCard(
            icon: '🧠',
            title: 'Recall',
            subtitle: 'Reconstruct the sentence from memory',
            difficulty: 3,
            levelColor: levelColor,
            onTap: () => _startDrill('recall'),
          ),
        ]),
      ),
    );
  }

  void _startDrill(String mode) {
    HapticService.mediumImpact();
    final langCode = ref.read(grammarLangCodeProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GrammarDrillScreen(
          concept: widget.concept,
          mode: mode,
          langCode: langCode,
        ),
      ),
    );
  }

  // ─── BOTTOM BAR ───────────────────────────────────────────────────────────

  Widget _buildBottomBar(ConceptProgress progress) {
    final levelColor = widget.concept.level.color;
    final label = progress.nodeState == ConceptNodeState.mastered
        ? 'Review · Keep Fresh'
        : progress.nodeState == ConceptNodeState.inProgress
            ? 'Continue Growing'
            : 'Start Learning';
    final icon = progress.nodeState == ConceptNodeState.mastered
        ? Icons.refresh_rounded
        : Icons.play_arrow_rounded;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: SeedlingColors.background.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (_, __) => GestureDetector(
          onTap: () {
            HapticService.mediumImpact();
            setState(() => _selectedCategory = 2); // jump to Drill tab
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [levelColor, SeedlingColors.seedlingGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: levelColor.withValues(
                      alpha: 0.30 + 0.15 * _pulseController.value),
                  blurRadius: 18 + 8 * _pulseController.value,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: SeedlingColors.deepRoot, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: SeedlingColors.deepRoot,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── SUPPORTING WIDGETS ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final Color levelColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.levelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: levelColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                title,
                style: SeedlingTypography.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: SeedlingColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: SeedlingTypography.body.copyWith(
              color: SeedlingColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: SeedlingTypography.heading3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: SeedlingColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: SeedlingTypography.caption.copyWith(
              fontSize: 9,
              letterSpacing: 1.0,
              color: SeedlingColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<GrammarSentence> sentences;
  final Color levelColor;

  const _CategorySection({
    required this.category,
    required this.sentences,
    required this.levelColor,
  });

  @override
  Widget build(BuildContext context) {
    final catNum = category.replaceAll('ca', '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: levelColor.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Text(
                    catNum,
                    style: SeedlingTypography.caption.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: levelColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _catLabel(category),
                style: SeedlingTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...sentences.map((s) => _SentenceRow(sentence: s, levelColor: levelColor)),
        ],
      ),
    );
  }

  String _catLabel(String cat) {
    const labels = {
      'ca1': 'Seed Sentences',
      'ca2': 'First Growth',
      'ca3': 'Wider Reach',
      'ca4': 'Question Forms',
      'ca5': 'Negation',
      'ca6': 'Past Time',
      'ca7': 'Future Time',
      'ca8': 'Modifier Growth',
      'ca9': 'Quantity',
      'ca10': 'Review Mix',
    };
    return labels[cat] ?? cat.toUpperCase();
  }
}

class _SentenceRow extends StatelessWidget {
  final GrammarSentence sentence;
  final Color levelColor;

  const _SentenceRow({required this.sentence, required this.levelColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SeedlingColors.seedlingGreen.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sentence.sentence,
            style: SeedlingTypography.body.copyWith(
              color: SeedlingColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (sentence.sentencePronunciation != null) ...[
            const SizedBox(height: 4),
            Text(
              sentence.sentencePronunciation!,
              style: SeedlingTypography.body.copyWith(
                color: SeedlingColors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (sentence.notes != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 12, color: levelColor.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    sentence.notes!,
                    style: SeedlingTypography.caption.copyWith(
                      color: levelColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DrillCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final int difficulty; // 1–3
  final Color levelColor;
  final VoidCallback onTap;

  const _DrillCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.difficulty,
    required this.levelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: levelColor.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SeedlingTypography.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: SeedlingColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Difficulty dots
            Column(
              children: List.generate(
                3,
                (i) => Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < difficulty
                        ? levelColor
                        : SeedlingColors.cardBackground.withValues(alpha: 0.6),
                    border: Border.all(
                        color: levelColor.withValues(alpha: 0.4), width: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
