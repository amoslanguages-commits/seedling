import 'package:flutter/material.dart';
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

class MultiplayerLobbyScreen extends ConsumerWidget {
  final LiveGameSession session;

  const MultiplayerLobbyScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch active session for real-time updates (like player requests)
    final activeSession = ref.watch(activeSessionProvider) ?? session;
    
    // Determine my role
    final myPlayer = activeSession.participants.where((p) => p.id == AuthService().userId).firstOrNull;
    final isHost = myPlayer?.role == PlayerRole.host;
    final isSpectator = myPlayer?.role == PlayerRole.spectator;

    // Listen to real-time status changes to trigger animations/transitions
    ref.listen<LiveGameSession?>(activeSessionProvider, (previous, next) {
      if (next != null && next.status == GameStatus.starting) {
        Navigator.pushReplacement(
          context,
          SeedlingPageRoute(page: LiveCountdownScreen(session: next)),
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await LiveExitDialog.show(context, ref, activeSession, isHost);
        if (shouldExit && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: SeedlingColors.background,
        body: Stack(
          children: [
            // Background Forest Graphic / Blur
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [SeedlingColors.seedlingGreen.withOpacity(0.2), Colors.transparent],
                  ),
                ),
              ),
            ),
            
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, ref, activeSession, isHost),
                  
                  const SizedBox(height: 20),
                  
                  // Lobby Slots
                  Text(
                    'THE ARENA (${activeSession.playerCount}/${activeSession.maxPlayers})',
                    textAlign: TextAlign.center,
                    style: SeedlingTypography.caption.copyWith(letterSpacing: 2, color: SeedlingColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        // Render 5 slots
                        ...List.generate(activeSession.maxPlayers, (index) {
                          return _buildPlayerSlot(
                            index < activeSession.activePlayers.length ? activeSession.activePlayers[index] : null,
                          );
                        }),
                        
                        const SizedBox(height: 40),
                        
                        // Spectators & Pending Zone
                        if (activeSession.spectators.isNotEmpty) ...[
                          Text(
                            'SPECTATORS (${activeSession.spectators.length})',
                            style: SeedlingTypography.heading3,
                          ),
                          const SizedBox(height: 10),
                          ...activeSession.spectators.map((s) => _buildSpectatorRow(ref, s, isHost)),
                        ] else ...[
                          const SizedBox(height: 40),
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.visibility_off_outlined, color: SeedlingColors.textSecondary.withOpacity(0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  'No spectators yet.',
                                  style: SeedlingTypography.body.copyWith(fontStyle: FontStyle.italic, color: SeedlingColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  
                  // Bottom Action Bar
                  _buildActionBar(ref, context, activeSession, isHost, isSpectator, myPlayer),
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

  Widget _buildHeader(BuildContext context, WidgetRef ref, LiveGameSession session, bool isHost) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 28),
            onPressed: () async {
              final shouldExit = await LiveExitDialog.show(context, ref, session, isHost);
              if (shouldExit && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          Column(
            children: [
              Text('Room Code', style: SeedlingTypography.caption),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: SeedlingColors.sunlight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  session.joinCode,
                  style: SeedlingTypography.heading2.copyWith(color: SeedlingColors.sunlight, letterSpacing: 2),
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (isHost)
                IconButton(
                  icon: const Icon(Icons.settings_rounded, color: SeedlingColors.textSecondary),
                  onPressed: () => _showSettings(context, session),
                ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: SeedlingColors.seedlingGreen),
                onPressed: () {},
              ),
            ],
          )
        ],
      ),
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

  Widget _buildPlayerSlot(LivePlayer? player) {
    final isOccupied = player != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 70,
      decoration: BoxDecoration(
        color: isOccupied ? SeedlingColors.cardBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOccupied ? SeedlingColors.seedlingGreen.withOpacity(0.4) : SeedlingColors.morningDew.withOpacity(0.3),
          width: isOccupied ? 2 : 1,
        ),
        boxShadow: isOccupied ? [
          BoxShadow(
            color: SeedlingColors.seedlingGreen.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOccupied ? SeedlingColors.morningDew.withOpacity(0.3) : Colors.transparent,
              shape: BoxShape.circle,
              border: isOccupied ? null : Border.all(color: SeedlingColors.textSecondary.withOpacity(0.3), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(isOccupied ? player.avatarEmoji : '👤', style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isOccupied ? player.displayName : 'Waiting for player...',
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: isOccupied ? FontWeight.bold : FontWeight.normal,
                    color: isOccupied ? SeedlingColors.textPrimary : SeedlingColors.textSecondary,
                  ),
                ),
                if (isOccupied && player.role == PlayerRole.host)
                  Text('HOST', style: SeedlingTypography.caption.copyWith(color: SeedlingColors.sunlight, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpectatorRow(WidgetRef ref, LivePlayer s, bool amIHost) {
    final hasRequested = s.role == PlayerRole.requesting;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: hasRequested ? Border.all(color: SeedlingColors.warning.withOpacity(0.5), width: 1) : null,
      ),
      child: Row(
        children: [
          Text(s.avatarEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.displayName, style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold)),
                if (hasRequested)
                  Text('Waiting for approval...', style: SeedlingTypography.caption.copyWith(color: SeedlingColors.warning)),
              ],
            ),
          ),
          if (hasRequested && amIHost) ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded, color: SeedlingColors.seedlingGreen),
              onPressed: () => ref.read(activeSessionProvider.notifier).acceptParticipant(s.id),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: SeedlingColors.warning),
              onPressed: () => ref.read(activeSessionProvider.notifier).rejectParticipant(s.id),
            ),
          ] else if (hasRequested) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SeedlingColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('REQUESTED', style: SeedlingTypography.caption.copyWith(color: SeedlingColors.warning, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ] else ...[
            Text('WATCHING', style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary, fontSize: 10)),
          ]
        ],
      ),
    );
  }

  Widget _buildActionBar(WidgetRef ref, BuildContext context, LiveGameSession activeSession, bool isHost, bool isSpectator, LivePlayer? myPlayer) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        children: [
          if (isHost) ...[
            Text('You are the host.', style: SeedlingTypography.caption),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                ref.read(activeSessionProvider.notifier).startGame();
                // The ref.listen will handle the pushReplacement for all clients when status == starting
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SeedlingColors.seedlingGreen,
                disabledBackgroundColor: SeedlingColors.morningDew,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text('Start Game', style: SeedlingTypography.heading3.copyWith(color: Colors.white)),
            ),
          ] else if (isSpectator) ...[
            if (myPlayer?.hasRequestedToPlay == true) ...[
              Text('Request sent. Waiting for host...', style: SeedlingTypography.body.copyWith(color: SeedlingColors.warning)),
            ] else ...[
              ElevatedButton(
                onPressed: activeSession.isFull ? null : () {
                  ref.read(activeSessionProvider.notifier).requestToPlay();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SeedlingColors.deepRoot,
                  disabledBackgroundColor: SeedlingColors.morningDew,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(activeSession.isFull ? 'Lobby Full' : 'Request to Play', style: SeedlingTypography.heading3.copyWith(color: Colors.white)),
              ),
            ]
          ] else ...[
             // Is Player
             Text('You are in! Get ready.', style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.seedlingGreen)),
          ]
        ],
      ),
    );
  }
}

class _EditSettingsSheet extends ConsumerStatefulWidget {
  final LiveGameSession session;
  const _EditSettingsSheet({required this.session});

  @override
  ConsumerState<_EditSettingsSheet> createState() => _EditSettingsSheetState();
}

class _EditSettingsSheetState extends ConsumerState<_EditSettingsSheet> {
  late LiveGameType _gameType;
  late int _maxPlayers;
  late int _questionCount;
  late int _timeLimit;
  late String _theme;
  late String _subtheme;

  @override
  void initState() {
    super.initState();
    _gameType = widget.session.gameType;
    _maxPlayers = widget.session.maxPlayers;
    _questionCount = widget.session.totalQuestions;
    _timeLimit = widget.session.timePerQuestion;
    _theme = widget.session.theme;
    _subtheme = widget.session.subtheme;
  }

  void _saveSettings() {
    ref.read(activeSessionProvider.notifier).updateSettings({
      'game_type': _gameType.name,
      'max_players': _maxPlayers,
      'question_count': _questionCount,
      'time_per_question': _timeLimit,
      'theme': _theme,
      'subtheme': _subtheme,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SeedlingColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Arena Settings', style: SeedlingTypography.heading1),
            const SizedBox(height: 30),

            // Game Type
            Text('Game Mode', style: SeedlingTypography.heading3),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _gameType = LiveGameType.vocabulary),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _gameType == LiveGameType.vocabulary ? SeedlingColors.water.withOpacity(0.2) : SeedlingColors.cardBackground,
                        border: Border.all(color: _gameType == LiveGameType.vocabulary ? SeedlingColors.water : Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('🌸 Vocabulary', style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _gameType = LiveGameType.sentences),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _gameType == LiveGameType.sentences ? SeedlingColors.water.withOpacity(0.2) : SeedlingColors.cardBackground,
                        border: Border.all(color: _gameType == LiveGameType.sentences ? SeedlingColors.water : Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('🌳 Sentences', style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Theme Selection
            Text('Arena Theme', style: SeedlingTypography.heading3),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _theme,
              decoration: InputDecoration(
                filled: true,
                fillColor: SeedlingColors.cardBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: ['General', 'Botany', 'Nature', 'Magic', 'Adventure']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _theme = v ?? 'General'),
            ),
            const SizedBox(height: 15),

            Text('Sub-Theme', style: SeedlingTypography.body),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _subtheme,
              onChanged: (v) => _subtheme = v,
              decoration: InputDecoration(
                hintText: 'e.g., Rare Flowers',
                filled: true,
                fillColor: SeedlingColors.cardBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 25),

            // Max Players
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Max Players', style: SeedlingTypography.body),
                Text('$_maxPlayers', style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.seedlingGreen)),
              ],
            ),
            Slider(
              value: _maxPlayers.toDouble(),
              min: 2,
              max: 10,
              divisions: 8,
              activeColor: SeedlingColors.seedlingGreen,
              onChanged: (v) => setState(() => _maxPlayers = v.toInt()),
            ),

            // Question Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Question Count', style: SeedlingTypography.body),
                Text('$_questionCount', style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.seedlingGreen)),
              ],
            ),
            Slider(
              value: _questionCount.toDouble(),
              min: 5,
              max: 30,
              divisions: 5,
              activeColor: SeedlingColors.seedlingGreen,
              onChanged: (v) => setState(() => _questionCount = v.toInt()),
            ),

            // Time Limit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Time per Question', style: SeedlingTypography.body),
                Text('${_timeLimit}s', style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.sunlight)),
              ],
            ),
            Slider(
              value: _timeLimit.toDouble(),
              min: 5,
              max: 30,
              divisions: 5,
              activeColor: SeedlingColors.sunlight,
              onChanged: (v) => setState(() => _timeLimit = v.toInt()),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: SeedlingColors.deepRoot,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Apply Changes', style: SeedlingTypography.heading3.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

