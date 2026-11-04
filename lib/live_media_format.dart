/// Formatos directos que los reproductores Android pueden entregar a ExoPlayer.
/// Una lista .m3u es un catálogo y no es, por sí sola, una señal de vídeo.
enum LiveMediaFormat {
  hls,
  dash,
  smoothStreaming,
  progressive,
}

/// Clasifica por la ruta real de la URL; Uri.path separa correctamente
/// los parámetros de consulta (tokens, firmas, etc.) de la extensión.
LiveMediaFormat? liveMediaFormatForUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }

  final path = uri.path.toLowerCase();
  if (path.endsWith('.m3u8')) return LiveMediaFormat.hls;
  if (path.endsWith('.mpd')) return LiveMediaFormat.dash;
  if (path.endsWith('.ism/manifest') ||
      path.endsWith('.isml/manifest')) {
    return LiveMediaFormat.smoothStreaming;
  }

  const progressiveExtensions = <String>[
    '.mp4',
    '.m4v',
    '.mov',
    '.mkv',
    '.webm',
    '.ts',
    '.mpeg',
    '.mpg',
    '.flv',
  ];
  if (progressiveExtensions.any(path.endsWith)) {
    return LiveMediaFormat.progressive;
  }
  return null;
}
