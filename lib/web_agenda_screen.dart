import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'web_protection_policy.dart';
import 'app_i18n.dart';
import 'automatic_live_service.dart';

const Color _brandBg = Color(0xFF030814);
const Color _brandPanel = Color(0xFF071326);
const Color _brandLine = Color(0xFF123D65);
const Color _brandCyan = Color(0xFF00E5FF);
const Color _brandBlue = Color(0xFF087BFF);
const Color _brandGreen = Color(0xFF39FF9C);
const Color _brandMuted = Color(0xFFA9BDD6);
const Color _brandRed = Color(0xFFFF3155);

/// Web de agenda dentro de la identidad visual de Deporte Total 360°.
/// El contenido de la web y sus reproductores siguen perteneciendo al proveedor.
class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({
    super.key,
    required this.onExit,
    required this.onOpenLive,
    this.pageTitle = 'AGENDA DEPORTIVA',
    this.showLiveButton = true,
  });

  final VoidCallback onExit;
  final VoidCallback onOpenLive;
  final String pageTitle;
  final bool showLiveButton;

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

  List<ContentBlocker> _buildContentBlockers() => WebProtectionPolicy.buildContentBlockers();

  bool _isHttpUrl(WebUri uri) {
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'https' || scheme == 'http') && uri.host.isNotEmpty;
  }

  bool _isFutbolLibrePlaybackRoute(WebUri url) {
    final uri = Uri.tryParse(url.toString());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final isAgendaHost = host == 'futbol-libre.cam' ||
        host.endsWith('.futbol-libre.cam');
    if (!isAgendaHost) return false;
    return RegExp(
      r'(?:^|/)(?:canal|channel|player|watch|stream|live|embed|partido|match|fixture|encuentro)(?:/|$)',
      caseSensitive: false,
    ).hasMatch(uri.path);
  }

  void _showNotice(String message) {
    if (!mounted) return;
    setState(() => _noticeMessage = message);
  }

  Future<void> _installAdElementCleanup(InAppWebViewController controller) async {
    // Elimina solo elementos publicitarios identificables. No elimina iframes
    // genéricos ni elementos que formen parte de un reproductor de vídeo.
    try {
      await controller.evaluateJavascript(source: r'''
        (() => {
          const selectors = [
            'iframe[src*="juicyads"]',
            'iframe[src*="trafficjunky"]',
            'iframe[src*="porn"]',
            'iframe[src*="porno"]',
            'iframe[src*="adult"]',
            'iframe[src*="xxx"]',
            'iframe[src*="popads"]',
            'iframe[src*="popcash"]',
            'iframe[src*="popunder"]',
            '[id*="popunder"]',
            '[class*="popunder"]',
            '[id*="interstitial"]',
            '[class*="interstitial"]',
            '[data-advertisement]',
            '[data-ad="true"]',
            'ins.adsbygoogle'
          ];
          const selector = selectors.join(',');
          const insidePlayer = (element) =>
            !!element.closest('video,audio,.video-player,[class*="player"],[id*="player"]');
          const removeAds = (root) => {
            if (!root || !root.querySelectorAll) return;
            root.querySelectorAll(selector).forEach((element) => {
              if (!insidePlayer(element)) element.remove();
            });
          };
          removeAds(document);
          if (!window.__dt360AdObserver && document.documentElement) {
            window.__dt360AdObserver = new MutationObserver((records) => {
              records.forEach((record) => record.addedNodes.forEach((node) => {
                if (node.nodeType !== 1) return;
                if (node.matches && node.matches(selector)) {
                  if (!insidePlayer(node)) node.remove();
                } else {
                  removeAds(node);
                }
              }));
            });
            window.__dt360AdObserver.observe(document.documentElement, {
              childList: true,
              subtree: true
            });
          }
        })();
      ''');
    } catch (_) {
      // La WebView permanece funcional si el sitio impide la limpieza DOM.
    }
  }


  Future<void> _installAgendaEventScanner(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: r'''
        (() => {
          const scan = () => {
            const nodes = Array.from(document.querySelectorAll(
              'article,li,[data-event],[class*="match"],[class*="fixture"],[class*="event"],a[href]'
            ));
            const found = [];
            const seen = new Set();
            const now = new Date();
            const timePattern = /\b(2[0-3]|[01]?\d):([0-5]\d)\b|\b(1[0-2]|0?[1-9]):([0-5]\d)\s*(AM|PM)\b/i;
            for (const node of nodes) {
              const rawText = (node.innerText || node.textContent || '').replace(/\s+/g, ' ').trim();
              if (rawText.length < 12 || rawText.length > 500) continue;
              const timeMatch = rawText.match(timePattern);
              if (!timeMatch) continue;
              const anchor = node.matches('a[href]') ? node : node.querySelector('a[href]');
              if (!anchor || !anchor.href || !/^https?:/i.test(anchor.href)) continue;
              if (/\/canal\/|\/channel\//i.test(new URL(anchor.href).pathname)) continue;
              const heading = node.querySelector('h1,h2,h3,h4,[class*="title"],[class*="team"]');
              let title = (heading && heading.textContent || anchor.textContent || '').replace(/\s+/g, ' ').trim();
              if (title.length < 5) title = rawText;
              title = title.replace(/\b(EN VIVO|VER PARTIDO|VER AHORA|DETALLES)\b/ig, '').replace(timePattern, '').trim();
              const pair = title.split(/\s+(?:vs?\.?|versus|contra|[-–—])\s+/i);
              if (pair.length < 2) continue;
              let hour = parseInt(timeMatch[1] || timeMatch[3], 10);
              const minute = parseInt(timeMatch[2] || timeMatch[4], 10);
              if (timeMatch[5]) {
                if (timeMatch[5].toUpperCase() === 'PM' && hour < 12) hour += 12;
                if (timeMatch[5].toUpperCase() === 'AM' && hour === 12) hour = 0;
              }
              let start = null;
              const timeNode = node.querySelector('time[datetime]');
              const dateValue = (timeNode && timeNode.getAttribute('datetime')) ||
                node.getAttribute('datetime') ||
                node.getAttribute('data-start') ||
                node.getAttribute('data-date') ||
                (node.dataset && (node.dataset.start || node.dataset.datetime || node.dataset.date));
              if (dateValue) {
                const parsed = new Date(dateValue);
                if (!Number.isNaN(parsed.getTime())) start = parsed;
              }
              if (!start) {
                start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0);
              }
              let end = null;
              const endValue = node.getAttribute('data-end') ||
                (node.dataset && (node.dataset.end || node.dataset.endTime));
              if (endValue) {
                const parsedEnd = new Date(endValue);
                if (!Number.isNaN(parsedEnd.getTime())) end = parsedEnd;
              }
              const textLower = rawText.toLowerCase();
              if (/finalizado|terminado|finished|final\b/.test(textLower)) end = now;
              const iso = start.toISOString();
              const endIso = end ? end.toISOString() : null;
              const key = anchor.href + '|' + title + '|' + iso;
              if (seen.has(key)) continue;
              seen.add(key);
              let sport = 'Fútbol';
              if (/nba|basquet|basketball/.test(textLower)) sport = 'Básquet';
              else if (/tenis|tennis/.test(textLower)) sport = 'Tenis';
              else if (/formula 1|f1\b/.test(textLower)) sport = 'Fórmula 1';
              else if (/beisbol|baseball/.test(textLower)) sport = 'Béisbol';
              const eventId = (node.dataset && (node.dataset.eventId || node.dataset.fixtureId)) ||
                anchor.href.split('/').filter(Boolean).pop() || key;
              const competitionNode = node.querySelector(
                '[class*="competition"],[class*="league"],[data-league]'
              );
              const competition = (competitionNode && competitionNode.textContent || '').replace(/\s+/g, ' ').trim();
              found.push({
                id: String(eventId),
                title: title,
                sport: sport,
                competition: competition,
                homeTeam: pair[0].trim(),
                awayTeam: pair.slice(1).join(' vs ').trim(),
                startsAt: iso,
                endsAt: endIso,
                detailUrl: anchor.href
              });
            }
            if (found.length && window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('dt360AgendaEvents', found);
            }
          };
          if (!window.__dt360AgendaScanner) {
            window.__dt360AgendaScanner = true;
            const run = () => { try { scan(); } catch (_) {} };
            run();
            window.setInterval(run, 15000);
            if (document.documentElement) {
              new MutationObserver(run).observe(document.documentElement, {
                childList: true, subtree: true, characterData: true
              });
            }
          } else {
            scan();
          }
        })();
      ''');
    } catch (_) {
      // No se interrumpe la agenda si el proveedor no permite inyección.
    }
  }

  Future<void> _installAgendaOnlyMode(InAppWebViewController controller) async {
    // La pestaña Agenda solo conserva los datos del calendario. Se ocultan y
    // detienen reproductores incrustados y se impide abrir páginas de partidos.
    try {
      await controller.evaluateJavascript(source: r'''
        (() => {
          const removeEmbeddedPlayers = () => {
            const selectors = [
              'video', 'audio', 'object', 'embed',
              'iframe[src*="player"]', 'iframe[src*="embed"]',
              'iframe[src*="stream"]', 'iframe[src*="live"]',
              'iframe[src*="m3u8"]'
            ];
            document.querySelectorAll(selectors.join(',')).forEach((element) => {
              try { element.pause?.(); } catch (_) {}
              try { element.remove(); } catch (_) {}
            });
          };
          removeEmbeddedPlayers();
          if (!window.__dt360AgendaPlayerObserver && document.documentElement) {
            window.__dt360AgendaPlayerObserver = true;
            new MutationObserver(removeEmbeddedPlayers).observe(document.documentElement, {
              childList: true, subtree: true
            });
          }

          if (!window.__dt360AgendaOnlyClickGuard) {
            window.__dt360AgendaOnlyClickGuard = true;
            document.addEventListener('click', (event) => {
              const target = event.target instanceof Element
                ? event.target : event.target?.parentElement;
              const anchor = target?.closest('a[href]');
              if (!anchor) return;

              const card = anchor.closest(
                'article,li,[data-event],[class*="match"],[class*="fixture"],[class*="event"]'
              ) || anchor.parentElement;
              const cardText = (card?.innerText || card?.textContent || '')
                .replace(/\s+/g, ' ').trim();
              const eventCard = /\b(?:2[0-3]|[01]?\d):[0-5]\d\b/.test(cardText) &&
                /\b(?:vs?\.?|versus|contra)\b/i.test(cardText);
              const path = new URL(anchor.href, location.href).pathname;
              const playerPath = /(?:^|\/)(?:canal|channel|player|watch|stream|live|embed|partido|match)(?:\/|$)/i
                .test(path);
              const actionText = (anchor.innerText || anchor.textContent || '').trim();
              const playerAction = /VER\s+(?:PARTIDO|AHORA|EN\s+VIVO)|EN\s+VIVO|WATCH|PLAY|REPRODUCIR/i
                .test(actionText);
              if (!eventCard && !playerPath && !playerAction) return;

              event.preventDefault();
              event.stopPropagation();
              event.stopImmediatePropagation();
              window.flutter_inappwebview?.callHandler('dt360AgendaOnlyNotice');
            }, true);
          }
        })();
      ''');
    } catch (_) {
      // Un fallo de inyección no debe interrumpir la lectura de la agenda.
    }
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

    if (_isFutbolLibrePlaybackRoute(target)) {
      _showNotice(
        'La Agenda solo muestra horarios y equipos. Las transmisiones de Fútbol Libre están desactivadas en esta pestaña.',
      );
      return false;
    }

    if (WebProtectionPolicy.isBlockedUrl(target.toString())) {
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
          tooltip: _canGoBack ? 'Volver a la página anterior' : 'Volver a Inicio',
          onPressed: _handleToolbarBack,
          icon: const Icon(Icons.arrow_back_rounded, color: _brandCyan),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.pageTitle,
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
          if (widget.showLiveButton)
            TextButton.icon(
              onPressed: widget.onOpenLive,
              icon: const Icon(Icons.play_circle_fill_rounded, color: _brandGreen, size: 17),
              label: Text(appText('VIVO AQUÍ', 'WATCH LIVE', 'AO VIVO AQUI', 'REGARDER EN DIRECT'), style: const TextStyle(color: _brandGreen, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
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
                  activeThumbColor: _brandGreen,
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
                        useShouldInterceptRequest: true,
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
                        controller.addJavaScriptHandler(
                          handlerName: 'dt360AgendaOnlyNotice',
                          callback: (arguments) async {
                            _showNotice(
                              'Agenda: solo horarios y eventos',
                              'Los reproductores y enlaces de transmisiones de Fútbol Libre están desactivados aquí. La APK busca la señal en sus listas M3U y EPG.',
                            );
                            return true;
                          },
                        );
                        controller.addJavaScriptHandler(
                          handlerName: 'dt360AgendaEvents',
                          callback: (arguments) async {
                            if (arguments.isEmpty || arguments.first is! List) {
                              return 0;
                            }
                            final events = (arguments.first as List)
                                .map(FutbolLibreEvent.fromJson)
                                .whereType<FutbolLibreEvent>()
                                .toList(growable: false);
                            if (events.isNotEmpty) {
                              await FutbolLibreAgendaStore.save(events);
                            }
                            return events.length;
                          },
                        );
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
                        await _installAdElementCleanup(controller);
                        await _installAgendaEventScanner(controller);
                        await _installAgendaOnlyMode(controller);
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

                        if (_isFutbolLibrePlaybackRoute(uri)) {
                          _showNotice(
                            'La Agenda solo muestra horarios y equipos. Las transmisiones de Fútbol Libre están desactivadas en esta pestaña.',
                          );
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (WebProtectionPolicy.isBlockedUrl(uri.toString())) {
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
                      shouldInterceptRequest: _blockKnownTrackers
                          ? (controller, request) async => WebProtectionPolicy.intercept(request)
                          : null,
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