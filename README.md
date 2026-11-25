# ShadowKeys · GTA San Andreas Mobile

Aplicación Android nativa en Kotlin para consultar y enviar los códigos de trucos de GTA San Andreas Mobile. El objetivo de compatibilidad es el juego Rockstar 2.11.311 en Android 15, en un Blackview WAVE 9C.

## Estado del proyecto

**Primera base de desarrollo.** Incluye el catálogo de 83 códigos de la edición móvil, búsqueda, filtros por categoría, copia de códigos, panel flotante y un servicio de entrada mediante Shizuku UserService.

La compatibilidad con el juego 2.11.311 todavía no está demostrada. La APK de CI es una compilación de depuración para pruebas, no una versión final verificada.

## Funciones

- Catálogo con 83 códigos móviles en siete categorías.
- Búsqueda por nombre, descripción o código.
- Copiar cualquier contraseña al portapapeles.
- Burbuja flotante movible y panel con todos los trucos.
- Ventanas superpuestas no enfocables para intentar conservar el foco de GTA.
- Comprobación de la versión instalada del paquete Rockstar.
- Prueba de envío dentro de un campo de texto de ShadowKeys.
- Inyección global mediante Shizuku UserService, si Shizuku se inició con los permisos ADB o root apropiados.

## Requisito real para enviar teclas a GTA

Android no concede a una aplicación normal el permiso de sistema INJECT_EVENTS. Un teclado IME puede escribir en campos de texto compatibles, pero GTA San Andreas Mobile no ofrece un campo de texto normal para introducir los trucos. Por esa razón, ShadowKeys no intenta simular un teclado mediante un servicio de accesibilidad ni ejecuta el comando input desde el UID normal de la aplicación.

Para la ruta de inyección incluida en este proyecto se necesita Shizuku, iniciado con identidad ADB mediante Depuración inalámbrica, o una configuración root compatible. Después, el usuario debe conceder permiso a ShadowKeys desde la propia interfaz de Shizuku. Sin ese permiso, la app conserva el catálogo y la opción de copiar códigos, pero no puede inyectar teclas globalmente.

Guía oficial de Shizuku: https://shizuku.rikka.app/  
API de Shizuku: https://github.com/RikkaApps/Shizuku-API

La API 13.1.5 se usa mediante UserService. El servicio ejecuta cada tecla como un evento Android KEYCODE y devuelve un resultado real de cada comando. El resultado positivo significa que Android aceptó los comandos; no demuestra por sí solo que el juego haya activado el truco.

## Catálogo

Los 83 códigos y sus categorías se basan en la lista de trucos de la edición móvil publicada en GTADb:
https://gtadb.io/gta-san-andreas/cheats/mobile

Hay diferencias entre los códigos de la edición móvil y los códigos clásicos de PC. No se deben sustituir automáticamente unos por otros. La lista debe contrastarse en el dispositivo con la compilación 2.11.311. Algunos trucos pueden desactivar logros, causar fallos de misión o alterar permanentemente una partida guardada; realiza una copia de seguridad y evita guardar con disturbios o ataques de peatones activos.

## Compilación

El workflow de GitHub Actions ejecuta las pruebas unitarias y genera una APK de depuración:

1. Abre Actions en la rama shadowkeys-rebuild-20261125.
2. Ejecuta Build ShadowKeys Android o espera a que termine el flujo automático.
3. Descarga el artefacto ShadowKeys-debug.
4. Instala app-debug.apk en Android.

Comando local:
gradle --no-daemon :app:testDebugUnitTest :app:assembleDebug

## Identificadores

- Nombre: ShadowKeys
- Package name: com.damian.shadowkeys
- minSdk: 26
- targetSdk: 35
- compileSdk: 35
- Java: 17
- Kotlin Gradle Plugin: 2.2.20
- Android Gradle Plugin: 8.9.1
- Gradle: 8.11.1
