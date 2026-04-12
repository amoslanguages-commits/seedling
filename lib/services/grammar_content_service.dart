import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/learning_path_model.dart';

class GrammarContentService {
  static final GrammarContentService instance = GrammarContentService._internal();
  GrammarContentService._internal();

  Future<List<PathLevel>> loadCourse(String langCode) async {
    try {
      final pathCsv = await rootBundle.loadString('assets/grammar/${langCode}_path.csv');
      final contentCsv = await rootBundle.loadString('assets/grammar/${langCode}_content.csv');

      final List<List<dynamic>> pathData = csv.decode(pathCsv);
      final List<List<dynamic>> contentData = csv.decode(contentCsv);

      // Skip headers (row 0)
      final nodes = _parseNodes(pathData.sublist(1));
      _parseAndJoinContent(nodes, contentData.sublist(1));

      return _groupIntoLevels(nodes);
    } catch (e) {
      debugPrint("Error loading grammar course for $langCode: $e");
      return [];
    }
  }

  List<PathNode> _parseNodes(List<List<dynamic>> rows) {
    return rows.map<PathNode>((row) {
      return PathNode(
        id: row[3].toString(),
        title: row[4].toString(),
        subtitle: row[5].toString(),
        unitTitle: row[2].toString(),
        stage: row[0].toString(),
        level: row[1].toString(),
        icon: _mapIcon(row[6].toString()),
        baseColor: _mapColor(row[7].toString()),
        state: NodeState.locked,
        lessons: [],
      );
    }).toList();
  }

  void _parseAndJoinContent(List<PathNode> nodes, List<List<dynamic>> rows) {
    for (var row in rows) {
      final nodeId = row[0].toString();
      final node = nodes.firstWhere((n) => n.id == nodeId);

      // Add concept explanation if not already set
      if (node.conceptExplanation == null && row[14].toString().isNotEmpty) {
        node.conceptExplanation = row[14].toString();
      }

      final lessonId = row[1].toString();
      Lesson? lesson = node.lessons.firstWhere((l) => l.id == lessonId, orElse: () {
        final newLesson = Lesson(
          id: lessonId,
          title: row[2].toString(),
          challenges: [],
        );
        node.lessons.add(newLesson);
        return newLesson;
      });

      final challenge = Challenge(
        id: row[3].toString(),
        type: _mapChallengeType(row[4].toString()),
        targetText: row[5].toString(),
        nativeText: row[6].toString(),
        phoneticText: row[7].toString(),
        literalGloss: row[8].toString().isEmpty ? null : row[8].toString(),
        magicHint: row[9].toString().isEmpty ? null : row[9].toString(),
        wordBank: row[10].toString().split(';'),
        correctTokens: row[11].toString().split(';'),
        options: row[12].toString().isEmpty ? [] : row[12].toString().split(';'),
        correctOption: row[13].toString().isEmpty ? '' : row[13].toString(),
      );

      lesson.challenges.add(challenge);
    }
    
    // Set First node to active for demo
    if (nodes.isNotEmpty) {
      nodes.first.state = NodeState.active;
    }
  }

  List<PathLevel> _groupIntoLevels(List<PathNode> nodes) {
    final Map<String, PathLevel> levelMap = {};

    for (var node in nodes) {
      final levelKey = "${node.stage}_${node.level}";
      if (!levelMap.containsKey(levelKey)) {
        levelMap[levelKey] = PathLevel(
          stage: node.stage,
          name: node.level,
          title: _getLevelTitle(node.stage, node.level),
          nodes: [],
        );
      }
      levelMap[levelKey]!.nodes.add(node);
    }

    return levelMap.values.toList();
  }

  String _getLevelTitle(String stage, String level) {
    switch (stage) {
      case 'A': return 'The Script';
      case 'B': return 'Foundations';
      case 'C': return 'Practical';
      case 'D': return 'Functional Fluency';
      case 'E': return 'Precision';
      case 'F': return 'Mastery';
      default: return level;
    }
  }

  IconData _mapIcon(String name) {
    switch (name) {
      case 'chat_bubble_outline_rounded': return Icons.chat_bubble_outline_rounded;
      case 'people_outline_rounded': return Icons.people_outline_rounded;
      case 'history_rounded': return Icons.history_rounded;
      case 'explore_rounded': return Icons.explore_rounded;
      default: return Icons.school_rounded;
    }
  }

  Color _mapColor(String hex) {
    try {
      final cleanHex = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      return Colors.green;
    }
  }

  ChallengeType _mapChallengeType(String type) {
    switch (type) {
      case 'phoneticMatch': return ChallengeType.phoneticMatch;
      case 'scriptRead': return ChallengeType.scriptRead;
      case 'syllableBuild': return ChallengeType.syllableBuild;
      case 'construct': return ChallengeType.construct;
      case 'listenSelect': return ChallengeType.listenSelect;
      case 'fillGap': return ChallengeType.fillGap;
      case 'reading': return ChallengeType.reading;
      default: return ChallengeType.construct;
    }
  }
}
