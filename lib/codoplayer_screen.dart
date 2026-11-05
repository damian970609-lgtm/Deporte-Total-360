import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String _codoPlayerUrl = 'https://codoplayer.com/watch.php';

const Color _codoBg = Color(0xFF030814);
const Color _codoPanel = Color(0xFF071326);
const Color _codoLine = Color(0xFF123D65);
const Color _codoCyan = Color(0xFF00E5FF);
const Color _codoMuted = Color(0xFFA9BDD6);

/// CodoPlayer se abre como reproductor web dentro de la app.
/// No recibe automáticamente las fuentes privadas guardadas en Deporte Total 360°.
class CodoPlayerScreen extends StatefulWidget {
  const CodoPlayerScreen({super.key});

  @override
  State<CodoPlayerScreen> createState() => _CodoPlayerScreenState();
}

class _CodoPlayerScreenState extends State<CodoPlayerScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _errorMessage;

  bool _isWebUrl(WebUri uri) {
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'https' || scheme == 'http') && uri.host.isNotEmpty;
  }

  Future<void> _refreshNavigationState() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final canGoBack = await controller.canGoBack();
      final canGoForward = await controller.canGoForward();
      if (!mounted) return;
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    } catch (_) {
      // La página sigue disponible aunque falle la consulta del historial.
    }
  }

  Future<void> _goBack() async {
    final controller = _controller;
    if (controller != null) {
      try {
        if (await controller.canGoBack()) {
          await controller.goBack();
          await _refreshNavigationState();
          return;
        }
      } catch (_) {
        // Si el historial web no está disponible, se cierra esta pantalla.
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openNewWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null || !_isWebUrl(uri)) return;
    try {
      await controller.loadUrl(urlRequest: action.request);
    } catch (_) {
      // No se abre una segunda ventana nativa.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: _codoBg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF020B19),
          titleSpacing: 8,
          leading: IconButton(
            tooltip: _canGoBack ? 'Volver en CodoPlayer' : 'Volver al menú secreto',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded, color: _codoCyan),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'CODOPLAYER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Text(
                'REPRODUCTOR WEB INTEGRADO',
                style: TextStyle(
                  color: _codoCyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Recargar CodoPlayer',
              onPressed: () => _controller?.reload(),
              icon: const Icon(Icons.refresh_rounded, color: _codoCyan),
            ),
            IconButton(
              tooltip: 'Página siguiente',
              onPressed: _canGoForward
                  ? () async {
                      await _controller?.goForward();
                      await _refreshNavigationState();
                    }
                  : null,
              icon: Icon(
                Icons.chevron_right_rounded,
                color: _canGoForward ? _codoCyan : _codoMuted,
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: _codoPanel,
                border: Border(bottom: BorderSide(color: _codoLine)),
              ),
              child: const Text(
                'Servicio externo. Esta APK no envía automáticamente tus listas guardadas. '
                'Las listas o credenciales que introduzcas aquí se comparten con CodoPlayer; '
                'consulta su política de privacidad antes de agregarlas.',
                style: TextStyle(color: _codoMuted, fontSize: 10, height: 1.4),
              ),
            ),
            if (_loading)
              LinearProgressIndicator(
                value: _progress > 0 && _progress < 1 ? _progress : null,
                minHeight: 2,
                color: _codoCyan,
                backgroundColor: _codoLine,
              ),
            Expanded(
              child: _errorMessage == null
                  ? InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(_codoPlayerUrl),
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
                      onUpdateVisitedHistory: (controller, url, androidIsReload) {
                        _refreshNavigationState();
                      },
                      shouldOverrideUrlLoading: (controller, action) async {
                        final uri = action.request.url;
                        if (uri == null || !_isWebUrl(uri)) {
                          return NavigationActionPolicy.CANCEL;
                        }
                        return NavigationActionPolicy.ALLOW;
                      },
                      onCreateWindow: (controller, action) async {
                        await _openNewWindow(controller, action);
                        return true;
                      },
                      onReceivedError: (controller, request, error) {
                        if (!(request.isForMainFrame ?? true) || !mounted) return;
                        setState(() {
                          _loading = false;
                          _errorMessage =
                              'No se pudo cargar CodoPlayer. Comprueba la conexión y pulsa Recargar.';
                        });
                      },
                      onReceivedHttpError: (controller, request, response) {
                        if (!(request.isForMainFrame ?? true) || !mounted) return;
                        final statusCode = response.statusCode ?? 0;
                        if (statusCode >= 400) {
                          setState(() {
                            _loading = false;
                            _errorMessage =
                                'CodoPlayer respondió con error HTTP $statusCode.';
                          });
                        }
                      },
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.redAccent,
                              size: 42,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _codoMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() {
                                  _errorMessage = null;
                                  _loading = true;
                                  _progress = 0;
                                });
                                _controller?.loadUrl(
                                  urlRequest: URLRequest(
                                    url: WebUri(_codoPlayerUrl),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('REINTENTAR'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
