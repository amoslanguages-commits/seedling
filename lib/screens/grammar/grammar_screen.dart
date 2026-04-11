import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:twemoji/twemoji.dart';

import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/grammar_model.dart';
import '../../providers/course_provider.dart';
import '../../providers/grammar_provider.dart';
import '../../services/grammar_calibration_service.dart';
import '../../services/grammar_observability_service.dart';
import '../../services/grammar_parser_service.dart';
import '../../services/grammar_service.dart';
import '../../services/grammar_rule_engine.dart';
import '../../services/haptic_service.dart';
import 'concept_detail_screen.dart';

enum _StudioMode { learn, practice, repair, master }

class GrammarScreen extends ConsumerStatefulWidget {
  const GrammarScreen({super.key});

  @override
  ConsumerState<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends ConsumerState<GrammarScreen> {
  _StudioMode _mode = _StudioMode.learn;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(grammarStatsProvider);
    final progressAsync = ref.watch(allConceptProgressProvider);
    final frontierAsync = ref.watch(frontierConceptIdProvider);
    final levelProgressAsync = ref.watch(levelProgressProvider);
    final activeCourse = ref.watch(courseProvider).activeCourse;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: _StudioHeader(
                  statsAsync: statsAsync,
                  flagEmoji: activeCourse?.targetLanguage.flag,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: _ModeSelector(
                  selected: _mode,
                  onSelect: (mode) {
                    HapticService.selectionClick();
                    setState(() => _mode = mode);
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: _StudioInsightBar(
                  mode: _mode,
                  statsAsync: statsAsync,
                  frontierAsync: frontierAsync,
                ),
              ),
            ),
            ..._buildModeSlivers(
              context,
              progressAsync,
              frontierAsync,
              levelProgressAsync,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModeSlivers(
    BuildContext context,
    AsyncValue<Map<int, ConceptProgress>> progressAsync,
    AsyncValue<int> frontierAsync,
    AsyncValue<Map<GrammarLevel, double>> levelProgressAsync,
  ) {
    switch (_mode) {
      case _StudioMode.learn:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _SectionLabel(
                title: 'Focused learning flow',
                subtitle: 'Context → pattern notice → transform → produce',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _SentenceWorkbenchCard(frontierAsync: frontierAsync),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _LevelRailCard(levelProgressAsync: levelProgressAsync),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _LiteracyBridgeCard(frontierAsync: frontierAsync),
            ),
          ),
          _conceptSliver(
            progressAsync: progressAsync,
            filter: (concept, progress) => progress.isUnlocked || concept.conceptId <= 3,
            emptyText: 'No learning concepts available yet.',
          ),
        ];
      case _StudioMode.practice:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _SectionLabel(
                title: 'Practical drill engine',
                subtitle: 'Fast transformations, contrast drills, and production tasks',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _PracticeDeck(frontierAsync: frontierAsync),
            ),
          ),
          _conceptSliver(
            progressAsync: progressAsync,
            filter: (concept, progress) =>
                progress.isUnlocked && progress.nodeState != ConceptNodeState.mastered,
            emptyText: 'No active practice concepts yet. Unlock your first concept in Learn mode.',
          ),
        ];
      case _StudioMode.repair:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _SectionLabel(
                title: 'Error clinic',
                subtitle: 'Personalized remediation based on weak grammar patterns',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: const _RepairMethodCard(),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _ErrorTaxonomyCard(),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _AdaptiveRepairPlanCard(),
            ),
          ),
          _conceptSliver(
            progressAsync: progressAsync,
            filter: (concept, progress) =>
                progress.isUnlocked && progress.mastery > 0 && progress.mastery < 0.75,
            emptyText: 'No weak concepts found. Great work — keep reviewing to maintain accuracy.',
          ),
        ];
      case _StudioMode.master:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _SectionLabel(
                title: 'Advanced mastery lab',
                subtitle: 'Nuance, register, precision, and high-level grammar control',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: const _MasterLabCard(),
            ),
          ),
          _conceptSliver(
            progressAsync: progressAsync,
            filter: (concept, progress) =>
                concept.level.index >= GrammarLevel.b2.index && progress.isUnlocked,
            emptyText: 'Unlock B2+ concepts to start advanced mastery work.',
          ),
        ];
    }
  }

  Widget _conceptSliver({
    required AsyncValue<Map<int, ConceptProgress>> progressAsync,
    required bool Function(GrammarConcept concept, ConceptProgress progress) filter,
    required String emptyText,
  }) {
    return progressAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Could not load concepts: $e',
            style: SeedlingTypography.body.copyWith(color: SeedlingColors.error),
          ),
        ),
      ),
      data: (progressMap) {
        final entries = GrammarConcept.allConcepts.where((concept) {
          final progress = progressMap[concept.conceptId] ??
              ConceptProgress.empty(concept.conceptId);
          return filter(concept, progress);
        }).toList();

        if (entries.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _EmptyStateCard(text: emptyText),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final concept = entries[index];
              final progress = progressMap[concept.conceptId] ??
                  ConceptProgress.empty(concept.conceptId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StudioConceptTile(
                  concept: concept,
                  progress: progress,
                  onTap: () => _openConceptDetail(context, concept, progress),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openConceptDetail(
    BuildContext context,
    GrammarConcept concept,
    ConceptProgress progress,
  ) {
    if (!progress.isUnlocked) {
      HapticService.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Master earlier concepts to unlock ${concept.displayName}.',
            style: SeedlingTypography.body.copyWith(color: Colors.white),
          ),
          backgroundColor: SeedlingColors.soil,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticService.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConceptDetailScreen(
          concept: concept,
          initialProgress: progress,
        ),
      ),
    );
  }
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({required this.statsAsync, required this.flagEmoji});

  final AsyncValue<GrammarStats> statsAsync;
  final String? flagEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102A1F), Color(0xFF122D3F)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Grammar Studio',
                style: SeedlingTypography.title.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              if (flagEmoji != null) Twemoji(emoji: flagEmoji!, width: 18, height: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'From reading foundations to advanced grammar precision.',
            style: SeedlingTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 6),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => Row(
              children: [
                _HeaderMetric(label: 'Mastered', value: '${stats.masteredConcepts}'),
                _HeaderMetric(label: 'Due', value: '${stats.dueCount}'),
                _HeaderMetric(label: 'Level', value: stats.currentLevel.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: SeedlingTypography.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: SeedlingTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onSelect});

  final _StudioMode selected;
  final ValueChanged<_StudioMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: _StudioMode.values.map((mode) {
          final isSelected = mode == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? SeedlingColors.seedlingGreen.withValues(alpha: 0.17)
                      : Colors.transparent,
                ),
                child: Text(
                  switch (mode) {
                    _StudioMode.learn => 'Learn',
                    _StudioMode.practice => 'Practice',
                    _StudioMode.repair => 'Repair',
                    _StudioMode.master => 'Master',
                  },
                  textAlign: TextAlign.center,
                  style: SeedlingTypography.caption.copyWith(
                    color: isSelected
                        ? SeedlingColors.seedlingGreen
                        : SeedlingColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StudioInsightBar extends StatelessWidget {
  const _StudioInsightBar({
    required this.mode,
    required this.statsAsync,
    required this.frontierAsync,
  });

  final _StudioMode mode;
  final AsyncValue<GrammarStats> statsAsync;
  final AsyncValue<int> frontierAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(_iconForMode(mode), size: 18, color: SeedlingColors.seedlingGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _textForMode(mode, statsAsync, frontierAsync),
              style: SeedlingTypography.caption.copyWith(
                color: SeedlingColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMode(_StudioMode mode) {
    switch (mode) {
      case _StudioMode.learn:
        return Icons.school;
      case _StudioMode.practice:
        return Icons.bolt;
      case _StudioMode.repair:
        return Icons.healing;
      case _StudioMode.master:
        return Icons.auto_awesome;
    }
  }

  String _textForMode(
    _StudioMode mode,
    AsyncValue<GrammarStats> statsAsync,
    AsyncValue<int> frontierAsync,
  ) {
    final due = statsAsync.asData?.value.dueCount ?? 0;
    final frontier = frontierAsync.asData?.value;
    switch (mode) {
      case _StudioMode.learn:
        return frontier == null
            ? 'Continue your guided concept sequence.'
            : 'Your guided next step is concept #$frontier.';
      case _StudioMode.practice:
        return 'Run rapid transformations and production drills (${due} reviews due).';
      case _StudioMode.repair:
        return 'Target weak patterns with adaptive hints and contrast explanations.';
      case _StudioMode.master:
        return 'Train high-level grammar nuance across advanced contexts.';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary),
        ),
      ],
    );
  }
}

class _SentenceWorkbenchCard extends ConsumerStatefulWidget {
  const _SentenceWorkbenchCard({required this.frontierAsync});

  final AsyncValue<int> frontierAsync;

  @override
  ConsumerState<_SentenceWorkbenchCard> createState() => _SentenceWorkbenchCardState();
}

class _SentenceWorkbenchCardState extends ConsumerState<_SentenceWorkbenchCard> {
  final TextEditingController _answerController = TextEditingController();
  final fsrs.Scheduler _scheduler = fsrs.Scheduler();
  final GrammarParserService _parser = GrammarParserService(engine: const GrammarRuleEngine());
  final GrammarCalibrationService _calibration = const GrammarCalibrationService();
  int _coachDepth = 0;
  String? _feedback;
  String? _errorType;
  bool _looksCorrect = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conceptId = widget.frontierAsync.asData?.value ?? 1;
    final sentencesAsync = ref.watch(conceptSentencesProvider(conceptId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: SeedlingColors.cardBackground,
        border: Border.all(color: SeedlingColors.seedlingGreen.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sentence Workbench',
                style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                'Concept #$conceptId',
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.seedlingGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          sentencesAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 6),
            error: (e, _) => Text(
              'Unable to load sentence: $e',
              style: SeedlingTypography.caption.copyWith(color: SeedlingColors.error),
            ),
            data: (sentences) {
              final prompt = sentences.isEmpty ? null : sentences.first;
              return _workbenchContent(prompt);
            },
          ),
        ],
      ),
    );
  }

  Widget _workbenchContent(GrammarSentence? prompt) {
    final baseSentence = prompt?.sentence ?? 'No sentence data yet for this concept.';
    final promptNotes =
        prompt?.notes ?? 'Rewrite the sentence using the target grammar naturally.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prompt',
          style: SeedlingTypography.caption.copyWith(
            color: SeedlingColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '“$baseSentence”',
          style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Task: $promptNotes',
          style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Type your transformed sentence...',
            hintStyle: SeedlingTypography.caption.copyWith(
              color: SeedlingColors.textSecondary.withValues(alpha: 0.8),
            ),
            filled: true,
            fillColor: SeedlingColors.deepRoot.withValues(alpha: 0.25),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: prompt == null || _isSaving ? null : () => _evaluate(prompt),
                style: FilledButton.styleFrom(
                  backgroundColor: SeedlingColors.seedlingGreen,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isSaving ? 'Saving...' : 'Check answer'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _nextCoachDepth,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: SeedlingColors.seedlingGreen.withValues(alpha: 0.4)),
                foregroundColor: SeedlingColors.seedlingGreen,
              ),
              child: Text(
                switch (_coachDepth) {
                  0 => 'Hint',
                  1 => 'Explain',
                  _ => 'Deep Dive',
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _CoachPanel(depth: _coachDepth, note: promptNotes),
        if (_errorType != null) ...[
          const SizedBox(height: 8),
          _DiagnosticTag(label: _errorType!),
        ],
        if (_feedback != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _looksCorrect
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
            ),
            child: Text(
              _feedback!,
              style: SeedlingTypography.caption.copyWith(
                color: _looksCorrect ? Colors.green.shade300 : Colors.orange.shade300,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _nextCoachDepth() {
    HapticService.selectionClick();
    setState(() => _coachDepth = (_coachDepth + 1).clamp(0, 2).toInt());
  }

  Future<void> _evaluate(GrammarSentence prompt) async {
    final input = _answerController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _looksCorrect = false;
        _errorType = 'Missing answer';
        _feedback = 'Write a full sentence first, then check again.';
      });
      return;
    }

    final analysis = _parser.evaluate(
      promptSentence: prompt.sentence,
      answer: input,
      langCode: prompt.langCode,
    );
    final threshold = _calibration.thresholdFor(
      langCode: prompt.langCode,
      level: prompt.level,
    );
    final isCorrect = analysis.score >= threshold;

    setState(() {
      _looksCorrect = isCorrect;
      _errorType = analysis.errorType;
      _isSaving = true;
      _feedback =
          '${analysis.feedback} [ref: ${analysis.explanationId}] [conf: ${analysis.confidence.toStringAsFixed(2)}]';
    });
    GrammarObservabilityService.instance.logEvaluation(
      langCode: prompt.langCode,
      errorType: analysis.errorType,
      score: analysis.score,
      threshold: threshold,
      confidence: analysis.confidence,
    );

    try {
      final previous = await GrammarService.instance.getSentenceProgress(
        prompt.sentenceId,
        prompt.langCode,
      );
      final baseCard = fsrs.Card(
        cardId: prompt.sentenceId,
        due: previous?.dueDate ?? DateTime.now().toUtc(),
        stability: (previous?.stability ?? 0) > 0 ? previous?.stability : null,
        difficulty: (previous?.difficulty ?? 0) > 0 ? previous?.difficulty : null,
        lastReview: previous?.lastReview,
      );
      final rating = isCorrect ? fsrs.Rating.good : fsrs.Rating.again;
      final result = _scheduler.reviewCard(
        baseCard,
        rating,
        reviewDateTime: DateTime.now().toUtc(),
        reviewDuration: const Duration(seconds: 2).inMilliseconds,
      );
      final updatedCard = result.card;
      final mastery = rating == fsrs.Rating.again
          ? (analysis.score * 0.35).clamp(0.0, 0.35)
          : (analysis.score * ((updatedCard.stability ?? 1.0) / 10.0)).clamp(0.0, 1.0);

      await GrammarService.instance.recordReview(
        sentenceId: prompt.sentenceId,
        conceptId: prompt.conceptId,
        langCode: prompt.langCode,
        mastery: mastery,
        stability: updatedCard.stability ?? 1.0,
        difficulty: updatedCard.difficulty ?? 5.0,
        reps: (previous?.reps ?? 0) + 1,
        dueDate: updatedCard.due,
        errorType: analysis.errorType,
        evaluationScore: analysis.score,
        subErrorCode: analysis.subErrorCode,
        explanationId: analysis.explanationId,
        attemptedText: input,
        confidence: analysis.confidence,
        modelVersion: analysis.modelVersion,
        featureScoresJson: analysis.featureScoresJson(),
        fixedFlag: analysis.errorType == 'Strong response',
      );
      ref.invalidate(allConceptProgressProvider);
      ref.invalidate(grammarStatsProvider);
      ref.invalidate(frontierConceptIdProvider);
    } catch (_) {
      setState(() {
        _feedback = '${_feedback ?? ''} Progress save failed. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

}

class _LiteracyBridgeCard extends StatelessWidget {
  const _LiteracyBridgeCard({required this.frontierAsync});

  final AsyncValue<int> frontierAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: SeedlingColors.cardBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading-zero bridge',
            style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Before complex grammar: train script, decoding, and pronunciation patterns.',
            style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary),
          ),
          const SizedBox(height: 8),
          frontierAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (id) => Text(
              'Suggested literacy checkpoint before concept #$id.',
              style: SeedlingTypography.caption.copyWith(
                color: SeedlingColors.seedlingGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorTaxonomyCard extends ConsumerWidget {
  const _ErrorTaxonomyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langCode = ref.watch(grammarLangCodeProvider);
    return FutureBuilder<Map<String, int>>(
      future: GrammarService.instance.getErrorTaxonomy(langCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 6);
        }
        final data = snapshot.data ?? const <String, int>{};
        if (data.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: SeedlingColors.cardBackground,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your recurring grammar errors',
                style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.entries
                    .map(
                      (e) => _DiagnosticTag(label: '${e.key} (${e.value})'),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdaptiveRepairPlanCard extends ConsumerWidget {
  const _AdaptiveRepairPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langCode = ref.watch(grammarLangCodeProvider);
    return FutureBuilder<List<Map<String, Object>>>(
      future: GrammarService.instance.getAdaptiveRepairPlan(langCode, limit: 3),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final items = snapshot.data ?? const <Map<String, Object>>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: SeedlingColors.cardBackground,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adaptive repair queue',
                style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${i['code']}  priority ${(i['priority'] as num).toStringAsFixed(2)}',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiagnosticTag extends StatelessWidget {
  const _DiagnosticTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isStrong = label == 'Strong response';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: (isStrong ? Colors.green : Colors.orange).withValues(alpha: 0.18),
      ),
      child: Text(
        'Diagnosis: $label',
        style: SeedlingTypography.caption.copyWith(
          color: isStrong ? Colors.green.shade300 : Colors.orange.shade300,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CoachPanel extends StatelessWidget {
  const _CoachPanel({required this.depth, required this.note});

  final int depth;
  final String note;

  @override
  Widget build(BuildContext context) {
    final title = switch (depth) {
      0 => 'Hint',
      1 => 'Explain',
      _ => 'Deep Dive',
    };
    final content = switch (depth) {
      0 => 'Focus on the verb form and time marker first.',
      1 => note,
      _ =>
        '$note Also compare subject-verb agreement and word order before submitting.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SeedlingColors.deepRoot.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SeedlingTypography.caption.copyWith(
              color: SeedlingColors.seedlingGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            content,
            style: SeedlingTypography.caption.copyWith(
              color: SeedlingColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRailCard extends StatelessWidget {
  const _LevelRailCard({required this.levelProgressAsync});

  final AsyncValue<Map<GrammarLevel, double>> levelProgressAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: SeedlingColors.cardBackground,
      ),
      child: levelProgressAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 8),
        error: (e, _) => Text(
          'Unable to load level rail: $e',
          style: SeedlingTypography.caption.copyWith(color: SeedlingColors.error),
        ),
        data: (levelMap) => Column(
          children: GrammarLevel.values.map((level) {
            final value = (levelMap[level] ?? 0).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      level.label,
                      style: SeedlingTypography.caption.copyWith(
                        color: level.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(99),
                      valueColor: AlwaysStoppedAnimation(level.color),
                      backgroundColor: SeedlingColors.deepRoot.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(value * 100).round()}%',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PracticeDeck extends StatelessWidget {
  const _PracticeDeck({required this.frontierAsync});

  final AsyncValue<int> frontierAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: SeedlingColors.cardBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Drill Pack',
            style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const _DrillRow(title: 'Transform', subtitle: 'Rewrite tense/aspect/register'),
          const _DrillRow(title: 'Contrast', subtitle: 'Choose X vs Y and explain why'),
          const _DrillRow(title: 'Produce', subtitle: 'Write your own target sentence'),
          const SizedBox(height: 8),
          frontierAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (id) => Text(
              'Start with concept #$id for highest impact today.',
              style: SeedlingTypography.caption.copyWith(
                color: SeedlingColors.seedlingGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrillRow extends StatelessWidget {
  const _DrillRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: SeedlingColors.seedlingGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: subtitle,
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepairMethodCard extends StatelessWidget {
  const _RepairMethodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: SeedlingColors.cardBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adaptive repair method',
            style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '1) Detect error pattern  2) Give minimal hint  3) Contrast correction  4) Retest with new sentence',
            style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MasterLabCard extends StatelessWidget {
  const _MasterLabCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: SeedlingColors.cardBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mastery dimensions',
            style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Register shifts · Rhetorical control · Precision rewriting · Advanced clause fluency',
            style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StudioConceptTile extends StatelessWidget {
  const _StudioConceptTile({
    required this.concept,
    required this.progress,
    required this.onTap,
  });

  final GrammarConcept concept;
  final ConceptProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = progress.nodeState;
    final label = switch (state) {
      ConceptNodeState.locked => 'Locked',
      ConceptNodeState.available => 'Ready',
      ConceptNodeState.inProgress => 'In Progress',
      ConceptNodeState.mastered => 'Mastered',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: SeedlingColors.cardBackground,
            border: Border.all(
              color: concept.level.color.withValues(alpha: progress.isUnlocked ? 0.25 : 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(concept.emoji, style: const TextStyle(fontSize: 19)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      concept.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _Badge(text: label, color: concept.level.color),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${concept.level.label} · #${concept.conceptId}',
                    style: SeedlingTypography.caption.copyWith(
                      color: concept.level.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${progress.completedSentences}/${progress.totalSentences}',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.mastery.clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
                valueColor: AlwaysStoppedAnimation(concept.level.color),
                backgroundColor: SeedlingColors.deepRoot.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        text,
        style: SeedlingTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: SeedlingColors.cardBackground,
      ),
      child: Text(
        text,
        style: SeedlingTypography.caption.copyWith(
          color: SeedlingColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
