import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/sentence_item.dart';
import '../core/supabase_config.dart';
import '../widgets/sentence_quizzes.dart';
import '../database/database_helper.dart';
import '../providers/app_providers.dart';
import '../services/auth_service.dart';
import '../services/sync_manager.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  QUIZ MODES
// ══════════════════════════════════════════════════════════════════════════════

enum SentenceQuizMode { fillBranch, translateSprint }

extension SentenceQuizModeX on SentenceQuizMode {
  String get label => switch (this) {
    SentenceQuizMode.fillBranch => 'Fill The Branch',
    SentenceQuizMode.translateSprint => 'Translation Sprint',
  };

  String get emoji => switch (this) {
    SentenceQuizMode.fillBranch => '🌿',
    SentenceQuizMode.translateSprint => '🌳',
  };

  String get description => switch (this) {
    SentenceQuizMode.fillBranch => 'Complete the missing word in a sentence',
    SentenceQuizMode.translateSprint =>
      'Identify what the highlighted word means',
  };

  Color get color => switch (this) {
    SentenceQuizMode.fillBranch => SeedlingColors.seedlingGreen,
    SentenceQuizMode.translateSprint => SeedlingColors.water,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
//  SESSION SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class SentenceSessionScreen extends ConsumerStatefulWidget {
  final SentenceQuizMode mode;

  /// Language pair — reserved for when real DB queries replace placeholder data.
  final String nativeLangCode;
  final String targetLangCode;

  const SentenceSessionScreen({
    super.key,
    required this.mode,
    this.nativeLangCode = 'en',
    this.targetLangCode = 'es',
  });

  @override
  ConsumerState<SentenceSessionScreen> createState() => _SentenceSessionScreenState();
}

class _SentenceSessionScreenState extends ConsumerState<SentenceSessionScreen> {
  List<SentenceItem> _items = [];
  bool _isLoading = true;
  String _error = '';
  int _currentIndex = 0;
  int _correct = 0;
  bool _sessionComplete = false;
  bool _saveSessionCalled = false;

  @override
  void initState() {
    super.initState();
    _fetchSentences();
  }

  Future<void> _fetchSentences() async {
    try {
      final response = await SupabaseConfig.client
          .from('sentences')
          .select()
          .eq('native_lang_code', widget.nativeLangCode)
          .eq('target_lang_code', widget.targetLangCode);
      
      final items = (response as List).map((e) => SentenceItem.fromJson(e)).toList();
      items.shuffle();
      
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ── Option generation ──────────────────────────────────────────────────────

  List<String> _generateOptions(SentenceItem current) {
    final isTranslate = widget.mode == SentenceQuizMode.translateSprint;
    final correct = isTranslate ? current.nativeWord : current.targetWord;

    // Collect up to 3 distractors from the other items
    final distractors = _items
        .where((it) => it.id != current.id)
        .map((it) => isTranslate ? it.nativeWord : it.targetWord)
        .toSet()
        .take(3)
        .toList();

    final opts = <String>[correct, ...distractors];
    opts.shuffle();
    return opts;
  }

  // ── Answer handling ────────────────────────────────────────────────────────

  void _onAnswer(bool correct) {
    if (correct) setState(() => _correct++);
    setState(() {
      if (_currentIndex < _items.length - 1) {
        _currentIndex++;
      } else {
        _sessionComplete = true;
        _saveProgress();
      }
    });
  }

  Future<void> _saveProgress() async {
    if (_saveSessionCalled) return;
    _saveSessionCalled = true;

    final userId = AuthService().userId ?? 'guest';
    final db = DatabaseHelper();
    
    await db.saveStudySession({
      'user_id': userId,
      'language_code': widget.targetLangCode,
      'session_date': DateTime.now().toIso8601String(),
      'words_studied': _items.length,
      'correct_answers': _correct,
      'duration_minutes': 5, // Estimated
      'xp_gained': 100, // Balanced XP for sentence sessions
    });

    // Refresh stats provider
    ref.invalidate(userStatsProvider);
    // Sync to cloud
    SyncManager().syncToCloud();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: SeedlingColors.background,
        appBar: _buildAppBar(0),
        body: const Center(
          child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: SeedlingColors.background,
        appBar: _buildAppBar(0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Failed to load sentences: $_error', style: SeedlingTypography.body),
          ),
        ),
      );
    }
    
    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: SeedlingColors.background,
        appBar: _buildAppBar(0),
        body: Center(
          child: Text('No sentences available.', style: SeedlingTypography.body),
        ),
      );
    }

    if (_sessionComplete) {
      return _SessionCompleteScreen(
        mode: widget.mode,
        correct: _correct,
        total: _items.length,
        onRestart: () => setState(() {
          _currentIndex = 0;
          _correct = 0;
          _sessionComplete = false;
          _items.shuffle();
        }),
        onExit: () => Navigator.of(context).pop(),
      );
    }

    final item = _items[_currentIndex];
    final options = _generateOptions(item);
    final progress = (_currentIndex) / _items.length;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: _buildAppBar(progress),
      body: SafeArea(
        child: switch (widget.mode) {
          SentenceQuizMode.fillBranch => FillTheBranchQuiz(
            key: ValueKey(_currentIndex),
            item: item,
            options: options,
            onAnswer: _onAnswer,
          ),
          SentenceQuizMode.translateSprint => TranslationSprintQuiz(
            key: ValueKey(_currentIndex),
            item: item,
            options: options,
            onAnswer: _onAnswer,
          ),
        },
      ),
    );
  }

  AppBar _buildAppBar(double progress) {
    return AppBar(
      backgroundColor: SeedlingColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.close_rounded,
          color: SeedlingColors.textSecondary,
          size: 22,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        children: [
          Text(
            widget.mode.label,
            style: SeedlingTypography.caption.copyWith(
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: SeedlingColors.cardBackground,
              valueColor: AlwaysStoppedAnimation<Color>(widget.mode.color),
              minHeight: 5,
            ),
          ),
        ],
      ),
      centerTitle: true,
      titleTextStyle: SeedlingTypography.caption,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '${_currentIndex + 1}/${_items.length}',
              style: SeedlingTypography.caption.copyWith(
                color: SeedlingColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SESSION COMPLETE SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _SessionCompleteScreen extends StatelessWidget {
  final SentenceQuizMode mode;
  final int correct;
  final int total;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const _SessionCompleteScreen({
    required this.mode,
    required this.correct,
    required this.total,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = correct / total;
    final String encouragement;
    final String icon;
    if (ratio >= 0.9) {
      encouragement = 'Your garden is thriving!';
      icon = '🌳';
    } else if (ratio >= 0.6) {
      encouragement = 'Good growth! Keep watering.';
      icon = '🌿';
    } else {
      encouragement = 'Every seed needs time — try again!';
      icon = '🌱';
    }

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              // Icon
              Text(icon, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 24),
              Text(
                mode.label,
                style: SeedlingTypography.caption.copyWith(
                  letterSpacing: 1.4,
                  color: mode.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                encouragement,
                style: SeedlingTypography.heading2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Score ring
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 32,
                ),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: mode.color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_florist_rounded,
                      color: mode.color,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$correct',
                            style: SeedlingTypography.heading1.copyWith(
                              color: mode.color,
                              fontSize: 48,
                            ),
                          ),
                          TextSpan(
                            text: ' / $total',
                            style: SeedlingTypography.heading2.copyWith(
                              color: SeedlingColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${(ratio * 100).round()}% correct',
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Buttons
              _PrimaryButton(
                label: '🔄  Practice Again',
                color: mode.color,
                onTap: onRestart,
              ),
              const SizedBox(height: 12),
              _GhostButton(label: '← Back to Garden', onTap: onExit),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LOCAL BUTTON HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: SeedlingTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            color: SeedlingColors.background,
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: SeedlingColors.morningDew.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: SeedlingTypography.body.copyWith(
            color: SeedlingColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
