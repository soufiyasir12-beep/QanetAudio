import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/console_log.dart';
import '../widgets/gradient_button.dart';

class TextTtsScreen extends StatefulWidget {
  final TtsService ttsService;

  const TextTtsScreen({super.key, required this.ttsService});

  @override
  State<TextTtsScreen> createState() => _TextTtsScreenState();
}

class _TextTtsScreenState extends State<TextTtsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final List<String> _logs = ['> Sistema listo'];
  String? _selectedLanguage;
  String? _selectedVoiceName;
  List<Map<String, String>> _availableVoices = [];
  late AnimationController _pulseController;

  TtsService get tts => widget.ttsService;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    tts.onStateChanged = () {
      if (mounted) setState(() {});
      if (tts.state == TtsState.playing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    };

    tts.onLog = (log) {
      if (mounted) {
        setState(() => _logs.add(log));
      }
    };

    _selectedLanguage = tts.currentLanguage;
    _updateVoicesForLanguage();
  }

  void _updateVoicesForLanguage() {
    if (_selectedLanguage != null) {
      _availableVoices = tts.getVoicesForLanguage(_selectedLanguage!);
      if (_availableVoices.isNotEmpty) {
        _selectedVoiceName = tts.currentVoice ?? _availableVoices.first['name'];
      } else {
        _selectedVoiceName = null;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  int get _charCount => _textController.text.length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 20),

          // Text input
          _buildTextInput(),
          const SizedBox(height: 6),
          _buildCharCount(),
          const SizedBox(height: 16),

          // Voice controls
          _buildVoiceControls(),
          const SizedBox(height: 16),

          // Sliders
          _buildSliders(),
          const SizedBox(height: 20),

          // Action buttons
          _buildActionButtons(),
          const SizedBox(height: 20),

          // Console
          ConsoleLog(logs: _logs),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.record_voice_over,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transcriptor de Texto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Escribe tu texto y reprodúcelo',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return Container(
      decoration: AppTheme.glassCard,
      child: TextField(
        controller: _textController,
        maxLines: 6,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: 'Escribe o pega tu texto aquí...',
          hintStyle: TextStyle(color: AppTheme.textSecondary.withAlpha(120)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCharCount() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$_charCount caracteres  •  $_wordCount palabras',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildVoiceControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.language, size: 16, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text(
                'IDIOMA Y VOZ',
                style: TextStyle(
                  color: AppTheme.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Language dropdown
          DropdownButtonFormField<String>(
            initialValue: tts.languages.contains(_selectedLanguage)
                ? _selectedLanguage
                : null,
            isExpanded: true,
            dropdownColor: AppTheme.cardDark,
            decoration: const InputDecoration(
              labelText: 'Idioma',
              labelStyle: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: tts.languages.map((lang) {
              return DropdownMenuItem<String>(
                value: lang.toString(),
                child: Text(
                  lang.toString(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) async {
              if (value != null) {
                await tts.setLanguage(value);
                setState(() {
                  _selectedLanguage = value;
                  _updateVoicesForLanguage();
                });
                _logs.add('> Idioma cambiado a: $value');
              }
            },
          ),
          const SizedBox(height: 12),

          // Voice dropdown
          DropdownButtonFormField<String>(
            initialValue:
                _availableVoices.any((v) => v['name'] == _selectedVoiceName)
                ? _selectedVoiceName
                : null,
            isExpanded: true,
            dropdownColor: AppTheme.cardDark,
            decoration: const InputDecoration(
              labelText: 'Voz',
              labelStyle: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: _availableVoices.map((voice) {
              return DropdownMenuItem<String>(
                value: voice['name'],
                child: Text(
                  voice['name'] ?? '',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) async {
              if (value != null) {
                final voice = _availableVoices.firstWhere(
                  (v) => v['name'] == value,
                );
                await tts.setVoice(value, voice['locale'] ?? '');
                setState(() => _selectedVoiceName = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliders() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard,
      child: Column(
        children: [
          _buildSliderRow(
            icon: Icons.speed,
            label: 'Velocidad',
            value: tts.rate,
            min: 0.0,
            max: 1.0,
            displayValue: '${(tts.rate * 200).round()}%',
            onChanged: (v) async {
              await tts.setRate(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            icon: Icons.tune,
            label: 'Tono',
            value: tts.pitch,
            min: 0.5,
            max: 2.0,
            displayValue: '${tts.pitch.toStringAsFixed(1)}x',
            onChanged: (v) async {
              await tts.setPitch(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            icon: Icons.volume_up,
            label: 'Volumen',
            value: tts.volume,
            min: 0.0,
            max: 1.0,
            displayValue: '${(tts.volume * 100).round()}%',
            onChanged: (v) async {
              await tts.setVolume(v);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.accentCyan),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 45,
          child: Text(
            displayValue,
            style: const TextStyle(
              color: AppTheme.accentCyan,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final isPlaying = tts.state == TtsState.playing;
    final isPaused = tts.state == TtsState.paused;

    return Row(
      children: [
        Expanded(
          child: GradientButton(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            label: isPlaying
                ? 'PAUSAR'
                : (isPaused ? 'CONTINUAR' : 'REPRODUCIR'),
            isActive: isPlaying,
            onPressed: () async {
              if (isPlaying) {
                await tts.pause();
              } else if (isPaused) {
                await tts.speak(_textController.text);
              } else {
                await tts.speak(_textController.text);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        GradientButton(
          icon: Icons.stop,
          label: 'STOP',
          colors: [AppTheme.errorRed, AppTheme.accentOrange],
          onPressed: isPlaying || isPaused
              ? () async {
                  await tts.stop();
                }
              : null,
        ),
      ],
    );
  }
}
