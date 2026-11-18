import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebProtectionPolicy {
  WebProtectionPolicy._();

  // Redes de anuncios, popunders y publicidad adulta observadas habitualmente.
  // Se filtran por host y URL sin bloquear dominios de vídeo de forma general.
  static const List<String> blockedDomains = <String>[
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.com',
    'google-analytics.com',
    'ads.pubmatic.com',
    'pubmatic.com',
    'adnxs.com',
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'exoclick.com',
    'onclickads.net',
    'outbrain.com',
    'taboola.com',
    'trafficjunky.net',
    'adbrite.com',
    'exponential.com',
    'quantserve.com',
    'scorecardresearch.com',
    'zedo.com',
    'adsafeprotected.com',
    'teads.tv',
    'criteo.com',
    'smartadserver.com',
    'serving-sys.com',
    'juicyads.com',
    'clickadu.com',
    'hilltopads.net',
    'hilltopads.com',
    'adsterra.com',
    'ad-maven.com',
    'adnium.com',
    'trafficstars.com',
    'plugrush.com',
    'tsyndicate.com',
    'adultforce.com',
    'ero-advertising.com',
  ];

  static final RegExp _adultUrlPattern = RegExp(
    r'(^|[./_-])(porn|porno|xxx|hentai|sexcam|camgirl|escort|adultads|'
    r'nsfw|nude|nudes|sexvideo|adultcontent)([./_?&=-]|$)',
    caseSensitive: false,
  );

  static bool isBlockedHost(String host) {
    final normalized = host.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    return blockedDomains.any((domain) =>
        normalized == domain || normalized.endsWith('.' + domain));
  }

  static bool isBlockedUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return true;
    if (uri.scheme != 'http' && uri.scheme != 'https') return true;
    if (isBlockedHost(uri.host)) return true;
    return _adultUrlPattern.hasMatch(uri.host) ||
        _adultUrlPattern.hasMatch(uri.path) ||
        _adultUrlPattern.hasMatch(uri.query);
  }

  static bool isHttpUrl(WebUri uri) {
    if (uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  /// El documento principal del reproductor solo puede permanecer en el
  /// mismo host que la página elegida en Agenda (se acepta el alias www).
  /// Los iframes de vídeo de otros hosts se siguen permitiendo.
  static bool allowsEmbeddedPlayerMainFrameNavigation(
    String targetUrl, {
    required String playerUrl,
  }) {
    final target = Uri.tryParse(targetUrl.trim());
    final player = Uri.tryParse(playerUrl.trim());
    if (target == null || player == null) return false;
    if (!_isWebUri(target) || !_isWebUri(player)) return false;
    if (target.userInfo.isNotEmpty || player.userInfo.isNotEmpty) return false;
    if (isBlockedUrl(targetUrl)) return false;

    return _withoutWww(target.host) == _withoutWww(player.host);
  }

  /// Filtra recursos publicitarios conocidos y evita que una navegación
  /// principal salga del dominio del reproductor. Los recursos de iframe
  /// de otros hosts permanecen disponibles para la señal.
  static WebResourceResponse? interceptEmbeddedPlayerRequest(
    WebResourceRequest request, {
    required String playerUrl,
  }) {
    final uri = Uri.tryParse(request.url.toString());
    if (uri == null || !_isWebUri(uri)) return null;

    final blockedResource = intercept(request);
    if (blockedResource != null) return blockedResource;

    if (request.isForMainFrame &&
        !allowsEmbeddedPlayerMainFrameNavigation(
          uri.toString(),
          playerUrl: playerUrl,
        )) {
      return _noContentResponse();
    }
    return null;
  }

  static bool _isWebUri(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;

  static String _withoutWww(String host) =>
      host.toLowerCase().trim().replaceFirst(RegExp(r'^www\\.'), '');

  static WebResourceResponse _noContentResponse() => WebResourceResponse(
        contentType: 'text/plain',
        contentEncoding: 'utf-8',
        data: Uint8List(0),
        statusCode: 204,
        reasonPhrase: 'No Content',
        headers: <String, String>{'Cache-Control': 'no-store'},
      );

  static List<ContentBlocker> buildContentBlockers() {
    return blockedDomains.map((domain) {
      final escaped = RegExp.escape(domain);
      return ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*://([A-Za-z0-9_-]+\\.)*$escaped(:[0-9]+)?/.*',
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      );
    }).toList()
      ..add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter:
                '.*(porn|porno|xxx|hentai|sexcam|camgirl|escort|adultads|nsfw|nude|sexvideo).*',
            resourceType: <ContentBlockerTriggerResourceType>[
              ContentBlockerTriggerResourceType.SCRIPT,
              ContentBlockerTriggerResourceType.IMAGE,
              ContentBlockerTriggerResourceType.MEDIA,
              ContentBlockerTriggerResourceType.RAW,
            ],
          ),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
      );
  }

  static WebResourceResponse? intercept(WebResourceRequest request) {
    final uri = request.url;
    if (!isBlockedUrl(uri.toString())) return null;
    return _noContentResponse();
  }
}
