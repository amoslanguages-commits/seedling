import 'package:flutter/material.dart';

/// Ultra premium page transitions matching Seedling's botanical theme.
/// Uses a grow-from-seed scale + fade animation for all navigation.
class SeedlingPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SeedlingPageRoute({required this.page})
    : super(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Organic entry: grow from center + fade in
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          final scale = Tween<double>(begin: 0.88, end: 1.0).animate(curve);
          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
            ),
          );

          // Outgoing page slides slightly back
          final secondaryCurve = CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeInCubic,
          );
          final secondarySlide = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.06, 0),
          ).animate(secondaryCurve);

          return SlideTransition(
            position: secondarySlide,
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
          );
        },
      );
}
