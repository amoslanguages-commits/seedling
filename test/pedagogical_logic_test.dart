import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/database/database_helper.dart';
import 'package:seedling/models/word.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() {
  late DatabaseHelper dbHelper;
  late Database db;

  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  setUp(() async {
    // Open a fresh in-memory database for each test
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.databaseForTesting = db;
    dbHelper = DatabaseHelper();
    
    // Minimal schema for testing SRS logic
    await db.execute('''
      CREATE TABLE IF NOT EXISTS words(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        language_code TEXT NOT NULL,
        target_language_code TEXT NOT NULL,
        domain TEXT,
        sub_domain TEXT,
        micro_category TEXT,
        parts_of_speech TEXT DEFAULT 'noun',
        category_ids TEXT DEFAULT 'general',
        mastery_level INTEGER DEFAULT 0,
        next_review TEXT
      )
    ''');
    
    // Clear the table just in case (though in-memory should be fresh)
    await db.delete('words');
  });

  tearDown(() async {
    await db.close();
  });

  test('Distractor Isolation: Subtheme Review strictly isolates distractors', () async {
    // 1. Setup words: 5 in 'fruit' (learned), 10 in 'airport' (learned)
    for(int i=1; i<=5; i++) {
        await db.insert('words', {
            'word': 'fruit_$i',
            'translation': 'target_fruit_$i',
            'language_code': 'en',
            'target_language_code': 'es',
            'sub_domain': 'fruit',
            'mastery_level': 1,
            'next_review': DateTime.now().toIso8601String(),
        });
    }
    for(int i=1; i<=10; i++) {
        await db.insert('words', {
            'word': 'airport_$i',
            'translation': 'target_airport_$i',
            'language_code': 'en',
            'target_language_code': 'es',
            'sub_domain': 'airport',
            'mastery_level': 1,
            'next_review': DateTime.now().toIso8601String(),
        });
    }

    // 2. Fetch SRS words for 'fruit' subtheme
    final words = await dbHelper.getSRSDueWords('en', 'es', subDomain: 'fruit');
    
    expect(words.length, 5);
    for (var w in words) {
        expect(w.subDomain, 'fruit');
        final options = w.options;
        expect(options.length, 4); 
        
        for (var opt in options) {
            final check = await db.query('words', where: 'translation = ?', whereArgs: [opt]);
            expect(check.isNotEmpty, true, reason: 'Option $opt must exist in database');
            expect(check.first['sub_domain'], 'fruit', reason: 'Option $opt must be from fruit subdomain');
        }
    }
  });

  test('Distractor Isolation: Global Review (Review All) mixes distractors', () async {
    // 1. Setup: 1 word in 'fruit', 20 words in 'airport'
     await db.insert('words', {
        'word': 'apple',
        'translation': 'manzana',
        'language_code': 'en',
        'target_language_code': 'es',
        'sub_domain': 'fruit',
        'mastery_level': 1,
        'next_review': DateTime.now().toIso8601String(),
    });
    for(int i=1; i<=10; i++) {
        await db.insert('words', {
            'word': 'plane_$i',
            'translation': 'avion_$i',
            'language_code': 'en',
            'target_language_code': 'es',
            'sub_domain': 'airport',
            'mastery_level': 1,
            'next_review': DateTime.now().toIso8601String(),
        });
    }

    // 2. Fetch SRS words without subDomain (Global)
    final words = await dbHelper.getSRSDueWords('en', 'es');
    final apple = words.firstWhere((w) => w.word == 'apple');
    
    final options = apple.options;
    expect(options.length, 4);
    
    bool foundAirportDistractor = false;
    for (var opt in options) {
        if (opt == 'manzana') continue;
        final check = await db.query('words', where: 'translation = ?', whereArgs: [opt]);
        if (check.first['sub_domain'] == 'airport') foundAirportDistractor = true;
    }
    expect(foundAirportDistractor, true, reason: 'Global review should draw distractors from all learned words');
  });

  test('Locking Logic: getTotalWordsLearned counts correctly', () async {
    await db.insert('words', {'word': 'a', 'translation': '1', 'language_code': 'en', 'target_language_code': 'es', 'sub_domain': 's1', 'mastery_level': 1});
    await db.insert('words', {'word': 'b', 'translation': '2', 'language_code': 'en', 'target_language_code': 'es', 'sub_domain': 's1', 'mastery_level': 1});
    await db.insert('words', {'word': 'c', 'translation': '3', 'language_code': 'en', 'target_language_code': 'es', 'sub_domain': 's2', 'mastery_level': 0}); // not learned

    final total = await dbHelper.getTotalWordsLearned('es');
    expect(total, 2);

    final sub1 = await dbHelper.getTotalWordsLearned('es', subDomain: 's1');
    expect(sub1, 2);

    final sub2 = await dbHelper.getTotalWordsLearned('es', subDomain: 's2');
    expect(sub2, 0);
  });
}
