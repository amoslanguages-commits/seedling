import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/grammar_model.dart';

/// Manages all grammar data: sentence loading, progress tracking, unlocking.
class GrammarService {
  static GrammarService? _instance;
  static GrammarService get instance => _instance ??= GrammarService._();
  GrammarService._();

  Database? _db;

  // In-memory sentence cache per lang code
  final Map<String, List<GrammarSentence>> _sentenceCache = {};

  // Unlock threshold — a concept needs this mastery for the next to unlock
  static const double _unlockThreshold = 0.40;

  // ─── DATABASE SETUP ────────────────────────────────────────────────────────

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'grammar.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
    return _db!;
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sentence_progress (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        sentence_id     INTEGER NOT NULL,
        concept_id      INTEGER NOT NULL,
        lang_code       TEXT    NOT NULL,
        mastery         REAL    DEFAULT 0.0,
        stability       REAL    DEFAULT 1.0,
        difficulty      REAL    DEFAULT 5.0,
        reps            INTEGER DEFAULT 0,
        last_review     TEXT,
        due_date        TEXT,
        UNIQUE(sentence_id, lang_code)
      )
    ''');
  }

  // ─── SENTENCE LOADING ─────────────────────────────────────────────────────

  /// Load sentences for a [langCode] from an asset CSV file.
  /// Falls back to empty list if the file does not exist yet.
  Future<List<GrammarSentence>> loadSentences(String langCode) async {
    if (_sentenceCache.containsKey(langCode)) {
      return _sentenceCache[langCode]!;
    }

    try {
      final csvPath = 'assets/grammar/sentences.csv';
      final raw = await rootBundle.loadString(csvPath);
      final sentences = _parseCsv(raw, langCode);
      _sentenceCache[langCode] = sentences;
      return sentences;
    } catch (e) {
      _sentenceCache[langCode] = [];
      return [];
    }
  }

  List<GrammarSentence> _parseCsv(String raw, String langCode) {
    final List<List<String>> rows = [];
    List<String> currentRow = [];
    StringBuffer currentField = StringBuffer();
    bool inQuotes = false;

    // Process character by character to handle newlines inside quotes
    for (int i = 0; i < raw.length; i++) {
      final char = raw[i];
      final nextChar = (i + 1 < raw.length) ? raw[i + 1] : '';

      if (char == '"') {
        if (inQuotes && nextChar == '"') {
          // Double quote inside quotes = escaped quote
          currentField.write('"');
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && nextChar == '\n') i++; // Skip \n in \r\n
        
        currentRow.add(currentField.toString().trim());
        if (currentRow.any((s) => s.isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = [];
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }
    
    // Add final row if exists
    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString().trim());
      rows.add(currentRow);
    }

    if (rows.length < 2) return [];

    final headers = rows.first.map((e) => e.trim().toLowerCase()).toList();
    final sentences = <GrammarSentence>[];

    // Find indices
    final sIdIdx = headers.indexOf('sentence_id');
    final cIdIdx = headers.indexOf('concept_id');
    final chapterIdx = headers.indexOf('concept_chapter');
    final langIdx = headers.indexOf('lang_code');
    final levelIdx = headers.indexOf('level');
    final catIdx = headers.indexOf('category');
    final sortIdx = headers.indexOf('sort_order');
    final sentenceIdx = headers.indexOf('sentence');
    final pronIdx = headers.indexOf('sentence_pronunciation');
    final notesIdx = headers.indexOf('notes');

    for (int i = 1; i < rows.length; i++) {
      final rowData = rows[i];
      if (rowData.isEmpty) continue;

      try {
        final rowMap = <String, String>{};
        _safePut(rowMap, 'sentence_id', rowData, sIdIdx);
        _safePut(rowMap, 'concept_id', rowData, cIdIdx);
        _safePut(rowMap, 'concept_chapter', rowData, chapterIdx);
        _safePut(rowMap, 'lang_code', rowData, langIdx);
        _safePut(rowMap, 'level', rowData, levelIdx);
        _safePut(rowMap, 'category', rowData, catIdx);
        _safePut(rowMap, 'sort_order', rowData, sortIdx);
        _safePut(rowMap, 'sentence', rowData, sentenceIdx);
        _safePut(rowMap, 'sentence_pronunciation', rowData, pronIdx);
        _safePut(rowMap, 'notes', rowData, notesIdx);

        final sentence = GrammarSentence.fromCsvRow(rowMap);
        if (sentence.langCode == langCode) {
          sentences.add(sentence);
        }
      } catch (_) {}
    }

    sentences.sort((a, b) {
      final lc = a.level.index.compareTo(b.level.index);
      if (lc != 0) return lc;
      final cc = a.conceptId.compareTo(b.conceptId);
      if (cc != 0) return cc;
      final kc = a.category.compareTo(b.category);
      if (kc != 0) return kc;
      final sc = a.sortOrder.compareTo(b.sortOrder);
      if (sc != 0) return sc;
      return a.sentenceId.compareTo(b.sentenceId);
    });

    return sentences;
  }

  void _safePut(Map<String, String> map, String key, List<dynamic> row, int index) {
    if (index >= 0 && index < row.length) {
      map[key] = row[index].toString().trim();
    } else {
      map[key] = '';
    }
  }

  // ─── CONCEPT PROGRESS ────────────────────────────────────────────────────

  /// Get progress for every concept for a given [langCode].
  Future<Map<int, ConceptProgress>> getAllConceptProgress(
      String langCode) async {
    final db = await database;
    final sentences = await loadSentences(langCode);

    // Count total sentences per concept
    final totals = <int, int>{};
    for (final s in sentences) {
      totals[s.conceptId] = (totals[s.conceptId] ?? 0) + 1;
    }

    // Fetch all progress rows for this lang
    final rows = await db.query(
      'sentence_progress',
      where: 'lang_code = ?',
      whereArgs: [langCode],
    );

    // Aggregate mastery per concept
    final completedMap = <int, int>{};
    final masterySum = <int, double>{};
    for (final row in rows) {
      final cid = row['concept_id'] as int;
      final mastery = (row['mastery'] as num?)?.toDouble() ?? 0.0;
      completedMap[cid] = (completedMap[cid] ?? 0) + (mastery > 0 ? 1 : 0);
      masterySum[cid] = (masterySum[cid] ?? 0.0) + mastery;
    }

    // Build concept progress list in order, with unlocking logic
    final result = <int, ConceptProgress>{};
    double prevMastery = 1.0; // A0 always unlocked

    for (final concept in GrammarConcept.allConcepts) {
      final cid = concept.conceptId;
      final total = totals[cid] ?? 0;
      final completed = completedMap[cid] ?? 0;
      final sum = masterySum[cid] ?? 0.0;
      final avgMastery = total > 0 ? (sum / total).clamp(0.0, 1.0) : 0.0;

      // Unlock logic: first A0 concept always unlocked, rest need prev ≥ threshold
      final isUnlocked = cid == 1 || prevMastery >= _unlockThreshold;

      result[cid] = ConceptProgress(
        conceptId: cid,
        mastery: avgMastery,
        completedSentences: completed,
        totalSentences: total,
        isUnlocked: isUnlocked,
      );

      prevMastery = avgMastery;
    }

    // If no CSV data yet, unlock the first few concepts so the roadmap isn't empty
    if (sentences.isEmpty) {
      for (int i = 1; i <= 5; i++) {
        result[i] = ConceptProgress(
          conceptId: i,
          mastery: 0.0,
          completedSentences: 0,
          totalSentences: 0,
          isUnlocked: true,
        );
      }
    }

    return result;
  }

  /// Get progress for a single concept.
  Future<ConceptProgress> getConceptProgress(
      int conceptId, String langCode) async {
    final all = await getAllConceptProgress(langCode);
    return all[conceptId] ??
        ConceptProgress.empty(conceptId, isUnlocked: conceptId == 1);
  }

  /// Get sentences for a specific concept + lang, sorted for lesson delivery.
  Future<List<GrammarSentence>> getSentencesForConcept(
      int conceptId, String langCode) async {
    final all = await loadSentences(langCode);
    return all
        .where((s) => s.conceptId == conceptId && s.langCode == langCode)
        .toList();
  }

  // ─── PROGRESS UPDATES ────────────────────────────────────────────────────

  /// Record a review for a sentence. [mastery] is the new 0.0–1.0 score.
  Future<void> recordReview({
    required int sentenceId,
    required int conceptId,
    required String langCode,
    required double mastery,
    required double stability,
    required double difficulty,
    required int reps,
    required DateTime dueDate,
  }) async {
    final db = await database;
    await db.insert(
      'sentence_progress',
      {
        'sentence_id': sentenceId,
        'concept_id': conceptId,
        'lang_code': langCode,
        'mastery': mastery,
        'stability': stability,
        'difficulty': difficulty,
        'reps': reps,
        'last_review': DateTime.now().toIso8601String(),
        'due_date': dueDate.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Sentences due for review (due_date ≤ now) for a given lang.
  Future<List<SentenceProgress>> getDueSentences(String langCode) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'sentence_progress',
      where: 'lang_code = ? AND due_date <= ?',
      whereArgs: [langCode, now],
      orderBy: 'due_date ASC',
    );

    return rows.map((row) {
      return SentenceProgress(
        sentenceId: row['sentence_id'] as int,
        conceptId: row['concept_id'] as int,
        langCode: langCode,
        mastery: (row['mastery'] as num?)?.toDouble() ?? 0.0,
        dueDate: row['due_date'] != null
            ? DateTime.tryParse(row['due_date'] as String)
            : null,
        lastReview: row['last_review'] != null
            ? DateTime.tryParse(row['last_review'] as String)
            : null,
        stability: (row['stability'] as num?)?.toDouble() ?? 1.0,
        difficulty: (row['difficulty'] as num?)?.toDouble() ?? 5.0,
        reps: row['reps'] as int? ?? 0,
      );
    }).toList();
  }

  // ─── LEVEL SUMMARY ───────────────────────────────────────────────────────

  /// Overall progress per level — mastery averaged across all concepts in that level.
  Future<Map<GrammarLevel, double>> getLevelProgress(String langCode) async {
    final allProgress = await getAllConceptProgress(langCode);
    final levelMastery = <GrammarLevel, List<double>>{};

    for (final concept in GrammarConcept.allConcepts) {
      final progress = allProgress[concept.conceptId];
      if (progress == null) continue;
      levelMastery.putIfAbsent(concept.level, () => []);
      levelMastery[concept.level]!.add(progress.mastery);
    }

    return levelMastery.map((level, values) {
      final avg = values.isEmpty
          ? 0.0
          : values.reduce((a, b) => a + b) / values.length;
      return MapEntry(level, avg.clamp(0.0, 1.0));
    });
  }

  /// The first unlocked but not-yet-mastered concept (the learner's frontier).
  Future<int> getFrontierConceptId(String langCode) async {
    final allProgress = await getAllConceptProgress(langCode);
    for (final concept in GrammarConcept.allConcepts) {
      final p = allProgress[concept.conceptId];
      if (p == null) continue;
      if (p.isUnlocked && p.mastery < 0.90) return concept.conceptId;
    }
    return 1; // default to first
  }

  // ─── CACHE CLEAR ─────────────────────────────────────────────────────────

  void clearCache() => _sentenceCache.clear();
}
