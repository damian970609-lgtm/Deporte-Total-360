# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

Archivos principales:
- lib/main.dart: navegación, inicio, reproductor SSH101 y ajustes.
- lib/agenda_screen.dart: agenda nativa y eventos API-Sports.
- lib/sports_statistics_screen.dart: estadísticas multideporte, identificadores de deporte/competición y escudos/logos cuando la API los entrega.
- lib/sports_api_service.dart: rutas API-Sports para fútbol, básquet, NBA, béisbol, fútbol americano, hockey, balonmano, rugby, vóley, fútbol australiano, Fórmula 1 y MMA.
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
La app usa el Worker público deporte-total-360-api para no incluir la clave API-Sports dentro del APK. Estadísticas consulta tablas en deportes con recurso `standings`, rankings de pilotos en Fórmula 1 y combates por fecha en MMA. Los identificadores y logos se muestran cuando el proveedor los incluye en su respuesta. La clave debe guardarse únicamente como secreto APISPORTS_KEY del repositorio del Worker:
https://github.com/damian970609-lgtm/Deporte-Total-360-

Compilación:
El workflow configura Java y Flutter, genera Android en el runner, prepara permisos de red e icono, ejecuta flutter analyze y flutter test, compila el APK release y publica deporte-total-360-apk durante 30 días.

Límites:
La reproducción SSH101 requiere un identificador de canal activo y una emisión HLS disponible. El bloqueo web incorpora redes publicitarias conocidas y redes de anuncios adultos, y revisa navegación/ventanas emergentes. No puede garantizar eliminar anuncios servidos desde el mismo dominio del reproductor ni todos los redireccionamientos de terceros.
