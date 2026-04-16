import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/podcast_service.dart';
import '../../database/database_helper.dart';
import '../../core/colors.dart';
import '../../widgets/backgrounds.dart';
import '../../models/taxonomy.dart';
import 'podcast_player_screen.dart';

class PodcastBrowserScreen extends ConsumerStatefulWidget {
  const PodcastBrowserScreen({super.key});

  @override
  ConsumerState<PodcastBrowserScreen> createState() => _PodcastBrowserScreenState();
}

class _PodcastBrowserScreenState extends ConsumerState<PodcastBrowserScreen> {
  bool _shuffle = false;
  String _selectedSentenceLevel = 'all';

  @override
  Widget build(BuildContext context) {
    final targetLang = ref.watch(currentLanguageProvider);
    final nativeLang = ref.watch(nativeLanguageProvider);

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: Stack(
        children: [
          const FloatingLeavesBackground(child: SizedBox.expand()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildHeroSection(),
                      const SizedBox(height: 32),
                      _buildGlobalControls(),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Vocabulary Themes', Icons.grid_view_rounded),
                      const SizedBox(height: 16),
                      _buildPlayAllCard(nativeLang, targetLang),
                      const SizedBox(height: 16),
                      _buildThematicGrid(nativeLang, targetLang),
                      const SizedBox(height: 40),
                      _buildSectionHeader('Sentence Learning', Icons.auto_awesome_motion_rounded),
                      const SizedBox(height: 16),
                      _buildSentenceSection(nativeLang, targetLang),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'Podcast Library',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SeedlingColors.seedlingGreen.withValues(alpha: 0.2),
            SeedlingColors.morningDew.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Immersive Audio',
                  style: TextStyle(
                    color: SeedlingColors.sunlight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Master your language by just listening.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalControls() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassToggle(
            'Shuffle Playback',
            _shuffle,
            Icons.shuffle_rounded,
            (val) => setState(() => _shuffle = val),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassToggle(String label, bool value, IconData icon, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: value ? SeedlingColors.seedlingGreen.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value ? SeedlingColors.seedlingGreen : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: value ? Colors.white : Colors.white54, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: SeedlingColors.morningDew,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: SeedlingColors.morningDew, size: 20),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayAllCard(String native, String target) {
    return GestureDetector(
      onTap: () => _launchPodcast(
        contentType: PodcastContentType.thematicVocabulary,
        subTheme: 'all',
        native: native,
        target: target,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: SeedlingColors.morningDew, size: 40),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Play All Themes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Continuous sequential playback',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
            Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildThematicGrid(String native, String target) {
    return FutureBuilder<List<String>>(
      future: DatabaseHelper().getUniqueSubThemes(native, target),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final dbSubThemes = snapshot.data!;
        if (dbSubThemes.isEmpty) return const Text('No themes found yet.', style: TextStyle(color: Colors.white54));

        final rootCategories = CategoryTaxonomy.getRootCategories();
        final List<Widget> sections = [];

        // Track which subthemes from DB we've matched to taxonomy
        final Set<String> matchedSubThemes = {};

        for (var root in rootCategories) {
          final subCategories = CategoryTaxonomy.getSubCategories(root.id);
          final availableInDb = subCategories.where((sc) => dbSubThemes.contains(sc.id)).toList();

          if (availableInDb.isNotEmpty) {
            sections.add(_buildCategoryGroup(root, availableInDb, native, target));
            sections.add(const SizedBox(height: 24));
            matchedSubThemes.addAll(availableInDb.map((sc) => sc.id));
          }
        }

        // Handle subthemes in DB that are NOT in taxonomy (fallback)
        final unmatched = dbSubThemes.where((st) => !matchedSubThemes.contains(st)).toList();
        if (unmatched.isNotEmpty) {
          sections.add(_buildSectionHeader('Discovery & Extras', Icons.explore_rounded));
          sections.add(const SizedBox(height: 12));
          sections.add(_buildRawSubThemeGrid(unmatched, native, target));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections,
        );
      },
    );
  }

  Widget _buildCategoryGroup(SemanticCategory root, List<SemanticCategory> subs, String native, String target) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(root.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              root.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: subs.length,
          itemBuilder: (context, index) {
            final cat = subs[index];
            return _buildThemeCard(cat.name, cat.id, cat.icon, cat.color, native, target);
          },
        ),
      ],
    );
  }

  Widget _buildRawSubThemeGrid(List<String> themes, String native, String target) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: themes.length,
      itemBuilder: (context, index) {
        final theme = themes[index];
        return _buildThemeCard(theme, theme, '🌱', SeedlingColors.seedlingGreen, native, target);
      },
    );
  }

  Widget _buildThemeCard(String displayName, String id, String emoji, Color accentColor, String native, String target) {
    return GestureDetector(
      onTap: () => _launchPodcast(
        contentType: PodcastContentType.thematicVocabulary,
        subTheme: id,
        native: native,
        target: target,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSentenceSection(String native, String target) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              _buildLevelTab('all'),
              _buildLevelTab('beginner'),
              _buildLevelTab('intermediate'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _launchPodcast(
            contentType: PodcastContentType.sentences,
            sentenceLevel: _selectedSentenceLevel,
            native: native,
            target: target,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded),
              SizedBox(width: 8),
              Text('START SENTENCE SESSION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelTab(String level) {
    final isSelected = _selectedSentenceLevel == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSentenceLevel = level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white10 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            level.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  void _launchPodcast({
    required PodcastContentType contentType,
    String? subTheme,
    String? sentenceLevel,
    required String native,
    required String target,
  }) {
    // Reset service first
    ref.read(podcastServiceProvider).startSession(
      nativeLang: native,
      targetLang: target,
      contentType: contentType,
      subTheme: subTheme,
      sentenceLevel: sentenceLevel,
      shuffle: _shuffle,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PodcastPlayerScreen()),
    );
  }
}
