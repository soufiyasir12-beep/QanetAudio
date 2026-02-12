import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isActive;
  final List<Color>? colors;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isActive = false,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        colors ?? [AppTheme.accentCyan, AppTheme.accentPurple];

    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? LinearGradient(
                colors: isActive
                    ? [AppTheme.accentOrange, AppTheme.errorRed]
                    : gradientColors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: onPressed == null ? AppTheme.cardDark : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color:
                      (isActive ? AppTheme.accentOrange : gradientColors.first)
                          .withAlpha(60),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
