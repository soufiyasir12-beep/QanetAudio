import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ConsoleLog extends StatefulWidget {
  final List<String> logs;

  const ConsoleLog({super.key, required this.logs});

  @override
  State<ConsoleLog> createState() => _ConsoleLogState();
}

class _ConsoleLogState extends State<ConsoleLog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(ConsoleLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.consoleBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGreen.withAlpha(40), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.terminal,
                size: 14,
                color: AppTheme.accentGreen.withAlpha(150),
              ),
              const SizedBox(width: 6),
              Text(
                'CONSOLE',
                style: AppTheme.consoleTextStyle.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentGreen.withAlpha(150),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.logs.length,
              itemBuilder: (context, index) {
                final log = widget.logs[index];
                Color logColor = AppTheme.consoleText;
                if (log.contains('ERROR')) {
                  logColor = AppTheme.errorRed;
                } else if (log.contains('guardado') ||
                    log.contains('completada')) {
                  logColor = AppTheme.accentCyan;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    log,
                    style: AppTheme.consoleTextStyle.copyWith(color: logColor),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
