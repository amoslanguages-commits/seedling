import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../widgets/mascot.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Global Garden', style: SeedlingTypography.heading2),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SeedlingMascot(size: 100, state: MascotState.happy),
            SizedBox(height: 20),
            Text('Leaderboard rankings coming soon!'),
          ],
        ),
      ),
    );
  }
}

class DailyChallengesScreen extends StatelessWidget {
  const DailyChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Daily Challenges', style: SeedlingTypography.heading2),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: SeedlingColors.water),
            SizedBox(height: 20),
            Text('Complete challenges to grow faster!'),
          ],
        ),
      ),
    );
  }
}
