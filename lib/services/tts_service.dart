import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart';

const String _kGhOwner = 'amoslanguages-commits';
const String _kGhRepo  = 'seedling';
const String _kGhTag   = 'tts-models-v1';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  static TtsService get instance => _instance;

  static const Set<String> _supportedOfflineModels = {
    'aka', 'amh', 'ara', 'asm', 'azb', 'ben', 'bul', 'cat', 'ceb', 'ces', 
    'cmn-script_simplified', 'cym', 'deu', 'div', 'ell', 'eng', 'eng-gb', 'eng-us', 
    'eus', 'fas', 'fin', 'fra', 'ful', 'grn', 'guj', 'hat', 'hau', 'heb', 
    'hin', 'hun', 'ind', 'isl', 'ita', 'jav', 'kan', 'kat', 'kaz', 'khm', 
    'kin', 'kir', 'kmr-script_latin', 'kor', 'lao', 'lav', 'ltz', 'lug', 
    'mad', 'mal', 'mar', 'mdy', 'mlg', 'mon', 'mya', 'nld', 'nob', 'npi', 
    'nya', 'onb', 'orm', 'ory', 'pan', 'pcm', 'pol', 'por', 'por-br', 'por-pt', 
    'quz', 'ron', 'rus', 'sld', 'slk', 'slv', 'sna', 'som', 'spa', 'spa-es', 
    'spa-mx', 'sqi', 'sri', 'sun', 'swe', 'swh', 'tam', 'tat', 'tel', 'tgk', 
    'tgl', 'tha', 'tir', 'tuk', 'tur', 'uig', 'ukr', 'urd', 'uzb', 'vie', 
    'wlo', 'yor', 'zlm'
  };

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  sherpa.OfflineTts? _offlineTts;
  bool _isReady = false;
  
  /// Exposes the live download progress from 0.0 to 1.0. Null if no download is active.
  final ValueNotifier<double?> downloadProgress = ValueNotifier(null);

  /// Notifies when speech is actively playing.
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  /// Simple FIFO cache for synthesized audio (PCM data as List<double>).
  /// Max items: 10 to prevent memory bloat (~1MB total).
  final Map<String, List<double>> _audioCache = {};
  final List<String> _cacheHistory = [];
  static const int _maxCacheSize = 10;
  
  String _currentLang = '';

  TtsService._internal() {
    _initFlutterTts();
  }

  Future<void> _initFlutterTts() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  /// Maps internal locale variants to broad MMS ISO-639-3 codes
  String _getMmsCode(String languageCode) {
    // We only merge dialects where the pronunciation nuances are identical or acceptable.
    final Map<String, String> variants = {
      // Chinese relies on MMS for both scripts
      'zh-CN': 'cmn-script_simplified', 
      'zh-TW': 'cmn-script_simplified', 
      'zh': 'cmn-script_simplified',

      // Regional variants explicitly using loaded MMS/Piper models
      'en-US': 'eng-us',
      'en-GB': 'eng-gb',
      'es-MX': 'spa-mx',
      'es-ES': 'spa-es',
      'pt-BR': 'por-br',
      'pt-PT': 'por-pt',
      
      // Generic Core Redirects
      'en': 'eng',
      'es': 'spa',
      'pt': 'por',
      'fr': 'fra',
      'de': 'deu',
      'it': 'ita',

      // Auto-mapped from Supported ISO 639-1/3
      'ak': 'aka', 'sq': 'sqi', 'am': 'amh', 'ar': 'ara', 'ar-SA': 'ara', 
      'as': 'asm', 'az': 'azb', 'eu': 'eus', 'bn': 'ben', 'bg': 'bul', 
      'my': 'mya', 'ca': 'cat', 'ceb': 'ceb', 'ny': 'nya', 'cs': 'ces', 
      'nl': 'nld', 'fil': 'tgl', 'fi': 'fin', 'ff': 'ful', 'ka': 'kat', 
      'el': 'ell', 'gn': 'grn', 'gu': 'guj', 'ht': 'hat', 'ha': 'hau', 
      'he': 'heb', 'hi': 'hin', 'hi-IN': 'hin', 'hu': 'hun', 'is': 'isl', 
      'id': 'ind', 'id-ID': 'ind', 'jv': 'jav', 'kn': 'kan', 'kk': 'kaz', 
      'km': 'khm', 'rw': 'kin', 'ko': 'kor', 'ko-KR': 'kor', 
      'ku': 'kmr-script_latin', 'ky': 'kir', 'lo': 'lao', 'lv': 'lav', 
      'lg': 'lug', 'lb': 'ltz', 'mad': 'mad', 'mg': 'mlg', 'ms': 'zlm', 
      'ml': 'mal', 'mr': 'mar', 'mn': 'mon', 'ne': 'npi', 'pcm': 'pcm', 
      'nb-NO': 'nob', 'or': 'ory', 'fa': 'fas', 'pl': 'pol', 'pa': 'pan', 
      'qu': 'quz', 'ro': 'ron', 'ru': 'rus', 'ru-RU': 'rus', 'sn': 'sna', 
      'si': 'sri', 'sk': 'slk', 'sl': 'slv', 'so': 'som', 'su': 'sun', 
      'sw': 'swh', 'sv': 'swe', 'tg': 'tgk', 'ta': 'tam', 'tt': 'tat', 
      'te': 'tel', 'th': 'tha', 'ti': 'tir', 'tr': 'tur', 'tk': 'tuk', 
      'uk': 'ukr', 'ur': 'urd', 'ug': 'uig', 'uz': 'uzb', 'vi': 'vie', 
      'cy': 'cym', 'wo': 'wlo', 'yo': 'yor', 'om': 'orm',
    };

    if (variants.containsKey(languageCode)) {
      return variants[languageCode]!;
    }
    
    // Unmapped/regional codes
    return languageCode;
  }

  /// Ensures that the TTS engine is initialized with the correct language model.
  /// Supports both MMS format (tokens.txt) and Piper format (model.onnx.json).
  Future<void> ensureModelReady(String languageCode) async {
    final mmsCode = _getMmsCode(languageCode);
    
    // ── Fail Fast for Unsupported Languages ───────────────────────────────────
    if (!_supportedOfflineModels.contains(mmsCode)) {
      throw Exception('Language $mmsCode is not supported by our offline models (Fallback triggered).');
    }

    if (_isReady && _currentLang == mmsCode && _offlineTts != null) return;

    try {
      sherpa.initBindings();
      final docsDir = await getApplicationDocumentsDirectory();
      final langDir = Directory('${docsDir.path}/tts/$mmsCode');

      if (!langDir.existsSync()) {
        langDir.createSync(recursive: true);
      }

      final modelPath  = '${langDir.path}/model.onnx';
      final tokensPath = '${langDir.path}/tokens.txt';       // MMS format
      final piperJson  = '${langDir.path}/model.onnx.json';  // Piper format

      // ── Step 1: ensure files are on disk (from assets or backend) ────────
      final hasModel  = File(modelPath).existsSync();
      final hasMms    = File(tokensPath).existsSync();
      final hasPiper  = File(piperJson).existsSync();

      if (!hasModel || (!hasMms && !hasPiper)) {
        debugPrint('TTS: Models missing locally for $mmsCode. Downloading from GitHub Releases...');
        try {
          await _downloadGitHubRelease(mmsCode, '${docsDir.path}/tts');
          debugPrint('TTS: Successfully downloaded and extracted models for $mmsCode.');
        } catch (e) {
          debugPrint('TTS: GitHub Release Download Failed for $mmsCode - $e');
          throw Exception('Download failed');
        }
      }

      // ── Step 2: detect format and initialise sherpa-onnx ─────────────────
      final isPiper = File(piperJson).existsSync();
      debugPrint('TTS: Loading $mmsCode in ${isPiper ? "Piper" : "MMS"} mode.');

      final vitsConfig = isPiper
          ? sherpa.OfflineTtsVitsModelConfig(
              model: modelPath,
              // Piper models embed token/phoneme info in the ONNX graph itself;
              // sherpa-onnx reads the companion JSON for language/speaker metadata.
              tokens: piperJson,
              noiseScale: 0.667,
              noiseScaleW: 0.8,
              lengthScale: 1.0,
            )
          : sherpa.OfflineTtsVitsModelConfig(
              model: modelPath,
              tokens: tokensPath,
              noiseScale: 0.667,
              noiseScaleW: 0.8,
              lengthScale: 1.0,
            );

      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: vitsConfig,
          numThreads: 1,
          debug: false,
          provider: 'cpu',
        ),
      );

      _offlineTts?.free();
      _offlineTts = sherpa.OfflineTts(config);
      _currentLang = mmsCode;
      _isReady = true;
    } catch (e) {
      debugPrint('TTS Init Error for $mmsCode: $e');
      _isReady = false;
      throw Exception('Failed to initialize MMS for $mmsCode');
    }
  }

  /// Downloads a language zip from GitHub Releases and extracts all files.
  /// Supports HTTP Range resuming and automatic retries.
  Future<void> _downloadGitHubRelease(String mmsCode, String destDir) async {
    final url = Uri.parse(
      'https://github.com/$_kGhOwner/$_kGhRepo/releases/download/$_kGhTag/$mmsCode.zip',
    );
    
    final prefs = await SharedPreferences.getInstance();
    final tempDir = await getTemporaryDirectory();
    final tempZipPath = '${tempDir.path}/$mmsCode.zip.part';
    final tempZipFile = File(tempZipPath);
    
    int bytesReceived = 0;
    if (tempZipFile.existsSync()) {
      bytesReceived = tempZipFile.lengthSync();
      debugPrint('TTS: Found partial download for $mmsCode at $bytesReceived bytes.');
    }

    int retryCount = 0;
    const int maxRetries = 3;
    bool success = false;

    while (retryCount < maxRetries && !success) {
      try {
        final client = http.Client();
        final request = http.Request('GET', url);
        
        if (bytesReceived > 0) {
          request.headers['Range'] = 'bytes=$bytesReceived-';
        }

        // Extended connection timeout for slow GitHub/S3 handshakes
        final response = await client.send(request).timeout(const Duration(seconds: 30));

        // If server doesn't support Range or file changed, restart from 0
        bool isPartial = response.statusCode == 206;
        if (response.statusCode == 200) {
          isPartial = false;
          bytesReceived = 0;
          if (tempZipFile.existsSync()) tempZipFile.deleteSync();
        } else if (response.statusCode != 206 && response.statusCode != 200) {
          throw Exception('HTTP Error: ${response.statusCode}');
        }

        final totalBytes = (response.contentLength ?? 0) + bytesReceived;
        final sink = tempZipFile.openWrite(mode: isPartial ? FileMode.append : FileMode.write);
        
        downloadProgress.value = totalBytes > 0 ? bytesReceived / totalBytes : 0.0;

        await for (final chunk in response.stream.timeout(const Duration(seconds: 20))) {
          sink.add(chunk);
          bytesReceived += chunk.length;
          if (totalBytes > 0) {
            downloadProgress.value = bytesReceived / totalBytes;
          }
        }

        await sink.flush();
        await sink.close();
        success = true;
        
      } catch (e) {
        retryCount++;
        debugPrint('TTS: Download attempt $retryCount failed for $mmsCode: $e');
        if (retryCount >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: 2 * retryCount)); // Exponential backoff
      }
    }

    downloadProgress.value = 1.0;

    // Extract
    try {
      final finalZipPath = tempZipPath.replaceFirst('.part', '');
      await tempZipFile.rename(finalZipPath);
      
      await compute(_extractZipInIsolate, {
        'zipPath': finalZipPath,
        'destDir': destDir,
      });
      
      await File(finalZipPath).delete();
      // Clear persistence on success
      await prefs.remove('tts_last_download_$mmsCode');
    } catch (e) {
      debugPrint('TTS: Extraction failed for $mmsCode: $e');
      if (tempZipFile.existsSync()) tempZipFile.deleteSync();
      rethrow;
    } finally {
      downloadProgress.value = null;
    }
  }

  /// Pre-synthesizes text in the background and stores it in a memory cache.
  Future<void> preSynthesize(String text, String languageCode) async {
    if (text.isEmpty) return;
    
    final cacheKey = '${languageCode}::$text';
    if (_audioCache.containsKey(cacheKey)) return;

    try {
      // Ensure model is ready before synthesizing
      await ensureModelReady(languageCode);
      
      if (!_isReady || _offlineTts == null) return;

      debugPrint('TTS: Pre-synthesizing "$text" ($languageCode)...');
      
      final audio = _offlineTts!.generate(text: text, speed: 0.85);
      if (audio.samples.isNotEmpty) {
        _addToCache(cacheKey, audio.samples);
      }
    } catch (e) {
      debugPrint('TTS: Pre-synthesis failed: $e');
    }
  }

  void _addToCache(String key, List<double> samples) {
    if (_audioCache.length >= _maxCacheSize) {
      final oldest = _cacheHistory.removeAt(0);
      _audioCache.remove(oldest);
    }
    _audioCache[key] = samples;
    _cacheHistory.add(key);
  }

  /// Deletes local model files that are no longer associated with any course.
  Future<void> cleanOrphanedModels(List<String> activeMmsCodes) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final ttsBaseDir = Directory('${appDocDir.path}/tts');
      
      if (!await ttsBaseDir.exists()) return;

      final entities = await ttsBaseDir.list().toList();
      for (var entity in entities) {
        if (entity is Directory) {
          final dirName = entity.path.split(Platform.pathSeparator).last;
          if (!activeMmsCodes.contains(dirName)) {
            debugPrint('TTS: 🧹 Cleaning up orphaned model: $dirName');
            await entity.delete(recursive: true);
          }
        }
      }
    } catch (e) {
      debugPrint('TTS: Cleanup error: $e');
    }
  }

  /// Synthesizes text to a WAV file at the specified path.
  Future<void> synthesizeToFile(String text, String languageCode, String filePath) async {
    if (text.isEmpty) return;

    try {
      List<double> samples;
      final cacheKey = '${languageCode}::$text';

      if (_audioCache.containsKey(cacheKey)) {
        samples = _audioCache[cacheKey]!;
      } else {
        try {
          await ensureModelReady(languageCode);
        } catch (_) {
          // Model unsupported or failed to download
        }

        if (!_isReady || _offlineTts == null) {
          final success = await _downloadOnlineTtsFallback(text, languageCode, filePath);
          if (success) return; // Online mp3 downloaded successfully, no need for wav encode
          
          throw Exception('Batch synthesis failed for both offline and online fallback.');
        }

        // Use appropriate speed based on global setting or default
        final audio = _offlineTts!.generate(text: text, speed: 0.85);
        samples = audio.samples;
        if (samples.isEmpty) throw Exception('TTS produced empty samples.');
        _addToCache(cacheKey, samples);
      }

      final success = sherpa.writeWave(
        filename: filePath,
        samples: Float32List.fromList(samples),
        sampleRate: 16000,
      );

      if (!success) throw Exception('Failed to write wave file to $filePath');
    } catch (e) {
      debugPrint('TTS SynthesizeToFile Error: $e');
      rethrow;
    }
  }

  /// Speaks the text using Sherpa-ONNX offline engine.
  Future<void> speak(String text, String languageCode) async {
    if (text.isEmpty) return;

    final cacheKey = '${languageCode}::$text';
    isSpeaking.value = true;

    try {
      List<double> samples;

      // 1. Check Cache
      if (_audioCache.containsKey(cacheKey)) {
        debugPrint('TTS: Playing from cache: "$text"');
        samples = _audioCache[cacheKey]!;
      } else {
        // 2. Synthesize if not cached
        await ensureModelReady(languageCode);
        
        if (!_isReady || _offlineTts == null) {
          throw Exception('MMS Engine not ready for $languageCode.');
        }

        final audio = _offlineTts!.generate(text: text, speed: 0.85);
        samples = audio.samples;

        if (samples.isEmpty) throw Exception('MMS Engine created empty audio buffer.');
        
        _addToCache(cacheKey, samples);
      }

      // Save to temp file for playback
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/tts_output.wav';

      final success = sherpa.writeWave(
        filename: tempPath,
        samples: Float32List.fromList(samples),
        sampleRate: 16000, // MMS/VITS standard
      );

      if (!success) throw Exception('Failed to write wave file.');

      await AudioService.instance.setAmbientDucking(true);
      await _player.setSource(DeviceFileSource(tempPath));
      final onComplete = _player.onPlayerComplete.first;
      await _player.resume();
      await onComplete;
      await AudioService.instance.setAmbientDucking(false);

    } catch (e) {
      debugPrint('TTS Error ($e). Falling back to OS Native for $languageCode');
      try {
        await AudioService.instance.setAmbientDucking(true);
        await _flutterTts.setLanguage(languageCode);
        await _flutterTts.speak(text);
        _flutterTts.setCompletionHandler(() {
          AudioService.instance.setAmbientDucking(false);
          isSpeaking.value = false;
        });
        // For fallback, we return early as setCompletionHandler handles state
        return;
      } catch (fErr) {
        debugPrint('TTS Fallback Error: $fErr');
        await AudioService.instance.setAmbientDucking(false);
      }
    } finally {
      isSpeaking.value = false;
    }
  }

  /// Exposed helper for consumers
  String mmsCodeFor(String isoCode) => _getMmsCode(isoCode);

  Future<void> stop() async {
    try {
      if (_player.state == PlayerState.playing) {
        await _player.stop();
      }
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS Stop Error: $e');
    }
  }
  Future<bool> _downloadOnlineTtsFallback(String text, String langCode, String filePath) async {
    try {
      final url = Uri.parse(
        'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$langCode&q=${Uri.encodeComponent(text)}'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (e) {
      debugPrint('Online TTS Fallback Failed: $e');
    }
    return false;
  }
}

/// Helper function to extract zip files in a background Isolate.
Future<void> _extractZipInIsolate(Map<String, String> params) async {
  final zipPath = params['zipPath']!;
  final destDir = params['destDir']!;
  
  final bytes = File(zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  
  for (final file in archive) {
    if (file.isFile) {
      final outPath = '$destDir/${file.name}';
      final outputStream = OutputFileStream(outPath);
      file.writeContent(outputStream);
      await outputStream.close();
    }
  }
}
