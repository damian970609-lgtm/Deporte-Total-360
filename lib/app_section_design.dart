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
          width: 39,
          height: 39,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                accent.withAlpha(38),
                const Color(0xFF090D14),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withAlpha(190)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withAlpha(38),
                blurRadius: 13,
                spreadRadius: .2,
              ),
              const BoxShadow(
                color: Colors.black,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: accent, size: 20),
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.55,
                  shadows: <Shadow>[
                    Shadow(color: accent.withAlpha(65), blurRadius: 9),
                  ],
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEAF0F8),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.65,
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
