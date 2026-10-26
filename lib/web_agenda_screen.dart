import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const Color _navy = Color(0xFF030814);
const Color _panel = Color(0xFF071326);
const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF28CF);
const Color _green = Color(0xFF39FF9C);

const String _defaultAgendaUrl = 'https://futbol-libre.cam/';

class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({
    super.key,
    this.initialUrl = _defaultAgendaUrl,
    this.pageTitle = 'AGENDA DEPORTIVA',
  });

  final String initialUrl;
  final String pageTitle;

  @override
  State<WebAgendaScreen> createState() => _WebAgendaScreenState();
}

class _WebAgendaScreenState extends State<WebAgendaScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  String? _error;
  bool _loading = true;

  Future<void> _back() async {
    final controller = _controller;

    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }

    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _reload() async {
    if (!mounted) return;

    setState(() {
      _error = null;
      _loading = true;
      _progress = 0;
    });

    try {
      await _controller?.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(widget.initialUrl),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'No se pudo iniciar la carga. Comprueba Internet e inténtalo otra vez.';
      });
    }
  }

  Future<NavigationActionPolicy> _handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final target = action.request.url;

    if (target == null) {
      return NavigationActionPolicy.CANCEL;
    }

    final scheme = target.scheme.toLowerCase();

    // Los enlaces web se abren dentro de esta misma vista.
    if (scheme == 'https' || scheme == 'http') {
      return NavigationActionPolicy.ALLOW;
    }

    // Evita lanzar esquemas externos no compatibles.
    return NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _back();
      },
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _panel,
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _back,
            icon: const Icon(Icons.arrow_back, color: _cyan),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DEPORTE TOTAL 360°',
                style: TextStyle(
                  color: _cyan,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                widget.pageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Recargar página',
              onPressed: _reload,
              icon: const Icon(Icons.refresh, color: _green),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: LinearProgressIndicator(
              value: _loading ? null : _progress,
              backgroundColor: _panel,
              valueColor: const AlwaysStoppedAnimation<Color>(_pink),
            ),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              color: const Color(0xFF091A31),
              child: const Row(
                children: [
                  Icon(
                    Icons.sports_soccer_rounded,
                    color: _cyan,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'DEPORTE TOTAL 360° · AGENDA DEPORTIVA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
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
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.initialUrl),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      databaseEnabled: true,

                      // Evita que los enlaces target="_blank" dependan
                      // de una ventana emergente que la app no crea.
                      supportMultipleWindows: false,
                      javaScriptCanOpenWindowsAutomatically: true,

                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      thirdPartyCookiesEnabled: true,
                      useWideViewPort: true,
                      loadWithOverviewMode: true,
                      supportZoom: true,
                      builtInZoomControls: true,
                      displayZoomControls: false,
                      cacheEnabled: true,

                      // Identificación habitual de Chrome móvil.
                      userAgent:
                          'Mozilla/5.0 (Linux; Android 15) '
                          'AppleWebKit/537.36 (KHTML, like Gecko) '
                          'Chrome/131.0.0.0 Mobile Safari/537.36',
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                    shouldOverrideUrlLoading: _handleNavigation,
                    onLoadStart: (controller, url) {
                      if (!mounted) return;

                      setState(() {
                        _loading = true;
                        _error = null;
                        _progress = 0;
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      if (!mounted) return;

                      setState(() {
                        _progress = progress / 100;
                        _loading = progress < 100;
                      });
                    },
                    onLoadStop: (controller, url) {
                      if (!mounted) return;

                      setState(() {
                        _loading = false;
                        _progress = 1;
                        _error = null;
                      });
                    },
                    onReceivedError: (controller, request, error) {
                      if (request.isForMainFrame != true || !mounted) {
                        return;
                      }

                      setState(() {
                        _loading = false;
                        _error =
                            'La web no respondió. Comprueba la conexión '
                            'o prueba a abrir la página en Chrome.';
                      });
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
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 54,
                                color: _pink,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'PÁGINA NO DISPONIBLE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _cyan,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _reload,
                                icon: const Icon(Icons.refresh),
                                label: const Text('VOLVER A INTENTAR'),
                              ),
                            ],
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