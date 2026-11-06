import 'package:flutter/material.dart';

/// Encabezado compartido, estático y ligero para las secciones de la APK.
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withAlpha(145)),
          ),
          child: Icon(icon, color: accent, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.45,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEAF0F8),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
