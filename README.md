# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

## Navegación principal

La aplicación conserva ocho secciones principales:
1. Inicio: panel de deportes y accesos directos a Chat, Telegram, contacto y donaciones.
2. Deportes en vivo: centro preparado para señales HLS autorizadas.
3. Agenda de hoy: Fútbol Libre se abre dentro de la aplicación; la agenda nativa con eventos y marcadores de API-Sports sigue disponible desde Inicio y Estadísticas.
4. Noticias: feed deportivo de fuentes RSS.
5. Mister Fantasy: sitio oficial integrado en WebView.
6. Estadísticas: ligas, resultados y clasificaciones disponibles mediante API-Sports/Worker.
7. Resúmenes: búsqueda y reproducción dentro de la aplicación desde YouTube.
8. Ajustes: idioma, notificaciones, enlaces y servidor deportivo.

## Archivos principales

- `lib/main.dart`: navegación, Inicio, centro de transmisiones y ajustes.
- `lib/highlights_screen.dart`: resúmenes y búsqueda integrada de YouTube.
- `lib/agenda_screen.dart`: agenda nativa y eventos API-Sports.
- `lib/sports_statistics_screen.dart`: búsqueda de ligas y clasificaciones.
- `lib/sports_api_service.dart`: conexión con el Worker sin introducir claves en la APK.
- `lib/web_agenda_screen.dart`: Fútbol Libre integrado y controles de navegación.
- `lib/news_screen.dart`: feed RSS y lector de noticias.
- `lib/notification_service.dart`: notificaciones locales y recordatorios.
- `lib/fantasy_screen.dart`: módulo oficial Mister Fantasy.
- `lib/web_protection_policy.dart`: reglas compartidas de protección web.
- `test/`: pruebas automatizadas.

## Recursos

- `assets/images/app_icon.png`: icono de la aplicación.
- `assets/images/home_reference.png`: referencia visual de Inicio.
- `assets/images/file_000000006048820e9e0720f1adf548f1.png`: fondo de Ajustes.

## API deportiva

La app usa el Worker público deporte-total-360-api para no incluir la clave API-Sports dentro del APK. La clave debe guardarse únicamente como secreto `APISPORTS_KEY` del repositorio del Worker:
https://github.com/damian970609-lgtm/Deporte-Total-360-

## Compilación

El workflow configura Java y Flutter, genera Android en el runner, prepara permisos de red e icono, ejecuta `flutter analyze` y `flutter test`, compila el APK release y publica el artefacto `deporte-total-360-apk` durante 30 días.

## Límites actuales

- El módulo En vivo ya no usa SSH101. El reproductor multifuente requiere que se agregue un catálogo de URLs HLS autorizadas y verificadas; no se inventan enlaces.
- La agenda web conserva Fútbol Libre dentro de la app. Los datos nativos de agenda provienen de API-Sports; no se extraen automáticamente señales ni contenido protegido del sitio externo.
- Los resúmenes se cargan desde YouTube y respetan la disponibilidad y las restricciones de esa plataforma.
- La disponibilidad de ligas, resultados y estadísticas depende del plan y los datos habilitados en API-Sports.
