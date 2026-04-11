import 'grammar_model.dart';

enum GrammarJourneyStage {
  preA1,
  a1Foundation,
  a2Practical,
  b1Functional,
  b2Precision,
  c1c2Mastery;

  String get label => switch (this) {
        GrammarJourneyStage.preA1 => 'Pre-A1 Literacy',
        GrammarJourneyStage.a1Foundation => 'A1 Foundation',
        GrammarJourneyStage.a2Practical => 'A2 Practical',
        GrammarJourneyStage.b1Functional => 'B1 Functional Fluency',
        GrammarJourneyStage.b2Precision => 'B2 Precision',
        GrammarJourneyStage.c1c2Mastery => 'C1/C2 Mastery',
      };
}

class GrammarExerciseTemplate {
  const GrammarExerciseTemplate({
    required this.id,
    required this.type,
    required this.promptStyle,
    required this.expectedOutput,
  });

  final String id;
  final String type;
  final String promptStyle;
  final String expectedOutput;

  factory GrammarExerciseTemplate.fromJson(Map<String, dynamic> json) {
    return GrammarExerciseTemplate(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'transform',
      promptStyle: json['prompt_style']?.toString() ?? '',
      expectedOutput: json['expected_output']?.toString() ?? '',
    );
  }
}

class GrammarConceptPack {
  const GrammarConceptPack({
    required this.conceptId,
    required this.languageCode,
    required this.level,
    required this.prerequisites,
    required this.learningObjective,
    required this.explanations,
    required this.examples,
    required this.commonErrors,
    required this.contrasts,
    required this.exerciseTemplates,
    required this.assessmentItems,
    required this.reviewScheduleRules,
    required this.localExceptions,
  });

  final int conceptId;
  final String languageCode;
  final GrammarLevel level;
  final List<int> prerequisites;
  final String learningObjective;
  final Map<String, String> explanations;
  final List<String> examples;
  final List<String> commonErrors;
  final List<String> contrasts;
  final List<GrammarExerciseTemplate> exerciseTemplates;
  final List<String> assessmentItems;
  final Map<String, dynamic> reviewScheduleRules;
  final List<String> localExceptions;

  factory GrammarConceptPack.fromJson(Map<String, dynamic> json) {
    final rawLevel = json['level']?.toString() ?? 'A0';
    return GrammarConceptPack(
      conceptId: (json['concept_id'] as num?)?.toInt() ?? 0,
      languageCode: json['language_code']?.toString() ?? '',
      level: GrammarLevel.fromString(rawLevel),
      prerequisites:
          ((json['prerequisites'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList(),
      learningObjective: json['learning_objective']?.toString() ?? '',
      explanations: ((json['explanations'] as Map?) ?? const {})
          .map((key, value) => MapEntry(key.toString(), value.toString())),
      examples: ((json['examples'] as List?) ?? const []).map((e) => e.toString()).toList(),
      commonErrors: ((json['common_errors'] as List?) ?? const []).map((e) => e.toString()).toList(),
      contrasts: ((json['contrast_with'] as List?) ?? const []).map((e) => e.toString()).toList(),
      exerciseTemplates: ((json['exercise_templates'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => GrammarExerciseTemplate.fromJson(e.cast<String, dynamic>()))
          .toList(),
      assessmentItems: ((json['assessment_items'] as List?) ?? const []).map((e) => e.toString()).toList(),
      reviewScheduleRules: ((json['review_schedule_rules'] as Map?) ?? const {})
          .map((key, value) => MapEntry(key.toString(), value)),
      localExceptions: ((json['local_exceptions'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}
