# DEPORTE TOTAL 360° — proyecto Flutter

Aplicación Android en Flutter. El APK se compila en GitHub Actions; la carpeta Android se genera en el runner.

Interfaz visible de esta edición: Inicio, Agenda deportiva y Deportes en vivo. Agenda deportiva integra https://futbol-libre.cam/ y muestra únicamente la programación bajo un encabezado propio de Deporte Total 360° con la fecha local del teléfono. Deportes en vivo presenta ocho reproductores vacíos preparados para una nueva solución de transmisión. Se retiraron de esta interfaz la selección antigua de eventos y señales, las listas de fuentes M3U, los favoritos de transmisión y la configuración XMLTV/EPG; al abrir la sección se limpian también esos valores locales heredados. La nueva forma de cargar transmisiones se desarrollará posteriormente. Los módulos Canales deportivos, Mister Fantasy, Chat, Actualización y Ajustes permanecen fuera de la navegación; no se borran las listas IPTV del catálogo ni sus favoritos.

Archivos principales:
- lib/main.dart: control de acceso y navegación visible de Inicio, Agenda deportiva y Deportes en vivo.
- lib/live_channels_screen.dart: pantalla Deportes en vivo con ocho reproductores preparados; el flujo antiguo de configuración y asignación automática de señales está desactivado en la interfaz. La conexión de una nueva fuente de transmisión queda pendiente de una futura implementación.
- lib/live_media_format.dart y el motor de reproducción conservado: compatibilidad técnica con HLS, DASH, Smooth Streaming y vídeo progresivo; no se carga ninguna señal hasta integrar el nuevo método de transmisión.
- lib/public_chat_screen.dart: comunidad privada de compradores con alias estable por cuenta, denuncias de mensajes, revisión administrativa, eliminación moderada y sesión Google vinculada a licencias de pago.
- lib/app_update_screen.dart: consulta la versión publicada en GitHub Releases y abre la APK oficial; no depende de la cuota de Cloudflare ni de SportsAPI.
- lib/sports_api_service.dart: cliente legado de API-Sports/Worker, conservado para compatibilidad.
- lib/sportsapi_app_service.dart: conexión segura con las rutas SportsAPI.app del Worker para la Agenda, sin introducir claves en la APK.
- lib/notification_service.dart: recordatorios locales a 60, 30, 15 y 5 minutos para los eventos de la ventana de Agenda, sincronización incremental de avisos, Firebase Cloud Messaging y apertura de Deportes en vivo al tocar un aviso.
- lib/agenda_web_screen.dart: WebView de futbol-libre.cam con filtro visual para dejar la programación del día y ocultar la marca y los bloques ajenos a la agenda.
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
La pestaña visible Agenda deportiva integra futbol-libre.cam y deja únicamente la programación del día. Los servicios de agenda y estadísticas siguen consultando SportsAPI.app a través del Worker para los deportes configurados; las horas se convierten a la hora local del teléfono. El filtro visual de Agenda oculta los bloques de canales, navegación, instrucciones y preguntas frecuentes del sitio. La pestaña Deportes en vivo ya no consulta horarios para asignar señales ni carga listas M3U o guías XMLTV/EPG. Muestra ocho cuadros vacíos con el estado SEÑAL PENDIENTE y conserva el motor de reproducción para una integración posterior; hasta que se incorpore el nuevo método no se intenta reproducir ninguna señal. Las páginas HTML, RTMP, DRM, credenciales y geobloqueos no se eluden.


## Activar notificaciones push

En Firebase crea una aplicación Android para el paquete de esta APK y copia los valores de configuración. Añade estos cuatro GitHub Actions Secrets en el repositorio de la APK: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID` y `FIREBASE_PROJECT_ID`. En el Worker configura el secreto `FCM_SERVICE_ACCOUNT_JSON` con el JSON de una cuenta de servicio de Firebase que tenga permiso para enviar mensajes FCM. La APK suscribe los dispositivos que activan los avisos al tema `deporte_total_360_live`; el Worker envía una sola notificación al tema, sin almacenar tokens personales. El secreto se guarda en Cloudflare, nunca en GitHub ni en el APK. Después de compilar e instalar la APK, cada usuario debe activar Notificaciones en Ajustes y conceder el permiso Android. El Worker registra el token del dispositivo y envía un aviso cuando una señal directa queda verificada. Tocar el aviso abre la aplicación en Inicio; la pantalla de reproducción permanece fuera de la navegación Inicio / Agenda deportiva. Sin los secretos Firebase y Cloudflare, las notificaciones locales existentes siguen funcionando, pero no se envían avisos push.

 
## Módulo conservado de Canales deportivos (no visible en esta edición)

El módulo **Canales deportivos** conserva la lógica para mostrar únicamente señales aprobadas y
publicadas desde el catálogo central de Cloudflare. El reproductor se desplaza
con la lista y admite HLS, DASH, Smooth Streaming y los formatos progresivos
que clasifica el proyecto, con controles ocultables a los cinco segundos,
bloqueo, pantalla completa, ajuste gestual de brillo de la aplicación y
volumen multimedia, además de calidad automática y pistas publicadas por el
proveedor. La calidad automática depende de las variantes disponibles en la
señal; no puede crear resoluciones que el proveedor no publique.

El panel privado de importación y sus funciones se conservan en el código, pero
no están accesibles desde la interfaz de Inicio único porque Ajustes permanece
oculto en esta edición. No se eliminan ni se reinicializan las listas o los
datos existentes. En la versión completa, el panel permite iniciar sesión con
Google y añadir listas M3U, PLS, XSPF/XML, JSON o TXT mediante HTTPS; confirma
que tienes autorización para distribuir las señales. Cloudflare descarga y procesa las listas en segundo plano; el inventario privado conserva
todos los canales compatibles, tanto deportivos como generales. La clasificación
deportiva no descarta entradas: solo determina cuáles pueden publicarse en la
pestaña pública Canales deportivos. El panel privado muestra el total y pagina
el inventario completo; el total se confirma al cargar el último bloque. Los nuevos
canales permanecen ocultos. Desde el catálogo privado puedes probar una señal,
copiar su identificador o URL, asignar idioma, publicar u ocultar los canales
deportivos y eliminar un canal permanentemente. El borrado bloquea la URL para que las actualizaciones
posteriores no vuelvan a añadir esa misma señal.

Configura `GOOGLE_OAUTH_CLIENT_ID` como secreto de GitHub Actions del
repositorio de la APK y del repositorio del Worker. Debe ser el **ID de cliente
OAuth Web**, no un secreto privado. En Google Cloud configura además el cliente
Android para el package name y la huella SHA-1 del certificado de firma
utilizado por GitHub Actions. El Worker comprueba el ID token, su audiencia y
correo verificado; solo `damian970609@gmail.com` administra el catálogo.
Los favoritos individuales se sincronizan en Cloudflare al iniciar sesión
con Google; sin iniciar sesión solo se guardan localmente. La aplicación también guarda localmente una
instantánea de hasta 2.000 canales publicados. Si Cloudflare agota la cuota o
pierde conexión, la lista y el reproductor siguen mostrando la última copia
disponible en ese teléfono; al restablecerse el servicio se actualiza de nuevo.
La sincronización de favoritos fusiona lo local con lo remoto para no borrar
selecciones cuando una respuesta del servidor llegue vacía o incompleta.

El package name Android que ya usa la APK es `com.example.deporte_total_360`.
El workflow comprueba que no cambie y, después de compilar, publica en el resumen
del trabajo la huella SHA-1 exacta del certificado que firmó esa APK. Para crear
el cliente OAuth Android en Google Cloud, copia ambos datos desde ese resumen.
El workflow falla antes de compilar si falta `GOOGLE_OAUTH_CLIENT_ID` o si no
parece un ID OAuth Web; nunca imprime el valor del secreto.

El reproductor modifica el brillo de la aplicación, no el brillo global del
sistema, por lo que no necesita el permiso especial de Android. El control
gestual de volumen utiliza el volumen multimedia de Android. El reproductor
comparte el mismo clasificador de formatos que el catálogo: HLS, DASH, Smooth
Streaming y vídeo progresivo compatible, siempre mediante enlaces HTTPS directos.
No extrae páginas de reproducción ni evade DRM, cuentas o restricciones regionales.


### Idioma de los canales

En la configuración conservada del panel privado de canales, cada señal tiene
un selector de idioma: Español 🇪🇸, Inglés 🇺🇸 o
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

