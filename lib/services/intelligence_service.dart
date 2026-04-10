import 'dart:math' as math;
import '../database/database_helper.dart';
import '../models/word.dart';

// ═══════════════════════════════════════════════════════════════════════════
// INTELLIGENCE SERVICE
// Central hub for all adaptive learning logic. Keeps DB and UI layers clean.
// ═══════════════════════════════════════════════════════════════════════════

class IntelligenceService {
  static final IntelligenceService _instance = IntelligenceService._internal();
  factory IntelligenceService() => _instance;
  IntelligenceService._internal();

  static IntelligenceService get instance => _instance;

  final _rng = math.Random();

  // ── Mastery Decay ─────────────────────────────────────────────────────────

  /// Call on every app startup. Silently decays fragile words (mastery 1–2)
  /// if the user has been absent for 3+ days. Returns the number of words decayed.
  Future<int> detectAndApplyMasteryDecay(
    DatabaseHelper db,
    String languageCode,
    String targetLanguageCode,
  ) async {
    try {
      return await db.applyMasteryDecay(languageCode, targetLanguageCode);
    } catch (e) {
      // Non-fatal — never block startup
      return 0;
    }
  }

  // ── Warm-Up Ramp ──────────────────────────────────────────────────────────

  /// Sorts [words] for session warm-up: easiest/most-mastered words first,
  /// gradually ramping into harder/newer words.
  /// - High mastery + high streak = easy warm-up card
  /// - Low mastery + high difficulty = hard card for later
  List<Word> getSessionWordOrder(List<Word> words) {
    if (words.length <= 2) return words;

    final sorted = List<Word>.from(words);
    sorted.sort((a, b) {
      final scoreA = _warmUpScore(a);
      final scoreB = _warmUpScore(b);
      return scoreB.compareTo(scoreA); // descending = easiest first
    });
    return sorted;
  }

  /// Higher score = easier / more familiar = goes first in the warm-up ramp.
  double _warmUpScore(Word w) {
    // We use FSRS Retrievability (R) as the primary ease metric.
    // Higher R means the user is more likely to remember it right now.
    // R = exp(ln(0.9) * (elapsed_days / stability))
    
    double stability = w.fsrsStability;
    if (stability <= 0) return 0.0; // New words go last in warm-up

    double elapsed = w.fsrsElapsedDays.toDouble();
    double retrievability = math.exp(math.log(0.9) * (elapsed / stability));

    double score = retrievability * 100.0;
    score += w.fsrsReps * 2.0; // More reps = more familiarity
    score += _rng.nextDouble() * 5.0; // small noise
    
    return score;
  }

  // ── Adaptive Quiz Type ────────────────────────────────────────────────────

  /// Returns the best quiz type for [word]:
  /// - If a quiz type has < 40% accuracy with ≥ 3 attempts, prefer it 70% of the time
  /// - Otherwise falls back to [fallbackType]
  Future<String?> getBestQuizTypeForWord(
    int wordId,
    DatabaseHelper db, {
    String? fallbackType,
  }) async {
    try {
      final weakest = await db.getWeakestQuizType(wordId);
      if (weakest != null && _rng.nextDouble() < 0.70) {
        return weakest;
      }
    } catch (_) {}
    return fallbackType;
  }

  // ── Confusion-Based Distractors ───────────────────────────────────────────

  /// Merges historically confused words with [sessionWords] to produce the
  /// best possible distractor set for a quiz on [targetWord].
  /// Confused words are prioritised; session words fill any remaining slots.
  Future<List<Word>> getConfusionDistractors(
    Word targetWord,
    List<Word> sessionWords,
    DatabaseHelper db, {
    int needed = 3,
  }) async {
    final distractors = <Word>[];

    // 1. Use confusion graph first
    try {
      final confused = await db.getConfusionDistractors(
        targetWord,
        limit: needed,
      );
      for (final w in confused) {
        if (w.id != targetWord.id && !distractors.any((d) => d.id == w.id)) {
          distractors.add(w);
        }
      }
    } catch (_) {}

    // 2. Fill remaining with session words (sorted by similarity)
    if (distractors.length < needed) {
      final others = sessionWords
          .where(
            (w) =>
                w.id != targetWord.id && !distractors.any((d) => d.id == w.id),
          )
          .toList();
      others.sort(
        (a, b) => _levenshtein(
          targetWord.translation,
          a.translation,
        ).compareTo(_levenshtein(targetWord.translation, b.translation)),
      );
      distractors.addAll(others.take(needed - distractors.length));
    }

    return distractors;
  }

  // ── Contextual Word Grouping ──────────────────────────────────────────────

  /// Determines the dominant sub-domain being practiced in [sessionWords].
  /// Used to bias next new word toward the same semantic cluster.
  String? getDominantSubDomain(List<Word> sessionWords) {
    if (sessionWords.isEmpty) return null;
    final counts = <String, int>{};
    for (final w in sessionWords) {
      if (w.subDomain != null && w.subDomain!.isNotEmpty) {
        counts[w.subDomain!] = (counts[w.subDomain!] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  // ── Levenshtein (internal, for similarity ranking) ────────────────────────

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var v0 = List<int>.generate(b.length + 1, (i) => i);
    var v1 = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i].toLowerCase() == b[j].toLowerCase() ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (var j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }
}
