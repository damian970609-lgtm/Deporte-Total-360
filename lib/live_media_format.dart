import 'package:video_player/video_player.dart';

/// Formatos directos que los reproductores Android pueden entregar a ExoPlayer.
/// Una lista .m3u es un catálogo y no es, por sí sola, una señal de vídeo.
enum LiveMediaFormat {
  hls,
  dash,
  smoothStreaming,
  progressive,
}

const Set<String> _progressiveMediaExtensions = <String>{
  '.mp4',
  '.m4v',
  '.m4a',
  '.m4b',
  '.fmp4',
  '.mov',
  '.mkv',
  '.webm',
  '.mp3',
  '.mp2',
  '.ogg',
  '.oga',
  '.opus',
  '.wav',
  '.aac',
  '.flac',
  '.amr',
  '.ts',
  '.mpeg',
  '.mpg',
  '.vob',
  '.flv',
  '.m2ts',
  '.2ts',
  '.mts',
};

const Set<String> _dynamicStreamExtensions = <String>{
  '.php',
  '.asp',
  '.aspx',
  '.ashx',
  '.cgi',
  '.do',
  '.action',
};

const Set<String> _nonMediaExtensions = <String>{
  '.m3u',
  '.pls',
  '.xspf',
  '.wpl',
  '.smil',
  '.asx',
  '.xml',
  '.json',
  '.csv',
  '.txt',
  '.html',
  '.htm',
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.svg',
  '.css',
  '.js',
  '.pdf',
  '.zip',
};

String _queryFormatHint(Uri uri) {
  const hintKeys = <String>{
    'format',
    'type',
    'output',
    'ext',
    'extension',
    'streamtype',
    'stream_type',
    'container',
    'protocol',
    'manifest',
  };
  return uri.queryParameters.entries
      .where((entry) => hintKeys.contains(entry.key.toLowerCase()))
      .map((entry) => entry.value.toLowerCase())
      .join(' ');
}

/// Clasifica primero por la ruta y después por parámetros de formato explícitos.
/// Así también detecta HLS/DASH en endpoints como /live.php?type=m3u8.
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
  final queryHint = _queryFormatHint(uri);

  if (path.endsWith('.m3u8') ||
      queryHint.contains('m3u8') ||
      queryHint.contains('hls')) {
    return LiveMediaFormat.hls;
  }
  if (path.endsWith('.mpd') ||
      queryHint.contains('mpd') ||
      queryHint.contains('dash')) {
    return LiveMediaFormat.dash;
  }
  if (path.endsWith('.ism/manifest') ||
      path.endsWith('.isml/manifest') ||
      queryHint.contains('smoothstream') ||
      queryHint.contains('smooth-stream') ||
      queryHint.contains('isml') ||
      queryHint.contains('ism')) {
    return LiveMediaFormat.smoothStreaming;
  }

  if (_progressiveMediaExtensions.any(path.endsWith)) {
    return LiveMediaFormat.progressive;
  }

  final lastSegment = path.split('/').where((part) => part.isNotEmpty).lastOrNull ?? '';
  final extensionMatch = RegExp(r'\.[a-z0-9]{1,10}$').firstMatch(lastSegment);
  final extension = extensionMatch?.group(0);

  if (extension != null && _nonMediaExtensions.contains(extension)) {
    return null;
  }
  if (extension == null || _dynamicStreamExtensions.contains(extension)) {
    // Muchos proveedores IPTV publican señales directas en /live/ID o
    // /stream.php sin extensión; ExoPlayer intentará detectar el contenedor.
    return LiveMediaFormat.progressive;
  }

  return null;
}

/// Indicación común para todos los controladores Android. Los formatos
/// progresivos usan VideoFormat.other para que ExoPlayer seleccione su extractor.
VideoFormat? videoFormatHintForUrl(String value) {
  switch (liveMediaFormatForUrl(value)) {
    case LiveMediaFormat.hls:
      return VideoFormat.hls;
    case LiveMediaFormat.dash:
      return VideoFormat.dash;
    case LiveMediaFormat.smoothStreaming:
      return VideoFormat.ss;
    case LiveMediaFormat.progressive:
      return VideoFormat.other;
    case null:
      return null;
  }
}

/// Crea controladores con la misma detección de formatos en todos los players.
VideoPlayerController createCompatibleNetworkVideoController(
  Uri uri, {
  Map<String, String> httpHeaders = const <String, String>{},
  VideoPlayerOptions? videoPlayerOptions,
}) {
  return VideoPlayerController.networkUrl(
    uri,
    formatHint: videoFormatHintForUrl(uri.toString()),
    httpHeaders: httpHeaders,
    videoPlayerOptions: videoPlayerOptions,
  );
}

// El catálogo público sigue aceptando únicamente enlaces HTTPS directos; las
// páginas web y los archivos de listas no se envían al reproductor.
bool isSupportedChannelPlaybackUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.scheme == 'https' &&
      uri.hasAuthority &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      liveMediaFormatForUrl(value) != null;
}
