import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const Color _brandBg = Color(0xFF030814);
const Color _brandPanel = Color(0xFF071326);
const Color _brandLine = Color(0xFF123D65);
const Color _brandCyan = Color(0xFF00E5FF);
const Color _brandBlue = Color(0xFF087BFF);
const Color _brandPink = Color(0xFFFF28CF);
const Color _brandGreen = Color(0xFF39FF9C);
const Color _brandMuted = Color(0xFFA9BDD6);
const Color _brandRed = Color(0xFFFF3155);

/// Web de agenda dentro de la identidad visual de Deporte Total 360°.
/// El contenido de la web y sus reproductores siguen perteneciendo al proveedor.
class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({super.key, required this.onExit});

  final VoidCallback onExit;

  static const String initialUrl = 'https://futbol-libre.cam/';

  @override
  State<WebAgendaScreen> createState() => WebAgendaScreenState();
}

class WebAgendaScreenState extends State<WebAgendaScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _blockKnownTrackers = true;
  String? _errorMessage;
  String? _noticeMessage;

  // Dominios publicitarios/rastreadores conocidos. No es una lista universal:
  // un proveedor puede utilizar otros dominios o alojar anuncios en su web.
  static const List<String> _blockedDomains = <String>[
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.com',
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
  ];

  List<ContentBlocker> _buildContentBlockers() {
    return _blockedDomains.map((domain) {
      final escapedDomain = RegExp.escape(domain);
      return ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*$escapedDomain/.*',
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK,
        ),
      );
    }).toList();
  }

  bool _isKnownTrackerHost(String host) {
    final normalized = host.toLowerCase().trim();
    return _blockedDomains.any((domain) {
      return normalized == domain || normalized.endsWith('.$domain');
    });
  }

  bool _isHttpUrl(WebUri uri) {
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'https' || scheme == 'http') && uri.host.isNotEmpty;
  }

  void _showNotice(String message) {
    if (!mounted) return;
    setState(() => _noticeMessage = message);
  }

  Future<void> _refreshNavigationState() async {
    final controller = _controller;
    if (controller == null || !mounted) return;

    try {
      final canBack = await controller.canGoBack();
      final canForward = await controller.canGoForward();
      if (!mounted) return;

      setState(() {
        _canGoBack = canBack;
        _canGoForward = canForward;
      });
    } catch (_) {
      // La navegación sigue disponible aunque WebView no entregue historial.
    }
  }

  /// Lo invoca MainShell cuando el usuario pulsa Atrás en Android.
  /// Devuelve true si retrocedió dentro del historial web.
  Future<bool> handleSystemBack() async {
    final controller = _controller;
    if (controller == null) return false;

    try {
      if (await controller.canGoBack()) {
        await controller.goBack();
        await _refreshNavigationState();
        return true;
      }
    } catch (_) {
      // Si WebView falla al consultar el historial, MainShell vuelve a Inicio.
    }
    return false;
  }

  Future<void> _handleToolbarBack() async {
    final didGoBack = await handleSystemBack();
    if (!didGoBack && mounted) widget.onExit();
  }

  Future<void> _goForward() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      if (await controller.canGoForward()) {
        await controller.goForward();
        await _refreshNavigationState();
      }
    } catch (_) {
      _showNotice('No se pudo avanzar en el historial de la página.');
    }
  }

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      _loading = true;
      _progress = 0;
      _errorMessage = null;
      _noticeMessage = null;
    });

    try {
      await controller.reload();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'No se pudo recargar la agenda. Comprueba tu conexión.';
      });
    }
  }

  Future<void> _toggleTrackerProtection(bool enabled) async {
    final controller = _controller;
    setState(() => _blockKnownTrackers = enabled);
    if (controller == null) return;

    try {
      await controller.setSettings(
        settings: InAppWebViewSettings(
          contentBlockers:
              enabled ? _buildContentBlockers() : <ContentBlocker>[],
        ),
      );

      _showNotice(
        enabled
            ? 'Protección activada. Si una señal deja de cargar, desactívala y recarga la página.'
            : 'Protección desactivada. Recarga la página para probar de nuevo.',
      );

      await controller.reload();
    } catch (_) {
      _showNotice('No se pudo cambiar la protección del navegador.');
    }
  }

  Future<bool> _handleNewWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final target = action.request.url;

    if (target == null || !_isHttpUrl(target)) {
      _showNotice('Se bloqueó una ventana con una dirección no compatible.');
      return false;
    }

    if (_isKnownTrackerHost(target.host)) {
      _showNotice(
        'Se bloqueó una ventana de publicidad o seguimiento conocida.',
      );
      return false;
    }

    // Algunos reproductores usan target="_blank" o window.open.
    // Cargamos el destino HTTP/HTTPS en ESTA vista, no en otra ventana.
    // Así el usuario conserva el marco de la app y puede retroceder.
    try {
      await controller.loadUrl(urlRequest: action.request);
      return false;
    } catch (_) {
      _showNotice('No se pudo abrir el reproductor dentro de la app.');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        titleSpacing: 8,
        leading: IconButton(
          tooltip: 'Atrás',
          onPressed: _handleToolbarBack,
          icon: const Icon(Icons.arrow_back_rounded, color: _brandCyan),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'AGENDA DEPORTIVA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: .4,
              ),
            ),
            Text(
              'DEPORTE TOTAL 360°',
              style: TextStyle(
                color: _brandCyan,
                fontWeight: FontWeight.w800,
                fontSize: 9,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Página siguiente',
            onPressed: _canGoForward ? _goForward : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _canGoForward ? _brandCyan : _brandMuted,
            ),
          ),
          IconButton(
            tooltip: 'Recargar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, color: _brandCyan),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFF071A39),
                  Color(0xFF150B30),
                ],
              ),
              border: Border(bottom: BorderSide(color: _brandLine)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.shield_outlined,
                  color: _brandCyan,
                  size: 17,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Navegación integrada · protección de rastreadores conocidos',
                    style: TextStyle(
                      color: _brandMuted,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _blockKnownTrackers,
                  activeColor: _brandGreen,
                  onChanged: _toggleTrackerProtection,
                ),
              ],
            ),
          ),
          if (_noticeMessage != null)
            Material(
              color: const Color(0xFF10243A),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline_rounded,
                      color: _brandCyan,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _noticeMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() => _noticeMessage = null);
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          if (_loading)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              minHeight: 2,
              backgroundColor: _brandPanel,
              color: _brandCyan,
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: _brandBlue.withAlpha(170)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _brandBlue.withAlpha(25),
                    blurRadius: 14,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _errorMessage != null
                  ? _errorPanel()
                  : InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(WebAgendaScreen.initialUrl),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        databaseEnabled: true,
                        thirdPartyCookiesEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        supportMultipleWindows: true,
                        javaScriptCanOpenWindowsAutomatically: true,
                        mediaPlaybackRequiresUserGesture: true,
                        allowsInlineMediaPlayback: true,
                        iframeAllowFullscreen: true,
                        isElementFullscreenEnabled: true,
                        hardwareAcceleration: true,
                        safeBrowsingEnabled: true,
                        allowFileAccess: false,
                        allowContentAccess: true,
                        loadsImagesAutomatically: true,
                        cacheEnabled: true,
                        supportZoom: true,
                        builtInZoomControls: true,
                        displayZoomControls: false,
                        contentBlockers: _blockKnownTrackers
                            ? _buildContentBlockers()
                            : <ContentBlocker>[],
                      ),
                      onWebViewCreated: (controller) {
                        _controller = controller;
                      },
                      onLoadStart: (controller, url) {
                        if (!mounted) return;
                        setState(() {
                          _loading = true;
                          _progress = 0;
                          _errorMessage = null;
                        });
                        _refreshNavigationState();
                      },
                      onProgressChanged: (controller, progress) {
                        if (!mounted) return;
                        setState(() {
                          _progress = progress / 100;
                          _loading = progress < 100;
                        });
                      },
                      onLoadStop: (controller, url) async {
                        if (!mounted) return;
                        setState(() {
                          _loading = false;
                          _progress = 1;
                        });
                        await _refreshNavigationState();
                      },
                      onUpdateVisitedHistory:
                          (controller, url, androidIsReload) {
                        _refreshNavigationState();
                      },
                      shouldOverrideUrlLoading: (controller, action) async {
                        final uri = action.request.url;
                        if (uri == null) return NavigationActionPolicy.ALLOW;

                        if (!_isHttpUrl(uri)) {
                          _showNotice(
                            'Se bloqueó un enlace externo no web para mantener la navegación dentro de la aplicación.',
                          );
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (_isKnownTrackerHost(uri.host)) {
                          _showNotice(
                            'Se bloqueó un recurso de publicidad/seguimiento conocido.',
                          );
                          return NavigationActionPolicy.CANCEL;
                        }

                        // Los dominios del reproductor pueden ser distintos
                        // del dominio principal. Se permiten dentro de WebView.
                        return NavigationActionPolicy.ALLOW;
                      },
                      onCreateWindow: _handleNewWindow,
                      onReceivedError: (controller, request, error) {
                        if (!(request.isForMainFrame ?? true) || !mounted) {
                          return;
                        }
                        setState(() {
                          _loading = false;
                          _errorMessage =
                              'No se pudo cargar esta página. Comprueba la conexión y pulsa Recargar. Código: ${error.type}';
                        });
                      },
                      onReceivedHttpError: (controller, request, response) {
                        if (!(request.isForMainFrame ?? true) || !mounted) {
                          return;
                        }
                        final statusCode = response.statusCode ?? 0;
                        if (statusCode >= 400) {
                          setState(() {
                            _loading = false;
                            _errorMessage =
                                'El servidor respondió con error HTTP $statusCode. Puede estar temporalmente no disponible.';
                          });
                        }
                      },
                    ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 7),
            color: const Color(0xFF020B19),
            child: const Text(
              'La agenda y sus reproductores son servicios de terceros. '
              'La protección detiene dominios conocidos, pero no garantiza '
              'eliminar todos los anuncios ni que cada señal sea compatible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _brandMuted,
                fontSize: 9,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.wifi_off_rounded,
              color: _brandRed,
              size: 44,
            ),
            const SizedBox(height: 11),
            const Text(
              'AGENDA NO DISPONIBLE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'No se pudo abrir la página.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _brandMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('REINTENTAR'),
              style: FilledButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}