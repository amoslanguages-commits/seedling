import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../services/tts_service.dart';

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
    final db = DatabaseHelper();
    final userId = AuthService().userId;
    final localData = await db.getCourses(userId);

    if (localData.isNotEmpty) {
      final courses = localData.map((m) => Course(
        id: m['id'],
        nativeLanguage: Language.byCode(m['native_lang_code']) ?? Language.all.first,
        targetLanguage: Language.byCode(m['target_lang_code']) ?? Language.all.last,
      )).toList();

      final activeRecord = localData.firstWhere((c) => c['is_active'] == 1, orElse: () => localData.first);

      state = CourseState(
        courses: courses,
        activeCourseId: activeRecord['id'],
      );
    } else {
      // Fallback to SharedPreferences if DB is empty (migration path)
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
          // Migrate to DB
          for (final c in courses) {
            await db.saveCourse({
              'id': c.id,
              'user_id': userId,
              'native_lang_code': c.nativeLanguage.code,
              'target_lang_code': c.targetLanguage.code,
              'is_active': c.id == state.activeCourseId ? 1 : 0,
            });
          }
          return;
        } catch (_) {}
      }
      state = CourseState(courses: [], activeCourseId: null);
    }
  }

  Future<void> _persist() async {
    final db = DatabaseHelper();
    final userId = AuthService().userId;

    for (final c in state.courses) {
      await db.saveCourse({
        'id': c.id,
        'user_id': userId,
        'native_lang_code': c.nativeLanguage.code,
        'target_lang_code': c.targetLanguage.code,
        'is_active': c.id == state.activeCourseId ? 1 : 0,
      });
    }

    // Still sync to SharedPreferences for legacy/backup compatibility if needed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coursesKey, Course.listToJson(state.courses));
    if (state.activeCourseId != null) {
      await prefs.setString(_activeKey, state.activeCourseId!);
    }
  }

  Future<void> refresh() async {
    await _load();
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

    // Trigger TTS storage cleanup for any orphaned models
    final activeMmsCodes = updated
        .map((c) => TtsService.instance.mmsCodeFor(c.targetLanguage.code))
        .toList();
    await TtsService.instance.cleanOrphanedModels(activeMmsCodes);
  }

  Future<void> setActive(String id) async {
    state = state.copyWith(activeCourseId: id);
    await _persist();
  }

  String? get activeCourseId => state.activeCourseId;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final courseProvider = StateNotifierProvider<CourseNotifier, CourseState>(
  (_) => CourseNotifier(),
);
