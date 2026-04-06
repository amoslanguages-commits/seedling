import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/colors.dart';
import '../../../../core/typography.dart';
import '../../../../models/multiplayer.dart';
import '../../../../providers/multiplayer_provider.dart';
import '../../../../providers/app_providers.dart';
import '../../../../services/auth_service.dart';
import '../../../../database/database_helper.dart';
import 'live_chat_overlay.dart';
import 'live_exit_dialog.dart';
import 'memory_patch_screen.dart';
import '../../../../core/page_route.dart';

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
    final isHost = activeSession.participants.any(
      (p) =>
          (p.id == 'current_user' || p.id == 'host') &&
          p.role == PlayerRole.host,
    );

    // Sort players by score
    final sortedPlayers = List<LivePlayer>.from(activeSession.activePlayers)
      ..sort((a, b) => b.score.compareTo(a.score));

    final top3 = sortedPlayers.take(3).toList();
    final rest = sortedPlayers.skip(3).toList();

    // Determine my player to check win stats
    final myPlayer = activeSession.participants
        .where((p) => p.id == (AuthService().userId ?? 'current_user'))
        .firstOrNull;

    // Check if current user is the winner and increment stats once
    final winnerId = top3.isNotEmpty ? top3[0].id : null;
    final currentUserId = AuthService().userId;
    if (winnerId != null &&
        (winnerId == currentUserId || (top3[0].id == 'current_user'))) {
      // We use a future that runs once when the screen builds
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Basic de-duplication check: check if we just won a match in the last 10 seconds?
        // For now we assume this screen is only entered once per match completion.
        await DatabaseHelper().incrementChallengeWin();
        await DatabaseHelper().logActivity(
          type: 'competition_win',
          description: 'Victory in ${session.title}!',
          xp: 250,
        );

        // Refresh shared global stats and competition header
        ref.invalidate(userCompeteStatsProvider);
        ref.invalidate(userStatsProvider);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await LiveExitDialog.show(
          context,
          ref,
          activeSession,
          isHost,
        );
        if (shouldExit && context.mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: SeedlingColors.background,
        body: Stack(
          children: [
            // Premium Mesh Background
            Positioned.fill(child: _ResultMeshBackground()),

            // Victory Bloom Effects
            Positioned.fill(child: _VictoryBloomParticles()),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'TOURNAMENT COMPLETE',
                    style: SeedlingTypography.caption.copyWith(
                      letterSpacing: 3,
                      color: SeedlingColors.sunlight,
                    ),
                  ),
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
                            top3[1],
                            2,
                            160,
                            const Color(0xFFC0C0C0),
                          ),
                        const SizedBox(width: 10),
                        // 1st Place
                        if (top3.isNotEmpty)
                          _buildPodium(
                            top3[0],
                            1,
                            200,
                            const Color(0xFFFFD700),
                          ),
                        const SizedBox(width: 10),
                        // 3rd Place
                        if (top3.length > 2)
                          _buildPodium(
                            top3[2],
                            3,
                            130,
                            const Color(0xFFCD7F32),
                          ),
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
                              Text(
                                '#${index + 4}',
                                style: SeedlingTypography.heading3.copyWith(
                                  color: SeedlingColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                p.avatarEmoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  p.displayName,
                                  style: SeedlingTypography.body,
                                ),
                              ),
                              Text(
                                '${p.score} pts',
                                style: SeedlingTypography.heading3.copyWith(
                                  color: SeedlingColors.seedlingGreen,
                                ),
                              ),
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
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              'Play Next Match',
                              style: SeedlingTypography.heading3.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],
                        if (myPlayer != null &&
                            myPlayer.missedConceptIds.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                SeedlingPageRoute(
                                  page: MemoryPatchScreen(
                                    conceptIds: myPlayer.missedConceptIds,
                                    theme: session.theme,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.psychology_rounded,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Memory Patch (${myPlayer.missedConceptIds.length} missed)',
                              style: SeedlingTypography.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SeedlingColors.hibiscusRed
                                  .withValues(alpha: 0.8),
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
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
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SeedlingColors.deepRoot,
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            isHost ? 'End Games & Leave' : 'Leave Arena',
                            style: SeedlingTypography.heading3.copyWith(
                              color: Colors.white,
                            ),
                          ),
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
      duration: Duration(milliseconds: 1000 + (rank * 200)),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Winner Avatar with Glow
            Stack(
              alignment: Alignment.center,
              children: [
                if (rank == 1)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(seconds: 2),
                    builder: (context, v, _) => Container(
                      width: 70 + (sin(v * pi * 2) * 10),
                      height: 70 + (sin(v * pi * 2) * 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                Text(player.avatarEmoji, style: const TextStyle(fontSize: 48)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              player.displayName.toUpperCase(),
              style: SeedlingTypography.caption.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 100,
              height: value,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: color.withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Glassy Rank Glow
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        '$rank',
                        style: SeedlingTypography.heading1.copyWith(
                          color: color,
                          fontSize: 32,
                          shadows: [Shadow(color: color, blurRadius: 10)],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: Text(
                        '${player.score}',
                        textAlign: TextAlign.center,
                        style: SeedlingTypography.heading3.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResultMeshBackground extends StatefulWidget {
  @override
  State<_ResultMeshBackground> createState() => _ResultMeshBackgroundState();
}

class _ResultMeshBackgroundState extends State<_ResultMeshBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          children: [
            Positioned(
              top: -100 + (sin(t * pi * 2) * 50),
              left: -100 + (cos(t * pi * 2) * 50),
              child: _Orb(
                size: 500,
                color: SeedlingColors.water.withValues(alpha: 0.1),
              ),
            ),
            Positioned(
              bottom: -100 + (cos(t * pi * 2) * 50),
              right: -100 + (sin(t * pi * 2) * 50),
              child: _Orb(
                size: 600,
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.08),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _VictoryBloomParticles extends StatefulWidget {
  @override
  State<_VictoryBloomParticles> createState() => _VictoryBloomParticlesState();
}

class _VictoryBloomParticlesState extends State<_VictoryBloomParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Bloom> _blooms = List.generate(15, (i) => _Bloom());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(painter: _BloomPainter(_blooms, _controller.value));
      },
    );
  }
}

class _Bloom {
  late double x, y, size, speed, angle;
  late Color color;
  _Bloom() {
    x = Random().nextDouble();
    y = Random().nextDouble();
    size = Random().nextDouble() * 20 + 10;
    speed = Random().nextDouble() * 0.02 + 0.01;
    angle = Random().nextDouble() * pi * 2;
    color = [
      SeedlingColors.sunlight,
      SeedlingColors.seedlingGreen,
      SeedlingColors.water,
    ][Random().nextInt(3)].withValues(alpha: 0.3);
  }

  void update(double t) {
    y -= speed * 0.1;
    if (y < -0.1) y = 1.1;
    angle += 0.01;
  }
}

class _BloomPainter extends CustomPainter {
  final List<_Bloom> blooms;
  final double progress;
  _BloomPainter(this.blooms, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var bloom in blooms) {
      bloom.update(progress);
      paint.color = bloom.color;

      final centerX = bloom.x * size.width;
      final centerY = bloom.y * size.height;

      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(bloom.angle);

      // Draw a simple 4-petal flower/leaf
      for (int i = 0; i < 4; i++) {
        canvas.rotate(pi / 2);
        canvas.drawOval(
          Rect.fromLTWH(0, -bloom.size / 4, bloom.size, bloom.size / 2),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
