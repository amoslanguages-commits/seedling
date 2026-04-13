import 'package:flutter/material.dart';

class FadeInStaggered extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Offset offset;

  const FadeInStaggered({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 100),
    this.offset = const Offset(0, 20),
  });

  @override
  State<FadeInStaggered> createState() => _FadeInStaggeredState();
}

class _FadeInStaggeredState extends State<FadeInStaggered>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(offset: _slide.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

class FloatingAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double distance;

  const FloatingAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
    this.distance = 8.0,
  });

  @override
  State<FloatingAnimation> createState() => _FloatingAnimationState();
}

class _FloatingAnimationState extends State<FloatingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: widget.distance).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
