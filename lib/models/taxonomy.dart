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

  SemanticCategory({
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
    // ================== ROOT THEMES ==================
    'people': SemanticCategory(
      id: 'people',
      name: 'People',
      icon: '👥',
      color: const Color(0xFF64B5F6),
      childIds: ['identity', 'relationships', 'roles', 'traits', 'emotions', 'health'],
    ),
    'daily_life': SemanticCategory(
      id: 'daily_life',
      name: 'Daily Life',
      icon: '🌅',
      color: const Color(0xFFF06292),
      childIds: ['activities', 'household', 'shopping', 'communication'],
    ),
    'food_drink': SemanticCategory(
      id: 'food_drink',
      name: 'Food & Drink',
      icon: '🍽️',
      color: const Color(0xFFFFB74D),
      childIds: ['fruits', 'vegetables', 'meals', 'drinks', 'cooking', 'taste'],
    ),
    'home_environment': SemanticCategory(
      id: 'home_environment',
      name: 'Home & Environment',
      icon: '🏠',
      color: const Color(0xFF81C784),
      childIds: ['house', 'furniture', 'objects', 'nature', 'weather'],
    ),
    'education': SemanticCategory(
      id: 'education',
      name: 'Education',
      icon: '📚',
      color: const Color(0xFF4FC3F7),
      childIds: ['institutions', 'subjects', 'learning_actions', 'evaluation'],
    ),
    'work_business': SemanticCategory(
      id: 'work_business',
      name: 'Work & Business',
      icon: '💼',
      color: const Color(0xFF9575CD),
      childIds: ['jobs', 'workplace', 'business', 'finance'],
    ),
    'travel_transport': SemanticCategory(
      id: 'travel_transport',
      name: 'Travel & Transport',
      icon: '✈️',
      color: const Color(0xFF4DD0E1),
      childIds: ['transport', 'places', 'accommodation', 'travel_actions'],
    ),
    'society_government': SemanticCategory(
      id: 'society_government',
      name: 'Society & Government',
      icon: '🏛️',
      color: const Color(0xFF7986CB),
      childIds: ['government', 'politics', 'law', 'community'],
    ),
    'technology': SemanticCategory(
      id: 'technology',
      name: 'Technology',
      icon: '💻',
      color: const Color(0xFF90A4AE),
      childIds: ['devices', 'internet', 'actions', 'digital_life'],
    ),
    'time_space': SemanticCategory(
      id: 'time_space',
      name: 'Time & Space',
      icon: '🕰️',
      color: const Color(0xFFFF8A65),
      childIds: ['time', 'frequency', 'sequence', 'space'],
    ),
    'numbers_measurement': SemanticCategory(
      id: 'numbers_measurement',
      name: 'Numbers & Measurement',
      icon: '🔢',
      color: const Color(0xFF4DB6AC),
      childIds: ['numbers', 'quantity', 'measurement', 'comparison'],
    ),
    'universal_verbs': SemanticCategory(
      id: 'universal_verbs',
      name: 'Universal Verbs',
      icon: '⚡',
      color: const Color(0xFFE57373),
      childIds: ['movement', 'creation', 'thinking', 'change', 'possession', 'existence'],
      commonPOS: ['verb'],
    ),
    'descriptions': SemanticCategory(
      id: 'descriptions',
      name: 'Descriptions',
      icon: '🎨',
      color: const Color(0xFFCE93D8),
      childIds: ['size', 'color', 'shape', 'speed', 'intensity', 'quality'],
      commonPOS: ['adjective', 'adverb'],
    ),
    'abstract_concepts': SemanticCategory(
      id: 'abstract_concepts',
      name: 'Abstract Concepts',
      icon: '💭',
      color: const Color(0xFFBA68C8),
      childIds: ['ideas', 'states', 'systems', 'relationships'],
      commonPOS: ['noun'],
    ),
    'grammar_functions': SemanticCategory(
      id: 'grammar_functions',
      name: 'Grammar Functions',
      icon: '🔧',
      color: const Color(0xFFB0BEC5),
      childIds: ['pronouns', 'determiners_articles', 'prepositions', 'adverbs', 'conjunctions', 'auxiliary_modal_verbs', 'particles_markers'],
      commonPOS: ['pronoun', 'preposition', 'conjunction'],
    ),

    // ================== SUB THEMES ==================
    'identity': SemanticCategory(
      id: 'identity',
      name: 'Identity',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'relationships': SemanticCategory(
      id: 'relationships',
      name: 'Relationships',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'roles': SemanticCategory(
      id: 'roles',
      name: 'Roles',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'traits': SemanticCategory(
      id: 'traits',
      name: 'Traits',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'emotions': SemanticCategory(
      id: 'emotions',
      name: 'Emotions',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'health': SemanticCategory(
      id: 'health',
      name: 'Health',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF64B5F6),
      parentIds: ['people'],
    ),
    'activities': SemanticCategory(
      id: 'activities',
      name: 'Activities',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFF06292),
      parentIds: ['daily_life'],
    ),
    'household': SemanticCategory(
      id: 'household',
      name: 'Household',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFF06292),
      parentIds: ['daily_life'],
    ),
    'shopping': SemanticCategory(
      id: 'shopping',
      name: 'Shopping',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFF06292),
      parentIds: ['daily_life'],
    ),
    'communication': SemanticCategory(
      id: 'communication',
      name: 'Communication',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFF06292),
      parentIds: ['daily_life'],
    ),
    'fruits': SemanticCategory(
      id: 'fruits',
      name: 'Fruits',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFFB74D),
      parentIds: ['food_drink'],
    ),
    'vegetables': SemanticCategory(
      id: 'vegetables',
      name: 'Vegetables',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFFB74D),
      parentIds: ['food_drink'],
    ),
    'meals': SemanticCategory(
      id: 'meals',
      name: 'Meals',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFFB74D),
      parentIds: ['food_drink'],
    ),
    'drinks': SemanticCategory(
      id: 'drinks',
      name: 'Drinks',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFFB74D),
      parentIds: ['food_drink'],
    ),
    'cooking': SemanticCategory(
      id: 'cooking',
      name: 'Cooking',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFFB74D),
      parentIds: ['food_drink'],
    ),
    'taste': SemanticCategory(
      id: 'taste',
      name: 'Taste',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFFB74D),
      parentIds: ['food_drink'],
    ),
    'house': SemanticCategory(
      id: 'house',
      name: 'House',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF81C784),
      parentIds: ['home_environment'],
    ),
    'furniture': SemanticCategory(
      id: 'furniture',
      name: 'Furniture',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF81C784),
      parentIds: ['home_environment'],
    ),
    'objects': SemanticCategory(
      id: 'objects',
      name: 'Objects',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF81C784),
      parentIds: ['home_environment'],
    ),
    'nature': SemanticCategory(
      id: 'nature',
      name: 'Nature',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF81C784),
      parentIds: ['home_environment'],
    ),
    'weather': SemanticCategory(
      id: 'weather',
      name: 'Weather',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF81C784),
      parentIds: ['home_environment'],
    ),
    'institutions': SemanticCategory(
      id: 'institutions',
      name: 'Institutions',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4FC3F7),
      parentIds: ['education'],
    ),
    'subjects': SemanticCategory(
      id: 'subjects',
      name: 'Subjects',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4FC3F7),
      parentIds: ['education'],
    ),
    'learning_actions': SemanticCategory(
      id: 'learning_actions',
      name: 'Learning Actions',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4FC3F7),
      parentIds: ['education'],
    ),
    'evaluation': SemanticCategory(
      id: 'evaluation',
      name: 'Evaluation',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4FC3F7),
      parentIds: ['education'],
    ),
    'jobs': SemanticCategory(
      id: 'jobs',
      name: 'Jobs',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF9575CD),
      parentIds: ['work_business'],
    ),
    'workplace': SemanticCategory(
      id: 'workplace',
      name: 'Workplace',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF9575CD),
      parentIds: ['work_business'],
    ),
    'business': SemanticCategory(
      id: 'business',
      name: 'Business',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF9575CD),
      parentIds: ['work_business'],
    ),
    'finance': SemanticCategory(
      id: 'finance',
      name: 'Finance',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF9575CD),
      parentIds: ['work_business'],
    ),
    'transport': SemanticCategory(
      id: 'transport',
      name: 'Transport',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4DD0E1),
      parentIds: ['travel_transport'],
    ),
    'places': SemanticCategory(
      id: 'places',
      name: 'Places',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4DD0E1),
      parentIds: ['travel_transport'],
    ),
    'accommodation': SemanticCategory(
      id: 'accommodation',
      name: 'Accommodation',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4DD0E1),
      parentIds: ['travel_transport'],
    ),
    'travel_actions': SemanticCategory(
      id: 'travel_actions',
      name: 'Travel Actions',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4DD0E1),
      parentIds: ['travel_transport'],
    ),
    'government': SemanticCategory(
      id: 'government',
      name: 'Government',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF7986CB),
      parentIds: ['society_government'],
    ),
    'politics': SemanticCategory(
      id: 'politics',
      name: 'Politics',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF7986CB),
      parentIds: ['society_government'],
    ),
    'law': SemanticCategory(
      id: 'law',
      name: 'Law',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF7986CB),
      parentIds: ['society_government'],
    ),
    'community': SemanticCategory(
      id: 'community',
      name: 'Community',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF7986CB),
      parentIds: ['society_government'],
    ),
    'devices': SemanticCategory(
      id: 'devices',
      name: 'Devices',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF90A4AE),
      parentIds: ['technology'],
    ),
    'internet': SemanticCategory(
      id: 'internet',
      name: 'Internet',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF90A4AE),
      parentIds: ['technology'],
    ),
    'actions': SemanticCategory(
      id: 'actions',
      name: 'Actions',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF90A4AE),
      parentIds: ['technology'],
    ),
    'digital_life': SemanticCategory(
      id: 'digital_life',
      name: 'Digital Life',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF90A4AE),
      parentIds: ['technology'],
    ),
    'time': SemanticCategory(
      id: 'time',
      name: 'Time',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFF8A65),
      parentIds: ['time_space'],
    ),
    'frequency': SemanticCategory(
      id: 'frequency',
      name: 'Frequency',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFF8A65),
      parentIds: ['time_space'],
    ),
    'sequence': SemanticCategory(
      id: 'sequence',
      name: 'Sequence',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFF8A65),
      parentIds: ['time_space'],
    ),
    'space': SemanticCategory(
      id: 'space',
      name: 'Space',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFFF8A65),
      parentIds: ['time_space'],
    ),
    'numbers': SemanticCategory(
      id: 'numbers',
      name: 'Numbers',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4DB6AC),
      parentIds: ['numbers_measurement'],
    ),
    'quantity': SemanticCategory(
      id: 'quantity',
      name: 'Quantity',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4DB6AC),
      parentIds: ['numbers_measurement'],
    ),
    'measurement': SemanticCategory(
      id: 'measurement',
      name: 'Measurement',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4DB6AC),
      parentIds: ['numbers_measurement'],
    ),
    'comparison': SemanticCategory(
      id: 'comparison',
      name: 'Comparison',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFF4DB6AC),
      parentIds: ['numbers_measurement'],
    ),
    'movement': SemanticCategory(
      id: 'movement',
      name: 'Movement',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFE57373),
      parentIds: ['universal_verbs'],
    ),
    'creation': SemanticCategory(
      id: 'creation',
      name: 'Creation',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFE57373),
      parentIds: ['universal_verbs'],
    ),
    'thinking': SemanticCategory(
      id: 'thinking',
      name: 'Thinking',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFE57373),
      parentIds: ['universal_verbs'],
    ),
    'change': SemanticCategory(
      id: 'change',
      name: 'Change',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFE57373),
      parentIds: ['universal_verbs'],
    ),
    'possession': SemanticCategory(
      id: 'possession',
      name: 'Possession',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFE57373),
      parentIds: ['universal_verbs'],
    ),
    'existence': SemanticCategory(
      id: 'existence',
      name: 'Existence',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFE57373),
      parentIds: ['universal_verbs'],
    ),
    'size': SemanticCategory(
      id: 'size',
      name: 'Size',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFCE93D8),
      parentIds: ['descriptions'],
    ),
    'color': SemanticCategory(
      id: 'color',
      name: 'Color',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFCE93D8),
      parentIds: ['descriptions'],
    ),
    'shape': SemanticCategory(
      id: 'shape',
      name: 'Shape',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFCE93D8),
      parentIds: ['descriptions'],
    ),
    'speed': SemanticCategory(
      id: 'speed',
      name: 'Speed',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFCE93D8),
      parentIds: ['descriptions'],
    ),
    'intensity': SemanticCategory(
      id: 'intensity',
      name: 'Intensity',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFCE93D8),
      parentIds: ['descriptions'],
    ),
    'quality': SemanticCategory(
      id: 'quality',
      name: 'Quality',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFCE93D8),
      parentIds: ['descriptions'],
    ),
    'ideas': SemanticCategory(
      id: 'ideas',
      name: 'Ideas',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFBA68C8),
      parentIds: ['abstract_concepts'],
    ),
    'states': SemanticCategory(
      id: 'states',
      name: 'States',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFBA68C8),
      parentIds: ['abstract_concepts'],
    ),
    'systems': SemanticCategory(
      id: 'systems',
      name: 'Systems',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFBA68C8),
      parentIds: ['abstract_concepts'],
    ),
    'pronouns': SemanticCategory(
      id: 'pronouns',
      name: 'Pronouns',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFB0BEC5),
      parentIds: ['grammar_functions'],
    ),
    'determiners_articles': SemanticCategory(
      id: 'determiners_articles',
      name: 'Determiners & Articles',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFB0BEC5),
      parentIds: ['grammar_functions'],
    ),
    'prepositions': SemanticCategory(
      id: 'prepositions',
      name: 'Prepositions',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFB0BEC5),
      parentIds: ['grammar_functions'],
    ),
    'adverbs': SemanticCategory(
      id: 'adverbs',
      name: 'Adverbs',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFB0BEC5),
      parentIds: ['grammar_functions'],
    ),
    'conjunctions': SemanticCategory(
      id: 'conjunctions',
      name: 'Conjunctions',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFB0BEC5),
      parentIds: ['grammar_functions'],
    ),
    'auxiliary_modal_verbs': SemanticCategory(
      id: 'auxiliary_modal_verbs',
      name: 'Auxiliary & Modal Verbs',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFB0BEC5),
      parentIds: ['grammar_functions'],
    ),
    'particles_markers': SemanticCategory(
      id: 'particles_markers',
      name: 'Particles & Markers',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color(0xFFB0BEC5),
      parentIds: ['grammar_functions'],
    ),
  };

  static SemanticCategory? getCategory(String id) => _categories[id];
  
  static SemanticCategory? getTheme(String domainName) {
    return _categories.values.firstWhere(
      (c) => c.isRoot && c.name.toLowerCase() == domainName.toLowerCase(),
      orElse: () => _categories.values.first,
    );
  }

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

  static List<SemanticCategory> getPathwayCategories() => getRootCategories();
}
