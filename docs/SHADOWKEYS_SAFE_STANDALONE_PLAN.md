# ShadowKeys — plan seguro y límites Android 15

## Decisión de seguridad
- La instalación original de GTA San Andreas del usuario debe permanecer intacta.
- No escribir, borrar ni reemplazar archivos de `com.rockstargames.gtasa`.
- No desinstalar GTA original durante pruebas.
- No alterar ni fusionar cambios en `main` ni en Deporte Total 360.
- Cualquier ensayo nativo se hará únicamente contra una copia separada, identificada y desechable; se conservarán aparte los datos y partidas originales.

## Restricciones verificadas
- Dispositivo objetivo: Android 15, ARM64.
- El usuario no dispone de root, segundo teléfono, PC ni red Wi-Fi para iniciar Wireless Debugging.
- La aplicación ShadowKeys anterior usa Kadb y requiere el servicio Android Wireless Debugging; esa ruta no resuelve la condición actual del usuario.
- Una aplicación Android corriente no puede enviar KeyEvents arbitrarios a otra aplicación. `INJECT_EVENTS` es un permiso de firma del sistema.
- `AccessibilityService.dispatchGesture()` simula gestos táctiles, no inyecta teclas de teclado. Puede automatizar una interfaz de entrada solamente si el juego expone una superficie táctil o un campo accesible adecuado.
- Un panel flotante independiente puede mostrar controles, pero por sí solo no puede escribir códigos dentro del proceso de GTA.

## Evidencia del archivo suministrado
Se recibió `libGame.so` del usuario:
- ELF 64-bit AArch64.
- SHA-256: `4c6a7445e30b27afdda781302e4db9bac89c28fc1181b68b1eef16f84d6a282e`.
- La tabla de símbolos del archivo contiene funciones de CCheat, entre ellas:
  - `CCheat::AddToCheatString(char)` — dirección relativa observada: `0x3e12c4`.
  - `CCheat::JetpackCheat()` — `0x3e06f4`.
  - `CCheat::MoneyArmourHealthCheat()` — `0x3df5d4`.
  - `CCheat::TogglePlayerInvincibility()` — `0x3df520`.
- Estas direcciones relativas solo tienen sentido dentro del proceso que cargó esa misma biblioteca y no son una vía de control desde una APK externa.

## Rutas técnicas permitidas
1. **Primera opción, totalmente externa:** comprobar si esta compilación del juego expone un cuadro de entrada de trucos accesible a Android. Si existe, desarrollar ShadowKeys como app separada con panel flotante y automatización de ese campo; validar en dispositivo antes de prometer envío automático.
2. **Si no existe tal campo:** la única ruta sin root ni ADB para ejecutar trucos es cargar un módulo nativo dentro del proceso de un clon de GTA. Eso requiere un cargador integrado en la copia de prueba y un paquete de instalación separado. No debe modificarse el GTA original.
3. Si el usuario no acepta un clon con cargador, limitar ShadowKeys a catálogo, búsqueda y copia de códigos; no simular que los trucos se activan.

## Fase siguiente obligatoria
Antes de modificar código o generar APK:
- Confirmar en el juego si aparece un campo/menú real de «Introducir código de truco» en Pausa > Opciones > Accesibilidad.
- Si no aparece, explicar la necesidad del clon con cargador y pedir autorización explícita antes de preparar ese paquete.
- No copiar offsets de otras versiones/ABI ni utilizar un binario distinto del SHA-256 registrado.
- La primera compilación nativa será una prueba no-op de carga, sin escrituras en memoria ni activación de trucos.
