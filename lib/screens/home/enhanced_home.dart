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
import '../../providers/course_provider.dart';

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
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: SeedlingColors.seedlingGreen,
          unselectedItemColor: Colors.grey,
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
  int _selectedTab = 0; // 0 = Topics, 1 = Word Types

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(userStatsProvider);
    final categoryStatsAsync = ref.watch(categoryStatsProvider);
    final posStatsAsync = ref.watch(posStatsProvider);

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
                        color: Colors.orange,
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

          // Mastery Highlight
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NEEDS WATERING', style: SeedlingTypography.caption),
                  const SizedBox(height: 12),
                  _buildMasteryCard(context, 'Eficiencia', 'Efficiency', 0.65),
                ],
              ),
            ),
          ),

          // ─── Pill Tab Bar ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _PillTabBar(
                labels: const ['Topics', 'Word Types'],
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
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.85,
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
            // WORD TYPES: POS cards in the same compact grid style
            posStatsAsync.when(
              data: (posStats) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildListDelegate(
                    _getPOSCards(context, posStats),
                  ),
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<Widget> _getPOSCards(BuildContext context, List<Map<String, dynamic>> posStats) {
    final activeCourse = ref.watch(courseProvider).activeCourse;
    final lang = activeCourse?.targetLanguage.code ?? 'es';

    return getApplicablePOS(lang).map((pos) {
      final stat = posStats.firstWhere(
        (s) => s['pos'] == pos.name,
        orElse: () => {'learned': 0, 'total': 0},
      );
      return _CategoryCard(
        title: pos.displayName,
        learnedCount: stat['learned'] as int,
        totalCount: stat['total'] as int,
        emojiIcon: pos.icon,
        color: pos.color.withValues(alpha: 0.18),
        iconColor: pos.color,
        compact: true,
        partOfSpeech: pos.name,
      );
    }).toList();
  }


  Widget _buildMasteryCard(BuildContext context, String word, String translation, double progress) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const LearningSessionScreen(),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SeedlingColors.seedlingGreen, SeedlingColors.water],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word, style: SeedlingTypography.heading3),
                  Text(translation, style: SeedlingTypography.body),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(SeedlingColors.water),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
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
        color: Colors.grey.shade100,
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
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: SeedlingTypography.body.copyWith(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? SeedlingColors.seedlingGreen : Colors.grey.shade500,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
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
  final String? partOfSpeech;

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
    this.partOfSpeech,
  }) : assert(emojiIcon != null || iconData != null, 'Provide emojiIcon or iconData');

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? color;
    final double emojiSize = compact ? 18 : 22;
    final double fontSize = compact ? 11 : 13;
    final double pad = compact ? 8 : 12;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LearningSessionScreen(
            categoryId: categoryId,
            partOfSpeech: partOfSpeech,
          )),
        );
      },
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(compact ? 16 : 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(compact ? 8 : 12),
              ),
              child: emojiIcon != null
                  ? Text(emojiIcon!, style: TextStyle(fontSize: emojiSize))
                  : Icon(iconData, color: resolvedIconColor, size: emojiSize),
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              title,
              style: SeedlingTypography.heading3.copyWith(fontSize: fontSize),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$learnedCount / $totalCount',
              style: SeedlingTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: SeedlingColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



