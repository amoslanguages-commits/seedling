import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grammar_model.dart';
import '../services/grammar_service.dart';
import 'course_provider.dart';

// ─── ACTIVE LANG CODE ────────────────────────────────────────────────────────

/// Resolves the current learning language code from the active course.
final grammarLangCodeProvider = Provider<String>((ref) {
  final courseState = ref.watch(courseProvider);
  return courseState.activeCourse?.targetLanguage.code ?? 'en-US';
});

// ─── ALL CONCEPT PROGRESS ────────────────────────────────────────────────────

/// Loads all 121 concept progress entries for the active language.
final allConceptProgressProvider =
    FutureProvider<Map<int, ConceptProgress>>((ref) async {
  final langCode = ref.watch(grammarLangCodeProvider);
  return GrammarService.instance.getAllConceptProgress(langCode);
});

// ─── LEVEL PROGRESS ──────────────────────────────────────────────────────────

/// Average mastery per level (A0–C1).
final levelProgressProvider =
    FutureProvider<Map<GrammarLevel, double>>((ref) async {
  final langCode = ref.watch(grammarLangCodeProvider);
  return GrammarService.instance.getLevelProgress(langCode);
});

// ─── FRONTIER CONCEPT ────────────────────────────────────────────────────────

/// The concept ID of the learner's current frontier (lowest unlocked, not mastered).
final frontierConceptIdProvider = FutureProvider<int>((ref) async {
  final langCode = ref.watch(grammarLangCodeProvider);
  return GrammarService.instance.getFrontierConceptId(langCode);
});

// ─── SINGLE CONCEPT PROGRESS ─────────────────────────────────────────────────

/// Progress for a specific concept by ID.
final conceptProgressProvider =
    FutureProvider.family<ConceptProgress, int>((ref, conceptId) async {
  final langCode = ref.watch(grammarLangCodeProvider);
  return GrammarService.instance.getConceptProgress(conceptId, langCode);
});

// ─── CONCEPT SENTENCES ───────────────────────────────────────────────────────

/// All sentences for a specific concept in the active language.
final conceptSentencesProvider =
    FutureProvider.family<List<GrammarSentence>, int>((ref, conceptId) async {
  final langCode = ref.watch(grammarLangCodeProvider);
  return GrammarService.instance.getSentencesForConcept(conceptId, langCode);
});

// ─── DUE SENTENCES ───────────────────────────────────────────────────────────

/// Sentences due for review today.
final dueSentencesProvider =
    FutureProvider<List<SentenceProgress>>((ref) async {
  final langCode = ref.watch(grammarLangCodeProvider);
  return GrammarService.instance.getDueSentences(langCode);
});

// ─── OVERALL GRAMMAR STATS ───────────────────────────────────────────────────

class GrammarStats {
  final int totalConcepts;
  final int masteredConcepts;
  final int inProgressConcepts;
  final int availableConcepts;
  final int lockedConcepts;
  final double overallMastery;
  final int dueCount;
  final GrammarLevel currentLevel;

  const GrammarStats({
    required this.totalConcepts,
    required this.masteredConcepts,
    required this.inProgressConcepts,
    required this.availableConcepts,
    required this.lockedConcepts,
    required this.overallMastery,
    required this.dueCount,
    required this.currentLevel,
  });

  static const empty = GrammarStats(
    totalConcepts: 121,
    masteredConcepts: 0,
    inProgressConcepts: 0,
    availableConcepts: 1,
    lockedConcepts: 120,
    overallMastery: 0.0,
    dueCount: 0,
    currentLevel: GrammarLevel.a0,
  );
}

final grammarStatsProvider = FutureProvider<GrammarStats>((ref) async {
  final progressMap = await ref.watch(allConceptProgressProvider.future);
  final due = await ref.watch(dueSentencesProvider.future);

  int mastered = 0;
  int inProgress = 0;
  int available = 0;
  int locked = 0;
  double masterySum = 0.0;
  GrammarLevel currentLevel = GrammarLevel.a0;

  for (final entry in progressMap.entries) {
    final progress = entry.value;
    masterySum += progress.mastery;
    switch (progress.nodeState) {
      case ConceptNodeState.mastered:
        mastered++;
        break;
      case ConceptNodeState.inProgress:
        inProgress++;
        break;
      case ConceptNodeState.available:
        available++;
        break;
      case ConceptNodeState.locked:
        locked++;
        break;
    }
  }

  // Determine current level from highest level with any progress
  for (final level in GrammarLevel.values.reversed) {
    final levelConcepts = GrammarConcept.allConcepts
        .where((c) => c.level == level)
        .map((c) => progressMap[c.conceptId])
        .whereType<ConceptProgress>()
        .toList();
    final hasProgress = levelConcepts.any((p) => p.mastery > 0);
    if (hasProgress) {
      currentLevel = level;
      break;
    }
  }

  final total = progressMap.length;
  return GrammarStats(
    totalConcepts: 121,
    masteredConcepts: mastered,
    inProgressConcepts: inProgress,
    availableConcepts: available,
    lockedConcepts: locked,
    overallMastery: total > 0 ? (masterySum / total).clamp(0.0, 1.0) : 0.0,
    dueCount: due.length,
    currentLevel: currentLevel,
  );
});
