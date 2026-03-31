import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../learning.dart';
import '../social/competitions_screen.dart';
import '../../providers/app_providers.dart';
import '../profile_screen.dart';
import '../../models/taxonomy.dart';
import '../courses/active_course_banner.dart';
import '../sentence_session_screen.dart';
import '../../widgets/word_library_sheet.dart';

class EnhancedHomeScreen extends ConsumerStatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  ConsumerState<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends ConsumerState<EnhancedHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const _HomeTab(),
    const CompetitionsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.deepRoot.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: SeedlingColors.background,
          selectedItemColor: SeedlingColors.seedlingGreen,
          unselectedItemColor: SeedlingColors.textSecondary,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Grow'),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), activeIcon: Icon(Icons.emoji_events), label: 'Compete'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Roots'),
          ],
        ),
      ),
    );
  }
}


class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  int _selectedTab = 0; // 0 = Topics, 1 = Sentences

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(userStatsProvider);
    final categoryStatsAsync = ref.watch(categoryStatsProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header: active course + sync icon
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Expanded(child: ActiveCourseBanner()),
                ],
              ),
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
                        value: stats['currentStreak'].toString(),
                        icon: Icons.bolt,
                        color: SeedlingColors.sunlight,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatMiniCard(
                        label: 'Seeds',
                        value: stats['totalLearned'].toString(),
                        icon: Icons.grass,
                        color: SeedlingColors.seedlingGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: LinearProgressIndicator()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Smart Focus Hub
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: _SmartFocusHub(),
            ),
          ),

          // ─── Pill Tab Bar ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _PillTabBar(
                labels: const ['Vocabulary', 'Sentences'],
                selected: _selectedTab,
                onTap: (i) => setState(() => _selectedTab = i),
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                    loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                    error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
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
    );
  }

}

// ─── Smart Focus Hub ──────────────────────────────────────────────────────────

class _SmartFocusHub extends ConsumerStatefulWidget {
  const _SmartFocusHub();

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
          onTap: () => _handleTap(context, focus),
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
                    color: Colors.white.withValues(alpha: 0.15 + 0.08 * _pulseAnimation.value),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(config.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    switch (focus.mode) {
      case FocusMode.watering:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const LearningSessionScreen(),
        ));
        break;
      case FocusMode.resume:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LearningSessionScreen(
            domain: focus.lastDomain,
            subDomain: focus.lastSubDomain,
          ),
        ));
        break;
      case FocusMode.discover:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const LearningSessionScreen(),
        ));
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
                  color: isSelected ? SeedlingColors.seedlingGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [BoxShadow(color: SeedlingColors.deepRoot.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: SeedlingTypography.body.copyWith(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? SeedlingColors.background : SeedlingColors.textSecondary,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SeedlingColors.seedlingGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: SeedlingTypography.heading3.copyWith(fontSize: 18)),
              Text(label, style: SeedlingTypography.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
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
  }) : assert(emojiIcon != null || iconData != null, 'Provide emojiIcon or iconData');

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? color;
    final progress = totalCount > 0 ? learnedCount / totalCount : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LearningSessionScreen(
            categoryId: categoryId,
            domain: domain,
            subDomain: subDomain,
          )),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: resolvedIconColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: resolvedIconColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Emoji Vessel
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: resolvedIconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: emojiIcon != null 
                      ? Text(emojiIcon!, style: const TextStyle(fontSize: 22))
                      : Icon(iconData!, color: resolvedIconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: SeedlingTypography.heading3.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: resolvedIconColor.withValues(alpha: 0.08),
                                  valueColor: AlwaysStoppedAnimation<Color>(resolvedIconColor),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$learnedCount/$totalCount',
                              style: SeedlingTypography.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: SeedlingColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Space for review icon
                  const SizedBox(width: 24),
                ],
              ),
            ),
            // Review Trigger (floating in corner)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => WordLibraryBottomSheet(
                        title: title,
                        categoryId: categoryId,
                        domain: domain,
                        subDomain: subDomain,
                        themeColor: resolvedIconColor,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 16,
                      color: SeedlingColors.textSecondary.withValues(alpha: 0.6),
                    ),
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

class _SentencesTabContent extends StatelessWidget {
  const _SentencesTabContent();

  @override
  Widget build(BuildContext context) {
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
                color: SeedlingColors.sunlight.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '10 sample sentences loaded — a dedicated sentences library will be added soon.',
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style:
                            SeedlingTypography.heading3.copyWith(fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: SeedlingTypography.caption.copyWith(
                            fontSize: 9,
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: SeedlingTypography.body.copyWith(
                      color: SeedlingColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: accentColor.withValues(alpha: 0.7), size: 22),
          ],
        ),
      ),
    );
  }
}
