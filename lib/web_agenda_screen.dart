import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const Color _navy = Color(0xFF030814);
const Color _panel = Color(0xFF09172B);
const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF28CF);
const Color _green = Color(0xFF39FF9C);
const Color _muted = Color(0xFFB4C4D9);

const String _originalAgendaUrl = 'https://futbol-libre.cam/';
const String _fallbackAgendaUrl =
    'https://www.espn.com/soccer/scoreboard';

class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({
    super.key,
    this.initialUrl = _originalAgendaUrl,
    this.pageTitle = 'AGENDA DEPORTIVA',
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

  // Este botón vuelve a la pantalla Flutter anterior.
  // No recorre primero los anuncios y páginas intermedias del historial web.
  Future<void> _back() async {
    if (mounted) {
      Navigator.of(context).maybePop();
    }
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
    ];

    if (adHosts.any(
      (domain) => host == domain || host.endsWith('.$domain'),
    )) {
      return true;
    }

    final address = uri.toString().toLowerCase();

    return address.contains('popunder') ||
        address.contains('pop-up-ad') ||
        address.contains('popup-ad') ||
        address.contains('clickunder');
  }

  Future<NavigationActionPolicy> _allowSafeWebNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = Uri.tryParse(
      action.request.url?.toString() ?? '',
    );

    if (uri == null) {
      return NavigationActionPolicy.CANCEL;
    }

    // No abre aplicaciones externas ni esquemas que salgan de la WebView.
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return NavigationActionPolicy.CANCEL;
    }

    // Bloquea dominios publicitarios conocidos.
    if (_isBlockedAdUri(uri)) {
      return NavigationActionPolicy.CANCEL;
    }

    // Las demás direcciones web permanecen dentro de la aplicación.
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
            document.head.appendChild(style);
          }

          style.textContent = `
            html, body {
              background: #030814 !important;
              color: #f4f8ff !important;
              color-scheme: dark;
            }

            header, nav, [role="navigation"],
            .navbar, .site-header,
            [class*="header"], [class*="navbar"],
            [class*="navigation"] {
              background-color: #09172b !important;
              border-color: rgba(0,229,255,.28) !important;
            }

            article, [class*="match"],
            [class*="partido"], [class*="fixture"],
            [class*="evento"], [data-match] {
              border-color: rgba(0,229,255,.30) !important;
            }

            a, a:visited {
              color: #00e5ff !important;
            }

            button, [role="button"],
            input[type="button"], input[type="submit"] {
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
              background: linear-gradient(
                110deg, #00e5ff, #39ff9c
              ) !important;
              color: #030814 !important;
              font: 900 13px Arial, sans-serif !important;
              letter-spacing: .5px !important;
              text-align: center !important;
              box-shadow: 0 0 14px rgba(0,229,255,.22) !important;
              cursor: pointer !important;
              position: relative !important;
              z-index: 20 !important;
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
            'adf.ly'
          ];

          function isAdUrl(value) {
            try {
              const u = new URL(value, location.href);
              const h = u.hostname.toLowerCase();

              return adHosts.some(
                d => h === d || h.endsWith('.' + d)
              ) || /popunder|pop-up-ad|popup-ad|clickunder/i.test(u.href);
            } catch (_) {
              return true;
            }
          }

          // Los enlaces que normalmente abren otra ventana
          // se convierten para navegar en la misma vista.
          document.querySelectorAll('a[target="_blank"]').forEach(a => {
            a.target = '_self';
            a.rel = 'noopener noreferrer';
          });

          // Intercepta ventanas emergentes JavaScript.
          // Los dominios publicitarios identificados no se abren.
          if (!window.__dt360WindowOpenPatched) {
            window.__dt360WindowOpenPatched = true;

            window.open = function (url) {
              if (!url) return null;

              try {
                const target = new URL(String(url), location.href);

                if (!/^https?:$/.test(target.protocol) ||
                    isAdUrl(target.href)) {
                  return null;
                }

                location.href = target.href;
                return window;
              } catch (_) {
                return null;
              }
            };
          }

          function installPlayButtons() {
            const selector =
              'article,[class*="match" i],' +
              '[class*="partido" i],[class*="fixture" i],' +
              '[class*="evento" i],[data-match]';

            document.querySelectorAll(selector).forEach(card => {
              if (card.dataset.dt360PlayReady === '1') return;

              const text = (
                card.innerText || card.textContent || ''
              ).trim();

              const looksLikeMatch =
                /\bvs\b|\bvs\.?\b|\b\d{1,2}:\d{2}\b|en vivo|live|partido|canal/i
                  .test(text);

              if (!text || !looksLikeMatch) return;

              const links = Array.from(
                card.querySelectorAll('a[href]')
              );

              const matchLink = links.find(a => {
                const href = a.href;
                const label = (
                  a.innerText || a.textContent || ''
                ).trim();

                return href &&
                  !isAdUrl(href) &&
                  (
                    /ver|play|partido|canal|live|en vivo|reproduc|watch|stream|evento/i
                      .test(label) ||
                    /partido|match|evento|event|canal|play|live|stream|watch|reproduc/i
                      .test(href)
                  );
              }) || links.find(
                a => a.href && !isAdUrl(a.href)
              );

              if (!matchLink) return;

              const button = document.createElement('button');
              button.type = 'button';
              button.className = 'dt360-play-button';
              button.textContent = '▶  REPRODUCIR PARTIDO';
              button.setAttribute(
                'aria-label',
                'Abrir partido dentro de DEPORTE TOTAL 360'
              );

              button.addEventListener('click', function (event) {
                event.preventDefault();
                event.stopPropagation();

                const target = matchLink.href;

                if (!isAdUrl(target)) {
                  location.href = target;
                }
              }, true);

              card.insertBefore(button, card.firstChild);
              card.dataset.dt360PlayReady = '1';
            });

            // También estiliza enlaces de reproducción que no estén
            // dentro de una tarjeta identificable como partido.
            document.querySelectorAll('a[href]').forEach(a => {
              if (a.dataset.dt360Styled === '1') return;

              const label = (
                a.innerText || a.textContent || ''
              ).trim();

              if (
                /^(ver partido|ver canal|reproducir|play|ver en vivo|en vivo|canal \d*)$/i
                  .test(label) &&
                !isAdUrl(a.href)
              ) {
                a.classList.add('dt360-play-link');
                a.dataset.dt360Styled = '1';
                a.target = '_self';
              }
            });
          }

          installPlayButtons();

          // Vuelve a comprobar cuando la agenda carga partidos dinámicamente.
          if (!window.__dt360Observer) {
            window.__dt360Observer = new MutationObserver(
              installPlayButtons
            );

            window.__dt360Observer.observe(document.body, {
              childList: true,
              subtree: true
            });
          }
        })();
      ''');
    } catch (_) {
      // Si el sitio bloquea la inyección, aún se puede navegar por la web.
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
    return Scaffold(
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
          children: [
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
                children: [
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
        actions: [
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
            valueColor:
                const AlwaysStoppedAnimation<Color>(_pink),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            color: const Color(0xFF0B1D35),
            child: const Row(
              children: [
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
              children: [
                InAppWebView(
                  key: ValueKey<int>(_viewKey),
                  initialUrlRequest: URLRequest(
                    url: WebUri(_activeUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    thirdPartyCookiesEnabled: true,
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
                    final popupUri = Uri.tryParse(
                      createWindowAction.request.url?.toString() ?? '',
                    );

                    // No crea una segunda ventana. Si la URL parece válida,
                    // la carga en la WebView principal.
                    if (popupUri == null ||
                        (popupUri.scheme != 'https' &&
                            popupUri.scheme != 'http') ||
                        _isBlockedAdUri(popupUri)) {
                      return false;
                    }

                    await _loadUrl(popupUri.toString());
                    return false;
                  },
                  shouldOverrideUrlLoading:
                      _allowSafeWebNavigation,
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
                            children: [
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
    );
  }
}