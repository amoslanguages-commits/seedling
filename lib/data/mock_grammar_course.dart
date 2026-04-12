import 'package:flutter/material.dart';
import '../models/learning_path_model.dart';

class MockGrammarCourse {
  static List<PathLevel> get courseLevels => [
        PathLevel(
          name: 'A1',
          title: 'Foundations',
          nodes: [
            PathNode(
              id: 'es_a1_u1_n1',
              title: 'Greetings',
              subtitle: 'Essential expressions',
              unitTitle: 'Unit 1: Foundations',
              icon: Icons.chat_bubble_outline_rounded,
              baseColor: const Color(0xFF4BAE4F),
              state: NodeState.completed,
              conceptExplanation: "In Spanish, greetings often change based on the time of day.",
              lessons: [
                const Lesson(
                  id: 'l1',
                  title: 'Basic Hello',
                  challenges: [
                    Challenge(
                      id: 'c1',
                      type: ChallengeType.construct,
                      targetText: 'Hola, ¿cómo estás?',
                      nativeText: 'Hello, how are you?',
                      phoneticText: 'Oh-lah, koh-moh es-tahs',
                      literalGloss: 'Hello, how are-you?',
                      magicHint: 'Remember that "H" is silent in Spanish!',
                      wordBank: ['Hola', '¿cómo', 'estás?', 'Adiós', 'bien'],
                      correctTokens: ['Hola', '¿cómo', 'estás?'],
                    ),
                  ],
                ),
              ],
            ),
            PathNode(
              id: 'es_a1_u1_n2',
              title: 'Pronouns',
              subtitle: 'I, You, He/She',
              unitTitle: 'Unit 1: Foundations',
              icon: Icons.people_outline_rounded,
              baseColor: const Color(0xFF81C784),
              state: NodeState.active,
              conceptExplanation: "Pronouns are often omitted in Spanish because the verb ending tells you who is speaking.",
              lessons: [
                const Lesson(
                  id: 'l2',
                  title: 'Subject Pronouns',
                  challenges: [
                    Challenge(
                      id: 'c2',
                      type: ChallengeType.construct,
                      targetText: 'Yo soy Germán',
                      nativeText: 'I am German',
                      phoneticText: 'Yo soy Her-mahn',
                      literalGloss: 'I am-1st-sing Germán',
                      wordBank: ['Yo', 'soy', 'Germán', 'Tú'],
                      correctTokens: ['Yo', 'soy', 'Germán'],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        PathLevel(
          name: 'A2',
          title: 'Explorer',
          nodes: [
            PathNode(
              id: 'es_a2_u1_n1',
              title: 'Past Tense',
              subtitle: 'Sharing stories',
              unitTitle: 'Unit 1: Narratives',
              icon: Icons.history_rounded,
              baseColor: const Color(0xFF388E3C),
              state: NodeState.locked,
              lessons: [],
            ),
          ],
        ),
      ];
}
