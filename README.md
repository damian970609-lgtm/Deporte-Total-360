# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

Navegación principal: Inicio, Deportes en vivo, Agenda de hoy, Noticias, Mister Fantasy, Estadísticas, Resúmenes y Ajustes. Deportes en vivo y Agenda de hoy cargan Fútbol Libre dentro de la APK. Chat, Telegram, contacto y donaciones permanecen como accesos auxiliares.

Archivos principales:
- lib/main.dart: navegación de ocho secciones, inicio y ajustes.
- lib/automatic_live_service.dart y lib/automatic_live_screen.dart: captura de eventos de agenda, lectura de M3U/XMLTV, clasificación y asignación automática de señales a cuatro reproductores fijos y retiro de señales al terminar su horario EPG.
- lib/live_media_format.dart y lib/live_channels_screen.dart: detección explícita de HLS (.m3u8), DASH (.mpd), Smooth Streaming (.ism/Manifest) y vídeo progresivo (MP4, MPEG-TS, WebM, MKV, entre otros), con la indicación de formato correspondiente para ExoPlayer.
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

Límites y funcionamiento:
API-Sports queda para Estadísticas. Agenda de hoy utiliza Fútbol Libre únicamente para leer deporte, competición, equipos, fechas y horas; no extrae ni reproduce sus reproductores. Cada captura reemplaza la anterior para retirar eventos que desaparecen de la agenda. El servicio automático descarga doce listas M3U y veinte guías XMLTV regionales/globales en segundo plano, sin que el usuario deba introducir URLs ni validar listas. Las direcciones y los catálogos no se muestran en la interfaz. La selección prioriza señales identificadas como español (idioma, país y metadatos); solo prueba otros idiomas cuando no hay una señal española comprobada. Las fuentes incluyen listas públicas de Teleonline, iptv-org, freecasthub y catálogos existentes, además de EPG regionales de España, Latinoamérica y el Caribe y guías globales de respaldo. Diez minutos antes del evento busca una programación XMLTV coincidente y prueba la disponibilidad del manifiesto y de un segmento de vídeo. La pestaña Deportes en vivo mantiene cuatro cuadros fijos sin desplazamiento; cada cuadro muestra el deporte, la competición y los equipos asociados. Al comenzar un evento, una señal directa y comprobada ocupa un canal libre; el usuario pulsa Play para reproducirla. Los canales 2, 3 y 4 empiezan silenciados. Al llegar la hora final del evento/EPG se libera el cuadro para el siguiente evento. La agenda y los catálogos se revisan cada 45 segundos mientras la pestaña está activa y la app permanece abierta en primer plano. Se aceptan señales multimedia directas HLS (.m3u8), DASH (.mpd), Smooth Streaming y contenedores progresivos compatibles como MP4, MPEG-TS, WebM, Matroska y FLV; los enlaces relativos dentro de las playlists se resuelven usando la URL de la lista. Las páginas HTML, RTMP, DRM, credenciales y geobloqueos no se eluden. La disponibilidad depende del proveedor, la región, la conexión y la correspondencia de horarios y nombres, por lo que no se garantiza una señal para cada evento. El canal SSH101 propio conserva su reproductor HLS y la configuración de emisión RTMP/HLS de forma independiente. Los resúmenes de YouTube se reproducen dentro de WebView.
