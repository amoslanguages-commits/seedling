import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../core/colors.dart';
import '../providers/app_providers.dart';

class TargetWordDisplay extends ConsumerWidget {
  final Word word;
  final TextStyle style;
  final TextAlign textAlign;
  final bool? showPronunciation; // If null, honors the global provider
  final bool useGlobalToggle; // Defaults to true

  const TargetWordDisplay({
    super.key,
    required this.word,
    required this.style,
    this.textAlign = TextAlign.center,
    this.showPronunciation,
    this.useGlobalToggle = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve which pronunciation state to use
    bool shouldShow = false;
    if (showPronunciation != null) {
      shouldShow = showPronunciation!;
    } else if (useGlobalToggle) {
      shouldShow = ref.watch(showPronunciationProvider);
    }

    final wordDisplay = word.hasTargetArticle
        ? RichText(
            textAlign: textAlign,
            text: TextSpan(
              style: style,
              children: [
                TextSpan(
                  text: '${word.targetArticle} ',
                  style: style.copyWith(
                    color:
                        style.color?.withValues(alpha: 0.6) ??
                        SeedlingColors.textPrimary.withValues(alpha: 0.6),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                TextSpan(text: word.word),
              ],
            ),
          )
        : Text(word.word, style: style, textAlign: textAlign);

    if (shouldShow &&
        word.pronunciation != null &&
        word.pronunciation!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: textAlign == TextAlign.center
            ? CrossAxisAlignment.center
            : (textAlign == TextAlign.right
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start),
        children: [
          wordDisplay,
          const SizedBox(height: 4),
          Text(
            '/${word.pronunciation}/',
            style: style.copyWith(
              fontSize: (style.fontSize ?? 20) * 0.45,
              color: SeedlingColors.textSecondary.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
            textAlign: textAlign,
          ),
        ],
      );
    }

    return wordDisplay;
  }
}
