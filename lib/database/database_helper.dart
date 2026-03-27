import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../models/word.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final dbPath = path.join(await getDatabasesPath(), 'seedling.db');
    return await openDatabase(
      dbPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Words table
    await db.execute('''
      CREATE TABLE words(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        language_code TEXT NOT NULL,
        target_language_code TEXT NOT NULL,
        parts_of_speech TEXT DEFAULT 'noun',
        category_ids TEXT DEFAULT 'general',
        definition TEXT,
        example_sentence TEXT,
        pronunciation TEXT,
        etymology TEXT,
        tags TEXT,
        difficulty INTEGER DEFAULT 1,
        mastery_level INTEGER DEFAULT 0,
        last_reviewed TEXT,
        next_review TEXT,
        streak INTEGER DEFAULT 0,
        total_reviews INTEGER DEFAULT 0,
        times_correct INTEGER DEFAULT 0,
        language_specific TEXT,
        frequency TEXT,
        category TEXT -- kept for backward compatibility if needed
      )
    ''');
    
    // User progress table
    await db.execute('''
      CREATE TABLE user_progress(
        user_id TEXT PRIMARY KEY,
        learning_language TEXT NOT NULL,
        native_language TEXT NOT NULL,
        total_words_learned INTEGER DEFAULT 0,
        current_streak INTEGER DEFAULT 0,
        longest_streak INTEGER DEFAULT 0,
        last_study_session TEXT,
        total_study_minutes INTEGER DEFAULT 0,
        is_premium INTEGER DEFAULT 0
      )
    ''');
    
    // Study sessions table
    await db.execute('''
      CREATE TABLE study_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        language_code TEXT NOT NULL,
        session_date TEXT NOT NULL,
        words_studied INTEGER DEFAULT 0,
        correct_answers INTEGER DEFAULT 0,
        duration_minutes INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE words ADD COLUMN parts_of_speech TEXT DEFAULT "noun"');
      await db.execute('ALTER TABLE words ADD COLUMN category_ids TEXT DEFAULT "general"');
      await db.execute('ALTER TABLE words ADD COLUMN definition TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN etymology TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN tags TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN total_reviews INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE words ADD COLUMN times_correct INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE words ADD COLUMN language_specific TEXT');
      
      // Update existing records to sync category -> category_ids
      await db.execute('UPDATE words SET category_ids = category WHERE category IS NOT NULL');
    }
    
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE words ADD COLUMN frequency TEXT');
    }
  }
  
  // Word operations
  Future<List<Word>> getWordsForLanguage(
    String languageCode, 
    String targetLanguageCode, {
    String? categoryId,
    String? partOfSpeech,
    int? limit,
  }) async {
    final db = await database;
    String whereClause = 
        'language_code = ? AND target_language_code = ?';
    List<dynamic> whereArgs = [languageCode, targetLanguageCode];
    
    if (categoryId != null) {
      // Simple string matching for now, as category_ids is comma-separated
      whereClause += ' AND (category_ids LIKE ? OR category = ?)';
      whereArgs.add('%$categoryId%');
      whereArgs.add(categoryId);
    }
    
    if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
      whereClause += ' AND parts_of_speech LIKE ?';
      whereArgs.add('%$partOfSpeech%');
    }
    
    final maps = await db.query(
      'words',
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
      orderBy: 'mastery_level ASC, RANDOM()',
    );
    
    return maps.map((m) => Word.fromMap(m)).toList();
  }
  
  Future<void> updateWordMastery(int wordId, bool correct) async {
    final db = await database;
    final word = await db.query(
      'words',
      where: 'id = ?',
      whereArgs: [wordId],
    );
    
    if (word.isNotEmpty) {
      final current = Word.fromMap(word.first);
      final newStreak = correct ? current.streak + 1 : 0;
      final newMastery = correct 
          ? math.min(current.masteryLevel + 1, 5) 
          : math.max(current.masteryLevel - 1, 0);
      final newTimesCorrect = correct ? current.timesCorrect + 1 : current.timesCorrect;
      
      await db.update(
        'words',
        {
          'mastery_level': newMastery,
          'streak': newStreak,
          'total_reviews': current.totalReviews + 1,
          'times_correct': newTimesCorrect,
          'last_reviewed': DateTime.now().toIso8601String(),
          'next_review': _calculateNextReview(newMastery).toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [wordId],
      );
    }
  }
  
  DateTime _calculateNextReview(int masteryLevel) {
    final intervals = [1, 3, 7, 14, 30]; // days
    final days = intervals[math.min(masteryLevel, intervals.length - 1)];
    return DateTime.now().add(Duration(days: days));
  }
  
  // ── SRS: words due for review today ─────────────────────────────────────
  // Returns words whose next_review is today or earlier (or never reviewed),
  // filtered by language pair, ordered by urgency then interleaved by mastery
  // for optimal interleaving (Active Recall + SRS combined).
  Future<List<Word>> getSRSDueWords(
    String languageCode,
    String targetLanguageCode, {
    String? categoryId,
    String? partOfSpeech,
    int limit = 15,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    String where = 'language_code = ? AND target_language_code = ? '
        'AND mastery_level > 0 '
        'AND (next_review IS NULL OR next_review <= ?)';
    List<dynamic> args = [languageCode, targetLanguageCode, now];

    if (categoryId != null && categoryId.isNotEmpty) {
      where += ' AND (category_ids LIKE ? OR category = ?)';
      args.add('%$categoryId%');
      args.add(categoryId);
    }

    if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
      where += ' AND parts_of_speech LIKE ?';
      args.add('%$partOfSpeech%');
    }

    final due = await db.query(
      'words',
      where: where,
      whereArgs: args,
      orderBy: 'next_review ASC, mastery_level ASC',
      limit: limit,
    );

    final words = due.map((m) => Word.fromMap(m)).toList();
    words.shuffle();
    return words;
  }

  // ── Get the next unplanted word to reveal ────────────────────────────────
  // Returns a word with mastery_level == 0 (never planted) for the language
  // pair. Topic/category filtering supported.
  Future<Word?> getNewWordToPlant(
    String languageCode,
    String targetLanguageCode, {
    String? categoryId,
    String? partOfSpeech,
  }) async {
    final db = await database;
    String where =
        'language_code = ? AND target_language_code = ? AND mastery_level = 0';
    List<dynamic> args = [languageCode, targetLanguageCode];

    if (categoryId != null && categoryId.isNotEmpty) {
      where += ' AND (category_ids LIKE ? OR category = ?)';
      args.add('%$categoryId%');
      args.add(categoryId);
    }

    if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
      where += ' AND parts_of_speech LIKE ?';
      args.add('%$partOfSpeech%');
    }

    final maps = await db.query(
      'words',
      where: where,
      whereArgs: args,
      orderBy: '''
        (CASE frequency 
          WHEN 'Very high' THEN 8 
          WHEN 'High' THEN 4 
          WHEN 'Medium' THEN 2 
          ELSE 1 
        END) * (ABS(RANDOM()) % 100) DESC
      ''',
      limit: 1,
    );

    return maps.isEmpty ? null : Word.fromMap(maps.first);
  }

  // ── Mark a word as planted (mastery 0 → 1, schedules first review) ───────
  Future<void> markWordAsPlanted(int wordId) async {
    final db = await database;
    await db.update(
      'words',
      {
        'mastery_level': 1,
        'last_reviewed': DateTime.now().toIso8601String(),
        'next_review': _calculateNextReview(1).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  Future<int> getTotalWordsLearned(String languageCode) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE target_language_code = ? AND mastery_level > 0',
      [languageCode],
    );
    return result.first['count'] as int? ?? 0;
  }
  
  // SYNC METHODS
  
  Future<List<Word>> getAllWordsWithProgress() async {
    final db = await database;
    final maps = await db.query('words', where: 'mastery_level > 0');
    return maps.map((m) => Word.fromMap(m)).toList();
  }
  
  Future<Map<String, dynamic>> getUserStats() async {
    final db = await database;
    final result = await db.query('user_progress', limit: 1);
    if (result.isNotEmpty) {
      return {
        'totalWordsLearned': result.first['total_words_learned'],
        'currentStreak': result.first['current_streak'],
        'longestStreak': result.first['longest_streak'],
        'totalStudyMinutes': result.first['total_study_minutes'],
      };
    }
    return {
      'totalWordsLearned': 0,
      'currentStreak': 0,
      'longestStreak': 0,
      'totalStudyMinutes': 0,
    };
  }
  
  // Import StudySession if needed, but here we'll use dynamic for simplicity in the helper
  Future<List<dynamic>> getUnsyncedStudySessions() async {
    final db = await database;
    final maps = await db.query('study_sessions', where: 'is_synced = 0');
    // Using simple maps for now to avoid circular dependency or import issues if not careful
    return maps;
  }
  
  Future<void> markSessionAsSynced(int sessionId) async {
    final db = await database;
    await db.update(
      'study_sessions',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }
  
  Future<void> updateWordProgress(
    String wordId,
    int masteryLevel,
    int streak,
  ) async {
    final db = await database;
    await db.update(
      'words',
      {
        'mastery_level': masteryLevel,
        'streak': streak,
        'last_reviewed': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }
  
  Future<void> updateUserStats(Map<String, dynamic> stats) async {
    final db = await database;
    await db.update(
      'user_progress',
      {
        'total_words_learned': stats['totalWordsLearned'],
        'current_streak': stats['currentStreak'],
        'longest_streak': stats['longestStreak'],
        'total_study_minutes': stats['totalStudyMinutes'],
      },
    ); // Assumes one row
  }
  
  Future<void> clearUserData() async {
    final db = await database;
    await db.delete('words', where: 'mastery_level > 0');
    await db.delete('user_progress');
    await db.delete('study_sessions');
  }
  
  Future<void> insertWordWithProgress(Word word) async {
    final db = await database;
    await db.insert(
      'words',
      word.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertWordsBatch(List<Word> words) async {
    final db = await database;
    final batch = db.batch();
    
    for (final word in words) {
      batch.insert(
        'words',
        word.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }
  
  // ── HOME SCREEN AGGREGATION & ACTIVITY ──────────────────────────────────
  
  /// Get counts of learned vs total words per category
  Future<List<Map<String, dynamic>>> getCategoryStats(String languageCode, String targetLanguageCode) async {
    final db = await database;
    final maps = await db.query(
      'words',
      columns: ['category_ids', 'mastery_level'],
      where: 'language_code = ? AND target_language_code = ?',
      whereArgs: [languageCode, targetLanguageCode],
    );
    
    final Map<String, int> totalCounts = {};
    final Map<String, int> learnedCounts = {};
    
    for (final row in maps) {
      final catsStr = (row['category_ids'] as String?) ?? 'general';
      final isLearned = (row['mastery_level'] as int) > 0;
      
      final cats = catsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      for (final cat in cats) {
        totalCounts[cat] = (totalCounts[cat] ?? 0) + 1;
        if (isLearned) {
          learnedCounts[cat] = (learnedCounts[cat] ?? 0) + 1;
        }
      }
    }
    
    final List<Map<String, dynamic>> result = [];
    for (final cat in totalCounts.keys) {
      result.add({
        'category': cat,
        'total': totalCounts[cat] ?? 0,
        'learned': learnedCounts[cat] ?? 0,
      });
    }
    
    result.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    return result;
  }

  /// Get counts of learned vs total words per part of speech
  Future<List<Map<String, dynamic>>> getPOSStats(String languageCode, String targetLanguageCode) async {
    final db = await database;
    final maps = await db.query(
      'words',
      columns: ['parts_of_speech', 'mastery_level'],
      where: 'language_code = ? AND target_language_code = ?',
      whereArgs: [languageCode, targetLanguageCode],
    );
    
    final Map<String, int> totalCounts = {};
    final Map<String, int> learnedCounts = {};
    
    for (final row in maps) {
      final posStr = (row['parts_of_speech'] as String?) ?? 'noun';
      final isLearned = (row['mastery_level'] as int) > 0;
      
      final poses = posStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      for (final pos in poses) {
        totalCounts[pos] = (totalCounts[pos] ?? 0) + 1;
        if (isLearned) {
          learnedCounts[pos] = (learnedCounts[pos] ?? 0) + 1;
        }
      }
    }
    
    final List<Map<String, dynamic>> result = [];
    for (final pos in totalCounts.keys) {
      result.add({
        'pos': pos,
        'total': totalCounts[pos] ?? 0,
        'learned': learnedCounts[pos] ?? 0,
      });
    }
    
    result.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    return result;
  }

  /// Get the most recently reviewed/learned words
  Future<List<Word>> getRecentActivity(String languageCode, String targetLanguageCode, {int limit = 5}) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'language_code = ? AND target_language_code = ? AND mastery_level > 0 AND last_reviewed IS NOT NULL',
      whereArgs: [languageCode, targetLanguageCode],
      orderBy: 'last_reviewed DESC',
      limit: limit,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  /// Get the number of words reviewed today
  Future<int> getWordsReviewedToday(String languageCode, String targetLanguageCode) async {
    final db = await database;
    final now = DateTime.now();
    // Use ISO string substring '2026-03-27' to match SQLite standard dates starting with today
    final todayStr = now.toIso8601String().substring(0, 10);
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE language_code = ? AND target_language_code = ? AND last_reviewed LIKE ?',
      [languageCode, targetLanguageCode, '$todayStr%'],
    );
    return result.first['count'] as int? ?? 0;
  }
}
