import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  final FlutterTts _tts = FlutterTts();

  factory VoiceService() => _instance;
  VoiceService._internal() {
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("es-US");
    await _tts.setSpeechRate(0.5); // Velocidad natural
    await _tts.setVolume(1.0);
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }
}