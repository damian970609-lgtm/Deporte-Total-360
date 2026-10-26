import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String _originalAgendaUrl = 'https://futbol-libre.cam/';
const String _fallbackAgendaUrl =
    'https://www.espn.com/soccer/scoreboard';

const Color _navy = Color(0xFF020817);
const Color _panel = Color(0xFF071B35);
const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF28CF);
const Color _green = Color(0xFF39FF9C);
const Color _muted = Color(0xFFB4C4D9);

class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({
    super.key,
    this.initialUrl = _originalAgendaUrl,
    this.pageTitle = 'AGENDA DE PARTIDOS',
  });

  final String initialUrl;
  final String pageTitle;

  @override
  State<WebAgendaScreen> createState() =>
      _WebAgendaScreenState();
}

class _WebAgendaScreenState extends State<WebAgendaScreen> {
  InAppWebViewController? _controller;

  late String _activeUrl;
  late String _lastSafeUrl;

  bool _loading = true;
  bool _handlingUnsafeNavigation = false;

  double _progress = 0;
  String? _error;
  int _viewKey = 0;

  static const List<String> _adHosts = <String>[
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.com',
    'adnxs.com',
    'adsrvr.org',
    'ad-delivery.net',
    'adsterra.com',
    'adsterratools.com',
    'popads.net',
    'popcash.net',
    'exoclick.com',
    'onclickads.net',
    'onclickalgo.com',
    'propellerads.com',
    'trafficjunky.com',
    'trafficjunky.net',
    'juicyads.com',
    'hilltopads.net',
    'richpush.co',
    'taboola.com',
    'outbrain.com',
    'revcontent.com',
    'mgid.com',
    'criteo.com',
    'smartadserver.com',
    'media.net',
    'bidvertiser.com',
    'adf.ly',
    'linkvertise.com',
    'link.tl',
    'ouo.io',
    'shrinkme.io',
    'shorte.st',
    'bc.vc',
    'clk.sh',
    'adfoc.us',
    'pop.do',
    'admaven.com',
    'monetag.com',
    'ero-advertising.com',
    'tsyndicate.com',
  ];

  static const List<String> _adultHosts = <String>[
    'pornhub.com',
    'xvideos.com',
    'xnxx.com',
    'xhamster.com',
    'redtube.com',
    'youporn.com',
    'tube8.com',
    'spankbang.com',
    'chaturbate.com',
    'stripchat.com',
    'cam4.com',
    'livejasmin.com',
    'onlyfans.com',
    'eporner.com',
    'motherless.com',
    'hentaihaven.xxx',
    'rule34.xxx',
    'xhamsterlive.com',
    'brazzers.com',
    'bangbros.com',
  ];

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.initialUrl;
    _lastSafeUrl = widget.initialUrl;
  }

  bool _hostMatches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

  bool _isFirstPartyHost(String host) {
    final normalized = host.toLowerCase();

    return normalized == 'futbol-libre.cam' ||
        normalized.endsWith('.futbol-libre.cam') ||
        normalized.contains('futbollibre') ||
        normalized.contains('futbol-libre');
  }

  bool _isTrustedPlayerUri(Uri uri) {
    final host = uri.host.toLowerCase();

    const knownVideoDomains = <String>[
      'youtube.com',
      'youtu.be',
      'dailymotion.com',
      'dai.ly',
      'vimeo.com',
      'twitch.tv',
      'ok.ru',
      'streamwish.com',
      'streamtape.com',
      'vixcloud.co',
    ];

    if (knownVideoDomains.any(
      (domain) => _hostMatches(host, domain),
    )) {
      return true;
    }

    return RegExp(
          r'(^|[.-])(stream|player|video|embed|cdn|hls|live)([.-]|$)',
          caseSensitive: false,
        ).hasMatch(host) ||
        uri.path.toLowerCase().endsWith('.m3u8') ||
        uri.path.toLowerCase().endsWith('.mp4');
  }

  bool _isBlockedAdUri(Uri uri) {
    final host = uri.host.toLowerCase();

    if (_adHosts.any(
      (domain) => _hostMatches(host, domain),
    )) {
      return true;
    }

    if (_adultHosts.any(
      (domain) => _hostMatches(host, domain),
    )) {
      return true;
    }

    const unsafeHostFragments = <String>[
      'porn',
      'xnxx',
      'xvideos',
      'xhamster',
      'redtube',
      'youporn',
      'hentai',
      'chaturbate',
      'stripchat',
      'camgirl',
      'adult-video',
      'sexcam',
      'popunder',
      'popads',
      'adsterra',
      'onclickads',
      'clickadu',
      'trafficjunky',
      'juicyads',
    ];

    if (unsafeHostFragments.any(
      (fragment) => host.contains(fragment),
    )) {
      return true;
    }

    final address =
        '${uri.host}${uri.path}${uri.query}'.toLowerCase();

    return RegExp(
      r'(popunder|pop-up-ad|popup-ad|clickunder|adclick|interstitial-ad|redirect-ad|adult-content|porn-video|xxx-video|hentai-video|camgirl)',
    ).hasMatch(address);
  }

  bool _isAllowedWebUri(Uri uri) {
    return (uri.scheme == 'http' ||
            uri.scheme == 'https') &&
        !_isBlockedAdUri(uri);
  }

  Future<NavigationActionPolicy> _allowSafeWebNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = Uri.tryParse(
      action.request.url?.toString() ?? '',
    );

    if (uri == null || !_isAllowedWebUri(uri)) {
      return NavigationActionPolicy.CANCEL;
    }

    // Bloquea redirecciones automáticas hacia destinos desconocidos.
    // Se conservan la agenda y los destinos que parecen reproductores.
    if (action.isRedirect == true &&
        !_isFirstPartyHost(uri.host) &&
        !_isTrustedPlayerUri(uri)) {
      return NavigationActionPolicy.CANCEL;
    }

    if (_isFirstPartyHost(uri.host) ||
        _isTrustedPlayerUri(uri)) {
      _lastSafeUrl = uri.toString();
    }

    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _restoreLastSafePage(
    InAppWebViewController controller,
  ) async {
    if (_handlingUnsafeNavigation) return;

    _handlingUnsafeNavigation = true;

    try {
      await controller.stopLoading();

      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(_lastSafeUrl),
        ),
      );
    } catch (_) {
      // El botón Atrás permite regresar a la aplicación.
    }
  }

  Future<void> _loadUrl(String url) async {
    if (!mounted) return;

    final uri = Uri.tryParse(url);

    if (uri == null || !_isAllowedWebUri(uri)) {
      _setError(
        'El enlace fue bloqueado por seguridad porque '
        'parece un anuncio o una redirección no permitida.',
      );
      return;
    }

    setState(() {
      _activeUrl = uri.toString();
      _loading = true;
      _progress = 0;
      _error = null;
    });

    final controller = _controller;

    if (controller == null) {
      setState(() => _viewKey++);
      return;
    }

    try {
      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(uri.toString()),
        ),
      );
    } catch (error) {
      _setError('No se pudo abrir la página: $error');
    }
  }

  Future<void> _reload() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _progress = 0;
      _error = null;
    });

    final controller = _controller;

    if (controller == null) {
      setState(() => _viewKey++);
      return;
    }

    try {
      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(_activeUrl),
        ),
      );
    } catch (error) {
      _setError('No se pudo recargar la página: $error');
    }
  }

  void _setError(String message) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = message;
    });
  }

  Future<void> _applyAppThemeAndBlockAds(
    InAppWebViewController controller,
  ) async {
    try {
      await controller.evaluateJavascript(
        source: r'''
        (function () {
          if (!document.documentElement) return;

          const id = 'dt360-branding-and-ad-filter';

          let style = document.getElementById(id);

          if (!style) {
            style = document.createElement('style');
            style.id = id;
            (document.head || document.documentElement)
              .appendChild(style);
          }

          style.textContent = `
            html, body {
              background: #020817 !important;
              color: #f4f8ff !important;
              color-scheme: dark !important;
            }

            body {
              margin-top: 0 !important;
            }

            header, .site-header, .navbar, .navbar-header,
            .site-navigation,
            [class*="advertisement" i],
            [id*="advertisement" i],
            [class*="ad-banner" i],
            [id*="ad-banner" i],
            [class*="ad-container" i],
            [id*="ad-container" i],
            [class*="popunder" i],
            [id*="popunder" i],
            [class*="popup-ad" i],
            [id*="popup-ad" i],
            [class="ads"], [id="ads"],
            .adsbygoogle, [data-ad-slot], [data-ad-unit],
            iframe[src*="doubleclick" i],
            iframe[src*="googlesyndication" i],
            iframe[src*="popads" i],
            iframe[src*="popcash" i],
            iframe[src*="porn" i],
            iframe[src*="xxx" i],
            iframe[src*="hentai" i],
            iframe[src*="chaturbate" i] {
              display: none !important;
              visibility: hidden !important;
              pointer-events: none !important;
            }

            nav, [role="navigation"] {
              background: #071B35 !important;
              border-color: rgba(0,229,255,.3) !important;
            }

            article, li, .card,
            [class*="match" i],
            [class*="partido" i],
            [class*="fixture" i],
            [data-match] {
              border-color: rgba(0,229,255,.28) !important;
              border-radius: 12px !important;
            }

            a, a:visited {
              color: #00E5FF !important;
            }

            button, [role="button"],
            input[type="button"],
            input[type="submit"] {
              border-radius: 10px !important;
            }

            .dt360-play-link {
              display: inline-block !important;
              padding: 9px 12px !important;
              margin: 4px !important;
              background: linear-gradient(
                110deg, #00E5FF, #39FF9C
              ) !important;
              color: #020817 !important;
              border: 1px solid #00E5FF !important;
              border-radius: 10px !important;
              font-weight: 900 !important;
              text-decoration: none !important;
            }

            #dt360-page-banner {
              box-sizing: border-box;
              position: sticky;
              top: 0;
              z-index: 2147483000;
              width: 100%;
              padding: 10px 12px;
              margin: 0 0 8px;
              text-align: center;
              color: #00E5FF;
              background: linear-gradient(
                100deg, #061B3C, #0A0D26, #1C0734
              );
              border-bottom: 1px solid rgba(0,229,255,.7);
              font: 900 12px Arial, sans-serif;
              letter-spacing: .7px;
              text-shadow: 0 0 8px rgba(0,229,255,.28);
            }
          `;

          const adHosts = [
            'doubleclick.net',
            'googlesyndication.com',
            'googleadservices.com',
            'adservice.google.com',
            'adnxs.com',
            'adsrvr.org',
            'ad-delivery.net',
            'adsterra.com',
            'adsterratools.com',
            'popads.net',
            'popcash.net',
            'exoclick.com',
            'onclickads.net',
            'onclickalgo.com',
            'propellerads.com',
            'trafficjunky.com',
            'trafficjunky.net',
            'juicyads.com',
            'hilltopads.net',
            'richpush.co',
            'taboola.com',
            'outbrain.com',
            'revcontent.com',
            'mgid.com',
            'criteo.com',
            'smartadserver.com',
            'media.net',
            'bidvertiser.com',
            'adf.ly',
            'linkvertise.com',
            'link.tl',
            'ouo.io',
            'shrinkme.io',
            'shorte.st',
            'bc.vc',
            'clk.sh',
            'adfoc.us',
            'pop.do',
            'admaven.com',
            'monetag.com',
            'ero-advertising.com',
            'tsyndicate.com'
          ];

          const adultHosts = [
            'pornhub.com',
            'xvideos.com',
            'xnxx.com',
            'xhamster.com',
            'redtube.com',
            'youporn.com',
            'tube8.com',
            'spankbang.com',
            'chaturbate.com',
            'stripchat.com',
            'cam4.com',
            'livejasmin.com',
            'onlyfans.com',
            'eporner.com',
            'motherless.com',
            'hentaihaven.xxx',
            'rule34.xxx',
            'xhamsterlive.com',
            'brazzers.com',
            'bangbros.com'
          ];

          function blockedUrl(value) {
            try {
              const u = new URL(value, location.href);

              if (!/^https?:$/.test(u.protocol)) return true;

              const h = u.hostname.toLowerCase();

              if (adHosts.some(
                d => h === d || h.endsWith('.' + d)
              )) return true;

              if (adultHosts.some(
                d => h === d || h.endsWith('.' + d)
              )) return true;

              if (/(porn|xnxx|xvideos|xhamster|redtube|youporn|hentai|chaturbate|stripchat|camgirl|popunder|popads|adsterra|onclickads|clickadu|juicyads)/i.test(h)) {
                return true;
              }

              return /(popunder|pop-up-ad|popup-ad|clickunder|adclick|interstitial-ad|redirect-ad|adult-content|porn-video|xxx-video|hentai-video|camgirl)/i.test(
                h + u.pathname + u.search
              );
            } catch (_) {
              return true;
            }
          }

          function hasPlayerContent(el) {
            if (!el || !el.querySelector) return false;

            return !!el.querySelector(
              'video, audio, [class*="player" i], ' +
              '[id*="player" i], iframe[src*="stream" i], ' +
              'iframe[src*="video" i], iframe[src*="embed" i]'
            );
          }

          function hideAdElements() {
            const selector =
              'iframe, [data-ad-slot], [data-ad-unit], ' +
              '[id], [class], [aria-label]';

            document.querySelectorAll(selector).forEach(el => {
              if (el.id === 'dt360-page-banner' ||
                  el.id === id) {
                return;
              }

              // Evita ocultar un reproductor reconocido.
              if (hasPlayerContent(el) ||
                  el.matches(
                    'video, audio, source, .dt360-play-link'
                  )) {
                return;
              }

              const hint = [
                el.id || '',
                typeof el.className === 'string'
                  ? el.className : '',
                el.getAttribute('src') || '',
                el.getAttribute('href') || '',
                el.getAttribute('aria-label') || '',
                el.getAttribute('data-ad-slot') || ''
              ].join(' ').toLowerCase();

              const source = el.getAttribute('src') || '';

              const unsafeSource =
                /^https?:/i.test(source) &&
                blockedUrl(source);

              if (unsafeSource ||
                  /(^|[\s_-])(ads?|advert|advertisement|popunder|popup|sponsor|adult|porn|xxx|hentai|camgirl)([\s_-]|$)/i.test(hint)) {
                el.style.setProperty(
                  'display', 'none', 'important'
                );
                el.style.setProperty(
                  'visibility', 'hidden', 'important'
                );
                el.style.setProperty(
                  'pointer-events', 'none', 'important'
                );
              }
            });
          }

          function installBranding() {
            if (!document.body) return;

            if (!document.getElementById('dt360-page-banner')) {
              const brand = document.createElement('div');
              brand.id = 'dt360-page-banner';
              brand.textContent =
                'DEPORTE TOTAL 360°  •  AGENDA DE PARTIDOS';

              document.body.insertBefore(
                brand, document.body.firstChild
              );
            }

            document.querySelectorAll(
              'a[target="_blank"]'
            ).forEach(a => {
              a.target = '_self';
              a.rel = 'noopener noreferrer';
            });

            document.querySelectorAll('a[href]').forEach(a => {
              if (blockedUrl(a.href)) {
                a.removeAttribute('href');
                a.style.setProperty(
                  'pointer-events', 'none', 'important'
                );
              }

              const label =
                (a.innerText || a.textContent || '').trim();

              if (/^(ver|ver partido|ver canal|reproducir|play|watch|ver en vivo|en vivo|canal\s*\d*)$/i.test(label)) {
                a.classList.add('dt360-play-link');
                a.target = '_self';
                a.rel = 'noopener noreferrer';
              }
            });

            document.querySelectorAll('button').forEach(b => {
              const label =
                (b.innerText || b.textContent || '').trim();

              if (/^(ver|ver partido|ver canal|reproducir|play|watch|ver en vivo|en vivo)$/i.test(label)) {
                b.classList.add('dt360-play-link');
              }
            });
          }

          if (!window.__dt360PopupsBlocked) {
            window.__dt360PopupsBlocked = true;

            // Evita crear nuevas pestañas con window.open.
            window.open = function () {
              return null;
            };

            document.addEventListener('click', function (event) {
              const target = event.target;

              const link = target && target.closest
                ? target.closest('a[href]')
                : null;

              if (link && blockedUrl(link.href)) {
                event.preventDefault();
                event.stopImmediatePropagation();
              }
            }, true);

            document.addEventListener('submit', function (event) {
              const form = event.target;

              if (form && form.action &&
                  blockedUrl(form.action)) {
                event.preventDefault();
                event.stopImmediatePropagation();
              }
            }, true);
          }

          installBranding();
          hideAdElements();

          if (!window.__dt360Observer) {
            window.__dt360Observer = new MutationObserver(
              function () {
                installBranding();
                hideAdElements();
              }
            );

            window.__dt360Observer.observe(
              document.documentElement,
              {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: [
                  'src', 'href', 'class', 'id'
                ]
              }
            );
          }
        })();
      ''');
    } catch (_) {
      // Si la web impide la inyección, sigue activo el filtro
      // nativo de navegación de la aplicación.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: true,
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _panel,
          leading: IconButton(
            tooltip: 'Volver a la aplicación',
            onPressed: () =>
                Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _cyan,
            ),
          ),
          title: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sports_soccer_rounded,
                    color: _cyan,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'DEPORTE TOTAL 360°',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      widget.pageTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Recargar página',
              onPressed: _reload,
              icon: const Icon(
                Icons.refresh_rounded,
                color: _green,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: _loading ? null : _progress,
              minHeight: 3,
              backgroundColor: _panel,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(_pink),
            ),
          ),
        ),
        body: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 8,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFF0B1D35),
                    Color(0xFF10132D),
                  ],
                ),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.sports_soccer_rounded,
                    color: _cyan,
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AGENDA · PARTIDOS · RESULTADOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.sports_basketball_rounded,
                    color: _pink,
                    size: 18,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  InAppWebView(
                    key: ValueKey<int>(_viewKey),
                    initialUrlRequest: URLRequest(
                      url: WebUri(_activeUrl),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: false,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      thirdPartyCookiesEnabled: true,

                      // Se interceptan las solicitudes de ventana nueva
                      // y el callback siguiente las rechaza.
                      supportMultipleWindows: true,

                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      useWideViewPort: true,
                      loadWithOverviewMode: true,
                      supportZoom: true,
                      builtInZoomControls: true,
                      displayZoomControls: false,
                      cacheEnabled: true,
                      transparentBackground: false,
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                    onCreateWindow: (
                      controller,
                      createWindowAction,
                    ) async {
                      // No se permiten pestañas publicitarias.
                      return false;
                    },
                    shouldOverrideUrlLoading:
                        _allowSafeWebNavigation,
                    onLoadStart: (controller, url) async {
                      final value = url?.toString();

                      final uri = value == null
                          ? null
                          : Uri.tryParse(value);

                      if (uri != null &&
                          _isBlockedAdUri(uri)) {
                        await _restoreLastSafePage(controller);
                        return;
                      }

                      if (!mounted) return;

                      setState(() {
                        _loading = true;
                        _progress = 0;
                        _error = null;
                      });
                    },
                    onProgressChanged: (
                      controller,
                      progress,
                    ) {
                      if (!mounted) return;

                      setState(() {
                        _progress = progress / 100;
                        _loading = progress < 100;
                      });
                    },
                    onLoadStop: (controller, url) async {
                      _handlingUnsafeNavigation = false;

                      final value = url?.toString();

                      final uri = value == null
                          ? null
                          : Uri.tryParse(value);

                      if (uri != null &&
                          _isBlockedAdUri(uri)) {
                        await _restoreLastSafePage(controller);
                        return;
                      }

                      await _applyAppThemeAndBlockAds(controller);

                      if (!mounted) return;

                      setState(() {
                        _loading = false;
                        _progress = 1;

                        if (uri != null &&
                            (_isFirstPartyHost(uri.host) ||
                                _isTrustedPlayerUri(uri))) {
                          _lastSafeUrl = uri.toString();
                        }
                      });
                    },
                    onReceivedError: (
                      controller,
                      request,
                      error,
                    ) {
                      if (request.isForMainFrame != true) return;

                      _setError(
                        'La página no respondió. Comprueba tu '
                        'conexión o abre la agenda alternativa.'
                        '\n\n${error.description}',
                      );
                    },
                    onReceivedHttpError: (
                      controller,
                      request,
                      response,
                    ) {
                      if (request.isForMainFrame != true) return;

                      final status = response.statusCode;

                      if (status != null && status >= 400) {
                        _setError(
                          'El servidor respondió HTTP $status. '
                          'La web puede estar fuera de servicio '
                          'o rechazar la conexión desde la app.',
                        );
                      }
                    },
                  ),

                  if (_loading && _error == null)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_pink),
                      ),
                    ),

                  if (_error != null)
                    Positioned.fill(
                      child: ColoredBox(
                        color: _navy,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  color: _pink,
                                  size: 52,
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'NO SE PUDO CARGAR LA PÁGINA',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _cyan,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _muted,
                                    height: 1.45,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _reload,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                    ),
                                    label: const Text('REINTENTAR'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _loadUrl(_fallbackAgendaUrl),
                                    icon: const Icon(
                                      Icons.sports_soccer_rounded,
                                    ),
                                    label: const Text(
                                      'USAR AGENDA ALTERNATIVA',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _green,
                                      side: const BorderSide(
                                        color: _green,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}