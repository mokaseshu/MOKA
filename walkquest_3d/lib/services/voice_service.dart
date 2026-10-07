import 'package:flutter_tts/flutter_tts.dart';

/// Spoken progress cues ("You have walked 500 steps. 1 km to go!").
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool enabled = true;

  Future<void> _init() async {
    if (_ready) return;
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.05);
    // Duck other audio (music/podcasts) instead of stopping it.
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.duckOthers,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,
    ]);
    _ready = true;
  }

  Future<void> say(String text) async {
    if (!enabled) return;
    try {
      await _init();
      await _tts.speak(text);
    } catch (_) {
      // TTS unavailable (e.g. no engine installed) — cues are best-effort.
    }
  }

  Future<void> stop() => _tts.stop();
}
