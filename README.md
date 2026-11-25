# ShadowKeys · GTA San Andreas Mobile

Aplicación Android nativa en Kotlin para consultar los 83 códigos de trucos de GTA San Andreas Mobile y enviarlos mediante el servicio ADB inalámbrico integrado de Android.

## Objetivo de compatibilidad

- Juego esperado: Rockstar GTA San Andreas clásico, paquete `com.rockstargames.gtasa`, versión informada 2.11.311.
- Dispositivo de referencia: Android 15.
- No modifica ni reemplaza los archivos del juego y no accede a sus partidas guardadas.
- La compatibilidad real de cada código con la compilación 2.11.311 debe confirmarse en el teléfono. Una respuesta correcta de ADB confirma que Android recibió las teclas, no que GTA activó el truco.

## Enviar trucos sin instalar Shizuku

ShadowKeys integra el cliente Kotlin ADB `Kadb` y se conecta al servicio `adbd` del mismo teléfono. Esto evita instalar Shizuku, pero Android no permite a una aplicación normal inyectar teclas en otra aplicación. Por eso sigue siendo necesaria una autorización única desde Opciones de desarrollador / Depuración inalámbrica. No requiere root ni PC; el emparejamiento se realiza en el propio teléfono.

### Emparejamiento inicial

1. Activa Opciones de desarrollador: Ajustes → Acerca del teléfono → pulsa varias veces «Número de compilación» hasta que Android indique que se activaron.
2. Abre Ajustes → Sistema (o Ajustes adicionales) → Opciones de desarrollador → Depuración inalámbrica y actívala.
3. Dentro de Depuración inalámbrica, pulsa «Emparejar dispositivo con código». Deja esa pantalla abierta.
4. En ShadowKeys, usa la IP indicada por el sistema (prueba primero `127.0.0.1`), escribe el puerto de emparejamiento y el PIN de seis cifras que aparecen en esa ventana y pulsa «1 · EMPAREJAR ESTE TELÉFONO».
5. Regresa a la pantalla principal de Depuración inalámbrica. Copia el puerto que aparece junto a «Dirección IP y puerto» en el campo «Puerto de conexión» de ShadowKeys.
6. Pulsa «2 · CONECTAR A ADB». Cuando el estado indique que ADB está conectado, activa el panel flotante y abre GTA.

El puerto de emparejamiento y el puerto de conexión son distintos. Pueden cambiar cuando Android reinicia o vuelve a iniciar Depuración inalámbrica; si deja de conectar, consulta el puerto actual y vuelve a conectar. Si `127.0.0.1` no funciona en la ROM del teléfono, escribe la dirección IP local que muestre Android.

### Seguridad y alcance

- La pantalla de emparejamiento de Android muestra el PIN de autorización; no compartas ese PIN.
- ShadowKeys guarda su identidad ADB en el almacenamiento privado de la aplicación y solo ejecuta comandos `input keyevent` construidos a partir de códigos alfanuméricos del catálogo. No expone una consola de comandos libre.
- La conexión ADB puede realizar operaciones con identidad shell mientras la autorización siga vigente. Desactiva Depuración inalámbrica cuando no la estés usando.
- Si ADB no está conectado, el catálogo y la función de copiar códigos siguen disponibles.
- La ventana flotante permanece sin foco para no tomar el teclado del juego.
- Los trucos pueden romper misiones o afectar la partida activa. No guardes la partida principal con disturbios ni peatones agresivos activos.

## Catálogo móvil revisado

El catálogo está contrastado con la lista específica de 83 códigos para móviles: 12 de jugador, 6 de armas, 21 de vehículos, 4 de nivel policial, 14 de mundo y tráfico, 11 de clima y hora, y 15 de diversión.

No se mezclan listas de PC ni de Definitive Edition. Dos códigos de depuración/interfaz que aparecen en algunas referencias (`KRRIHBT` y `JQFUDUB`) se mantienen fuera de los 83 trucos normales porque son funciones de diagnóstico, no trucos de juego generales.

Los códigos específicos de móvil que deben conservarse son, entre otros: invencibilidad completa `GONPXWR`, set de armas 4 `BIEUHQY`, avanzar cuatro horas `YACKMWS` y completar la misión actual `BYIXZIY`. Este último no funciona en todas las misiones.

## Compilación

GitHub Actions ejecuta las pruebas unitarias y genera una APK debug:

```bash
gradle --no-daemon :app:testDebugUnitTest :app:assembleDebug
```

Artefacto: `ShadowKeys-debug`.

## Identificadores

- Nombre: ShadowKeys
- Package name: `com.damian.shadowkeys`
- minSdk: 26
- targetSdk / compileSdk: 35
- Java: 17
- Kotlin Gradle Plugin: 2.2.20
- Android Gradle Plugin: 8.9.1
- Gradle: 8.11.1
- Cliente ADB: `com.flyfishxu:kadb:1.2.1` (Apache 2.0)
