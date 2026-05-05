import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { stopped, playing, paused }

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  final FlutterTts _tts = FlutterTts();

  TtsState _state = TtsState.stopped;
  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;
  bool get isStopped => _state == TtsState.stopped;

  double _rate = 0.5;
  double get rate => _rate;

  List<Map<String, dynamic>> _voices = [];
  List<Map<String, dynamic>> get voices => _voices;

  String? _selectedVoiceId;
  String? get selectedVoiceId => _selectedVoiceId;

  // Callback when current chunk finishes — caller can feed next text
  VoidCallback? onChunkComplete;

  // Progress: text position (char offset in current chunk)
  int _currentCharOffset = 0;
  int get currentCharOffset => _currentCharOffset;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _tts.setSpeechRate(_rate);

    _tts.setStartHandler(() {
      _state = TtsState.playing;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _state = TtsState.stopped;
      _currentCharOffset = 0;
      notifyListeners();
      onChunkComplete?.call();
    });

    _tts.setErrorHandler((msg) {
      _state = TtsState.stopped;
      notifyListeners();
    });

    _tts.setCancelHandler(() {
      _state = TtsState.stopped;
      notifyListeners();
    });

    _tts.setPauseHandler(() {
      _state = TtsState.paused;
      notifyListeners();
    });

    _tts.setContinueHandler(() {
      _state = TtsState.playing;
      notifyListeners();
    });

    _tts.setProgressHandler((text, start, end, word) {
      _currentCharOffset = start;
      notifyListeners();
    });

    try {
      _voices = List<Map<String, dynamic>>.from(
        (await _tts.getVoices).cast<Map>(),
      );
    } catch (_) {}

    // Default to Chinese if available
    await _setDefaultChinese();
  }

  Future<void> _setDefaultChinese() async {
    if (_voices.isEmpty) return;
    // Prefer zh-CN voice
    for (final v in _voices) {
      final locale = v['locale']?.toString() ?? v['name']?.toString() ?? '';
      if (locale.startsWith('zh') || locale.contains('Chinese')) {
        _selectedVoiceId = v['name']?.toString() ?? v['identifier']?.toString();
        try {
          await _tts.setVoice(v as Map<String, String>);
        } catch (_) {}
        return;
      }
    }
  }

  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

  Future<void> setVoiceById(String voiceId) async {
    _selectedVoiceId = voiceId;
    final voice = _voices.firstWhere(
      (v) => (v['name'] ?? v['identifier']) == voiceId,
      orElse: () => <String, dynamic>{},
    );
    if (voice.isNotEmpty) {
      try {
        await _tts.setVoice(voice as Map<String, String>);
      } catch (e) {
        // Fallback: try setting via language
        final locale = voice['locale']?.toString() ?? 'zh-CN';
        await _tts.setLanguage(locale);
      }
    }
  }

  Future<void> setRate(double rate) async {
    // flutter_tts uses 0.0-1.0, where 0.5 is default
    _rate = rate.clamp(0.1, 1.0);
    await _tts.setSpeechRate(_rate);
    notifyListeners();
  }

  Future<void> speak(String text) async {
    _currentCharOffset = 0;
    // Split long text into paragraphs for better progress tracking
    // Use max 2000 chars per chunk
    if (text.length > 2000) {
      final paragraphs = text.split(RegExp(r'\n+'));
      var buffer = '';
      for (final para in paragraphs) {
        if (buffer.length + para.length > 2000) {
          await _tts.speak(buffer);
          buffer = para;
        } else {
          if (buffer.isNotEmpty) buffer += '\n';
          buffer += para;
        }
      }
      if (buffer.isNotEmpty) {
        await _tts.speak(buffer);
      }
    } else {
      await _tts.speak(text);
    }
  }

  Future<void> speakText(String text) async {
    await speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _state = TtsState.stopped;
    _currentCharOffset = 0;
    notifyListeners();
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  void togglePlayPause() {
    if (_state == TtsState.playing) {
      pause();
    } else if (_state == TtsState.paused) {
      // Flutter_tts doesn't have resume; we use stop + speak again
      stop();
    }
  }

  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
