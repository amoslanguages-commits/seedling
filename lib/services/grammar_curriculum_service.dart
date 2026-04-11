import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/grammar_curriculum_model.dart';
import '../models/grammar_model.dart';

class DailyGrammarMission {
  const DailyGrammarMission({
    required this.stage,
    required this.title,
    required this.tasks,
    required this.estimatedMinutes,
  });

  final GrammarJourneyStage stage;
  final String title;
  final List<String> tasks;
  final int estimatedMinutes;
}

class GrammarCurriculumService {
  GrammarCurriculumService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<List<GrammarConceptPack>> loadConceptPacks() async {
    try {
      final raw = await _bundle.loadString('assets/grammar/curriculum.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final concepts = (json['concepts'] as List?) ?? const [];
      return concepts
          .whereType<Map>()
          .map((item) => GrammarConceptPack.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  GrammarJourneyStage stageForLevel(GrammarLevel level) {
    return switch (level) {
      GrammarLevel.a0 => GrammarJourneyStage.preA1,
      GrammarLevel.a1 => GrammarJourneyStage.a1Foundation,
      GrammarLevel.a2 => GrammarJourneyStage.a2Practical,
      GrammarLevel.b1 => GrammarJourneyStage.b1Functional,
      GrammarLevel.b2 => GrammarJourneyStage.b2Precision,
      GrammarLevel.c1 => GrammarJourneyStage.c1c2Mastery,
    };
  }

  DailyGrammarMission missionForStage(GrammarJourneyStage stage) {
    return switch (stage) {
      GrammarJourneyStage.preA1 => const DailyGrammarMission(
          stage: GrammarJourneyStage.preA1,
          title: 'Decode & Build',
          tasks: [
            'Sound-letter warmup',
            'Syllable blend sprint',
            'Read 3 micro sentences',
          ],
          estimatedMinutes: 8,
        ),
      GrammarJourneyStage.a1Foundation => const DailyGrammarMission(
          stage: GrammarJourneyStage.a1Foundation,
          title: 'Core Sentence Control',
          tasks: [
            'Word-order transform set',
            'Pronoun + negation drill',
            'Mini dialogue readout',
          ],
          estimatedMinutes: 10,
        ),
      GrammarJourneyStage.a2Practical => const DailyGrammarMission(
          stage: GrammarJourneyStage.a2Practical,
          title: 'Daily Communication Pack',
          tasks: [
            'Time/aspect transformation',
            'Connector selection',
            'Functional message response',
          ],
          estimatedMinutes: 12,
        ),
      GrammarJourneyStage.b1Functional => const DailyGrammarMission(
          stage: GrammarJourneyStage.b1Functional,
          title: 'Functional Fluency Builder',
          tasks: [
            'Conditional rewrite',
            'Relative clause expansion',
            'Opinion + reason production',
          ],
          estimatedMinutes: 14,
        ),
      GrammarJourneyStage.b2Precision => const DailyGrammarMission(
          stage: GrammarJourneyStage.b2Precision,
          title: 'Precision & Register',
          tasks: [
            'Tone/register swap',
            'Complex clause reconstruction',
            'Professional context response',
          ],
          estimatedMinutes: 15,
        ),
      GrammarJourneyStage.c1c2Mastery => const DailyGrammarMission(
          stage: GrammarJourneyStage.c1c2Mastery,
          title: 'Discourse Mastery Lab',
          tasks: [
            'Discourse coherence repair',
            'Rhetorical precision challenge',
            'Nuance transfer task',
          ],
          estimatedMinutes: 18,
        ),
    };
  }
}
