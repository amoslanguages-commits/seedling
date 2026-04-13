import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/sentence_item.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  FILL THE BRANCH QUIZ
//  Shows: target sentence with the key word blanked ("___")
//  Options: target-language words — pick the correct one to fill the gap
// ══════════════════════════════════════════════════════════════════════════════

class FillTheBranchQuiz extends StatefulWidget {
  final SentenceItem item;

  /// Must include [item.targetWord] as one of the options.
  final List<String> options;
  final void Function(bool correct) onAnswer;

  const FillTheBranchQuiz({
    super.key,
    required this.item,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<FillTheBranchQuiz> createState() => _FillTheBranchQuizState();
}

class _FillTheBranchQuizState extends State<FillTheBranchQuiz>
    with TickerProviderStateMixin {
  late final AnimationController _bloomCtrl;
  late final AnimationController _shakeCtrl;
  int? _selectedIndex;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    // Speak the key word for audio context
    TtsService.instance.speak(
      widget.item.targetWord,
      widget.item.targetLangCode,
    );
    _bloomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _bloomCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _handleAnswer(int index) {
    if (_hasAnswered) return;
    final isCorrect = widget.options[index] == widget.item.targetWord;
    setState(() {
      _selectedIndex = index;
      _hasAnswered = true;
    });
    if (isCorrect) {
      _bloomCtrl.forward();
      AudioService.instance.playCorrect();
      AudioService.haptic(HapticType.correct).ignore();
      // Speak the full sentence once answered correctly
      Future.delayed(const Duration(milliseconds: 300), () {
        TtsService.instance.speak(
          widget.item.targetSentence,
          widget.item.targetLangCode,
        );
      });
    } else {
      _shakeCtrl.forward(from: 0);
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();
    }
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onAnswer(isCorrect);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 620;
        return Column(
          children: [
            // ── Branch Visualization ────────────────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_bloomCtrl, _shakeCtrl]),
              builder: (_, __) {
                final shake =
                    math.sin(_shakeCtrl.value * math.pi * 8) *
                    10 *
                    (1 - _shakeCtrl.value);
                final isWrong =
                    _hasAnswered &&
                    _selectedIndex != null &&
                    widget.options[_selectedIndex!] != widget.item.targetWord;
                return Transform.translate(
                  offset: Offset(shake, 0),
                  child: SizedBox(
                    height: isSmall ? 110 : 140,
                    child: CustomPaint(
                      size: Size(double.infinity, isSmall ? 110 : 140),
                      painter: _BranchPainter(
                        bloomProgress: _bloomCtrl.value,
                        isWrong: isWrong,
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Sentence Card ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isSmall ? 8 : 14,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isSmall ? 14 : 20,
                ),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.08,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Fill in the missing word',
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.textSecondary,
                        fontSize: isSmall ? 11 : 12,
                      ),
                    ),
                    SizedBox(height: isSmall ? 10 : 14),
                    _SentenceWithGap(
                      gapped: widget.item.gappedSentence,
                      revealWord: _hasAnswered ? widget.item.targetWord : null,
                      isCorrect:
                          _hasAnswered &&
                          _selectedIndex != null &&
                          widget.options[_selectedIndex!] ==
                              widget.item.targetWord,
                      fontSize: isSmall ? 17.0 : 21.0,
                    ),
                    SizedBox(height: isSmall ? 8 : 12),
                    // Native hint: show complete sentence without blank
                    Text(
                      widget.item.fullNativeSentence,
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.textSecondary.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: isSmall ? 12 : 13,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // Audio replay
                    GestureDetector(
                      onTap: () {
                        AudioService.haptic(HapticType.selection).ignore();
                        TtsService.instance.speak(
                          widget.item.targetWord,
                          widget.item.targetLangCode,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.volume_up_rounded,
                          color: SeedlingColors.seedlingGreen,
                          size: isSmall ? 18 : 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // ── Options Grid 2×2 ───────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, isSmall ? 12 : 20),
              child: _OptionsGrid(
                options: widget.options,
                selectedIndex: _selectedIndex,
                hasAnswered: _hasAnswered,
                correctAnswer: widget.item.targetWord,
                isSmall: isSmall,
                onTap: _handleAnswer,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TRANSLATION SPRINT QUIZ
//  Shows: full target-language sentence
//  Options: native-language words — identify what the highlighted word means
// ══════════════════════════════════════════════════════════════════════════════

class TranslationSprintQuiz extends StatefulWidget {
  final SentenceItem item;

  /// Must include [item.nativeWord] as one of the options.
  final List<String> options;
  final void Function(bool correct) onAnswer;

  const TranslationSprintQuiz({
    super.key,
    required this.item,
    required this.options,
    required this.onAnswer,
  });

  @override
  State<TranslationSprintQuiz> createState() => _TranslationSprintQuizState();
}

class _TranslationSprintQuizState extends State<TranslationSprintQuiz>
    with TickerProviderStateMixin {
  late final AnimationController _bloomCtrl;
  late final AnimationController _shakeCtrl;
  int? _selectedIndex;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.speak(
      widget.item.targetSentence,
      widget.item.targetLangCode,
    );
    _bloomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _bloomCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _handleAnswer(int index) {
    if (_hasAnswered) return;
    final isCorrect = widget.options[index] == widget.item.nativeWord;
    setState(() {
      _selectedIndex = index;
      _hasAnswered = true;
    });
    if (isCorrect) {
      _bloomCtrl.forward();
      AudioService.instance.playCorrect();
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _shakeCtrl.forward(from: 0);
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();
    }
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onAnswer(isCorrect);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 620;
        return Column(
          children: [
            // ── Branch Visualization ────────────────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_bloomCtrl, _shakeCtrl]),
              builder: (_, __) {
                final shake =
                    math.sin(_shakeCtrl.value * math.pi * 8) *
                    10 *
                    (1 - _shakeCtrl.value);
                final isWrong =
                    _hasAnswered &&
                    _selectedIndex != null &&
                    widget.options[_selectedIndex!] != widget.item.nativeWord;
                return Transform.translate(
                  offset: Offset(shake, 0),
                  child: SizedBox(
                    height: isSmall ? 110 : 140,
                    child: CustomPaint(
                      size: Size(double.infinity, isSmall ? 110 : 140),
                      painter: _BranchPainter(
                        bloomProgress: _bloomCtrl.value,
                        isWrong: isWrong,
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Sentence Card ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isSmall ? 8 : 14,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isSmall ? 14 : 20,
                ),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: SeedlingColors.water.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.water.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'What does the highlighted word mean?',
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.textSecondary,
                        fontSize: isSmall ? 11 : 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmall ? 10 : 14),
                    // Full target sentence with key word highlighted
                    _SentenceWithHighlight(
                      sentence: widget.item.targetSentence,
                      highlightWord: widget.item.targetWord,
                      fontSize: isSmall ? 17.0 : 21.0,
                      revealNative: _hasAnswered
                          ? widget.item.nativeWord
                          : null,
                      isCorrect:
                          _hasAnswered &&
                          _selectedIndex != null &&
                          widget.options[_selectedIndex!] ==
                              widget.item.nativeWord,
                    ),
                    // Audio replay
                    GestureDetector(
                      onTap: () {
                        AudioService.haptic(HapticType.selection).ignore();
                        TtsService.instance.speak(
                          widget.item.targetSentence,
                          widget.item.targetLangCode,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Icon(
                          Icons.volume_up_rounded,
                          color: SeedlingColors.water,
                          size: isSmall ? 18 : 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // ── Options Grid 2×2 ───────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, isSmall ? 12 : 20),
              child: _OptionsGrid(
                options: widget.options,
                selectedIndex: _selectedIndex,
                hasAnswered: _hasAnswered,
                correctAnswer: widget.item.nativeWord,
                isSmall: isSmall,
                onTap: _handleAnswer,
                accentColor: SeedlingColors.water,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED UTILITIES
// ══════════════════════════════════════════════════════════════════════════════

/// Renders a sentence with "___" gap; after answering, the gap is revealed
/// with success/error colouring.
class _SentenceWithGap extends StatelessWidget {
  final String gapped;
  final String? revealWord;
  final bool isCorrect;
  final double fontSize;

  const _SentenceWithGap({
    required this.gapped,
    required this.revealWord,
    required this.isCorrect,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final parts = gapped.split('___');
    final before = parts.isNotEmpty ? parts[0] : '';
    final after = parts.length > 1 ? parts[1] : '';
    final gapColor = revealWord != null
        ? (isCorrect ? SeedlingColors.success : SeedlingColors.error)
        : SeedlingColors.seedlingGreen;
        
    final bool isRevealed = revealWord != null;

    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: SeedlingTypography.bodyLarge.copyWith(
            fontSize: fontSize,
            color: SeedlingColors.textPrimary,
            height: 1.6,
          ),
          children: [
            TextSpan(text: before),
            WidgetSpan(
               alignment: PlaceholderAlignment.baseline,
               baseline: TextBaseline.alphabetic,
               child: TweenAnimationBuilder<double>(
                  key: ValueKey(isRevealed), // Forces restart when revealed
                  tween: Tween<double>(begin: isRevealed ? 0.3 : 1.0, end: 1.0),
                  duration: isRevealed ? const Duration(milliseconds: 600) : Duration.zero,
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                     return Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomCenter,
                        child: Text(
                          revealWord ?? '___',
                          style: TextStyle(
                            fontSize: fontSize,
                            color: gapColor,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: gapColor,
                            decorationThickness: 2,
                            fontFamily: SeedlingTypography.bodyLarge.fontFamily,
                          ),
                        ),
                     );
                  },
               ),
            ),
            TextSpan(text: after),
          ],
        ),
      ),
    );
  }
}

/// Renders a full sentence with the key word highlighted via underline/bold;
/// after answering, shows its native translation below it.
class _SentenceWithHighlight extends StatelessWidget {
  final String sentence;
  final String highlightWord;
  final double fontSize;
  final String? revealNative;
  final bool isCorrect;

  const _SentenceWithHighlight({
    required this.sentence,
    required this.highlightWord,
    required this.fontSize,
    required this.revealNative,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final idx = sentence.toLowerCase().indexOf(highlightWord.toLowerCase());
    if (idx < 0) {
      return Text(
        sentence,
        textAlign: TextAlign.center,
        style: SeedlingTypography.bodyLarge.copyWith(
          fontSize: fontSize,
          height: 1.6,
        ),
      );
    }
    final before = sentence.substring(0, idx);
    final word = sentence.substring(idx, idx + highlightWord.length);
    final after = sentence.substring(idx + highlightWord.length);

    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: SeedlingTypography.bodyLarge.copyWith(
              fontSize: fontSize,
              color: SeedlingColors.textPrimary,
              height: 1.6,
            ),
            children: [
              TextSpan(text: before),
              TextSpan(
                text: word,
                style: const TextStyle(
                  color: SeedlingColors.water,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: SeedlingColors.water,
                  decorationThickness: 2.5,
                ),
              ),
              TextSpan(text: after),
            ],
          ),
        ),
        if (revealNative != null) ...[
          const SizedBox(height: 8),
          Text(
            '"${revealNative!}"',
            style: SeedlingTypography.caption.copyWith(
              color: isCorrect ? SeedlingColors.success : SeedlingColors.error,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// A 2×2 option button grid.
class _OptionsGrid extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final bool hasAnswered;
  final String correctAnswer;
  final bool isSmall;
  final void Function(int) onTap;
  final Color accentColor;

  const _OptionsGrid({
    required this.options,
    required this.selectedIndex,
    required this.hasAnswered,
    required this.correctAnswer,
    required this.isSmall,
    required this.onTap,
    this.accentColor = SeedlingColors.seedlingGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: isSmall ? 2.8 : 2.6,
      children: List.generate(options.length, (i) {
        if (i >= 4) return const SizedBox.shrink();
        final opt = options[i];
        final isSelected = selectedIndex == i;
        final isCorrect = opt == correctAnswer;

        Color bg = SeedlingColors.cardBackground;
        Color border = SeedlingColors.morningDew.withValues(alpha: 0.35);
        Color textColor = SeedlingColors.textPrimary;

        if (hasAnswered) {
          if (isCorrect) {
            bg = SeedlingColors.success.withValues(alpha: 0.15);
            border = SeedlingColors.success;
            textColor = SeedlingColors.success;
          } else if (isSelected) {
            bg = SeedlingColors.error.withValues(alpha: 0.12);
            border = SeedlingColors.error;
            textColor = SeedlingColors.error;
          }
        } else if (isSelected) {
          bg = accentColor.withValues(alpha: 0.12);
          border = accentColor;
          textColor = accentColor;
        }

        return GestureDetector(
          onTap: () {
            AudioService.haptic(HapticType.selection).ignore();
            onTap(i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.5),
              boxShadow: isSelected && !hasAnswered
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    opt,
                    style: SeedlingTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmall ? 13 : 15,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasAnswered && isCorrect) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: SeedlingColors.success,
                    size: 16,
                  ),
                ],
                if (hasAnswered && isSelected && !isCorrect) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.cancel_rounded,
                    color: SeedlingColors.error,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BRANCH CUSTOM PAINTER
//  A botanical branch with 5 leaf positions; position 2 (centre) is the
//  "missing bud" that blooms on a correct answer.
// ══════════════════════════════════════════════════════════════════════════════

class _BranchPainter extends CustomPainter {
  final double bloomProgress; // 0.0 → 1.0
  final bool isWrong;

  static const int _leafCount = 5;
  static const int _budIdx = 2;

  const _BranchPainter({required this.bloomProgress, required this.isWrong});

  // ── Cubic bezier helpers ──────────────────────────────────────────────────
  double _bezierX(double x0, double x1, double x2, double x3, double t) {
    final m = 1 - t;
    return m * m * m * x0 +
        3 * m * m * t * x1 +
        3 * m * t * t * x2 +
        t * t * t * x3;
  }

  double _bezierY(double y0, double y1, double y2, double y3, double t) {
    final m = 1 - t;
    return m * m * m * y0 +
        3 * m * m * t * y1 +
        3 * m * t * t * y2 +
        t * t * t * y3;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Control points for the gracefully curving branch
    const double bx0 = 0.04, bx1 = 0.28, bx2 = 0.72, bx3 = 0.96;
    const double by0 = 0.60, by1 = 0.35, by2 = 0.75, by3 = 0.52;

    // ── Draw main branch ──────────────────────────────────────────────────
    final branchPaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    final branchPath = Path()
      ..moveTo(w * bx0, h * by0)
      ..cubicTo(w * bx1, h * by1, w * bx2, h * by2, w * bx3, h * by3);
    canvas.drawPath(branchPath, branchPaint);

    // ── Compute leaf positions along bezier ───────────────────────────────
    for (int i = 0; i < _leafCount; i++) {
      if (i == _budIdx) continue; // drawn separately below
      final t = i / (_leafCount - 1);
      final x = _bezierX(w * bx0, w * bx1, w * bx2, w * bx3, t);
      final y = _bezierY(h * by0, h * by1, h * by2, h * by3, t);
      final above = i.isOdd;
      _drawLeaf(canvas, x, y, above, 1.0, SeedlingColors.freshSprout);
    }

    // ── Draw the bud / blooming / wilted leaf at budIdx ───────────────────
    const budT = _budIdx / (_leafCount - 1);
    final budX = _bezierX(w * bx0, w * bx1, w * bx2, w * bx3, budT);
    final budY = _bezierY(h * by0, h * by1, h * by2, h * by3, budT);
    final budAbove = _budIdx.isOdd;

    if (bloomProgress > 0 && !isWrong) {
      _drawBloomingLeaf(canvas, budX, budY, budAbove, bloomProgress);
    } else if (isWrong) {
      _drawWiltedBud(canvas, budX, budY, budAbove);
    } else {
      _drawBud(canvas, budX, budY, budAbove);
    }
  }

  void _drawLeaf(
    Canvas canvas,
    double x,
    double y,
    bool above,
    double scale,
    Color color,
  ) {
    if (scale <= 0) return;
    final dir = above ? -1.0 : 1.0;
    final stemLen = 14.0 * scale;
    final leafLen = 20.0 * scale;
    final leafW = 9.0 * scale;

    // stem
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + dir * stemLen),
      Paint()
        ..color = SeedlingColors.soil.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    // leaf body
    final tip = Offset(x, y + dir * (stemLen + leafLen));
    final base = Offset(x, y + dir * stemLen);
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
        base.dx - leafW,
        base.dy + dir * leafLen * 0.55,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        base.dx + leafW,
        base.dy + dir * leafLen * 0.55,
        base.dx,
        base.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _drawBud(Canvas canvas, double x, double y, bool above) {
    final dir = above ? -1.0 : 1.0;
    // Short dashed stem
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + dir * 12),
      Paint()
        ..color = SeedlingColors.seedlingGreen.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Unfilled bud circle
    final center = Offset(x, y + dir * 20);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = SeedlingColors.morningDew.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = SeedlingColors.seedlingGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    // Small "?" hint dots
    for (int dot = 0; dot < 3; dot++) {
      canvas.drawCircle(
        Offset(x, y + dir * (19 - dot * 3.0)),
        1.2,
        Paint()
          ..color = SeedlingColors.seedlingGreen.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawBloomingLeaf(
    Canvas canvas,
    double x,
    double y,
    bool above,
    double progress,
  ) {
    final color = Color.lerp(
      SeedlingColors.seedlingGreen,
      SeedlingColors.freshSprout,
      progress,
    )!;
    _drawLeaf(canvas, x, y, above, progress, color);

    // Golden shimmer when fully bloomed
    if (progress > 0.65) {
      final shimmerAlpha = (progress - 0.65) / 0.35 * 0.28;
      _drawLeaf(
        canvas,
        x,
        y,
        above,
        progress * 1.12,
        SeedlingColors.sunlight.withValues(alpha: shimmerAlpha),
      );
    }
  }

  void _drawWiltedBud(Canvas canvas, double x, double y, bool above) {
    final dir = above ? -1.0 : 1.0;
    // Drooping stem
    canvas.drawLine(
      Offset(x, y),
      Offset(x + 4, y + dir * 11),
      Paint()
        ..color = SeedlingColors.error.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(x + 4, y + dir * 19),
      7,
      Paint()
        ..color = SeedlingColors.error.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(x + 4, y + dir * 19),
      7,
      Paint()
        ..color = SeedlingColors.error.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BranchPainter old) =>
      old.bloomProgress != bloomProgress || old.isWrong != isWrong;
}
