# Deporte Total 360°

Aplicación Android de dos secciones:

- **Agenda:** muestra la programación de https://futbol-libre.cam/ y oculta el contenido que no pertenece a la agenda.
- **Transmisión en vivo:** mantiene un reproductor fijo arriba y coloca debajo los eventos activos y próximos según el horario capturado en Agenda.

## Funcionamiento

La app lee datos de programación (partido, competición, hora y nombres de canales publicados). Para reproducir, busca una coincidencia en el catálogo propio de canales del proyecto y solo acepta URLs multimedia directas HTTPS compatibles, como HLS (.m3u8), DASH (.mpd) o vídeo progresivo.

No extrae enlaces de transmisión ocultos de sitios de terceros, no evita redirecciones protegidas y no intenta saltar restricciones de acceso o de región. Para reproducir una señal, debe estar disponible en el catálogo propio y contar con autorización de uso.

Los eventos se guardan localmente para que el módulo En vivo pueda organizar la lista aunque la agenda tarde en actualizarse. El horario se interpreta con la hora local del teléfono.

## Compilar

El flujo de GitHub Actions ejecuta análisis, pruebas y generación del APK release. Abre Actions → Crear APK de Deporte Total 360 → Run workflow para iniciar la compilación manualmente.
