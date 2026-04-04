import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/multiplayer_provider.dart';

class LiveReactionBar extends ConsumerWidget {
  const LiveReactionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emojis = ['🌿', '🔥', '💧', '🌸', '✨', '👏'];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((e) => _buildEmojiButton(ref, e)).toList(),
      ),
    );
  }

  Widget _buildEmojiButton(WidgetRef ref, String emoji) {
    return GestureDetector(
      onTap: () {
        ref.read(activeSessionProvider.notifier).sendReaction(emoji);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
