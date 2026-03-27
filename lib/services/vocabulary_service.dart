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

  /// Looks up a category ID by its display name from the taxonomy.
  static String? _findCategoryIdByName(String name) {
    for (final cat in CategoryTaxonomy.getAllCategories()) {
      if (cat.name.toLowerCase() == name.toLowerCase()) return cat.id;
    }
    return null;
  }

  /// Maps CSV Parts of Speech to our enum
  static PartOfSpeech _mapPartOfSpeech(String posStr) {
    if (posStr.isEmpty) return PartOfSpeech.noun;
    final normalized = posStr.trim().toLowerCase();
    
    // Manual overrides for known edge cases
    if (normalized == 'suffix' || normalized == 'prefix' || normalized == 'particle') {
      return PartOfSpeech.particle; // Or whatever bucket makes the most sense if we miss one
    }

    try {
      return PartOfSpeech.values.firstWhere((e) => e.name.toLowerCase() == normalized);
    } catch (_) {
      return PartOfSpeech.noun; // Default fallback
    }
  }

  /// Populates the SQLite database with words for a specific learning pair.
  /// For instance, if user's native lang is 'en' and learning lang is 'es'.
  static Future<void> populateCourse(String nativeLangCode, String targetLangCode) async {
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
}
