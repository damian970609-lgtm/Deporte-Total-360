# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

Navegación principal: Inicio, Deportes en vivo, Agenda de hoy, Noticias, Mister Fantasy, Estadísticas, Resúmenes y Ajustes. Chat, Telegram, contacto y donaciones permanecen como accesos auxiliares.

## Fuente de cada sección

- **Agenda de hoy:** exclusivamente `https://futbol-libre.cam/`. Se abre dentro de la APK en WebView. Un puente observa la programación visible e intenta reconocer eventos y enlaces de canal publicados por la propia página.
- **Deportes en vivo:** consume los eventos extraídos de Fútbol Libre y los mezcla por hora. Los enlaces web de canales se abren dentro de la aplicación. El reproductor nativo y la multivista conservan el catálogo independiente de señales directas HLS (`.m3u8`) o MP4 autorizadas.
- **Estadísticas:** API-Sports exclusivamente para búsqueda de ligas, temporadas, clasificaciones, datos de equipos y recursos estadísticos de los deportes cubiertos. No se consulta API-Sports para construir la Agenda ni la lista de eventos de En vivo.
- **Noticias:** feed RSS deportivo.
- **Resúmenes:** reproducción de vídeos de YouTube dentro de la aplicación mediante WebView.

## Archivos principales

- `lib/main.dart`: navegación de ocho secciones, Inicio y Ajustes.
- `lib/web_agenda_screen.dart`: agenda Fútbol Libre integrada y puente de extracción de eventos/canales visibles.
- `lib/futbol_libre_agenda.dart`: modelo compartido de eventos publicados por Fútbol Libre.
- `lib/live_channels_screen.dart`: feed mixto de eventos de Fútbol Libre, enlaces de canales, señales autorizadas y reproductor multivista de hasta cuatro cuadros.
- `lib/sports_statistics_screen.dart`: búsqueda de ligas y carga de estadísticas API-Sports.
- `lib/sports_api_service.dart`: cliente del Worker para estadísticas y catálogo independiente de señales autorizadas.
- `lib/sports_summaries_screen.dart`: categorías deportivas y reproducción de YouTube.
- `lib/public_chat_screen.dart`: sala pública de chat compartida.
- `lib/news_screen.dart`: feed RSS y lector de noticias.
- `lib/web_protection_policy.dart`: reglas compartidas de protección web.
- `lib/fantasy_screen.dart`: módulo Fantasy.
- `test/`: pruebas automatizadas.

## API-Sports y secretos

La aplicación llama al Worker público `https://deporte-total-360-api.damian970609.workers.dev`, que conserva la clave de proveedor en Cloudflare. `APISPORTS_KEY`, `CLOUDFLARE_API_TOKEN` y `CLOUDFLARE_ACCOUNT_ID` se administran como secretos de GitHub Actions en el repositorio Worker:

https://github.com/damian970609-lgtm/Deporte-Total-360-

No se incluye ninguna de esas claves dentro del APK. El cliente mantiene pausas y caché para respetar los límites del proveedor.

## Señales de transmisión

El catálogo `GET /api/live/sources` es independiente de los datos de API-Sports. Solo devuelve enlaces directos HTTPS `.m3u8` o `.mp4` autorizados y vinculados por el propietario. Los enlaces de canal de Fútbol Libre son páginas web; se abren dentro de WebView y no se convierten falsamente en URLs HLS/MP4. No se extraen reproductores protegidos ni se eluden DRM, autenticación o restricciones regionales.

La extracción automática depende de que Fútbol Libre publique las filas del evento y sus enlaces en el DOM visible de la página/ficha. Si el sitio no carga la programación o cambia su estructura, la agenda web seguirá disponible, pero el feed de En vivo no inventará eventos ni canales.

## Compilación

El workflow configura Java y Flutter, genera Android en el runner, prepara permisos de red e icono, ejecuta `flutter analyze` y `flutter test`, compila el APK release y publica el artefacto `deporte-total-360-apk` durante 30 días.

Recursos visuales:
- `assets/images/app_icon.png`: icono de la aplicación.
- `assets/images/home_reference.png`: referencia visual; Inicio se construye con widgets Flutter, no como captura estática.
