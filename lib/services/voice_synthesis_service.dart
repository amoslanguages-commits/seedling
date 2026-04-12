import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceSynthesisService {
  static final VoiceSynthesisService instance = VoiceSynthesisService._();
  VoiceSynthesisService._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isIOS || Platform.isMacOS) {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }
    
    // Set a premium voice feeling if possible
    await _flutterTts.setLanguage("es-ES"); // Default testing
    await _flutterTts.setSpeechRate(Platform.isWindows ? 1.0 : 0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _initialized = true;
  }

  Future<void> speak(String text, {String langCode = 'es-ES'}) async {
    await initialize();
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
