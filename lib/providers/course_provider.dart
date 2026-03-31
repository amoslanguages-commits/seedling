import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class CourseState {
  final List<Course> courses;
  final String? activeCourseId;

  CourseState({this.courses = const [], this.activeCourseId});

  Course? get activeCourse {
    if (activeCourseId == null) return null;
    try {
      return courses.firstWhere((c) => c.id == activeCourseId);
    } catch (_) {
      return courses.isEmpty ? null : courses.first;
    }
  }

  CourseState copyWith({List<Course>? courses, String? activeCourseId}) =>
      CourseState(
        courses: courses ?? this.courses,
        activeCourseId: activeCourseId ?? this.activeCourseId,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CourseNotifier extends StateNotifier<CourseState> {
  static const _coursesKey = 'courses_v1';
  static const _activeKey = 'active_course_id';

  CourseNotifier() : super(CourseState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_coursesKey);
    final activeId = prefs.getString(_activeKey);

    if (raw != null) {
      try {
        final courses = Course.listFromJson(raw);
        state = CourseState(
          courses: courses,
          activeCourseId: activeId ?? (courses.isNotEmpty ? courses.first.id : null),
        );
        return;
      } catch (_) {}
    }

    // Default: Return empty state
    state = CourseState(courses: [], activeCourseId: null);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coursesKey, Course.listToJson(state.courses));
    if (state.activeCourseId != null) {
      await prefs.setString(_activeKey, state.activeCourseId!);
    }
  }

  Future<void> addCourse(Course course) async {
    state = state.copyWith(
      courses: [...state.courses, course],
      activeCourseId: state.activeCourseId ?? course.id,
    );
    await _persist();
  }

  Future<void> deleteCourse(String id) async {
    final updated = state.courses.where((c) => c.id != id).toList();
    final newActive = state.activeCourseId == id
        ? (updated.isNotEmpty ? updated.first.id : null)
        : state.activeCourseId;
    state = CourseState(courses: updated, activeCourseId: newActive);
    await _persist();
  }

  Future<void> setActive(String id) async {
    state = state.copyWith(activeCourseId: id);
    await _persist();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final courseProvider = StateNotifierProvider<CourseNotifier, CourseState>(
  (_) => CourseNotifier(),
);
