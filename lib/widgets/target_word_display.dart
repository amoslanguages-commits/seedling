import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../core/colors.dart';
import '../providers/app_providers.dart';

class TargetWordDisplay extends ConsumerStatefulWidget {
  final Word word;
  final TextStyle style;
  final TextAlign textAlign;
  final bool? showPronunciation; // If null, honors the global provider
  final bool useGlobalToggle; // Defaults to true
  final bool hideArticle;

  const TargetWordDisplay({
    super.key,
    required this.word,
    required this.style,
    this.textAlign = TextAlign.center,
    this.showPronunciation,
    this.useGlobalToggle = true,
    this.hideArticle = false,
  });

  @override
  ConsumerState<TargetWordDisplay> createState() => _TargetWordDisplayState();
}

class _TargetWordDisplayState extends ConsumerState<TargetWordDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolve which pronunciation state to use
    bool shouldShow = false;
    if (widget.showPronunciation != null) {
      shouldShow = widget.showPronunciation!;
    } else if (widget.useGlobalToggle) {
      shouldShow = ref.watch(showPronunciationProvider);
    }

    final wordDisplay = (widget.word.hasTargetArticle && !widget.hideArticle)
        ? RichText(
            textAlign: widget.textAlign,
            text: TextSpan(
              style: widget.style,
              children: [
                TextSpan(
                  text: '${widget.word.targetArticle} ',
                  style: widget.style.copyWith(
                    color:
                        widget.style.color?.withValues(alpha: 0.6) ??
                        SeedlingColors.textPrimary.withValues(alpha: 0.6),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                TextSpan(text: widget.word.word),
              ],
            ),
          )
        : Text(widget.word.word, style: widget.style, textAlign: widget.textAlign);

    Widget content;
    if (shouldShow &&
        widget.word.pronunciation != null &&
        widget.word.pronunciation!.isNotEmpty) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: widget.textAlign == TextAlign.center
            ? CrossAxisAlignment.center
            : (widget.textAlign == TextAlign.right
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start),
        children: [
          wordDisplay,
          const SizedBox(height: 4),
          Text(
            '/${widget.word.pronunciation}/',
            style: widget.style.copyWith(
              fontSize: (widget.style.fontSize ?? 20) * 0.45,
              color: SeedlingColors.textSecondary.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
            textAlign: widget.textAlign,
          ),
        ],
      );
    } else {
      content = wordDisplay;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: content,
    );
  }
}
