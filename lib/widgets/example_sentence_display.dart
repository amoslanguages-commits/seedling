import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../providers/app_providers.dart';
import '../services/tts_service.dart';

class ExampleSentenceDisplay extends ConsumerWidget {
  final Word word;
  final TextStyle? style;
  final bool? showPronunciation; // If null, honors global provider
  final bool useGlobalToggle;

  const ExampleSentenceDisplay({
    super.key,
    required this.word,
    this.style,
    this.showPronunciation,
    this.useGlobalToggle = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (word.exampleSentence == null || word.exampleSentence!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Resolve toggle state
    bool shouldShow = false;
    if (showPronunciation != null) {
      shouldShow = showPronunciation!;
    } else if (useGlobalToggle) {
      shouldShow = ref.watch(showPronunciationProvider);
    }

    final baseStyle =
        style ??
        SeedlingTypography.body.copyWith(
          color: SeedlingColors.textPrimary,
          fontSize: 16,
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SeedlingColors.morningDew.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SeedlingColors.morningDew.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(word.exampleSentence!, style: baseStyle)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => TtsService.instance.speak(
                  word.exampleSentence!,
                  word.targetLanguageCode,
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    color: SeedlingColors.seedlingGreen,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          if (shouldShow &&
              word.exampleSentencePronunciation != null &&
              word.exampleSentencePronunciation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '/${word.exampleSentencePronunciation}/',
              style: baseStyle.copyWith(
                fontSize: baseStyle.fontSize! * 0.8,
                color: SeedlingColors.textSecondary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          if (word.exampleSentenceTranslation != null &&
              word.exampleSentenceTranslation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              word.exampleSentenceTranslation!,
              style: baseStyle.copyWith(
                fontSize: baseStyle.fontSize! * 0.9,
                color: SeedlingColors.textSecondary.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
