import 'dart:convert';
import 'taxonomy.dart';

class Word {
  final int? id;
  final String word;
  final String translation;
  final String languageCode;
  final String targetLanguageCode;
  
  // New taxonomy support
  final String? conceptId;
  final String? conceptType;
  final String? domain;
  final String? subDomain;
  final String? microCategory;
  final List<PartOfSpeech> partsOfSpeech;
  final List<String> categoryIds;
  
  // Enhanced metadata
  final String? gender;
  final String? definition;
  final String? exampleSentence;
  final String? exampleSentencePronunciation;
  final String? pronunciation;
  final String? etymology;
  final List<String> tags;
  final int difficulty; // Changed from String to int (1-5)
  
  // Learning progress
  int masteryLevel;
  DateTime? lastReviewed;
  DateTime? nextReview;
  int streak;
  int totalReviews;
  int timesCorrect; // New field from taxonomy
  
  // Image illustration
  final String? imageId; // e.g. 'Img_42' → assets/images/words/Img_42.jpg

  // Language-specific
  final String? frequency;
  final Map<String, dynamic> languageSpecific;
  
  Word({
    this.id,
    required this.word,
    required this.translation,
    required this.languageCode,
    required this.targetLanguageCode,
    this.conceptId,
    this.conceptType,
    this.domain,
    this.subDomain,
    this.microCategory,
    this.partsOfSpeech = const [PartOfSpeech.noun],
    this.categoryIds = const ['general'],
    this.gender,
    this.definition,
    this.exampleSentence,
    this.exampleSentencePronunciation,
    this.pronunciation,
    this.etymology,
    this.tags = const [],
    this.difficulty = 1,
    this.frequency,
    this.masteryLevel = 0,
    this.lastReviewed,
    this.nextReview,
    this.streak = 0,
    this.totalReviews = 0,
    this.timesCorrect = 0,
    this.languageSpecific = const {},
    this.imageId,
  });

  // Compatibility getter for old 'category' field
  String get category => categoryIds.isNotEmpty ? categoryIds.first : 'general';

  // Check if word belongs to a category (handles hierarchy)
  bool belongsToCategory(String categoryId) {
    if (categoryIds.contains(categoryId)) return true;
    
    // Check parent categories
    for (final id in categoryIds) {
      final cat = CategoryTaxonomy.getCategory(id);
      if (cat != null && cat.parentIds.contains(categoryId)) return true;
    }
    
    return false;
  }

  // Get all applicable categories (including parents)
  List<SemanticCategory> getAllCategories() {
    final allCats = <SemanticCategory>{};
    
    for (final id in categoryIds) {
      final cat = CategoryTaxonomy.getCategory(id);
      if (cat != null) {
        allCats.add(cat);
        // Add parents
        for (final parentId in cat.parentIds) {
          final parent = CategoryTaxonomy.getCategory(parentId);
          if (parent != null) allCats.add(parent);
        }
      }
    }
    
    return allCats.toList();
  }

  SemanticCategory? get primaryCategory {
    if (categoryIds.isEmpty) return null;
    return CategoryTaxonomy.getCategory(categoryIds.first);
  }

  PartOfSpeech get primaryPOS => partsOfSpeech.isNotEmpty 
      ? partsOfSpeech.first 
      : PartOfSpeech.noun;
      
  // Article support for target languages
  bool get hasTargetArticle {
    if (!partsOfSpeech.contains(PartOfSpeech.noun)) return false;
    // Check if target language requires article prefixing
    if (!['de', 'nl', 'es', 'fr', 'it', 'pt', 'ca'].contains(targetLanguageCode.toLowerCase())) return false;
    return languageSpecific['article'] != null && languageSpecific['article'].toString().isNotEmpty;
  }

  String get targetArticle => hasTargetArticle ? languageSpecific['article']!.toString() : '';

  // Use this whenever playing the word through TTS
  String get ttsWord => hasTargetArticle ? '$targetArticle $word' : word;
  
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'language_code': languageCode,
      'target_language_code': targetLanguageCode,
      'concept_id': conceptId,
      'concept_type': conceptType,
      'domain': domain,
      'sub_domain': subDomain,
      'micro_category': microCategory,
      'parts_of_speech': partsOfSpeech.map((p) => p.name).join(','),
      'category_ids': categoryIds.join(','),
      'gender': gender,
      'definition': definition,
      'example_sentence': exampleSentence,
      'example_sentence_pronunciation': exampleSentencePronunciation,
      'pronunciation': pronunciation,
      'etymology': etymology,
      'tags': tags.join(','),
      'difficulty': difficulty,
      'frequency': frequency,
      'mastery_level': masteryLevel,
      'last_reviewed': lastReviewed?.toIso8601String(),
      'next_review': nextReview?.toIso8601String(),
      'streak': streak,
      'total_reviews': totalReviews,
      'times_correct': timesCorrect,
      'language_specific': languageSpecific.isNotEmpty 
          ? jsonEncode(languageSpecific) 
          : null,
      'image_id': imageId,
      // Keep 'category' for minor compatibility during transition if needed
      'category': category, 
    };
  }
  
  factory Word.fromMap(Map<String, dynamic> map) {
    // Handle difficulty string to int conversion if coming from old DB
    int difficultyInt = 1;
    if (map['difficulty'] is String) {
      switch (map['difficulty']) {
        case 'beginner': difficultyInt = 1; break;
        case 'intermediate': difficultyInt = 3; break;
        case 'advanced': difficultyInt = 5; break;
        default: difficultyInt = 1;
      }
    } else {
      difficultyInt = map['difficulty'] ?? 1;
    }

    return Word(
      id: map['id'],
      word: map['word'],
      translation: map['translation'],
      languageCode: map['language_code'],
      targetLanguageCode: map['target_language_code'],
      conceptId: map['concept_id'],
      conceptType: map['concept_type'],
      domain: map['domain'],
      subDomain: map['sub_domain'],
      microCategory: map['micro_category'],
      partsOfSpeech: (map['parts_of_speech'] as String? ?? 'noun')
          .split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => PartOfSpeech.values.firstWhere(
                (e) => e.name == s,
                orElse: () => PartOfSpeech.noun,
              ))
          .toList(),
      categoryIds: (map['category_ids'] as String? ?? map['category'] as String? ?? 'general')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      gender: map['gender'],
      definition: map['definition'],
      exampleSentence: map['example_sentence'],
      exampleSentencePronunciation: map['example_sentence_pronunciation'],
      pronunciation: map['pronunciation'],
      etymology: map['etymology'],
      tags: (map['tags'] as String? ?? '').split(',').where((s) => s.isNotEmpty).toList(),
      difficulty: difficultyInt,
      frequency: map['frequency'],
      masteryLevel: map['mastery_level'] ?? 0,
      lastReviewed: map['last_reviewed'] != null 
          ? DateTime.parse(map['last_reviewed']) 
          : null,
      nextReview: map['next_review'] != null 
          ? DateTime.parse(map['next_review']) 
          : null,
      streak: map['streak'] ?? 0,
      totalReviews: map['total_reviews'] ?? 0,
      timesCorrect: map['times_correct'] ?? 0,
      imageId: map['image_id'],
      languageSpecific: map['language_specific'] != null 
          ? jsonDecode(map['language_specific']) 
          : {},
    );
  }
}
