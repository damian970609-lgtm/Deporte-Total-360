# DEPORTE TOTAL 360° — proyecto Flutter

Proyecto fuente para compilar una APK Android desde GitHub Actions. La interfaz utiliza el estilo oscuro/neón de la referencia, incluye la imagen de marca, navegación inferior, accesos a transmisiones, agenda, Telegram provisional, WhatsApp, donaciones y ajustes.

## Estructura

```text
.
├── .github/workflows/build-apk.yml
├── app/
│   ├── lib/
│   │   ├── main.dart
│   │   └── web_agenda_screen.dart
│   ├── assets/images/
│   │   ├── app_icon.png
│   │   ├── home_reference.png
│   │   └── logo.png
│   └── pubspec.yaml
└── README.md
```

## Crear la APK desde GitHub

1. Sube el contenido de esta carpeta al directorio raíz del repositorio.
2. Abre **Actions** en GitHub y selecciona **Crear APK de DEPORTE TOTAL 360**.
3. Pulsa **Run workflow** y espera a que termine correctamente.
4. Abre la ejecución completada y descarga el artefacto `deporte-total-360-apk`. Dentro estará `app-release.apk`.

El flujo genera la plataforma Android, instala las dependencias, configura el icono desde `app/assets/images/app_icon.png`, ejecuta `flutter analyze` y compila la APK release.

## Enlaces que puedes configurar

- Agenda web: constante `_agendaUrl` en `app/lib/web_agenda_screen.dart` (ahora usa `https://futbol-libre.cam/`, según la solicitud).
- Canal de Telegram: constante `telegramUrl` en `app/lib/main.dart` (por ahora `https://t.me/`; reemplázala cuando tengas el enlace real del canal).
- Señal propia en vivo: constante `streamUrl` en `app/lib/main.dart`. Debe ser una URL de transmisión que tengas derecho a distribuir.
- WhatsApp del creador: constante `whatsappUrl` en `app/lib/main.dart`.

## Comportamiento de la agenda

La agenda se carga en un navegador integrado. Los enlaces web HTTP/HTTPS permanecen dentro de la aplicación y el botón **Atrás** permite regresar a la página anterior; la barra superior muestra el dominio actual para no ocultar la identidad del sitio. La página externa decide qué partidos y botones de reproducción muestra. No se puede garantizar que todos los reproductores funcionen en una WebView: depende de las políticas, cookies, disponibilidad y compatibilidad de cada proveedor. Usa fuentes deportivas autorizadas.

## Compilación local (opcional)

Desde `app/` con Flutter instalado:

```bash
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter build apk --release
```

La APK local se genera en `app/build/app/outputs/flutter-apk/app-release.apk`.

## Notas

- No se incluyen claves ni archivos privados de Firebase. El código actual de esta versión no importa Firebase, por lo que no los necesita para compilar.
- El flujo de GitHub crea `app/android/` durante la compilación; no necesitas subir archivos generados de Android para usar el flujo.
- El canal de Telegram es provisional hasta que se configure el enlace verdadero.