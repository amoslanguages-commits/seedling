import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/word.dart';
import '../models/taxonomy.dart';
import '../providers/app_providers.dart';
import '../services/tts_service.dart';
import '../screens/learning.dart';

enum _SortMode { mastery, alphabetical, recent }

/// A premium Word Library / Dictionary UI that slides up from the bottom.
/// Includes real-time search and sort-by-mastery toggling.
class WordLibraryBottomSheet extends ConsumerStatefulWidget {
  final String title;
  final String? categoryId;
  final String? domain;
  final String? subDomain;
  final Color themeColor;

  const WordLibraryBottomSheet({
    super.key,
    required this.title,
    this.categoryId,
    this.domain,
    this.subDomain,
    required this.themeColor,
  });

  @override
  ConsumerState<WordLibraryBottomSheet> createState() =>
      _WordLibraryBottomSheetState();
}

class _WordLibraryBottomSheetState
    extends ConsumerState<WordLibraryBottomSheet> {
  List<Word> _allWords = [];
  List<Word> _filteredWords = [];
  bool _isLoading = true;
  _SortMode _sortMode = _SortMode.mastery;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWords();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final db = ref.read(databaseProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);

    final words = await db.getWordsForLanguage(
      nativeLang,
      targetLang,
      categoryId: widget.categoryId,
      domain: widget.domain,
      subDomain: widget.subDomain,
    );

    if (mounted) {
      setState(() {
        _allWords = words.where((w) => w.masteryLevel > 0).toList();
        _sortMode = _SortMode.mastery;
        _applyFilter();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase().trim();
    List<Word> base = q.isEmpty
        ? List.from(_allWords)
        : _allWords.where((w) {
            return w.word.toLowerCase().contains(q) ||
                w.translation.toLowerCase().contains(q);
          }).toList();

    setState(() {
      _filteredWords = _sorted(base);
    });
  }

  List<Word> _sorted(List<Word> words) {
    switch (_sortMode) {
      case _SortMode.mastery:
        return words..sort((a, b) => b.masteryLevel.compareTo(a.masteryLevel));
      case _SortMode.alphabetical:
        return words..sort((a, b) => a.word.compareTo(b.word));
      case _SortMode.recent:
        return words..sort((a, b) {
          final aDate = a.lastReviewed ?? DateTime(2000);
          final bDate = b.lastReviewed ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
    }
  }

  void _cycleSortMode() {
    setState(() {
      _sortMode =
          _SortMode.values[(_sortMode.index + 1) % _SortMode.values.length];
      _filteredWords = _sorted(List.from(_filteredWords));
    });
  }

  String get _sortLabel => switch (_sortMode) {
    _SortMode.mastery => 'Mastery',
    _SortMode.alphabetical => 'A→Z',
    _SortMode.recent => 'Recent',
  };

  IconData get _sortIcon => switch (_sortMode) {
    _SortMode.mastery => Icons.local_florist_rounded,
    _SortMode.alphabetical => Icons.sort_by_alpha_rounded,
    _SortMode.recent => Icons.access_time_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: SeedlingColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: SeedlingColors.seedlingGreen,
                    ),
                  )
                : _filteredWords.isEmpty
                ? _buildEmptyState()
                : _buildWordList(),
          ),
        ],
      ),
    );
  }

  /// Groups planted words by micro_category and returns non-null clusters.
  Map<String, List<Word>> get _microCategoryClusters {
    final clusters = <String, List<Word>>{};
    for (final w in _allWords) {
      final mc = w.microCategory;
      if (mc != null && mc.isNotEmpty) {
        clusters.putIfAbsent(mc, () => []).add(w);
      }
    }
    // Only return clusters with 2+ words (single-word clusters aren't useful)
    clusters.removeWhere((_, words) => words.length < 2);
    return clusters;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 16),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SeedlingColors.morningDew.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.themeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  CategoryTaxonomy.getCategory(
                        widget.subDomain ?? widget.categoryId ?? '',
                      )?.icon ??
                      '🌱',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: SeedlingTypography.heading2),
                    Text(
                      '${_allWords.length} words planted',
                      style: SeedlingTypography.caption,
                    ),
                  ],
                ),
              ),
              // Sort Toggle
              GestureDetector(
                onTap: _cycleSortMode,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.themeColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_sortIcon, size: 14, color: widget.themeColor),
                      const SizedBox(width: 5),
                      Text(
                        _sortLabel,
                        style: SeedlingTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: SeedlingColors.morningDew.withValues(alpha: 0.12),
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: SeedlingTypography.body.copyWith(fontSize: 15),
          cursorColor: widget.themeColor,
          decoration: InputDecoration(
            hintText: 'Search words or translations…',
            hintStyle: SeedlingTypography.caption.copyWith(
              color: SeedlingColors.textSecondary.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: SeedlingColors.textSecondary.withValues(alpha: 0.5),
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: SeedlingColors.textSecondary.withValues(
                        alpha: 0.5,
                      ),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilter();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isSearching ? '🔍' : '🌱', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? 'No words match your search.'
                : 'No seeds planted yet.',
            style: SeedlingTypography.body.copyWith(
              color: SeedlingColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Try a different word or translation.'
                : 'Start a session to grow your garden!',
            style: SeedlingTypography.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildWordList() {
    final clusters = _microCategoryClusters;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // ── Burst Mode Clusters (shown when micro-categories exist) ──
        if (clusters.isNotEmpty && _searchController.text.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'DEEP DIVE CLUSTERS',
                  style: SeedlingTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: SeedlingColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: clusters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                final entry = clusters.entries.elementAt(idx);
                final mcName = entry.key;
                final words = entry.value;
                final mastered = words.where((w) => w.masteryLevel >= 3).length;
                final progress = words.isEmpty ? 0.0 : mastered / words.length;
                final isMastered = mastered == words.length;

                return GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LearningSessionScreen(microCategory: mcName),
                      ),
                    );
                  },
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMastered
                          ? SeedlingColors.success.withValues(alpha: 0.1)
                          : SeedlingColors.cardBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isMastered
                            ? SeedlingColors.success.withValues(alpha: 0.5)
                            : widget.themeColor.withValues(alpha: 0.2),
                        width: isMastered ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Mini progress ring
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: Stack(
                                children: [
                                  CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 3.5,
                                    backgroundColor: SeedlingColors.morningDew
                                        .withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation(
                                      isMastered
                                          ? SeedlingColors.success
                                          : widget.themeColor,
                                    ),
                                  ),
                                  if (isMastered)
                                    const Center(
                                      child: Text(
                                        '🌸',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.themeColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$mastered/${words.length}',
                                style: SeedlingTypography.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: widget.themeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mcName,
                          style: SeedlingTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: SeedlingColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          isMastered ? 'Mastered ✓' : 'Deep Dive →',
                          style: SeedlingTypography.caption.copyWith(
                            fontSize: 10,
                            color: isMastered
                                ? SeedlingColors.success
                                : widget.themeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'ALL WORDS',
                style: SeedlingTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: SeedlingColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        // ── Word tiles ───────────────────────────────────────────────
        ...List.generate(_filteredWords.length, (index) {
          final word = _filteredWords[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WordListTile(
              word: word,
              themeColor: widget.themeColor,
              searchQuery: _searchController.text,
              onTap: () => _showWordDetail(word),
            ),
          );
        }),
      ],
    );
  }

  void _showWordDetail(Word word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WordDetailSheet(word: word),
    );
  }
}

// ─── Word List Tile ───────────────────────────────────────────────────────────

class _WordListTile extends StatelessWidget {
  final Word word;
  final Color themeColor;
  final String searchQuery;
  final VoidCallback onTap;

  const _WordListTile({
    required this.word,
    required this.themeColor,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: SeedlingColors.morningDew.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            // Mastery level indicator (left accent bar)
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: themeColor.withValues(
                  alpha: 0.2 + (word.masteryLevel / 5) * 0.75,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightText(
                    text: word.word,
                    query: searchQuery,
                    style: SeedlingTypography.heading3.copyWith(fontSize: 16),
                    highlightColor: themeColor,
                  ),
                  const SizedBox(height: 2),
                  _HighlightText(
                    text: word.translation,
                    query: searchQuery,
                    style: SeedlingTypography.body.copyWith(
                      color: SeedlingColors.textSecondary,
                      fontSize: 13,
                    ),
                    highlightColor: themeColor,
                  ),
                ],
              ),
            ),
            // Mastery dot row
            _buildMasteryDots(),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: SeedlingColors.morningDew.withValues(alpha: 0.4),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteryDots() {
    return Row(
      children: List.generate(5, (index) {
        final isActive = index < word.masteryLevel;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? themeColor
                : SeedlingColors.morningDew.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

// ─── Highlight Text helper ────────────────────────────────────────────────────
// Wraps matching characters in a bold highlighted span.

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final start = lower.indexOf(lowerQ);
    if (start == -1) return Text(text, style: style);

    final end = start + query.length;
    return Text.rich(
      TextSpan(
        children: [
          if (start > 0) TextSpan(text: text.substring(0, start), style: style),
          TextSpan(
            text: text.substring(start, end),
            style: style.copyWith(
              color: highlightColor,
              fontWeight: FontWeight.w800,
              backgroundColor: highlightColor.withValues(alpha: 0.12),
            ),
          ),
          if (end < text.length)
            TextSpan(text: text.substring(end), style: style),
        ],
      ),
    );
  }
}

// ─── Word Detail Sheet ────────────────────────────────────────────────────────

class _WordDetailSheet extends StatelessWidget {
  final Word word;

  const _WordDetailSheet({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: const BoxDecoration(
        color: SeedlingColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SeedlingColors.morningDew.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          Text(
            word.word,
            style: SeedlingTypography.heading1.copyWith(fontSize: 36),
          ),
          const SizedBox(height: 4),
          Text(
            word.translation,
            style: SeedlingTypography.body.copyWith(
              color: SeedlingColors.textSecondary,
              fontSize: 20,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),

          // Mastery level row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'MASTERY  ',
                style: SeedlingTypography.caption.copyWith(letterSpacing: 1.2),
              ),
              ...List.generate(
                5,
                (i) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i < word.masteryLevel
                        ? SeedlingColors.seedlingGreen
                        : SeedlingColors.morningDew.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Text(
                '  ${word.masteryLevel}/5',
                style: SeedlingTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pronounce button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLargeActionButton(
                icon: Icons.volume_up_rounded,
                label: 'Pronounce',
                onTap: () => TtsService.instance.speak(
                  word.ttsWord,
                  word.targetLanguageCode,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Details Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: SeedlingColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: SeedlingColors.morningDew.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (word.definition != null && word.definition!.isNotEmpty) ...[
                  _buildSectionTitle('DEFINITION'),
                  const SizedBox(height: 8),
                  Text(word.definition!, style: SeedlingTypography.body),
                  const SizedBox(height: 24),
                ],
                if (word.exampleSentence != null &&
                    word.exampleSentence!.isNotEmpty) ...[
                  Row(
                    children: [
                      _buildSectionTitle('IN CONTEXT'),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.volume_up_rounded,
                          color: SeedlingColors.seedlingGreen,
                          size: 20,
                        ),
                        onPressed: () => TtsService.instance.speak(
                          word.exampleSentence!,
                          word.targetLanguageCode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SeedlingColors.morningDew.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.exampleSentence!,
                          style: SeedlingTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        if (word.exampleSentencePronunciation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            word.exampleSentencePronunciation!,
                            style: SeedlingTypography.caption.copyWith(
                              color: SeedlingColors.morningDew,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: SeedlingTypography.caption.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: SeedlingColors.morningDew,
      ),
    );
  }

  Widget _buildLargeActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SeedlingColors.seedlingGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: SeedlingTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
