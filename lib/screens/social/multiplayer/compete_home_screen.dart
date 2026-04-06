import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twemoji/twemoji.dart';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../core/page_route.dart';
import '../../../models/multiplayer.dart';
import '../../../models/social.dart';
import '../../../models/taxonomy.dart';
import '../../../providers/multiplayer_provider.dart';
import '../../../providers/competition_provider.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/course_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/haptic_service.dart';
import '../live_duel_screen.dart';
import 'host_setup_screen.dart';
import 'multiplayer_lobby_screen.dart';
import '../../../models/course.dart';
import '../../../widgets/premium_gate.dart';
import '../../../services/usage_service.dart';

class CompeteHomeScreen extends ConsumerStatefulWidget {
  const CompeteHomeScreen({super.key});

  @override
  ConsumerState<CompeteHomeScreen> createState() => _CompeteHomeScreenState();
}

class _CompeteHomeScreenState extends ConsumerState<CompeteHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _countUpController;
  late AnimationController _floatController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countUpController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeGames = ref.watch(filteredGamesProvider);
    final currentTab = ref.watch(competeTabProvider);

    final statsAsync = ref.watch(userCompeteStatsProvider);
    final pendingAsync = ref.watch(pendingRequestsProvider);

    final stats = statsAsync.maybeWhen(
      data: (s) => s,
      orElse: CompetitionStats.empty,
    );
    final pendingCount = pendingAsync.maybeWhen(
      data: (p) => p.length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      floatingActionButton: _buildFAB(currentTab),
      body: Stack(
        children: [
          _buildBgMesh(),
          RefreshIndicator(
            color: SeedlingColors.freshSprout,
            backgroundColor: SeedlingColors.soil,
            onRefresh: () async {
              HapticService.mediumImpact();
              ref.invalidate(globalRankingsProvider);
              ref.invalidate(friendsProvider);
              ref.invalidate(pendingRequestsProvider);
              ref.invalidate(userProfileProvider);
              ref.invalidate(userCompeteStatsProvider);
              ref.invalidate(activeGamesProvider);
              await Future.delayed(
                const Duration(milliseconds: 800),
              ); // allow time for fresh data
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildHeader(stats),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Column(
                      children: [
                        _buildTabSwitcher(ref, currentTab, pendingCount),
                        const SizedBox(height: 24),
                        if (currentTab == CompeteTab.live)
                          _buildFilterStrip(ref, activeGames.length)
                        else if (currentTab == CompeteTab.leaderboard)
                          _buildLeaderboardHeader()
                        else
                          _buildFriendsHeader(ref),
                      ],
                    ),
                  ),
                ),
                if (currentTab == CompeteTab.live)
                  _buildLiveSliver(activeGames)
                else if (currentTab == CompeteTab.leaderboard)
                  _buildLeaderboardSliver()
                else
                  _buildFriendsSliver(),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // Sticky "You" Bar for Leaderboard
          if (currentTab == CompeteTab.leaderboard)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildStickyYouBar(ref, stats),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyYouBar(WidgetRef ref, CompetitionStats stats) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final displayName = profile?['display_name'] ?? 'You';
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      decoration: BoxDecoration(
        color: SeedlingColors.soil.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SeedlingColors.waterBlue.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: SeedlingColors.waterBlue.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildRankBadge(stats.globalPosition),
                const SizedBox(width: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: SeedlingColors.deepRoot,
                      child: Text(
                        initials,
                        style: SeedlingTypography.heading3.copyWith(
                          color: SeedlingColors.freshSprout,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: SeedlingColors.soil,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: SeedlingColors.water,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: SeedlingTypography.body.copyWith(
                          color: SeedlingColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${stats.totalXP} XP',
                        style: SeedlingTypography.caption.copyWith(
                          color: SeedlingColors.water,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: SeedlingColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── FAB ───────────────────────────────────────────────────────────────────

  Widget? _buildFAB(CompeteTab tab) {
    if (tab == CompeteTab.live) {
      return _shimmerFAB(
        icon: Icons.add_rounded,
        label: 'Create Room',

        onTap: () => Navigator.push(
          context,
          SeedlingPageRoute(page: const HostSetupScreen()),
        ),
      );
    }
    if (tab == CompeteTab.friends) {
      return _shimmerFAB(
        icon: Icons.person_add_rounded,
        label: 'Add Friend',
        onTap: () => _showAddFriendDialog(context, ref),
      );
    }
    return null;
  }

  Widget _shimmerFAB({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: const [
              SeedlingColors.seedlingGreen,
              SeedlingColors.freshSprout,
              SeedlingColors.seedlingGreen,
            ],
            stops: [0.0, _shimmerController.value, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.seedlingGreen.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticService.mediumImpact();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: SeedlingColors.deepRoot, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: SeedlingTypography.body.copyWith(
                      color: SeedlingColors.deepRoot,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── BACKGROUND MESH ───────────────────────────────────────────────────────

  Widget _buildBgMesh() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Stack(
        children: [
          Positioned(
            top: -100 + (math.sin(_pulseController.value * math.pi) * 20),
            right: -80 + (math.cos(_pulseController.value * math.pi) * 30),
            child: _orb(450, SeedlingColors.seedlingGreen, 0.15),
          ),
          Positioned(
            top: 150 + (math.cos(_pulseController.value * math.pi) * 40),
            left: -150 + (math.sin(_pulseController.value * math.pi) * 20),
            child: _orb(500, SeedlingColors.hibiscusRed, 0.06),
          ),
          Positioned(
            bottom: -50,
            left: 20,
            right: 20,
            child: _orb(300, SeedlingColors.deepRoot, 0.10),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          Colors.transparent,
        ],
      ),
    ),
  );

  // ─── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader(CompetitionStats stats) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned.fill(
              child: Opacity(opacity: 0.6, child: _buildBgMesh()),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _arenaStatusBadge(),
                            const SizedBox(height: 16),
                            _shimmerText('Language Progress'),
                          ],
                        ),

                        _rankBadge(stats.rank),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        _statCard(
                          'XP',
                          stats.totalXP.toString(),
                          Icons.star_rounded,
                          SeedlingColors.autumnGold,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          'Victory',
                          stats.winRate,
                          Icons.military_tech_rounded,
                          SeedlingColors.hibiscusRed,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          'Medals',
                          stats.medals.toString(),
                          Icons.stars_rounded,
                          SeedlingColors.water,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arenaStatusBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: SeedlingColors.seedlingGreen.withValues(alpha: 0.4),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.bolt_rounded,
          color: SeedlingColors.seedlingGreen,
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          'ROOMS: ACTIVE',
          style: SeedlingTypography.caption.copyWith(
            color: SeedlingColors.seedlingGreen,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );

  Widget _shimmerText(String text) => AnimatedBuilder(
    animation: _shimmerController,
    builder: (_, __) => ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: const [
          SeedlingColors.textPrimary,
          SeedlingColors.freshSprout,
          SeedlingColors.textPrimary,
        ],
        stops: [
          (_shimmerController.value - 0.3).clamp(0.0, 1.0),
          _shimmerController.value.clamp(0.0, 1.0),
          (_shimmerController.value + 0.3).clamp(0.0, 1.0),
        ],
      ).createShader(bounds),
      child: Text(
        text,
        style: SeedlingTypography.heading1.copyWith(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _rankBadge(String rank) => AnimatedBuilder(
    animation: _pulseController,
    builder: (_, __) {
      final pulse = math.sin(_pulseController.value * math.pi);
      return Container(
        width: 84,
        height: 84,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              SeedlingColors.autumnGold,
              SeedlingColors.autumnGold.withValues(alpha: 0.5),
              SeedlingColors.autumnGold,
            ],
            stops: [0.0, _pulseController.value, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.autumnGold.withValues(
                alpha: 0.3 + 0.2 * pulse,
              ),
              blurRadius: 15 + 10 * pulse,
              spreadRadius: 2 * pulse,
            ),
          ],
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: SeedlingColors.background,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                rank.split(' ').last.toUpperCase(),
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.autumnGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _statCard(String label, String value, IconData icon, Color accent) {
    final num = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
    final suffix = value.replaceAll(RegExp(r'[0-9.]'), '');
    return Expanded(
      child: AnimatedBuilder(
        animation: _countUpController,
        builder: (_, __) {
          final disp = num != null
              ? (num * _countUpController.value).toStringAsFixed(
                  num % 1 == 0 ? 0 : 1,
                )
              : value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              color: SeedlingColors.cardBackground.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accent.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (_, __) => ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        SeedlingColors.textPrimary,
                        accent,
                        SeedlingColors.textPrimary,
                      ],
                      stops: [
                        (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                        _shimmerController.value.clamp(0.0, 1.0),
                        (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      '$disp$suffix',
                      style: SeedlingTypography.heading3.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: SeedlingTypography.caption.copyWith(
                    fontSize: 8,
                    letterSpacing: 1.1,
                    color: SeedlingColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── TAB SWITCHER ──────────────────────────────────────────────────────────

  Widget _buildTabSwitcher(
    WidgetRef ref,
    CompeteTab current,
    int pendingCount,
  ) {
    final tabs = [
      (tab: CompeteTab.live, label: '⚔️  Live'),
      (tab: CompeteTab.leaderboard, label: '🌿  Ranks'),
      (tab: CompeteTab.friends, label: '👥  Friends'),
    ];
    final total = tabs.length;
    final w = (MediaQuery.of(context).size.width - 56) / total;
    final idx = tabs.indexWhere((t) => t.tab == current);

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SeedlingColors.morningDew.withValues(alpha: 0.15),
        ),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: idx * w,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    SeedlingColors.seedlingGreen,
                    SeedlingColors.freshSprout,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: tabs.map((t) {
              final isActive = t.tab == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticService.selectionClick();
                    ref.read(competeTabProvider.notifier).state = t.tab;
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: SeedlingTypography.body.copyWith(
                            color: isActive
                                ? SeedlingColors.deepRoot
                                : SeedlingColors.textSecondary,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          child: Text(t.label),
                        ),
                        if (t.tab == CompeteTab.friends && pendingCount > 0)
                          Positioned(
                            top: -6,
                            right: -14,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: SeedlingColors.hibiscusRed,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$pendingCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
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
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── LIVE ARENAS ───────────────────────────────────────────────────────────

  Widget _buildFilterStrip(WidgetRef ref, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Active Rooms', style: SeedlingTypography.heading3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count Live',
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.seedlingGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Course Filters (Flag based)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _filterChip(
                label: 'All Courses',
                isActive: ref.watch(gameCourseFilterProvider) == 'All',
                onTap: () =>
                    ref.read(gameCourseFilterProvider.notifier).state = 'All',
              ),
              ...ref.watch(courseProvider).courses.map((course) {
                final courseId =
                    '${course.nativeLanguage.code}_${course.targetLanguage.code}';
                final isActive =
                    ref.watch(gameCourseFilterProvider) == courseId;
                return _courseNavChip(course, isActive, () {
                  ref.read(gameCourseFilterProvider.notifier).state = courseId;
                });
              }),
              // Add New Course Shortcut
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () {
                    // Navigate to course selection, then return here
                    Navigator.pushReplacementNamed(
                      context,
                      '/course-management',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SeedlingColors.morningDew.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: SeedlingColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Mode Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              ...['All', 'Vocabulary', 'Sentences'].map(
                (m) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip(
                    label: m,
                    isActive: ref.watch(gameModeFilterProvider) == m,
                    onTap: () =>
                        ref.read(gameModeFilterProvider.notifier).state = m,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Theme Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _filterChip(
                label: 'All Themes',
                isActive: ref.watch(gameThemeFilterProvider) == 'All',
                onTap: () =>
                    ref.read(gameThemeFilterProvider.notifier).state = 'All',
              ),
              ...CategoryTaxonomy.getRootCategories().map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _filterChip(
                    label: cat.name,
                    isActive: ref.watch(gameThemeFilterProvider) == cat.name,
                    onTap: () =>
                        ref.read(gameThemeFilterProvider.notifier).state =
                            cat.name,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _courseNavChip(Course course, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticService.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? SeedlingColors.waterBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? SeedlingColors.waterBlue
                : SeedlingColors.morningDew.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Twemoji(emoji: course.nativeLanguage.flag, height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 10,
                color: SeedlingColors.textSecondary,
              ),
            ),
            Twemoji(emoji: course.targetLanguage.flag, height: 16),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticService.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    SeedlingColors.seedlingGreen.withValues(alpha: 0.25),
                    SeedlingColors.freshSprout.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? SeedlingColors.seedlingGreen
                : SeedlingColors.morningDew.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: SeedlingTypography.caption.copyWith(
            color: isActive
                ? SeedlingColors.seedlingGreen
                : SeedlingColors.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSliver(List<LiveGameSession> games) {
    final mySessionAsync = ref.watch(myActiveSessionProvider);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          mySessionAsync.maybeWhen(
            data: (session) => session != null
                ? _buildRejoinBanner(session)
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          ...games.asMap().entries.map(
            (e) => _staggeredSlide(e.key, _arenaCard(e.value)),
          ),
          if (games.isEmpty) _emptyLiveState(),
        ]),
      ),
    );
  }

  Widget _arenaCard(LiveGameSession game) {
    final isVocab = game.gameType == LiveGameType.vocabulary;
    final accent = isVocab
        ? SeedlingColors.seedlingGreen
        : SeedlingColors.water;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isVocab ? '🌸' : '🌳',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.title,
                              style: SeedlingTypography.heading2.copyWith(
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '${game.hostRankEmoji} ',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '${game.hostName} • ',
                                  style: SeedlingTypography.caption.copyWith(
                                    color: SeedlingColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  game.hostBotanicalRank,
                                  style: SeedlingTypography.caption.copyWith(
                                    color: SeedlingColors.seedlingGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    _liveIndicator(),
                  ],
                ),
                const SizedBox(height: 16),
                _playerSlots(game.playerCount, game.maxPlayers),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _infoTag(Icons.timer_outlined, '${game.timePerQuestion}s'),
                    const SizedBox(width: 8),
                    _infoTag(Icons.category_rounded, game.theme),
                    if (game.subtheme != 'All') ...[
                      const SizedBox(width: 8),
                      _infoTag(Icons.grid_view_rounded, game.subtheme),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _courseTag(game.languageCode, game.targetLanguageCode),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          HapticService.lightImpact();
                          ref
                              .read(activeSessionProvider.notifier)
                              .joinAsSpectator(game);
                          Navigator.push(
                            context,
                            SeedlingPageRoute(
                              page: MultiplayerLobbyScreen(session: game),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: SeedlingColors.morningDew.withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'SPECTATE',
                          style: SeedlingTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (_, __) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: const [
                                SeedlingColors.seedlingGreen,
                                SeedlingColors.freshSprout,
                                SeedlingColors.seedlingGreen,
                              ],
                              stops: [0.0, _shimmerController.value, 1.0],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final canJoin = await UsageService()
                                    .canJoinGame();
                                if (!canJoin) {
                                  if (context.mounted) {
                                    PremiumGateDialog.show(
                                      context,
                                      title: 'Daily Join Limit',
                                      message:
                                          'You\'ve joined 5 games today! Free users can join 5 games daily.',
                                      iconSymbol: '⚔️',
                                    );
                                  }
                                  return;
                                }
                                try {
                                  HapticService.mediumImpact();
                                  await ref
                                      .read(activeSessionProvider.notifier)
                                      .joinAsPlayer(game);
                                  if (!context.mounted) return;
                                  Navigator.push(
                                    context,
                                    SeedlingPageRoute(
                                      page: MultiplayerLobbyScreen(
                                        session: game,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  final errorStr = e.toString();
                                  if (errorStr.contains('PREMIUM_LIMIT_JOIN')) {
                                    PremiumGateDialog.show(
                                      context,
                                      title: 'Daily Join Limit',
                                      message:
                                          'You\'ve joined 5 games today! Free users can join 5 games daily.',
                                      iconSymbol: '⚔️',
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to join: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: Text(
                                    'JOIN CHALLENGE',
                                    style: SeedlingTypography.caption.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: SeedlingColors.deepRoot,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _staggeredSlide(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Interval(
        (index * 0.1).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  Widget _playerSlots(int filled, int total) => Row(
    children: [
      const Icon(
        Icons.people_rounded,
        size: 14,
        color: SeedlingColors.textSecondary,
      ),
      const SizedBox(width: 8),
      ...List.generate(
        total,
        (i) => Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < filled
                ? SeedlingColors.seedlingGreen
                : SeedlingColors.morningDew.withValues(alpha: 0.2),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        '$filled/$total',
        style: SeedlingTypography.caption.copyWith(
          color: SeedlingColors.textSecondary,
          fontSize: 11,
        ),
      ),
    ],
  );

  Widget _liveIndicator() => AnimatedBuilder(
    animation: _pulseController,
    builder: (_, __) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SeedlingColors.hibiscusRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: SeedlingColors.hibiscusRed.withValues(
            alpha: 0.3 + 0.4 * _pulseController.value,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: SeedlingColors.hibiscusRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SeedlingColors.hibiscusRed.withValues(
                    alpha: 0.6 * _pulseController.value,
                  ),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: SeedlingTypography.caption.copyWith(
              color: SeedlingColors.hibiscusRed,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _infoTag(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: SeedlingColors.background.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: SeedlingColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: SeedlingTypography.caption.copyWith(
            color: SeedlingColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );

  Widget _courseTag(String native, String target) {
    String getFlag(String langCode) {
      if (langCode == 'en') return '🇺🇸';
      if (langCode == 'es') return '🇪🇸';
      if (langCode == 'fr') return '🇫🇷';
      if (langCode == 'de') return '🇩🇪';
      if (langCode == 'it') return '🇮🇹';
      if (langCode == 'pt') return '🇧🇷';
      if (langCode == 'ja') return '🇯🇵';
      if (langCode == 'ko') return '🇰🇷';
      if (langCode == 'zh') return '🇨🇳';
      return '🏳️';
    }

    final nativeFlag = getFlag(native);
    final targetFlag = getFlag(target);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SeedlingColors.waterBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: SeedlingColors.waterBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Twemoji(emoji: nativeFlag, height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 8,
              color: SeedlingColors.textSecondary,
            ),
          ),
          Twemoji(emoji: targetFlag, height: 12),
        ],
      ),
    );
  }

  Widget _emptyLiveState() => Padding(
    padding: const EdgeInsets.only(top: 40, bottom: 20),
    child: Center(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) {
              final wave = _floatController.value;
              return SizedBox(
                height: 100,
                width: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            SeedlingColors.seedlingGreen.withValues(
                              alpha: 0.12,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10 + wave * 8,
                      child: const Text('🌙', style: TextStyle(fontSize: 40)),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 10 + (1 - wave) * 10,
                      child: const Text('🌿', style: TextStyle(fontSize: 22)),
                    ),
                    Positioned(
                      right: 20,
                      top: 20 + wave * 12,
                      child: const Text('✨', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('No active rooms...', style: SeedlingTypography.heading3),
          const SizedBox(height: 8),
          Text(
            'Be the first to create a room!',
            style: SeedlingTypography.caption.copyWith(
              color: SeedlingColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  // ─── LEADERBOARD ───────────────────────────────────────────────────────────

  Widget _buildLeaderboardHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('Top Players', style: SeedlingTypography.heading3),
      _WeeklyCountdown(),
    ],
  );

  Widget _buildLeaderboardSliver() {
    final rankAsync = ref.watch(globalRankingsProvider);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          rankAsync.when(
            data: (friends) {
              if (friends.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      'No global data yet. Complete a session to appear here!',
                      textAlign: TextAlign.center,
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }
              final top3 = friends.take(3).toList();
              final rest = friends.skip(3).toList();
              return Column(
                children: [
                  if (top3.length >= 3) _podium(top3),
                  if (top3.length >= 3) const SizedBox(height: 24),
                  ...rest.asMap().entries.map(
                    (e) => _staggeredSlide(
                      e.key,
                      _leaderboardRow(e.value, e.key + 4),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: CircularProgressIndicator(
                  color: SeedlingColors.seedlingGreen,
                ),
              ),
            ),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'Could not load rankings',
                  style: SeedlingTypography.body.copyWith(
                    color: SeedlingColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _podium(List<Friend> top3) {
    final order = [top3[1], top3[0], top3[2]];
    final heights = [80.0, 110.0, 65.0];
    final colors = [
      SeedlingColors.mistSilver,
      SeedlingColors.autumnGold,
      SeedlingColors.bronzeLeaf,
    ];
    final medals = ['🥈', '🥇', '🥉'];

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              SeedlingColors.cardBackground,
              SeedlingColors.cardBackground.withValues(alpha: 0.7),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: SeedlingColors.autumnGold.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.autumnGold.withValues(
                alpha: 0.08 + 0.05 * _pulseController.value,
              ),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '🏆 THIS WEEK\'S CHAMPIONS',
              style: SeedlingTypography.caption.copyWith(
                color: SeedlingColors.autumnGold,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(3, (i) {
                final e = order[i];
                final color = colors[i];
                final h = heights[i];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: SeedlingColors.background,
                          backgroundImage: e.avatarUrl != null
                              ? NetworkImage(e.avatarUrl!)
                              : null,
                          child: e.avatarUrl == null
                              ? Text(
                                  e.displayName[0].toUpperCase(),
                                  style: SeedlingTypography.heading3.copyWith(
                                    color: SeedlingColors.seedlingGreen,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(medals[i], style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          e.displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SeedlingTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${e.totalXP} XP',
                          style: SeedlingTypography.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.4),
                                color.withValues(alpha: 0.15),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '#${i == 1
                                  ? 1
                                  : i == 0
                                  ? 2
                                  : 3}',
                              style: SeedlingTypography.heading3.copyWith(
                                color: color,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Challenge button
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            SeedlingPageRoute(
                              page: LiveDuelScreen(opponent: e),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: color.withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '⚔️',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leaderboardRow(Friend e, int rank) {
    final currentUserId = ref.read(socialServiceProvider).currentUserId;
    final isMe = e.userId == currentUserId;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        SeedlingPageRoute(page: LiveDuelScreen(opponent: e)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isMe
              ? SeedlingColors.seedlingGreen.withValues(alpha: 0.1)
              : SeedlingColors.cardBackground.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe
                ? SeedlingColors.seedlingGreen.withValues(alpha: 0.3)
                : SeedlingColors.morningDew.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: SeedlingTypography.heading3.copyWith(
                  color: SeedlingColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 18,
              backgroundColor: SeedlingColors.morningDew,
              backgroundImage: e.avatarUrl != null
                  ? NetworkImage(e.avatarUrl!)
                  : null,
              child: e.avatarUrl == null
                  ? Text(
                      e.displayName[0].toUpperCase(),
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.seedlingGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isMe ? '${e.displayName} (You)' : e.displayName,
                style: SeedlingTypography.body.copyWith(
                  fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Text(
              '${e.totalXP} XP',
              style: SeedlingTypography.body.copyWith(
                color: SeedlingColors.seedlingGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SeedlingColors.waterBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('⚔️', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FRIENDS TAB ───────────────────────────────────────────────────────────

  Widget _buildFriendsHeader(WidgetRef ref) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('Your Squad', style: SeedlingTypography.heading3),
      GestureDetector(
        onTap: () {
          ref.invalidate(friendsProvider);
          ref.invalidate(pendingRequestsProvider);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: SeedlingColors.morningDew.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.refresh_rounded,
                size: 13,
                color: SeedlingColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text('Refresh', style: SeedlingTypography.caption),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildFriendsSliver() {
    final friendsAsync = ref.watch(friendsProvider);
    final pendingAsync = ref.watch(pendingRequestsProvider);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Pending requests section
          pendingAsync.maybeWhen(
            data: (pending) => pending.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: SeedlingColors.sunlight.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: SeedlingColors.sunlight.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          '${pending.length} pending request${pending.length > 1 ? 's' : ''}',
                          style: SeedlingTypography.caption.copyWith(
                            color: SeedlingColors.sunlight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...pending.map((f) => _pendingCard(f)),
                      const SizedBox(height: 20),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          // Friends list
          friendsAsync.when(
            data: (friends) {
              if (friends.isEmpty) {
                return _emptyFriendsState();
              }
              final sorted = List<Friend>.from(friends)
                ..sort((a, b) => b.totalXP.compareTo(a.totalXP));
              return Column(
                children: sorted
                    .asMap()
                    .entries
                    .map(
                      (e) => _staggeredSlide(
                        e.key,
                        _friendCompeteCard(e.value, e.key + 1),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: CircularProgressIndicator(
                  color: SeedlingColors.seedlingGreen,
                ),
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                'Could not load friends',
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pendingCard(Friend friend) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SeedlingColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SeedlingColors.sunlight.withValues(alpha: 0.5)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: SeedlingColors.morningDew,
          child: Text(
            friend.displayName[0].toUpperCase(),
            style: SeedlingTypography.heading3.copyWith(
              color: SeedlingColors.seedlingGreen,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                friend.displayName,
                style: SeedlingTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Wants to join your forest',
                style: SeedlingTypography.caption,
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.check_circle,
                color: SeedlingColors.success,
              ),
              onPressed: () {
                final container = ProviderScope.containerOf(context);
                final socialService = ref.read(socialServiceProvider);
                HapticService.mediumImpact();
                
                Future(() async {
                  await socialService.respondToRequest(friend.userId, true);
                  if (!mounted) return;
                  container.invalidate(friendsProvider);
                  container.invalidate(pendingRequestsProvider);
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: SeedlingColors.error),
              onPressed: () {
                final container = ProviderScope.containerOf(context);
                final socialService = ref.read(socialServiceProvider);
                HapticService.lightImpact();

                Future(() async {
                  await socialService.respondToRequest(friend.userId, false);
                  if (!mounted) return;
                  container.invalidate(pendingRequestsProvider);
                });
              },
            ),
          ],
        ),
      ],
    ),
  );

  Widget _friendCompeteCard(Friend friend, int rank) {
    Color rankColor = rank == 1
        ? SeedlingColors.autumnGold
        : rank == 2
        ? SeedlingColors.mistSilver
        : rank == 3
        ? SeedlingColors.bronzeLeaf
        : SeedlingColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: rank <= 3
            ? Border.all(color: rankColor.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: rank <= 3
            ? [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: SeedlingTypography.heading3.copyWith(
                color: rankColor,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: SeedlingColors.morningDew,
                backgroundImage: friend.avatarUrl != null
                    ? NetworkImage(friend.avatarUrl!)
                    : null,
                child: friend.avatarUrl == null
                    ? Text(
                        friend.displayName[0].toUpperCase(),
                        style: SeedlingTypography.heading3.copyWith(
                          color: SeedlingColors.seedlingGreen,
                        ),
                      )
                    : null,
              ),
              if (friend.isOnline)
                Positioned(right: 0, bottom: 0, child: _buildBreathingDot()),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 13,
                      color: SeedlingColors.sunlight,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${friend.currentStreak}d',
                      style: SeedlingTypography.caption,
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.star,
                      size: 13,
                      color: SeedlingColors.seedlingGreen,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${friend.totalXP} XP',
                      style: SeedlingTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticService.mediumImpact();
              Navigator.push(
                context,
                SeedlingPageRoute(page: LiveDuelScreen(opponent: friend)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SeedlingColors.waterBlue, SeedlingColors.water],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: SeedlingColors.waterBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                'DUEL',
                style: SeedlingTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingDot() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 14 + (_pulseController.value * 4),
              height: 14 + (_pulseController.value * 4),
              decoration: BoxDecoration(
                color: SeedlingColors.success.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: SeedlingColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: SeedlingColors.cardBackground,
                  width: 2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyFriendsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = math.sin(_pulseController.value * math.pi);
            return Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        SeedlingColors.seedlingGreen.withValues(
                          alpha: 0.15 + 0.1 * pulse,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(0, -pulse * 5),
                      child: const Text('👥', style: TextStyle(fontSize: 50)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('No companions yet', style: SeedlingTypography.heading3),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'The quickest way to learn is together. Add some friends!',
                    textAlign: TextAlign.center,
                    style: SeedlingTypography.body.copyWith(
                      color: SeedlingColors.textSecondary,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── ADD FRIEND DIALOG ─────────────────────────────────────────────────────

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: SeedlingColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Find a Forest Companion',
            style: SeedlingTypography.heading3,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  style: SeedlingTypography.body,
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: SeedlingColors.waterBlue,
                    ),
                    filled: true,
                    fillColor: SeedlingColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                if (ctrl.text.isNotEmpty)
                  FutureBuilder<List<Friend>>(
                    future: ref
                        .read(socialServiceProvider)
                        .searchUsers(ctrl.text),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(
                          color: SeedlingColors.seedlingGreen,
                        );
                      }
                      final results = snap.data ?? [];
                      if (results.isEmpty) {
                        return Text(
                          'No users found.',
                          style: SeedlingTypography.body.copyWith(
                            color: SeedlingColors.textSecondary,
                          ),
                        );
                      }
                      return Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final u = results[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: SeedlingColors.morningDew,
                                child: Text(
                                  u.displayName[0].toUpperCase(),
                                  style: SeedlingTypography.body.copyWith(
                                    color: SeedlingColors.seedlingGreen,
                                  ),
                                ),
                              ),
                              title: Text(
                                u.displayName,
                                style: SeedlingTypography.body,
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: SeedlingColors.seedlingGreen,
                                ),
                                onPressed: () {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final socialService = ref.read(socialServiceProvider);
                                  final nav = Navigator.of(ctx);

                                  Future(() async {
                                    await socialService.sendFriendRequest(u.userId);
                                    if (!ctx.mounted) return;
                                    nav.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Friend request sent! 🌱',
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejoinBanner(LiveGameSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SeedlingColors.water,
            SeedlingColors.water.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: SeedlingColors.waterBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _rejoinGame(session),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REJOIN ACTIVE BATTLE',
                        style: SeedlingTypography.heading3.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'You have a game in progress: ${session.title}',
                        style: SeedlingTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _rejoinGame(LiveGameSession session) {
    final navigator = Navigator.of(context);
    final notifier = ref.read(activeSessionProvider.notifier);

    Future(() async {
      await notifier.rejoinSession(session.id);
      if (!mounted) return;

      if (session.isDuel) {
        // Find the opponent (not me)
        final user = AuthService().currentUser;
        if (user == null) return;
        final opponent = session.participants.firstWhere(
          (p) => p.id != user.id,
          orElse: () => session.participants.first,
        );

        navigator.push(
          SeedlingPageRoute(
            page: LiveDuelScreen(
              opponent: Friend(
                userId: opponent.id,
                displayName: opponent.displayName,
                avatarUrl: null,
                currentStreak: 0,
                totalXP: 0,
                isOnline: true,
              ),
              sessionId: session.id,
            ),
          ),
        );
      } else {
        navigator.push(
          SeedlingPageRoute(page: MultiplayerLobbyScreen(session: session)),
        );
      }
    });
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SeedlingColors.seedlingGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        '#$rank',
        style: SeedlingTypography.caption.copyWith(
          color: SeedlingColors.seedlingGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── WEEKLY COUNTDOWN ──────────────────────────────────────────────────────

class _WeeklyCountdown extends StatefulWidget {
  @override
  State<_WeeklyCountdown> createState() => _WeeklyCountdownState();
}

class _WeeklyCountdownState extends State<_WeeklyCountdown> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _calculate();
  }

  Duration _calculate() {
    final now = DateTime.now();
    final days = (8 - now.weekday) % 7;
    final next = DateTime(
      now.year,
      now.month,
      now.day + (days == 0 ? 7 : days),
    );
    return next.difference(now);
  }

  @override
  Widget build(BuildContext context) {
    final d = _remaining.inDays;
    final h = _remaining.inHours % 24;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SeedlingColors.sunlight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: SeedlingColors.sunlight.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 12,
            color: SeedlingColors.sunlight,
          ),
          const SizedBox(width: 4),
          Text(
            d > 0 ? '${d}d ${h}h left' : '${h}h left',
            style: SeedlingTypography.caption.copyWith(
              color: SeedlingColors.sunlight,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
