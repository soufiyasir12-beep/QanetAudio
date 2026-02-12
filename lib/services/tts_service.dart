import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused }

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsState state = TtsState.stopped;

  List<dynamic> voices = [];
  List<dynamic> languages = [];
  String? currentVoice;
  String? currentLanguage;
  double rate = 0.5;
  double pitch = 1.0;
  double volume = 1.0;

  // Callbacks
  VoidCallback? onStateChanged;
  ValueChanged<String>? onLog;
  ValueChanged<int>? onProgressChanged;

  Future<void> init() async {
    if (!kIsWeb) {
      await _flutterTts.setSharedInstance(true);
    }

    _flutterTts.setStartHandler(() {
      state = TtsState.playing;
      onStateChanged?.call();
    });

    _flutterTts.setCompletionHandler(() {
      state = TtsState.stopped;
      onStateChanged?.call();
      onLog?.call('> Reproducción completada');
    });

    _flutterTts.setCancelHandler(() {
      state = TtsState.stopped;
      onStateChanged?.call();
    });

    _flutterTts.setPauseHandler(() {
      state = TtsState.paused;
      onStateChanged?.call();
    });

    _flutterTts.setContinueHandler(() {
      state = TtsState.playing;
      onStateChanged?.call();
    });

    _flutterTts.setErrorHandler((msg) {
      state = TtsState.stopped;
      onStateChanged?.call();
      onLog?.call('> ERROR TTS: $msg');
    });

    _flutterTts.setProgressHandler((text, start, end, word) {
      onProgressChanged?.call(end);
    });

    // Load available voices and languages
    voices = await _flutterTts.getVoices as List<dynamic>;
    languages = await _flutterTts.getLanguages as List<dynamic>;

    // Sort languages
    languages.sort((a, b) => a.toString().compareTo(b.toString()));

    // Set default language to Spanish if available
    final defaultLang = languages.firstWhere(
      (l) => l.toString().startsWith('es'),
      orElse: () => languages.isNotEmpty ? languages.first : 'en-US',
    );
    await setLanguage(defaultLang.toString());

    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setPitch(pitch);
    await _flutterTts.setVolume(volume);

    onLog?.call('> Motor TTS inicializado');
    onLog?.call('> ${voices.length} voces disponibles');
    onLog?.call('> Idioma: $currentLanguage');
  }

  Future<void> setLanguage(String language) async {
    currentLanguage = language;
    await _flutterTts.setLanguage(language);

    // Filter voices for this language
    final langVoices = voices.where((v) {
      final locale = v['locale']?.toString() ?? '';
      return locale.startsWith(language.split('-').first);
    }).toList();

    if (langVoices.isNotEmpty) {
      currentVoice = langVoices.first['name']?.toString();
    }
  }

  List<Map<String, String>> getVoicesForLanguage(String language) {
    final prefix = language.split('-').first;
    return voices
        .where((v) {
          final locale = v['locale']?.toString() ?? '';
          return locale.startsWith(prefix);
        })
        .map(
          (v) => {
            'name': v['name']?.toString() ?? 'Unknown',
            'locale': v['locale']?.toString() ?? '',
          },
        )
        .toList();
  }

  Future<void> setVoice(String voiceName, String locale) async {
    currentVoice = voiceName;
    await _flutterTts.setVoice({'name': voiceName, 'locale': locale});
    onLog?.call('> Voz seleccionada: $voiceName');
  }

  Future<void> setRate(double newRate) async {
    rate = newRate;
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setPitch(double newPitch) async {
    pitch = newPitch;
    await _flutterTts.setPitch(pitch);
  }

  Future<void> setVolume(double newVolume) async {
    volume = newVolume;
    await _flutterTts.setVolume(volume);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) {
      onLog?.call('> No hay texto para reproducir');
      return;
    }
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setPitch(pitch);
    await _flutterTts.setVolume(volume);
    state = TtsState.playing;
    onStateChanged?.call();
    onLog?.call('> Reproduciendo audio...');
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    state = TtsState.stopped;
    onStateChanged?.call();
    onLog?.call('> Detenido');
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    state = TtsState.paused;
    onStateChanged?.call();
    onLog?.call('> Pausado');
  }

  Future<String?> synthesizeToFile(String text, String filePath) async {
    if (kIsWeb) {
      onLog?.call('> Guardar audio no disponible en Web');
      return null;
    }
    if (text.isEmpty) {
      onLog?.call('> No hay texto para sintetizar');
      return null;
    }

    onLog?.call('> Sintetizando audio a archivo...');
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setPitch(pitch);
    await _flutterTts.setVolume(volume);

    final result = await _flutterTts.synthesizeToFile(text, filePath);
    if (result == 1) {
      onLog?.call('> Audio guardado: $filePath');
      return filePath;
    } else {
      onLog?.call('> Error al guardar audio');
      return null;
    }
  }

  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}
