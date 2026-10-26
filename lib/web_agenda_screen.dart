import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const Color _navy = Color(0xFF030814);
const Color _panel = Color(0xFF071326);
const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF28CF);
const Color _green = Color(0xFF39FF9C);

const String _agendaUrl = 'https://futbol-libre.cam/';

class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({
    super.key,
    this.initialUrl = _agendaUrl,
    this.pageTitle = 'AGENDA DEPORTIVA',
  });

  final String initialUrl;
  final String pageTitle;

  @override
  State<WebAgendaScreen> createState() => _WebAgendaScreenState();
}

class _WebAgendaScreenState extends State<WebAgendaScreen> {
  InAppWebViewController? _controller;

  bool _loading = true;
  double _progress = 0;
  String? _error;
  int _reloadKey = 0;

  Future<void> _reload() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _progress = 0;
      _error = null;
    });

    final controller = _controller;

    if (controller == null) {
      setState(() {
        _reloadKey++;
      });
      return;
    }

    try {
      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(widget.initialUrl),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo iniciar la carga: $e';
      });
    }
  }

  Future<void> _back() async {
    final controller = _controller;

    if (controller != null) {
      try {
        if (await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
      } catch (_) {
        // Si falla el historial, vuelve a la pantalla anterior.
      }
    }

    if (mounted) {
      Navigator.of(context).maybePop();
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

    // Mantener los enlaces HTTP y HTTPS dentro de la aplicación.
    if (scheme == 'https' || scheme == 'http') {
      return NavigationActionPolicy.ALLOW;
    }

    // Bloquear esquemas externos desconocidos.
    return NavigationActionPolicy.CANCEL;
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _back();
        }
      },
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _panel,
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _back,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _cyan,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DEPORTE TOTAL 360°',
                style: TextStyle(
                  color: _cyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                widget.pageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Recargar',
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
                horizontal: 12,
                vertical: 10,
              ),
              color: const Color(0xFF091A31),
              child: const Row(
                children: [
                  Icon(
                    Icons.sports_soccer_rounded,
                    color: _cyan,
                    size: 21,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'AGENDA DEPORTIVA · PARTIDOS',
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
                    size: 20,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    key: ValueKey(_reloadKey),
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.initialUrl),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: true,
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
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                    shouldOverrideUrlLoading: _handleNavigation,
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
                    onLoadStop: (controller, url) {
                      if (!mounted) return;
                      setState(() {
                        _loading = false;
                        _progress = 1;
                        _error = null;
                      });
                    },
                    onReceivedError: (controller, request, error) {
                      if (request.isForMainFrame != true) return;

                      _showError(
                        'No se pudo cargar la página.\n\n'
                        'Código: ${error.type}\n'
                        '${error.description}\n\n'
                        'Comprueba Internet y prueba la dirección '
                        'en Chrome. Si tampoco abre en Chrome, '
                        'el problema puede estar en el sitio web.',
                      );
                    },
                    onReceivedHttpError:
                        (controller, request, response) {
                      if (request.isForMainFrame != true) return;

                      final status = response.statusCode;

                      if (status != null && status >= 400) {
                        _showError(
                          'El servidor respondió con el código '
                          'HTTP $status.\n\n'
                          'Puede ser un error del sitio, una '
                          'restricción o una página temporalmente '
                          'no disponible.',
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
                              children: [
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  color: _pink,
                                  size: 54,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'NO SE PUDO CARGAR LA AGENDA',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _cyan,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.5,
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
                                    label: const Text(
                                      'VOLVER A INTENTAR',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Si el sitio bloquea navegadores '
                                  'integrados o no responde, el '
                                  'código de la aplicación no puede '
                                  'obligarlo a funcionar.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
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