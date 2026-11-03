import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'web_protection_policy.dart';
import 'app_i18n.dart';
import 'futbol_libre_agenda.dart';

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
    this.pageUrl = initialUrl,
  });

  final VoidCallback onExit;
  final VoidCallback onOpenLive;
  final String pageUrl;

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

  void _showNotice(String message) {
    if (!mounted) return;
    setState(() => _noticeMessage = message);
  }

  Future<void> _installAgendaExtraction(InAppWebViewController controller) async {
    // Lee únicamente los datos que Fútbol Libre ya muestra en su propia agenda.
    // No busca URLs internas de vídeo ni intenta abrir reproductores ocultos.
    try {
      await controller.evaluateJavascript(source: r'''
        (() => {
          if (window.__dt360AgendaInstalled) {
            window.__dt360ExtractAgenda?.();
            return;
          }
          window.__dt360AgendaInstalled = true;

          const clean = (value) => String(value || '')
            .replace(/\u00a0/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
          const channelPattern = /\b(ESPN(?:\s*\d+)?|DSports(?:\s*\d+)?|TyC Sports|FOX Sports(?:\s*\d+)?|Liga 1 MAX|TNT Sports|GolTV|Win Sports|TUDN|Claro Sports|DAZN)\b/i;
          const eventPattern = /\b(vs\.?|versus|v\.|contra)\b|(?:\s[-–—]\s)/i;
          const sportFor = (text) => {
            const value = text.toLowerCase();
            if (/\bnba\b|basketball|básquet|baloncesto/.test(value)) return 'NBA';
            if (/baseball|béisbol/.test(value)) return 'Béisbol';
            if (/tennis|tenis/.test(value)) return 'Tenis';
            if (/hockey/.test(value)) return 'Hockey';
            if (/volleyball|voleibol|vóley/.test(value)) return 'Vóley';
            if (/formula\s*1|fórmula\s*1|\bf1\b/.test(value)) return 'Fórmula 1';
            if (/rugby/.test(value)) return 'Rugby';
            if (/ufc|mma|artes marciales/.test(value)) return 'MMA';
            return 'Fútbol';
          };
          const matchLine = (text) => {
            const pattern = /^(.{2,65}?)\s+(?:vs\.?|versus|v\.|contra|[-–—])\s+(.{2,65}?)(?=\s+(?:\d{1,2}:\d{2}|EN VIVO|LIVE|HOY|MAÑANA|FINAL|FT)\b|$)/i;
            const parse = (line) => {
              const found = clean(line).match(pattern);
              if (!found) return null;
              const home = clean(found[1]).replace(/^(?:partido|evento)\s*[:|-]\s*/i, '');
              const away = clean(found[2]).replace(/\s+(?:EN VIVO|LIVE|HOY|MAÑANA|FINAL|FT).*$/i, '');
              return home && away ? { home, away } : null;
            };
            const lines = String(text || '').split(/\n+/).map(clean).filter(Boolean);
            for (const line of lines) {
              if (line.length > 150) continue;
              const parsed = parse(line);
              if (parsed) return parsed;
            }
            return parse(clean(text));
          };
          const dateFor = (element, text) => {
            const time = element.querySelector('time[datetime], [datetime]');
            const raw = time?.getAttribute('datetime') ||
              element.getAttribute('data-start') ||
              element.getAttribute('data-date') ||
              element.getAttribute('datetime');
            if (raw) {
              const parsed = new Date(raw);
              if (!Number.isNaN(parsed.getTime())) return parsed.toISOString();
            }
            const clock = clean(text).match(/\b([01]?\d|2[0-3]):([0-5]\d)\b/);
            if (!clock) return null;
            const date = new Date();
            date.setHours(Number(clock[1]), Number(clock[2]), 0, 0);
            return date.toISOString();
          };
          const getCandidates = () => {
            const selector = 'article, li, [data-event-id], [class*="match"], [class*="event"], [class*="fixture"], [class*="game"], [class*="partido"]';
            const elements = Array.from(document.querySelectorAll(selector));
            return elements.filter((element) => {
              const text = clean(element.innerText || element.textContent);
              if (text.length < 12 || text.length > 1000 || !eventPattern.test(text)) return false;
              return !Array.from(element.children).some((child) => {
                const childText = clean(child.innerText || child.textContent);
                return childText.length >= 12 && childText.length < text.length && eventPattern.test(childText);
              });
            });
          };

          window.__dt360ExtractAgenda = () => {
            try {
              const events = [];
              for (const element of getCandidates()) {
                const text = clean(element.innerText || element.textContent);
                const teams = matchLine(element.innerText || element.textContent);
                const startsAt = dateFor(element, text);
                if (!teams || !startsAt) continue;

                const channels = [];
                for (const link of Array.from(element.querySelectorAll('a[href]'))) {
                  const name = clean(link.innerText || link.textContent);
                  if (!channelPattern.test(name)) continue;
                  try {
                    const url = new URL(link.getAttribute('href'), location.href);
                    if (url.protocol !== 'https:' && url.protocol !== 'http:') continue;
                    if (!channels.some((item) => item.url === url.href)) {
                      channels.push({ name: name.slice(0, 80), url: url.href });
                    }
                  } catch (_) {}
                }

                const eventLink = Array.from(element.querySelectorAll('a[href]')).find((link) =>
                  /ver partido|ver evento|abrir partido|ver juego|partido completo/i.test(clean(link.innerText || link.textContent))
                );
                const fallbackLink = element.querySelector('a[href]');
                const detail = eventLink || fallbackLink;
                let competition = '';
                const heading = element.querySelector('h1,h2,h3,h4,[class*="league"],[class*="competition"]');
                if (heading) competition = clean(heading.innerText || heading.textContent);
                if (!competition) competition = 'Programación de Fútbol Libre';

                const statusText = text.match(/\b(en vivo|live|finalizado|final|finished|ft)\b/i);
                const sport = sportFor(text);
                const explicitId = element.getAttribute('data-event-id') ||
                  element.getAttribute('data-id') || element.id;
                const href = detail ? new URL(detail.getAttribute('href'), location.href).href : '';
                const id = explicitId || href || (
                  teams.home.toLowerCase() + '-' + teams.away.toLowerCase() + '-' + startsAt
                );
                events.push({
                  id: String(id).slice(0, 180),
                  sport,
                  competition,
                  homeTeam: teams.home,
                  awayTeam: teams.away,
                  startsAt,
                  status: statusText ? statusText[1] : 'programado',
                  detailUrl: href,
                  channels
                });
              }

              // Las fichas individuales pueden publicar la señal fuera
              // de la tarjeta del evento. Solo leemos enlaces web visibles.
              if (events.length === 0 && !/^\/(?:agenda)?\/?$/.test(location.pathname)) {
                const pageText = document.body?.innerText || '';
                const teams = matchLine(pageText);
                const startsAt = dateFor(document.body || document.documentElement, pageText);
                if (teams && startsAt) {
                  const channels = [];
                  for (const link of Array.from(document.querySelectorAll('a[href]'))) {
                    const name = clean(link.innerText || link.textContent);
                    if (!channelPattern.test(name)) continue;
                    try {
                      const url = new URL(link.getAttribute('href'), location.href);
                      if ((url.protocol === 'https:' || url.protocol === 'http:') &&
                          !channels.some((item) => item.url === url.href)) {
                        channels.push({ name: name.slice(0, 80), url: url.href });
                      }
                    } catch (_) {}
                  }
                  const heading = document.querySelector('h1,h2,h3');
                  events.push({
                    id: location.href,
                    sport: sportFor(pageText),
                    competition: heading ? clean(heading.innerText || heading.textContent) : 'Fútbol Libre',
                    homeTeam: teams.home,
                    awayTeam: teams.away,
                    startsAt,
                    status: /\b(en vivo|live)\b/i.test(pageText) ? 'live' : 'programado',
                    detailUrl: location.href,
                    channels
                  });
                }
              }

              const unique = new Map();
              for (const event of events) unique.set(event.id, event);
              const result = Array.from(unique.values())
                .sort((a, b) => Date.parse(a.startsAt) - Date.parse(b.startsAt));
              window.flutter_inappwebview?.callHandler('dt360AgendaEvents', result);
              return result.length;
            } catch (_) {
              return 0;
            }
          };

          window.__dt360ExtractAgenda();
          if (document.documentElement && window.MutationObserver) {
            window.__dt360AgendaObserver = new MutationObserver(() => {
              window.clearTimeout(window.__dt360AgendaDebounce);
              window.__dt360AgendaDebounce = window.setTimeout(
                () => window.__dt360ExtractAgenda?.(), 700
              );
            });
            window.__dt360AgendaObserver.observe(document.documentElement, {
              childList: true,
              subtree: true,
              characterData: true
            });
          }
        })();
      ''');
    } catch (_) {
      // La página sigue siendo navegable aunque cambie la estructura del sitio.
    }
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
                        url: WebUri(widget.pageUrl),
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
                          handlerName: 'dt360AgendaEvents',
                          callback: (args) {
                            if (args.isNotEmpty) {
                              FutbolLibreAgenda.publish(args.first);
                            }
                            return true;
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
                        await _installAgendaExtraction(controller);
                        await _installAdElementCleanup(controller);
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