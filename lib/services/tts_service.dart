import 'package:flutter_tts/flutter_tts.dart';
import 'audio_service.dart';
import 'package:flutter/foundation.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  static TtsService get instance => _instance;

  late FlutterTts _flutterTts;
  bool _isReady = false;

  TtsService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();

    // Configure ultra high-end parameters for pedagogical clarity
    await _flutterTts.setVolume(1.0);

    // Slow down speech slightly for language learners (1.0 is default, 0.85 is clearer)
    await _flutterTts.setSpeechRate(0.85);

    // Very slight pitch lift for a brighter, more engaging AI voice
    await _flutterTts.setPitch(1.05);

    // Ensure asynchronous TTS completion tracking
    await _flutterTts.awaitSpeakCompletion(true);

    // Prioritize high-quality local voices if available
    if (!kIsWeb) {
      // In a full production app, you might iterate through await _flutterTts.getVoices
      // and explicitly select a neural/enhanced voice variant.
      // FlutterTts naturally picks the system active voice.
    }

    _isReady = true;
  }

  /// Maps a generic 2-letter language code or locale string to a precise TTS locale.
  /// If no mapping exists, it returns the input as-is, letting the OS resolve it.
  String _mapLanguageCodeToLocale(String languageCode) {
    if (languageCode.length >= 5)
      return languageCode; // Already a locale: e.g. "pt-BR"

    final code = languageCode.toLowerCase().trim();

    // Explicit mapping for pedagogical clarity and common system-voice consistency
    const mapping = {
      'es': 'es-ES', // Spanish
      'ja': 'ja-JP', // Japanese
      'fr': 'fr-FR', // French
      'de': 'de-DE', // German
      'it': 'it-IT', // Italian
      'ar': 'ar-SA', // Arabic
      'zh': 'zh-CN', // Chinese
      'ru': 'ru-RU', // Russian
      'pt': 'pt-PT', // Portuguese (Europe)
      'hi': 'hi-IN', // Hindi
      'ko': 'ko-KR', // Korean
      'tr': 'tr-TR', // Turkish
      'en': 'en-US', // English
      'vl':
          'en-GB', // Vanilla Language (Internal Seedling standard maps to high-quality EN)
    };

    return mapping[code] ?? code;
  }

  /// Speaks the text using ultra-high-end pedagogical settings
  Future<void> speak(String text, String languageCode) async {
    try {
      if (!_isReady) await _initTts();

      final locale = _mapLanguageCodeToLocale(languageCode);

      // Strict pedagogical check: only attempt speech if system confirms support
      final availability = await _flutterTts.isLanguageAvailable(locale);

      if (availability == null ||
          (availability is int && availability < 0) ||
          (availability is bool && availability == false)) {
        debugPrint(
          'TTS: Language $locale is not available on this device. Skipping speech.',
        );
        return;
      }

      // Hot-swap language context
      await _flutterTts.setLanguage(locale);

      // Duck ambient music during speech
      AudioService.instance.setAmbientDucking(true);

      // The awaitSpeakCompletion(true) setting ensures this awaits until audio finishes
      await _flutterTts.speak(text);

      // Restore ambient music volume
      AudioService.instance.setAmbientDucking(false);
    } catch (e) {
      debugPrint('TTS Error: $e');
      // Ensure we always unduck music if we fail
      AudioService.instance.setAmbientDucking(false);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
