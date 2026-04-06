import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../widgets/buttons.dart';
import '../screens/settings/subscription_screen.dart';

class PremiumGateDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final String? iconSymbol;

  const PremiumGateDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.stars_rounded,
    this.iconSymbol,
  });

  // Compatibility constructor for old fields
  factory PremiumGateDialog.legacy({
    Key? key,
    required String featureName,
    required String limitDescription,
    dynamic icon, // Can be String or IconData
  }) {
    return PremiumGateDialog(
      key: key,
      title: featureName,
      message: limitDescription,
      icon: icon is IconData ? icon : null,
      iconSymbol: icon is String ? icon : null,
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    IconData? icon = Icons.stars_rounded,
    String? iconSymbol,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PremiumGateDialog(
        title: title,
        message: message,
        icon: icon,
        iconSymbol: iconSymbol,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: SeedlingColors.background,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: SeedlingColors.autumnGold.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.autumnGold.withValues(alpha: 0.1),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SeedlingColors.autumnGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: iconSymbol != null
                  ? Text(iconSymbol!, style: const TextStyle(fontSize: 40))
                  : Icon(icon, color: SeedlingColors.autumnGold, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: SeedlingTypography.heading2.copyWith(fontSize: 24),
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
            OrganicButton(
              text: 'UPGRADE TO PRO',
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              width: double.infinity,
              isPremiumActiveMode: true,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
