import 'package:flutter/services.dart' show rootBundle;
import '../models/word.dart';
import '../models/taxonomy.dart';
import '../database/database_helper.dart';

class VocabularyService {
  static const String csvFilePath = 'assets/database/vocabulary.csv';

  /// Parses the huge CSV file and returns a map of conceptId -> rowData
  /// for a specific language code.
  static Future<Map<int, List<dynamic>>> _loadLanguageData(String langCode) async {
    final csvString = await rootBundle.loadString(csvFilePath);
    
    final lines = csvString.split('\n');
    if (lines.isEmpty) return {};
    
    final map = <int, List<dynamic>>{};
    
    // Pattern matches commas not inside quotes
    final RegExp splitPattern = RegExp(r',(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)');
    
    // Skip header (row 0)
    for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final row = line.split(splitPattern).map((s) {
          // Remove surrounding quotes if they exist
          String clean = s.trim();
          if (clean.startsWith('"') && clean.endsWith('"')) {
            clean = clean.substring(1, clean.length - 1);
          }
          return clean;
        }).toList();

        if (row.length < 10) continue;
        
        final String rowLangCode = row[2].toString().trim().toLowerCase();
        final String normalizedTarget = langCode.toLowerCase();
        final String baseTarget = normalizedTarget.split('-')[0];
        
        if (rowLangCode == normalizedTarget || rowLangCode == baseTarget) {
            final int conceptId = int.tryParse(row[1].toString()) ?? -1;
            if (conceptId != -1) {
            map[conceptId] = row;
            }
        }
    }
    
    return map;
  }

  /// Looks up a Theme ID by its display name.
  static String? _findThemeIdByName(String name) {
    if (name.isEmpty) return null;
    final theme = CategoryTaxonomy.getTheme(name);
    return theme?.id;
  }

  /// Looks up a Sub-theme ID by its display name.
  static String? _findSubThemeIdByName(String subThemeName, String? themeName) {
    if (subThemeName.isEmpty) return null;
    
    // First try a global search for the sub-theme name
    for (final cat in CategoryTaxonomy.getAllCategories()) {
      if (!cat.isRoot && cat.name.toLowerCase() == subThemeName.toLowerCase()) {
        return cat.id;
      }
    }
    return null;
  }

  /// New ingestion engine for the 8-column format:
  /// Theme, Sub-theme, Micro-category, Native Word, Translation, Definition, Example, Pronunciation
  static Future<void> importFromNewCsv(
    String csvData, 
    String nativeLangCode, 
    String targetLangCode
  ) async {
    final lines = csvData.split('\n');
    if (lines.isEmpty) return;

    final dbHelper = DatabaseHelper();
    final List<Word> batchWords = [];
    
    // Pattern matches commas not inside quotes
    final RegExp splitPattern = RegExp(r',(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)');

    // Skip header if it exists (check if first row contains 'Theme')
    int startIndex = 0;
    if (lines[0].toLowerCase().contains('theme')) {
      startIndex = 1;
    }

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final row = line.split(splitPattern).map((s) {
        String clean = s.trim();
        if (clean.startsWith('"') && clean.endsWith('"')) {
          clean = clean.substring(1, clean.length - 1);
        }
        return clean;
      }).toList();

      if (row.length < 5) continue; // Minimum required: Theme, Sub, Micro, Native, Translation

      final String themeName = row[0];
      final String subThemeName = row[1];
      final String microCategory = row[2];
      final String nativeWord = row[3];
      final String translation = row[4];
      final String definition = row.length > 5 ? row[5] : '';
      final String example = row.length > 6 ? row[6] : '';
      final String examplePronunciation = row.length > 7 ? row[7] : '';

      // Determine IDs for legacy compatibility
      final String? themeId = _findThemeIdByName(themeName);
      final String? subThemeId = _findSubThemeIdByName(subThemeName, themeName);
      
      final List<String> categoryIds = [];
      if (themeId != null) categoryIds.add(themeId);
      if (subThemeId != null) categoryIds.add(subThemeId);
      if (categoryIds.isEmpty) categoryIds.add('general');

      final word = Word(
        word: translation, // In our app 'word' is the Target language
        translation: nativeWord, // 'translation' is Native language
        languageCode: nativeLangCode,
        targetLanguageCode: targetLangCode,
        domain: themeName.toLowerCase().replaceAll(' ', '_'),
        subDomain: subThemeName.toLowerCase().replaceAll(' ', '_'),
        microCategory: microCategory,
        categoryIds: categoryIds,
        definition: definition.isNotEmpty ? definition : null,
        exampleSentence: example.isNotEmpty ? example : null,
        exampleSentencePronunciation: examplePronunciation.isNotEmpty ? examplePronunciation : null,
        difficulty: 1,
        frequency: 'Medium',
      );

      batchWords.add(word);
    }

    if (batchWords.isNotEmpty) {
      await dbHelper.insertWordsBatch(batchWords);
    }
  }

  /// Populates the SQLite database with words for a specific learning pair.
  /// For instance, if user's native lang is 'en' and learning lang is 'es'.
  static Future<void> populateCourse(String nativeLangCode, String targetLangCode) async {
    // Legacy mapping preserved for safety, but new content should use importFromNewCsv
    // 1. Load data for both languages
    final nativeData = await _loadLanguageData(nativeLangCode);
    final targetData = await _loadLanguageData(targetLangCode);
    
    final dbHelper = DatabaseHelper();
    final List<Word> batchWords = [];
    
    // 2. Find matches on concept_id
    for (final conceptId in targetData.keys) {
      if (nativeData.containsKey(conceptId)) {
        final targetRow = targetData[conceptId]!;
        final nativeRow = nativeData[conceptId]!;
        
        // CSV columns matching our schema:
        // 0: vocabulary_id, 1: concept_id, 2: lang_code, 3: word, 4: article, 
        // 5: gender, 6: pronunciation, 7: part_of_speech, 8: category, 
        // 9: subcategory, 10: frequency, 11: image_id
        
        if (targetRow.length < 10 || nativeRow.length < 10) continue;
        
        final String targetWord = targetRow[3].toString().trim();
        final String nativeWord = nativeRow[3].toString().trim();
        final String targetArticle = targetRow.length > 4 ? targetRow[4].toString().trim() : '';
        final String pronunciation = targetRow[6].toString().trim();
        final String posStr = targetRow[7].toString().trim();
        final String categoryName = targetRow[8].toString().trim();
        final String subCategoryName = targetRow[9].toString().trim();
        final String frequency = targetRow.length > 10 ? targetRow[10].toString().trim() : 'Medium';
        final String rawImageId = targetRow.length > 11 ? targetRow[11].toString().trim() : '';
        final String? imageId = rawImageId.isEmpty ? null : rawImageId;

        // Determine Category ID
        String? catId = _findCategoryIdByName(subCategoryName);
        catId ??= _findCategoryIdByName(categoryName);
        catId ??= 'general'; // fallback
        
        // Parse POS
        final pos = _mapPartOfSpeech(posStr);
        
        // Create the Word model
        final word = Word(
          word: targetWord,
          translation: nativeWord,
          languageCode: nativeLangCode,
          targetLanguageCode: targetLangCode,
          partsOfSpeech: [pos],
          categoryIds: [catId],
          pronunciation: pronunciation.isNotEmpty ? pronunciation : null,
          difficulty: 1,
          frequency: frequency,
          imageId: imageId,
          languageSpecific: targetArticle.isNotEmpty ? {'article': targetArticle} : {},
        );
        
        // Accumulate in batch array
        batchWords.add(word);
      }
    }
    
    // 3. Insert into the database in one massive operation
    if (batchWords.isNotEmpty) {
      await dbHelper.insertWordsBatch(batchWords);
    }
  }

  /// Looks up a legacy Category ID by its display name.
  static String? _findCategoryIdByName(String name) {
    if (name.isEmpty) return null;
    for (final cat in CategoryTaxonomy.getAllCategories()) {
      if (cat.name.toLowerCase() == name.toLowerCase()) {
        return cat.id;
      }
    }
    return null;
  }

  /// Maps a part of speech string to the Enum.
  static PartOfSpeech _mapPartOfSpeech(String pos) {
    final clean = pos.toLowerCase().trim();
    if (clean.contains('noun')) return PartOfSpeech.noun;
    if (clean.contains('verb')) return PartOfSpeech.verb;
    if (clean.contains('adj')) return PartOfSpeech.adjective;
    if (clean.contains('adv')) return PartOfSpeech.adverb;
    if (clean.contains('pron')) return PartOfSpeech.pronoun;
    if (clean.contains('prep')) return PartOfSpeech.preposition;
    if (clean.contains('conj')) return PartOfSpeech.conjunction;
    if (clean.contains('interj')) return PartOfSpeech.interjection;
    return PartOfSpeech.noun;
  }
}
