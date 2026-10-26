import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String _agendaUrl = 'https://futbol-libre.cam/';
const String _fallbackAgendaUrl =
    'https://www.espn.com/soccer/scoreboard';

const Color _navy = Color(0xFF020817);
const Color _panel = Color(0xFF071B35);
const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF28CF);
const Color _green = Color(0xFF39FF9C);
const Color _yellow = Color(0xFFFFD600);
const Color _muted = Color(0xFFB4C4D9);

class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({
    super.key,
    this.initialUrl = _agendaUrl,
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

  bool _loading = true;
  bool _isPopping = false;

  double _progress = 0;

  String? _error;
  String _logoDataUrl = '';

  int _viewKey = 0;

  static const List<String> _blockedHosts = <String>[
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
    'richpush.co',
    'taboola.com',
    'outbrain.com',
    'revcontent.com',
    'mgid.com',
    'criteo.com',
    'smartadserver.com',
    'media.net',
    'bidvertiser.com',
    'monetag.com',
    'admaven.com',
    'ero-advertising.com',
    'popunder.net',
    'pushground.com',
    'push-house.net',
  ];

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.initialUrl;
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load(
        'assets/images/app_icon.png',
      );

      if (!mounted) return;

      setState(() {
        _logoDataUrl =
            'data:image/png;base64,${base64Encode(data.buffer.asUint8List())}';
      });

      final controller = _controller;

      if (controller != null) {
        await _applyBranding(controller);
      }
    } catch (_) {
      // El icono es opcional para la navegación.
    }
  }

  bool _hostMatches(String host, String domain) {
    final value = host.toLowerCase();

    return value == domain ||
        value.endsWith('.$domain');
  }

  bool _isBlockedUri(Uri uri) {
    if (_blockedHosts.any(
      (domain) => _hostMatches(uri.host.toLowerCase(), domain),
    )) {
      return true;
    }

    final address =
        '${uri.host}${uri.path}${uri.query}'.toLowerCase();

    return RegExp(
      r'(popunder|pop-up-ad|popup-ad|clickunder|'
      r'interstitial-ad|redirect-ad|adult-content|'
      r'porn-video|xxx-video|hentai-video|camgirl)',
    ).hasMatch(address);
  }

  bool _isAllowedUri(Uri uri) {
    return (uri.scheme == 'https' ||
            uri.scheme == 'http') &&
        !_isBlockedUri(uri);
  }

  String _normalizedHost(String host) {
    return host
        .toLowerCase()
        .replaceFirst(RegExp(r'^www\.'), '');
  }

  Future<NavigationActionPolicy> _handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = Uri.tryParse(
      action.request.url?.toString() ?? '',
    );

    if (uri == null || !_isAllowedUri(uri)) {
      return NavigationActionPolicy.CANCEL;
    }

    // Los iframes de vídeo pueden estar alojados en otros dominios.
    // Se permiten si su dominio no figura en el filtro publicitario.
    if (action.isForMainFrame != true) {
      return NavigationActionPolicy.ALLOW;
    }

    // Bloquear la navegación principal hacia un dominio diferente.
    final current = Uri.tryParse(_activeUrl);

    if (current == null ||
        _normalizedHost(uri.host) !=
            _normalizedHost(current.host)) {
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);

    if (uri == null || !_isAllowedUri(uri)) {
      _setError(
        'El enlace se bloqueó porque no es válido '
        'o parece publicitario.',
      );
      return;
    }

    if (!mounted) return;

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
      await controller.reload();
    } catch (error) {
      _setError('No se pudo recargar: $error');
    }
  }

  Future<void> _goBack() async {
    if (_isPopping) return;

    final controller = _controller;

    if (controller != null) {
      try {
        if (await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
      } catch (_) {
        // Sin historial web, cerrar la pantalla integrada.
      }
    }

    if (!mounted) return;

    _isPopping = true;
    Navigator.of(context).pop();
  }

  void _setError(String message) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = message;
    });
  }

  Future<void> _applyBranding(
    InAppWebViewController controller,
  ) async {
    try {
      final script = r'''
        (function () {
          if (!document.documentElement) return;

          const logoData = '__DT360_LOGO__';
          const styleId = 'dt360-app-style';

          let style = document.getElementById(styleId);

          if (!style) {
            style = document.createElement('style');
            style.id = styleId;
            (document.head || document.documentElement)
              .appendChild(style);
          }

          style.textContent = `
            html, body {
              color: #f4f8ff !important;
              color-scheme: dark !important;
              background-color: #020817 !important;
              background-image:
                linear-gradient(
                  rgba(2,8,23,.87),
                  rgba(2,8,23,.90)
                ),
                url("${logoData}") !important;
              background-repeat: no-repeat, no-repeat !important;
              background-position: center, center !important;
              background-size:
                cover, min(76vw, 430px) auto !important;
              background-attachment: fixed, fixed !important;
            }

            body {
              min-height: 100vh !important;
            }

            header,
            .site-header,
            .navbar-header,
            nav,
            [role="navigation"] {
              background: #071b35 !important;
              border-color: rgba(0,229,255,.35) !important;
            }

            a, a:visited {
              color: #00e5ff !important;
            }

            button,
            [role="button"],
            input[type="button"],
            input[type="submit"] {
              border-radius: 10px !important;
            }

            iframe[src*="doubleclick" i],
            iframe[src*="googlesyndication" i],
            iframe[src*="adsterra" i],
            iframe[src*="popads" i],
            iframe[src*="popcash" i],
            iframe[src*="popunder" i] {
              display: none !important;
              visibility: hidden !important;
              pointer-events: none !important;
            }

            #dt360-page-banner {
              box-sizing: border-box;
              position: sticky;
              top: 0;
              z-index: 2147483000;
              width: 100%;
              padding: 11px 10px;
              margin: 0 0 8px;
              text-align: center;
              color: #00e5ff;
              background: linear-gradient(
                110deg, #061b3c, #0a0d26, #1c0734
              );
              border-bottom: 2px solid #00e5ff;
              box-shadow: 0 4px 14px rgba(0,0,0,.55);
              font: 900 12px Arial, sans-serif;
              letter-spacing: .7px;
            }

            #dt360-status-legend {
              display: flex;
              flex-wrap: wrap;
              justify-content: center;
              gap: 8px;
              padding: 9px 5px;
              margin: 4px;
              border: 1px solid rgba(0,229,255,.35);
              border-radius: 12px;
              background: rgba(4,14,35,.94);
              font: 900 10px Arial, sans-serif;
            }

            .dt360-status-pill {
              display: inline-flex !important;
              align-items: center !important;
              width: fit-content !important;
              padding: 5px 9px !important;
              margin: 4px 4px 6px 0 !important;
              border-radius: 999px !important;
              font: 900 10px Arial, sans-serif !important;
              pointer-events: none !important;
            }

            .dt360-live {
              background: #ff3159 !important;
              color: white !important;
            }

            .dt360-finished {
              background: #91a1b5 !important;
              color: #07101e !important;
            }

            .dt360-waiting {
              background: linear-gradient(
                100deg, #ffd600, #ff9d00
              ) !important;
              color: #1a1000 !important;
            }

            .dt360-play-link {
              display: inline-block !important;
              padding: 10px 13px !important;
              margin: 5px !important;
              background: linear-gradient(
                110deg, #00e5ff, #39ff9c
              ) !important;
              color: #020817 !important;
              border: 1px solid #00e5ff !important;
              border-radius: 11px !important;
              font-weight: 900 !important;
              text-decoration: none !important;
            }
          `;

          const blockedHosts = [
            'doubleclick.net',
            'googlesyndication.com',
            'googleadservices.com',
            'adservice.google.com',
            'adnxs.com',
            'adsrvr.org',
            'adsterra.com',
            'adsterratools.com',
            'popads.net',
            'popcash.net',
            'exoclick.com',
            'onclickads.net',
            'onclickalgo.com',
            'propellerads.com',
            'trafficjunky.net',
            'juicyads.com',
            'taboola.com',
            'outbrain.com',
            'revcontent.com',
            'mgid.com',
            'criteo.com',
            'smartadserver.com',
            'media.net',
            'bidvertiser.com',
            'monetag.com',
            'admaven.com',
            'popunder.net',
            'pushground.com',
            'push-house.net'
          ];

          function blockedUrl(value) {
            try {
              const u = new URL(value, location.href);

              if (!/^https?:$/.test(u.protocol)) return true;

              const h = u.hostname.toLowerCase();

              if (blockedHosts.some(
                d => h === d || h.endsWith('.' + d)
              )) {
                return true;
              }

              return /(popunder|popup-ad|clickunder|redirect-ad|adult-content|porn-video|xxx-video|hentai-video)/i
                .test(h + u.pathname + u.search);
            } catch (_) {
              return true;
            }
          }

          function installBranding() {
            if (!document.body) return;

            if (!document.getElementById('dt360-page-banner')) {
              const banner = document.createElement('div');
              banner.id = 'dt360-page-banner';
              banner.textContent =
                'DEPORTE TOTAL 360° • AGENDA Y TRANSMISIONES';
              document.body.insertBefore(
                banner,
                document.body.firstChild
              );
            }

            if (!document.getElementById('dt360-status-legend')) {
              const legend = document.createElement('div');
              legend.id = 'dt360-status-legend';
              legend.innerHTML =
                '<span style="color:#ff3159">● EN VIVO</span>' +
                '<span style="color:#b4c4d9">● TERMINADO</span>' +
                '<span style="color:#ffd600">● ESPERANDO TRANSMISIÓN</span>';

              const banner = document.getElementById(
                'dt360-page-banner'
              );

              if (banner && banner.nextSibling) {
                document.body.insertBefore(
                  legend,
                  banner.nextSibling
                );
              } else {
                document.body.insertBefore(
                  legend,
                  document.body.firstChild
                );
              }
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
                  'pointer-events',
                  'none',
                  'important'
                );
              }

              const label = (
                a.innerText || a.textContent || ''
              ).trim();

              if (/^EN VIVO AQUÍ$/i.test(label)) return;

              if (/^(ver|ver partido|ver canal|reproducir|play|watch|ver en vivo|en vivo|canal\s*\d*|transmitir|transmisión)$/i.test(label)) {
                a.classList.add('dt360-play-link');
                a.setAttribute('aria-label', 'EN VIVO AQUÍ');
                a.textContent = 'EN VIVO AQUÍ';
              }
            });

            document.querySelectorAll(
              'button, [role="button"], ' +
              'input[type="button"], input[type="submit"]'
            ).forEach(node => {
              const label = (
                node.innerText ||
                node.value ||
                node.getAttribute('aria-label') ||
                node.textContent ||
                ''
              ).trim();

              if (/^EN VIVO AQUÍ$/i.test(label)) return;

              if (!/(ver partido|ver canal|reproduc|play|watch|en vivo|live|stream|transmit)/i.test(label)) {
                return;
              }

              node.setAttribute(
                'aria-label',
                'EN VIVO AQUÍ'
              );

              if (node.tagName === 'INPUT') {
                node.value = 'EN VIVO AQUÍ';
              } else {
                node.textContent = 'EN VIVO AQUÍ';
              }

              node.classList.add('dt360-play-link');
            });
          }

          function addMatchStatuses() {
            const selector =
              'article,li,[class*="match" i],' +
              '[class*="partido" i],[class*="fixture" i],' +
              '[data-match]';

            document.querySelectorAll(selector).forEach(node => {
              if (node.querySelector(
                ':scope > .dt360-status-pill'
              )) return;

              const text = (
                node.innerText || node.textContent || ''
              ).replace(/\s+/g, ' ').trim();

              if (text.length < 18 || text.length > 800) return;

              const explicit = node.matches(
                '[class*="match" i],[class*="partido" i],' +
                '[class*="fixture" i],[data-match]'
              );

              const indicators =
                /\bvs\.?\b|\bversus\b|\d{1,2}:\d{2}|\b\d+\s*[-–:]\s*\d+\b/i
                  .test(text);

              if (!explicit && !indicators) return;

              const parent = node.parentElement
                ? node.parentElement.closest(selector)
                : null;

              if (parent) {
                const parentText =
                  (parent.innerText || '').trim();

                if (
                  parentText.length > text.length &&
                  parentText.length < 700
                ) return;
              }

              let label = 'ESPERANDO TRANSMISIÓN';
              let cls = 'dt360-waiting';

              if (/\b(en vivo|live now|live|en juego|playing|primer tiempo|segundo tiempo|medio tiempo|halftime|descanso)\b/i.test(text)) {
                label = '● EN VIVO';
                cls = 'dt360-live';
              } else if (/\b(terminado|finalizado|finished|full time|final|ft)\b/i.test(text)) {
                label = '● TERMINADO';
                cls = 'dt360-finished';
              }

              const pill = document.createElement('span');
              pill.className = 'dt360-status-pill ' + cls;
              pill.textContent = label;

              node.insertBefore(pill, node.firstChild);
            });
          }

          if (!window.__dt360PopupPatch) {
            window.__dt360PopupPatch = true;

            // window.open no puede abrir otra página.
            window.open = function () {
              return null;
            };

            document.addEventListener('click', function (event) {
              const target = event.target;
              const link = target && target.closest
                ? target.closest('a[href]')
                : null;

              if (!link) return;

              let destination;

              try {
                destination = new URL(link.href, location.href);
              } catch (_) {
                event.preventDefault();
                event.stopImmediatePropagation();
                return;
              }

              const host = destination.hostname
                .toLowerCase()
                .replace(/^www\./, '');

              const currentHost = location.hostname
                .toLowerCase()
                .replace(/^www\./, '');

              if (
                blockedUrl(destination.href) ||
                host !== currentHost
              ) {
                event.preventDefault();
                event.stopPropagation();
                event.stopImmediatePropagation();
              }
            }, true);

            document.addEventListener('submit', function (event) {
              const form = event.target;
              if (!form || !form.action) return;

              let destination;

              try {
                destination = new URL(form.action, location.href);
              } catch (_) {
                event.preventDefault();
                event.stopImmediatePropagation();
                return;
              }

              const host = destination.hostname
                .toLowerCase()
                .replace(/^www\./, '');

              const currentHost = location.hostname
                .toLowerCase()
                .replace(/^www\./, '');

              if (
                blockedUrl(destination.href) ||
                host !== currentHost
              ) {
                event.preventDefault();
                event.stopPropagation();
                event.stopImmediatePropagation();
              }
            }, true);
          }

          function updatePage() {
            installBranding();
            addMatchStatuses();
          }

          updatePage();

          if (!window.__dt360Observer) {
            window.__dt360Observer = new MutationObserver(
              updatePage
            );

            window.__dt360Observer.observe(
              document.documentElement,
              {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['href', 'class', 'id']
              }
            );
          }
        })();
      '''.replaceAll('__DT360_LOGO__', _logoDataUrl);

      await controller.evaluateJavascript(source: script);
    } catch (_) {
      // La página sigue funcionando si rechaza el script de estilo.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _panel,
          leading: IconButton(
            onPressed: _goBack,
            tooltip: 'Atrás',
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _cyan,
            ),
          ),
          title: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sports_soccer_rounded,
                    color: _cyan,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'DEPORTE TOTAL 360°',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Recargar',
              onPressed: _reload,
              icon: const Icon(
                Icons.refresh_rounded,
                color: _green,
              ),
            ),
            IconButton(
              tooltip: 'Agenda alternativa',
              onPressed: () => _openUrl(_fallbackAgendaUrl),
              icon: const Icon(
                Icons.sports_soccer_rounded,
                color: _yellow,
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
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Opacity(
                opacity: .13,
                child: Image.asset(
                  'assets/images/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: _navy.withValues(alpha: .84),
              ),
            ),
            Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0xFF0B1D35),
                        Color(0xFF10132D),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: _cyan.withValues(alpha: .45),
                      ),
                    ),
                  ),
                  child: const Text(
                    'EN VIVO • TERMINADO • ESPERANDO TRANSMISIÓN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
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
                          javaScriptCanOpenWindowsAutomatically:
                              false,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                          thirdPartyCookiesEnabled: true,
                          supportMultipleWindows: true,
                          useShouldOverrideUrlLoading: true,
                          useShouldInterceptRequest: true,
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

                          if (_logoDataUrl.isNotEmpty) {
                            _applyBranding(controller);
                          }
                        },
                        onCreateWindow: (
                          controller,
                          createWindowAction,
                        ) async {
                          return false;
                        },
                        shouldOverrideUrlLoading:
                            _handleNavigation,
                        shouldInterceptRequest: (
                          controller,
                          request,
                        ) async {
                          final uri = Uri.tryParse(
                            request.url.toString(),
                          );

                          if (uri != null && _isBlockedUri(uri)) {
                            return WebResourceResponse(
                              contentType: 'text/plain',
                              data: Uint8List(0),
                              statusCode: 204,
                              reasonPhrase: 'Blocked',
                            );
                          }

                          return null;
                        },
                        onLoadStart: (controller, url) {
                          final uri = Uri.tryParse(
                            url?.toString() ?? '',
                          );

                          if (uri != null && _isBlockedUri(uri)) {
                            controller.stopLoading();
                            return;
                          }

                          final expected = Uri.tryParse(_activeUrl);

                          if (uri != null &&
                              expected != null &&
                              _normalizedHost(uri.host) !=
                                  _normalizedHost(expected.host)) {
                            controller.stopLoading();
                            _setError(
                              'Se bloqueó una redirección a otro dominio.',
                            );
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
                        onLoadStop: (
                          controller,
                          url,
                        ) async {
                          final uri = Uri.tryParse(
                            url?.toString() ?? '',
                          );

                          if (uri != null && _isBlockedUri(uri)) {
                            await controller.stopLoading();
                            return;
                          }

                          await _applyBranding(controller);

                          if (!mounted) return;

                          setState(() {
                            _loading = false;
                            _progress = 1;
                            _error = null;

                            if (uri != null && _isAllowedUri(uri)) {
                              _activeUrl = uri.toString();
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
                            'La página no respondió. '
                            'Comprueba tu conexión.\n\n'
                            '${error.description}',
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
                              'Puede estar temporalmente fuera de servicio.',
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
                          child: Container(
                            color: _navy,
                            padding: const EdgeInsets.all(22),
                            child: Center(
                              child: SingleChildScrollView(
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
                                            _openUrl(_fallbackAgendaUrl),
                                        icon: const Icon(
                                          Icons.sports_soccer_rounded,
                                        ),
                                        label: const Text(
                                          'ABRIR AGENDA ALTERNATIVA',
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
          ],
        ),
      ),
    );
  }
}