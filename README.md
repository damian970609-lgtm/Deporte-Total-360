# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

Interfaz visible: Inicio, Agenda, En vivo, Canales deportivos y Ajustes. Agenda integra https://futbol-libre.cam/ y muestra la programación del día. Al desplegar un partido en Agenda, la app guarda los nombres y enlaces HTTPS de las opciones de transmisión que la propia página muestra. En vivo presenta los partidos capturados, con un cuadro por evento que abre la página original para conservar su reproductor integrado. Canales deportivos agrupa por nombre las opciones repetidas y permite abrir el reproductor asociado a cada partido. La app no extrae enlaces internos de vídeo, no descarga listas IPTV y no evita DRM, cuentas ni restricciones regionales.

Archivos principales:
- lib/main.dart: control de acceso y navegación visible de Inicio, Agenda, En vivo, Canales y Ajustes.
- lib/agenda_live_service.dart: guarda eventos, nombres de opciones y páginas HTTPS públicas capturadas al desplegar cada partido; ordena opciones por métricas de popularidad publicadas y conserva el orden de la Agenda cuando no existen métricas.
- lib/live_channels_screen.dart: tablero dinámico con un cuadro por cada partido capturado; abre la página original de la opción seleccionada y actualiza los eventos mientras la app permanece en primer plano.
- lib/live_media_format.dart y el motor de reproducción: compatibilidad con HLS, DASH, Smooth Streaming y vídeo/audio progresivo (MP4, M4A, FMP4, WebM, Matroska, MP3, Ogg, WAV, MPEG-TS, FLV, AAC, FLAC y AMR); las URLs proceden de los canales visibles y se cargan en el reproductor asignado.
- lib/public_chat_screen.dart: comunidad privada de compradores con alias estable por cuenta, denuncias de mensajes, revisión administrativa, eliminación moderada y sesión Google vinculada a licencias de pago.
- lib/app_update_screen.dart: consulta la versión publicada en GitHub Releases y abre la APK oficial; no depende de la cuota de Cloudflare ni de SportsAPI.
- lib/sports_api_service.dart: cliente legado de API-Sports/Worker, conservado para compatibilidad.
- lib/sportsapi_app_service.dart: conexión segura con las rutas SportsAPI.app del Worker para la Agenda, sin introducir claves en la APK.
- lib/notification_service.dart: recordatorios locales a 60, 30, 15 y 5 minutos para los eventos de la ventana de Agenda, sincronización incremental de avisos, Firebase Cloud Messaging y apertura de Deportes en vivo al tocar un aviso.
- lib/agenda_web_screen.dart: WebView de futbol-libre.cam, filtro visual de Agenda y puente JavaScript que captura horario, evento, estado, nombres y opciones HTTPS visibles cuando se despliega la ficha.
- lib/sportsapi_app_service.dart: paginación de partidos y carreras, alias de competiciones, caché con vencimientos diferenciados y actualización manual que solicita al Worker omitir su caché.
- lib/news_screen.dart: feed RSS y lector de noticias.
- lib/web_protection_policy.dart: reglas compartidas de protección web.
- lib/fantasy_screen.dart: módulo Fantasy.
- test/: pruebas automatizadas.

Recursos:
- assets/images/app_icon.png: icono de lanzamiento y emblema central de Inicio; el widget limita la resolución decodificada para reducir memoria.
- assets/images/home_reference.png: referencia visual conservada en el repositorio, no se incluye en los recursos de ejecución.
- assets/images/file_000000006048820e9e0720f1adf548f1.png: recurso histórico de ajustes conservado en el proyecto.
- Inicio usa widgets Flutter adaptables; el bisel del escudo incorpora un barrido luminoso animado y ajuste para pantallas compactas y orientación horizontal.

API deportiva:
Los servicios de automatización de eventos, deportes favoritos y estadísticas usan SportsAPI.app a través del Worker público deporte-total-360-api. La pestaña visible Agenda deportiva utiliza futbol-libre.cam. La clave SPORTAPI_API_KEY debe guardarse en los secretos Actions del repositorio del Worker y se publica como secreto del Worker mediante Wrangler; nunca se incluye en el APK. Las rutas API-Sports existentes siguen en el Worker por compatibilidad. Su clave APISPORTS_KEY es independiente y solo es necesaria para esas rutas antiguas:
https://github.com/damian970609-lgtm/Deporte-Total-360-

Compilación:
El workflow configura Java y Flutter, genera Android en el runner, prepara permisos de red e icono, ejecuta flutter analyze y flutter test, compila el APK release y publica deporte-total-360-apk durante 30 días.

Límites y funcionamiento:
La pestaña Agenda deportiva integra futbol-libre.cam y deja únicamente la programación del día. El puente de Agenda captura las fichas de los eventos, incluidos sus nombres de canales de referencia y el estado de finalización. Deportes en vivo consulta el catálogo público del propietario, conserva solo los canales marcados como deportivos y visibles, y compara sus nombres con los publicados para cada evento. La preparación comienza cinco minutos antes del inicio. Se asigna una sola señal coincidente por evento y no se repite una misma URL en dos cuadros simultáneos. El reproductor se activa a partir de la hora de inicio; el primero puede comenzar automáticamente y los demás quedan disponibles para iniciar manualmente. Al finalizar el evento, su tarjeta se retira y el espacio queda libre para el próximo partido. La comprobación se repite cada 15 segundos mientras la app permanece abierta y en primer plano; Android no ejecuta este temporizador después de cerrar por completo la APK. Si no se captura la ficha o no hay coincidencia en los canales visibles, el cuadro permanece pendiente sin inventar una fuente. La integración no extrae URLs de páginas externas ni evade DRM, credenciales o geobloqueos.


## Activar notificaciones push

En Firebase crea una aplicación Android para el paquete de esta APK y copia los valores de configuración. Añade estos cuatro GitHub Actions Secrets en el repositorio de la APK: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID` y `FIREBASE_PROJECT_ID`. En el Worker configura el secreto `FCM_SERVICE_ACCOUNT_JSON` con el JSON de una cuenta de servicio de Firebase que tenga permiso para enviar mensajes FCM. La APK suscribe los dispositivos que activan los avisos al tema `deporte_total_360_live`; el Worker envía una sola notificación al tema, sin almacenar tokens personales. El secreto se guarda en Cloudflare, nunca en GitHub ni en el APK. Después de compilar e instalar la APK, cada usuario debe activar Notificaciones en Ajustes y conceder el permiso Android. El Worker registra el token del dispositivo y envía un aviso cuando una señal directa queda verificada. Tocar el aviso abre la aplicación en Inicio; la pantalla de reproducción permanece fuera de la navegación Inicio / Agenda deportiva. Sin los secretos Firebase y Cloudflare, las notificaciones locales existentes siguen funcionando, pero no se envían avisos push.

 
## Canales deportivos desde la Agenda

La pestaña **Canales deportivos** no depende del catálogo IPTV. Agrupa los nombres únicos de las opciones que Fútbol Libre publica al desplegar las fichas de partido y conserva las páginas HTTPS asociadas a cada evento. Un canal puede aparecer una sola vez en la lista y mostrar sus diferentes partidos debajo. Las opciones con una métrica pública de popularidad se ordenan primero; si el sitio no publica esa métrica, se conserva el orden original.

La pantalla **En vivo** muestra todos los partidos que la app haya capturado, sin el límite anterior de ocho tarjetas. Cada tarjeta abre la página de reproducción original dentro de la APK para mantener el reproductor de esa fuente. Solo el primer cuadro se inicia automáticamente para reducir el uso simultáneo de memoria y datos; los demás se cargan al pulsar reproducir. La app revisa los eventos cada 15 segundos mientras permanece abierta y en primer plano.

Para revelar las opciones que el sitio mantiene dentro de una ficha, abre el partido en Agenda y despliega su lista de canales. La app solo registra las opciones visibles publicadas por la página; no extrae enlaces internos de vídeo ni evade DRM, credenciales o bloqueos regionales. Los datos y servicios antiguos se conservan en el repositorio para compatibilidad, pero no se usan para poblar estas dos pestañas.


El package name Android que ya usa la APK es `com.example.deporte_total_360`.
El workflow comprueba que no cambie y, después de compilar, publica en el resumen
del trabajo la huella SHA-1 exacta del certificado que firmó esa APK. Para crear
el cliente OAuth Android en Google Cloud, copia ambos datos desde ese resumen.
El workflow falla antes de compilar si falta `GOOGLE_OAUTH_CLIENT_ID` o si no
parece un ID OAuth Web; nunca imprime el valor del secreto.
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

