# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

Archivos principales:
- lib/main.dart: navegación de ocho secciones, inicio y ajustes.
- lib/live_channels_screen.dart: catálogo por deporte, agenda de eventos, señales autorizadas y reproductor multivista de hasta cuatro cuadros.
- lib/agenda_screen.dart: agenda nativa y eventos API-Sports.
- lib/sports_statistics_screen.dart: búsqueda de ligas y clasificaciones.
- lib/sports_api_service.dart: conexión con el Worker sin introducir claves en la APK.
- lib/web_agenda_screen.dart: agenda externa integrada.
- lib/news_screen.dart: feed RSS y lector de noticias.
- lib/web_protection_policy.dart: reglas compartidas de protección web.
- lib/fantasy_screen.dart: módulo Fantasy.
- test/: pruebas automatizadas.

Recursos:
- assets/images/app_icon.png: icono y recurso gráfico reutilizado en Inicio.
- assets/images/home_reference.png: referencia visual conservada en GitHub; no se incluye en la APK porque Inicio se construye con widgets Flutter.
- assets/images/file_000000006048820e9e0720f1adf548f1.png: fondo de ajustes.

API deportiva:
La app usa el Worker público deporte-total-360-api para no incluir la clave API-Sports dentro del APK. La clave debe guardarse únicamente como secreto APISPORTS_KEY del repositorio del Worker:
https://github.com/damian970609-lgtm/Deporte-Total-360-

Compilación:
El workflow configura Java y Flutter, genera Android en el runner, prepara permisos de red e icono, ejecuta flutter analyze y flutter test, compila el APK release y publica deporte-total-360-apk durante 30 días.

Límites:
El módulo Deportes en vivo consulta los eventos disponibles en el Worker de estadísticas y permite vincular señales directas HLS (.m3u8) o MP4 que el propietario esté autorizado a reproducir. Admite hasta cuatro cuadros simultáneos; el número real de reproducciones depende del dispositivo y de la conexión. No extrae enlaces de páginas de terceros ni elude DRM, autenticación o restricciones. La agenda web externa se conserva como alternativa integrada.
