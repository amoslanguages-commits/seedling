import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../models/word.dart';
import '../services/offline_queue_manager.dart';

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
      version: 9,
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
        concept_id TEXT,
        concept_type TEXT,
        domain TEXT,
        sub_domain TEXT,
        micro_category TEXT,
        parts_of_speech TEXT DEFAULT 'noun',
        category_ids TEXT DEFAULT 'general',
        gender TEXT,
        definition TEXT,
        example_sentence TEXT,
        example_sentence_translation TEXT,
        example_sentence_pronunciation TEXT,
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
        category TEXT, -- kept for backward compatibility if needed
        image_id TEXT,
        part_of_speech_raw TEXT
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
        total_xp INTEGER DEFAULT 0,
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
        xp_gained INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    // Confusion Graph — tracks which wrong answer a user picked for each word
    await db.execute('''
      CREATE TABLE word_confusions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        correct_word_id INTEGER NOT NULL,
        confused_with_id INTEGER NOT NULL,
        language_code TEXT NOT NULL,
        target_language_code TEXT NOT NULL,
        confusion_count INTEGER DEFAULT 1,
        last_confused TEXT,
        UNIQUE(correct_word_id, confused_with_id)
      )
    ''');

    // Per-word, per-quiz-type accuracy tracker
    await db.execute('''
      CREATE TABLE word_quiz_performance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        quiz_type TEXT NOT NULL,
        attempts INTEGER DEFAULT 0,
        correct_count INTEGER DEFAULT 0,
        avg_response_ms INTEGER DEFAULT 0,
        UNIQUE(word_id, quiz_type)
      )
    ''');

    // Composite indexes for high-performance SRS and domain queries at 10k+ words
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_words_srs ON words (language_code, target_language_code, mastery_level, next_review)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_words_domain ON words (language_code, target_language_code, domain, sub_domain, mastery_level)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE words ADD COLUMN parts_of_speech TEXT DEFAULT "noun"',
      );
      await db.execute(
        'ALTER TABLE words ADD COLUMN category_ids TEXT DEFAULT "general"',
      );
      await db.execute('ALTER TABLE words ADD COLUMN definition TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN etymology TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN tags TEXT');
      await db.execute(
        'ALTER TABLE words ADD COLUMN total_reviews INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE words ADD COLUMN times_correct INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE words ADD COLUMN language_specific TEXT');

      // Update existing records to sync category -> category_ids
      await db.execute(
        'UPDATE words SET category_ids = category WHERE category IS NOT NULL',
      );
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE words ADD COLUMN frequency TEXT');
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE words ADD COLUMN image_id TEXT');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE words ADD COLUMN concept_id TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN concept_type TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN domain TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN sub_domain TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN micro_category TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN gender TEXT');
      await db.execute(
        'ALTER TABLE words ADD COLUMN example_sentence_pronunciation TEXT',
      );
    }

    if (oldVersion < 6) {
      await db.execute('ALTER TABLE words ADD COLUMN part_of_speech_raw TEXT');
    }

    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE words ADD COLUMN example_sentence_translation TEXT',
      );
    }

    if (oldVersion < 8) {
      // Confusion Graph table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS word_confusions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          correct_word_id INTEGER NOT NULL,
          confused_with_id INTEGER NOT NULL,
          language_code TEXT NOT NULL,
          target_language_code TEXT NOT NULL,
          confusion_count INTEGER DEFAULT 1,
          last_confused TEXT,
          UNIQUE(correct_word_id, confused_with_id)
        )
      ''');
      // Quiz performance tracker
      await db.execute('''
        CREATE TABLE IF NOT EXISTS word_quiz_performance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word_id INTEGER NOT NULL,
          quiz_type TEXT NOT NULL,
          attempts INTEGER DEFAULT 0,
          correct_count INTEGER DEFAULT 0,
          avg_response_ms INTEGER DEFAULT 0,
          UNIQUE(word_id, quiz_type)
        )
      ''');
      // New columns on words
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN avg_response_ms INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE words ADD COLUMN fragile_decay_applied INTEGER DEFAULT 0',
        );
      } catch (_) {} // Ignore if already added
      // Composite indexes
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_words_srs ON words (language_code, target_language_code, mastery_level, next_review)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_words_domain ON words (language_code, target_language_code, domain, sub_domain, mastery_level)',
      );
    }

    if (oldVersion < 9) {
      await db.execute('ALTER TABLE user_progress ADD COLUMN total_xp INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE study_sessions ADD COLUMN xp_gained INTEGER DEFAULT 0');
    }
  }

  // Word operations
  Future<List<Word>> getWordsForLanguage(
    String languageCode,
    String targetLanguageCode, {
    String? categoryId,
    String? domain,
    String? subDomain,
    String? partOfSpeech,
    int? limit,
  }) async {
    final db = await database;
    String whereClause = 'language_code = ? AND target_language_code = ?';
    List<dynamic> whereArgs = [languageCode, targetLanguageCode];

    if (domain != null && domain.isNotEmpty) {
      whereClause += ' AND domain = ?';
      whereArgs.add(domain);
    }

    if (subDomain != null && subDomain.isNotEmpty) {
      whereClause += ' AND sub_domain = ?';
      whereArgs.add(subDomain);
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      // Simple string matching for backwards compatibility
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
    final word = await db.query('words', where: 'id = ?', whereArgs: [wordId]);

    if (word.isNotEmpty) {
      final current = Word.fromMap(word.first);
      final newStreak = correct ? current.streak + 1 : 0;
      final newMastery = correct
          ? math.min(current.masteryLevel + 1, 5)
          : math.max(current.masteryLevel - 1, 0);
      final newTimesCorrect = correct
          ? current.timesCorrect + 1
          : current.timesCorrect;

      await db.update(
        'words',
        {
          'mastery_level': newMastery,
          'streak': newStreak,
          'total_reviews': current.totalReviews + 1,
          'times_correct': newTimesCorrect,
          'last_reviewed': DateTime.now().toIso8601String(),
          'next_review': _calculateNextReview(
            newMastery,
            current.frequency,
          ).toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [wordId],
      );
    }
  }

  /// Calculates next review date using SM-2-style intervals, weighted by word frequency.
  /// High-frequency words ("very high") are reviewed 2× more often than low-frequency ones.
  DateTime _calculateNextReview(int masteryLevel, String? frequency) {
    final baseIntervals = [1, 3, 7, 14, 30]; // days per mastery level
    final baseDays =
        baseIntervals[math.min(masteryLevel, baseIntervals.length - 1)];

    // Frequency multiplier: common words need more aggressive drilling
    final multiplier = switch (frequency?.toLowerCase().trim()) {
      'very high' => 0.5,
      'high' => 0.75,
      'medium' => 1.0,
      'low' => 1.5,
      'very low' => 2.5,
      _ => 1.0,
    };

    final adjustedDays = math.max(1, (baseDays * multiplier).round());
    return DateTime.now().add(Duration(days: adjustedDays));
  }

  // ── SRS: words due for review today ─────────────────────────────────────
  // Returns words whose next_review is today or earlier (or never reviewed),
  // filtered by language pair, ordered by urgency then interleaved by mastery
  // for optimal interleaving (Active Recall + SRS combined).
  Future<List<Word>> getSRSDueWords(
    String languageCode,
    String targetLanguageCode, {
    String? categoryId,
    String? domain,
    String? subDomain,
    String? partOfSpeech,
    String? microCategory,
    int limit = 15,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    String where =
        'language_code = ? AND target_language_code = ? '
        'AND mastery_level > 0 '
        'AND (next_review IS NULL OR next_review <= ?)';
    List<dynamic> args = [languageCode, targetLanguageCode, now];

    if (domain != null && domain.isNotEmpty) {
      where += ' AND domain = ?';
      args.add(domain);
    }

    if (subDomain != null && subDomain.isNotEmpty) {
      where += ' AND sub_domain = ?';
      args.add(subDomain);
    }

    if (microCategory != null && microCategory.isNotEmpty) {
      where += ' AND micro_category = ?';
      args.add(microCategory);
    }

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
    String? domain,
    String? subDomain,
    String? partOfSpeech,
    String? microCategory,
  }) async {
    final db = await database;
    String where =
        'language_code = ? AND target_language_code = ? AND mastery_level = 0';
    List<dynamic> args = [languageCode, targetLanguageCode];

    if (domain != null && domain.isNotEmpty) {
      where += ' AND domain = ?';
      args.add(domain);
    }

    if (subDomain != null && subDomain.isNotEmpty) {
      where += ' AND sub_domain = ?';
      args.add(subDomain);
    }

    if (microCategory != null && microCategory.isNotEmpty) {
      where += ' AND micro_category = ?';
      args.add(microCategory);
    }

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
    // Fetch word to get its frequency for weighted scheduling
    final rows = await db.query('words', where: 'id = ?', whereArgs: [wordId]);
    final frequency = rows.isNotEmpty
        ? rows.first['frequency'] as String?
        : null;
    await db.update(
      'words',
      {
        'mastery_level': 1,
        'last_reviewed': DateTime.now().toIso8601String(),
        'next_review': _calculateNextReview(1, frequency).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  /// Returns total vs mastered word counts for a specific micro-category.
  Future<Map<String, int>> getMicroCategoryProgress(
    String microCategory,
    String languageCode,
    String targetLanguageCode,
  ) async {
    final db = await database;
    final total = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE micro_category = ? AND language_code = ? AND target_language_code = ?',
      [microCategory, languageCode, targetLanguageCode],
    );
    final mastered = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE micro_category = ? AND language_code = ? AND target_language_code = ? AND mastery_level >= 3',
      [microCategory, languageCode, targetLanguageCode],
    );
    return {
      'total': (total.first['c'] as int? ?? 0),
      'mastered': (mastered.first['c'] as int? ?? 0),
    };
  }

  Future<int> getTotalWordsLearned(String languageCode) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE target_language_code = ? AND mastery_level > 0',
      [languageCode],
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Returns the number of words currently due for SRS review.
  Future<int> getDueCount(
    String languageCode,
    String targetLanguageCode,
  ) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      '''SELECT COUNT(*) as count FROM words 
         WHERE language_code = ? AND target_language_code = ?
         AND mastery_level > 0
         AND (next_review IS NULL OR next_review <= ?)''',
      [languageCode, targetLanguageCode, now],
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Returns the sub_domain and domain of the most recently reviewed word.
  /// Used to offer a "Resume" action on the Smart Focus Hub.
  Future<Map<String, String?>?> getLastActiveSubTheme(
    String languageCode,
    String targetLanguageCode,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''SELECT domain, sub_domain FROM words 
         WHERE language_code = ? AND target_language_code = ?
         AND last_reviewed IS NOT NULL
         AND sub_domain IS NOT NULL
         ORDER BY last_reviewed DESC
         LIMIT 1''',
      [languageCode, targetLanguageCode],
    );
    if (result.isNotEmpty) {
      return {
        'domain': result.first['domain'] as String?,
        'subDomain': result.first['sub_domain'] as String?,
      };
    }
    return null;
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
        'totalXP': result.first['total_xp'] ?? 0,
      };
    }
    return {
      'totalWordsLearned': 0,
      'currentStreak': 0,
      'longestStreak': 0,
      'totalStudyMinutes': 0,
      'totalXP': 0,
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
    await db.update('user_progress', {
      'total_words_learned': stats['totalWordsLearned'],
      'current_streak': stats['currentStreak'],
      'longest_streak': stats['longestStreak'],
      'total_study_minutes': stats['totalStudyMinutes'],
      'total_xp': stats['totalXP'] ?? 0,
    }); // Assumes one row
  }

  Future<void> updatePremiumStatus(bool isPremium) async {
    final db = await database;
    await db.update('user_progress', {
      'is_premium': isPremium ? 1 : 0,
    });
  }

  Future<void> saveStudySession(Map<String, dynamic> session) async {
    final db = await database;
    await db.insert('study_sessions', {
      'user_id': session['user_id'],
      'language_code': session['language_code'],
      'session_date': session['session_date'],
      'words_studied': session['words_studied'],
      'correct_answers': session['correct_answers'],
      'duration_minutes': session['duration_minutes'],
      'xp_gained': session['xp_gained'],
      'is_synced': 0,
    });

    // Also update aggregate XP in user_progress
    await db.rawUpdate(
      'UPDATE user_progress SET total_xp = total_xp + ?',
      [session['xp_gained']],
    );
  }

  Future<void> clearUserData() async {
    final db = await database;
    await db.delete('words', where: 'mastery_level > 0');
    await db.delete('user_progress');
    await db.delete('study_sessions');
  }

  Future<void> resetCourseProgress(String nativeLang, String targetLang) async {
    final db = await database;
    await db.update(
      'words',
      {
        'mastery_level': 0,
        'streak': 0,
        'last_reviewed': null,
        'next_review': null,
        'total_reviews': 0,
        'times_correct': 0,
      },
      where: 'language_code = ? AND target_language_code = ?',
      whereArgs: [nativeLang, targetLang],
    );
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
  Future<List<Map<String, dynamic>>> getCategoryStats(
    String languageCode,
    String targetLanguageCode,
  ) async {
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

      final cats = catsStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
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
  Future<List<Map<String, dynamic>>> getPOSStats(
    String languageCode,
    String targetLanguageCode,
  ) async {
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

      final poses = posStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
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
  Future<List<Word>> getRecentActivity(
    String languageCode,
    String targetLanguageCode, {
    int limit = 5,
  }) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where:
          'language_code = ? AND target_language_code = ? AND mastery_level > 0 AND last_reviewed IS NOT NULL',
      whereArgs: [languageCode, targetLanguageCode],
      orderBy: 'last_reviewed DESC',
      limit: limit,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  /// Get the number of words reviewed today
  Future<int> getWordsReviewedToday(
    String languageCode,
    String targetLanguageCode,
  ) async {
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

  // ── INTELLIGENT DISTRACTORS ────────────────────────────────────────────────

  /// Fetches intelligent distractors that match the semantic domain and part of speech
  /// of the target word. Falls back to part-of-speech only, then random words.
  Future<List<Word>> getIntelligentDistractors(
    Word correctWord, {
    int limit = 3,
  }) async {
    final db = await database;
    final List<Word> distractors = [];
    final needed = limit;

    // Helper function to query with specific conditions
    Future<List<Word>> fetchWithConditions(
      String extraWhere,
      List<dynamic> extraArgs,
    ) async {
      final maps = await db.query(
        'words',
        where:
            'language_code = ? AND target_language_code = ? AND id != ?$extraWhere',
        whereArgs: [
          correctWord.languageCode,
          correctWord.targetLanguageCode,
          correctWord.id ?? -1,
          ...extraArgs,
        ],
        orderBy: 'RANDOM()',
        limit: needed - distractors.length,
      );
      return maps.map((m) => Word.fromMap(m)).toList();
    }

    // 1. Try to find words in the EXACT same Micro Category & Part of Speech
    if (correctWord.microCategory != null &&
        correctWord.microCategory!.isNotEmpty) {
      final pos = correctWord.partOfSpeechRaw ?? 'noun';
      distractors.addAll(
        await fetchWithConditions(
          ' AND micro_category = ? AND parts_of_speech LIKE ?',
          [correctWord.microCategory, '%$pos%'],
        ),
      );
    }

    // 2. Try same Sub-Domain & POS
    if (distractors.length < needed &&
        correctWord.subDomain != null &&
        correctWord.subDomain!.isNotEmpty) {
      final pos = correctWord.partOfSpeechRaw ?? 'noun';
      final fetched = await fetchWithConditions(
        ' AND sub_domain = ? AND parts_of_speech LIKE ?',
        [correctWord.subDomain, '%$pos%'],
      );
      distractors.addAll(
        fetched.where((w) => !distractors.any((d) => d.id == w.id)),
      );
    }

    // 3. Try same Domain & POS
    if (distractors.length < needed &&
        correctWord.domain != null &&
        correctWord.domain!.isNotEmpty) {
      final pos = correctWord.partOfSpeechRaw ?? 'noun';
      final fetched = await fetchWithConditions(
        ' AND domain = ? AND parts_of_speech LIKE ?',
        [correctWord.domain, '%$pos%'],
      );
      distractors.addAll(
        fetched.where((w) => !distractors.any((d) => d.id == w.id)),
      );
    }

    // 4. Fallback to just same Part of Speech
    if (distractors.length < needed) {
      final pos = correctWord.partOfSpeechRaw ?? 'noun';
      final fetched = await fetchWithConditions(' AND parts_of_speech LIKE ?', [
        '%$pos%',
      ]);
      distractors.addAll(
        fetched.where((w) => !distractors.any((d) => d.id == w.id)),
      );
    }

    // 5. Ultimate fallback to purely random words in the same language pair
    if (distractors.length < needed) {
      final fetched = await fetchWithConditions('', []);
      distractors.addAll(
        fetched.where((w) => !distractors.any((d) => d.id == w.id)),
      );
    }

    return distractors;
  }

  // ── CONFUSION GRAPH ───────────────────────────────────────────────────────

  /// Record a wrong answer: showed [correctWordId] but user chose [confusedWithId].
  Future<void> recordConfusion({
    required int correctWordId,
    required int confusedWithId,
    required String languageCode,
    required String targetLanguageCode,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawInsert(
      '''
      INSERT INTO word_confusions
        (correct_word_id, confused_with_id, language_code, target_language_code, confusion_count, last_confused)
      VALUES (?, ?, ?, ?, 1, ?)
      ON CONFLICT(correct_word_id, confused_with_id) DO UPDATE SET
        confusion_count = confusion_count + 1,
        last_confused = excluded.last_confused
    ''',
      [correctWordId, confusedWithId, languageCode, targetLanguageCode, now],
    );

    // Async Queue for sync
    OfflineQueueManager().queueConfusionRecord(correctWordId, confusedWithId);
  }

  /// Returns Word objects the user has historically confused with [word].
  Future<List<Word>> getConfusionDistractors(Word word, {int limit = 3}) async {
    if (word.id == null) return [];
    final db = await database;
    final ids = await db.rawQuery(
      '''
      SELECT confused_with_id FROM word_confusions
      WHERE correct_word_id = ?
      ORDER BY confusion_count DESC
      LIMIT ?
    ''',
      [word.id, limit],
    );
    if (ids.isEmpty) return [];
    final idList = ids.map((r) => r['confused_with_id'] as int).toList();
    final placeholders = idList.map((_) => '?').join(',');
    final maps = await db.rawQuery(
      'SELECT * FROM words WHERE id IN ($placeholders)',
      idList,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  // ── QUIZ PERFORMANCE TRACKER ──────────────────────────────────────────────

  Future<void> recordQuizPerformance({
    required int wordId,
    required String quizType,
    required bool correct,
    required int responseMs,
  }) async {
    final db = await database;
    await db.rawInsert(
      '''
      INSERT INTO word_quiz_performance (word_id, quiz_type, attempts, correct_count, avg_response_ms)
      VALUES (?, ?, 1, ?, ?)
      ON CONFLICT(word_id, quiz_type) DO UPDATE SET
        attempts = attempts + 1,
        correct_count = correct_count + ?,
        avg_response_ms = (avg_response_ms * (attempts - 1) + ?) / attempts
    ''',
      [
        wordId,
        quizType,
        correct ? 1 : 0,
        responseMs,
        correct ? 1 : 0,
        responseMs,
      ],
    );

    // Async Queue for sync
    OfflineQueueManager().queueQuizPerformance(
      wordId,
      quizType,
      responseMs,
      correct,
    );
  }

  Future<String?> getWeakestQuizType(int wordId, {int minAttempts = 3}) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT quiz_type, correct_count * 1.0 / attempts AS accuracy
      FROM word_quiz_performance
      WHERE word_id = ? AND attempts >= ?
      ORDER BY accuracy ASC
      LIMIT 1
    ''',
      [wordId, minAttempts],
    );
    if (result.isEmpty) return null;
    return result.first['quiz_type'] as String?;
  }

  // ── MASTERY DECAY ON SILENCE ──────────────────────────────────────────────

  Future<int> applyMasteryDecay(
    String languageCode,
    String targetLanguageCode, {
    int decayAfterDays = 3,
  }) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: decayAfterDays))
        .toIso8601String();
    final affected = await db.rawUpdate(
      '''
      UPDATE words SET
        mastery_level = MAX(0, mastery_level - 1),
        fragile_decay_applied = 1,
        next_review = ?
      WHERE language_code = ? AND target_language_code = ?
        AND mastery_level IN (1, 2)
        AND fragile_decay_applied = 0
        AND (last_reviewed IS NULL OR last_reviewed < ?)
    ''',
      [
        DateTime.now().toIso8601String(),
        languageCode,
        targetLanguageCode,
        cutoff,
      ],
    );
    await db.rawUpdate(
      '''
      UPDATE words SET fragile_decay_applied = 0
      WHERE language_code = ? AND target_language_code = ?
        AND last_reviewed >= ?
    ''',
      [languageCode, targetLanguageCode, cutoff],
    );
    return affected;
  }

  // ── DOMAIN COVERAGE HEATMAP ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDomainCoverageGaps(
    String languageCode,
    String targetLanguageCode,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT
        domain,
        sub_domain,
        COUNT(*) as total,
        SUM(CASE WHEN mastery_level > 0 THEN 1 ELSE 0 END) as learned,
        CAST(SUM(CASE WHEN mastery_level > 0 THEN 1 ELSE 0 END) AS REAL) / COUNT(*) AS coverage_ratio
      FROM words
      WHERE language_code = ? AND target_language_code = ?
        AND domain IS NOT NULL
      GROUP BY domain, sub_domain
      HAVING total > 0
      ORDER BY coverage_ratio ASC, total DESC
    ''',
      [languageCode, targetLanguageCode],
    );
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ── SMART NEW WORD (context + coverage bias) ──────────────────────────────

  Future<Word?> getSmartNewWord(
    String languageCode,
    String targetLanguageCode, {
    String? categoryId,
    String? domain,
    String? subDomain,
    String? partOfSpeech,
    String? microCategory,
    String? activeSubDomain,
    List<Map<String, dynamic>>? coverageGaps,
  }) async {
    final db = await database;
    String baseWhere =
        'language_code = ? AND target_language_code = ? AND mastery_level = 0';
    List<dynamic> baseArgs = [languageCode, targetLanguageCode];
    if (domain != null && domain.isNotEmpty) {
      baseWhere += ' AND domain = ?';
      baseArgs.add(domain);
    }
    if (subDomain != null && subDomain.isNotEmpty) {
      baseWhere += ' AND sub_domain = ?';
      baseArgs.add(subDomain);
    }
    if (microCategory != null && microCategory.isNotEmpty) {
      baseWhere += ' AND micro_category = ?';
      baseArgs.add(microCategory);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      baseWhere += ' AND (category_ids LIKE ? OR category = ?)';
      baseArgs.add('%$categoryId%');
      baseArgs.add(categoryId);
    }
    if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
      baseWhere += ' AND parts_of_speech LIKE ?';
      baseArgs.add('%$partOfSpeech%');
    }
    const order =
        "(CASE frequency WHEN 'Very high' THEN 8 WHEN 'High' THEN 4 WHEN 'Medium' THEN 2 ELSE 1 END) * (ABS(RANDOM()) % 100) DESC";

    if (activeSubDomain != null &&
        activeSubDomain.isNotEmpty &&
        subDomain == null) {
      final maps = await db.query(
        'words',
        where: '$baseWhere AND sub_domain = ?',
        whereArgs: [...baseArgs, activeSubDomain],
        orderBy: order,
        limit: 1,
      );
      if (maps.isNotEmpty) return Word.fromMap(maps.first);
    }
    if (coverageGaps != null && subDomain == null) {
      for (final gap in coverageGaps.take(3)) {
        final gs = gap['sub_domain'] as String?;
        if (gs == null) continue;
        final maps = await db.query(
          'words',
          where: '$baseWhere AND sub_domain = ?',
          whereArgs: [...baseArgs, gs],
          orderBy: order,
          limit: 1,
        );
        if (maps.isNotEmpty) return Word.fromMap(maps.first);
      }
    }
    final maps = await db.query(
      'words',
      where: baseWhere,
      whereArgs: baseArgs,
      orderBy: order,
      limit: 1,
    );
    return maps.isEmpty ? null : Word.fromMap(maps.first);
  }

  // ── FORGOTTEN CURVE DETECTION ─────────────────────────────────────────────

  Future<List<Word>> getForgottenWords(
    String languageCode,
    String targetLanguageCode, {
    int overdueDays = 3,
    int limit = 5,
  }) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: overdueDays))
        .toIso8601String();
    final maps = await db.query(
      'words',
      where:
          'language_code = ? AND target_language_code = ? AND mastery_level > 0 AND next_review < ?',
      whereArgs: [languageCode, targetLanguageCode, cutoff],
      orderBy: 'next_review ASC',
      limit: limit,
    );
    return maps.map((m) {
      final w = Word.fromMap(m);
      if (w.masteryLevel > 1) w.masteryLevel = w.masteryLevel - 1;
      return w;
    }).toList();
  }
}
