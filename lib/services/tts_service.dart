import 'dart:convert' show jsonEncode;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

enum TtsState { playing, stopped, paused }

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

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

    // Web: AudioPlayer listeners
    if (kIsWeb) {
      _audioPlayer.onPlayerComplete.listen((_) {
        state = TtsState.stopped;
        onStateChanged?.call();
        onLog?.call('> Reproducción completada');
      });
    }

    // Load available voices and languages
    if (kIsWeb) {
      // Web: Use hardcoded edge-tts voices (flutter_tts web doesn't implement getVoices properly)
      voices = [
        {'name': 'es-ES-AlvaroNeural', 'locale': 'es-ES'},
        {'name': 'es-ES-ElviraNeural', 'locale': 'es-ES'},
        {'name': 'es-ES-AbrilNeural', 'locale': 'es-ES'},
        {'name': 'es-MX-DaliaNeural', 'locale': 'es-MX'},
        {'name': 'es-MX-JorgeNeural', 'locale': 'es-MX'},
        {'name': 'es-AR-ElenaNeural', 'locale': 'es-AR'},
        {'name': 'en-US-JennyNeural', 'locale': 'en-US'},
        {'name': 'en-US-GuyNeural', 'locale': 'en-US'},
        {'name': 'en-US-AriaNeural', 'locale': 'en-US'},
        {'name': 'en-GB-SoniaNeural', 'locale': 'en-GB'},
        {'name': 'en-GB-RyanNeural', 'locale': 'en-GB'},
        {'name': 'fr-FR-DeniseNeural', 'locale': 'fr-FR'},
        {'name': 'fr-FR-HenriNeural', 'locale': 'fr-FR'},
        {'name': 'de-DE-KatjaNeural', 'locale': 'de-DE'},
        {'name': 'de-DE-ConradNeural', 'locale': 'de-DE'},
        {'name': 'it-IT-ElsaNeural', 'locale': 'it-IT'},
        {'name': 'it-IT-DiegoNeural', 'locale': 'it-IT'},
        {'name': 'pt-BR-FranciscaNeural', 'locale': 'pt-BR'},
        {'name': 'pt-BR-AntonioNeural', 'locale': 'pt-BR'},
      ];
      languages = [
        'es-ES',
        'es-MX',
        'es-AR',
        'en-US',
        'en-GB',
        'fr-FR',
        'de-DE',
        'it-IT',
        'pt-BR',
      ];
    } else {
      // Mobile: Use native API
      voices = await _flutterTts.getVoices as List<dynamic>;
      languages = await _flutterTts.getLanguages as List<dynamic>;
    }

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

    if (kIsWeb) {
      // Web: Use edge-tts API + AudioPlayer
      try {
        state = TtsState.playing;
        onStateChanged?.call();
        onLog?.call('> Generando audio con edge-tts...');
        onLog?.call('> Voz: ${currentVoice ?? "es-ES-AlvaroNeural"}');

        final response = await http.post(
          Uri.parse('/api/tts'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'voice': currentVoice ?? 'es-ES-AlvaroNeural',
            'format': 'mp3',
          }),
        );

        if (response.statusCode == 200) {
          onLog?.call('> Reproduciendo audio...');
          await _audioPlayer.play(BytesSource(response.bodyBytes));
        } else {
          state = TtsState.stopped;
          onStateChanged?.call();
          onLog?.call('> ERROR del servidor: ${response.statusCode}');
          onLog?.call('> ${response.body}');
        }
      } catch (e) {
        state = TtsState.stopped;
        onStateChanged?.call();
        onLog?.call('> ERROR de conexión: $e');
      }
    } else {
      // Mobile: Use flutter_tts
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.setVolume(volume);
      state = TtsState.playing;
      onStateChanged?.call();
      onLog?.call('> Reproduciendo audio...');
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    if (kIsWeb) {
      await _audioPlayer.stop();
    } else {
      await _flutterTts.stop();
    }
    state = TtsState.stopped;
    onStateChanged?.call();
    onLog?.call('> Detenido');
  }

  Future<void> pause() async {
    if (kIsWeb) {
      await _audioPlayer.pause();
    } else {
      await _flutterTts.pause();
    }
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
    await _audioPlayer.dispose();
  }
}
