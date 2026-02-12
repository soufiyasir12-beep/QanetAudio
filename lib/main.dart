import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/tts_service.dart';
import 'screens/text_tts_screen.dart';
import 'screens/file_reader_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.surfaceDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
  runApp(const QanetAudioTTSApp());
}

class QanetAudioTTSApp extends StatelessWidget {
  const QanetAudioTTSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QANET Audio TTS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final TtsService _ttsService;
  bool _isInitialized = false;
  String _initStatus = 'Inicializando motor TTS...';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _ttsService.init();
      setState(() {
        _isInitialized = true;
        _initStatus = 'Listo';
      });
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _initStatus = 'Error al inicializar TTS: $e';
      });
    }
  }

  @override
  void dispose() {
    _ttsService.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated logo
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.5 + (value * 0.5),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentCyan.withAlpha(60),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.graphic_eq,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(bounds),
                child: const Text(
                  'QANET AUDIO TTS',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.accentCyan.withAlpha(180),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _initStatus,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: AppTheme.primaryDark,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceDark,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(bounds),
                child: const Icon(
                  Icons.graphic_eq,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(bounds),
                child: const Text(
                  'QANET TTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentIndex == 0
              ? TextTtsScreen(key: const ValueKey(0), ttsService: _ttsService)
              : FileReaderScreen(
                  key: const ValueKey(1),
                  ttsService: _ttsService,
                ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            border: Border(
              top: BorderSide(
                color: AppTheme.accentCyan.withAlpha(30),
                width: 1,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.keyboard_voice_outlined, 0),
                activeIcon: _buildNavIcon(
                  Icons.keyboard_voice,
                  0,
                  active: true,
                ),
                label: 'Texto a Voz',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.description_outlined, 1),
                activeIcon: _buildNavIcon(Icons.description, 1, active: true),
                label: 'Lector .TXT',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {bool active = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: active
          ? BoxDecoration(
              color: AppTheme.accentCyan.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Icon(icon),
    );
  }
}
