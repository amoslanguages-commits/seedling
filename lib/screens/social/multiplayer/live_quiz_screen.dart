import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../models/multiplayer.dart';
import '../../../models/word.dart';
import '../../../providers/multiplayer_provider.dart';
import 'live_reaction_bar.dart';
import 'live_chat_overlay.dart';
import 'floating_reaction_overlay.dart';
import 'live_exit_dialog.dart';
import '../../../services/auth_service.dart';
import '../../../services/vocabulary_service.dart';

class _BurstParticle {
  late double velocity, angle, size;
  late Color color;

  _BurstParticle() {
    velocity = math.Random().nextDouble() * 150 + 50;
    angle = math.Random().nextDouble() * math.pi * 2;
    size = math.Random().nextDouble() * 4 + 2;

    final r = math.Random().nextDouble();
    if (r < 0.6) {
      color = SeedlingColors.seedlingGreen;
    } else if (r < 0.9) {
      color = SeedlingColors.autumnGold;
    } else {
      color = Colors.white;
    }
  }
}

class _BurstPainter extends CustomPainter {
  final List<_BurstParticle> particles;
  final double progress;
  final Offset origin;

  _BurstPainter(this.particles, this.progress, this.origin);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) {
      return;
    }

    final paint = Paint();
    for (var p in particles) {
      final distance = p.velocity * progress;
      final x = origin.dx + math.cos(p.angle) * distance;
      final y = origin.dy + math.sin(p.angle) * distance;

      paint.color = p.color.withValues(alpha: (1 - progress).clamp(0, 1.0));
      canvas.drawCircle(Offset(x, y), p.size * (1 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => true;
}

class LiveQuizScreen extends ConsumerStatefulWidget {
  final LiveGameSession session;

  const LiveQuizScreen({super.key, required this.session});

  @override
  ConsumerState<LiveQuizScreen> createState() => _LiveQuizScreenState();
}

class _LiveQuizScreenState extends ConsumerState<LiveQuizScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FloatingReactionOverlayState> _reactionKey = GlobalKey();

  late AnimationController _bgController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _burstController;
  late List<_Spore> _spores;
  late List<_BurstParticle> _burstParticles;
  Offset _burstPosition = Offset.zero;

  Word? _currentWord;
  Timer? _syncTimer;
  int _secondsRemaining = 15;
  bool _revealed = false;
  int _selectedOption = -1;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _spores = List.generate(20, (i) => _Spore());
    _burstParticles = [];

    _startSyncTimer();
    _loadCurrentQuestion();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _bgController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final session = ref.read(activeSessionProvider);
      if (session == null || session.currentQuestionStartAt == null) return;

      final now = DateTime.now().toUtc();
      final diff = now.difference(session.currentQuestionStartAt!).inSeconds;
      final remaining = (session.timePerQuestion - diff).clamp(
        0,
        session.timePerQuestion,
      );

      if (remaining != _secondsRemaining) {
        setState(() {
          _secondsRemaining = remaining;
          // Speed up pulse as time runs out
          if (remaining < 5) {
            _pulseController.duration = const Duration(milliseconds: 400);
          } else if (remaining < 10) {
            _pulseController.duration = const Duration(milliseconds: 800);
          } else {
            _pulseController.duration = const Duration(milliseconds: 1500);
          }
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        });
        if (remaining == 0) {
          _onTimeOut();
        }
      }
    });
  }

  Future<void> _loadCurrentQuestion() async {
    final session = ref.read(activeSessionProvider);
    if (session == null || session.questionIds.isEmpty) return;

    final notifier = ref.read(activeSessionProvider.notifier);
    notifier.onReactionReceived = (emoji) {
      _reactionKey.currentState?.spawnEmoji(emoji);
    };

    // Load current word from concept ID

    try {
      final qId =
          session.questionIds[session.currentQuestionIndex %
              session.questionIds.length];
      final targetLang = session.targetLanguageCode;
      final nativeLang = session.languageCode;

      final word = await VocabularyService.fetchOnlineWord(
        qId,
        targetLang,
        nativeLang,
      );

      if (mounted) {
        setState(() {
          _currentWord = word;
          _selectedOption = -1;
        });
      }
    } catch (e) {
      debugPrint('Error loading question: $e');
      // Error handled, word remains null or previous state
    }
  }

  void _onTimeOut() {
    // If not revealed, logic for timeout here
  }

  void _onOptionSelected(int index, Offset position) {
    if (_selectedOption != -1 || _revealed || _currentWord == null) return;

    final isCorrect = index == _currentWord!.correctIndex;

    setState(() {
      _selectedOption = index;
      if (isCorrect) {
        _triggerBurst(position);
      }
    });

    ref
        .read(activeSessionProvider.notifier)
        .submitAnswer(widget.session.currentQuestionIndex, index, isCorrect);
  }

  void _triggerBurst(Offset position) {
    _burstPosition = position;
    _burstParticles = List.generate(24, (i) => _BurstParticle());
    _burstController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider) ?? widget.session;
    final myPlayer = session.participants
        .where((p) => p.id == AuthService().userId)
        .firstOrNull;
    _revealed = myPlayer?.lastAnswerStatus != AnswerStatus.idle;

    final amIPlaying =
        myPlayer?.role == PlayerRole.player ||
        myPlayer?.role == PlayerRole.host;
    final isHost = myPlayer?.role == PlayerRole.host;

    final article = _currentWord?.article ?? '';
    final question = _currentWord?.question ?? 'Looking for a word...';
    final pronunciation = _currentWord?.pronunciation ?? '';
    final gender = _currentWord?.gender;
    final pos = _currentWord?.pos ?? '';

    Color genderColor = SeedlingColors.water;
    if (gender == 'Masculine') {
      genderColor = const Color(0xFF64B5F6);
    }
    if (gender == 'Feminine') {
      genderColor = const Color(0xFFF06292);
    }
    if (gender == 'Neuter') {
      genderColor = const Color(0xFF81C784);
    }

    ref.listen<LiveGameSession?>(activeSessionProvider, (previous, next) {
      if (next == null) return;
      if (next.status == GameStatus.terminated) {
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
          session,
          isHost,
        );
        if (shouldExit && context.mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF070F06),
        body: Stack(
          children: [
            _buildLivingBackground(),
            _buildSporeParticles(),
            _buildBurstParticles(),

            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context, ref, session, isHost),
                  _buildAnimatedLeaderboard(session),
                  const SizedBox(height: 20),
                  _buildTimerBadge(),
                  const SizedBox(height: 32),
                  _buildGlassQuestionCard(
                    article,
                    question,
                    pronunciation,
                    gender,
                    pos,
                    genderColor,
                  ),
                  Expanded(
                    child: amIPlaying
                        ? _buildParticipantOptions(genderColor)
                        : _buildSpectatorView(),
                  ),
                ],
              ),
            ),

            FloatingReactionOverlay(
              key: _reactionKey,
              sessionId: widget.session.id,
            ),
            const Positioned(bottom: 110, left: 24, child: LiveReactionBar()),
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
          title: Text('Battle Interrupted', style: SeedlingTypography.heading2),
          content: Text(
            'The host has terminated the battle. You will be returned to the garden.',
            style: SeedlingTypography.body.copyWith(
              color: SeedlingColors.textSecondary,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.popUntil(context, (route) => route.isFirst);
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

  Widget _buildLivingBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_bgController, _pulseController]),
      builder: (context, child) {
        final t = _bgController.value;
        final p = _pulseController.value;

        // Background color shifts Based on time urgency
        Color baseColor = SeedlingColors.seedlingGreen;
        double opacityFactor = 0.12;

        if (_secondsRemaining < 5) {
          baseColor = SeedlingColors.hibiscusRed;
          opacityFactor = 0.18 + (p * 0.05); // Pulsing opacity for urgency
        } else if (_secondsRemaining < 10) {
          baseColor = SeedlingColors.autumnGold;
          opacityFactor = 0.15;
        }

        return Stack(
          children: [
            // Orb 1: Pulsing Core - Shifts color and breathes
            Positioned(
              top: 100 + (math.sin(t * math.pi * 2) * 60),
              left: -80 + (math.cos(t * math.pi * 2) * 40),
              child: _Orb(
                size: 450 + (p * 80),
                color: baseColor.withValues(alpha: opacityFactor),
              ),
            ),
            // Orb 2: Dynamic Swirl - Contrasting color
            Positioned(
              bottom: 150 + (math.cos(t * math.pi * 2) * 100),
              right: -120 + (math.sin(t * math.pi * 2) * 60),
              child: _Orb(
                size: 550 + (p * 40),
                color:
                    (_secondsRemaining < 5
                            ? SeedlingColors.autumnGold
                            : SeedlingColors.water)
                        .withValues(alpha: 0.08),
              ),
            ),
            // Orb 3: Top Float
            Positioned(
              top: -50 + (math.sin(t * math.pi * 3) * 30),
              right: 20 + (math.cos(t * math.pi * 2) * 50),
              child: _Orb(size: 300, color: baseColor.withValues(alpha: 0.05)),
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

  Widget _buildBurstParticles() {
    return AnimatedBuilder(
      animation: _burstController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            _burstParticles,
            _burstController.value,
            _burstPosition,
          ),
        );
      },
    );
  }

  Widget _buildTimerBadge() {
    final urgencyColor = _secondsRemaining < 5
        ? SeedlingColors.hibiscusRed
        : (_secondsRemaining < 10 ? SeedlingColors.autumnGold : Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: urgencyColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          if (_secondsRemaining < 5)
            BoxShadow(
              color: urgencyColor.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: urgencyColor, size: 18),
          const SizedBox(width: 10),
          Text(
            '$_secondsRemaining',
            style: SeedlingTypography.heading3.copyWith(
              color: urgencyColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassQuestionCard(
    String article,
    String question,
    String pronunciation,
    String? gender,
    String pos,
    Color genderColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: (gender != null ? genderColor : Colors.white).withValues(
            alpha: 0.15,
          ),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (gender != null ? genderColor : SeedlingColors.seedlingGreen)
                .withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
          // Inner glow simulation
          if (gender != null)
            BoxShadow(
              color: genderColor.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: -10,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                if (pos.isNotEmpty || gender != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBadge(pos.toUpperCase(), Colors.white60),
                      if (gender != null) ...[
                        const SizedBox(width: 8),
                        _buildBadge(gender.toUpperCase(), genderColor),
                      ],
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (article.isNotEmpty)
                      Text(
                        '$article ',
                        style: SeedlingTypography.heading2.copyWith(
                          color: Colors.white38,
                          fontSize: 24,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        question,
                        textAlign: TextAlign.center,
                        style: SeedlingTypography.heading1.copyWith(
                          fontSize: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (pronunciation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    pronunciation,
                    style: SeedlingTypography.body.copyWith(
                      color: Colors.white38,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLeaderboard(LiveGameSession session) {
    // Sort players so the local user is drawn last (on top)
    final sortedPlayers = List<LivePlayer>.from(session.activePlayers);
    final myId = AuthService().userId;
    sortedPlayers.sort((a, b) {
      if (a.id == myId) return 1;
      if (b.id == myId) return -1;
      return a.id.compareTo(b.id);
    });

    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          const avatarWidth = 44.0;
          final maxTravel = trackWidth - avatarWidth;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Track background line
              Positioned(
                left: 0,
                right: 0,
                bottom: 34,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: SeedlingColors.water.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              // Finish line marker
              Positioned(
                right: 0,
                bottom: 25,
                child: Icon(
                  Icons.flag_circle_rounded,
                  color: SeedlingColors.autumnGold.withValues(alpha: 0.8),
                  size: 22,
                ),
              ),

              // Players
              ...sortedPlayers.map((player) {
                final isMe = player.id == myId;
                final status = player.lastAnswerStatus;

                Color glowColor = Colors.transparent;
                if (status == AnswerStatus.correct) {
                  glowColor = SeedlingColors.seedlingGreen;
                } else if (status == AnswerStatus.incorrect) {
                  glowColor = SeedlingColors.hibiscusRed;
                } else if (status == AnswerStatus.answered) {
                  glowColor = SeedlingColors.autumnGold;
                }

                final totalPoints = session.totalQuestions * 100.0;
                final progress = totalPoints > 0
                    ? (player.score / totalPoints).clamp(0.0, 1.0)
                    : 0.0;

                final leftPos = maxTravel * progress;

                return AnimatedPositioned(
                  key: ValueKey(player.id),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  left: leftPos,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (glowColor != Colors.transparent)
                            TweenAnimationBuilder(
                              key: ValueKey('${player.id}_$status'),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 600),
                              builder: (context, value, child) => Container(
                                width: avatarWidth + (value * 12),
                                height: avatarWidth + (value * 12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: glowColor.withValues(
                                      alpha: 1 - value,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          Container(
                            width: avatarWidth,
                            height: avatarWidth,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: isMe
                                    ? SeedlingColors.autumnGold
                                    : Colors.white24,
                                width: isMe ? 2 : 1.5,
                              ),
                              boxShadow: [
                                if (glowColor != Colors.transparent)
                                  BoxShadow(
                                    color: glowColor.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                if (isMe)
                                  BoxShadow(
                                    color: SeedlingColors.autumnGold.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 8,
                                  ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              player.avatarEmoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        player.displayName.split(' ')[0].toUpperCase(),
                        style: SeedlingTypography.caption.copyWith(
                          color: isMe
                              ? SeedlingColors.autumnGold
                              : Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildParticipantOptions(Color genderColor) {
    if (_currentWord == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
        ),
        itemBuilder: (context, index) =>
            _buildOptionCard(index, _currentWord!.options[index], genderColor),
      ),
    );
  }

  Widget _buildOptionCard(int index, String text, Color genderColor) {
    final correctIndex = _currentWord?.correctIndex ?? -1;
    bool isSelected = _selectedOption == index;
    bool isCorrect = _revealed && index == correctIndex;
    bool isWrongSelection = _revealed && isSelected && index != correctIndex;

    Color glowColor = Colors.transparent;
    if (_revealed) {
      if (isCorrect) {
        glowColor = SeedlingColors.seedlingGreen;
      } else if (isWrongSelection) {
        glowColor = SeedlingColors.hibiscusRed;
      }
    } else if (isSelected) {
      glowColor = SeedlingColors.autumnGold;
    }

    return GestureDetector(
      onTapDown: (details) => _onOptionSelected(index, details.localPosition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isSelected ? 0.15 : 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: glowColor != Colors.transparent
                ? glowColor
                : Colors.white.withValues(alpha: 0.1),
            width: glowColor != Colors.transparent ? 2.5 : 1,
          ),
          boxShadow: [
            if (glowColor != Colors.transparent)
              BoxShadow(
                color: glowColor.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: -2,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: SeedlingTypography.heading3.copyWith(
                      color: glowColor != Colors.transparent
                          ? Colors.white
                          : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.bold,
                    ),
                  ),
                  if (isSelected && isCorrect)
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(
                        Icons.stars_rounded,
                        color: SeedlingColors.autumnGold,
                        size: 16,
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

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    LiveGameSession session,
    bool isHost,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white10,
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
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
          // Progress bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${session.currentQuestionIndex + 1}/${session.totalQuestions}',
              style: SeedlingTypography.body.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48), // Spacer for balance
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: SeedlingTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSpectatorView() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Text(
            _revealed ? 'BATTLE FEED' : 'EYE OF THE STORM',
            style: SeedlingTypography.caption.copyWith(
              color: _revealed
                  ? SeedlingColors.seedlingGreen
                  : SeedlingColors.autumnGold,
              letterSpacing: 4,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 30),
          if (_revealed && _currentWord != null)
            Text(
              _currentWord!.options[_currentWord!.correctIndex].toUpperCase(),
              textAlign: TextAlign.center,
              style: SeedlingTypography.heading1.copyWith(
                color: Colors.white,
                letterSpacing: 2,
              ),
            )
          else ...[
            const CircularProgressIndicator(
              color: SeedlingColors.autumnGold,
              strokeWidth: 2,
            ),
            const SizedBox(height: 20),
            Text(
              'Warriors are choosing their path...',
              style: SeedlingTypography.body.copyWith(color: Colors.white38),
            ),
          ],
        ],
      ),
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
