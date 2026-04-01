import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../models/multiplayer.dart';
import '../../../providers/multiplayer_provider.dart';
import 'live_chat_overlay.dart';
import 'live_exit_dialog.dart';

class QuizResultsScreen extends ConsumerWidget {
  final LiveGameSession session;

  const QuizResultsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for GameStatus.lobby, and jump everyone back!
    ref.listen(activeSessionProvider, (previous, next) {
      if (next?.status == GameStatus.lobby) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });

    final activeSession = ref.watch(activeSessionProvider) ?? session;
    final isHost = activeSession.participants.any((p) =>
        (p.id == 'current_user' || p.id == 'host') &&
        p.role == PlayerRole.host);

    // Sort players by score
    final sortedPlayers = List<LivePlayer>.from(activeSession.activePlayers)
      ..sort((a, b) => b.score.compareTo(a.score));

    final top3 = sortedPlayers.take(3).toList();
    final rest = sortedPlayers.skip(3).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit =
            await LiveExitDialog.show(context, ref, activeSession, isHost);
        if (shouldExit && context.mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: SeedlingColors.background,
        body: Stack(
          children: [
            // Background Celebration Effects
            Positioned.fill(
              child: CustomPaint(painter: _ConfettiPainter()),
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text('TOURNAMENT COMPLETE',
                      style: SeedlingTypography.caption.copyWith(
                          letterSpacing: 3, color: SeedlingColors.sunlight)),
                  const SizedBox(height: 10),
                  Text(session.title, style: SeedlingTypography.heading1),

                  const SizedBox(height: 50),

                  // Podium
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 2nd Place
                        if (top3.length > 1)
                          _buildPodium(
                              top3[1], 2, 160, const Color(0xFFC0C0C0)),
                        const SizedBox(width: 10),
                        // 1st Place
                        if (top3.isNotEmpty)
                          _buildPodium(
                              top3[0], 1, 200, const Color(0xFFFFD700)),
                        const SizedBox(width: 10),
                        // 3rd Place
                        if (top3.length > 2)
                          _buildPodium(
                              top3[2], 3, 130, const Color(0xFFCD7F32)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Rest of players
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: rest.length,
                      itemBuilder: (context, index) {
                        final p = rest[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: SeedlingColors.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Text('#${index + 4}',
                                  style: SeedlingTypography.heading3
                                      .copyWith(color: SeedlingColors.textSecondary)),
                              const SizedBox(width: 16),
                              Text(p.avatarEmoji,
                                  style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(p.displayName,
                                      style: SeedlingTypography.body)),
                              Text('${p.score} pts',
                                  style: SeedlingTypography.heading3.copyWith(
                                      color: SeedlingColors.seedlingGreen)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        if (isHost) ...[
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(activeSessionProvider.notifier)
                                  .resetToLobby();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SeedlingColors.water,
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text('Play Next Match',
                                style: SeedlingTypography.heading3
                                    .copyWith(color: Colors.white)),
                          ),
                          const SizedBox(height: 15),
                        ],
                        ElevatedButton(
                          onPressed: () {
                            if (isHost) {
                              ref
                                  .read(activeSessionProvider.notifier)
                                  .endGameForAll();
                            } else {
                              ref
                                  .read(activeSessionProvider.notifier)
                                  .leaveGame();
                            }
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SeedlingColors.deepRoot,
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text(isHost ? 'End Games & Leave' : 'Leave Arena',
                              style: SeedlingTypography.heading3
                                  .copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Chat Overlay
            const LiveChatOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(LivePlayer player, int rank, double height, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: height),
      duration: Duration(milliseconds: 800 + (rank * 200)),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(player.avatarEmoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(player.displayName,
                style: SeedlingTypography.caption
                    .copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: 90,
              height: value,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withOpacity(0.4)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, -5))
                  ]),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Text('$rank',
                      style: SeedlingTypography.heading1
                          .copyWith(color: Colors.white.withOpacity(0.9), fontSize: 36)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('${player.score}',
                        style: SeedlingTypography.caption
                            .copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    final colors = [
      SeedlingColors.sunlight,
      SeedlingColors.seedlingGreen,
      SeedlingColors.water
    ];

    for (int i = 0; i < 50; i++) {
      paint.color = colors[rand.nextInt(colors.length)].withOpacity(0.4);

      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height * 0.5; // Only top half
      final r = 4.0 + rand.nextDouble() * 6.0;

      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
