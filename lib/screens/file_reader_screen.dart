import 'dart:convert' show utf8;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/console_log.dart';
import '../widgets/gradient_button.dart';
import '../utils/file_reader.dart';
import '../utils/web_download.dart';
import '../utils/permission_helper.dart';

class FileReaderScreen extends StatefulWidget {
  final TtsService ttsService;

  const FileReaderScreen({super.key, required this.ttsService});

  @override
  State<FileReaderScreen> createState() => _FileReaderScreenState();
}

class _FileReaderScreenState extends State<FileReaderScreen> {
  final List<String> _logs = ['> Sistema listo', '> Esperando archivo...'];
  String? _loadedText;
  String? _fileName;
  bool _isSaving = false;
  String _selectedFormat = 'wav';
  final List<String> _formats = ['wav'];

  TtsService get tts => widget.ttsService;

  @override
  void initState() {
    super.initState();
    tts.onStateChanged = () {
      if (mounted) setState(() {});
    };

    tts.onLog = (log) {
      if (mounted) {
        setState(() => _logs.add(log));
      }
    };
  }

  Future<void> _pickFile() async {
    try {
      _addLog('> Abriendo selector de archivos...');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.name.isNotEmpty) {
        String content;
        final name = result.files.single.name;

        if (kIsWeb) {
          // Web: read bytes from memory
          final bytes = result.files.single.bytes;
          if (bytes == null) {
            _addLog('> ERROR: No se pudieron leer los bytes del archivo');
            return;
          }
          content = utf8.decode(bytes);
        } else {
          // Mobile/Desktop: read from file path
          final path = result.files.single.path;
          if (path == null) {
            _addLog('> ERROR: No se pudo obtener la ruta del archivo');
            return;
          }
          content = await readFileAsString(path);
        }

        setState(() {
          _loadedText = content;
          _fileName = name;
        });

        final wordCount = content.trim().split(RegExp(r'\s+')).length;
        _addLog('> Archivo cargado: $name');
        _addLog('> ${content.length} caracteres, $wordCount palabras');
      } else {
        _addLog('> Selección cancelada');
      }
    } catch (e) {
      _addLog('> ERROR: No se pudo cargar el archivo: $e');
    }
  }

  Future<void> _saveAudio() async {
    if (_loadedText == null || _loadedText!.isEmpty) {
      _addLog('> No hay texto para guardar');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (kIsWeb) {
        // Web: call Vercel serverless API to generate MP3
        _addLog('> Generando audio en servidor...');

        final response = await http.post(
          Uri.parse('/api/tts'),
          headers: {'Content-Type': 'application/json'},
          body: '{"text": ${_jsonEscape(_loadedText!)}}',
        );

        if (response.statusCode == 200) {
          final baseName = _fileName?.replaceAll('.txt', '') ?? 'audio_tts';
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final downloadName = '${baseName}_$timestamp.mp3';

          downloadFileWeb(response.bodyBytes, downloadName);

          _addLog('> Audio descargado: $downloadName');
          _showSnackBar('Audio descargado exitosamente');
        } else {
          _addLog('> ERROR del servidor: ${response.statusCode}');
          _addLog('> ${response.body}');
        }
      } else {
        // Mobile: use native TTS synthesize + file picker
        await _saveAudioMobile();
      }
    } catch (e) {
      _addLog('> ERROR al guardar: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAudioMobile() async {
    // Request storage permission
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      _addLog('> ERROR: Permiso de almacenamiento denegado');
      return;
    }

    // Let user pick save directory
    final outputDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecciona dónde guardar el audio',
    );

    if (outputDir == null) {
      _addLog('> Guardado cancelado');
      return;
    }

    final baseName = _fileName?.replaceAll('.txt', '') ?? 'audio_tts';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$outputDir/${baseName}_$timestamp.$_selectedFormat';

    _addLog('> Sintetizando a: $filePath');

    final result = await tts.synthesizeToFile(_loadedText!, filePath);
    if (result != null) {
      _showSnackBar('Audio guardado exitosamente');
    }
  }

  String _jsonEscape(String text) {
    return '"${text.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\t', '\\t')}"';
  }

  void _addLog(String message) {
    setState(() => _logs.add(message));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.cardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

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

          // Load file button
          _buildLoadButton(),
          const SizedBox(height: 16),

          // File preview
          if (_loadedText != null) ...[
            _buildFilePreview(),
            const SizedBox(height: 16),
            _buildPlaybackControls(),
            const SizedBox(height: 16),
            _buildSaveSection(),
            const SizedBox(height: 16),
          ],

          // Console log
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
            gradient: LinearGradient(
              colors: [AppTheme.accentGreen, AppTheme.accentCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.description, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lector de Archivos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Carga un .txt y escúchalo',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.accentGreen, AppTheme.accentCyan],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentGreen.withAlpha(50),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_file, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    _fileName != null ? 'CAMBIAR ARCHIVO' : 'CARGAR .TXT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    final wordCount = _loadedText!.trim().split(RegExp(r'\s+')).length;

    return Container(
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withAlpha(15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file,
                  size: 16,
                  color: AppTheme.accentCyan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fileName ?? 'archivo.txt',
                    style: const TextStyle(
                      color: AppTheme.accentCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$wordCount palabras',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Preview text
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                _loadedText!,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    final isPlaying = tts.state == TtsState.playing;
    final isPaused = tts.state == TtsState.paused;

    return Row(
      children: [
        Expanded(
          child: GradientButton(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            label: isPlaying
                ? 'PAUSAR'
                : (isPaused ? 'CONTINUAR' : 'LEER EN VOZ ALTA'),
            isActive: isPlaying,
            colors: [AppTheme.accentGreen, AppTheme.accentCyan],
            onPressed: () async {
              if (isPlaying) {
                await tts.pause();
              } else {
                await tts.speak(_loadedText ?? '');
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

  Widget _buildSaveSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.save_alt, size: 16, color: AppTheme.accentPurple),
              SizedBox(width: 8),
              Text(
                'GUARDAR AUDIO',
                style: TextStyle(
                  color: AppTheme.accentPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Format selector (only for mobile)
          if (!kIsWeb)
            Row(
              children: [
                const Text(
                  'Formato:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(width: 12),
                ..._formats.map(
                  (format) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        format.toUpperCase(),
                        style: TextStyle(
                          color: _selectedFormat == format
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: _selectedFormat == format,
                      selectedColor: AppTheme.accentPurple,
                      backgroundColor: AppTheme.cardDark,
                      side: BorderSide(
                        color: _selectedFormat == format
                            ? AppTheme.accentPurple
                            : AppTheme.textSecondary.withAlpha(50),
                      ),
                      onSelected: (selected) {
                        setState(() => _selectedFormat = format);
                      },
                    ),
                  ),
                ),
              ],
            ),

          if (!kIsWeb) const SizedBox(height: 12),

          // Web info badge
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_download,
                    size: 14,
                    color: AppTheme.accentCyan.withAlpha(180),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Se generará MP3 vía servidor (edge-tts)',
                      style: TextStyle(
                        color: AppTheme.accentCyan,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Save button
          SizedBox(
            width: double.infinity,
            child: _isSaving
                ? const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.accentPurple),
                        SizedBox(height: 8),
                        Text(
                          'Generando audio...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : GradientButton(
                    icon: kIsWeb ? Icons.cloud_download : Icons.download,
                    label: kIsWeb ? 'DESCARGAR MP3' : 'GUARDAR EN DISPOSITIVO',
                    colors: [AppTheme.accentPurple, AppTheme.accentCyan],
                    onPressed: _saveAudio,
                  ),
          ),
        ],
      ),
    );
  }
}
