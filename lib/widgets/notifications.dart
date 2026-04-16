import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import 'mascot.dart';
import 'buttons.dart';

class SeedlingNotifications {
  /// Shows a premium, glassmorphic floating snackbar at the bottom of the screen.
  static void showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = true,
  }) {
    final color = isError ? SeedlingColors.error : SeedlingColors.seedlingGreen;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: SeedlingColors.cardBackground.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      message,
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a premium mascot-themed dialog for important successes or critical errors.
  static Future<void> showDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool isError = true,
    String? buttonText,
    VoidCallback? onConfirm,
    Widget? child,
    MascotState? mascotState,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, _) {
        final curve = Curves.elasticOut.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              backgroundColor: SeedlingColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(
                  color: (isError ? SeedlingColors.error : SeedlingColors.seedlingGreen)
                      .withValues(alpha: 0.2),
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SeedlingMascot(
                    size: 100,
                    state: mascotState ?? (isError ? MascotState.sad : MascotState.happy),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: SeedlingTypography.heading3.copyWith(
                      color: isError ? SeedlingColors.error : SeedlingColors.seedlingGreen,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: SeedlingTypography.body.copyWith(
                      color: SeedlingColors.textPrimary.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (child != null) ...[
                    const SizedBox(height: 16),
                    child,
                  ],
                  const SizedBox(height: 24),
                  OrganicButton(
                    text: buttonText ?? (isError ? 'TRY AGAIN' : 'GREAT!'),
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
