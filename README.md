# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

Navegación principal: Inicio, Deportes en vivo, Agenda de hoy, Noticias, Mister Fantasy, Estadísticas, Resúmenes y Ajustes. Deportes en vivo y Agenda de hoy cargan Fútbol Libre dentro de la APK. Chat, Telegram, contacto y donaciones permanecen como accesos auxiliares.

Archivos principales:
- lib/main.dart: navegación de ocho secciones, inicio y ajustes.
- lib/automatic_live_service.dart y lib/automatic_live_screen.dart: captura de eventos visibles de Fútbol Libre, lectura de M3U/XMLTV, selección de una señal por evento y multivista dinámica de hasta cuatro eventos en ExoPlayer.
- lib/live_channels_screen.dart: reproductor nativo video_player/ExoPlayer reutilizable.
- lib/sports_summaries_screen.dart: categorías deportivas y reproducción de YouTube dentro de la app mediante WebView.
- lib/public_chat_screen.dart: sala pública de chat compartida.
- lib/sports_statistics_screen.dart: búsqueda de ligas y clasificaciones.
- lib/sports_api_service.dart: conexión con el Worker sin introducir claves en la APK.
- lib/web_agenda_screen.dart: agenda Fútbol Libre integrada y captura de eventos visibles.
- lib/news_screen.dart: feed RSS y lector de noticias.
- lib/web_protection_policy.dart: reglas compartidas de protección web.
- lib/fantasy_screen.dart: módulo Fantasy.
- test/: pruebas automatizadas.

Recursos:
- assets/images/app_icon.png: icono y recurso gráfico reutilizado en Inicio.
- assets/images/home_reference.png: referencia visual declarada como asset; Inicio se construye con widgets Flutter, no como captura estática.
- assets/images/file_000000006048820e9e0720f1adf548f1.png: fondo de ajustes.

API deportiva:
La app usa el Worker público deporte-total-360-api para no incluir la clave API-Sports dentro del APK. La clave debe guardarse únicamente como secreto APISPORTS_KEY del repositorio del Worker:
https://github.com/damian970609-lgtm/Deporte-Total-360-

Compilación:
El workflow configura Java y Flutter, genera Android en el runner, prepara permisos de red e icono, ejecuta flutter analyze y flutter test, compila el APK release y publica deporte-total-360-apk durante 30 días.

Límites:
API-Sports queda para Estadísticas. Agenda de hoy utiliza Fútbol Libre en WebView. La página captura los eventos visibles y el módulo automático los cruza con una lista M3U/M3U8 y una EPG XMLTV configuradas en Ajustes de desarrollador. Diez minutos antes intenta encontrar una sola señal por evento, prioriza la calidad anunciada y comprueba su disponibilidad. ExoPlayer admite hasta cuatro eventos en cuadros separados y actualiza la multivista mientras permanece abierta; los cuadros se retiran al finalizar el evento o el programa EPG asociado. Se aceptan HLS, MP4 y MPEG-TS directos. La disponibilidad depende del proveedor, la región, la conexión y la correspondencia de horarios e IDs; no se puede garantizar que todas las emisiones estén activas. Configura solo listas que tengas autorización para reproducir. Los resúmenes de YouTube se reproducen dentro de WebView.
