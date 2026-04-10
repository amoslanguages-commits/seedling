import 'package:flutter/material.dart';

// ─── GRAMMAR LEVELS ──────────────────────────────────────────────────────────

enum GrammarLevel {
  a0,
  a1,
  a2,
  b1,
  b2,
  c1;

  String get label => name.toUpperCase();

  String get fullLabel {
    switch (this) {
      case GrammarLevel.a0:
        return 'A0 — ABSOLUTE BEGINNER';
      case GrammarLevel.a1:
        return 'A1 — BASIC SENTENCE BUILDING';
      case GrammarLevel.a2:
        return 'A2 — EVERYDAY COMMUNICATION';
      case GrammarLevel.b1:
        return 'B1 — CONNECTED COMMUNICATION';
      case GrammarLevel.b2:
        return 'B2 — FLEXIBLE NATURAL USE';
      case GrammarLevel.c1:
        return 'C1 — ADVANCED CONTROL';
    }
  }

  String get description {
    switch (this) {
      case GrammarLevel.a0:
        return 'Absolute zero — first seeds planted';
      case GrammarLevel.a1:
        return 'Beginner sentence building';
      case GrammarLevel.a2:
        return 'Everyday communication';
      case GrammarLevel.b1:
        return 'Connected storytelling';
      case GrammarLevel.b2:
        return 'Flexible natural use';
      case GrammarLevel.c1:
        return 'Advanced linguistic control';
    }
  }

  Color get color {
    switch (this) {
      case GrammarLevel.a0:
        return const Color(0xFF8D6E63); // soil brown — seed
      case GrammarLevel.a1:
        return const Color(0xFF66BB6A); // new green — sprout
      case GrammarLevel.a2:
        return const Color(0xFF4CAF50); // mid green — sapling
      case GrammarLevel.b1:
        return const Color(0xFF26A69A); // teal green — growing
      case GrammarLevel.b2:
        return const Color(0xFF42A5F5); // blue sky — branching
      case GrammarLevel.c1:
        return const Color(0xFFFFCA28); // sunlight gold — canopy
    }
  }

  Color get glowColor {
    switch (this) {
      case GrammarLevel.a0:
        return const Color(0xFF8D6E63);
      case GrammarLevel.a1:
        return const Color(0xFF66BB6A);
      case GrammarLevel.a2:
        return const Color(0xFF4CAF50);
      case GrammarLevel.b1:
        return const Color(0xFF26A69A);
      case GrammarLevel.b2:
        return const Color(0xFF42A5F5);
      case GrammarLevel.c1:
        return const Color(0xFFFFCA28);
    }
  }

  String get emoji {
    switch (this) {
      case GrammarLevel.a0:
        return '🌱';
      case GrammarLevel.a1:
        return '🌿';
      case GrammarLevel.a2:
        return '🍃';
      case GrammarLevel.b1:
        return '🌳';
      case GrammarLevel.b2:
        return '🌸';
      case GrammarLevel.c1:
        return '🌟';
    }
  }

  static GrammarLevel fromString(String s) {
    switch (s.trim().toUpperCase()) {
      case 'A0':
        return GrammarLevel.a0;
      case 'A1':
        return GrammarLevel.a1;
      case 'A2':
        return GrammarLevel.a2;
      case 'B1':
        return GrammarLevel.b1;
      case 'B2':
        return GrammarLevel.b2;
      case 'C1':
        return GrammarLevel.c1;
      default:
        return GrammarLevel.a0;
    }
  }
}

// ─── NODE STATE ───────────────────────────────────────────────────────────────

enum ConceptNodeState {
  locked, // not yet reached
  available, // unlocked, not started
  inProgress, // some sentences learned
  mastered, // ≥90% mastered
}

// ─── GRAMMAR CONCEPT ─────────────────────────────────────────────────────────

class GrammarConcept {
  final int conceptId;
  final String conceptChapter;
  final GrammarLevel level;
  final String emoji;

  const GrammarConcept({
    required this.conceptId,
    required this.conceptChapter,
    required this.level,
    required this.emoji,
  });

  String get displayName {
    return conceptChapter
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // ─── ALL 121 UNIVERSAL CONCEPTS ─────────────────────────────────────────────

  static const List<GrammarConcept> allConcepts = [
    // ── A0 ── Seed (1-19)
    GrammarConcept(conceptId: 1, conceptChapter: 'greeting_basic', level: GrammarLevel.a0, emoji: '👋'),
    GrammarConcept(conceptId: 2, conceptChapter: 'farewell_basic', level: GrammarLevel.a0, emoji: '🙏'),
    GrammarConcept(conceptId: 3, conceptChapter: 'thanks_basic', level: GrammarLevel.a0, emoji: '❤️'),
    GrammarConcept(conceptId: 4, conceptChapter: 'yes_no_basic', level: GrammarLevel.a0, emoji: '🤷'),
    GrammarConcept(conceptId: 5, conceptChapter: 'identity_self_basic', level: GrammarLevel.a0, emoji: '👤'),
    GrammarConcept(conceptId: 6, conceptChapter: 'name_basic', level: GrammarLevel.a0, emoji: '📛'),
    GrammarConcept(conceptId: 7, conceptChapter: 'ask_name_basic', level: GrammarLevel.a0, emoji: '❓'),
    GrammarConcept(conceptId: 8, conceptChapter: 'identify_near_object', level: GrammarLevel.a0, emoji: '👉'),
    GrammarConcept(conceptId: 9, conceptChapter: 'identify_far_object', level: GrammarLevel.a0, emoji: '👈'),
    GrammarConcept(conceptId: 10, conceptChapter: 'ask_object_identity', level: GrammarLevel.a0, emoji: '🔍'),
    GrammarConcept(conceptId: 11, conceptChapter: 'object_present_here', level: GrammarLevel.a0, emoji: '📍'),
    GrammarConcept(conceptId: 12, conceptChapter: 'object_present_there', level: GrammarLevel.a0, emoji: '📌'),
    GrammarConcept(conceptId: 13, conceptChapter: 'person_present_here', level: GrammarLevel.a0, emoji: '🧍'),
    GrammarConcept(conceptId: 14, conceptChapter: 'basic_possession', level: GrammarLevel.a0, emoji: '🎁'),
    GrammarConcept(conceptId: 15, conceptChapter: 'basic_possession_question', level: GrammarLevel.a0, emoji: '🎁'),
    GrammarConcept(conceptId: 16, conceptChapter: 'basic_possession_negative', level: GrammarLevel.a0, emoji: '🚫'),
    GrammarConcept(conceptId: 17, conceptChapter: 'basic_want', level: GrammarLevel.a0, emoji: '💭'),
    GrammarConcept(conceptId: 18, conceptChapter: 'basic_need', level: GrammarLevel.a0, emoji: '🆘'),
    GrammarConcept(conceptId: 19, conceptChapter: 'basic_request_object', level: GrammarLevel.a0, emoji: '🙌'),

    // ── A1 ── Sprout (20-48)
    GrammarConcept(conceptId: 20, conceptChapter: 'basic_subject_action', level: GrammarLevel.a1, emoji: '⚡'),
    GrammarConcept(conceptId: 21, conceptChapter: 'subject_mix_present', level: GrammarLevel.a1, emoji: '🔄'),
    GrammarConcept(conceptId: 22, conceptChapter: 'subject_object_basic', level: GrammarLevel.a1, emoji: '🔗'),
    GrammarConcept(conceptId: 23, conceptChapter: 'basic_object_reference', level: GrammarLevel.a1, emoji: '👆'),
    GrammarConcept(conceptId: 24, conceptChapter: 'basic_object_pronouns', level: GrammarLevel.a1, emoji: '🪄'),
    GrammarConcept(conceptId: 25, conceptChapter: 'basic_person_reference', level: GrammarLevel.a1, emoji: '🧑'),
    GrammarConcept(conceptId: 26, conceptChapter: 'basic_location_object', level: GrammarLevel.a1, emoji: '📍'),
    GrammarConcept(conceptId: 27, conceptChapter: 'ask_basic_location', level: GrammarLevel.a1, emoji: '🗺️'),
    GrammarConcept(conceptId: 28, conceptChapter: 'location_person', level: GrammarLevel.a1, emoji: '🧍'),
    GrammarConcept(conceptId: 29, conceptChapter: 'location_relation_basic', level: GrammarLevel.a1, emoji: '🔗'),
    GrammarConcept(conceptId: 30, conceptChapter: 'basic_description_quality', level: GrammarLevel.a1, emoji: '✨'),
    GrammarConcept(conceptId: 31, conceptChapter: 'basic_description_size', level: GrammarLevel.a1, emoji: '📏'),
    GrammarConcept(conceptId: 32, conceptChapter: 'basic_description_color', level: GrammarLevel.a1, emoji: '🎨'),
    GrammarConcept(conceptId: 33, conceptChapter: 'basic_description_state', level: GrammarLevel.a1, emoji: '🌡️'),
    GrammarConcept(conceptId: 34, conceptChapter: 'basic_daily_action', level: GrammarLevel.a1, emoji: '🌅'),
    GrammarConcept(conceptId: 35, conceptChapter: 'basic_food_action', level: GrammarLevel.a1, emoji: '🍽️'),
    GrammarConcept(conceptId: 36, conceptChapter: 'basic_motion_action', level: GrammarLevel.a1, emoji: '🏃'),
    GrammarConcept(conceptId: 37, conceptChapter: 'basic_preference', level: GrammarLevel.a1, emoji: '❤️'),
    GrammarConcept(conceptId: 38, conceptChapter: 'time_today_now', level: GrammarLevel.a1, emoji: '⏰'),
    GrammarConcept(conceptId: 39, conceptChapter: 'time_yesterday_past', level: GrammarLevel.a1, emoji: '⏪'),
    GrammarConcept(conceptId: 40, conceptChapter: 'time_tomorrow_future', level: GrammarLevel.a1, emoji: '⏩'),
    GrammarConcept(conceptId: 41, conceptChapter: 'basic_question_yes_no', level: GrammarLevel.a1, emoji: '❓'),
    GrammarConcept(conceptId: 42, conceptChapter: 'basic_question_what', level: GrammarLevel.a1, emoji: '🔍'),
    GrammarConcept(conceptId: 43, conceptChapter: 'basic_question_where', level: GrammarLevel.a1, emoji: '🗺️'),
    GrammarConcept(conceptId: 44, conceptChapter: 'basic_question_who', level: GrammarLevel.a1, emoji: '🧑'),
    GrammarConcept(conceptId: 45, conceptChapter: 'basic_negation_statement', level: GrammarLevel.a1, emoji: '❌'),
    GrammarConcept(conceptId: 46, conceptChapter: 'basic_negation_possession', level: GrammarLevel.a1, emoji: '❌'),
    GrammarConcept(conceptId: 47, conceptChapter: 'basic_negation_preference', level: GrammarLevel.a1, emoji: '❌'),
    GrammarConcept(conceptId: 48, conceptChapter: 'basic_negation_presence', level: GrammarLevel.a1, emoji: '❌'),

    // ── A2 ── Sapling (49-72)
    GrammarConcept(conceptId: 49, conceptChapter: 'habit_basic', level: GrammarLevel.a2, emoji: '🔄'),
    GrammarConcept(conceptId: 50, conceptChapter: 'routine_daily', level: GrammarLevel.a2, emoji: '📅'),
    GrammarConcept(conceptId: 51, conceptChapter: 'frequency_basic', level: GrammarLevel.a2, emoji: '🔁'),
    GrammarConcept(conceptId: 52, conceptChapter: 'quantity_basic', level: GrammarLevel.a2, emoji: '🔢'),
    GrammarConcept(conceptId: 53, conceptChapter: 'countable_objects', level: GrammarLevel.a2, emoji: '📦'),
    GrammarConcept(conceptId: 54, conceptChapter: 'more_less_basic', level: GrammarLevel.a2, emoji: '⚖️'),
    GrammarConcept(conceptId: 55, conceptChapter: 'some_all_none_basic', level: GrammarLevel.a2, emoji: '🌐'),
    GrammarConcept(conceptId: 56, conceptChapter: 'comparison_basic', level: GrammarLevel.a2, emoji: '🆚'),
    GrammarConcept(conceptId: 57, conceptChapter: 'comparison_equal', level: GrammarLevel.a2, emoji: '⟺'),
    GrammarConcept(conceptId: 58, conceptChapter: 'comparison_more_less', level: GrammarLevel.a2, emoji: '⚖️'),
    GrammarConcept(conceptId: 59, conceptChapter: 'ability_basic', level: GrammarLevel.a2, emoji: '💪'),
    GrammarConcept(conceptId: 60, conceptChapter: 'permission_basic', level: GrammarLevel.a2, emoji: '✅'),
    GrammarConcept(conceptId: 61, conceptChapter: 'obligation_basic', level: GrammarLevel.a2, emoji: '📋'),
    GrammarConcept(conceptId: 62, conceptChapter: 'necessity_basic', level: GrammarLevel.a2, emoji: '🆘'),
    GrammarConcept(conceptId: 63, conceptChapter: 'reason_basic', level: GrammarLevel.a2, emoji: '🔍'),
    GrammarConcept(conceptId: 64, conceptChapter: 'contrast_basic', level: GrammarLevel.a2, emoji: '🔀'),
    GrammarConcept(conceptId: 65, conceptChapter: 'addition_basic', level: GrammarLevel.a2, emoji: '➕'),
    GrammarConcept(conceptId: 66, conceptChapter: 'past_daily_actions', level: GrammarLevel.a2, emoji: '⏪'),
    GrammarConcept(conceptId: 67, conceptChapter: 'future_plans_basic', level: GrammarLevel.a2, emoji: '📅'),
    GrammarConcept(conceptId: 68, conceptChapter: 'past_experience_basic', level: GrammarLevel.a2, emoji: '💭'),
    GrammarConcept(conceptId: 69, conceptChapter: 'request_basic', level: GrammarLevel.a2, emoji: '🙏'),
    GrammarConcept(conceptId: 70, conceptChapter: 'offer_basic', level: GrammarLevel.a2, emoji: '🤝'),
    GrammarConcept(conceptId: 71, conceptChapter: 'help_basic', level: GrammarLevel.a2, emoji: '🆘'),
    GrammarConcept(conceptId: 72, conceptChapter: 'clarification_basic', level: GrammarLevel.a2, emoji: '🔍'),

    // ── B1 ── Growing (73-90)
    GrammarConcept(conceptId: 73, conceptChapter: 'past_sequence_basic', level: GrammarLevel.b1, emoji: '📅'),
    GrammarConcept(conceptId: 74, conceptChapter: 'past_background_basic', level: GrammarLevel.b1, emoji: '🌅'),
    GrammarConcept(conceptId: 75, conceptChapter: 'completed_action_basic', level: GrammarLevel.b1, emoji: '✅'),
    GrammarConcept(conceptId: 76, conceptChapter: 'future_plan_basic', level: GrammarLevel.b1, emoji: '📅'),
    GrammarConcept(conceptId: 77, conceptChapter: 'future_intention_basic', level: GrammarLevel.b1, emoji: '💭'),
    GrammarConcept(conceptId: 78, conceptChapter: 'future_prediction_basic', level: GrammarLevel.b1, emoji: '🔮'),
    GrammarConcept(conceptId: 79, conceptChapter: 'opinion_basic', level: GrammarLevel.b1, emoji: '💭'),
    GrammarConcept(conceptId: 80, conceptChapter: 'thought_basic', level: GrammarLevel.b1, emoji: '🧠'),
    GrammarConcept(conceptId: 81, conceptChapter: 'uncertainty_basic', level: GrammarLevel.b1, emoji: '🤔'),
    GrammarConcept(conceptId: 82, conceptChapter: 'condition_real_basic', level: GrammarLevel.b1, emoji: '🔀'),
    GrammarConcept(conceptId: 83, conceptChapter: 'condition_future_basic', level: GrammarLevel.b1, emoji: '🔮'),
    GrammarConcept(conceptId: 84, conceptChapter: 'cause_result_basic', level: GrammarLevel.b1, emoji: '🔗'),
    GrammarConcept(conceptId: 85, conceptChapter: 'relative_person_basic', level: GrammarLevel.b1, emoji: '🧑'),
    GrammarConcept(conceptId: 86, conceptChapter: 'relative_object_basic', level: GrammarLevel.b1, emoji: '📦'),
    GrammarConcept(conceptId: 87, conceptChapter: 'extra_information_basic', level: GrammarLevel.b1, emoji: 'ℹ️'),
    GrammarConcept(conceptId: 88, conceptChapter: 'polite_request_basic', level: GrammarLevel.b1, emoji: '🙏'),
    GrammarConcept(conceptId: 89, conceptChapter: 'suggestion_basic', level: GrammarLevel.b1, emoji: '💡'),
    GrammarConcept(conceptId: 90, conceptChapter: 'formal_informal_basic', level: GrammarLevel.b1, emoji: '🎩'),

    // ── B2 ── Branching (91-108)
    GrammarConcept(conceptId: 91, conceptChapter: 'ongoing_vs_completed', level: GrammarLevel.b2, emoji: '🔄'),
    GrammarConcept(conceptId: 92, conceptChapter: 'habit_vs_current', level: GrammarLevel.b2, emoji: '📅'),
    GrammarConcept(conceptId: 93, conceptChapter: 'before_after_relation', level: GrammarLevel.b2, emoji: '⏱️'),
    GrammarConcept(conceptId: 94, conceptChapter: 'hypothetical_basic', level: GrammarLevel.b2, emoji: '🤔'),
    GrammarConcept(conceptId: 95, conceptChapter: 'unlikely_condition_basic', level: GrammarLevel.b2, emoji: '🎲'),
    GrammarConcept(conceptId: 96, conceptChapter: 'regret_basic', level: GrammarLevel.b2, emoji: '😔'),
    GrammarConcept(conceptId: 97, conceptChapter: 'passive_basic', level: GrammarLevel.b2, emoji: '🔄'),
    GrammarConcept(conceptId: 98, conceptChapter: 'agent_focus_basic', level: GrammarLevel.b2, emoji: '🎯'),
    GrammarConcept(conceptId: 99, conceptChapter: 'result_focus_basic', level: GrammarLevel.b2, emoji: '🏆'),
    GrammarConcept(conceptId: 100, conceptChapter: 'contrast_extended', level: GrammarLevel.b2, emoji: '🔄'),
    GrammarConcept(conceptId: 101, conceptChapter: 'concession_basic', level: GrammarLevel.b2, emoji: '🤝'),
    GrammarConcept(conceptId: 102, conceptChapter: 'reasoning_chain_basic', level: GrammarLevel.b2, emoji: '🔗'),
    GrammarConcept(conceptId: 103, conceptChapter: 'emphasis_basic', level: GrammarLevel.b2, emoji: '‼️'),
    GrammarConcept(conceptId: 104, conceptChapter: 'limitation_basic', level: GrammarLevel.b2, emoji: '🚫'),
    GrammarConcept(conceptId: 105, conceptChapter: 'not_only_but_also_basic', level: GrammarLevel.b2, emoji: '➕'),
    GrammarConcept(conceptId: 106, conceptChapter: 'register_shift_basic', level: GrammarLevel.b2, emoji: '🎚️'),
    GrammarConcept(conceptId: 107, conceptChapter: 'spoken_written_contrast', level: GrammarLevel.b2, emoji: '📝'),
    GrammarConcept(conceptId: 108, conceptChapter: 'softening_basic', level: GrammarLevel.b2, emoji: '🌊'),

    // ── C1 ── Canopy (109-121)
    GrammarConcept(conceptId: 109, conceptChapter: 'embedded_clause_advanced', level: GrammarLevel.c1, emoji: '🔗'),
    GrammarConcept(conceptId: 110, conceptChapter: 'complex_relative_advanced', level: GrammarLevel.c1, emoji: '🧩'),
    GrammarConcept(conceptId: 111, conceptChapter: 'multi_clause_argument_basic', level: GrammarLevel.c1, emoji: '📜'),
    GrammarConcept(conceptId: 112, conceptChapter: 'stance_advanced', level: GrammarLevel.c1, emoji: '🎯'),
    GrammarConcept(conceptId: 113, conceptChapter: 'inference_advanced', level: GrammarLevel.c1, emoji: '🧠'),
    GrammarConcept(conceptId: 114, conceptChapter: 'distance_from_claim', level: GrammarLevel.c1, emoji: '🌊'),
    GrammarConcept(conceptId: 115, conceptChapter: 'argument_structure_basic', level: GrammarLevel.c1, emoji: '🏗️'),
    GrammarConcept(conceptId: 116, conceptChapter: 'concession_refinement', level: GrammarLevel.c1, emoji: '🔄'),
    GrammarConcept(conceptId: 117, conceptChapter: 'topic_shift_control', level: GrammarLevel.c1, emoji: '🔀'),
    GrammarConcept(conceptId: 118, conceptChapter: 'formal_register_advanced', level: GrammarLevel.c1, emoji: '🎩'),
    GrammarConcept(conceptId: 119, conceptChapter: 'professional_expression_basic', level: GrammarLevel.c1, emoji: '💼'),
    GrammarConcept(conceptId: 120, conceptChapter: 'written_style_advanced', level: GrammarLevel.c1, emoji: '📝'),
    GrammarConcept(conceptId: 121, conceptChapter: 'advanced_language_specific_features', level: GrammarLevel.c1, emoji: '🌐'),
  ];

  static GrammarConcept? byId(int id) {
    try {
      return allConcepts.firstWhere((c) => c.conceptId == id);
    } catch (_) {
      return null;
    }
  }
}

// ─── GRAMMAR SENTENCE ────────────────────────────────────────────────────────

class GrammarSentence {
  final int sentenceId;
  final int conceptId;
  final String conceptChapter;
  final String langCode;
  final GrammarLevel level;
  final String category; // ca1–ca10
  final int sortOrder;
  final String sentence;
  final String? sentencePronunciation;
  final String? notes;

  const GrammarSentence({
    required this.sentenceId,
    required this.conceptId,
    required this.conceptChapter,
    required this.langCode,
    required this.level,
    required this.category,
    required this.sortOrder,
    required this.sentence,
    this.sentencePronunciation,
    this.notes,
  });

  factory GrammarSentence.fromCsvRow(Map<String, String> row) {
    return GrammarSentence(
      sentenceId: int.tryParse(row['sentence_id'] ?? '') ?? 0,
      conceptId: int.tryParse(row['concept_id'] ?? '') ?? 0,
      conceptChapter: row['concept_chapter'] ?? '',
      langCode: row['lang_code'] ?? '',
      level: GrammarLevel.fromString(row['level'] ?? 'A0'),
      category: row['category'] ?? 'ca1',
      sortOrder: int.tryParse(row['sort_order'] ?? '1') ?? 1,
      sentence: row['sentence'] ?? '',
      sentencePronunciation: row['sentence_pronunciation']?.isEmpty == true
          ? null
          : row['sentence_pronunciation'],
      notes: row['notes']?.isEmpty == true ? null : row['notes'],
    );
  }
}

// ─── CONCEPT PROGRESS ────────────────────────────────────────────────────────

class ConceptProgress {
  final int conceptId;
  final double mastery; // 0.0 – 1.0
  final int completedSentences;
  final int totalSentences;
  final bool isUnlocked;

  const ConceptProgress({
    required this.conceptId,
    required this.mastery,
    required this.completedSentences,
    required this.totalSentences,
    required this.isUnlocked,
  });

  /// The visual render state of this concept node on the roadmap
  ConceptNodeState get nodeState {
    if (!isUnlocked) return ConceptNodeState.locked;
    if (mastery >= 0.90) return ConceptNodeState.mastered;
    if (completedSentences > 0) return ConceptNodeState.inProgress;
    return ConceptNodeState.available;
  }

  static ConceptProgress empty(int conceptId, {bool isUnlocked = false}) {
    return ConceptProgress(
      conceptId: conceptId,
      mastery: 0.0,
      completedSentences: 0,
      totalSentences: 0,
      isUnlocked: isUnlocked,
    );
  }
}

// ─── SENTENCE PROGRESS ───────────────────────────────────────────────────────

class SentenceProgress {
  final int sentenceId;
  final int conceptId;
  final String langCode;
  final double mastery;
  final DateTime? dueDate;
  final DateTime? lastReview;
  final double stability;
  final double difficulty;
  final int reps;

  const SentenceProgress({
    required this.sentenceId,
    required this.conceptId,
    required this.langCode,
    required this.mastery,
    this.dueDate,
    this.lastReview,
    this.stability = 1.0,
    this.difficulty = 5.0,
    this.reps = 0,
  });

  factory SentenceProgress.fresh(int sentenceId, int conceptId, String langCode) {
    return SentenceProgress(
      sentenceId: sentenceId,
      conceptId: conceptId,
      langCode: langCode,
      mastery: 0.0,
    );
  }
}
