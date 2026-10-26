import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const Color _navy = Color(0xFF030814);
const Color _panel = Color(0xFF09172B);
const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF28CF);
const Color _green = Color(0xFF39FF9C);
const Color _muted = Color(0xFFB4C4D9);

const String _originalAgendaUrl = 'https://futbol-libre.cam/';
const String _fallbackAgendaUrl = 'https://www.espn.com/soccer/scoreboard';

class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({
    super.key,
    this.initialUrl = _originalAgendaUrl,
    this.pageTitle = 'AGENDA DE PARTIDOS',
  });

  final String initialUrl;
  final String pageTitle;

  @override
  State<WebAgendaScreen> createState() => _WebAgendaScreenState();
}

class _WebAgendaScreenState extends State<WebAgendaScreen> {
  InAppWebViewController? _controller;
  late String _activeUrl;
  bool _loading = true;
  double _progress = 0;
  String? _error;
  int _viewKey = 0;
  bool _allowRoutePop = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.initialUrl;
  }

  Future<void> _loadUrl(String url) async {
    if (!mounted) return;

    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        _isBlockedAdUri(uri)) {
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
        urlRequest: URLRequest(url: WebUri(uri.toString())),
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
        urlRequest: URLRequest(url: WebUri(_activeUrl)),
      );
    } catch (error) {
      _setError('No se pudo recargar la página: $error');
    }
  }

  // El botón de la barra y el botón Atrás de Android salen de la agenda.
  // El historial interno no puede atrapar al usuario en páginas intermedias.
  void _back() {
    if (!mounted || _leaving) return;

    _leaving = true;
    setState(() => _allowRoutePop = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    });
  }

  bool _isBlockedAdUri(Uri uri) {
    final host = uri.host.toLowerCase();

    const adHosts = <String>[
      'doubleclick.net',
      'googlesyndication.com',
      'googleadservices.com',
      'adservice.google.com',
      'popads.net',
      'popcash.net',
      'exoclick.com',
      'onclickads.net',
      'propellerads.com',
      'trafficjunky.net',
      'adsterra.com',
      'clickadu.com',
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
    ];

    if (adHosts.any(
      (domain) => host == domain || host.endsWith('.$domain'),
    )) {
      return true;
    }

    final address = '${uri.host}${uri.path}'.toLowerCase();

    return address.contains('popunder') ||
        address.contains('pop-up-ad') ||
        address.contains('popup-ad') ||
        address.contains('clickunder') ||
        address.contains('/adclick') ||
        address.contains('interstitial-ad') ||
        address.contains('redirect-ad');
  }

  Future<NavigationActionPolicy> _allowSafeWebNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = Uri.tryParse(
      action.request.url?.toString() ?? '',
    );

    if (uri == null) return NavigationActionPolicy.CANCEL;

    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return NavigationActionPolicy.CANCEL;
    }

    if (_isBlockedAdUri(uri)) {
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _applyAppThemeAndPlayButtons(
    InAppWebViewController controller,
  ) async {
    try {
      await controller.evaluateJavascript(source: r'''
        (function () {
          if (!document.documentElement) return;

          const styleId = 'deporte-total-360-brand-style';
          let style = document.getElementById(styleId);

          if (!style) {
            style = document.createElement('style');
            style.id = styleId;
            (document.head || document.documentElement).appendChild(style);
          }

          style.textContent = `
            html, body {
              background: #030814 !important;
              color: #f4f8ff !important;
              color-scheme: dark !important;
            }

            header, nav, [role="navigation"], .navbar, .site-header,
            [class*="header"], [class*="navbar"], [class*="navigation"] {
              background-color: #09172b !important;
              border-color: rgba(0,229,255,.32) !important;
              color: #f4f8ff !important;
            }

            article, li, .card, [class*="card" i], [class*="match" i],
            [class*="partido" i], [class*="fixture" i], [class*="evento" i],
            [data-match] {
              border-color: rgba(0,229,255,.30) !important;
              border-radius: 12px !important;
            }

            a, a:visited {
              color: #00e5ff !important;
            }

            button, [role="button"], input[type="button"],
            input[type="submit"] {
              border-radius: 10px !important;
            }

            .dt360-play-button {
              display: block !important;
              width: calc(100% - 12px) !important;
              box-sizing: border-box !important;
              margin: 8px 6px 10px !important;
              padding: 11px 14px !important;
              border: 1px solid #00e5ff !important;
              border-radius: 12px !important;
              background: linear-gradient(110deg, #00e5ff, #39ff9c) !important;
              color: #030814 !important;
              font: 900 13px Arial, sans-serif !important;
              letter-spacing: .4px !important;
              text-align: center !important;
              box-shadow: 0 0 14px rgba(0,229,255,.22) !important;
              cursor: pointer !important;
              position: relative !important;
              z-index: 20 !important;
            }

            .dt360-play-button:disabled {
              background: #23344b !important;
              border-color: #617187 !important;
              color: #b4c4d9 !important;
              box-shadow: none !important;
            }

            .dt360-play-link {
              display: inline-block !important;
              padding: 8px 11px !important;
              margin: 4px !important;
              background: #00e5ff !important;
              color: #030814 !important;
              border-radius: 9px !important;
              font-weight: 900 !important;
              text-decoration: none !important;
            }
          `;

          const adHosts = [
            'doubleclick.net', 'googlesyndication.com',
            'googleadservices.com', 'adservice.google.com',
            'popads.net', 'popcash.net', 'exoclick.com',
            'onclickads.net', 'propellerads.com', 'trafficjunky.net',
            'adsterra.com', 'clickadu.com', 'adf.ly',
            'linkvertise.com', 'link.tl', 'ouo.io', 'shrinkme.io',
            'shorte.st', 'bc.vc', 'clk.sh', 'adfoc.us', 'pop.do'
          ];

          function isAdUrl(value) {
            try {
              const u = new URL(value, location.href);

              if (!/^https?:$/.test(u.protocol)) return true;

              const h = u.hostname.toLowerCase();

              if (adHosts.some(d => h === d || h.endsWith('.' + d))) {
                return true;
              }

              const address = (h + u.pathname).toLowerCase();

              return /popunder|pop-up-ad|popup-ad|clickunder|\/adclick|interstitial-ad|redirect-ad/i
                .test(address);
            } catch (_) {
              return true;
            }
          }

          // Evita pestañas y ventanas fantasma.
          if (!window.__dt360PopupGuardInstalled) {
            window.__dt360PopupGuardInstalled = true;

            window.open = function () {
              return null;
            };

            document.addEventListener('click', function (event) {
              const target = event.target;
              const link = target && target.closest
                ? target.closest('a[href]')
                : null;

              if (link && isAdUrl(link.href)) {
                event.preventDefault();
                event.stopImmediatePropagation();
              }
            }, true);
          }

          // Los enlaces que normalmente abren otra pestaña se quedan aquí.
          document.querySelectorAll('a[target="_blank"]').forEach(a => {
            a.target = '_self';
            a.rel = 'noopener noreferrer';
          });

          function installPlayButtons() {
            const selector =
              'article,li,.card,[class*="card" i],' +
              '[class*="game" i],[class*="match" i],' +
              '[class*="partido" i],[class*="fixture" i],' +
              '[class*="evento" i],[data-match]';

            document.querySelectorAll(selector).forEach(card => {
              if (card.dataset.dt360PlayReady === '1') return;

              const text = (
                card.innerText || card.textContent || ''
              ).trim();

              if (!text) return;

              const links = Array.from(
                card.querySelectorAll('a[href]')
              );

              const looksLikeMatch =
                /\bvs\b|\bvs\.?\b|\b\d{1,2}:\d{2}\b|en vivo|live|partido|canal|liga|league|fixture|match/i
                  .test(text);

              const hasPlaybackLabel = links.some(a => {
                const label = (
                  a.innerText || a.textContent || ''
                ).trim();

                return /^(ver|ver partido|ver canal|reproducir|play|watch|en vivo|ver en vivo|abrir)$/i
                  .test(label);
              });

              if (!looksLikeMatch && !hasPlaybackLabel) return;

              // No se elige un enlace cualquiera: solo uno identificable
              // como reproducción.
              const matchLink = links.find(a => {
                let targetUrl;

                try {
                  targetUrl = new URL(a.href, location.href);
                } catch (_) {
                  return false;
                }

                const label = (
                  a.innerText || a.textContent || ''
                ).trim();

                return /^https?:$/.test(targetUrl.protocol) &&
                  !isAdUrl(targetUrl.href) &&
                  (
                    /^(ver|ver partido|ver canal|reproducir|play|watch|en vivo|ver en vivo|abrir)$/i
                      .test(label) ||
                    /play|live|match|stream|watch|player|canal|partido|evento/i
                      .test(targetUrl.pathname + targetUrl.search)
                  );
              });

              const button = document.createElement('button');
              button.type = 'button';
              button.className = 'dt360-play-button';
              button.textContent = matchLink
                ? '▶  VER PARTIDO'
                : '▶  ENLACE NO DISPONIBLE';

              button.setAttribute(
                'aria-label',
                'Abrir partido en DEPORTE TOTAL 360'
              );

              if (matchLink) {
                button.addEventListener('click', function (event) {
                  event.preventDefault();
                  event.stopImmediatePropagation();

                  const targetUrl = new URL(matchLink.href, location.href);

                  if (
                    /^https?:$/.test(targetUrl.protocol) &&
                    !isAdUrl(targetUrl.href)
                  ) {
                    location.assign(targetUrl.href);
                  }
                }, true);
              } else {
                button.disabled = true;
                button.title =
                  'El sitio no publica un enlace de reproducción identificable para este partido.';
              }

              card.insertBefore(button, card.firstChild);
              card.dataset.dt360PlayReady = '1';
            });

            document.querySelectorAll('a[href]').forEach(a => {
              if (a.dataset.dt360Styled === '1') return;

              const label = (
                a.innerText || a.textContent || ''
              ).trim();

              if (
                /^(ver|ver partido|ver canal|reproducir|play|watch|ver en vivo|en vivo|canal \d*)$/i
                  .test(label) &&
                !isAdUrl(a.href)
              ) {
                a.classList.add('dt360-play-link');
                a.dataset.dt360Styled = '1';
                a.target = '_self';
                a.rel = 'noopener noreferrer';
              }
            });
          }

          installPlayButtons();

          if (!window.__dt360Observer) {
            window.__dt360Observer = new MutationObserver(
              installPlayButtons
            );

            window.__dt360Observer.observe(
              document.body || document.documentElement,
              {
                childList: true,
                subtree: true
              }
            );
          }
        })();
      ''');
    } catch (_) {
      // Si el sitio no permite la inyección, la agenda conserva
      // la navegación básica.
    }
  }

  void _setError(String message) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _panel,
          leading: IconButton(
            tooltip: 'Volver a la aplicación',
            onPressed: _back,
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
                  'assets/images/logo.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sports_soccer_rounded,
                    color: _cyan,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 9),
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
                        fontSize: 13,
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
              tooltip: 'Recargar agenda',
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
              valueColor: const AlwaysStoppedAnimation<Color>(_pink),
            ),
          ),
        ),
        body: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
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
                    size: 20,
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
                    size: 19,
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
                      supportMultipleWindows: false,
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
                      // Cancela las ventanas adicionales y sus pop-ups.
                      return false;
                    },
                    shouldOverrideUrlLoading: _allowSafeWebNavigation,
                    onLoadStart: (controller, url) {
                      if (!mounted) return;

                      setState(() {
                        _loading = true;
                        _progress = 0;
                        _error = null;
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      if (!mounted) return;

                      setState(() {
                        _progress = progress / 100;
                        _loading = progress < 100;
                      });
                    },
                    onLoadStop: (controller, url) async {
                      await _applyAppThemeAndPlayButtons(controller);

                      if (!mounted) return;

                      setState(() {
                        _loading = false;
                        _progress = 1;
                      });
                    },
                    onReceivedError: (controller, request, error) {
                      if (request.isForMainFrame != true) return;

                      _setError(
                        'La página no respondió. Comprueba la conexión '
                        'o usa la agenda alternativa.\n\n'
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
                          'La web puede estar fuera de servicio o '
                          'rechazar la conexión desde la aplicación.',
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
                                  size: 54,
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  'NO SE PUDO CARGAR LA WEB',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _cyan,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _muted,
                                    height: 1.45,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 20),
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
                                    onPressed: () => _loadUrl(
                                      _fallbackAgendaUrl,
                                    ),
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