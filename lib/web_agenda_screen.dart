import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const Color _appBg = Color(0xFF030814);
const Color _appPanel = Color(0xFF071326);
const Color _appLine = Color(0xFF123D65);
const Color _appCyan = Color(0xFF00E5FF);
const Color _appBlue = Color(0xFF087BFF);
const Color _appGreen = Color(0xFF39FF9C);
const Color _appPink = Color(0xFFFF28CF);
const Color _appRed = Color(0xFFFF3155);
const Color _appMuted = Color(0xFFA9BDD6);

/// Integra la agenda de un proveedor externo en el marco visual de
/// DEPORTE TOTAL 360°. El sitio sigue siendo contenido de un tercero.
class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({super.key});

  static const String agendaUrl = 'https://futbol-libre.cam/';

  @override
  State<WebAgendaScreen> createState() => _WebAgendaScreenState();
}

class _WebAgendaScreenState extends State<WebAgendaScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = true;
  String? _error;
  String? _notice;
  late final List<ContentBlocker> _contentBlockers;

  static const List<String> _adUrlFilters = <String>[
    r'.*doubleclick\.net/.*',
    r'.*googlesyndication\.com/.*',
    r'.*googleadservices\.com/.*',
    r'.*adservice\.google\..*/.*',
    r'.*ads\.pubmatic\.com/.*',
    r'.*adnxs\.com/.*',
    r'.*popads\.net/.*',
    r'.*popcash\.net/.*',
    r'.*adsterra\.com/.*',
    r'.*propellerads\.com/.*',
    r'.*exoclick\.com/.*',
    r'.*onclickads\.net/.*',
    r'.*outbrain\.com/.*',
    r'.*taboola\.com/.*',
    r'.*trafficjunky\.net/.*',
    r'.*adskeeper\.[^/]+/.*',
    r'.*push-notification\.tools/.*',
  ];

  @override
  void initState() {
    super.initState();

    _contentBlockers = <ContentBlocker>[
      for (final filter in _adUrlFilters)
        ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: filter),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK,
          ),
        ),
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: r'https?://(www\.)?futbol-libre\.cam/.*',
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.CSS_DISPLAY_NONE,
          selector: '.ads, .ad-container, .ad-banner, .advertisement, '
              '.advertising, .widget-ads, .ad-unit, [id^="ad-container"], '
              '[class*="ad-container"], [id*="google_ads"]',
        ),
      ),
    ];
  }

  bool _isTrustedHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'futbol-libre.cam' ||
        normalized == 'www.futbol-libre.cam' ||
        normalized.endsWith('.futbol-libre.cam');
  }

  bool _isHttpOrHttps(WebUri uri) =>
      uri.scheme == 'https' || uri.scheme == 'http';

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
      _progress = 0;
    });
    await _controller?.reload();
  }

  Future<void> _goBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya estás en la primera página de la agenda.'),
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    setState(() => _notice = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        foregroundColor: Colors.white,
        titleSpacing: 12,
        title: const Row(
          children: <Widget>[
            Icon(
              Icons.calendar_month_rounded,
              color: _appGreen,
              size: 25,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'AGENDA DE PARTIDOS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .35,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Volver dentro de la agenda',
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _appCyan,
            ),
          ),
          IconButton(
            tooltip: 'Recargar agenda',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, color: _appCyan),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFF071A39),
                  Color(0xFF150B30),
                ],
              ),
              border: Border(bottom: BorderSide(color: _appLine)),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.shield_outlined, color: _appCyan, size: 16),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Vista integrada · bloqueador parcial de anuncios y ventanas emergentes',
                    style: TextStyle(
                      color: _appMuted,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ),
                Icon(Icons.bolt_rounded, color: _appPink, size: 16),
              ],
            ),
          ),
          if (_notice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              color: const Color(0xFF3A1B20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    color: _appRed,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _notice!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: () => setState(() => _notice = null),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          if (_loading && _progress < 1)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              minHeight: 2,
              backgroundColor: _appPanel,
              color: _appCyan,
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(7, 7, 7, 7),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: _appBlue.withAlpha(170)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _appBlue.withAlpha(28),
                    blurRadius: 14,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _error != null
                  ? _errorPanel()
                  : InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(WebAgendaScreen.agendaUrl),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        javaScriptCanOpenWindowsAutomatically: false,
                        supportMultipleWindows: true,
                        mediaPlaybackRequiresUserGesture: true,
                        allowsInlineMediaPlayback: true,
                        contentBlockers: _contentBlockers,
                        transparentBackground: false,
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
                          _error = null;
                          _progress = 0;
                        });
                      },
                      onProgressChanged: (controller, progress) {
                        if (!mounted) return;
                        setState(() {
                          _progress = progress / 100;
                          if (progress >= 100) _loading = false;
                        });
                      },
                      onLoadStop: (controller, url) async {
                        await _applyBrandStyles(controller);
                        if (!mounted) return;
                        setState(() {
                          _loading = false;
                          _progress = 1;
                        });
                      },
                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                        final uri = navigationAction.request.url;
                        if (uri == null || !_isHttpOrHttps(uri)) {
                          _showMessage(
                            'Se bloqueó un enlace no seguro o un esquema externo.',
                          );
                          return NavigationActionPolicy.CANCEL;
                        }

                        // La ventana principal se mantiene en el sitio elegido.
                        // Los reproductores incrustados pueden cargar recursos
                        // de terceros dentro de sus iframes.
                        if ((navigationAction.isForMainFrame ?? true) &&
                            !_isTrustedHost(uri.host)) {
                          _showMessage(
                            'Redirección externa bloqueada para evitar salir '
                            'de la agenda. Si el vídeo solo funciona en otra '
                            'página, no se abrirá aquí automáticamente.',
                          );
                          return NavigationActionPolicy.CANCEL;
                        }

                        return NavigationActionPolicy.ALLOW;
                      },
                      onCreateWindow: (controller, createWindowAction) async {
                        _showMessage(
                          'Se bloqueó una ventana emergente para evitar que '
                          'el botón Play abra otra página. El vídeo solo '
                          'funcionará si el reproductor está integrado en '
                          'la página actual.',
                        );
                        // No crear ventanas nuevas: bloquea pop-ups.
                        return false;
                      },
                      onReceivedError: (controller, request, error) {
                        if (!(request.isForMainFrame ?? true) || !mounted) {
                          return;
                        }
                        setState(() {
                          _loading = false;
                          _error = 'No se pudo cargar la agenda. Comprueba tu '
                              'conexión o que el sitio siga disponible. '
                              'Código: ${error.type}';
                        });
                      },
                    ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 7),
            color: const Color(0xFF020B19),
            child: const Text(
              'La página y sus transmisiones pertenecen a sus proveedores. '
              'El bloqueo no es total: algunos anuncios o redireccionamientos '
              'pueden escapar y ciertos reproductores pueden requerir otra ventana.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _appMuted,
                fontSize: 9,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyBrandStyles(
    InAppWebViewController controller,
  ) async {
    // Colorea los controles visibles con la paleta de la app, sin sustituir
    // logotipos, textos de autoría ni el contenido del proveedor externo.
    const script = r"""
      (function () {
        try {
          var id = 'deporte-total-360-theme';
          var style = document.getElementById(id);
          if (!style) {
            style = document.createElement('style');
            style.id = id;
            (document.head || document.documentElement).appendChild(style);
          }
          style.textContent = `
            :root {
              color-scheme: dark !important;
              --dt360-bg: #030814;
              --dt360-panel: #071326;
              --dt360-line: #123d65;
              --dt360-cyan: #00e5ff;
              --dt360-blue: #087bff;
              --dt360-pink: #ff28cf;
              --dt360-green: #39ff9c;
            }
            html, body {
              background-color: #030814 !important;
              color: #f4f8ff !important;
            }
            header, nav, .navbar, .topbar, .header, .site-header {
              background-color: #071326 !important;
              border-color: #123d65 !important;
            }
            a, .link, .text-link { color: #00e5ff !important; }
            button, .btn, [role="button"] {
              border-radius: 9px !important;
              border-color: #087bff !important;
            }
            .ads, .ad-container, .ad-banner, .advertisement,
            .advertising, .widget-ads, .ad-unit,
            [id^="ad-container"], [class*="ad-container"],
            [id*="google_ads"] {
              display: none !important;
            }
          `;
          // Impide que window.open abra una ventana desde la página.
          try { window.open = function () { return null; }; } catch (_) {}
          return true;
        } catch (_) {
          return false;
        }
      })();
    """;

    try {
      await controller.evaluateJavascript(source: script);
    } catch (_) {
      // Si el sitio impide esta inyección, el WebView conserva sus otros
      // controles de navegación y sus reglas de bloqueo de recursos.
    }
  }

  Widget _errorPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.wifi_off_rounded,
              color: _appRed,
              size: 45,
            ),
            const SizedBox(height: 12),
            const Text(
              'AGENDA NO DISPONIBLE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'No se pudo abrir la página.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _appMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('REINTENTAR'),
              style: FilledButton.styleFrom(
                backgroundColor: _appBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}