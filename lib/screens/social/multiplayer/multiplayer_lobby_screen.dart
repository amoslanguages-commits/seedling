import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/page_route.dart';
import '../../../services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../models/multiplayer.dart';
import '../../../providers/multiplayer_provider.dart';
import 'live_countdown_screen.dart';
import 'live_chat_overlay.dart';
import 'live_exit_dialog.dart';

class MultiplayerLobbyScreen extends ConsumerStatefulWidget {
  final LiveGameSession session;

  const MultiplayerLobbyScreen({super.key, required this.session});

  @override
  ConsumerState<MultiplayerLobbyScreen> createState() =>
      _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends ConsumerState<MultiplayerLobbyScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late List<_Spore> _spores;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _spores = List.generate(15, (i) => _Spore());

    // Set up pulse listener for spectators
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeSessionProvider.notifier).onPulseReceived = (type) {
        _showPulse(type);
      };
    });
  }

  final List<_ActivePulse> _activePulses = [];

  void _showPulse(String type) {
    if (!mounted) return;
    setState(() {
      _activePulses.add(
        _ActivePulse(
          type: type,
          startTime: DateTime.now(),
          position: Offset(
            20 +
                math.Random().nextDouble() *
                    (MediaQuery.of(context).size.width - 40),
            MediaQuery.of(context).size.height * 0.4 +
                math.Random().nextDouble() * 200,
          ),
        ),
      );
    });

    // Remove pulse after animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _activePulses.removeWhere(
            (p) => DateTime.now().difference(p.startTime).inSeconds >= 3,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch active session for real-time updates
    final activeSession = ref.watch(activeSessionProvider) ?? widget.session;

    final myPlayer = activeSession.participants
        .where((p) => p.id == AuthService().userId)
        .firstOrNull;
    final isHost = myPlayer?.role == PlayerRole.host;
    final isSpectator = myPlayer?.role == PlayerRole.spectator;

    ref.listen<LiveGameSession?>(activeSessionProvider, (previous, next) {
      if (next == null) return;
      if (next.status == GameStatus.starting) {
        Navigator.pushReplacement(
          context,
          SeedlingPageRoute(page: LiveCountdownScreen(session: next)),
        );
      } else if (next.status == GameStatus.terminated) {
        _showTerminatedDialog(context);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldExit = await LiveExitDialog.show(
          context,
          ref,
          activeSession,
          isHost,
        );
        if (shouldExit && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildAnimatedBackground(),
            _buildSporeParticles(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, ref, activeSession, isHost),
                  const SizedBox(height: 16),
                  _buildArenaCard(activeSession),
                  const SizedBox(height: 32),
                  _buildSectionHeader(activeSession),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: activeSession.maxPlayers,
                      itemBuilder: (context, index) {
                        final player =
                            index < activeSession.activePlayers.length
                            ? activeSession.activePlayers[index]
                            : null;
                        return _buildPlayerCard(player, index);
                      },
                    ),
                  ),
                  _buildSpectatorArea(ref, activeSession, isHost),

                  // NEW: Friends Invite Area
                  if (isHost &&
                      activeSession.activePlayers.length <
                          activeSession.maxPlayers)
                    _buildFriendsInviteArea(ref),

                  _buildActionBar(
                    ref,
                    context,
                    activeSession,
                    isHost,
                    isSpectator,
                    myPlayer,
                  ),
                ],
              ),
            ),

            // Pulse Overlay for spectators
            ..._activePulses.map((p) => _PulseOverlay(pulse: p)),

            const LiveChatOverlay(),
          ],
        ),
      ),
    );
  }

  void _showTerminatedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: SeedlingColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text('Session Closed', style: SeedlingTypography.heading2),
          content: Text(
            'The host has terminated this session. You will be returned to the garden.',
            style: SeedlingTypography.body.copyWith(
              color: SeedlingColors.textSecondary,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Exit lobby
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SeedlingColors.seedlingGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Back to Home',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final t = _bgController.value;
        final theme = widget.session.theme.toLowerCase();

        Color orb1 = SeedlingColors.deepRoot.withValues(alpha: 0.18);
        Color orb2 = SeedlingColors.autumnGold.withValues(alpha: 0.1);
        Color orb3 = SeedlingColors.water.withValues(alpha: 0.14);

        if (theme.contains('food')) {
          orb1 = Colors.orange.withValues(alpha: 0.15);
          orb2 = Colors.yellow.withValues(alpha: 0.1);
          orb3 = Colors.deepOrange.withValues(alpha: 0.1);
        } else if (theme.contains('travel') || theme.contains('nature')) {
          orb1 = Colors.lightBlue.withValues(alpha: 0.15);
          orb2 = Colors.teal.withValues(alpha: 0.1);
          orb3 = Colors.white.withValues(alpha: 0.1);
        } else if (theme.contains('verb') || theme.contains('action')) {
          orb1 = Colors.purple.withValues(alpha: 0.15);
          orb2 = Colors.pinkAccent.withValues(alpha: 0.1);
          orb3 = Colors.blueAccent.withValues(alpha: 0.1);
        }

        return Stack(
          children: [
            // Orb 1: Deep - Moves in a wide oval
            Positioned(
              top: -150 + (math.sin(t * math.pi * 2) * 100),
              left: -150 + (math.cos(t * math.pi * 2) * 80),
              child: _Orb(size: 500, color: orb1),
            ),
            // Orb 2: Secondary - Moves in a counter-oval
            Positioned(
              bottom: -100 + (math.cos(t * math.pi * 2 + 0.5) * 120),
              right: -150 + (math.sin(t * math.pi * 2 + 0.5) * 100),
              child: _Orb(size: 600, color: orb2),
            ),
            // Orb 3: Shimmer - Faster central float
            Positioned(
              top:
                  MediaQuery.of(context).size.height * 0.3 +
                  (math.sin(t * math.pi * 4) * 40),
              right: -50 + (math.cos(t * math.pi * 2) * 60),
              child: _Orb(size: 400, color: orb3),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSporeParticles() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _SporePainter(_spores, _particleController.value),
        );
      },
    );
  }

  Widget _buildSectionHeader(LiveGameSession session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLAYERS IN ROOM',
                style: SeedlingTypography.caption.copyWith(
                  color: Colors.white70,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 2,
                width: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [SeedlingColors.seedlingGreen, Colors.transparent],
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SeedlingColors.autumnGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: SeedlingColors.autumnGold.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '${session.playerCount}/${session.maxPlayers}',
              style: SeedlingTypography.body.copyWith(
                color: SeedlingColors.autumnGold,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(LivePlayer? player, int index) {
    final isOccupied = player != null;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = _pulseController.value;

          return Container(
            decoration: BoxDecoration(
              color: isOccupied
                  ? SeedlingColors.seedlingGreen.withValues(
                      alpha: 0.06 + (pulse * 0.04),
                    )
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isOccupied
                    ? SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.2 + (pulse * 0.4),
                      )
                    : Colors.white.withValues(alpha: 0.03 + (pulse * 0.05)),
                width: isOccupied ? 2.5 : 1,
              ),
              boxShadow: isOccupied
                  ? [
                      BoxShadow(
                        color: SeedlingColors.seedlingGreen.withValues(
                          alpha: 0.15 * pulse,
                        ),
                        blurRadius: 20 * pulse,
                        spreadRadius: -2,
                      ),
                    ]
                  : [
                      // Heartbeat glow for empty slot
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.02 * pulse),
                        blurRadius: 10 * pulse,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar Bloom
                      _buildAvatarBloom(player, pulse),
                      const SizedBox(height: 8),

                      // Rank Badge
                      if (isOccupied) _buildRankBadge(player),

                      Text(
                        isOccupied ? player.displayName : 'AWAITING...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SeedlingTypography.body.copyWith(
                          color: isOccupied ? Colors.white : Colors.white24,
                          fontWeight: isOccupied
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),

                      if (isOccupied && player.role == PlayerRole.host)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SeedlingColors.autumnGold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'HOST',
                            style: SeedlingTypography.caption.copyWith(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRankBadge(LivePlayer player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(player.rankEmoji, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            player.botanicalRank.toUpperCase(),
            style: SeedlingTypography.caption.copyWith(
              color: Colors.white70,
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarBloom(LivePlayer? player, double pulse) {
    final isOccupied = player != null;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow Rings
        if (isOccupied)
          ...List.generate(
            2,
            (i) => Container(
              width: 55 + (i * 10 * pulse),
              height: 55 + (i * 10 * pulse),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: SeedlingColors.seedlingGreen.withValues(
                    alpha: 0.3 / (i + 1),
                  ),
                  width: 1,
                ),
              ),
            ),
          ),

        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: isOccupied
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: isOccupied ? null : Border.all(color: Colors.white10),
          ),
          alignment: Alignment.center,
          child: Text(
            isOccupied ? player.avatarEmoji : '?',
            style: TextStyle(
              fontSize: 24,
              color: isOccupied ? null : Colors.white10,
            ),
          ),
        ),
      ],
    );
  }

  // --- Reused UI Helpers ---

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    LiveGameSession session,
    bool isHost,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () async {
              final shouldExit = await LiveExitDialog.show(
                context,
                ref,
                session,
                isHost,
              );
              if (shouldExit && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          Text(
            'CHALLENGE LOBBY',
            style: SeedlingTypography.heading3.copyWith(
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            children: [
              if (isHost)
                IconButton(
                  icon: const Icon(
                    Icons.settings_suggest_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: () => _showSettings(context, session),
                ),
              IconButton(
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: SeedlingColors.autumnGold,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArenaCard(LiveGameSession session) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                session.gameType == LiveGameType.vocabulary
                    ? '🌸 VOCABULARY'
                    : '🌳 SENTENCES',
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.autumnGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                session.theme.toUpperCase(),
                style: SeedlingTypography.caption.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            session.title,
            textAlign: TextAlign.center,
            style: SeedlingTypography.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildArenaMetric(
                Icons.quiz_rounded,
                '${session.totalQuestions} Qs',
              ),
              const SizedBox(width: 24),
              _buildArenaMetric(
                session.isSurvival ? Icons.bolt_rounded : Icons.timer_rounded,
                session.isSurvival ? 'SURVIVAL' : '${session.timePerQuestion}s',
                color: session.isSurvival
                    ? SeedlingColors.hibiscusRed
                    : Colors.white38,
              ),
              const SizedBox(width: 24),
              _buildArenaMetric(
                Icons.code_rounded,
                session.joinCode,
                isCode: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArenaMetric(
    IconData icon,
    String label, {
    bool isCode = false,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color ?? (isCode ? SeedlingColors.autumnGold : Colors.white38),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: SeedlingTypography.body.copyWith(
            color: color ?? (isCode ? SeedlingColors.autumnGold : Colors.white),
            fontWeight: isCode ? FontWeight.w900 : FontWeight.bold,
            letterSpacing: isCode ? 1.5 : 0,
            fontSize: isCode ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSpectatorArea(
    WidgetRef ref,
    LiveGameSession session,
    bool isHost,
  ) {
    if (session.spectators.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 100,
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'SPECTATORS (${session.spectators.length})',
              style: SeedlingTypography.caption.copyWith(
                color: Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: session.spectators.length,
              itemBuilder: (context, index) {
                final s = session.spectators[index];
                return _buildSpectatorAvatar(ref, s, isHost);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpectatorAvatar(WidgetRef ref, LivePlayer s, bool amIHost) {
    final hasRequested = s.role == PlayerRole.requesting;
    return GestureDetector(
      onTap: (hasRequested && amIHost)
          ? () => _showApprovalDialog(ref, s)
          : null,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: hasRequested
              ? SeedlingColors.hibiscusRed.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: hasRequested ? SeedlingColors.hibiscusRed : Colors.white10,
            width: hasRequested ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(s.avatarEmoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  Widget _buildFriendsInviteArea(WidgetRef ref) {
    // This would typically fetch from a friends provider
    final mockFriends = [
      {'name': 'Amos', 'emoji': '🦊', 'level': 12},
      {'name': 'Lumi', 'emoji': '🦄', 'level': 8},
      {'name': 'Aris', 'emoji': '🦜', 'level': 15},
    ];

    return Container(
      height: 80,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'INVITE FRIENDS',
              style: SeedlingTypography.caption.copyWith(
                color: Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: mockFriends.length,
              itemBuilder: (context, index) {
                final friend = mockFriends[index];
                return GestureDetector(
                  onTap: () {
                    // Send invite logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invite sent to ${friend['name']}!'),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          friend['emoji'] as String,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          friend['name'] as String,
                          style: SeedlingTypography.body.copyWith(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.add_circle_outline,
                          color: SeedlingColors.autumnGold,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(WidgetRef ref, LivePlayer player) {
    ref.read(activeSessionProvider.notifier).acceptParticipant(player.id);
  }

  Widget _buildActionBar(
    WidgetRef ref,
    BuildContext context,
    LiveGameSession activeSession,
    bool isHost,
    bool isSpectator,
    LivePlayer? myPlayer,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Column(
            children: [
              if (isHost)
                _buildHostControls(ref, activeSession)
              else if (isSpectator)
                _buildSpectatorControls(ref, activeSession, myPlayer)
              else
                _buildPlayerReadyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostControls(WidgetRef ref, LiveGameSession session) {
    final canStart = session.playerCount >= 1;
    return Column(
      children: [
        Text(
          canStart
              ? (session.playerCount == 1
                    ? 'Room ready for solo challenge.'
                    : 'Room ready for challenge.')
              : 'Planting seeds...',
          style: SeedlingTypography.caption.copyWith(
            color: canStart ? SeedlingColors.seedlingGreen : Colors.white60,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: canStart
              ? () => ref.read(activeSessionProvider.notifier).startGame()
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: canStart
                    ? [SeedlingColors.autumnGold, const Color(0xFFFFB300)]
                    : [Colors.white10, Colors.white.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: canStart
                  ? [
                      BoxShadow(
                        color: SeedlingColors.autumnGold.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : [],
            ),
            alignment: Alignment.center,
            child: Text(
              'START CHALLENGE',
              style: SeedlingTypography.heading3.copyWith(
                color: canStart ? Colors.black : Colors.white24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpectatorControls(
    WidgetRef ref,
    LiveGameSession session,
    LivePlayer? myPlayer,
  ) {
    final hasRequested = myPlayer?.hasRequestedToPlay == true;
    return Column(
      children: [
        Text(
          hasRequested
              ? 'Request sent to host...'
              : 'Spectating the preparations.',
          style: SeedlingTypography.caption.copyWith(
            color: hasRequested ? SeedlingColors.autumnGold : Colors.white60,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: (hasRequested || session.isFull)
              ? null
              : () => ref.read(activeSessionProvider.notifier).requestToPlay(),
          style: ElevatedButton.styleFrom(
            backgroundColor: SeedlingColors.seedlingGreen,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: Text(
            session.isFull
                ? 'ARENA FULL'
                : (hasRequested ? 'PENDING...' : 'REQUEST TO JOIN'),
            style: SeedlingTypography.heading3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerReadyState() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.verified_user_rounded,
          color: SeedlingColors.seedlingGreen,
        ),
        const SizedBox(width: 12),
        Text(
          'WARRIOR READY',
          style: SeedlingTypography.heading3.copyWith(
            color: SeedlingColors.seedlingGreen,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  void _showSettings(BuildContext context, LiveGameSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditSettingsSheet(session: session),
    );
  }
}

// --- Background Components ---

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

class _Spore {
  late double x, y, size, speed, angle, drift;
  late Color color;

  _Spore() {
    x = math.Random().nextDouble();
    y = math.Random().nextDouble();
    size = math.Random().nextDouble() * 3 + 1.5;
    speed = math.Random().nextDouble() * 0.015 + 0.005;
    angle = math.Random().nextDouble() * math.pi * 2;
    drift = (math.Random().nextDouble() - 0.5) * 0.002;

    // Some spores are colored, some are white
    final r = math.Random().nextDouble();
    if (r < 0.1) {
      color = SeedlingColors.autumnGold.withValues(alpha: 0.4);
    } else if (r < 0.2) {
      color = SeedlingColors.seedlingGreen.withValues(alpha: 0.3);
    } else {
      color = Colors.white.withValues(alpha: 0.15);
    }
  }

  void update(double t) {
    y -= speed * 0.15;
    if (y < -0.1) {
      y = 1.1;
      x = math.Random().nextDouble();
    }
    x += math.sin(t * math.pi * 2 + angle) * 0.0015 + drift;
  }
}

class _SporePainter extends CustomPainter {
  final List<_Spore> spores;
  final double progress;
  _SporePainter(this.spores, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var spore in spores) {
      spore.update(progress);
      paint.color = spore.color;

      // Draw organic leaf/spore shape
      final path = Path();
      final centerX = spore.x * size.width;
      final centerY = spore.y * size.height;

      path.addOval(
        Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: spore.size,
          height: spore.size * 1.8,
        ),
      );

      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(spore.angle + progress * 2);
      canvas.translate(-centerX, -centerY);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SporePainter oldDelegate) => true;
}

class _EditSettingsSheet extends ConsumerStatefulWidget {
  final LiveGameSession session;
  const _EditSettingsSheet({required this.session});

  @override
  ConsumerState<_EditSettingsSheet> createState() => _EditSettingsSheetState();
}

class _EditSettingsSheetState extends ConsumerState<_EditSettingsSheet> {
  late int _maxPlayers, _questionCount, _timeLimit;
  late String _theme;

  @override
  void initState() {
    super.initState();
    _maxPlayers = widget.session.maxPlayers;
    _questionCount = widget.session.totalQuestions;
    _timeLimit = widget.session.timePerQuestion;
    _theme = widget.session.theme;
  }

  void _saveSettings() {
    ref.read(activeSessionProvider.notifier).updateSettings({
      'max_players': _maxPlayers,
      'question_count': _questionCount,
      'time_per_question': _timeLimit,
      'theme': _theme,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D160B).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Arena Configuration',
                style: SeedlingTypography.heading2.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              _buildSettingSlider(
                'Warriors',
                _maxPlayers.toDouble(),
                2,
                10,
                SeedlingColors.seedlingGreen,
                (v) => setState(() => _maxPlayers = v.toInt()),
              ),
              const SizedBox(height: 24),
              _buildSettingSlider(
                'Questions',
                _questionCount.toDouble(),
                5,
                30,
                SeedlingColors.autumnGold,
                (v) => setState(() => _questionCount = v.toInt()),
              ),
              const SizedBox(height: 24),
              _buildSettingSlider(
                'Time (s)',
                _timeLimit.toDouble(),
                5,
                30,
                SeedlingColors.sunlight,
                (v) => setState(() => _timeLimit = v.toInt()),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SeedlingColors.autumnGold,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'APPLY NEW LAWS',
                  style: SeedlingTypography.heading3.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSlider(
    String label,
    double value,
    double min,
    double max,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: SeedlingTypography.body.copyWith(color: Colors.white70),
            ),
            Text(
              '${value.toInt()}',
              style: SeedlingTypography.heading3.copyWith(color: color),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: color,
          inactiveColor: Colors.white10,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ActivePulse {
  final String type;
  final DateTime startTime;
  final Offset position;

  _ActivePulse({
    required this.type,
    required this.startTime,
    required this.position,
  });
}

class _PulseOverlay extends StatefulWidget {
  final _ActivePulse pulse;
  const _PulseOverlay({required this.pulse});

  @override
  State<_PulseOverlay> createState() => _PulseOverlayState();
}

class _PulseOverlayState extends State<_PulseOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scale = Tween<double>(
      begin: 0.5,
      end: 3.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.pulse.position.dx - 50,
      top: widget.pulse.position.dy - 50,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isSun = widget.pulse.type == 'sunlight';
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isSun ? SeedlingColors.autumnGold : SeedlingColors.water)
                          .withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  isSun ? '🌞' : '💧',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
