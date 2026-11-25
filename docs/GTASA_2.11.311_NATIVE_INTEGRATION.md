# ShadowKeys — integración nativa para GTA San Andreas 2.11.311

## Objetivo

Crear una copia modificada de GTA San Andreas que incluya un panel de trucos dentro del propio proceso del juego. Al pulsar una opción, el complemento llamará a la función nativa del juego correspondiente. La ruta final no debe depender de ADB, Shizuku, depuración inalámbrica, Wi-Fi ni root.

La instalación original del usuario debe permanecer intacta. No se modificará `main` ni la rama de Deporte Total 360°.

## Objetivo de compatibilidad que hay que verificar

- Paquete informado por el usuario: `com.rockstargames.gtasa`
- Versión informada: `2.11.311`
- ABI candidata: `arm64-v8a`
- Biblioteca de juego esperada para la compilación oficial 2.11.311: `lib/arm64-v8a/libGame.so`

La documentación pública de proyectos que trabajan con 2.11.311 identifica esa biblioteca como el binario de juego ARM64. Un proyecto comunitario de modificaciones, WNPatcher, declara compatibilidad con GTA:SA/SA-MP 2.10 y 2.11 en ARMv7 y ARM64. Estos datos hacen viable investigar un complemento nativo para la versión, pero no demuestran todavía que el APK instalado desde APKWARD tenga el mismo binario ni la misma firma.

Referencias de investigación:
- https://github.com/isweikton/WNPatcher
- https://github.com/isweikton/gtasa-2.11.311-dump
- https://github.com/AndroidModLoader/AndroidModLoader
- https://github.com/kuzia15/SAMP-Mobile/tree/GTA-2.11
- https://github.com/NaGaa95/gtasa_nx

## Arquitectura propuesta

1. **Identificación del binario:** verificar metadatos, ABI y SHA-256 de `libGame.so`. No se usarán offsets de otra versión.
2. **Bootstrap de la copia de juego:** incorporar un cargador nativo al paquete modificado y ejecutarlo después de que Android cargue `libGame.so`.
3. **Complemento nativo:** compilar `libShadowKeys.so` para ARM64. El punto de entrada debe comprobar que la versión y el hash del binario son los esperados; ante una diferencia, se desactiva sin escribir memoria.
4. **Menú dentro del juego:** dibujar un botón discreto y un panel táctil con categorías, buscador y confirmación visual. No se usará una superposición de otra aplicación ni inyección global de teclas.
5. **Activación de trucos:** mapear cada opción a una función o mecanismo nativo comprobado para esta compilación. Los códigos alfanuméricos solo se mostrarán como información de referencia; no se simulará que funcionan si no se ha verificado su efecto.
6. **Instalación separada:** preparar primero una copia con identificador de paquete distinto para no sustituir la instalación original. La ruta de los datos/OBB y las partidas debe comprobarse antes de permitir importar datos.

## Límites de seguridad y calidad

- No descargar ni incluir en este repositorio el APK, los recursos ni la biblioteca propietaria del juego.
- No instalar ni sustituir automáticamente el juego original.
- No usar direcciones de memoria copiadas de otra versión o ABI.
- No ejecutar comandos de shell arbitrarios.
- No guardar automáticamente una partida con trucos de caos activos.
- La primera compilación será una prueba de carga y registro; no se anunciarán trucos como funcionales hasta probarlos en el teléfono.

## Material necesario para continuar

Se necesita una copia local del APK instalado o, como mínimo, el archivo `lib/arm64-v8a/libGame.so` extraído de ese mismo APK. El archivo debe venir de la versión que realmente está instalada en el Blackview. Con él se podrá contrastar el hash conocido, identificar diferencias del paquete APKWARD y confirmar si se puede usar el mismo mapa de funciones.

No subir contraseñas, PIN de depuración ni datos de cuenta. No se necesita ningún PIN ni acceso ADB para esta integración.
