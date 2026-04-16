import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/course_provider.dart';
import '../../services/podcast_handler.dart';
import '../../services/audio_service.dart' as sfx;
import '../../services/podcast_service.dart';
import '../../core/colors.dart';
import '../../widgets/backgrounds.dart';

class PodcastPlayerScreen extends ConsumerStatefulWidget {
  const PodcastPlayerScreen({super.key});

  @override
  ConsumerState<PodcastPlayerScreen> createState() => _PodcastPlayerScreenState();
}

class _PodcastPlayerScreenState extends ConsumerState<PodcastPlayerScreen> {
  @override
  void initState() {
    super.initState();
    // Start session when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPodcast();
    });
  }
  void _startPodcast() {
    final service = ref.read(podcastServiceProvider);
    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);

    if (service.handler == null) {
      service.startSession(
        nativeLang: nativeLang,
        targetLang: targetLang,
        mode: service.currentMode,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final podcastService = ref.watch(podcastServiceProvider);
    final targetLang = ref.watch(currentLanguageProvider);
    final nativeLang = ref.watch(nativeLanguageProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Dynamic Background Based on Mode
          _buildBackground(podcastService.currentMode),

          // 2. Glassmorphic Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, podcastService),
                _buildContentTypeSelector(podcastService, nativeLang, targetLang),
                _buildSRSToggle(podcastService, nativeLang, targetLang),
                _buildModeSelector(podcastService),
                _buildBinauralSelector(podcastService),
                const Spacer(),
                _buildMainDisplay(ref),
                const Spacer(),
                _buildControls(podcastService),
                _buildFooter(podcastService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(PodcastMode mode) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: switch (mode) {
        PodcastMode.sport => Container(
            key: const ValueKey('sport'),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A237E), Color(0xFFAD1457)],
              ),
            ),
          ),
        PodcastMode.sleep => Container(
            key: const ValueKey('sleep'),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF000428), Color(0xFF004e92)],
              ),
            ),
          ),
        PodcastMode.focus => FloatingLeavesBackground(
            key: const ValueKey('focus'),
            child: const SizedBox.expand(),
          ),
      },
    );
  }

  Widget _buildHeader(BuildContext context, PodcastService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.expand_more_rounded, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded, color: SeedlingColors.sunlight, size: 16),
                const SizedBox(width: 8),
                Text(
                  'PODCAST PRO',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildContentTypeSelector(PodcastService service, String nativeLang, String targetLang) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypeTab(
              label: 'VOCABULARY',
              isSelected: service.contentType == PodcastContentType.vocabulary,
              onTap: () => service.setContentType(PodcastContentType.vocabulary, nativeLang: nativeLang, targetLang: targetLang),
            ),
            _TypeTab(
              label: 'SENTENCES',
              isSelected: service.contentType == PodcastContentType.sentences,
              onTap: () => service.setContentType(PodcastContentType.sentences, nativeLang: nativeLang, targetLang: targetLang),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSRSToggle(PodcastService service, String nativeLang, String targetLang) {
    final bool isSmart = service.smartReview;
    final int count = service.dueCount;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () => service.setSmartReview(!isSmart, nativeLang: nativeLang, targetLang: targetLang),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSmart 
              ? SeedlingColors.seedlingGreen.withValues(alpha: 0.2) 
              : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSmart 
                ? SeedlingColors.seedlingGreen.withValues(alpha: 0.5) 
                : Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: isSmart ? [
              BoxShadow(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ] : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSmart ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                size: 14,
                color: isSmart ? SeedlingColors.morningDew : Colors.white54,
              ),
              const SizedBox(width: 8),
              Text(
                'SMART REVIEW',
                style: TextStyle(
                  color: isSmart ? Colors.white : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSmart ? SeedlingColors.seedlingGreen : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(PodcastService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ModeTab(
            label: 'SPORT',
            icon: Icons.bolt_rounded,
            isSelected: service.currentMode == PodcastMode.sport,
            onTap: () => service.setMode(PodcastMode.sport),
          ),
          const SizedBox(width: 8),
          _ModeTab(
            label: 'FOCUS',
            icon: Icons.psychology_rounded,
            isSelected: service.currentMode == PodcastMode.focus,
            onTap: () => service.setMode(PodcastMode.focus),
          ),
          const SizedBox(width: 8),
          _ModeTab(
            label: 'SLEEP',
            icon: Icons.nightlight_round,
            isSelected: service.currentMode == PodcastMode.sleep,
            onTap: () => service.setMode(PodcastMode.sleep),
          ),
        ],
      ),
    );
  }

  Widget _buildBinauralSelector(PodcastService service) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'FOCUS BOOSTER',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.headphones_rounded, color: SeedlingColors.sunlight, size: 14),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildBinauralChip(
                'OFF',
                BinauralMode.off,
                service,
                Icons.block_rounded,
              ),
              const SizedBox(width: 8),
              _buildBinauralChip(
                'DEEP FOCUS',
                BinauralMode.alpha,
                service,
                Icons.psychology_rounded,
              ),
              const SizedBox(width: 8),
              _buildBinauralChip(
                'PEAK STUDY',
                BinauralMode.beta,
                service,
                Icons.bolt_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBinauralChip(String label, BinauralMode mode, PodcastService service, IconData icon) {
    final isSelected = service.binauralMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => service.setBinauralMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : Colors.white54,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainDisplay(WidgetRef ref) {
    final service = ref.watch(podcastServiceProvider);
    final handler = service.handler;
    
    if (handler == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              // Rotating / Pulsing Artwork
              _buildArtwork(item, handler),
              const SizedBox(height: 32),
              SizedBox(
                height: 180,
                child: _TranscriptView(handler: handler),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtwork(MediaItem? item, PodcastHandler handler) {
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: playing 
                ? SeedlingColors.seedlingGreen.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1), 
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Consumer(
              builder: (context, ref, _) {
                final mode = ref.watch(podcastServiceProvider).currentMode;
                return _PulsingIcon(
                  isSport: mode == PodcastMode.sport,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SeedlingColors.seedlingGreen.withValues(alpha: playing ? 0.9 : 0.4),
                          SeedlingColors.morningDew.withValues(alpha: playing ? 0.6 : 0.2),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        mode == PodcastMode.sleep ? Icons.nightlight_round : Icons.eco_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }


  Widget _buildTrackInfo(PodcastHandler handler) {
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        return Column(
          children: [
            Text(
              item?.title ?? 'Ready to Learn',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              item?.artist ?? 'Seedling AI',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSentenceLevelSelector(PodcastService service, WidgetRef ref) {
    final levels = ['all', 'beginner', 'intermediate', 'advanced'];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8,
        children: levels.map((level) {
          final isSelected = service.selectedSentenceLevel == level || (level == 'all' && service.selectedSentenceLevel == null);
          return ChoiceChip(
            label: Text(level.toUpperCase(), style: const TextStyle(fontSize: 10)),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                 sfx.AudioService.haptic(sfx.HapticType.selection).ignore();
                 sfx.AudioService.instance.play(sfx.SFX.buttonTap);
                 final activeCourse = ref.read(courseProvider).activeCourse;
                 service.setSentenceLevel(level, 
                    nativeLang: activeCourse?.nativeLanguage.code ?? 'en', 
                    targetLang: activeCourse?.targetLanguage.code ?? 'de'
                 );
              }
            },
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            selectedColor: SeedlingColors.morningDew.withValues(alpha: 0.3),
            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        }).toList(),
      ),
    );
  }
  Widget _buildControls(PodcastService service) {
    final handler = service.handler;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded, 
              color: service.shuffleEnabled ? SeedlingColors.morningDew : Colors.white54
            ),
            onPressed: () {
              sfx.AudioService.haptic(sfx.HapticType.selection).ignore();
              sfx.AudioService.instance.play(sfx.SFX.buttonTap);
              service.setShuffle(!service.shuffleEnabled);
            },
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40),
            onPressed: () {
              sfx.AudioService.haptic(sfx.HapticType.tap).ignore();
              sfx.AudioService.instance.play(sfx.SFX.navTap);
              handler?.skipToPrevious();
            },
          ),
          if (handler != null)
            _buildPlayButton(handler)
          else
            const CircularProgressIndicator(color: Colors.white),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40),
            onPressed: () {
              sfx.AudioService.haptic(sfx.HapticType.tap).ignore();
              sfx.AudioService.instance.play(sfx.SFX.navTap);
              handler?.skipToNext();
            },
          ),
          _buildRepeatButton(service),
        ],
      ),
    );
  }

  Widget _buildRepeatButton(PodcastService service) {
    IconData icon;
    Color color;
    
    switch (service.repeatMode) {
      case PodcastRepeatMode.off:
        icon = Icons.repeat_rounded;
        color = Colors.white54;
        break;
      case PodcastRepeatMode.one:
        icon = Icons.repeat_one_rounded;
        color = SeedlingColors.morningDew;
        break;
      case PodcastRepeatMode.all:
        icon = Icons.repeat_rounded;
        color = SeedlingColors.morningDew;
        break;
    }

    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: () {
        sfx.AudioService.haptic(sfx.HapticType.selection).ignore();
        sfx.AudioService.instance.play(sfx.SFX.buttonTap);
        final next = switch (service.repeatMode) {
          PodcastRepeatMode.off => PodcastRepeatMode.all,
          PodcastRepeatMode.all => PodcastRepeatMode.one,
          PodcastRepeatMode.one => PodcastRepeatMode.off,
        };
        service.setRepeatMode(next);
      },
    );
  }

  Widget _buildPlayButton(PodcastHandler handler) {
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return GestureDetector(
          onTap: () {
            sfx.AudioService.haptic(sfx.HapticType.tap).ignore();
            sfx.AudioService.instance.play(sfx.SFX.buttonTap);
            playing ? handler.pause() : handler.play();
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded, 
              size: 48, 
              color: Colors.black,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(PodcastService service) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.multitrack_audio_rounded, color: Colors.white54),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ambient Track',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              Text(
                service.currentTheme?.name ?? 'Natural Rain',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _showAmbientPicker(context, service),
            child: const Text('Change', style: TextStyle(color: SeedlingColors.morningDew)),
          ),
        ],
      ),
    );
  }

  void _showAmbientPicker(BuildContext context, PodcastService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ambient Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set the atmosphere for your session',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: service.themes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final theme = service.themes[index];
                  final isSelected = service.currentTheme?.id == theme.id;
                  return GestureDetector(
                    onTap: () {
                      service.setTheme(theme);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected 
                          ? theme.color.withValues(alpha: 0.15) 
                          : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? theme.color : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: theme.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(theme.icon, color: theme.color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  theme.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (theme.id != 'garden')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Experimental • Loop active',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptView extends StatefulWidget {
  final PodcastHandler handler;
  const _TranscriptView({required this.handler});

  @override
  State<_TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<_TranscriptView> {
  final ScrollController _scrollController = ScrollController();
  int _lastKnownIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (index < 0 || !_scrollController.hasClients) return;
    final offset = (index * 40.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MediaItem>>(
      stream: widget.handler.queue,
      builder: (context, queueSnapshot) {
        final items = queueSnapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(
            child: Text('Building Transcript...', style: TextStyle(color: Colors.white54, fontSize: 18)),
          );
        }

        return StreamBuilder<MediaItem?>(
          stream: widget.handler.mediaItem,
          builder: (context, mediaSnapshot) {
            final currentItem = mediaSnapshot.data;
            final currentIndex = currentItem != null ? items.indexWhere((i) => i.id == currentItem.id) : -1;
            
            if (currentIndex != -1 && currentIndex != _lastKnownIndex) {
              _lastKnownIndex = currentIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToIndex(currentIndex));
            }

            return ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 60),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = index == currentIndex;
                  final isPast = index < currentIndex;

                  if (item.title == 'Breathing Space' || item.title == 'Recall Pause') {
                    return const SizedBox(height: 16);
                  }

                  return GestureDetector(
                    onTap: () {
                       sfx.AudioService.instance.play(sfx.SFX.pencilScratch);
                       sfx.AudioService.haptic(sfx.HapticType.medium);
                       widget.handler.pause();
                       _showWordDetail(context, item);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: isActive 
                        ? _KaraokeLine(
                            text: item.title,
                            handler: widget.handler,
                          )
                        : Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isPast ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.3),
                              fontSize: 18,
                              fontWeight: isPast ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showWordDetail(BuildContext context, MediaItem item) {
     sfx.AudioService.instance.play(sfx.SFX.shimmerIn);
     showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(item.album ?? 'Transcript Detail', style: const TextStyle(color: Colors.white54, fontSize: 12)),
               const SizedBox(height: 8),
               Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               const Text('Example translation or specific word hint could appear here, integrated seamlessly with the spaced repetition data.', style: TextStyle(color: Colors.white70, fontSize: 14)),
               const SizedBox(height: 24),
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: SeedlingColors.seedlingGreen,
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   ),
                   onPressed: () {
                     Navigator.of(context).pop();
                     widget.handler.play();
                   },
                   child: const Text('Resume Podcast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                 ),
               ),
               const SizedBox(height: 24),
            ],
          ),
        ),
     );
  }
}

class _KaraokeLine extends StatelessWidget {
  final String text;
  final PodcastHandler handler;

  const _KaraokeLine({required this.text, required this.handler});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: handler.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        final duration = handler.voicePlayer.duration ?? const Duration(seconds: 2); // fallback
        
        final progress = duration.inMilliseconds == 0 
            ? 0.0 
            : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

        final words = text.split(' ');
        final activeWordIndex = (words.length * progress).floor();

        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: List.generate(words.length, (index) {
              final isHighlighted = index <= activeWordIndex;
              return TextSpan(
                text: '${words[index]} ',
                style: TextStyle(
                  color: isHighlighted ? SeedlingColors.seedlingGreen : Colors.white.withValues(alpha: 0.3),
                  fontSize: 24,
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
class _PulsingIcon extends StatefulWidget {
  final Widget child;
  final bool isSport;

  const _PulsingIcon({required this.child, required this.isSport});

  @override
  _PulsingIconState createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isSport) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSport && !oldWidget.isSport) {
      _controller.repeat(reverse: true);
    } else if (!widget.isSport && oldWidget.isSport) {
      _controller.stop();
      _controller.animateTo(0, duration: const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.isSport ? _animation : const AlwaysStoppedAnimation(1.0),
      child: widget.child,
    );
  }
}
