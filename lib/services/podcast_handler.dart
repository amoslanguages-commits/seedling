import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

/// PodcastMode determines the rhythm, ambient default, and TTS speed.
enum PodcastMode {
  sport, // Fast, minimal pauses, upbeat lo-fi
  focus, // Standard, optional recall pause, rainy garden
  sleep, // Slow, long intervals, white noise
}

/// A background audio handler for the Seedling Podcast feature.
/// Manages two players:
/// 1. [_voicePlayer] for the TTS word/sentence sequence.
/// 2. [_ambientPlayer] for the looping background SFX.
class PodcastHandler extends BaseAudioHandler {
  final _voicePlayer = AudioPlayer();
  final _ambientPlayer = AudioPlayer();
  final _binauralPlayer = AudioPlayer();

  AudioPlayer get voicePlayer => _voicePlayer;

  PodcastMode _currentMode = PodcastMode.focus;
  bool _recallModeEnabled = false;
  Duration _recallPauseDuration = const Duration(seconds: 2);
  double _baseAmbientVolume = 0.15;
  
  // Link to service for notification on completion
  Function? onSequenceCompleted;

  PodcastHandler() {
    // Initial configuration
    _ambientPlayer.setLoopMode(LoopMode.one);
    _binauralPlayer.setLoopMode(LoopMode.one);
    
    // Broadcast state changes
    _voicePlayer.playbackEventStream.listen(_broadcastState);
    _voicePlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (onSequenceCompleted != null) {
          onSequenceCompleted!();
        } else {
          stop();
        }
      }
    });

    // Integrated Audio Ducking
    // We lower ambient volume when voice is playing, but restore it during silence/pauses
    _voicePlayer.sequenceStateStream.listen((state) {
      if (state == null || state.sequence.isEmpty) return;
      
      final currentIndex = state.currentIndex;
      final currentSource = state.sequence[currentIndex];
      final tag = currentSource.tag;

      if (tag is MediaItem) {
        final isVoice = tag.id.startsWith('item_');
        if (isVoice) {
           _ambientPlayer.setVolume(_baseAmbientVolume * 0.3); // Ducked
        } else {
           // Silence/Pause: Swell the ambient sound
           _ambientPlayer.setVolume(_baseAmbientVolume);
        }
      }
    });
  }

  // ── Mode Control ──────────────────────────────────────────────

  Future<void> setMode(PodcastMode mode) async {
    _currentMode = mode;
    // Update ambient default based on mode if not overridden by user
    // (Logic will be refined in PodcastService)
  }

  Future<void> setRecallMode(bool enabled, {int pauseSeconds = 2}) async {
    _recallModeEnabled = enabled;
    _recallPauseDuration = Duration(seconds: pauseSeconds);
  }

  // ── Ambient Management ────────────────────────────────────────

  Future<void> setAmbientSource(String assetPath) async {
    try {
      // Smooth fade out
      if (_ambientPlayer.playing) {
        await _ambientPlayer.setVolume(0);
      }
      
      await _ambientPlayer.setAsset(assetPath);
      
      if (playbackState.value.playing) {
        _ambientPlayer.play();
        // Smooth fade in back to base volume
        await _ambientPlayer.setVolume(_baseAmbientVolume);
      } else {
        await _ambientPlayer.setVolume(_baseAmbientVolume);
      }
    } catch (e) {
      print('PodcastHandler: Error setting ambient: $e');
    }
  }

  Future<void> setAmbientVolume(double volume) async {
    _baseAmbientVolume = volume;
    await _ambientPlayer.setVolume(volume);
  }

  // ── Binaural Management ───────────────────────────────────────

  Future<void> setBinauralSource(String filePath) async {
    try {
      await _binauralPlayer.setFilePath(filePath);
      await _binauralPlayer.setLoopMode(LoopMode.all);
      if (playbackState.value.playing) {
        _binauralPlayer.play();
      }
    } catch (e) {
      print('PodcastHandler: Error setting binaural: $e');
    }
  }

  Future<void> stopBinaural() async {
    await _binauralPlayer.stop();
  }

  Future<void> setBinauralVolume(double volume) async {
    await _binauralPlayer.setVolume(volume);
  }

  // ── Voice Management ──────────────────────────────────────────

  Future<void> setPlaylist(ConcatenatingAudioSource source) async {
    await _voicePlayer.setAudioSource(source);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = {
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
    }[repeatMode] ?? LoopMode.off;
    await _voicePlayer.setLoopMode(loopMode);
  }

  Future<void> updateQueue(List<MediaItem> items) async {
    queue.add(items);
  }

  Stream<Duration> get positionStream => _voicePlayer.positionStream;

  // ── AudioHandler Implementation ───────────────────────────────

  @override
  Future<void> play() async {
    await _voicePlayer.play();
    await _ambientPlayer.play();
    if (_binauralPlayer.audioSource != null) {
      await _binauralPlayer.play();
    }
  }

  @override
  Future<void> pause() async {
    await _voicePlayer.pause();
    await _ambientPlayer.pause();
    await _binauralPlayer.pause();
  }

  @override
  Future<void> stop() async {
    await _voicePlayer.stop();
    await _ambientPlayer.stop();
    await _binauralPlayer.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() => _voicePlayer.seekToNext();

  @override
  Future<void> skipToPrevious() => _voicePlayer.seekToPrevious();

  @override
  Future<void> seek(Duration position) => _voicePlayer.seek(position);

  /// Broadcasts the current state to the system (lock screen / notification)
  void _broadcastState(PlaybackEvent event) {
    final playing = _voicePlayer.playing;
    final queueIndex = _voicePlayer.currentIndex;
    
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_voicePlayer.processingState]!,
      playing: playing,
      updatePosition: _voicePlayer.position,
      bufferedPosition: _voicePlayer.bufferedPosition,
      speed: _voicePlayer.speed,
      queueIndex: queueIndex,
    ));
  }
}
