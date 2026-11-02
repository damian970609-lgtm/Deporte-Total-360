# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

Archivos principales:
- lib/main.dart: navegación, inicio, reproductor SSH101 y ajustes.
- lib/agenda_screen.dart: agenda nativa, eventos API-Sports y asociación con canales del catálogo autorizado.
- lib/channel_catalog_service.dart: lectura de listas M3U y guías XMLTV/EPG autorizadas, coincidencia de partidos y soporte limitado para Referer/User-Agent.
- lib/channel_catalog_screen.dart: configuración y prueba de las fuentes de canales.
- lib/multi_match_player_screen.dart: hasta cuatro ventanas simultáneas con sesiones independientes del reproductor ExoPlayer de Android.
- lib/sports_statistics_screen.dart: búsqueda de ligas y clasificaciones.
- lib/sports_api_service.dart: conexión con el Worker sin introducir claves en la APK.
- lib/web_agenda_screen.dart: agenda externa integrada.
- lib/news_screen.dart: feed RSS y lector de noticias.
- lib/sports_summaries_screen.dart: resúmenes recientes de canales oficiales de YouTube, reproducidos dentro de la APK.
- lib/public_chat_screen.dart: chat neón, fondo de Ajustes y traducción local según el idioma elegido.
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

Canales y multipantalla:
En Agenda y En Vivo se puede abrir la vista multipantalla para eventos que tengan una fuente válida asociada. La asociación automática necesita una URL HTTPS de lista M3U y, para identificar el partido, una guía XMLTV/EPG HTTPS. La app cruza el identificador tvg-id con programas cuyo título contiene los dos equipos del evento. La opción de configuración está en el icono de lista de la Agenda. El botón PROBAR LISTA valida cuántos enlaces HLS/DASH compatibles hay en la M3U.

Solo deben configurarse listas y señales que el usuario tenga autorización para reproducir. No se extraen canales ni credenciales de otras aplicaciones. Si la guía no incluye el nombre de ambos equipos o el identificador tvg-id no coincide, la app no asigna un canal automáticamente. La multipantalla abre hasta cuatro reproductores a la vez por página; los límites reales dependen del hardware, ancho de banda y compatibilidad de cada señal. El recordatorio de diez minutos notifica, pero Android no permite garantizar que la app abra automáticamente pantallas de vídeo mientras está en segundo plano.

Compilación:
El workflow configura Java y Flutter, genera Android en el runner, prepara permisos de red e icono, ejecuta flutter analyze y flutter test, compila el APK release y publica deporte-total-360-apk durante 30 días.

Límites:
La reproducción SSH101 requiere un identificador de canal activo y una emisión HLS disponible. El bloqueo web filtra dominios publicitarios conocidos, pero no puede garantizar eliminar todos los anuncios ni interceptar todas las redirecciones de terceros.
