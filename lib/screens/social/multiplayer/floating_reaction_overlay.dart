import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FloatingReactionOverlay extends ConsumerStatefulWidget {
  final String sessionId;
  const FloatingReactionOverlay({super.key, required this.sessionId});

  @override
  ConsumerState<FloatingReactionOverlay> createState() =>
      FloatingReactionOverlayState();
}

class FloatingReactionOverlayState
    extends ConsumerState<FloatingReactionOverlay>
    with TickerProviderStateMixin {
  final List<_FloatingEmoji> _emojis = [];

  @override
  void initState() {
    super.initState();
    // In a real app with Supabase Realtime, we'd listen for the 'reaction' event here
    // However, since we're using broadcast inside the provider, we could either
    // listen to the provider or have the provider trigger a global event bus.
  }

  void spawnEmoji(String emoji) {
    if (!mounted) return;
    final id = DateTime.now().millisecondsSinceEpoch;
    final random = Random();

    setState(() {
      _emojis.add(
        _FloatingEmoji(
          id: id,
          emoji: emoji,
          left:
              random.nextDouble() * MediaQuery.of(context).size.width * 0.8 +
              20,
          controller:
              AnimationController(
                  duration: const Duration(milliseconds: 2500),
                  vsync: this,
                )
                ..forward().then((_) {
                  setState(() {
                    _emojis.removeWhere((e) => e.id == id);
                  });
                }),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // We listen to the broadcast indirectly here.
    // For simplicity in this demo, let's just make the reaction bar directly tell this overlay.
    // In production, we'd use ref.listen on a reaction stream.

    return Stack(
      children: _emojis.map((e) {
        return AnimatedBuilder(
          animation: e.controller,
          builder: (context, child) {
            final double progress = e.controller.value;
            final double bottom = 120 + (progress * 400); // Float up
            final double opacity = (1.0 - progress).clamp(0.0, 1.0);
            final double scale = 1.0 + (progress * 0.5);

            return Positioned(
              left: e.left,
              bottom: bottom,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Text(e.emoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

class _FloatingEmoji {
  final int id;
  final String emoji;
  final double left;
  final AnimationController controller;

  _FloatingEmoji({
    required this.id,
    required this.emoji,
    required this.left,
    required this.controller,
  });
}
