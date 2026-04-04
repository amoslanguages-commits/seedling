import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../models/multiplayer.dart';
import '../../../providers/multiplayer_provider.dart';
import '../../../core/page_route.dart';
import '../../../services/auth_service.dart';
import 'live_quiz_screen.dart';
import 'live_chat_overlay.dart';

class LiveCountdownScreen extends ConsumerStatefulWidget {
  final LiveGameSession session;

  const LiveCountdownScreen({super.key, required this.session});

  @override
  ConsumerState<LiveCountdownScreen> createState() =>
      _LiveCountdownScreenState();
}

class _LiveCountdownScreenState extends ConsumerState<LiveCountdownScreen>
    with SingleTickerProviderStateMixin {
  int _countdown = 3;
  late Timer _timer;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutBack),
    );

    _pulseController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
        _pulseController.reset();
        _pulseController.forward();
      } else {
        _timer.cancel();
        _transitionToGame();
      }
    });
  }

  void _transitionToGame() {
    // Host informs state that playing has begun, other clients will eventually sync this over web sockets (for now it's local)
    final activeSession = ref.read(activeSessionProvider);
    final isHost =
        activeSession?.participants.any(
          (p) => p.id == AuthService().userId && p.role == PlayerRole.host,
        ) ??
        false;

    if (isHost) {
      ref.read(activeSessionProvider.notifier).beginPlaying();
    }

    Navigator.pushReplacement(
      context,
      SeedlingPageRoute(
        page: LiveQuizScreen(session: activeSession ?? widget.session),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlingColors.deepRoot,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient background elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SeedlingColors.water.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SeedlingColors.sunlight.withValues(alpha: 0.1),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ARENA STARTING IN',
                  style: SeedlingTypography.heading3.copyWith(
                    color: SeedlingColors.morningDew,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 30),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Text(
                    '$_countdown',
                    style: SeedlingTypography.heading1.copyWith(
                      fontSize: 120,
                      color: SeedlingColors.sunlight,
                      shadows: [
                        BoxShadow(
                          color: SeedlingColors.sunlight.withValues(alpha: 0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chat Overlay
          const LiveChatOverlay(),
        ],
      ),
    );
  }
}
