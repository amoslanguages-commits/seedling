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
  final String? partOfSpeechRaw;
  final List<String> categoryIds;

  // Enhanced metadata
  final String? gender;
  final String? definition;
  final String? exampleSentence;
  final String? exampleSentenceTranslation;
  final String? exampleSentencePronunciation;
  final String? pronunciation;
  final String? etymology;
  final String? article;
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

  // FSRS (Free Spaced Repetition Scheduler) state fields
  double fsrsStability;
  double fsrsDifficulty;
  int fsrsElapsedDays;
  int fsrsScheduledDays;
  int fsrsReps;
  int fsrsLapses;
  int fsrsState; // 0: New, 1: Learning, 2: Review, 3: Relearning

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
    this.partOfSpeechRaw,
    this.categoryIds = const ['general'],
    this.gender,
    this.definition,
    this.exampleSentence,
    this.exampleSentenceTranslation,
    this.exampleSentencePronunciation,
    this.pronunciation,
    this.etymology,
    this.article,
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
    this.fsrsStability = 0.0,
    this.fsrsDifficulty = 0.0,
    this.fsrsElapsedDays = 0,
    this.fsrsScheduledDays = 0,
    this.fsrsReps = 0,
    this.fsrsLapses = 0,
    this.fsrsState = 0,
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

  PartOfSpeech get primaryPOS =>
      partsOfSpeech.isNotEmpty ? partsOfSpeech.first : PartOfSpeech.noun;

  // Article support for target languages
  bool get hasTargetArticle {
    if (!partsOfSpeech.contains(PartOfSpeech.noun)) return false;
    // Check if target language requires article prefixing
    if (![
      'de',
      'nl',
      'es',
      'fr',
      'it',
      'pt',
      'ca',
    ].contains(targetLanguageCode.toLowerCase())) {
      return false;
    }
    return languageSpecific['article'] != null &&
        languageSpecific['article'].toString().isNotEmpty;
  }

  String get targetArticle =>
      hasTargetArticle ? languageSpecific['article']!.toString() : '';

  // Use this whenever playing the word through TTS
  String get ttsWord {
    final art = hasTargetArticle ? targetArticle : (article ?? '');
    return art.isNotEmpty ? '$art $word' : word;
  }

  // ── Botanical Growth Logic (Stability-Driven) ──────────────────────────
  
  String get botanicalRank {
    if (fsrsStability >= 90) return 'Great Bloom';
    if (fsrsStability >= 30) return 'Oak';
    if (fsrsStability >= 10) return 'Sapling';
    if (fsrsStability >= 2) return 'Sprout';
    return 'Seedling';
  }

  String get rankEmoji {
    if (fsrsStability >= 90) return '🌸';
    if (fsrsStability >= 30) return '🌳';
    if (fsrsStability >= 10) return '🌲';
    if (fsrsStability >= 2) return '🌿';
    return '🌱';
  }

  // Quiz Helpers for Multiplayer Arena
  List<String>? _customOptions;
  void setOptions(List<String> opt) => _customOptions = opt;

  String get question => word; // Show the target word as the question

  // Use provided options or fall back to native translation with placeholders
  List<String> get options {
    if (_customOptions != null && _customOptions!.isNotEmpty) {
      return _customOptions!;
    }
    return [translation, 'Option A', 'Option B', 'Option C']..shuffle();
  }

  int get correctIndex => options.indexOf(translation);

  String get pos =>
      partsOfSpeech.isNotEmpty ? partsOfSpeech.first.name : 'Noun';

  static Word fromJson(Map<String, dynamic> json) => Word.fromMap(json);

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
      'part_of_speech_raw': partOfSpeechRaw,
      'category_ids': categoryIds.join(','),
      'gender': gender,
      'definition': definition,
      'example_sentence': exampleSentence,
      'example_sentence_translation': exampleSentenceTranslation,
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
      'image_id': imageId,
      'language_specific': languageSpecific.isNotEmpty
          ? jsonEncode(languageSpecific)
          : null,
      'fsrs_stability': fsrsStability,
      'fsrs_difficulty': fsrsDifficulty,
      'fsrs_elapsed_days': fsrsElapsedDays,
      'fsrs_scheduled_days': fsrsScheduledDays,
      'fsrs_reps': fsrsReps,
      'fsrs_lapses': fsrsLapses,
      'fsrs_state': fsrsState,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    // Handle difficulty string to int conversion if coming from old DB
    int difficultyInt = 1;
    if (map['difficulty'] is String) {
      switch (map['difficulty']) {
        case 'beginner':
          difficultyInt = 1;
          break;
        case 'intermediate':
          difficultyInt = 3;
          break;
        case 'advanced':
          difficultyInt = 5;
          break;
        default:
          difficultyInt = 1;
      }
    } else {
      difficultyInt = int.tryParse(map['difficulty']?.toString() ?? '') ?? 1;
    }

    return Word(
      id: int.tryParse(map['vocabulary_id']?.toString() ?? map['id']?.toString() ?? '') ,
      word: map['word'] ?? '',
      translation:
          map['translation'] ??
          map['meaning'] ??
          map['word'] ??
          '', // Prioritize literal translation
      languageCode: map['lang_code'] ?? map['language_code'] ?? 'en',
      targetLanguageCode: map['target_language_code'] ?? 'de',
      conceptId: map['concept_id'],
      conceptType: map['concept_type'],
      domain: map['domain'],
      subDomain: map['sub_domain'],
      microCategory: map['micro_category'],
      partsOfSpeech:
          (map['part_of_speech'] as String? ??
                  map['parts_of_speech'] as String? ??
                  'noun')
              .split(',')
              .where((s) => s.isNotEmpty)
              .map(
                (s) => PartOfSpeech.values.firstWhere(
                  (e) => e.name == s.toLowerCase(),
                  orElse: () => PartOfSpeech.noun,
                ),
              )
              .toList(),
      partOfSpeechRaw: map['part_of_speech'] ?? map['part_of_speech_raw'],
      categoryIds:
          (map['category_ids'] as String? ??
                  map['category'] as String? ??
                  'general')
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(),
      gender: map['gender'],
      definition: map['definition'],
      exampleSentence: map['example_sentence'],
      exampleSentenceTranslation: map['example_sentence_translation'],
      exampleSentencePronunciation: map['example_sentence_pronunciation'],
      pronunciation: map['pronunciation'],
      etymology: map['etymology'],
      tags: (map['tags'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      difficulty: difficultyInt,
      frequency: map['frequency'],
      masteryLevel: int.tryParse(map['mastery_level']?.toString() ?? '') ?? 0,
      lastReviewed: map['last_reviewed'] != null
          ? DateTime.parse(map['last_reviewed'])
          : null,
      nextReview: map['next_review'] != null
          ? DateTime.parse(map['next_review'])
          : null,
      streak: int.tryParse(map['streak']?.toString() ?? '') ?? 0,
      totalReviews: int.tryParse(map['total_reviews']?.toString() ?? '') ?? 0,
      timesCorrect: int.tryParse(map['times_correct']?.toString() ?? '') ?? 0,
      imageId: map['image_id'],
      languageSpecific: map['language_specific'] != null
          ? (map['language_specific'] is String
                ? jsonDecode(map['language_specific'])
                : map['language_specific'])
          : {},
      article: map['article'],
      fsrsStability: (map['fsrs_stability'] as num?)?.toDouble() ?? 0.0,
      fsrsDifficulty: (map['fsrs_difficulty'] as num?)?.toDouble() ?? 0.0,
      fsrsElapsedDays: int.tryParse(map['fsrs_elapsed_days']?.toString() ?? '') ?? 0,
      fsrsScheduledDays: int.tryParse(map['fsrs_scheduled_days']?.toString() ?? '') ?? 0,
      fsrsReps: int.tryParse(map['fsrs_reps']?.toString() ?? '') ?? 0,
      fsrsLapses: int.tryParse(map['fsrs_lapses']?.toString() ?? '') ?? 0,
      fsrsState: int.tryParse(map['fsrs_state']?.toString() ?? '') ?? 0,
    );
  }
}
