DEPORTE TOTAL 360° — paquete de interfaz

Incluye:
- app/lib/main.dart: pantalla principal, menú inferior, accesos a agenda, señal, Telegram, WhatsApp, donaciones y ajustes.
- app/lib/web_agenda_screen.dart: pantalla de agenda web con controles atrás y recarga.
- app/pubspec.yaml: dependencias y registro de recursos/icono.
- app/assets/images/logo.png: logotipo enviado.
- app/assets/images/app_icon.png: imagen para el icono Android.
- app/assets/images/home_reference.png: imagen de referencia visual.

IMPORTANTE:
1. Haz copia de seguridad de tus archivos actuales antes de sustituirlos.
2. Este pubspec mantiene las dependencias observadas en el archivo consultado; verifica que no falte ninguna dependencia adicional que use tu proyecto.
3. Desde la carpeta app ejecuta:
   flutter pub get
   dart run flutter_launcher_icons
   flutter analyze
   flutter build apk --release
4. La dirección de señal en main.dart es la que figuraba en la propuesta anterior; no se ha validado que esté activa o autorizada.
5. Telegram queda como https://t.me/ hasta que tengas tu canal.
6. La página externa puede impedir reproducción incrustada o abrir otros dominios. El código no puede forzar sus políticas ni garantizar que el vídeo funcione dentro de la app.
7. No se ha compilado esta aplicación en este entorno.