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

  /// Maps a generic 2-letter language code to a precise TTS locale
  String _mapLanguageCodeToLocale(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'es':
        return 'es-ES';
      case 'ja':
        return 'ja-JP';
      case 'fr':
        return 'fr-FR';
      case 'de':
        return 'de-DE';
      case 'it':
        return 'it-IT';
      case 'ar':
        return 'ar-SA'; // Standard Arabic
      case 'zh':
        return 'zh-CN'; // Mandarin Chinese
      case 'ru':
        return 'ru-RU';
      case 'pt':
        return 'pt-BR';
      case 'hi':
        return 'hi-IN';
      case 'en':
      default:
        return 'en-US';
    }
  }

  /// Speaks the text using ultra-high-end pedagogical settings
  Future<void> speak(String text, String languageCode) async {
    if (!_isReady) await _initTts();

    final locale = _mapLanguageCodeToLocale(languageCode);
    
    // Hot-swap language context
    await _flutterTts.setLanguage(locale);
    
    // Duck ambient music during speech
    AudioService.instance.setAmbientDucking(true);
    
    // The awaitSpeakCompletion(true) setting ensures this awaits until audio finishes
    await _flutterTts.speak(text);
    
    // Restore ambient music volume
    AudioService.instance.setAmbientDucking(false);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
