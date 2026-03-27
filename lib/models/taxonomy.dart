import 'package:flutter/material.dart';

// ================ PARTS OF SPEECH ENUMERATION ================

enum PartOfSpeech {
  noun,
  verb,
  adjective,
  adverb,
  pronoun,
  determiner,
  preposition,
  conjunction,
  interjection,
  numeral,
  classifier,
  particle,
  auxiliaryVerb,
  copula,
  postposition,
  suffix,
  article,
  incorporatedNoun,
}

extension PartOfSpeechExtension on PartOfSpeech {
  String get displayName {
    switch (this) {
      case PartOfSpeech.noun: return 'Noun';
      case PartOfSpeech.verb: return 'Verb';
      case PartOfSpeech.adjective: return 'Adjective';
      case PartOfSpeech.adverb: return 'Adverb';
      case PartOfSpeech.pronoun: return 'Pronoun';
      case PartOfSpeech.determiner: return 'Determiner';
      case PartOfSpeech.preposition: return 'Preposition';
      case PartOfSpeech.conjunction: return 'Conjunction';
      case PartOfSpeech.interjection: return 'Interjection';
      case PartOfSpeech.numeral: return 'Numeral';
      case PartOfSpeech.classifier: return 'Classifier';
      case PartOfSpeech.particle: return 'Particle';
      case PartOfSpeech.auxiliaryVerb: return 'Aux. Verb';
      case PartOfSpeech.copula: return 'Copula';
      case PartOfSpeech.postposition: return 'Postposition';
      case PartOfSpeech.suffix: return 'Suffix';
      case PartOfSpeech.article: return 'Article';
      case PartOfSpeech.incorporatedNoun: return 'Incorp. Noun';
    }
  }

  String get icon {
    switch (this) {
      case PartOfSpeech.noun: return '📦';
      case PartOfSpeech.verb: return '⚡';
      case PartOfSpeech.adjective: return '🎨';
      case PartOfSpeech.adverb: return '💨';
      case PartOfSpeech.pronoun: return '👤';
      case PartOfSpeech.determiner: return '👆';
      case PartOfSpeech.preposition: return '🔗';
      case PartOfSpeech.conjunction: return '➕';
      case PartOfSpeech.interjection: return '💥';
      case PartOfSpeech.numeral: return '🔢';
      case PartOfSpeech.classifier: return '📏';
      case PartOfSpeech.particle: return '✨';
      case PartOfSpeech.auxiliaryVerb: return '🤝';
      case PartOfSpeech.copula: return '⬌';
      case PartOfSpeech.postposition: return '⬅️';
      case PartOfSpeech.suffix: return '➡️';
      case PartOfSpeech.article: return '📰';
      case PartOfSpeech.incorporatedNoun: return '🔄';
    }
  }

  Color get color {
    switch (this) {
      case PartOfSpeech.noun: return const Color(0xFF5C6BC0);
      case PartOfSpeech.verb: return const Color(0xFFE57373);
      case PartOfSpeech.adjective: return const Color(0xFFF06292);
      case PartOfSpeech.adverb: return const Color(0xFF4DB6AC);
      case PartOfSpeech.pronoun: return const Color(0xFF9575CD);
      case PartOfSpeech.determiner: return const Color(0xFF7986CB);
      case PartOfSpeech.preposition: return const Color(0xFF4FC3F7);
      case PartOfSpeech.conjunction: return const Color(0xFF81C784);
      case PartOfSpeech.interjection: return const Color(0xFFFFB74D);
      case PartOfSpeech.numeral: return const Color(0xFF4DD0E1);
      case PartOfSpeech.classifier: return const Color(0xFFA1887F);
      case PartOfSpeech.particle: return const Color(0xFFFFD54F);
      case PartOfSpeech.auxiliaryVerb: return const Color(0xFFFF8A65);
      case PartOfSpeech.copula: return const Color(0xFF90A4AE);
      case PartOfSpeech.postposition: return const Color(0xFFCE93D8);
      case PartOfSpeech.suffix: return const Color(0xFFB0BEC5);
      case PartOfSpeech.article: return const Color(0xFF80CBC4);
      case PartOfSpeech.incorporatedNoun: return const Color(0xFFA5D6A7);
    }
  }

  /// Whether this POS is universal across all languages
  bool get isUniversal {
    const universal = {
      PartOfSpeech.noun,
      PartOfSpeech.verb,
      PartOfSpeech.adjective,
      PartOfSpeech.adverb,
      PartOfSpeech.pronoun,
      PartOfSpeech.conjunction,
      PartOfSpeech.interjection,
      PartOfSpeech.numeral,
    };
    return universal.contains(this);
  }

  /// Languages that specifically feature this POS
  List<String> get applicableLanguages {
    switch (this) {
      case PartOfSpeech.classifier:
        return ['zh', 'ja', 'ko', 'vi', 'th', 'my'];
      case PartOfSpeech.particle:
        return ['ja', 'ko', 'de', 'zh', 'vi', 'th', 'ru'];
      case PartOfSpeech.postposition:
        return ['ja', 'ko', 'tr', 'hi', 'fi', 'hu'];
      case PartOfSpeech.auxiliaryVerb:
        return ['en', 'de', 'fr', 'es', 'pt', 'it', 'nl', 'ru', 'ja'];
      case PartOfSpeech.copula:
        return ['ja', 'ko', 'ar', 'ru', 'zh'];
      case PartOfSpeech.suffix:
        return ['ja', 'ko', 'tr', 'fi', 'hu', 'de'];
      case PartOfSpeech.article:
        return ['en', 'de', 'fr', 'es', 'pt', 'it', 'nl', 'ar', 'sv', 'no'];
      case PartOfSpeech.determiner:
        return ['en', 'de', 'fr', 'es', 'pt', 'it', 'nl'];
      case PartOfSpeech.preposition:
        return ['en', 'de', 'fr', 'es', 'pt', 'it', 'nl', 'ru', 'pl', 'ar'];
      case PartOfSpeech.incorporatedNoun:
        return ['sw', 'nah']; // Swahili, Nahuatl etc.
      default:
        return []; // handled by isUniversal
    }
  }
}

/// Returns all applicable POS for a given learning language code
List<PartOfSpeech> getApplicablePOS(String languageCode) {
  return PartOfSpeech.values.where((pos) {
    if (pos.isUniversal) return true;
    return pos.applicableLanguages.contains(languageCode);
  }).toList();
}

// ================ SEMANTIC CATEGORIES ================

class SemanticCategory {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final List<String> parentIds;
  final List<String> childIds;
  final int difficulty;
  final List<String> commonPOS;

  const SemanticCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.parentIds = const [],
    this.childIds = const [],
    this.difficulty = 1,
    this.commonPOS = const ['noun'],
  });

  bool get isRoot => parentIds.isEmpty;
}

class CategoryTaxonomy {
  static final Map<String, SemanticCategory> _categories = {

    // ══════════════════════════════════════════════════════════════
    // ROOT CATEGORIES
    // ══════════════════════════════════════════════════════════════

    'people': const SemanticCategory(
      id: 'people',
      name: 'People',
      icon: '👥',
      color: Color(0xFF64B5F6),
      childIds: ['relationships', 'roles', 'identity', 'demographics', 'health_status', 'personal_traits'],
    ),
    'society': const SemanticCategory(
      id: 'society',
      name: 'Society',
      icon: '🏛️',
      color: Color(0xFF9575CD),
      childIds: ['work_business', 'economy_finance', 'government_politics', 'law_justice', 'education', 'military_security', 'religion_belief', 'media_public_life'],
    ),
    'physical_world': const SemanticCategory(
      id: 'physical_world',
      name: 'Physical World',
      icon: '🌍',
      color: Color(0xFF81C784),
      childIds: ['places', 'nature', 'body', 'objects', 'housing', 'materials', 'systems', 'food_drink', 'clothing_items'],
    ),
    'activity': const SemanticCategory(
      id: 'activity',
      name: 'Activity',
      icon: '🏃',
      color: Color(0xFFE57373),
      childIds: ['movement', 'communication', 'social_interaction', 'work_actions', 'leisure_entertainment', 'consumption', 'creation', 'destruction', 'perception', 'possession', 'change_transformation', 'control_causation'],
      commonPOS: ['verb'],
    ),
    'abstract': const SemanticCategory(
      id: 'abstract',
      name: 'Abstract',
      icon: '💭',
      color: Color(0xFFBA68C8),
      childIds: ['general_concepts', 'structure_systems', 'quality', 'quantity', 'degree_intensity', 'direction_position', 'emotion', 'cognition', 'possibility_certainty', 'value_judgment', 'cause_effect', 'condition_state'],
      commonPOS: ['noun', 'adjective'],
    ),
    'language': const SemanticCategory(
      id: 'language',
      name: 'Language',
      icon: '🔤',
      color: Color(0xFF90A4AE),
      childIds: ['words_units', 'grammar', 'communication_concepts', 'text_discourse'],
      commonPOS: ['noun', 'pronoun', 'conjunction', 'preposition'],
      difficulty: 3,
    ),
    'time': const SemanticCategory(
      id: 'time',
      name: 'Time',
      icon: '⏰',
      color: Color(0xFF4DD0E1),
      childIds: ['time_points', 'duration', 'frequency', 'sequence', 'experience', 'time_relations'],
      commonPOS: ['noun', 'adverb'],
    ),

    // ══════════════════════════════════════════════════════════════
    // PEOPLE SUB-CATEGORIES
    // ══════════════════════════════════════════════════════════════

    'relationships': const SemanticCategory(
      id: 'relationships',
      name: 'Relationships',
      icon: '💕',
      color: Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'roles': const SemanticCategory(
      id: 'roles',
      name: 'Roles',
      icon: '🎭',
      color: Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'identity': const SemanticCategory(
      id: 'identity',
      name: 'Identity',
      icon: '🪪',
      color: Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'demographics': const SemanticCategory(
      id: 'demographics',
      name: 'Demographics',
      icon: '📊',
      color: Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'health_status': const SemanticCategory(
      id: 'health_status',
      name: 'Health Status',
      icon: '🏥',
      color: Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'personal_traits': const SemanticCategory(
      id: 'personal_traits',
      name: 'Personal Traits',
      icon: '⭐',
      color: Color(0xFF64B5F6),
      parentIds: ['people'],
      commonPOS: ['adjective', 'noun'],
    ),

    // ══════════════════════════════════════════════════════════════
    // SOCIETY SUB-CATEGORIES
    // ══════════════════════════════════════════════════════════════

    'work_business': const SemanticCategory(
      id: 'work_business',
      name: 'Work & Business',
      icon: '💼',
      color: Color(0xFF9575CD),
      parentIds: ['society'],
      difficulty: 2,
    ),
    'economy_finance': const SemanticCategory(
      id: 'economy_finance',
      name: 'Economy & Finance',
      icon: '💰',
      color: Color(0xFF9575CD),
      parentIds: ['society'],
      difficulty: 3,
    ),
    'government_politics': const SemanticCategory(
      id: 'government_politics',
      name: 'Government & Politics',
      icon: '🏛️',
      color: Color(0xFF9575CD),
      parentIds: ['society'],
      difficulty: 3,
    ),
    'law_justice': const SemanticCategory(
      id: 'law_justice',
      name: 'Law & Justice',
      icon: '⚖️',
      color: Color(0xFF9575CD),
      parentIds: ['society'],
      difficulty: 3,
    ),
    'education': const SemanticCategory(
      id: 'education',
      name: 'Education',
      icon: '📚',
      color: Color(0xFF9575CD),
      parentIds: ['society'],
      difficulty: 2,
    ),
    'military_security': const SemanticCategory(
      id: 'military_security',
      name: 'Military & Security',
      icon: '🛡️',
      color: Color(0xFF9575CD),
      parentIds: ['society'],
      difficulty: 3,
    ),
    'religion_belief': const SemanticCategory(
      id: 'religion_belief',
      name: 'Religion & Belief',
      icon: '🕌',
      color: Color(0xFF9575CD),
      parentIds: ['society'],
      difficulty: 2,
    ),
    'media_public_life': const SemanticCategory(
      id: 'media_public_life',
      name: 'Media & Public Life',
      icon: '📺',
      color: Color(0xFF9575CD),
      parentIds: ['society'],
      difficulty: 2,
    ),

    // ══════════════════════════════════════════════════════════════
    // PHYSICAL WORLD SUB-CATEGORIES
    // ══════════════════════════════════════════════════════════════

    'places': const SemanticCategory(
      id: 'places',
      name: 'Places',
      icon: '📍',
      color: Color(0xFF81C784),
      parentIds: ['physical_world'],
    ),
    'nature': const SemanticCategory(
      id: 'nature',
      name: 'Nature',
      icon: '🌿',
      color: Color(0xFF81C784),
      parentIds: ['physical_world'],
    ),
    'body': const SemanticCategory(
      id: 'body',
      name: 'Body',
      icon: '🫀',
      color: Color(0xFF81C784),
      parentIds: ['physical_world'],
    ),
    'objects': const SemanticCategory(
      id: 'objects',
      name: 'Objects',
      icon: '📦',
      color: Color(0xFF81C784),
      parentIds: ['physical_world'],
    ),
    'housing': const SemanticCategory(
      id: 'housing',
      name: 'Housing',
      icon: '🏠',
      color: Color(0xFF81C784),
      parentIds: ['physical_world'],
    ),
    'materials': const SemanticCategory(
      id: 'materials',
      name: 'Materials',
      icon: '🪨',
      color: Color(0xFF81C784),
      parentIds: ['physical_world'],
    ),
    'systems': const SemanticCategory(
      id: 'systems',
      name: 'Systems',
      icon: '⚙️',
      color: Color(0xFF81C784),
      parentIds: ['physical_world'],
      difficulty: 2,
    ),
    'food_drink': const SemanticCategory(
      id: 'food_drink',
      name: 'Food & Drink',
      icon: '🍽️',
      color: Color(0xFF81C784),
      parentIds: ['physical_world'],
    ),
    'clothing_items': const SemanticCategory(
      id: 'clothing_items',
      name: 'Clothing & Items',
      icon: '👕',
      color: Color(0xFF81C784),
      parentIds: ['physical_world'],
    ),

    // ══════════════════════════════════════════════════════════════
    // ACTIVITY SUB-CATEGORIES
    // ══════════════════════════════════════════════════════════════

    'movement': const SemanticCategory(
      id: 'movement',
      name: 'Movement',
      icon: '🏃',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
    ),
    'communication': const SemanticCategory(
      id: 'communication',
      name: 'Communication',
      icon: '💬',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb', 'noun'],
    ),
    'social_interaction': const SemanticCategory(
      id: 'social_interaction',
      name: 'Social Interaction',
      icon: '🤝',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
    ),
    'work_actions': const SemanticCategory(
      id: 'work_actions',
      name: 'Work Actions',
      icon: '🔨',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
      difficulty: 2,
    ),
    'leisure_entertainment': const SemanticCategory(
      id: 'leisure_entertainment',
      name: 'Leisure & Fun',
      icon: '🎮',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb', 'noun'],
    ),
    'consumption': const SemanticCategory(
      id: 'consumption',
      name: 'Consumption',
      icon: '🛒',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
    ),
    'creation': const SemanticCategory(
      id: 'creation',
      name: 'Creation',
      icon: '🎨',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
      difficulty: 2,
    ),
    'destruction': const SemanticCategory(
      id: 'destruction',
      name: 'Destruction',
      icon: '💥',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
    ),
    'perception': const SemanticCategory(
      id: 'perception',
      name: 'Perception',
      icon: '👁️',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
      difficulty: 2,
    ),
    'possession': const SemanticCategory(
      id: 'possession',
      name: 'Possession',
      icon: '🤲',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
    ),
    'change_transformation': const SemanticCategory(
      id: 'change_transformation',
      name: 'Change',
      icon: '🔄',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
      difficulty: 2,
    ),
    'control_causation': const SemanticCategory(
      id: 'control_causation',
      name: 'Control',
      icon: '🎛️',
      color: Color(0xFFE57373),
      parentIds: ['activity'],
      commonPOS: ['verb'],
      difficulty: 2,
    ),

    // ══════════════════════════════════════════════════════════════
    // ABSTRACT SUB-CATEGORIES
    // ══════════════════════════════════════════════════════════════

    'general_concepts': const SemanticCategory(
      id: 'general_concepts',
      name: 'General Concepts',
      icon: '💡',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['noun'],
    ),
    'structure_systems': const SemanticCategory(
      id: 'structure_systems',
      name: 'Structure',
      icon: '🧱',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['noun'],
      difficulty: 2,
    ),
    'quality': const SemanticCategory(
      id: 'quality',
      name: 'Quality',
      icon: '✨',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['adjective', 'adverb'],
      difficulty: 2,
    ),
    'quantity': const SemanticCategory(
      id: 'quantity',
      name: 'Quantity',
      icon: '🔢',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['numeral', 'adjective'],
    ),
    'degree_intensity': const SemanticCategory(
      id: 'degree_intensity',
      name: 'Degree & Intensity',
      icon: '📈',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['adverb'],
      difficulty: 2,
    ),
    'direction_position': const SemanticCategory(
      id: 'direction_position',
      name: 'Direction & Position',
      icon: '🧭',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['preposition', 'adverb'],
    ),
    'emotion': const SemanticCategory(
      id: 'emotion',
      name: 'Emotion',
      icon: '😊',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['noun', 'adjective'],
    ),
    'cognition': const SemanticCategory(
      id: 'cognition',
      name: 'Cognition',
      icon: '🧠',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['noun', 'verb'],
      difficulty: 3,
    ),
    'possibility_certainty': const SemanticCategory(
      id: 'possibility_certainty',
      name: 'Possibility',
      icon: '🎲',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['adverb', 'adjective'],
      difficulty: 3,
    ),
    'value_judgment': const SemanticCategory(
      id: 'value_judgment',
      name: 'Value & Judgment',
      icon: '⚖️',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['adjective', 'noun'],
      difficulty: 2,
    ),
    'cause_effect': const SemanticCategory(
      id: 'cause_effect',
      name: 'Cause & Effect',
      icon: '🔗',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['conjunction', 'noun'],
      difficulty: 3,
    ),
    'condition_state': const SemanticCategory(
      id: 'condition_state',
      name: 'Condition & State',
      icon: '🌡️',
      color: Color(0xFFBA68C8),
      parentIds: ['abstract'],
      commonPOS: ['adjective', 'noun'],
      difficulty: 2,
    ),

    // ══════════════════════════════════════════════════════════════
    // LANGUAGE SUB-CATEGORIES
    // ══════════════════════════════════════════════════════════════

    'words_units': const SemanticCategory(
      id: 'words_units',
      name: 'Words & Units',
      icon: '🔤',
      color: Color(0xFF90A4AE),
      parentIds: ['language'],
      commonPOS: ['noun'],
    ),
    'grammar': const SemanticCategory(
      id: 'grammar',
      name: 'Grammar',
      icon: '📝',
      color: Color(0xFF90A4AE),
      parentIds: ['language'],
      commonPOS: ['pronoun', 'preposition', 'conjunction', 'particle'],
      difficulty: 3,
    ),
    'communication_concepts': const SemanticCategory(
      id: 'communication_concepts',
      name: 'Communication',
      icon: '📡',
      color: Color(0xFF90A4AE),
      parentIds: ['language'],
      commonPOS: ['noun', 'verb'],
      difficulty: 2,
    ),
    'text_discourse': const SemanticCategory(
      id: 'text_discourse',
      name: 'Text & Discourse',
      icon: '📄',
      color: Color(0xFF90A4AE),
      parentIds: ['language'],
      commonPOS: ['noun'],
      difficulty: 3,
    ),

    // ══════════════════════════════════════════════════════════════
    // TIME SUB-CATEGORIES
    // ══════════════════════════════════════════════════════════════

    'time_points': const SemanticCategory(
      id: 'time_points',
      name: 'Time Points',
      icon: '📅',
      color: Color(0xFF4DD0E1),
      parentIds: ['time'],
      commonPOS: ['noun', 'adverb'],
    ),
    'duration': const SemanticCategory(
      id: 'duration',
      name: 'Duration',
      icon: '⏱️',
      color: Color(0xFF4DD0E1),
      parentIds: ['time'],
      commonPOS: ['noun', 'adverb'],
    ),
    'frequency': const SemanticCategory(
      id: 'frequency',
      name: 'Frequency',
      icon: '🔁',
      color: Color(0xFF4DD0E1),
      parentIds: ['time'],
      commonPOS: ['adverb'],
      difficulty: 2,
    ),
    'sequence': const SemanticCategory(
      id: 'sequence',
      name: 'Sequence',
      icon: '1️⃣',
      color: Color(0xFF4DD0E1),
      parentIds: ['time'],
      commonPOS: ['adverb', 'noun'],
    ),
    'experience': const SemanticCategory(
      id: 'experience',
      name: 'Experience',
      icon: '🌟',
      color: Color(0xFF4DD0E1),
      parentIds: ['time'],
      commonPOS: ['noun', 'verb'],
      difficulty: 2,
    ),
    'time_relations': const SemanticCategory(
      id: 'time_relations',
      name: 'Time Relations',
      icon: '🔀',
      color: Color(0xFF4DD0E1),
      parentIds: ['time'],
      commonPOS: ['preposition', 'conjunction'],
      difficulty: 2,
    ),
  };

  static SemanticCategory? getCategory(String id) => _categories[id];

  static List<SemanticCategory> getRootCategories() {
    return _categories.values.where((c) => c.isRoot).toList();
  }

  static List<SemanticCategory> getSubCategories(String parentId) {
    return _categories.values
        .where((c) => c.parentIds.contains(parentId))
        .toList();
  }

  static List<SemanticCategory> getAllCategories() {
    return _categories.values.toList();
  }

  /// Returns only root categories for the PATHWAYS overview
  static List<SemanticCategory> getPathwayCategories() => getRootCategories();
}
