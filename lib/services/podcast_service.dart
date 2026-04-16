import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'podcast_handler.dart';
import 'tts_service.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import '../data/placeholder_sentences.dart';
import '../models/taxonomy.dart';

enum PodcastContentType { vocabulary, sentences, thematicVocabulary }

enum PodcastRepeatMode { off, one, all }

enum BinauralMode {
  off,
  alpha, // 10Hz - Relaxed focus
  beta,  // 20Hz - Intense concentration
}

class AmbientTheme {
  final String id;
  final String name;
  final String assetPath;
  final IconData icon;
  final Color color;

  const AmbientTheme({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.icon,
    required this.color,
  });
}

class PodcastService extends ChangeNotifier {
  static final PodcastService _instance = PodcastService._internal();
  static PodcastService get instance => _instance;

  PodcastHandler? _handler;
  bool _isInitializing = false;

  PodcastMode _currentMode = PodcastMode.focus;
  PodcastContentType _contentType = PodcastContentType.vocabulary;
  AmbientTheme? _currentTheme;
  bool _recallActive = false;
  bool _smartReview = false;
  int _dueCount = 0;
  BinauralMode _binauralMode = BinauralMode.off;
  
  // New thematic & configuration fields
  PodcastRepeatMode _repeatMode = PodcastRepeatMode.off;
  String? _selectedSubTheme;
  String? _selectedSentenceLevel; // beginner, intermediate, advanced, all
  bool _shuffleEnabled = false;
  List<String> _subThemeQueue = [];
  int _currentSubThemeIndex = -1;
  String? _lastNativeLang;
  String? _lastTargetLang;
  
  PodcastService._internal();

  final List<AmbientTheme> themes = [
    const AmbientTheme(
      id: 'garden',
      name: 'Rainy Garden',
      assetPath: 'assets/sfx/ambient_garden.mp3',
      icon: Icons.filter_vintage_rounded,
      color: Color(0xFF4CAF50),
    ),
    const AmbientTheme(
      id: 'sport',
      name: 'Energy Pulse',
      assetPath: 'assets/sfx/ambient_flow.mp3', // Reusing flow for now
      icon: Icons.bolt_rounded,
      color: Color(0xFFFFC107),
    ),
    const AmbientTheme(
      id: 'sleep',
      name: 'Deep Forest',
      assetPath: 'assets/sfx/ambient_garden.mp3', // Will add real white noise later
      icon: Icons.nightlight_round,
      color: Color(0xFF3F51B5),
    ),
  ];

  PodcastMode get currentMode => _currentMode;
  PodcastContentType get contentType => _contentType;
  AmbientTheme? get currentTheme => _currentTheme;
  bool get recallActive => _recallActive;
  bool get smartReview => _smartReview;
  int get dueCount => _dueCount;
  BinauralMode get binauralMode => _binauralMode;
  PodcastRepeatMode get repeatMode => _repeatMode;
  String? get selectedSubTheme => _selectedSubTheme;
  String? get selectedSentenceLevel => _selectedSentenceLevel;
  bool get shuffleEnabled => _shuffleEnabled;
  PodcastHandler? get handler => _handler;

  Future<void> initialize() async {
    if (_handler != null || _isInitializing) return;
    _isInitializing = true;

    _handler = await AudioService.init(
      builder: () => PodcastHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.seedling.podcast',
        androidNotificationChannelName: 'Seedling Podcast',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    // Set callback for sequence completion
    if (_handler != null) {
      _handler!.onSequenceCompleted = _onSessionPartCompleted;
    }

    _isInitializing = false;
    notifyListeners();
  }

  void _onSessionPartCompleted() {
    // If we're playing all thematic subthemes sequentially, move to next
    if (_contentType == PodcastContentType.thematicVocabulary && _selectedSubTheme == 'all') {
      _currentSubThemeIndex++;
      if (_currentSubThemeIndex < _subThemeQueue.length) {
         if (_lastNativeLang != null && _lastTargetLang != null) {
           _buildAndPlayPlaylist(_lastNativeLang!, _lastTargetLang!);
         }
      } else if (_repeatMode == PodcastRepeatMode.all) {
        // Restart the whole queue
        _currentSubThemeIndex = 0;
        if (_lastNativeLang != null && _lastTargetLang != null) {
           _buildAndPlayPlaylist(_lastNativeLang!, _lastTargetLang!);
        }
      }
    }
  }

  Future<void> startSession({
    required String nativeLang,
    required String targetLang,
    PodcastMode mode = PodcastMode.focus,
    AmbientTheme? theme,
    PodcastContentType? contentType,
    String? subTheme,
    String? sentenceLevel,
    bool shuffle = false,
  }) async {
    await initialize();
    _isInitializing = false;
    _currentMode = mode;
    _currentTheme = theme ?? (mode == PodcastMode.sport ? themes[1] : themes[0]);
    _contentType = contentType ?? _contentType;
    _selectedSubTheme = subTheme;
    _selectedSentenceLevel = sentenceLevel;
    _shuffleEnabled = shuffle;
    _lastNativeLang = nativeLang;
    _lastTargetLang = targetLang;

    // If 'Play All' for thematic is requested, we need to populate a queue in taxonomy order
    if (_contentType == PodcastContentType.thematicVocabulary && subTheme == 'all') {
      final db = DatabaseHelper();
      final dbSubThemes = await db.getUniqueSubThemes(nativeLang, targetLang);
      
      // Order by taxonomy
      final List<String> orderedQueue = [];
      final rootCategories = CategoryTaxonomy.getRootCategories();
      for (var root in rootCategories) {
        final subs = CategoryTaxonomy.getSubCategories(root.id);
        for (var sub in subs) {
          if (dbSubThemes.contains(sub.id)) {
            orderedQueue.add(sub.id);
          }
        }
      }
      
      // Add any unmatched themes from DB at the end
      for (var dbSt in dbSubThemes) {
        if (!orderedQueue.contains(dbSt)) {
          orderedQueue.add(dbSt);
        }
      }

      _subThemeQueue = orderedQueue;
      if (_shuffleEnabled) _subThemeQueue.shuffle();
      _currentSubThemeIndex = 0;
    } else {
      _subThemeQueue = [];
      _currentSubThemeIndex = -1;
    }

    await _buildAndPlayPlaylist(nativeLang, targetLang);
  }

  Future<void> _buildAndPlayPlaylist(String nativeLang, String targetLang) async {
    if (_handler == null) return;
    
    // Refresh due count
    final db = DatabaseHelper();
    _dueCount = await db.getDueCount(nativeLang, targetLang);

    // 1. Fetch Items
    final List<Map<String, String>> itemsToPlay = [];
    
    String currentSub = _selectedSubTheme ?? 'general';
    // If in sequential Play All mode, pick from queue
    if (_contentType == PodcastContentType.thematicVocabulary && _selectedSubTheme == 'all') {
      if (_currentSubThemeIndex < _subThemeQueue.length) {
        currentSub = _subThemeQueue[_currentSubThemeIndex];
      }
    }

    if (_contentType == PodcastContentType.vocabulary || _contentType == PodcastContentType.thematicVocabulary) {
      List<Word> words;
      if (_contentType == PodcastContentType.thematicVocabulary && currentSub != 'all') {
        words = await db.getWordsBySubTheme(lang: nativeLang, target: targetLang, subTheme: currentSub, limit: 30);
      } else if (_smartReview && _dueCount > 0) {
        words = await db.getSRSDueWords(nativeLang, targetLang, limit: 30);
      } else {
        words = await db.getWordsForLanguage(nativeLang, targetLang, limit: 30);
      }
      
      if (_shuffleEnabled) words.shuffle();
      
      for (var w in words) {
        itemsToPlay.add({'target': w.ttsWord, 'native': w.translation});
      }
    } else if (_contentType == PodcastContentType.sentences) {
      final sentences = await db.getSentencesForPodcast(
        lang: nativeLang, 
        target: targetLang, 
        level: _selectedSentenceLevel ?? 'all',
        limit: 20
      );

      if (sentences.isEmpty) {
        // Fallback to placeholder if still no data
        final fallback = PlaceholderSentences.getForLanguagePair(nativeLang, targetLang);
        for (var s in fallback) {
          itemsToPlay.add({'target': s.targetSentence, 'native': s.nativeSentence});
        }
      } else {
        for (var s in sentences) {
          itemsToPlay.add({
            'target': s['sentence'] as String, 
            'native': s['translation'] as String
          });
        }
      }
      
      if (_shuffleEnabled) itemsToPlay.shuffle();
    }
    
    if (itemsToPlay.isEmpty) return;

    // 2. Prepare Playlist
    final audioSource = ConcatenatingAudioSource(children: []);
    final tempDir = await getTemporaryDirectory();
    final podcastDir = Directory('${tempDir.path}/podcast_cache');
    if (!podcastDir.existsSync()) podcastDir.createSync(recursive: true);

    // 3. Start Background Generation & Early Playback
    _generatePlaylistInBackground(itemsToPlay, audioSource, podcastDir, targetLang, nativeLang);
    
    // Configure Handler immediately so UI can show "Ready"
    await _handler!.setPlaylist(audioSource);
    
    // The rest of the setup (Repeat mode, themes) happens after we start
    await _handler!.setMode(_currentMode);
    await _handler!.setAmbientSource(_currentTheme!.assetPath.replaceFirst('assets/', ''));
    await _handler!.setAmbientVolume(0.15);
    
    // We don't call _handler!.play() here; we wait for at least a few items
    // or we can let the UI trigger it. Actually, the user expect it to start.
  }

  Future<void> _generatePlaylistInBackground(
    List<Map<String, String>> items, 
    ConcatenatingAudioSource audioSource, 
    Directory podcastDir,
    String targetLang,
    String nativeLang,
  ) async {
    bool hasStartedPlayback = false;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      
      // Use content-addressable naming to reuse files across sessions
      final String targetText = item['target']!;
      final String nativeText = item['native']!;
      
      // Simple sanitization for filename
      final String targetSafe = targetText.replaceAll(RegExp(r'[^\w\s]'), '');
      final String targetTrunc = targetSafe.length > 20 ? targetSafe.substring(0, 20) : targetSafe;
      final String targetId = '${targetLang}_${targetText.hashCode}_${targetTrunc.trim()}.wav';

      final String nativeSafe = nativeText.replaceAll(RegExp(r'[^\w\s]'), '');
      final String nativeTrunc = nativeSafe.length > 20 ? nativeSafe.substring(0, 20) : nativeSafe;
      final String nativeId = '${nativeLang}_${nativeText.hashCode}_${nativeTrunc.trim()}.wav';
      
      final targetPath = '${podcastDir.path}/$targetId';
      final nativePath = '${podcastDir.path}/$nativeId';

      try {
        // synthesizeToFile checks if file exists internally? 
        // No, let's check here to be fast.
        if (!File(targetPath).existsSync()) {
          await TtsService.instance.synthesizeToFile(targetText, targetLang, targetPath);
        }
        if (!File(nativePath).existsSync()) {
          await TtsService.instance.synthesizeToFile(nativeText, nativeLang, nativePath);
        }

        final targetItem = AudioSource.uri(Uri.file(targetPath), tag: MediaItem(
          id: 'item_target_${targetText.hashCode}',
          title: targetText,
          artist: 'Seedling AI',
          album: 'Vocabulary',
        ));
        
        final nativeItem = AudioSource.uri(Uri.file(nativePath), tag: MediaItem(
          id: 'item_native_${nativeText.hashCode}',
          title: nativeText,
          artist: 'Seedling AI',
          album: 'Translation',
        ));

        audioSource.add(targetItem);
        
        if (_recallActive) {
          final pauseSec = _contentType == PodcastContentType.sentences ? 5 : 2;
          final silencePath = await _getSilenceFile(Duration(seconds: pauseSec));
          audioSource.add(AudioSource.uri(Uri.file(silencePath), tag: const MediaItem(
            id: 'pause_recall',
            title: 'Recall Pause',
          )));
        }

        audioSource.add(nativeItem);

        // Breathing space
        final spaceSec = _currentMode == PodcastMode.sleep ? 3 : 1;
        final spacePath = await _getSilenceFile(Duration(seconds: spaceSec));
        audioSource.add(AudioSource.uri(Uri.file(spacePath), tag: const MediaItem(
          id: 'pause_breath',
          title: 'Breathing Space',
        )));

        // Trigger playback after first 2 items are ready
        if (!hasStartedPlayback && audioSource.length >= 4) { // 2 items + pauses
           hasStartedPlayback = true;
           await _handler!.play();
           notifyListeners();
        }
        
        // Update UI queue
        final mediaItems = audioSource.children
            .map((source) => (source as UriAudioSource).tag as MediaItem)
            .toList();
        await _handler!.updateQueue(mediaItems);

      } catch (e) {
        debugPrint('PodcastService: Background generation error at item $i: $e');
      }
    }
    
    // Ensure we start even if playlist is short
    if (!hasStartedPlayback && audioSource.length > 0) {
      await _handler!.play();
      notifyListeners();
    }
  }

  Future<void> setMode(PodcastMode mode) async {
    _currentMode = mode;
    if (_handler != null) {
      await _handler!.setMode(mode);
      // Update theme to default for mode
      _currentTheme = mode == PodcastMode.sport ? themes[1] : (mode == PodcastMode.sleep ? themes[2] : themes[0]);
      await _handler!.setAmbientSource(_currentTheme!.assetPath.replaceFirst('assets/', ''));
      
      // We might need to regenerate the playlist for speed/pause changes
      // For now, let's just update the internal state
      notifyListeners();
    }
  }

  Future<String> _getSilenceFile(Duration duration) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/podcast_cache/silence_${duration.inMilliseconds}.wav');
    if (file.existsSync()) return file.path;

    // Simple 8000Hz 8-bit Mono WAV Header for silence
    final sampleRate = 8000;
    final int numSamples = (sampleRate * duration.inMilliseconds / 1000).toInt();
    final int dataSize = numSamples;
    final fileSize = 36 + dataSize;

    final header = BytesBuilder();
    header.add([0x52, 0x49, 0x46, 0x46]); // RIFF
    header.addByte(fileSize & 0xFF);
    header.addByte((fileSize >> 8) & 0xFF);
    header.addByte((fileSize >> 16) & 0xFF);
    header.addByte((fileSize >> 24) & 0xFF);
    header.add([0x57, 0x41, 0x56, 0x45]); // WAVE
    header.add([0x66, 0x6d, 0x74, 0x20]); // fmt
    header.add([0x10, 0x00, 0x00, 0x00]); // length
    header.add([0x01, 0x00]); // type (PCM)
    header.add([0x01, 0x00]); // channels (Mono)
    header.add([0x40, 0x1f, 0x00, 0x00]); // 8000 rate
    header.add([0x40, 0x1f, 0x00, 0x00]); // 8000 bytes/sec
    header.add([0x01, 0x00]); // block align
    header.add([0x08, 0x00]); // 8 bits
    header.add([0x64, 0x61, 0x74, 0x61]); // data
    header.addByte(dataSize & 0xFF);
    header.addByte((dataSize >> 8) & 0xFF);
    header.addByte((dataSize >> 16) & 0xFF);
    header.addByte((dataSize >> 24) & 0xFF);
    
    // Data: All 128 (center for 8-bit PCM)
    header.add(Uint8List(dataSize)..fillRange(0, dataSize, 128));

    await file.writeAsBytes(header.toBytes());
    return file.path;
  }

  Future<void> stop() async {
    await _handler?.stop();
    notifyListeners();
  }

  Future<void> setTheme(AmbientTheme theme) async {
    _currentTheme = theme;
    notifyListeners();
    if (_handler != null) {
      // Use fallback if file might be missing (for placeholders)
      String path = theme.assetPath.replaceFirst('assets/', '');
      if (theme.id != 'garden') {
         // Placeholder logic: if not garden, check if file exists or fallback
         // For now, we'll just try to set it and let handler catch error
      }
      await _handler!.setAmbientSource(path);
    }
  }

  void setRecall(bool active) {
    _recallActive = active;
    notifyListeners();
  }

  Future<void> setRepeatMode(PodcastRepeatMode mode) async {
    _repeatMode = mode;
    notifyListeners();
    if (_handler != null) {
      await _handler!.setRepeatMode(AudioServiceRepeatMode.none);
    }
  }

  void setShuffle(bool enabled) {
    _shuffleEnabled = enabled;
    notifyListeners();
  }

  Future<void> setSentenceLevel(String level, {required String nativeLang, required String targetLang}) async {
    if (_selectedSentenceLevel == level) return;
    _selectedSentenceLevel = level;
    notifyListeners();
    if (_contentType == PodcastContentType.sentences && _handler?.playbackState.value.playing == true) {
      await startSession(nativeLang: nativeLang, targetLang: targetLang, mode: _currentMode);
    }
  }

  Future<void> setContentType(PodcastContentType type, {required String nativeLang, required String targetLang}) async {
    if (_contentType == type) return;
    _contentType = type;
    notifyListeners();
    // Restart session with new content type if already playing
    if (_handler?.playbackState.value.playing == true) {
      await startSession(nativeLang: nativeLang, targetLang: targetLang, mode: _currentMode);
    }
  }

  Future<void> setSmartReview(bool enabled, {required String nativeLang, required String targetLang}) async {
    if (_smartReview == enabled) return;
    _smartReview = enabled;
    notifyListeners();
    
    // Update due count immediately
    _dueCount = await DatabaseHelper().getDueCount(nativeLang, targetLang);
    
    // Restart session if already playing to apply SRS prioritization
    if (_handler?.playbackState.value.playing == true) {
      await startSession(nativeLang: nativeLang, targetLang: targetLang, mode: _currentMode);
    }
  }

  Future<void> setBinauralMode(BinauralMode mode) async {
    if (_binauralMode == mode) return;
    _binauralMode = mode;
    notifyListeners();
    await _updateBinauralLayer();
  }

  Future<void> _updateBinauralLayer() async {
    if (_handler == null) return;
    
    if (_binauralMode == BinauralMode.off) {
      await _handler!.stopBinaural();
      return;
    }

    final double beatFreq = _binauralMode == BinauralMode.alpha ? 10.0 : 20.0;
    final path = await _generateBinauralFile(beatFreq);
    await _handler!.setBinauralSource(path);
    await _handler!.setBinauralVolume(0.08); // Subtle enough to be effective but not annoying
  }

  Future<String> _generateBinauralFile(double beatFreq) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/podcast_cache/binaural_${beatFreq.toInt()}hz.wav');
    if (file.existsSync()) return file.path;

    const int sampleRate = 44100;
    const double baseFreq = 200.0;
    const double durationSec = 2.0;
    final int numSamples = (sampleRate * durationSec).toInt();
    
    final header = BytesBuilder();
    // RIFF Header
    final int dataSize = numSamples * 4; // 2 channels * 2 bytes (16-bit)
    final int fileSize = 36 + dataSize;
    
    header.add([0x52, 0x49, 0x46, 0x46]); // RIFF
    header.addByte(fileSize & 0xFF);
    header.addByte((fileSize >> 8) & 0xFF);
    header.addByte((fileSize >> 16) & 0xFF);
    header.addByte((fileSize >> 24) & 0xFF);
    header.add([0x57, 0x41, 0x56, 0x45]); // WAVE
    header.add([0x66, 0x6d, 0x74, 0x20]); // fmt
    header.add([0x10, 0x00, 0x00, 0x00]); // length
    header.add([0x01, 0x00]); // type (PCM)
    header.add([0x02, 0x00]); // channels (Stereo)
    header.add([0x44, 0xAC, 0x00, 0x00]); // 44100 rate
    header.add([0x10, 0xB1, 0x02, 0x00]); // 176400 bytes/sec (44100 * 4)
    header.add([0x04, 0x00]); // block align (4 bytes)
    header.add([0x10, 0x00]); // 16 bits
    header.add([0x64, 0x61, 0x74, 0x61]); // data
    header.addByte(dataSize & 0xFF);
    header.addByte((dataSize >> 8) & 0xFF);
    header.addByte((dataSize >> 16) & 0xFF);
    header.addByte((dataSize >> 24) & 0xFF);

    final leftFreq = baseFreq;
    final rightFreq = baseFreq + beatFreq;
    
    final data = ByteData(dataSize);
    for (int i = 0; i < numSamples; i++) {
       final t = i / sampleRate;
       // Left channel
       final lSample = (sin(2 * pi * leftFreq * t) * 32767 * 0.5).toInt();
       data.setInt16(i * 4, lSample, Endian.little);
       // Right channel
       final rSample = (sin(2 * pi * rightFreq * t) * 32767 * 0.5).toInt();
       data.setInt16(i * 4 + 2, rSample, Endian.little);
    }
    header.add(data.buffer.asUint8List());

    await file.writeAsBytes(header.toBytes());
    return file.path;
  }

  Future<void> refreshDueCount(String nativeLang, String targetLang) async {
    _dueCount = await DatabaseHelper().getDueCount(nativeLang, targetLang);
    notifyListeners();
  }
}
