import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

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

    setState(() {
      _activeUrl = url;
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
        urlRequest: URLRequest(url: WebUri(url)),
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

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(_activeUrl);

    if (uri == null) {
      _setError('La dirección web no es válida.');
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _setError(
          'Android no encontró una aplicación para abrir esta dirección.',
        );
      }
    } catch (error) {
      _setError('No se pudo abrir el navegador: $error');
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
        // Si el historial no está disponible, vuelve a la pantalla principal.
      }
    }

    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<NavigationActionPolicy> _allowSafeWebNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;

    if (uri == null) {
      return NavigationActionPolicy.CANCEL;
    }

    // Se permiten redirecciones HTTP/HTTPS a otros dominios.
    // Muchas páginas de agenda y reproductores usan varios dominios.
    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'https' || scheme == 'http') {
      return NavigationActionPolicy.ALLOW;
    }

    // Se bloquean esquemas externos como intent:, market:, file: y javascript:.
    return NavigationActionPolicy.CANCEL;
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
          actions: [
            IconButton(
              tooltip: 'Abrir en Chrome/navegador',
              onPressed: _openInBrowser,
              icon: const Icon(
                Icons.open_in_browser_rounded,
                color: _cyan,
              ),
            ),
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
                    onLoadStop: (controller, url) {
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
                    onReceivedHttpError:
                        (controller, request, response) {
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
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  onPressed: _openInBrowser,
                                  icon: const Icon(
                                    Icons.open_in_browser_rounded,
                                  ),
                                  label: const Text('PROBAR EN CHROME'),
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