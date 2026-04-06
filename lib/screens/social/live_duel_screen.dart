import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/social.dart';
import '../../models/word.dart';
import '../../models/multiplayer.dart';
import '../../providers/app_providers.dart';
import '../../providers/multiplayer_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/quizzes.dart';
import '../../widgets/mascot.dart';
import '../../widgets/premium_environment.dart';
import '../../services/audio_service.dart';

class LiveDuelScreen extends ConsumerStatefulWidget {
  final Friend opponent;
  final String? sessionId;

  const LiveDuelScreen({super.key, required this.opponent, this.sessionId});

  @override
  ConsumerState<LiveDuelScreen> createState() => _LiveDuelScreenState();
}

class _LiveDuelScreenState extends ConsumerState<LiveDuelScreen>
    with TickerProviderStateMixin {
  int _timeLeft = 60;
  Timer? _gameTimer;
  bool _isGameOver = false;

  List<Word> _duelWords = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  int _playerStreak = 0;

  // Premium FX
  late AnimationController _burstController;
  late AnimationController _headerPulseController;
  final List<BurstParticle> _burstParticles = [];

  @override
  void initState() {
    super.initState();
    _loadWords();

    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _loadWords() async {
    final db = ref.read(databaseProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);

    final words = await db.getWordsForLanguage(
      nativeLang,
      targetLang,
      limit: 30,
    );

    if (mounted) {
      setState(() {
        _duelWords = words..shuffle();
        _isLoading = false;
      });
      AudioService.instance.startAmbient();
      AudioService.instance.play(SFX.quizStart);
      _startGame();
    }
  }

  void _startGame() {
    final session = ref.read(activeSessionProvider);
    if (session?.currentQuestionStartAt != null) {
      final elapsed = DateTime.now()
          .toUtc()
          .difference(session!.currentQuestionStartAt!)
          .inSeconds;
      _timeLeft = (60 - elapsed).clamp(0, 60);
    }

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _endGame();
      }
    });
  }

  void _showTerminatedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: SeedlingColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Match Terminated', style: SeedlingTypography.heading2),
        content: Text(
          'The host has ended the match or disconnected.',
          style: SeedlingTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Exit screen
            },
            child: Text(
              'Return to Arena',
              style: SeedlingTypography.body.copyWith(
                color: SeedlingColors.waterBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _endGame() {
    _gameTimer?.cancel();
    AudioService.instance.stopAmbient();
    AudioService.instance.play(SFX.sessionComplete);
    AudioService.haptic(HapticType.sessionComplete).ignore();

    // If host, update session status to finished
    final session = ref.read(activeSessionProvider);
    if (session != null && session.hostId == AuthService().currentUser?.id) {
      ref
          .read(activeSessionProvider.notifier)
          .nextQuestion(); // This triggers next screen or finish
    }

    setState(() {
      _isGameOver = true;
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _burstController.dispose();
    _headerPulseController.dispose();
    AudioService.instance.stopAmbient();
    super.dispose();
  }

  void _handleAnswer(bool isCorrect) {
    if (_isGameOver) return;

    if (isCorrect) {
      AudioService.instance.playCorrect(streak: _playerStreak);
      if ((_playerStreak + 1) % 3 == 0) {
        AudioService.instance.play(SFX.streakBonus);
      }

      // Trigger Spore Burst
      _triggerBurst();

      setState(() {
        _playerStreak++;
      });
    } else {
      AudioService.instance.play(SFX.wrongAnswer);
      setState(() {
        _playerStreak = 0;
      });
    }

    // Submit to real-time sync
    ref
        .read(activeSessionProvider.notifier)
        .submitAnswer(
          _currentIndex,
          isCorrect
              ? 1
              : 0, // Placeholder choice indexes as we are in a rapid quiz
          isCorrect,
        );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && !_isGameOver) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _duelWords.length;
        });
      }
    });
  }

  void _triggerBurst() {
    setState(() {
      _burstParticles.clear();
      final random = Random();
      for (int i = 0; i < 15; i++) {
        _burstParticles.add(
          BurstParticle(
            angle: random.nextDouble() * pi * 2,
            speed: 2.0 + random.nextDouble() * 4.0,
            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.8),
          ),
        );
      }
    });
    _burstController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final user = AuthService().currentUser;

    // Listen for termination
    ref.listen<LiveGameSession?>(activeSessionProvider, (previous, next) {
      if (next == null) return;
      if (next.status == GameStatus.terminated) {
        _showTerminatedDialog();
      }
    });

    int playerScore = 0;
    int opponentScore = 0;

    if (session != null) {
      try {
        final me = session.participants.firstWhere((p) => p.id == user?.id);
        playerScore = me.score;
      } catch (_) {}

      try {
        final opp = session.participants.firstWhere((p) => p.id != user?.id);
        opponentScore = opp.score;
      } catch (_) {}
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SeedlingColors.background,
        body: Center(
          child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen),
        ),
      );
    }

    if (_isGameOver ||
        (session != null && session.status == GameStatus.finished)) {
      return _buildGameOverScreen(playerScore, opponentScore);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumEnvironment(
        timerProgress: 1.0 - (_timeLeft / 60.0),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildDuelHeader(playerScore, opponentScore),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned(
                          left: 20,
                          bottom: 0,
                          top: 0,
                          width: 20,
                          child: _buildVerticalVine(
                            opponentScore / 200.0,
                            SeedlingColors.hibiscusRed,
                          ),
                        ),

                        Positioned(
                          right: 20,
                          bottom: 0,
                          top: 0,
                          width: 20,
                          child: _buildVerticalVine(
                            playerScore / 200.0,
                            SeedlingColors.seedlingGreen,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 60,
                            vertical: 20,
                          ),
                          child: _buildQuizContent(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Local Burst Effect
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _burstController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _LocalBurstPainter(
                        _burstParticles,
                        _burstController.value,
                        MediaQuery.of(context).size /
                            2, // Centered for now as we don't have exact tap yet
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDuelHeader(int playerScore, int opponentScore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Opponent Avatar with Red Glow
          Column(
            children: [
              AnimatedBuilder(
                animation: _headerPulseController,
                builder: (context, _) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SeedlingColors.hibiscusRed.withValues(
                          alpha: 0.3 * _headerPulseController.value,
                        ),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: SeedlingColors.hibiscusRed.withValues(
                      alpha: 0.2,
                    ),
                    child: Text(
                      widget.opponent.displayName[0],
                      style: SeedlingTypography.heading3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$opponentScore',
                style: SeedlingTypography.heading3.copyWith(
                  color: SeedlingColors.hibiscusRed,
                  shadows: [
                    const Shadow(
                      color: SeedlingColors.hibiscusRed,
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Glossy Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              '0:${_timeLeft.toString().padLeft(2, '0')}',
              style: SeedlingTypography.heading2.copyWith(
                color: _timeLeft < 10
                    ? SeedlingColors.hibiscusRed
                    : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          // Player Avatar with Green Glow
          Column(
            children: [
              AnimatedBuilder(
                animation: _headerPulseController,
                builder: (context, _) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SeedlingColors.seedlingGreen.withValues(
                          alpha: 0.4 * _headerPulseController.value,
                        ),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 28, // Slightly larger for player
                    backgroundColor: SeedlingColors.seedlingGreen,
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$playerScore',
                style: SeedlingTypography.heading3.copyWith(
                  color: SeedlingColors.seedlingGreen,
                  shadows: [
                    const Shadow(
                      color: SeedlingColors.seedlingGreen,
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalVine(double progress, Color color) {
    final p = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 8,
              height: constraints.maxHeight * p,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuizContent() {
    if (_duelWords.isEmpty) return const SizedBox();

    final word = _duelWords[_currentIndex];

    final options = [word.translation];
    final random = Random();
    while (options.length < 3) {
      final randomWord = _duelWords[random.nextInt(_duelWords.length)];
      if (!options.contains(randomWord.translation)) {
        options.add(randomWord.translation);
      }
    }
    options.shuffle();

    return Column(
      children: [
        if (_playerStreak >= 3)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: SeedlingColors.sunlight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SeedlingColors.sunlight, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: SeedlingColors.sunlight,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_playerStreak Streak!',
                  style: SeedlingTypography.body.copyWith(
                    color: SeedlingColors.sunlight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: GrowTheWordQuiz(
            key: ValueKey('duel_q_$_currentIndex'),
            word: word,
            options: options,
            onAnswer: (correct, mastery, [wrongTranslation]) =>
                _handleAnswer(correct),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverScreen(int playerScore, int opponentScore) {
    final isWinner = playerScore > opponentScore;
    final isTie = playerScore == opponentScore;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
              width: 200,
              child: SeedlingMascot(
                state: MascotState.celebrating,
                accessories: MascotAccessories(holdingTrophy: isWinner),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              isTie ? "It's a Tie!" : (isWinner ? "Victory!" : "Defeat..."),
              style: SeedlingTypography.heading1.copyWith(
                color: isTie
                    ? SeedlingColors.textPrimary
                    : (isWinner
                          ? SeedlingColors.success
                          : SeedlingColors.error),
                fontSize: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text("Final Score", style: SeedlingTypography.heading3),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'You: $playerScore',
                  style: SeedlingTypography.heading2.copyWith(
                    color: SeedlingColors.seedlingGreen,
                  ),
                ),
                const SizedBox(width: 40),
                Text(
                  '${widget.opponent.displayName}: $opponentScore',
                  style: SeedlingTypography.heading2.copyWith(
                    color: SeedlingColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SeedlingColors.deepRoot,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Return to Arena',
                style: SeedlingTypography.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalBurstPainter extends CustomPainter {
  final List<BurstParticle> particles;
  final double progress;
  final Size centerSize;

  _LocalBurstPainter(this.particles, this.progress, this.centerSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      final distance = progress * 100 * particle.speed;
      final x = centerSize.width + cos(particle.angle) * distance;
      final y = centerSize.height + sin(particle.angle) * distance;

      paint.color = particle.color.withValues(alpha: 1.0 - progress);
      canvas.drawCircle(Offset(x, y), 3 * (1.0 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class BurstParticle {
  final double angle;
  final double speed;
  final Color color;

  BurstParticle({
    required this.angle,
    required this.speed,
    required this.color,
  });
}
