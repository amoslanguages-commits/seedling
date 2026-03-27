import 'package:flutter/material.dart';
import '../models/word.dart';
import '../core/colors.dart';

class TargetWordDisplay extends StatelessWidget {
  final Word word;
  final TextStyle style;
  final TextAlign textAlign;

  const TargetWordDisplay({
    super.key,
    required this.word,
    required this.style,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    if (word.hasTargetArticle) {
      return RichText(
        textAlign: textAlign,
        text: TextSpan(
          style: style,
          children: [
            TextSpan(
              text: '${word.targetArticle} ',
              style: style.copyWith(
                color: style.color?.withValues(alpha: 0.6) ?? SeedlingColors.textPrimary.withValues(alpha: 0.6),
                fontWeight: FontWeight.normal,
              ),
            ),
            TextSpan(text: word.word),
          ],
        ),
      );
    }

    return Text(
      word.word,
      style: style,
      textAlign: textAlign,
    );
  }
}
