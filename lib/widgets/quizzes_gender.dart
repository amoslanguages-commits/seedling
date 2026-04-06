import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/target_word_display.dart';

// ================================================================
// ARTICLE CHOICE QUIZ (Gender Challenge)
// ================================================================
// Displays the bare word stem and asks the learner to pick the
// correct grammatical article (der/die/das, le/la, el/la, etc.)
//
// Only shown when:
//  - word.hasTargetArticle == true
//  - word.primaryPOS == PartOfSpeech.noun
//  - word.masteryLevel >= 2
// ================================================================

/// Returns the set of articles for a given language code.
/// Returns null if the language does not use gendered articles.
List<String>? _articlesForLanguage(String langCode) {
  return switch (langCode.toLowerCase()) {
    'de' => ['der', 'die', 'das'], // German
    'nl' => ['de', 'het'], // Dutch
    'fr' => ['le', 'la', 'les'], // French
    'es' => ['el', 'la', 'los', 'las'], // Spanish
    'it' => ['il', 'la', 'lo', 'i', 'le', 'gli'], // Italian (simplified)
    'pt' => ['o', 'a', 'os', 'as'], // Portuguese
    _ => null,
  };
}

class ArticleChoiceQuiz extends StatefulWidget {
  final Word word;
  final void Function(
    bool correct,
    int masteryGained, [
    String? chosenWrongTranslation,
  ])
  onAnswer;

  const ArticleChoiceQuiz({
    super.key,
    required this.word,
    required this.onAnswer,
  });

  @override
  State<ArticleChoiceQuiz> createState() => _ArticleChoiceQuizState();
}

class _ArticleChoiceQuizState extends State<ArticleChoiceQuiz>
    with TickerProviderStateMixin {
  late AnimationController _bloomController;
  late AnimationController _shakeController;
  late AnimationController _entryController;
  late List<String> _displayArticles;
  String? _correctArticle;
  String? _selectedArticle;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();

    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // Determine correct article from word model
    _correctArticle = widget.word.targetArticle.isNotEmpty
        ? widget.word.targetArticle.toLowerCase().trim()
        : null;

    // Build the button set from the language's full article set
    final allArticles =
        _articlesForLanguage(widget.word.targetLanguageCode) ?? [];

    if (_correctArticle != null && allArticles.isNotEmpty) {
      // Italian has many articles — limit to 3 most common + the correct one
      final limited = allArticles.length > 4
          ? (allArticles..shuffle(math.Random())).take(3).toList()
          : List<String>.from(allArticles);

      if (!limited.contains(_correctArticle!)) {
        limited[limited.length - 1] = _correctArticle!;
      }
      limited.shuffle();
      _displayArticles = limited;
    } else {
      _displayArticles = [];
    }

    // Auto-play TTS so learner hears the word (without giving away article)
    TtsService.instance.speak(
      widget.word.word,
      widget.word.targetLanguageCode,
    );
  }

  @override
  void dispose() {
    _bloomController.dispose();
    _shakeController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _handleAnswer(String article) {
    if (_hasAnswered) return;
    final isCorrect = article == _correctArticle;

    setState(() {
      _selectedArticle = article;
      _hasAnswered = true;
    });

    if (isCorrect) {
      _bloomController.forward();
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _shakeController.forward(from: 0);
      AudioService.haptic(HapticType.wrong).ignore();
    }

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // If no articles available, skip gracefully
    if (_displayArticles.isEmpty || _correctArticle == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAnswer(true, 0); // skip silently
      });
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 620;

        return FadeTransition(
          opacity: _entryController,
          child: Column(
            children: [
              // ── Header card ─────────────────────────────────────────
              Container(
                margin: EdgeInsets.fromLTRB(24, isSmall ? 12 : 24, 24, 0),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 20 : 28,
                  vertical: isSmall ? 16 : 24,
                ),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.15,
                      ),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: SeedlingColors.morningDew.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botanical visual flair
                    CustomPaint(
                      size: Size(isSmall ? 40 : 50, isSmall ? 40 : 50),
                      painter: BotanicalArticleHeaderPainter(),
                    ),
                    SizedBox(height: isSmall ? 8 : 12),
                    Text(
                      'What is the article?',
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.textSecondary,
                        fontSize: isSmall ? 11 : 12,
                      ),
                    ),
                    SizedBox(height: isSmall ? 8 : 12),
                    // Show word WITHOUT article — learner must recall it
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Article result slot
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _bloomController,
                            _shakeController,
                          ]),
                          builder: (_, __) {
                            final shake =
                                math.sin(_shakeController.value * math.pi * 8) *
                                8 *
                                (1 - _shakeController.value);
                            return Transform.translate(
                              offset: Offset(shake, 0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: _hasAnswered
                                      ? (_selectedArticle == _correctArticle
                                            ? SeedlingColors.success.withValues(
                                                alpha: 0.2,
                                              )
                                            : SeedlingColors.error.withValues(
                                                alpha: 0.2,
                                              ))
                                      : SeedlingColors.morningDew.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _hasAnswered
                                        ? (_selectedArticle == _correctArticle
                                              ? SeedlingColors.success
                                              : SeedlingColors.error)
                                        : SeedlingColors.textSecondary
                                              .withValues(alpha: 0.3),
                                    width: _hasAnswered ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  _hasAnswered ? _correctArticle! : '___',
                                  style: SeedlingTypography.heading2.copyWith(
                                    fontSize: isSmall ? 24 : 30,
                                    color: _hasAnswered
                                        ? (_selectedArticle == _correctArticle
                                              ? SeedlingColors.success
                                              : SeedlingColors.error)
                                        : SeedlingColors.textSecondary
                                              .withValues(alpha: 0.5),
                                    fontStyle: _hasAnswered
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        TargetWordDisplay(
                          word: widget.word,
                          hideArticle: true,
                          style: SeedlingTypography.heading1.copyWith(
                            fontSize: isSmall ? 28 : 36,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.volume_up_rounded,
                            color: SeedlingColors.seedlingGreen,
                            size: isSmall ? 20 : 24,
                          ),
                          onPressed: () => TtsService.instance.speak(
                            widget.word.word,
                            widget.word.targetLanguageCode,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Gender color legend (shown before answering) ────────
              if (!_hasAnswered) ...[
                SizedBox(height: isSmall ? 8 : 12),
                _buildGenderLegend(context),
              ],

              const Spacer(),

              // ── Article buttons ─────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, isSmall ? 20 : 32),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: _displayArticles.map((article) {
                    final isSelected = _selectedArticle == article;
                    final isCorrectThis = article == _correctArticle;

                    Color bgColor = SeedlingColors.cardBackground;
                    Color borderColor = SeedlingColors.morningDew.withValues(
                      alpha: 0.4,
                    );
                    Color textColor = SeedlingColors.textPrimary;

                    if (_hasAnswered) {
                      if (isCorrectThis) {
                        bgColor = SeedlingColors.success.withValues(alpha: 0.2);
                        borderColor = SeedlingColors.success;
                        textColor = SeedlingColors.success;
                      } else if (isSelected && !isCorrectThis) {
                        bgColor = SeedlingColors.error.withValues(alpha: 0.15);
                        borderColor = SeedlingColors.error;
                        textColor = SeedlingColors.error;
                      }
                    } else if (isSelected) {
                      bgColor = SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.12,
                      );
                      borderColor = SeedlingColors.seedlingGreen;
                    }

                    return GestureDetector(
                      onTap: () => _handleAnswer(article),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 28 : 36,
                          vertical: isSmall ? 16 : 20,
                        ),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: SeedlingColors.seedlingGreen.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasAnswered && isCorrectThis)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.check_circle,
                                  color: SeedlingColors.success,
                                  size: 18,
                                ),
                              ),
                            if (_hasAnswered && isSelected && !isCorrectThis)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.cancel,
                                  color: SeedlingColors.error,
                                  size: 18,
                                ),
                              ),
                            Text(
                              article,
                              style: SeedlingTypography.heading2.copyWith(
                                fontSize: isSmall ? 18 : 22,
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGenderLegend(BuildContext context) {
    final lang = widget.word.targetLanguageCode.toLowerCase();

    // Only show legend for German (most learner-relevant)
    if (lang != 'de') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendDot(const Color(0xFF5C9BD6), 'der — masculine'),
          const SizedBox(width: 16),
          _legendDot(const Color(0xFFE57373), 'die — feminine'),
          const SizedBox(width: 16),
          _legendDot(const Color(0xFF81C784), 'das — neuter'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: SeedlingTypography.caption.copyWith(
            fontSize: 10,
            color: SeedlingColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class BotanicalArticleHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw an elegant double leaf pattern
    final paint = Paint()
      ..color = SeedlingColors.freshSprout.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // Left leaf
    final pathLeft = Path()
      ..moveTo(center.dx, center.dy + size.height * 0.3)
      ..quadraticBezierTo(
        center.dx - size.width * 0.4,
        center.dy + size.height * 0.1,
        center.dx - size.width * 0.3,
        center.dy - size.height * 0.2,
      )
      ..quadraticBezierTo(
        center.dx - size.width * 0.1,
        center.dy - size.height * 0.2,
        center.dx,
        center.dy + size.height * 0.3,
      );

    // Right leaf
    final pathRight = Path()
      ..moveTo(center.dx, center.dy + size.height * 0.3)
      ..quadraticBezierTo(
        center.dx + size.width * 0.4,
        center.dy + size.height * 0.1,
        center.dx + size.width * 0.3,
        center.dy - size.height * 0.3,
      )
      ..quadraticBezierTo(
        center.dx + size.width * 0.1,
        center.dy - size.height * 0.1,
        center.dx,
        center.dy + size.height * 0.3,
      );

    canvas.drawPath(pathLeft, paint);
    canvas.drawPath(
      pathRight,
      paint..color = SeedlingColors.sunlight.withValues(alpha: 0.9),
    );

    // Draw small stem
    final stemPaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx, center.dy + size.height * 0.3),
      Offset(center.dx, center.dy + size.height * 0.5),
      stemPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
