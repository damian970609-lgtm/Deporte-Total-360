import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const Color _fantasyBg = Color(0xFF030814);
const Color _fantasyPanel = Color(0xFF071326);
const Color _fantasyLine = Color(0xFF123D65);
const Color _fantasyCyan = Color(0xFF00E5FF);
const Color _fantasyBlue = Color(0xFF087BFF);
const Color _fantasyPink = Color(0xFFFF28CF);
const Color _fantasyMuted = Color(0xFFA9BDD6);

/// Contenedor con la identidad Deporte Total 360° para el servicio oficial
/// Mister Fantasy. No copia ni modifica el código, marca o interfaz interna
/// del servicio: el contenido se carga desde el dominio de su propietario.
class FantasyScreen extends StatefulWidget {
  const FantasyScreen({super.key});

  static const String officialUrl =
      'https://mister.mundodeportivo.com/new-onboarding/';

  @override
  State<FantasyScreen> createState() => _FantasyScreenState();
}

class _FantasyScreenState extends State<FantasyScreen> {
  InAppWebViewController? _controller;
  bool _loading = true;
  bool _allowPop = false;
  bool _handlingBack = false;
  double _progress = 0;
  String? _error;

  Future<void> _handleBackRequest() async {
    if (_handlingBack) return;
    _handlingBack = true;

    try {
      final controller = _controller;
      if (controller != null) {
        try {
          if (await controller.canGoBack()) {
            await controller.goBack();
            return;
          }
        } catch (_) {
          // Si el historial no está disponible, se cierra el módulo.
        }
      }

      if (!mounted) return;
      setState(() => _allowPop = true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    } finally {
      _handlingBack = false;
    }
  }

  Future<bool> _handleNewWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final target = action.request.url;

    if (target == null ||
        target.host.isEmpty ||
        (target.scheme != 'https' && target.scheme != 'http')) {
      return false;
    }

    // Los enlaces target=_blank se abren dentro del WebView actual.
    // El usuario conserva el marco de Deporte Total 360° y puede volver atrás.
    try {
      await controller.loadUrl(urlRequest: action.request);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo abrir esta sección de Mister Fantasy.';
          _loading = false;
        });
      }
    }
    return false;
  }

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _progress = 0;
    });

    try {
      await controller.reload();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo recargar Mister Fantasy. Comprueba tu conexión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackRequest();
      },
      child: Scaffold(
        backgroundColor: _fantasyBg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF020B19),
          leading: IconButton(
            tooltip: 'Atrás',
            onPressed: _handleBackRequest,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _fantasyCyan,
            ),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'FANTASY DEPORTE TOTAL 360°',
                style: TextStyle(
                  color: _fantasyCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Servicio oficial de Mister Fantasy',
                style: TextStyle(
                  color: _fantasyMuted,
                  fontSize: 9,
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
                color: _fantasyCyan,
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFF071A39),
                    Color(0xFF150B30),
                  ],
                ),
                border: Border(bottom: BorderSide(color: _fantasyLine)),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.emoji_events_rounded,
                    color: _fantasyPink,
                    size: 17,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Mercado, plantillas, jornadas y puntuaciones gestionados por Mister.',
                      style: TextStyle(
                        color: _fantasyMuted,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 2,
                backgroundColor: _fantasyPanel,
                color: _fantasyCyan,
              ),
            Expanded(
              child: _error != null
                  ? _errorPanel()
                  : InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(FantasyScreen.officialUrl),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        databaseEnabled: true,
                        thirdPartyCookiesEnabled: true,
                        supportMultipleWindows: true,
                        javaScriptCanOpenWindowsAutomatically: true,
                        useShouldOverrideUrlLoading: true,
                        safeBrowsingEnabled: true,
                        hardwareAcceleration: true,
                        allowFileAccess: false,
                        mediaPlaybackRequiresUserGesture: true,
                        allowsInlineMediaPlayback: true,
                        iframeAllowFullscreen: true,
                      ),
                      onWebViewCreated: (controller) {
                        _controller = controller;
                      },
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
                        if (!mounted) return;
                        setState(() {
                          _loading = false;
                          _progress = 1;
                        });
                      },
                      shouldOverrideUrlLoading: (controller, action) async {
                        final uri = action.request.url;

                        if (uri == null) {
                          return NavigationActionPolicy.ALLOW;
                        }

                        if (uri.scheme == 'https' || uri.scheme == 'http') {
                          // Mantener inicios de sesión y rutas oficiales dentro
                          // del WebView de la aplicación.
                          return NavigationActionPolicy.ALLOW;
                        }

                        return NavigationActionPolicy.CANCEL;
                      },
                      onCreateWindow: _handleNewWindow,
                      onReceivedError: (controller, request, error) {
                        if (!(request.isForMainFrame ?? true) || !mounted) {
                          return;
                        }

                        setState(() {
                          _loading = false;
                          _error =
                              'No se pudo cargar Mister Fantasy. Revisa la conexión y vuelve a intentarlo.';
                        });
                      },
                      onReceivedHttpError: (controller, request, response) {
                        if (!(request.isForMainFrame ?? true) || !mounted) {
                          return;
                        }

                        final status = response.statusCode ?? 0;
                        if (status >= 400) {
                          setState(() {
                            _loading = false;
                            _error =
                                'Mister Fantasy devolvió un error HTTP $status.';
                          });
                        }
                      },
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              color: const Color(0xFF020B19),
              child: const Text(
                'Mister Fantasy es un servicio externo. Su cuenta, marca, contenido y funciones se rigen por sus condiciones y disponibilidad.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _fantasyMuted,
                  fontSize: 9,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
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
              Icons.cloud_off_rounded,
              color: _fantasyPink,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'FANTASY NO DISPONIBLE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'No se pudo abrir el servicio.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _fantasyMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('REINTENTAR'),
              style: FilledButton.styleFrom(
                backgroundColor: _fantasyBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}