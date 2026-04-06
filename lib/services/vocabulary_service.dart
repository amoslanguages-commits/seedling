import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/word.dart';
import '../models/taxonomy.dart';
import '../core/supabase_config.dart';
import '../database/database_helper.dart';

class VocabularyService {
  static const String csvFilePath = 'assets/database/vocabulary.csv';

  /// Looks up a Theme ID by its display name.
  static String? _findThemeIdByName(String name) {
    if (name.isEmpty) return null;
    try {
      final theme = CategoryTaxonomy.getRootCategories().firstWhere(
        (c) =>
            c.name.toLowerCase() == name.toLowerCase() ||
            c.id.toLowerCase() == name.toLowerCase().replaceAll(' ', '_'),
      );
      return theme.id;
    } catch (_) {
      return null;
    }
  }

  /// Looks up a Sub-theme ID by its display name.
  static String? _findSubThemeIdByName(String subThemeName, String? parentId) {
    if (subThemeName.isEmpty) return null;
    if (parentId == null || parentId.isEmpty) return null;

    try {
      final subThemes = CategoryTaxonomy.getSubCategories(parentId);
      final theme = subThemes.firstWhere(
        (c) =>
            c.name.toLowerCase() == subThemeName.toLowerCase() ||
            c.id.toLowerCase() ==
                subThemeName.toLowerCase().replaceAll(' ', '_'),
      );
      return theme.id;
    } catch (_) {
      // Fallback to global search if parent not specified or not found
      for (final cat in CategoryTaxonomy.getAllCategories()) {
        if (!cat.isRoot &&
            cat.name.toLowerCase() == subThemeName.toLowerCase()) {
          return cat.id;
        }
      }
      return null;
    }
  }

  /// New ingestion engine for the 8-column format:
  /// Theme, Sub-theme, Micro-category, Native Word, Translation, Definition, Example, Pronunciation
  static Future<void> importFromNewCsv(
    String csvData,
    String nativeLangCode,
    String targetLangCode,
  ) async {
    final batchWords = await compute(_parseNewCsvVocabulary, {
      'csvData': csvData,
      'nativeLangCode': nativeLangCode,
      'targetLangCode': targetLangCode,
    });

    if (batchWords.isNotEmpty) {
      final dbHelper = DatabaseHelper();
      await dbHelper.insertWordsBatch(batchWords);
    }
  }

  static List<Word> _parseNewCsvVocabulary(Map<String, dynamic> args) {
    final csvData = args['csvData'] as String;
    final nativeLangCode = args['nativeLangCode'] as String;
    final targetLangCode = args['targetLangCode'] as String;

    final lines = csvData.split('\n');
    if (lines.isEmpty) return [];

    final List<Word> batchWords = [];

    // Use fast manual CSV parser to prevent RegExp backtracking freeze
    List<String> fastParseCsvRow(String line) {
      final List<String> row = [];
      final StringBuffer current = StringBuffer();
      bool inQuotes = false;
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(current.toString().trim());
          current.clear();
        } else {
          current.write(char);
        }
      }
      row.add(current.toString().trim());
      return row;
    }

    // Skip header if it exists (check if first row contains 'Theme')
    int startIndex = 0;
    if (lines.isNotEmpty && lines[0].toLowerCase().contains('theme')) {
      startIndex = 1;
    }

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final row = fastParseCsvRow(line);

      if (row.length < 13) continue; // Minimum required to reach definition

      final String themeName = row[9]; // domain
      final String subThemeName = row[10]; // sub_domain
      final String microCategory = row[11]; // micro_category
      final String wordText = row[3]; // word
      final String article = row[4];
      final String gender = row[5];
      final String pronunciation = row[6];
      // Optional part of speech could be mapped here if needed.
      final String definition = row[12];
      final String frequency = row[13];
      final String imageId = row[14];
      final String example = row.length > 15 ? row[15] : '';
      final String examplePronunciation = row.length > 16 ? row[16] : '';

      final String? themeId = _findThemeIdByName(themeName);
      final String? subThemeId = _findSubThemeIdByName(subThemeName, themeName);

      final List<String> categoryIds = [];
      if (themeId != null) categoryIds.add(themeId);
      if (subThemeId != null) categoryIds.add(subThemeId);
      if (categoryIds.isEmpty) categoryIds.add('general');

      final word = Word(
        id: int.tryParse(row[0].toString()), // vocabulary_id
        conceptId: row[1],
        word: wordText,
        translation:
            wordText, // Default to word itself for single-row, pairing happens in populateCourse
        languageCode: nativeLangCode,
        targetLanguageCode: targetLangCode,
        domain: themeName.toLowerCase(),
        subDomain: subThemeName.toLowerCase(),
        microCategory: microCategory,
        categoryIds: categoryIds,
        gender: gender.isNotEmpty ? gender : null,
        definition: definition,
        pronunciation: pronunciation.isNotEmpty ? pronunciation : null,
        exampleSentence: example.isNotEmpty ? example : null,
        exampleSentencePronunciation: examplePronunciation.isNotEmpty
            ? examplePronunciation
            : null,
        difficulty: _mapFrequencyToDifficulty(frequency),
        frequency: frequency,
        imageId: imageId.isNotEmpty ? imageId : null,
        languageSpecific: article.isNotEmpty ? {'article': article} : {},
      );

      batchWords.add(word);
    }

    return batchWords;
  }

  /// Populates the SQLite database with words for a specific learning pair.
  /// Uses compute() to avoid blocking the main UI thread (fixes infinite loading).
  static Future<void> populateCourse(
    String nativeLangCode,
    String targetLangCode,
  ) async {
    final csvString = await rootBundle.loadString(csvFilePath);

    final batchWords = await compute(_parseAndMatchVocabulary, {
      'csvString': csvString,
      'nativeLangCode': nativeLangCode,
      'targetLangCode': targetLangCode,
    });

    if (batchWords.isNotEmpty) {
      final dbHelper = DatabaseHelper();
      await dbHelper.insertWordsBatch(batchWords);
    }
  }

  static List<Word> _parseAndMatchVocabulary(Map<String, dynamic> args) {
    final csvString = args['csvString'] as String;
    final nativeLangCode = args['nativeLangCode'] as String;
    final targetLangCode = args['targetLangCode'] as String;

    final lines = csvString.split('\n');
    if (lines.isEmpty) return [];

    final nativeData = <int, List<dynamic>>{};
    final targetData = <int, List<dynamic>>{};

    List<String> fastParseCsvRow(String line) {
      final List<String> row = [];
      final StringBuffer current = StringBuffer();
      bool inQuotes = false;
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(current.toString().trim());
          current.clear();
        } else {
          current.write(char);
        }
      }
      row.add(current.toString().trim());
      return row;
    }

    final String normalizedTarget = targetLangCode.toLowerCase();
    final String baseTarget = normalizedTarget.split('-')[0];
    final String normalizedNative = nativeLangCode.toLowerCase();
    final String baseNative = normalizedNative.split('-')[0];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final row = fastParseCsvRow(line);
      if (row.length < 10) continue;

      final String rowLangCode = row[2].toString().trim().toLowerCase();

      if (rowLangCode == normalizedTarget || rowLangCode == baseTarget) {
        final int conceptId = int.tryParse(row[1].toString()) ?? -1;
        if (conceptId != -1) {
          targetData[conceptId] = row;
        }
      }
      if (rowLangCode == normalizedNative || rowLangCode == baseNative) {
        final int conceptId = int.tryParse(row[1].toString()) ?? -1;
        if (conceptId != -1) {
          nativeData[conceptId] = row;
        }
      }
    }

    final List<Word> batchWords = [];

    for (final conceptId in targetData.keys) {
      if (nativeData.containsKey(conceptId)) {
        final targetRow = targetData[conceptId]!;
        final nativeRow = nativeData[conceptId]!;

        if (targetRow.length < 15 || nativeRow.length < 15) continue;

        final String targetWord = targetRow[3].toString().trim();
        final String nativeWord = nativeRow[3].toString().trim();
        final String targetArticle = targetRow[4].toString().trim();
        final String gender = targetRow[5].toString().trim();
        final String pronunciation = targetRow[6].toString().trim();
        final String posStr = targetRow[7].toString().trim();
        final String conceptType = targetRow[8].toString().trim();
        final String rawDomain = targetRow[9].toString().trim();
        final String rawSubDomain = targetRow[10].toString().trim();
        final String microCategory = targetRow[11].toString().trim();

        final String domainId =
            _findThemeIdByName(rawDomain) ??
            rawDomain.toLowerCase().replaceAll(' ', '_');
        final String subDomainId =
            _findSubThemeIdByName(rawSubDomain, domainId) ??
            rawSubDomain.toLowerCase().replaceAll(' ', '_');

        final String definition = nativeRow[12].toString().trim();
        final String frequency = targetRow[13].toString().trim();
        final String rawImageId = targetRow[14].toString().trim();
        final String exampleSentence = targetRow[15].toString().trim();
        final String exampleSentenceTranslation = nativeRow[15]
            .toString()
            .trim();
        final String exampleSentencePronunciation = targetRow.length > 16
            ? targetRow[16].toString().trim()
            : '';

        final List<String> categoryIds = [];
        categoryIds.add(domainId);
        categoryIds.add(subDomainId);
        if (categoryIds.isEmpty) categoryIds.add('general');

        final pos = _mapPartOfSpeech(posStr);
        final difficulty = _mapFrequencyToDifficulty(frequency);

        final word = Word(
          word: targetWord,
          translation: nativeWord,
          languageCode: nativeLangCode,
          targetLanguageCode: targetLangCode,
          conceptId: conceptId.toString(),
          conceptType: conceptType,
          domain: domainId, // Store ID for filtering
          subDomain: subDomainId, // Store ID for filtering
          microCategory: microCategory,
          partsOfSpeech: [pos],
          partOfSpeechRaw: posStr,
          categoryIds: categoryIds,
          gender: gender.isNotEmpty ? gender : null,
          definition: definition.isNotEmpty ? definition : null,
          pronunciation: pronunciation.isNotEmpty ? pronunciation : null,
          exampleSentence: exampleSentence.isNotEmpty ? exampleSentence : null,
          exampleSentenceTranslation: exampleSentenceTranslation.isNotEmpty
              ? exampleSentenceTranslation
              : null,
          exampleSentencePronunciation: exampleSentencePronunciation.isNotEmpty
              ? exampleSentencePronunciation
              : null,
          difficulty: difficulty,
          frequency: frequency,
          imageId: rawImageId.isNotEmpty ? rawImageId : null,
          languageSpecific: targetArticle.isNotEmpty
              ? {'article': targetArticle}
              : {},
        );

        batchWords.add(word);
      }
    }

    return batchWords;
  }

  /// Fetches a paired word from Supabase for online games.
  /// Resolves the same Concept ID into Target and Native words.
  static Future<Word?> fetchOnlineWord(
    String conceptId,
    String targetLang,
    String nativeLang,
  ) async {
    try {
      final response = await SupabaseConfig.client
          .from('vocabulary')
          .select()
          .eq('concept_id', conceptId)
          .inFilter('lang_code', [targetLang, nativeLang]);

      final List rows = response as List;
      if (rows.isEmpty) return null;

      final targetRow = rows.firstWhere(
        (r) => r['lang_code'] == targetLang,
        orElse: () => null,
      );
      final nativeRow = rows.firstWhere(
        (r) => r['lang_code'] == nativeLang,
        orElse: () => rows.first,
      );

      if (targetRow == null) return null;

      // Fetch intelligent distractors
      final pos = targetRow['part_of_speech'];
      final subDomain = targetRow['sub_domain'];
      final domain = targetRow['domain'];

      List<dynamic> distractorsData = [];

      Future<List<dynamic>> fetchDistractors({
        String? eqSubDomain,
        String? eqDomain,
        String? likePos,
      }) async {
        var query = SupabaseConfig.client
            .from('vocabulary')
            .select('word')
            .eq('lang_code', nativeLang)
            .neq('concept_id', conceptId);

        if (likePos != null && likePos.isNotEmpty) {
          query = query.ilike('part_of_speech', '%$likePos%');
        }
        if (eqSubDomain != null && eqSubDomain.isNotEmpty) {
          query = query.eq('sub_domain', eqSubDomain);
        }
        if (eqDomain != null && eqDomain.isNotEmpty) {
          query = query.eq('domain', eqDomain);
        }

        return await query.limit(10);
      }

      // 1. Try Sub-Domain + POS
      distractorsData = await fetchDistractors(
        eqSubDomain: subDomain,
        likePos: pos,
      );

      // 2. Fallback to Domain + POS
      if (distractorsData.length < 3) {
        distractorsData = await fetchDistractors(
          eqDomain: domain,
          likePos: pos,
        );
      }

      // 3. Fallback to POS only
      if (distractorsData.length < 3) {
        distractorsData = await fetchDistractors(likePos: pos);
      }

      // 4. Ultimate Fallback
      if (distractorsData.length < 3) {
        distractorsData = await fetchDistractors();
      }

      distractorsData.shuffle();
      final distractors = distractorsData
          .take(3)
          .map((r) => r['word'].toString())
          .toList();

      // Pair the native word as translation
      final updatedWord = Word(
        word: targetRow['word'],
        translation: nativeRow['word'], // Use native word for meaning
        languageCode: nativeLang,
        targetLanguageCode: targetLang,
        conceptId: conceptId,
        conceptType: targetRow['concept_type'],
        domain: targetRow['domain'],
        subDomain: targetRow['sub_domain'],
        microCategory: targetRow['micro_category'],
        gender: targetRow['gender'],
        definition: nativeRow['definition'], // Keep definition for extra info
        pronunciation: targetRow['pronunciation'],
        exampleSentence: targetRow['example_sentence'],
        exampleSentenceTranslation:
            nativeRow['example_sentence'], // Translation of the sentence
        difficulty: _mapFrequencyToDifficulty(targetRow['frequency'] ?? ''),
        imageId: targetRow['imageId'] ?? targetRow['image_id'],
        partOfSpeechRaw: targetRow['part_of_speech'],
      );

      updatedWord.setOptions([nativeRow['word'], ...distractors]..shuffle());

      return updatedWord;
    } catch (e) {
      debugPrint('Error fetching online word: $e');
      return null;
    }
  }

  /// Maps frequency labels to difficulty levels (1-5).
  static int _mapFrequencyToDifficulty(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'very high':
        return 1;
      case 'high':
        return 2;
      case 'medium':
        return 3;
      case 'low':
        return 4;
      case 'very low':
        return 5;
      default:
        return 1;
    }
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

  static Future<void> normalizeDatabaseCategories() async {
    final dbHelper = DatabaseHelper();
    // One-time normalization to convert display names to IDs in the database.
    // We actually need all words regardless of lang to be safe, or just run for active ones.
    // Better to use a raw query to get everything.

    final db = await dbHelper.database;
    final List<Map<String, dynamic>> rows = await db.query('words');

    for (final row in rows) {
      final String rawDomain = (row['domain'] as String?) ?? '';
      final String rawSubDomain = (row['sub_domain'] as String?) ?? '';

      if (rawDomain.isEmpty) continue;

      final domainId = _findThemeIdByName(rawDomain);
      if (domainId != null && domainId != rawDomain) {
        final subDomainId = _findSubThemeIdByName(rawSubDomain, domainId);

        await db.update(
          'words',
          {
            'domain': domainId,
            'sub_domain': subDomainId ?? rawSubDomain,
            'category_ids': [
              domainId,
              if (subDomainId != null) subDomainId,
            ].join(','),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }
}
