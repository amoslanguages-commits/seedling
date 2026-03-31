import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/social.dart';
import '../../models/word.dart';
import '../../providers/app_providers.dart';
import '../../widgets/quizzes.dart'; 
import '../../widgets/mascot.dart';
import '../../services/audio_service.dart';

class LiveDuelScreen extends ConsumerStatefulWidget {
  final Friend opponent;
  
  const LiveDuelScreen({
    super.key,
    required this.opponent,
  });

  @override
  ConsumerState<LiveDuelScreen> createState() => _LiveDuelScreenState();
}

class _LiveDuelScreenState extends ConsumerState<LiveDuelScreen> with TickerProviderStateMixin {
  int _playerScore = 0;
  int _opponentScore = 0;
  int _timeLeft = 60; 
  Timer? _gameTimer;
  Timer? _opponentTimer;
  bool _isGameOver = false;
  
  List<Word> _duelWords = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  
  int _playerStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final db = ref.read(databaseProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);
    
    final words = await db.getWordsForLanguage(nativeLang, targetLang, limit: 30);
    
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
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _endGame();
      }
    });

    _opponentTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (_isGameOver) return;
      if (Random().nextDouble() > 0.3) {
        setState(() => _opponentScore += 10);
      }
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    _opponentTimer?.cancel();
    AudioService.instance.stopAmbient();
    AudioService.instance.play(SFX.sessionComplete);
    AudioService.haptic(HapticType.sessionComplete).ignore();
    setState(() {
      _isGameOver = true;
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _opponentTimer?.cancel();
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
      setState(() {
        _playerScore += 15;
        _playerStreak++;
      });
    } else {
      AudioService.instance.play(SFX.wrongAnswer);
      setState(() {
        _playerStreak = 0;
      });
    }
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && !_isGameOver) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _duelWords.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SeedlingColors.background,
        body: Center(child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen)),
      );
    }

    if (_isGameOver) {
      return _buildGameOverScreen();
    }

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildDuelHeader(),
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    bottom: 0,
                    top: 0,
                    width: 20,
                    child: _buildVerticalVine(_opponentScore / 200.0, SeedlingColors.warning),
                  ),
                  
                  Positioned(
                    right: 20,
                    bottom: 0,
                    top: 0,
                    width: 20,
                    child: _buildVerticalVine(_playerScore / 200.0, SeedlingColors.seedlingGreen),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    child: _buildQuizContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuelHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: SeedlingColors.cardBackground,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: SeedlingColors.warning,
                child: Text(
                  widget.opponent.displayName[0],
                  style: SeedlingTypography.heading3.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$_opponentScore',
                style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.warning),
              ),
            ],
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: SeedlingColors.deepRoot,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '0:${_timeLeft.toString().padLeft(2, '0')}',
              style: SeedlingTypography.heading2.copyWith(color: Colors.white),
            ),
          ),
          
          Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: SeedlingColors.seedlingGreen,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(
                '$_playerScore',
                style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.seedlingGreen),
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
                color: SeedlingColors.morningDew.withOpacity(0.3),
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
                    color: color.withOpacity(0.5),
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
              color: SeedlingColors.sunlight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SeedlingColors.sunlight, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, color: SeedlingColors.sunlight),
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
            onAnswer: (correct, _) => _handleAnswer(correct),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverScreen() {
    final isWinner = _playerScore > _opponentScore;
    final isTie = _playerScore == _opponentScore;
    
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
                color: isTie ? SeedlingColors.textPrimary : (isWinner ? SeedlingColors.success : SeedlingColors.error),
                fontSize: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Final Score",
              style: SeedlingTypography.heading3,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'You: $_playerScore',
                  style: SeedlingTypography.heading2.copyWith(color: SeedlingColors.seedlingGreen),
                ),
                const SizedBox(width: 40),
                Text(
                  '${widget.opponent.displayName}: $_opponentScore',
                  style: SeedlingTypography.heading2.copyWith(color: SeedlingColors.warning),
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
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
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
