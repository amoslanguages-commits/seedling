import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../learning.dart';
import '../review/smart_review_screen.dart';
import '../../providers/app_providers.dart';
import '../profile_screen.dart';
import '../../models/taxonomy.dart';
import '../courses/active_course_banner.dart';
import '../sentence_session_screen.dart';
import '../../widgets/word_library_sheet.dart';
import '../../services/haptic_service.dart';

class EnhancedHomeScreen extends ConsumerStatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  ConsumerState<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends ConsumerState<EnhancedHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const _HomeTab(),
    const SmartReviewScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      // #1 — Material 3 NavigationBar with animated pill indicator
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          HapticService.selectionClick();
          setState(() => _selectedIndex = index);
        },
        backgroundColor: SeedlingColors.background,
        indicatorColor: SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        shadowColor: SeedlingColors.deepRoot.withValues(alpha: 0.2),
        elevation: 8,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: SeedlingColors.seedlingGreen),
            label: 'Grow',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_motion_outlined),
            selectedIcon: Icon(Icons.auto_awesome_motion, color: SeedlingColors.seedlingGreen),
            label: 'Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: SeedlingColors.seedlingGreen),
            label: 'Roots',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

// #8 — _HomeTabState gains staggered entrance animations
class _HomeTabState extends ConsumerState<_HomeTab>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0 = Topics, 1 = Sentences
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(userStatsProvider);
    final categoryStatsAsync = ref.watch(categoryStatsProvider);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header: active course + sync icon
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(children: [Expanded(child: ActiveCourseBanner())]),
            ),
          ),

          // Daily Stats
          statsAsync.when(
            data: (stats) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatMiniCard(
                        label: 'Streak',
                        value: '${stats['currentStreak']} Days',
                        icon: Icons.bolt,
                        color: SeedlingColors.sunlight,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatMiniCard(
                        label: 'Daily Progress',
                        value:
                            '${stats['dailyProgress']}/${stats['dailyGoal']}',
                        icon: Icons.grass,
                        color: SeedlingColors.seedlingGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // #2 — Shimmer skeleton replaces raw LinearProgressIndicator
            loading: () => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(child: _ShimmerStatCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _ShimmerStatCard()),
                  ],
                ),
              ),
            ),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Smart Focus Hub
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _SmartFocusHub(tabIndex: _selectedTab),
            ),
          ),

          // ─── Pill Tab Bar ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _PillTabBar(
                labels: const ['Vocabulary', 'Sentences'],
                selected: _selectedTab,
                onTap: (i) {
                  HapticService.selectionClick();
                  setState(() => _selectedTab = i);
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ─── Tab Content ──────────────────────────────────────────
          if (_selectedTab == 0) ...[
            // TOPICS: grouped by root category
            ...CategoryTaxonomy.getRootCategories().expand((root) {
              final subs = CategoryTaxonomy.getSubCategories(root.id);
              if (subs.isEmpty) return <Widget>[];
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                    child: Row(
                      children: [
                        Text(root.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 7),
                        Text(
                          root.name.toUpperCase(),
                          style: SeedlingTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  sliver: categoryStatsAsync.when(
                    data: (catStats) => SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2.1,
                          ),
                      delegate: SliverChildListDelegate(
                        subs.map((cat) {
                          final stat = catStats.firstWhere(
                            (s) => s['category'] == cat.id,
                            orElse: () => {'learned': 0, 'total': 0},
                          );
                          return _CategoryCard(
                            title: cat.name,
                            learnedCount: stat['learned'] as int,
                            totalCount: stat['total'] as int,
                            emojiIcon: cat.icon,
                            color: cat.color.withValues(alpha: 0.18),
                            iconColor: cat.color,
                            compact: true,
                            categoryId: cat.id,
                            domain: root.id,
                            subDomain: cat.id,
                          );
                        }).toList(),
                      ),
                    ),
                    loading: () => const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),
                ),
              ];
            }),
          ] else ...[
            // SENTENCES: mode-selection cards
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: _SentencesTabContent(),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    ),
      ),
    );
  }
}

// ─── Smart Focus Hub ──────────────────────────────────────────────────────────

class _SmartFocusHub extends ConsumerStatefulWidget {
  final int tabIndex;
  const _SmartFocusHub({required this.tabIndex});

  @override
  ConsumerState<_SmartFocusHub> createState() => _SmartFocusHubState();
}

class _SmartFocusHubState extends ConsumerState<_SmartFocusHub>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusAsync = ref.watch(smartFocusProvider);

    return focusAsync.when(
      loading: () => _buildShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (focus) => _buildHub(context, focus),
    );
  }

  Widget _buildShimmer() {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _buildHub(BuildContext context, FocusState focus) {
    final config = _getConfig(focus);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            HapticService.mediumImpact();
            _handleTap(context, focus);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: config.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: config.glowColor.withValues(
                    alpha: 0.25 + 0.15 * _pulseAnimation.value,
                  ),
                  blurRadius: 20 + 10 * _pulseAnimation.value,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing icon vessel
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.15 + 0.08 * _pulseAnimation.value,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    config.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          config.badge,
                          style: SeedlingTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        config.title,
                        style: SeedlingTypography.heading3.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.subtitle,
                        style: SeedlingTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _HubConfig _getConfig(FocusState focus) {
    if (widget.tabIndex == 1) {
      return const _HubConfig(
        gradientColors: [Color(0xFF2C5282), Color(0xFF4299E1)],
        glowColor: Color(0xFF2C5282),
        emoji: '🌳',
        badge: 'SENTENCE SPRINT',
        title: 'Master Your Grammar',
        subtitle: 'Build complex sentences now',
      );
    }

    switch (focus.mode) {
      case FocusMode.watering:
        return _HubConfig(
          gradientColors: [const Color(0xFF1A7FBD), const Color(0xFF0D9488)],
          glowColor: const Color(0xFF1A7FBD),
          emoji: '💧',
          badge: 'REVIEW DUE',
          title: '${focus.dueCount} Plants Need Watering',
          subtitle: 'Keep your garden healthy — review now',
        );
      case FocusMode.resume:
        return _HubConfig(
          gradientColors: [const Color(0xFF2D7A3A), const Color(0xFF4CAF75)],
          glowColor: const Color(0xFF2D7A3A),
          emoji: '🌿',
          badge: 'CONTINUE',
          title: 'Resume: ${focus.displayName ?? "Your Garden"}',
          subtitle: 'Pick up right where you left off',
        );
      case FocusMode.discover:
        return _HubConfig(
          gradientColors: [const Color(0xFF6B3FA0), const Color(0xFF9B59B6)],
          glowColor: const Color(0xFF6B3FA0),
          emoji: '🌱',
          badge: 'START GROWING',
          title: 'Plant: ${focus.displayName ?? "New Words"}',
          subtitle: 'Your learning journey begins here',
        );
    }
  }

  void _handleTap(BuildContext context, FocusState focus) {
    if (widget.tabIndex == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const SentenceSessionScreen(mode: SentenceQuizMode.fillBranch),
        ),
      );
      return;
    }

    switch (focus.mode) {
      case FocusMode.watering:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LearningSessionScreen()),
        );
        break;
      case FocusMode.resume:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LearningSessionScreen(
              domain: focus.lastDomain,
              subDomain: focus.lastSubDomain,
            ),
          ),
        );
        break;
      case FocusMode.discover:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LearningSessionScreen(
              domain: focus.lastDomain,
              subDomain: focus.lastSubDomain,
            ),
          ),
        );
        break;
    }
  }
}

class _HubConfig {
  final List<Color> gradientColors;
  final Color glowColor;
  final String emoji;
  final String badge;
  final String title;
  final String subtitle;

  const _HubConfig({
    required this.gradientColors,
    required this.glowColor,
    required this.emoji,
    required this.badge,
    required this.title,
    required this.subtitle,
  });
}

// ─── Pill Tab Bar ─────────────────────────────────────────────────────────────

class _PillTabBar extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;

  const _PillTabBar({
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSelected
                      ? SeedlingColors.seedlingGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: SeedlingColors.deepRoot.withValues(
                              alpha: 0.2,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: SeedlingTypography.body.copyWith(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? SeedlingColors.background
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
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SeedlingColors.cardBackground,
            SeedlingColors.cardBackground.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: SeedlingTypography.heading3.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: SeedlingTypography.caption.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: SeedlingColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// #3 — StatefulWidget so we can track press state for scale animation
class _CategoryCard extends StatefulWidget {
  final String title;
  final int learnedCount;
  final int totalCount;
  final Color color;
  final Color? iconColor;
  final String? emojiIcon;
  final IconData? iconData;
  final bool compact;
  final String? categoryId;
  final String? domain;
  final String? subDomain;

  const _CategoryCard({
    required this.title,
    required this.learnedCount,
    required this.totalCount,
    required this.color,
    this.emojiIcon,
    this.iconData,
    this.iconColor,
    this.compact = false,
    this.categoryId,
    this.domain,
    this.subDomain,
  }) : assert(
         emojiIcon != null || iconData != null,
         'Provide emojiIcon or iconData',
       );

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    final resolvedIconColor = widget.iconColor ?? widget.color;
    final progress = widget.totalCount > 0 ? widget.learnedCount / widget.totalCount : 0.0;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) async {
        await _pressController.reverse();
        if (!context.mounted) return;
        HapticService.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LearningSessionScreen(
              categoryId: widget.categoryId,
              domain: widget.domain,
              subDomain: widget.subDomain,
            ),
          ),
        );
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              resolvedIconColor.withValues(alpha: 0.12),
              SeedlingColors.cardBackground,
              SeedlingColors.cardBackground.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: resolvedIconColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: resolvedIconColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Decorative background emoji
            Positioned(
              right: -12,
              bottom: -12,
              child: Opacity(
                opacity: 0.06,
                child: Text(
                  widget.emojiIcon ?? '🌿',
                  style: const TextStyle(fontSize: 84),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  // Emoji Vessel
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          resolvedIconColor.withValues(alpha: 0.25),
                          resolvedIconColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: resolvedIconColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: widget.emojiIcon != null
                        ? Text(widget.emojiIcon!, style: const TextStyle(fontSize: 24))
                        : Icon(widget.iconData!, color: resolvedIconColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: SeedlingTypography.heading3.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: SeedlingColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  // Background Track
                                  Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: resolvedIconColor.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  // Dynamic Progress
                                  FractionallySizedBox(
                                    widthFactor: progress.clamp(0.05, 1.0),
                                    child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            resolvedIconColor,
                                            resolvedIconColor.withValues(
                                              alpha: 0.7,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: resolvedIconColor.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
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
                              '${widget.learnedCount}/${widget.totalCount}',
                              style: SeedlingTypography.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: SeedlingColors.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            // Review Trigger (floating in corner)
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticService.selectionClick();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => WordLibraryBottomSheet(
                        title: widget.title,
                        categoryId: widget.categoryId,
                        domain: widget.domain,
                        subDomain: widget.subDomain,
                        themeColor: resolvedIconColor,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 14,
                        color: SeedlingColors.textSecondary.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SentencesTabContent extends ConsumerWidget {
  const _SentencesTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsProvider).value;
    final sentencesToday = stats?['sentencesToday'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          'SENTENCE GARDEN',
          style: SeedlingTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Practice words in real context',
          style: SeedlingTypography.body.copyWith(
            color: SeedlingColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        _SentenceModeCard(
          emoji: '🌿',
          title: 'Fill The Branch',
          subtitle: 'Complete the missing word in a sentence',
          accentColor: SeedlingColors.seedlingGreen,
          tag: 'CLOZE',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SentenceSessionScreen(
                mode: SentenceQuizMode.fillBranch,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SentenceModeCard(
          emoji: '🌳',
          title: 'Translation Sprint',
          subtitle: 'What does the highlighted word mean?',
          accentColor: SeedlingColors.water,
          tag: 'TRANSLATE',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SentenceSessionScreen(
                mode: SentenceQuizMode.translateSprint,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SeedlingColors.sunlight.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have completed $sentencesToday sentences today. Keep growing your context knowledge!',
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SentenceModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final String tag;
  final VoidCallback onTap;

  const _SentenceModeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticService.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.1),
              SeedlingColors.cardBackground,
              SeedlingColors.cardBackground.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Decorative background emoji
            Positioned(
              right: -15,
              bottom: -15,
              child: Opacity(
                opacity: 0.05,
                child: Text(emoji, style: const TextStyle(fontSize: 100)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Icon Vessel
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accentColor.withValues(alpha: 0.25),
                          accentColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: SeedlingTypography.heading3.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                  color: SeedlingColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Badge(label: tag, color: accentColor),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: SeedlingTypography.body.copyWith(
                            color: SeedlingColors.textSecondary.withValues(
                              alpha: 0.85,
                            ),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: SeedlingColors.textSecondary.withValues(alpha: 0.4),
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: SeedlingTypography.caption.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// #2 — Shimmer skeleton widget for stat cards
class _ShimmerStatCard extends StatefulWidget {
  @override
  State<_ShimmerStatCard> createState() => _ShimmerStatCardState();
}

class _ShimmerStatCardState extends State<_ShimmerStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _colorAnim = ColorTween(
      begin: SeedlingColors.cardBackground.withValues(alpha: 0.5),
      end: SeedlingColors.deepRoot.withValues(alpha: 0.1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _colorAnim.value,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SeedlingColors.textSecondary.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
