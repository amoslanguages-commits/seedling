import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Catalogue of every SFX in the app.
enum SFX {
  // ── Quiz events ─────────────────────────────────────────────
  correctAnswer,      // Used for streaks 0-2
  wrongAnswer,        // Dissonant low thud
  streakBonus,        // Every 3rd correct in a row
  engraveSuccess,     // EngraveRoot typing mastery passed

  // ── Session events ─────────────────────────────────────────
  quizStart,          // Session begins
  sessionComplete,    // Full session completed
  levelUp,            // Mastery level gained

  // ── Word & planting events ─────────────────────────────────
  wordPlanted,        // Word planted in garden
  wordReveal,         // Word shown during planting
  sparklePing,        // First correct on a brand-new word
  plantGrow,          // Plant growing animation

  // ── Navigation & UI events ─────────────────────────────────
  buttonTap,          // Generic button press
  navTap,             // Tab/navigation switch
  splashReveal,       // Logo/splash reveal
  onboardingComplete, // Onboarding finished
}

/// Escalating correct-answer chord tiers — mapped from streak count.
///  Tier 1 (0-2 streak):   warm C4 triad
///  Tier 2 (3-5 streak):   bright C5 triad
///  Tier 3 (6-8 streak):   brilliant C5+C6 quad
///  Tier 4 (9+ streak):    sparkling 5-note chord
const _escalatingCorrect = [
  'sfx/correct_1.wav',
  'sfx/correct_2.wav',
  'sfx/correct_3.wav',
  'sfx/correct_4.wav',
];

/// AudioService — ultra-smart, premium-quality audio engine.
///
/// Features:
///  • One warm-up player per SFX for zero-latency playback
///  • Dynamic escalating correct-answer SFX based on streak
///  • Haptic feedback paired with every key interaction
///  • Ambient garden layer with smart ducking when SFX fires
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  // ── Pools ────────────────────────────────────────────────────
  final Map<SFX, AudioPlayer> _pool = {};
  final List<AudioPlayer> _correctPool =
      List.generate(4, (_) => AudioPlayer());
  late final AudioPlayer _ambientPlayer;
  late final AudioPlayer _flowPlayer;

  bool _muted = false;
  double _volume = 0.85;
  final double _ambientVolume = 0.12; // very quiet under-layer
  final double _flowVolume = 0.35; // intensely louder upbeat mix

  bool _ambientRunning = false;
  bool _ambientEnabled = true; // user can toggle from Settings
  
  int _globalStreak = 0;
  bool _flowRunning = false;

  static const _assetMap = {
    SFX.correctAnswer:      'sfx/correct_2.wav', // default (overridden by streak)
    SFX.wrongAnswer:        'sfx/wrong.wav',
    SFX.streakBonus:        'sfx/streak_bonus.wav',
    SFX.engraveSuccess:     'sfx/engrave_success.wav',
    SFX.quizStart:          'sfx/quiz_start.wav',
    SFX.sessionComplete:    'sfx/session_complete.wav',
    SFX.levelUp:            'sfx/level_up.wav',
    SFX.wordPlanted:        'sfx/word_planted.wav',
    SFX.wordReveal:         'sfx/word_reveal.wav',
    SFX.sparklePing:        'sfx/sparkle_ping.wav',
    SFX.plantGrow:          'sfx/plant_grow.wav',
    SFX.buttonTap:          'sfx/button_tap.wav',
    SFX.navTap:             'sfx/nav_tap.wav',
    SFX.splashReveal:       'sfx/splash_reveal.wav',
    SFX.onboardingComplete: 'sfx/onboarding_complete.wav',
  };

  bool get muted => _muted;
  double get volume => _volume;
  bool get ambientEnabled => _ambientEnabled;
  void setAmbientEnabled(bool enabled) {
    _ambientEnabled = enabled;
    if (!enabled && _ambientRunning) {
      stopAmbient();
      _stopFlowState();
    }
  }

  // ── Initialization ───────────────────────────────────────────

  Future<void> initialize() async {
    // Warm up standard SFX pool
    for (final entry in _assetMap.entries) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(_volume);
      _pool[entry.key] = player;
    }

    // Warm up escalating correct-answer pool
    for (int i = 0; i < _correctPool.length; i++) {
      await _correctPool[i].setReleaseMode(ReleaseMode.stop);
      await _correctPool[i].setVolume(_volume);
    }

    // Set up ambient player
    _ambientPlayer = AudioPlayer();
    await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    await _ambientPlayer.setVolume(0); // starts silent
    
    // Set up flow state player
    _flowPlayer = AudioPlayer();
    await _flowPlayer.setReleaseMode(ReleaseMode.loop);
    await _flowPlayer.setVolume(0);
    await _flowPlayer.setPlaybackRate(1.25); // Faster, more intense upbeat tempo

    debugPrint('[AudioService] initialized ${_pool.length} SFX channels + ambient + flow.');
  }

  // ── Ambient garden layer ─────────────────────────────────────

  /// Start the ambient garden layer — call when a quiz session begins.
  Future<void> startAmbient() async {
    if (_muted || _ambientRunning || !_ambientEnabled) {
      return;
    }
    _ambientRunning = true;
    await _ambientPlayer.play(AssetSource('sfx/ambient_garden.mp3'));
    // Fade in gently over 2 seconds
    _ambientFadeTo(_ambientVolume, const Duration(seconds: 2));
  }

  /// Stop the ambient layer — call when session ends.
  Future<void> stopAmbient() async {
    resetFlowState();
    if (!_ambientRunning) {
      return;
    }
    _ambientRunning = false;
    await _ambientFadeTo(0, const Duration(milliseconds: 800));
    await Future.delayed(const Duration(milliseconds: 900));
    await _ambientPlayer.stop();
  }

  Future<void> _ambientFadeTo(double target, Duration dur) async {
    const steps = 20;
    final current = _ambientPlayer.volume;
    final stepMs = dur.inMilliseconds ~/ steps;
    final delta = (target - current) / steps;
    for (int i = 0; i < steps; i++) {
      final v = (current + delta * (i + 1)).clamp(0.0, 1.0);
      await _ambientPlayer.setVolume(v);
      await Future.delayed(Duration(milliseconds: stepMs));
    }
  }

  Future<void> _flowFadeTo(double target, Duration dur) async {
    const steps = 20;
    final current = _flowPlayer.volume;
    final stepMs = dur.inMilliseconds ~/ steps;
    final delta = (target - current) / steps;
    for (int i = 0; i < steps; i++) {
      final v = (current + delta * (i + 1)).clamp(0.0, 1.0);
      await _flowPlayer.setVolume(v);
      await Future.delayed(Duration(milliseconds: stepMs));
    }
  }
  
  // ── Dynamic Flow State Audio ──────────────────────────────────
  
  Future<void> _startFlowState() async {
    if (_muted || _flowRunning || !_ambientEnabled) return;
    _flowRunning = true;
    
    // Play the flow track (reusing ambient but faster/louder)
    await _flowPlayer.play(AssetSource('sfx/ambient_garden.mp3'));
    
    // Duck ambient to zero, ramp flow volume up
    _ambientFadeTo(0, const Duration(seconds: 1));
    _flowFadeTo(_flowVolume, const Duration(seconds: 1));
  }

  Future<void> _stopFlowState() async {
    if (!_flowRunning) return;
    _flowRunning = false;
    
    // Abrupt stop (record scratch effect)
    await _flowPlayer.stop();
    await _flowPlayer.setVolume(0);
    
    // Restore ambient gently
    if (_ambientRunning && !_muted && _ambientEnabled) {
      _ambientFadeTo(_ambientVolume, const Duration(seconds: 2));
    }
  }

  void resetFlowState() {
     _globalStreak = 0;
     _stopFlowState();
  }

  /// Duck ambient while a short SFX plays, then restore.
  Future<void> _duckAmbient() async {
    if (!_ambientRunning || _flowRunning) {
      return;
    }
    await _ambientPlayer.setVolume(_ambientVolume * 0.25);
    await Future.delayed(const Duration(milliseconds: 600));
    if (_ambientRunning) {
      await _ambientPlayer.setVolume(_ambientVolume);
    }
  }

  /// Duck ambient for TTS playback (longer — TTS can be 1-3 s).
  /// Call before TtsService.speak and it will fade back automatically.
  Future<void> duckForTts() async {
    if (!_ambientRunning) return;
    await setAmbientDucking(true);
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (_ambientRunning) setAmbientDucking(false);
    });
  }

  /// Manually control ambient ducking state.
  Future<void> setAmbientDucking(bool ducked) async {
    if (!_ambientRunning) return;
    final target = ducked ? _ambientVolume * 0.15 : _ambientVolume;
    await _ambientFadeTo(target, const Duration(milliseconds: 400));
  }

  // ── Core play API ────────────────────────────────────────────

  /// Play a standard SFX. Optionally ducks ambient.
  Future<void> play(SFX sfx) async {
    if (_muted) {
      return;
    }
    
    if (sfx == SFX.wrongAnswer) {
      _globalStreak = 0;
      _stopFlowState();
    }
    
    final player = _pool[sfx];
    if (player == null) {
      return;
    }
    try {
      await player.stop();
      await player.play(AssetSource(_assetMap[sfx]!));
      if (!_flowRunning) _duckAmbient(); // fire-and-forget, no await
    } catch (e) {
      debugPrint('[AudioService] Failed to play $sfx: $e');
    }
  }

  /// Play an escalating correct-answer sound based on current streak.
  /// Streak tiers: 0-2 → tier 1, 3-5 → tier 2, 6-8 → tier 3, 9+ → tier 4
  /// Each tier also raises playback rate ~12% (~half octave) for pitch escalation.
  Future<void> playCorrect({int? streak}) async {
    if (_muted) {
      return;
    }
    
    _globalStreak++;
    if (_globalStreak >= 5 && !_flowRunning) {
      _startFlowState();
    }
    
    // Determine which tier to use based on internal streak to guarantee escalating audio
    final effectiveStreak = _globalStreak;
    final tier = effectiveStreak < 3 ? 0 : effectiveStreak < 6 ? 1 : effectiveStreak < 9 ? 2 : 3;
    final player = _correctPool[tier];
    // Pitch escalation: +12% per tier simulates half-octave shift
    final pitchRate = 1.0 + (tier * 0.12);
    try {
      await player.stop();
      await player.setPlaybackRate(pitchRate);
      await player.play(AssetSource(_escalatingCorrect[tier]));
      if (!_flowRunning) _duckAmbient();
    } catch (e) {
      debugPrint('[AudioService] Failed to play correct tier $tier: $e');
    }
  }

  // ── Haptic feedback ──────────────────────────────────────────

  /// Paired haptic patterns for every key interaction.
  static Future<void> haptic(HapticType type) async {
    switch (type) {
      case HapticType.correct:
        // Double light pulse = satisfaction
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 80));
        await HapticFeedback.lightImpact();
      case HapticType.wrong:
        // Heavy single = error
        await HapticFeedback.heavyImpact();
      case HapticType.tap:
        // Selection = soft UI feedback
        await HapticFeedback.selectionClick();
      case HapticType.plant:
        // Medium = satisfying "plant" confirmation
        await HapticFeedback.mediumImpact();
      case HapticType.levelUp:
        // Triple light = celebration
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 60));
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 60));
        await HapticFeedback.lightImpact();
      case HapticType.sessionComplete:
        // Heavy + delay + medium = grand finish
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.mediumImpact();
    }
  }

  // ── Volume & mute control ────────────────────────────────────

  void setMuted(bool muted) {
    _muted = muted;
    if (muted) {
      _ambientPlayer.setVolume(0);
      _flowPlayer.setVolume(0);
    } else if (_ambientRunning) {
      if (_flowRunning) {
        _flowPlayer.setVolume(_flowVolume);
      } else {
        _ambientPlayer.setVolume(_ambientVolume);
      }
    }
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    for (final p in _pool.values) {
      await p.setVolume(_volume);
    }
    for (final p in _correctPool) {
      await p.setVolume(_volume);
    }
  }

  Future<void> dispose() async {
    for (final p in _pool.values) {
      await p.dispose();
    }
    for (final p in _correctPool) {
      await p.dispose();
    }
    await _ambientPlayer.dispose();
    await _flowPlayer.dispose();
    _pool.clear();
  }
}

/// Semantic haptic types matching app interactions.
enum HapticType {
  correct,
  wrong,
  tap,
  plant,
  levelUp,
  sessionComplete,
}
