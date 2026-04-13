import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../services/haptic_service.dart';
import '../../services/audio_service.dart';
import '../../services/tts_service.dart'; // Voice Synthesis
import '../../services/usage_service.dart';
import '../../providers/review_provider.dart';
import '../../providers/app_providers.dart'; // For targetLanguage
import '../../models/word.dart';

class McqReviewSessionScreen extends ConsumerStatefulWidget {
  const McqReviewSessionScreen({super.key});

  @override
  ConsumerState<McqReviewSessionScreen> createState() => _McqReviewSessionScreenState();
}

class _McqReviewSessionScreenState extends ConsumerState<McqReviewSessionScreen> with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _bloomController;
  late AnimationController _optionsController;
  
  // Duration used for the timer - null means no timer
  Duration? _timerDuration;
  // Track the status listener so we can remove it before re-adding
  AnimationStatusListener? _timerStatusListener;

  DateTime? _questionStartTime;
  bool _isAnswered = false;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _optionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // Initialize with a safe duration; _setupTimer() will configure it properly
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    final session = ref.read(reviewSessionProvider);
    if (session.words.isEmpty || session.currentWord == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Nothing to review in this session.')),
        );
        Navigator.of(context).pop();
      });
      return;
    }

    _setupTimer();
    _startBloom();
    Future.microtask(() {
      if (mounted) _playTts();
    });
  }

  void _startBloom() {
    _bloomController.reset();
    _optionsController.reset();
    _bloomController.forward();
    _optionsController.forward();
  }

  void _playTts() async {
    if (!mounted) return;
    try {
      await TtsService.instance.stop();
      if (!mounted) return;
      final session = ref.read(reviewSessionProvider);
      final word = session.currentWord;
      if (word != null) {
        final targetLang = ref.read(currentLanguageProvider);
        TtsService.instance.speak(word.word, targetLang);
      }
    } catch (e) {
      // TTS may not be supported on all platforms (e.g. Windows) — fail silently
      debugPrint('TTS playback skipped: $e');
    }
  }

  void _setupTimer() {
    final timerMode = ref.read(reviewTimerProvider);
    final seconds = timerMode.seconds;

    // SAFE: Stop the controller and remove the old status listener before
    // reconfiguring, so we never crash from a disposed/rebuilt controller.
    _timerController.stop();
    if (_timerStatusListener != null) {
      _timerController.removeStatusListener(_timerStatusListener!);
      _timerStatusListener = null;
    }
    _timerDuration = seconds != null ? Duration(seconds: seconds) : null;

    if (seconds != null) {
      _timerController.duration = Duration(seconds: seconds);
      _timerStatusListener = (status) {
        if (status == AnimationStatus.completed && !_isAnswered) {
          _submitSelection(-1); // Timeout
        }
      };
      _timerController.addStatusListener(_timerStatusListener!);
      _timerController.forward(from: 0);
    } else {
      _timerController.duration = const Duration(seconds: 1);
    }
    _questionStartTime = DateTime.now();
  }

  void _submitSelection(int index) async {
    if (_isAnswered) return;
    setState(() {
      _isAnswered = true;
      _selectedIndex = index;
    });
    
    _timerController.stop();
    final responseTime = DateTime.now().difference(_questionStartTime!);
    final session = ref.read(reviewSessionProvider);
    final currentWord = session.currentWord;
    
    if (currentWord == null) return;

    bool isCorrect = index != -1 && currentWord.options[index] == currentWord.translation;
    
    if (isCorrect) {
      AudioService.instance.playCorrect();
      HapticService.mediumImpact();
    } else {
      AudioService.instance.play(SFX.wrongAnswer);
      HapticService.heavyImpact();
    }

    await Future.delayed(const Duration(milliseconds: 600));
    final String? selectedTranslation = index != -1 ? currentWord.options[index] : null;
    await ref.read(reviewSessionProvider.notifier).submitRating(isCorrect, responseTime, selectedTranslation: selectedTranslation);
    await UsageService().logReviewTime(responseTime.inSeconds);

    if (mounted) {
      if (ref.read(reviewSessionProvider).isCompleted) {
        // Show completion logic or Navigator.pop
        _showResults();
      } else {
        _nextQuestion();
      }
    }
  }

  void _nextQuestion() {
    setState(() {
      _isAnswered = false;
      _selectedIndex = null;
    });
    _setupTimer();
    _startBloom();
    _playTts();
  }

  void _showResults() {
    HapticService.heavyImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GardenGrowthSummary(
          session: ref.read(reviewSessionProvider),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _timerController.dispose();
    _bloomController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(reviewSessionProvider);
    final word = session.currentWord;

    if (word == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      _buildTopBar(session),
                      const Expanded(flex: 2, child: SizedBox(height: 16)),
                      _buildQuestionCard(word),
                      const Expanded(flex: 3, child: SizedBox(height: 24)),
                      _buildOptions(word),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildTopBar(ReviewSessionState session) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: CustomPaint(
            painter: VineProgressPainter(progress: session.progress),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: SeedlingColors.textSecondary, size: 20),
              ),
            ),
            _buildTimerRing(),
            const SizedBox(width: 48), // Balancing spacer
          ],
        ),
      ],
    );
  }

  Widget _buildTimerRing() {
    final timerMode = ref.read(reviewTimerProvider);
    if (timerMode == ReviewTimerMode.none) return const SizedBox(height: 50, width: 50);

    return AnimatedBuilder(
      animation: _timerController,
      builder: (context, child) {
        final seconds = _timerDuration?.inSeconds ?? timerMode.seconds ?? 1;
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 50,
              width: 50,
              child: CircularProgressIndicator(
                value: 1 - _timerController.value,
                strokeWidth: 4,
                color: _timerController.value > 0.8 ? Colors.redAccent : const Color(0xFF6B3FA0),
                backgroundColor: SeedlingColors.cardBackground,
              ),
            ),
            Text(
              '${(seconds * (1 - _timerController.value)).ceil()}',
              style: SeedlingTypography.caption.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestionCard(Word word) {
    return FadeTransition(
      opacity: _bloomController,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _bloomController, curve: Curves.elasticOut),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  word.word,
                  style: SeedlingTypography.heading1.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: SeedlingColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _playTts,
                    icon: const Icon(Icons.volume_up_rounded, color: SeedlingColors.seedlingGreen, size: 24),
                    tooltip: 'Play Pronunciation',
                  ),
                ),
              ],
            ),
            if (word.pronunciation != null)
               Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text(
                   word.pronunciation!,
                   style: SeedlingTypography.body.copyWith(
                     color: SeedlingColors.textSecondary,
                     fontSize: 18,
                     letterSpacing: 2,
                   ),
                 ),
               ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(Word word) {
    final options = word.options;
    return Column(
      children: List.generate(options.length, (i) {
        final opt = options[i];
        final isSelected = _selectedIndex == i;
        final isCorrect = opt == word.translation;
        
        Color cardColor = SeedlingColors.cardBackground;
        double scale = 1.0;
        double opacity = 1.0;

        if (_isAnswered) {
          if (isCorrect) {
            // Golden Bloom!
            cardColor = SeedlingColors.sunlight.withValues(alpha: 0.15);
            scale = 1.03;
          } else {
            if (isSelected) cardColor = Colors.redAccent.withValues(alpha: 0.15);
             scale = 0.9;
             opacity = 0.4;
          }
        }

        final stagger = CurvedAnimation(
          parent: _optionsController,
          curve: Interval(i * 0.1, (i * 0.1 + 0.4).clamp(0, 1), curve: Curves.easeOutCubic),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeTransition(
            opacity: stagger,
            child: SlideTransition(
              position: stagger.drive(Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)),
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 400),
                  child: InkWell(
                    onTap: () => _submitSelection(i),
                    borderRadius: BorderRadius.circular(28),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: _isAnswered && isCorrect 
                            ? SeedlingColors.sunlight 
                            : (_isAnswered && isSelected ? Colors.redAccent : Colors.white.withValues(alpha: 0.03)),
                          width: 2,
                        ),
                        boxShadow: [
                          if (_isAnswered && isCorrect)
                            BoxShadow(
                              color: SeedlingColors.sunlight.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                        ],
                      ),
                      child: Text(
                        opt,
                        style: SeedlingTypography.heading3.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _isAnswered && isCorrect ? SeedlingColors.sunlight : SeedlingColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class VineProgressPainter extends CustomPainter {
  final double progress;
  VineProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SeedlingColors.seedlingGreen.withValues(alpha: 0.2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height / 2);
    
    // Draw a winding vine
    for (double i = 0; i < size.width; i += 10) {
      path.lineTo(i, size.height / 2 + (5 * (i % 20 == 0 ? 1 : -1)));
    }
    
    canvas.drawPath(path, paint);

    final activePaint = Paint()
      ..color = SeedlingColors.seedlingGreen
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final activePath = Path();
    activePath.moveTo(0, size.height / 2);
    final limit = size.width * progress;
    
    for (double i = 0; i < limit; i += 2) {
      activePath.lineTo(i, size.height / 2 + (5 * ((i/10).floor() % 2 == 0 ? 1 : -1)));
    }
    
    canvas.drawPath(activePath, activePaint);

    // Draw little leaves/blooms
    final bloomPaint = Paint()..style = PaintingStyle.fill;
    for (int j = 1; j <= 5; j++) {
      final x = (size.width / 6) * j;
      final isBloomed = progress >= (j / 6);
      bloomPaint.color = isBloomed ? SeedlingColors.seedlingGreen : SeedlingColors.cardBackground;
      
      canvas.drawCircle(Offset(x, size.height / 2), isBloomed ? 6 : 3, bloomPaint);
      if (isBloomed) {
         canvas.drawCircle(Offset(x, size.height / 2), 8, Paint()..color = SeedlingColors.seedlingGreen.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 1);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GardenGrowthSummary extends StatelessWidget {
  final ReviewSessionState session;
  const GardenGrowthSummary({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    // [results] values: 3 = correct, 1 = wrong (see [ReviewSessionNotifier.submitRating]).
    final correctCount = session.results.values.where((v) => v >= 3).length;
    final total = session.words.length;
    final accuracyPct = total == 0 ? 0 : (correctCount / total * 100).round();

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -100,
            right: -100,
            child: Icon(Icons.eco_rounded, size: 400, color: SeedlingColors.seedlingGreen.withValues(alpha: 0.03)),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: SeedlingColors.cardBackground,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: SeedlingColors.seedlingGreen, size: 48),
                        ),
                        const SizedBox(height: 32),
                        Text('Garden Flourishing!', style: SeedlingTypography.heading1.copyWith(fontSize: 32)),
                        const SizedBox(height: 12),
                        Text(
                          'Your consistent tending has strengthened the roots of your vocabulary.',
                          style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSummaryStat('Mastery', '$accuracyPct%', Icons.bolt_rounded),
                            _buildSummaryStat('Roots', '$total', Icons.spa_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SeedlingColors.seedlingGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Return to Forest', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: SeedlingColors.textSecondary, size: 24),
        const SizedBox(height: 8),
        Text(value, style: SeedlingTypography.heading2.copyWith(fontSize: 28, fontWeight: FontWeight.w900)),
        Text(label, style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary, letterSpacing: 1.2)),
      ],
    );
  }
}
