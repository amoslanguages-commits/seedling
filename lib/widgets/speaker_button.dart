import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../services/tts_service.dart';

/// A premium, reactive speaker button that provides visual feedback 
/// while the TTS engine is actively speaking.
class SeedlingSpeakerButton extends StatelessWidget {
  final String text;
  final String languageCode;
  final double iconSize;
  final Color? color;

  const SeedlingSpeakerButton({
    super.key,
    required this.text,
    required this.languageCode,
    this.iconSize = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TtsService.instance.isSpeaking,
      builder: (context, isSpeaking, _) {
        return GestureDetector(
          onTap: () => TtsService.instance.speak(text, languageCode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSpeaking 
                  ? (color ?? SeedlingColors.seedlingGreen).withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 1.0, end: isSpeaking ? 1.2 : 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticInOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Icon(
                isSpeaking ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                color: color ?? SeedlingColors.seedlingGreen,
                size: iconSize,
              ),
            ),
          ),
        );
      },
    );
  }
}
