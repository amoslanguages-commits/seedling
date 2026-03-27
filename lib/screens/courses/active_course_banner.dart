import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../providers/course_provider.dart';
import 'package:twemoji/twemoji.dart';
import 'course_management_screen.dart';

/// Compact active-course banner shown in the home screen header.
/// Displays: [flag] [TargetLanguage] (big) / [from flag NativeLanguage] (small)
/// Tapping opens [CourseManagementScreen].
class ActiveCourseBanner extends ConsumerWidget {
  const ActiveCourseBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseState = ref.watch(courseProvider);
    final course = courseState.activeCourse;

    if (course == null) {
      return GestureDetector(
        onTap: () => _openManagement(context),
        child: Row(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add a Course',
                    style: SeedlingTypography.heading3
                        .copyWith(color: SeedlingColors.seedlingGreen, fontSize: 15)),
                Text('Tap to get started',
                    style: SeedlingTypography.caption.copyWith(fontSize: 11)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: Colors.grey.shade400),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openManagement(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flag
          Twemoji(
            emoji: course.targetLanguage.flag,
            height: 28,
            width: 28,
          ),
          const SizedBox(width: 10),
          // Language names
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Target language — big
              Text(
                course.targetLanguage.name,
                style: SeedlingTypography.heading2.copyWith(
                  fontSize: 18,
                  color: SeedlingColors.seedlingGreen,
                  height: 1.1,
                ),
              ),
              // Native language — small
              Row(
                children: [
                  const Text(
                    'from ',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Twemoji(
                    emoji: course.nativeLanguage.flag,
                    height: 12,
                    width: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    course.nativeLanguage.name,
                    style: SeedlingTypography.caption.copyWith(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  void _openManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CourseManagementScreen(),
    );
  }
}
