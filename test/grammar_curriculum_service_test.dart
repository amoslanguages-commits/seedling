import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/models/grammar_curriculum_model.dart';
import 'package:seedling/models/grammar_model.dart';
import 'package:seedling/services/grammar_curriculum_service.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._payload);
  final String _payload;

  @override
  Future<String> loadString(String key, {bool cache = true}) async => _payload;
}

void main() {
  test('parses curriculum concept packs from JSON', () async {
    const payload = '''
    {
      "concepts": [
        {
          "concept_id": 22,
          "language_code": "es",
          "level": "A1",
          "prerequisites": [1,2],
          "learning_objective": "Build basic SVO sentences",
          "explanations": {"quick":"x"},
          "examples": ["Yo estudio."],
          "common_errors": ["Missing subject"],
          "contrast_with": ["subject_mix_present"],
          "exercise_templates": [{"id":"e1","type":"transform","prompt_style":"x","expected_output":"y"}],
          "assessment_items": ["item1"],
          "review_schedule_rules": {"target_retention": 0.9},
          "local_exceptions": ["drop pronoun in colloquial speech"]
        }
      ]
    }
    ''';
    final service = GrammarCurriculumService(bundle: _FakeAssetBundle(payload));
    final packs = await service.loadConceptPacks();
    expect(packs.length, 1);
    expect(packs.first.conceptId, 22);
    expect(packs.first.level, GrammarLevel.a1);
    expect(packs.first.exerciseTemplates.first.type, 'transform');
  });

  test('maps level to journey stage and mission', () {
    final service = GrammarCurriculumService();
    final stage = service.stageForLevel(GrammarLevel.b2);
    final mission = service.missionForStage(stage);
    expect(stage, GrammarJourneyStage.b2Precision);
    expect(mission.tasks, isNotEmpty);
    expect(mission.estimatedMinutes, greaterThanOrEqualTo(10));
  });
}
