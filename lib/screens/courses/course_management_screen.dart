import 'package:flutter/material.dart';
import '../../core/page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../providers/course_provider.dart';
import '../../models/course.dart';
import 'package:twemoji/twemoji.dart';
import 'add_course_screen.dart';

/// Bottom-sheet course management panel.
/// Shows all added courses; tap to activate, swipe left to delete.
/// Has an "Add Course" button to open [AddCourseScreen].
class CourseManagementScreen extends ConsumerWidget {
  const CourseManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseProvider);
    final notifier = ref.read(courseProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: SeedlingColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Row(
                  children: [
                    Text('My Courses', style: SeedlingTypography.heading2),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _openAddCourse(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: SeedlingColors.seedlingGreen,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Course list
              Expanded(
                child: state.courses.isEmpty
                    ? _EmptyCoursesPlaceholder(
                        onAdd: () => _openAddCourse(context, ref))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.courses.length,
                        itemBuilder: (_, i) {
                          final course = state.courses[i];
                          final isActive = course.id == state.activeCourseId;
                          return _CourseListTile(
                            course: course,
                            isActive: isActive,
                            onTap: () {
                              notifier.setActive(course.id);
                              Navigator.pop(context);
                            },
                            onDelete: () => notifier.deleteCourse(course.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAddCourse(BuildContext context, WidgetRef ref) {
    Navigator.pop(context); // close management sheet first
    Navigator.of(context).push(
      SeedlingPageRoute(page: const AddCourseScreen()),
    );
  }
}

// ─── Course Tile ──────────────────────────────────────────────────────────────

class _CourseListTile extends StatelessWidget {
  final Course course;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CourseListTile({
    required this.course,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(course.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: SeedlingColors.error.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: SeedlingColors.textPrimary, size: 24),
      ),
      confirmDismiss: (_) async {
        if (isActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Switch to another course before deleting this one.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        }
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? SeedlingColors.seedlingGreen.withValues(alpha: 0.12)
                : SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? SeedlingColors.seedlingGreen.withValues(alpha: 0.4)
                  : SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Flags
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Twemoji(
                    emoji: course.targetLanguage.flag,
                    height: 30,
                    width: 30,
                  ),
                  Positioned(
                    bottom: -4,
                    right: -10,
                    child: Twemoji(
                      emoji: course.nativeLanguage.flag,
                      height: 18,
                      width: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Names
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.targetLanguage.name,
                      style: SeedlingTypography.heading3
                          .copyWith(fontSize: 16),
                    ),
                    Text(
                      'from ${course.nativeLanguage.name}',
                      style: SeedlingTypography.caption,
                    ),
                  ],
                ),
              ),
              // Active indicator
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: SeedlingColors.seedlingGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.background,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: SeedlingColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyCoursesPlaceholder extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCoursesPlaceholder({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('No courses yet', style: SeedlingTypography.heading3),
          const SizedBox(height: 6),
          Text('Add your first course to start growing',
              style:
                  SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Course'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SeedlingColors.seedlingGreen,
              foregroundColor: SeedlingColors.textPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
