import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../models/word.dart';
import '../../../services/vocabulary_service.dart';
import '../../../providers/app_providers.dart';

class MemoryPatchScreen extends ConsumerStatefulWidget {
  final List<String> conceptIds;
  final String theme;

  const MemoryPatchScreen({
    super.key,
    required this.conceptIds,
    required this.theme,
  });

  @override
  ConsumerState<MemoryPatchScreen> createState() => _MemoryPatchScreenState();
}

class _MemoryPatchScreenState extends ConsumerState<MemoryPatchScreen> {
  late Future<List<Word>> _missedWordsFuture;

  @override
  void initState() {
    super.initState();
    _missedWordsFuture = _loadMissedWords();
  }

  Future<List<Word>> _loadMissedWords() async {
    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);

    final List<Word> words = [];
    for (final id in widget.conceptIds) {
      final word = await VocabularyService.fetchOnlineWord(
        id,
        targetLang,
        nativeLang,
      );
      if (word != null) words.add(word);
    }
    return words;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070F06),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    SeedlingColors.hibiscusRed.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                Expanded(
                  child: FutureBuilder<List<Word>>(
                    future: _missedWordsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: SeedlingColors.hibiscusRed,
                          ),
                        );
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return _buildEmptyState();
                      }

                      final words = snapshot.data!;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: words.length,
                        itemBuilder: (context, index) =>
                            _buildReviewCard(words[index]),
                      );
                    },
                  ),
                ),
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.psychology_rounded,
                  color: SeedlingColors.hibiscusRed,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEMORY PATCH',
                      style: SeedlingTypography.heading1.copyWith(fontSize: 28),
                    ),
                    Text(
                      'Let\'s fix those missed plants from ${widget.theme}',
                      style: SeedlingTypography.caption.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Word word) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                word.targetLanguageCode.toUpperCase(),
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.autumnGold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Icon(Icons.volume_up_rounded, color: Colors.white38),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            word.word,
            style: SeedlingTypography.heading2.copyWith(
              color: Colors.white,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            word.pronunciation ?? '',
            style: SeedlingTypography.body.copyWith(
              color: Colors.white38,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.translate_rounded,
                  color: SeedlingColors.seedlingGreen,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    word.translation,
                    style: SeedlingTypography.heading3.copyWith(
                      color: SeedlingColors.seedlingGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (word.exampleSentence != null) ...[
            const SizedBox(height: 24),
            Text(
              'EXAMPLE',
              style: SeedlingTypography.caption.copyWith(
                color: Colors.white30,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              word.exampleSentence!,
              style: SeedlingTypography.body.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: SeedlingColors.seedlingGreen,
            size: 64,
          ),
          const SizedBox(height: 24),
          Text('All plants are healthy!', style: SeedlingTypography.heading2),
          Text(
            'You didn\'t miss anything in this session.',
            style: SeedlingTypography.body.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: SeedlingColors.seedlingGreen,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: Text(
          'GARDEN IS READY',
          style: SeedlingTypography.heading3.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
