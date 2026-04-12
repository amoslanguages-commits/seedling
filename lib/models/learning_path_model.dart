import 'package:flutter/material.dart';

enum NodeState { locked, active, completed }
enum ChallengeType { 
  phoneticMatch, // Sound -> Script (Stage A)
  scriptRead,    // Script -> Sound (Stage A)
  syllableBuild, // Building syllables/words (Stage A)
  construct,     // Traditional word building (Stage B+)
  listenSelect,  // Hear and select
  fillGap,       // Contextual grammar
  reading        // Discourse level (Stage F)
}

class PathLevel {
  final String stage; // A, B, C, D, E, F
  final String name;  // e.g., "Pre-A1"
  final String title; // e.g., "The Script"
  final List<PathNode> nodes;

  const PathLevel({
    required this.stage,
    required this.name,
    required this.title,
    required this.nodes,
  });
}

class PathNode {
  final String id;
  final String title;
  final String subtitle;
  final String unitTitle; 
  final String stage;     // e.g. "A"
  final String level;     // e.g. "Pre-A1"
  final IconData icon;
  final Color baseColor;
  NodeState state;
  final List<Lesson> lessons;
  String? conceptExplanation;

  PathNode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.unitTitle,
    required this.stage,
    required this.level,
    required this.icon,
    required this.baseColor,
    this.state = NodeState.locked,
    required this.lessons,
    this.conceptExplanation,
  });
}

class Lesson {
  final String id;
  final String title;
  final List<Challenge> challenges;

  const Lesson({
    required this.id,
    required this.title,
    required this.challenges,
  });
}

class Challenge {
  final String id;
  final ChallengeType type;
  final String targetText;    // e.g., "Me gusta la manzana"
  final String nativeText;    // e.g., "I like the apple"
  final String phoneticText;  // e.g., "Meh goos-tah lah man-zah-nah"
  final String? literalGloss; // e.g., "To me pleases the apple"
  final String? magicHint;    // Pop-up hint if they get it wrong
  final String? conceptTag;   // e.g., "indirect_object_pronoun"
  
  // For 'construct' type
  final List<String> wordBank;
  final List<String> correctTokens; // Using tokens instead of a single string for better flexibility

  // For 'listenSelect' type
  final List<String> options;
  final String correctOption;

  const Challenge({
    required this.id,
    required this.type,
    required this.targetText,
    required this.nativeText,
    required this.phoneticText,
    this.literalGloss,
    this.magicHint,
    this.conceptTag,
    this.wordBank = const [],
    this.correctTokens = const [],
    this.options = const [],
    this.correctOption = '',
  });
}
