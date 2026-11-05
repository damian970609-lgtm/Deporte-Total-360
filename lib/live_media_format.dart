/// Formatos directos que los reproductores Android pueden entregar a ExoPlayer.
/// Una lista .m3u es un catálogo y no es, por sí sola, una señal de vídeo.
enum LiveMediaFormat {
  hls,
  dash,
  smoothStreaming,
  progressive,
  /// Endpoint HTTP de transmisión sin extensión visible.
  other,
}

bool _isExtensionlessLiveEndpoint(Uri uri) {
  final segments = uri.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
  const markers = <String>{'live', 'stream', 'streams', 'channel', 'channels'};
  final markerIndex = segments.indexWhere(
    (segment) => markers.contains(segment.toLowerCase()),
  );
  if (markerIndex < 0 || markerIndex == segments.length - 1) return false;

  final endpoint = segments.last.toLowerCase();
  // No convertir páginas, listas, guías ni documentos en señales.
  if (endpoint.isEmpty ||
      endpoint.contains('.') ||
      const <String>{'index', 'playlist', 'watch', 'player', 'embed'}.contains(endpoint)) {
    return false;
  }
  for (final entry in uri.queryParameters.entries) {
    final key = entry.key.toLowerCase();
    final value = entry.value.toLowerCase();
    if ((key == 'type' || key == 'output' || key == 'format') &&
        (value.contains('m3u') || value.contains('xml') || value.contains('html'))) {
      return false;
    }
  }
  return true;
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
  // Algunos proveedores IPTV entregan señales sin extensión y describen el
  // contenedor en la query string (por ejemplo get.php?...&output=ts).
  const hlsHints = <String>{
    'hls', 'm3u8', 'application/vnd.apple.mpegurl',
    'application/x-mpegurl',
  };
  const dashHints = <String>{'dash', 'mpd', 'application/dash+xml'};
  const progressiveHints = <String>{
    'ts', 'mpegts', 'mpeg-ts', 'mp4', 'm4v', 'mov', 'mkv', 'webm', 'flv',
  };
  final mediaHints = uri.queryParameters.entries
      .where((entry) => const <String>{
            'output', 'format', 'type', 'stream_type', 'container',
          }.contains(entry.key.toLowerCase()))
      .map((entry) => entry.value.trim().toLowerCase())
      .toSet();
  if (mediaHints.any(hlsHints.contains)) return LiveMediaFormat.hls;
  if (mediaHints.any(dashHints.contains)) return LiveMediaFormat.dash;
  if (mediaHints.any(progressiveHints.contains)) {
    return LiveMediaFormat.progressive;
  }

  if (_isExtensionlessLiveEndpoint(uri)) return LiveMediaFormat.other;
  return null;
}
