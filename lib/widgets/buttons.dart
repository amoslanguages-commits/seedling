import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../core/colors.dart';
import '../core/typography.dart';

class OrganicButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final double width;
  final double height;
  final Widget? child;
  final bool loading;
  
  const OrganicButton({
    super.key,
    required this.onPressed,
    this.text = '',
    this.isPrimary = true,
    this.width = double.infinity,
    this.height = 56,
    this.child,
    this.loading = false,
  });
  
  @override
  State<OrganicButton> createState() => _OrganicButtonState();
}

class _OrganicButtonState extends State<OrganicButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  
  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }
  
  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }
  
  void _handlePressDown(TapDownDetails details) {
    if (widget.onPressed == null || widget.loading) return;
    _pressController.forward();
  }
  
  void _handlePressUp(TapUpDetails details) {
    if (widget.onPressed == null || widget.loading) {
      _pressController.reverse();
      return;
    }
    _pressController.reverse();
    widget.onPressed?.call();
  }
  
  void _handlePressCancel() {
    _pressController.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handlePressDown,
      onTapUp: _handlePressUp,
      onTapCancel: _handlePressCancel,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.width, widget.height),
            painter: OrganicButtonPainter(
              progress: _pressController.value,
              isPrimary: widget.isPrimary,
            ),
            child: Container(
              width: widget.width,
              height: widget.height,
              alignment: Alignment.center,
              child: widget.loading 
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: widget.isPrimary ? Colors.white : SeedlingColors.seedlingGreen,
                    ),
                  )
                : Opacity(
                    opacity: widget.onPressed == null ? 0.5 : 1.0,
                    child: widget.child ?? Text(
                      widget.text,
                      style: SeedlingTypography.bodyLarge.copyWith(
                        color: widget.isPrimary 
                            ? Colors.white 
                            : SeedlingColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }
}

class OrganicButtonPainter extends CustomPainter {
  final double progress;
  final bool isPrimary;

  OrganicButtonPainter({
    required this.progress,
    required this.isPrimary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base shape
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    
    // 2. Shadows (Drop Shadow)
    final shadowScale = 1.0 - (progress * 0.05); // Button presses down
    
    canvas.save();
    canvas.translate(
      size.width * (1.0 - shadowScale) / 2, 
      (size.height * (1.0 - shadowScale) / 2) + (progress * 4.0)
    );
    canvas.scale(shadowScale, shadowScale);

    if (!isPressed(progress)) {
      canvas.drawRRect(
        rrect.shift(const Offset(0, 6)), 
        Paint()
          ..color = (isPrimary ? SeedlingColors.deepRoot : Colors.grey.shade400)
              .withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      );
    }

    // 3. Main Body
    final mainPaint = Paint()
      ..color = isPrimary ? SeedlingColors.seedlingGreen : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, mainPaint);

    // 4. Top Gloss Highlight
    final glossRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.4);
    final glossRRect = RRect.fromRectAndCorners(
      glossRect, 
      topLeft: const Radius.circular(20), 
      topRight: const Radius.circular(20),
    );
    
    final glossPaint = Paint()
      ..shader = ui.Gradient.linear(
        glossRect.topCenter,
        glossRect.bottomCenter,
        [
          Colors.white.withValues(alpha: isPrimary ? 0.2 : 0.8),
          Colors.white.withValues(alpha: 0.0),
        ]
      )
      ..style = PaintingStyle.fill;
    canvas.drawRRect(glossRRect, glossPaint);

    // 5. Inner Bottom Shadow (Bevel)
    final rimPath = Path()
      ..addRRect(rrect)
      ..addRRect(rrect.shift(const Offset(0, -2)));
    
    canvas.drawPath(
      rimPath,
      Paint()
        ..color = isPrimary ? SeedlingColors.deepRoot : Colors.grey.shade300
        ..style = PaintingStyle.fill
    );

    canvas.restore();
  }
  
  bool isPressed(double p) => p > 0.0;

  @override
  bool shouldRepaint(covariant OrganicButtonPainter oldDelegate) => 
      oldDelegate.progress != progress || oldDelegate.isPrimary != isPrimary;
}
