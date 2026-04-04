import 'package:flutter/material.dart';
import '../core/colors.dart';

class GrowingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const GrowingCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  State<GrowingCard> createState() => _GrowingCardState();
}

class _GrowingCardState extends State<GrowingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _growController;

  @override
  void initState() {
    super.initState();
    _growController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _growController.forward();
    });
  }

  @override
  void dispose() {
    _growController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _growController,
      builder: (context, child) {
        final scale = 0.9 + (_growController.value * 0.1);
        final opacity = _growController.value;

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.deepRoot.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: SeedlingColors.seedlingGreen.withValues(
                        alpha: 0.05,
                      ),
                      blurRadius: 40,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
