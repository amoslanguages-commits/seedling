import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../models/multiplayer.dart';
import '../../../providers/multiplayer_provider.dart';

class LiveExitDialog extends ConsumerWidget {
  final LiveGameSession session;
  final bool isHost;

  const LiveExitDialog({
    super.key,
    required this.session,
    required this.isHost,
  });

  static Future<bool> show(
    BuildContext context,
    WidgetRef ref,
    LiveGameSession session,
    bool isHost,
  ) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Exit',
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: LiveExitDialog(session: session, isHost: isHost),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isHost) {
      return _buildGeneralExit(context, ref);
    }

    // Check if there are other players to pass host to
    final otherPlayers = session.activePlayers
        .where((p) => p.id != 'current_user' && p.id != 'host')
        .toList();
    if (otherPlayers.isEmpty) {
      // Host is alone, just end the game
      return _buildGeneralExit(context, ref, true);
    }

    return _buildHostExit(context, ref, otherPlayers);
  }

  Widget _buildGeneralExit(
    BuildContext context,
    WidgetRef ref, [
    bool forceEndGame = false,
  ]) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: SeedlingColors.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: SeedlingColors.morningDew.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Leave Arena?', style: SeedlingTypography.heading2),
              const SizedBox(height: 10),
              Text(
                forceEndGame
                    ? 'You are the only player left. The game will be closed.'
                    : 'Are you sure you want to leave this game?',
                textAlign: TextAlign.center,
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false), // cancel
                      child: Text(
                        'Stay',
                        style: SeedlingTypography.heading3.copyWith(
                          color: SeedlingColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (forceEndGame) {
                          ref
                              .read(activeSessionProvider.notifier)
                              .endGameForAll();
                        } else {
                          ref.read(activeSessionProvider.notifier).leaveGame();
                        }
                        Navigator.pop(context, true); // exit allowed
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SeedlingColors.deepRoot,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Leave',
                        style: SeedlingTypography.heading3.copyWith(
                          color: Colors.white,
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
    );
  }

  Widget _buildHostExit(
    BuildContext context,
    WidgetRef ref,
    List<LivePlayer> otherPlayers,
  ) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: SeedlingColors.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: SeedlingColors.warning.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.warning.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Host Disconnect',
                style: SeedlingTypography.heading2.copyWith(
                  color: SeedlingColors.warning,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'You are the Host! If you leave, you must pass the host authority or end the game for everyone.',
                textAlign: TextAlign.center,
                style: SeedlingTypography.body,
              ),
              const SizedBox(height: 25),

              Text('Pass Host To:', style: SeedlingTypography.caption),
              const SizedBox(height: 10),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: otherPlayers.length,
                  itemBuilder: (context, index) {
                    final p = otherPlayers[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        p.avatarEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        p.displayName,
                        style: SeedlingTypography.body,
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          ref
                              .read(activeSessionProvider.notifier)
                              .passHostAndLeave(p.id);
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SeedlingColors.water,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Pass & Leave'),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: () {
                  // End Game For All
                  ref.read(activeSessionProvider.notifier).endGameForAll();
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SeedlingColors.deepRoot,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'End Game for Everyone',
                  style: SeedlingTypography.heading3.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: SeedlingTypography.body.copyWith(
                    color: SeedlingColors.textSecondary,
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
