# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

Navegación principal: Inicio, Deportes en vivo, Canales deportivos, Agenda de hoy, Noticias, Mister Fantasy, Estadísticas, Resúmenes, Chat y Ajustes. Chat es una pestaña de primer nivel y conserva la sala pública compartida del Worker. Inicio, Agenda, Estadísticas y Resúmenes utilizan los diez deportes favoritos configurados en SportsAPI.app; Deportes en vivo busca señales por separado en los catálogos M3U/XMLTV.

Archivos principales:
- lib/main.dart: navegación de diez secciones, inicio, chat y ajustes.
- lib/automatic_live_service.dart y lib/automatic_live_screen.dart: captura de eventos de SportsAPI, cruce de programación XMLTV con los canales deportivos visibles que el propietario seleccionó en Ajustes > Damián APK, verificación de señales en español e inglés y asignación automática a ocho reproductores.
- lib/live_media_format.dart y lib/live_channels_screen.dart: detección explícita de HLS, DASH, Smooth Streaming y vídeo progresivo, adaptación de calidad automática con ExoPlayer, selector manual por pistas y transición fullscreen/miniatura sin recrear el controlador.
- lib/sports_summaries_screen.dart: categorías deportivas y reproducción de YouTube dentro de la app mediante WebView.
- lib/public_chat_screen.dart: sala pública de chat compartida.
- lib/sports_statistics_screen.dart: búsqueda de ligas y clasificaciones.
- lib/sports_api_service.dart: cliente legado de API-Sports/Worker, conservado para compatibilidad.
- lib/sportsapi_app_service.dart y lib/sportsapi_statistics_screen.dart: conexión segura con las rutas SportsAPI.app del Worker; estadísticas de partidos y resultados de carreras sin introducir claves en la APK.
- lib/notification_service.dart: recordatorios locales, Firebase Cloud Messaging mediante suscripción al tema de transmisiones y apertura de Deportes en vivo al tocar un aviso.
- lib/web_agenda_screen.dart: agenda MARCA integrada y captura de eventos visibles.
- lib/news_screen.dart: feed RSS y lector de noticias.
- lib/web_protection_policy.dart: reglas compartidas de protección web.
- lib/fantasy_screen.dart: módulo Fantasy.
- test/: pruebas automatizadas.

Recursos:
- assets/images/app_icon.png: icono y recurso gráfico reutilizado en Inicio.
- assets/images/home_reference.png: referencia visual declarada como asset; Inicio se construye con widgets Flutter, no como captura estática.
- assets/images/file_000000006048820e9e0720f1adf548f1.png: fondo de ajustes.

API deportiva:
La agenda, los diez deportes favoritos y las estadísticas nuevas usan SportsAPI.app a través del Worker público deporte-total-360-api. La clave SPORTAPI_API_KEY debe guardarse en los secretos Actions del repositorio del Worker y se publica como secreto del Worker mediante Wrangler; nunca se incluye en el APK. Las rutas API-Sports existentes siguen en el Worker por compatibilidad. Su clave APISPORTS_KEY es independiente y solo es necesaria para esas rutas antiguas:
https://github.com/damian970609-lgtm/Deporte-Total-360-

Compilación:
El workflow configura Java y Flutter, genera Android en el runner, prepara permisos de red e icono, ejecuta flutter analyze y flutter test, compila el APK release y publica deporte-total-360-apk durante 30 días.

Límites y funcionamiento:
SportsAPI.app es la fuente principal de Agenda de hoy para Fútbol, Baloncesto, Béisbol, Hockey sobre hielo, Voleibol, MMA, Fútbol sala, Ciclismo, Deportes de motor y Balonmano, filtrados por las competiciones masculinas y femeninas elegidas. El Worker consulta los ocho deportes de partidos y los dos deportes de carreras; descarga páginas adicionales de ligas escalonadamente y refresca los marcadores globales cada 30 minutos. Las horas UTC del proveedor se convierten a la hora local del teléfono. MARCA queda como respaldo anterior cuando SPORTAPI_API_KEY no está configurada; no se utiliza como proveedor principal cuando SportsAPI está activo. El planificador central de Cloudflare descarga doce listas M3U y veinte guías XMLTV cada cinco minutos, de forma independiente de cualquier teléfono. Así continúa aunque el teléfono del propietario esté apagado o su APK esté desinstalada, una vez que el Worker esté desplegado. La búsqueda automática consulta únicamente los canales deportivos visibles que el propietario dejó seleccionados en Ajustes > Damián APK; utiliza la URL directa guardada para cada canal y no sustituye esa selección por listas genéricas. Diez minutos antes de cada evento busca una coincidencia XMLTV por equipos, participantes, evento y competición, comprueba todos los canales coincidentes y coloca la mejor señal española y la mejor inglesa en reproductores separados. Si solo existe una señal verificada, utiliza esa; si no hay idioma identificable, conserva una señal compatible como respaldo. El tablero Deportes en vivo mantiene ocho cuadros y muestra deporte, competición, evento/equipos, idioma y nombre del canal. Al comenzar un evento, una señal directa y comprobada ocupa un canal libre; el usuario pulsa Play para reproducirla. Los canales 2, 3 y 4 empiezan silenciados. La calidad Automática deja que ExoPlayer adapte la resolución al ancho de banda real de la conexión; el selector permite fijar cualquier resolución publicada por el manifiesto HLS/DASH. Al pulsar Play se abre pantalla completa reutilizando el mismo controlador; el primer atrás regresa a la miniatura sin detener el vídeo y el siguiente atrás detiene y libera el controlador. Los cuadros libres muestran el próximo evento y su horario con el estado ESPERANDO TRANSMISIÓN hasta que una señal comprobada esté en directo. Al detectar un estado final en la agenda o alcanzar la hora de finalización del evento/EPG, se detiene y libera el cuadro para el siguiente evento. La nueva fuente utiliza un almacén de eventos separado para no recuperar datos antiguos de la agenda anterior. Las APK instaladas actualizan la agenda y las asignaciones cada 45 segundos mientras la aplicación está abierta. El catálogo de canales seleccionados se conserva en memoria durante treinta minutos para reducir las consultas al servidor. Las señales se preparan diez minutos antes del comienzo y se asignan a los reproductores cuando el evento inicia. Firebase Cloud Messaging puede avisar a los dispositivos registrados que tengan las notificaciones activadas y abrir la pestaña Deportes en vivo al tocar el aviso. Android no permite forzar la reproducción de vídeo con la aplicación cerrada: el usuario debe abrir el aviso y pulsar Play. Se aceptan señales multimedia directas HLS (.m3u8), DASH (.mpd), Smooth Streaming y contenedores progresivos compatibles como MP4, MPEG-TS, WebM, Matroska y FLV; los enlaces relativos dentro de las playlists se resuelven usando la URL de la lista. Las páginas HTML, RTMP, DRM, credenciales y geobloqueos no se eluden. La disponibilidad depende del proveedor, la región, la conexión y la correspondencia de horarios y nombres, por lo que no se garantiza una señal para cada evento. Los resúmenes de YouTube se reproducen dentro de WebView.


## Activar notificaciones push

En Firebase crea una aplicación Android para el paquete de esta APK y copia los valores de configuración. Añade estos cuatro GitHub Actions Secrets en el repositorio de la APK: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID` y `FIREBASE_PROJECT_ID`. En el Worker configura el secreto `FCM_SERVICE_ACCOUNT_JSON` con el JSON de una cuenta de servicio de Firebase que tenga permiso para enviar mensajes FCM. La APK suscribe los dispositivos que activan los avisos al tema `deporte_total_360_live`; el Worker envía una sola notificación al tema, sin almacenar tokens personales. El secreto se guarda en Cloudflare, nunca en GitHub ni en el APK. Después de compilar e instalar la APK, cada usuario debe activar Notificaciones en Ajustes y conceder el permiso Android. El Worker registra el token del dispositivo y envía un aviso cuando una señal directa queda verificada. Tocar el aviso abre Deportes en vivo; el usuario inicia el vídeo con Play. Sin los secretos Firebase y Cloudflare, las notificaciones locales existentes siguen funcionando, pero no se envían avisos push.

 
## Catálogo de Canales deportivos

La nueva pestaña **Canales deportivos** muestra únicamente señales aprobadas y
publicadas desde el catálogo central de Cloudflare. El reproductor se desplaza
con la lista, admite HLS/MP4/MPEG-TS, controles ocultables a los cinco segundos,
bloqueo, pantalla completa, ajuste gestual de brillo de la aplicación y
volumen multimedia, además de calidad automática y pistas publicadas por el
proveedor. La calidad automática depende de las variantes disponibles en la
señal; no puede crear resoluciones que el proveedor no publique.

El acceso de diez pulsaciones sobre `DAMIÁN.APK` abre ahora el panel privado
de importación. Inicia sesión con Google. Añade una lista M3U HTTPS y confirma
que tienes autorización para distribuir las señales. Cloudflare descarga y
procesa la lista en segundo plano; los nuevos canales permanecen ocultos.
Desde el catálogo general puedes copiar su identificador o URL de señal y
activar/desactivar el ojo de visibilidad para publicar u ocultar cada señal
deportiva a todos los usuarios.

Configura `GOOGLE_OAUTH_CLIENT_ID` como secreto de GitHub Actions del
repositorio de la APK y del repositorio del Worker. Debe ser el **ID de cliente
OAuth Web**, no un secreto privado. En Google Cloud configura además el cliente
Android para el package name y la huella SHA-1 del certificado de firma
utilizado por GitHub Actions. El Worker comprueba el ID token, su audiencia y
correo verificado; solo `damian970609@gmail.com` administra el catálogo.
Los favoritos individuales se sincronizan en Cloudflare al iniciar sesión
con Google; sin iniciar sesión solo se guardan localmente.

El package name Android que ya usa la APK es `com.example.deporte_total_360`.
El workflow comprueba que no cambie y, después de compilar, publica en el resumen
del trabajo la huella SHA-1 exacta del certificado que firmó esa APK. Para crear
el cliente OAuth Android en Google Cloud, copia ambos datos desde ese resumen.
El workflow falla antes de compilar si falta `GOOGLE_OAUTH_CLIENT_ID` o si no
parece un ID OAuth Web; nunca imprime el valor del secreto.

El reproductor modifica el brillo de la aplicación, no el brillo global del
sistema, por lo que no necesita el permiso especial de Android. El control
gestual de volumen utiliza el volumen multimedia de Android. Las importaciones
solo aceptan playlists M3U HTTPS y direcciones HLS/MP4/MPEG-TS directas; no extraen
páginas de reproducción ni evaden DRM, cuentas o restricciones regionales.


### Idioma de los canales

En el panel privado de canales (diez pulsaciones en DAMIÁN.APK dentro de
Ajustes), cada señal tiene un selector de idioma: Español 🇪🇸, Inglés 🇺🇸 o
Sin definir. Al publicarse, la tarjeta de Canales deportivos muestra el
indicativo de idioma en su esquina superior. El idioma se guarda en Cloudflare
para que todos los usuarios vean la misma etiqueta.
## Configuración segura de Google Sign-In y firma Android

El inicio de sesión valida primero que el cliente OAuth Web incorporado en la APK
sea exactamente el mismo que está configurado en Cloudflare. Si no coincide,
la aplicación muestra un error concreto antes de abrir el selector de cuentas.
El ID de cliente OAuth es público; no se exponen ID tokens ni contraseñas.

### 1. Crear una llave privada de firma una sola vez

La compilación de distribución ya no guarda llaves Android en `actions/cache`.
El workflow necesita una llave privada estable, guardada únicamente como GitHub
Actions Secrets. En Termux instala Java y genera la llave:

```sh
pkg update
pkg install openjdk-17 coreutils
read -rsp 'Contraseña nueva para la llave: ' KEY_PASS
echo
keytool -genkeypair -v -storetype JKS \
  -keystore "$HOME/deporte-total-360-release.jks" \
  -alias dt360 -keyalg RSA -keysize 2048 -validity 10000 \
  -dname 'CN=Deporte Total 360,O=Deporte Total 360,C=GY' \
  -storepass "$KEY_PASS" -keypass "$KEY_PASS"
base64 -w 0 "$HOME/deporte-total-360-release.jks"
unset KEY_PASS
```

Copia el resultado de Base64 directamente a GitHub; no lo publiques ni lo envíes
por chat. En el repositorio abre Settings → Secrets and variables → Actions y
crea estos dos secretos:

- `ANDROID_KEYSTORE_BASE64`: el resultado completo del comando Base64.
- `ANDROID_KEYSTORE_PASSWORD`: la contraseña que acabas de crear.

Conserva una copia de seguridad cifrada del archivo `.jks` y su contraseña.
Si se pierde esta llave, no será posible crear actualizaciones firmadas con la
misma identidad de distribución. Los workflows de pull request no reciben la
llave privada ni publican APK.

### 2. Registrar Google OAuth

En Google Cloud Console, dentro del mismo proyecto, crea o revisa:

- Un cliente OAuth de tipo **Web application**. El valor de su Client ID debe
  estar configurado como `GOOGLE_OAUTH_CLIENT_ID` en los secretos de Actions
  de este repositorio y del repositorio Cloudflare `Deporte-Total-360-`.
- Un cliente OAuth de tipo **Android**, con package name
  `com.example.deporte_total_360` y el SHA-1 que el workflow publique en el
  resumen de la compilación ya firmada.

El cliente Web y el cliente Android pertenecen al mismo proyecto de Google
Cloud. Si la pantalla de consentimiento está en modo Testing, añade la cuenta
Google que va a iniciar sesión a la lista de usuarios de prueba.

### 3. Ejecutar la compilación

Después de guardar los dos secretos de firma, ejecuta el workflow
`Crear APK de DEPORTE TOTAL 360`. El workflow falla de forma segura si falta la
llave, si no puede leerla o si el SHA-1 de la APK no coincide con la llave usada.
Antes de crear la APK, el workflow compara el Client ID Web del secreto de
este repositorio con el publicado por Cloudflare y bloquea la compilación si no
coinciden. En el teléfono, la aplicación vuelve a comprobar la misma igualdad y
rechaza la autenticación antes de abrir Google cuando los dos no coinciden.

Los errores de Google muestran el código y la descripción disponibles sin
registrar contraseñas, credenciales ni tokens.
