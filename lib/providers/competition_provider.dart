import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── COMPETE TAB ENUM ──────────────────────────────────────────────────────────

enum CompeteTab { live, leaderboard, friends }

final competeTabProvider = StateProvider<CompeteTab>((ref) => CompeteTab.live);

// ── COMPETITION STATS ─────────────────────────────────────────────────────────

class CompetitionStats {
  final String rank;
  final String winRate;
  final int medals;
  final int totalXP;
  final int globalPosition;

  const CompetitionStats({
    required this.rank,
    required this.winRate,
    required this.medals,
    required this.totalXP,
    required this.globalPosition,
  });

  /// XP-to-league name mapping
  static String rankFromXP(int xp) {
    if (xp >= 10000) return 'Forest Elder';
    if (xp >= 5000) return 'Sage';
    if (xp >= 2000) return 'Scout Knight';
    if (xp >= 800) return 'Sprout Knight';
    if (xp >= 200) return 'Seedling';
    return 'Sapling';
  }

  factory CompetitionStats.empty() {
    return const CompetitionStats(
      rank: 'Sapling',
      winRate: '—',
      medals: 0,
      totalXP: 0,
      globalPosition: 0,
    );
  }
}
