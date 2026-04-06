import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/typography.dart';

class PremiumGateDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onSubscribe;

  const PremiumGateDialog({
    super.key,
    this.title = 'Seedling Pro Feature',
    this.message =
        'This feature is available exclusively for Seedling Pro members. Nurture your learning journey with unlimited access.',
    this.onSubscribe,
  });

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PremiumGateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: SeedlingColors.seedlingGreen,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: SeedlingTypography.heading3.copyWith(
                color: SeedlingColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: SeedlingTypography.body.copyWith(
                color: SeedlingColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Maybe Later',
                      style: SeedlingTypography.bodyLarge.copyWith(
                        color: SeedlingColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onSubscribe?.call();
                      // Navigate to subscription screen if needed
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SeedlingColors.seedlingGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Upgrade Now',
                      style: SeedlingTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
