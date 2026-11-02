import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebProtectionPolicy {
  WebProtectionPolicy._();

  static const List<String> blockedDomains = <String>[
    'doubleclick.net','googlesyndication.com','googleadservices.com',
    'adservice.google.com','google-analytics.com','ads.pubmatic.com',
    'pubmatic.com','adnxs.com','popads.net','popcash.net','propellerads.com',
    'exoclick.com','onclickads.net','outbrain.com','taboola.com',
    'trafficjunky.net','adbrite.com','exponential.com','quantserve.com',
    'scorecardresearch.com','zedo.com','adsafeprotected.com','teads.tv',
    'criteo.com','smartadserver.com','serving-sys.com',
  ];

  static bool isBlockedHost(String host) {
    final normalized=host.toLowerCase().trim();
    if(normalized.isEmpty) return false;
    return blockedDomains.any((domain)=>normalized==domain || normalized.endsWith('.'+domain));
  }

  static bool isHttpUrl(WebUri? uri) {
    if(uri==null || uri.host.isEmpty) return false;
    final scheme=uri.scheme.toLowerCase();
    return scheme=='http' || scheme=='https';
  }

  static List<ContentBlocker> buildContentBlockers() {
    return blockedDomains.map((domain) {
      final escaped=RegExp.escape(domain);
      return ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: '.*://([A-Za-z0-9_-]+\\.)*$escaped(:[0-9]+)?/.*'),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      );
    }).toList(growable:false);
  }

  static WebResourceResponse? intercept(WebResourceRequest request) {
    final uri=request.url;
    if(uri==null || !isBlockedHost(uri.host)) return null;
    return WebResourceResponse(
      contentType:'text/plain',
      contentEncoding:'utf-8',
      data:Uint8List(0),
      statusCode:204,
      reasonPhrase:'No Content',
      headers:<String,String>{'Cache-Control':'no-store'},
    );
  }
}
