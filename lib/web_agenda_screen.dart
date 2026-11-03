import 'dart:async';

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

  static const String initialUrl = 'https://www.marca.com/programacion-tv.html';

  @override
  State<WebAgendaScreen> createState() => WebAgendaScreenState();
}

class WebAgendaScreenState extends State<WebAgendaScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  // MARCA carga módulos de programación desde varios dominios. Se deja la
  // protección opcional desactivada inicialmente para no ocultar el calendario.
  bool _blockKnownTrackers = false;
  Timer? _loadTimeoutTimer;
  String? _errorMessage;
  String? _noticeMessage;

  List<ContentBlocker> _buildContentBlockers() => WebProtectionPolicy.buildContentBlockers();

  bool _isHttpUrl(WebUri uri) {
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'https' || scheme == 'http') && uri.host.isNotEmpty;
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    super.dispose();
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
              'article,li,tr,[data-event],[class*="match"],[class*="fixture"],[class*="event"],[class*="program"],[class*="guide"],[class*="schedule"],[class*="tv-item"],a[href]'
            ));
            const found = [];
            const seen = new Set();
            const now = new Date();
            // MARCA publica la programación en hora peninsular española.
            // Convertimos esa hora a un instante absoluto para mostrarla
            // correctamente en la zona horaria local del teléfono.
            const madridParts = new Intl.DateTimeFormat('en-GB', {
              timeZone: 'Europe/Madrid', year: 'numeric', month: '2-digit',
              day: '2-digit'
            }).formatToParts(now);
            const madridFields = Object.fromEntries(
              madridParts.map((part) => [part.type, part.value])
            );
            const madridToday = {
              year: Number(madridFields.year),
              month: Number(madridFields.month) - 1,
              day: Number(madridFields.day)
            };
            const madridDate = (year, month, day, hour, minute) => {
              const target = Date.UTC(year, month, day, hour, minute, 0);
              let candidate = new Date(target);
              for (let pass = 0; pass < 3; pass++) {
                const parts = new Intl.DateTimeFormat('en-GB', {
                  timeZone: 'Europe/Madrid', year: 'numeric', month: '2-digit',
                  day: '2-digit', hour: '2-digit', minute: '2-digit',
                  second: '2-digit', hourCycle: 'h23'
                }).formatToParts(candidate);
                const fields = Object.fromEntries(
                  parts.map((part) => [part.type, Number(part.value)])
                );
                const represented = Date.UTC(
                  fields.year, fields.month - 1, fields.day,
                  fields.hour, fields.minute, fields.second
                );
                candidate = new Date(candidate.getTime() + target - represented);
              }
              return candidate;
            };
            const timePattern = /\b(2[0-3]|[01]?\d):([0-5]\d)\b|\b(1[0-2]|0?[1-9]):([0-5]\d)\s*(AM|PM)\b/i;
            for (const sourceNode of nodes) {
              let node = sourceNode;
              // Algunos listados colocan la hora fuera del enlace del evento.
              // En ese caso se inspeccionan hasta cuatro contenedores padres.
              if (sourceNode.matches('a[href]')) {
                let parent = sourceNode.parentElement;
                for (let depth = 0; parent && depth < 4; depth++, parent = parent.parentElement) {
                  const parentText = (parent.innerText || parent.textContent || '')
                    .replace(/\s+/g, ' ').trim();
                  const hasTimeElement = !!(parent.querySelector &&
                    parent.querySelector('time[datetime],time'));
                  if (parentText.length >= 12 && parentText.length <= 500 &&
                      (timePattern.test(parentText) || hasTimeElement)) {
                    node = parent;
                    break;
                  }
                }
              }
              const rawText = (node.innerText || node.textContent || '').replace(/\s+/g, ' ').trim();
              if (rawText.length < 12 || rawText.length > 500) continue;
              const timeNode = node.querySelector('time');
              const timeText = timeNode
                ? [timeNode.textContent, timeNode.getAttribute('datetime')]
                    .filter(Boolean).join(' ')
                : '';
              const timeMatch = (rawText + ' ' + timeText).match(timePattern);
              if (!timeMatch) continue;
              const anchor = node.matches('a[href]') ? node : node.querySelector('a[href]');
              const eventContainer = node.matches(
                'article,li,[data-event],[class*="match"],[class*="fixture"],[class*="event"]'
              );
              const eventUrl = anchor && anchor.href ? anchor.href : location.href;
              if (!eventContainer && !anchor) continue;
              if (!/^https?:/i.test(eventUrl)) continue;
              if (anchor && /\/canal\/|\/channel\//i.test(new URL(eventUrl).pathname)) continue;
              const heading = node.querySelector('h1,h2,h3,h4,[class*="title"],[class*="team"]');
              let title = (heading && heading.textContent || rawText).replace(/\s+/g, ' ').trim();
              if (title.length < 5) title = rawText;
              title = title.replace(/\b(EN VIVO|VER PARTIDO|VER AHORA|DETALLES)\b/ig, '').replace(timePattern, '').trim();
              const pair = title.split(/\s+(?:vs?\.?|versus|contra|[-–—])\s+/i);
              const textLower = rawText.toLowerCase();
              let sport = 'Fútbol';
              if (/table tennis|tenis de mesa|ping\s?pong/.test(textLower)) sport = 'Tenis de mesa';
              else if (/nba|basquet|basketball|baloncesto/.test(textLower)) sport = 'Básquet';
              else if (/tenis|tennis|wta|atp/.test(textLower)) sport = 'Tenis';
              else if (/formula\s?1|f1\b/.test(textLower)) sport = 'Fórmula 1';
              else if (/motogp|moto\s?gp|motociclismo/.test(textLower)) sport = 'Motociclismo';
              else if (/nascar|rally|motorsport|automovilismo/.test(textLower)) sport = 'Automovilismo';
              else if (/beisbol|baseball|mlb\b/.test(textLower)) sport = 'Béisbol';
              else if (/futbol americano|american football|nfl\b|gridiron/.test(textLower)) sport = 'Fútbol americano';
              else if (/rugby/.test(textLower)) sport = 'Rugby';
              else if (/voleibol|volleyball/.test(textLower)) sport = 'Voleibol';
              else if (/cricket|críquet/.test(textLower)) sport = 'Críquet';
              else if (/hockey|nhl\b/.test(textLower)) sport = 'Hockey';
              else if (/boxeo|boxing|kickboxing/.test(textLower)) sport = 'Boxeo';
              else if (/mma\b|ufc\b|artes marciales mixtas/.test(textLower)) sport = 'MMA';
              else if (/wrestling|lucha libre/.test(textLower)) sport = 'Lucha libre';
              else if (/ciclismo|cycling/.test(textLower)) sport = 'Ciclismo';
              else if (/golf/.test(textLower)) sport = 'Golf';
              else if (/balonmano|handball/.test(textLower)) sport = 'Balonmano';
              else if (/atletismo|athletics/.test(textLower)) sport = 'Atletismo';
              else if (/natacion|swimming/.test(textLower)) sport = 'Natación';
              else if (/surf|skateboarding|snowboard|esports|e-sports/.test(textLower)) sport = 'Otros deportes';
              const individualSports = new Set([
                'Fórmula 1', 'Motociclismo', 'Automovilismo', 'Ciclismo',
                'Golf', 'Atletismo', 'Natación', 'Otros deportes'
              ]);
              if (pair.length < 2 && !individualSports.has(sport)) continue;
              let hour = parseInt(timeMatch[1] || timeMatch[3], 10);
              const minute = parseInt(timeMatch[2] || timeMatch[4], 10);
              if (timeMatch[5]) {
                if (timeMatch[5].toUpperCase() === 'PM' && hour < 12) hour += 12;
                if (timeMatch[5].toUpperCase() === 'AM' && hour === 12) hour = 0;
              }
              const parseDateHint = (raw) => {
                const value = (raw || '').toLowerCase().replace(/\s+/g, ' ').trim();
                if (!value) return null;
                if (/\b(mañana|tomorrow)\b/.test(value)) {
                  const next = new Date(Date.UTC(madridToday.year, madridToday.month, madridToday.day + 1));
                  return { year: next.getUTCFullYear(), month: next.getUTCMonth(), day: next.getUTCDate() };
                }
                if (/\b(hoy|today)\b/.test(value)) {
                  return madridToday;
                }
                let match = value.match(/\b(20\d{2})[-/](\d{1,2})[-/](\d{1,2})\b/);
                if (match) return { year: Number(match[1]), month: Number(match[2]) - 1, day: Number(match[3]) };
                match = value.match(/\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b/);
                if (match) {
                  let year = Number(match[3] || madridToday.year);
                  if (year < 100) year += 2000;
                  return { year, month: Number(match[2]) - 1, day: Number(match[1]) };
                }
                const months = {
                  enero: 0, febrero: 1, marzo: 2, abril: 3, mayo: 4, junio: 5,
                  julio: 6, agosto: 7, septiembre: 8, setiembre: 8,
                  octubre: 9, noviembre: 10, diciembre: 11
                };
                match = value.match(/\b(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)(?:\s+de\s+(20\d{2}))?\b/);
                if (match) {
                  let year = Number(match[3] || madridToday.year);
                  const month = months[match[2]];
                  if (!match[3] && month < madridToday.month - 5) year++;
                  return { year, month, day: Number(match[1]) };
                }
                return null;
              };
              let dateHint = null;
              let contextNode = node;
              for (let depth = 0; depth < 5 && contextNode && !dateHint; depth++) {
                const heading = contextNode.querySelector
                  ? contextNode.querySelector('h1,h2,h3,h4,[class*="date"],[class*="day"]')
                  : null;
                const contextText = [
                  contextNode.getAttribute && contextNode.getAttribute('data-date'),
                  contextNode.getAttribute && contextNode.getAttribute('data-day'),
                  contextNode.getAttribute && contextNode.getAttribute('datetime'),
                  heading && heading.textContent,
                  depth === 0 ? contextNode.innerText : null
                ].filter(Boolean).join(' ');
                dateHint = parseDateHint(contextText);
                contextNode = contextNode.parentElement;
              }
              let start = null;
              const dateValue = (timeNode && timeNode.getAttribute('datetime')) ||
                node.getAttribute('datetime') ||
                node.getAttribute('data-start') ||
                node.getAttribute('data-date') ||
                (node.dataset && (node.dataset.start || node.dataset.datetime || node.dataset.date));
              if (dateValue) {
                const parsed = new Date(dateValue);
                if (!Number.isNaN(parsed.getTime())) {
                  if (/T|\d{1,2}:\d{2}/i.test(dateValue)) {
                    const hasZone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(dateValue);
                    start = hasZone ? parsed : madridDate(
                      parsed.getFullYear(), parsed.getMonth(), parsed.getDate(),
                      parsed.getHours(), parsed.getMinutes()
                    );
                  } else {
                    const explicit = parseDateHint(dateValue) || dateHint;
                    if (explicit) start = madridDate(explicit.year, explicit.month, explicit.day, hour, minute);
                  }
                }
              }
              if (!start && dateHint) {
                start = madridDate(dateHint.year, dateHint.month, dateHint.day, hour, minute);
              }
              if (!start) {
                start = madridDate(madridToday.year, madridToday.month, madridToday.day, hour, minute);
                // Sin fecha explícita no se reutilizan horarios claramente caducados.
                if (start.getTime() < now.getTime() - 6 * 60 * 60 * 1000) continue;
              }
              let end = null;
              const endValue = node.getAttribute('data-end') ||
                (node.dataset && (node.dataset.end || node.dataset.endTime));
              if (endValue) {
                const parsedEnd = new Date(endValue);
                if (!Number.isNaN(parsedEnd.getTime())) {
                  const hasEndZone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(endValue);
                  end = hasEndZone ? parsedEnd : madridDate(
                    parsedEnd.getFullYear(), parsedEnd.getMonth(), parsedEnd.getDate(),
                    parsedEnd.getHours(), parsedEnd.getMinutes()
                  );
                }
              }
              const statusNode = node.querySelector(
                '[data-status],[class*="status"],[class*="state"]'
              );
              const statusText = (statusNode && statusNode.textContent || '')
                .replace(/\s+/g, ' ').trim().toLowerCase();
              if (/\b(?:finalizado|finalizada|terminado|terminada|finished|full time|ft)\b/.test(statusText) ||
                  /\b(?:FINALIZADO|TERMINADO|FULL TIME|FT)\b/i.test(rawText)) {
                end = now;
              }
              if (/\b(?:cancelado|cancelada|suspendido|suspendida)\b/.test(statusText)) continue;
              const iso = start.toISOString();
              const endIso = end ? end.toISOString() : null;
              const key = eventUrl + '|' + title + '|' + iso;
              if (seen.has(key)) continue;
              seen.add(key);
              const rawId = node.dataset && (node.dataset.eventId || node.dataset.fixtureId);
              const eventId = String(rawId || key);
              const competitionNode = node.querySelector(
                '[class*="competition"],[class*="league"],[data-league]'
              );
              const competition = (competitionNode && competitionNode.textContent || '').replace(/\s+/g, ' ').trim();
              const homeTeam = pair.length > 1 ? pair[0].trim() : '';
              const awayTeam = pair.length > 1 ? pair.slice(1).join(' vs ').trim() : '';
              const normalizeLabel = (value) => String(value || '')
                .normalize('NFD').replace(/[\\u0300-\\u036f]/g, '')
                .toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
              const imageNodes = Array.from(node.querySelectorAll('img'));
              const resolveImage = (image) => {
                if (!image) return '';
                const source = image.currentSrc ||
                  image.getAttribute('src') ||
                  image.getAttribute('data-src') ||
                  image.getAttribute('data-lazy-src') ||
                  image.getAttribute('data-original') ||
                  (image.getAttribute('srcset') || '').split(',')[0].trim().split(/\\s+/)[0];
                if (!source || /^data:/i.test(source)) return '';
                try {
                  const url = new URL(source, location.href);
                  return url.protocol === 'https:' && !url.username && !url.password
                    ? url.href : '';
                } catch (_) {
                  return '';
                }
              };
              const teamLogo = (teamName, fallbackIndex) => {
                if (!teamName) return '';
                const wanted = normalizeLabel(teamName);
                const labelled = imageNodes.find((image) => {
                  const label = normalizeLabel([
                    image.alt, image.title, image.getAttribute('aria-label'),
                    image.getAttribute('data-team'), image.getAttribute('data-name')
                  ].filter(Boolean).join(' '));
                  return label && (label.includes(wanted) || wanted.includes(label));
                });
                return resolveImage(labelled || imageNodes[fallbackIndex]);
              };
              const homeTeamLogo = teamLogo(homeTeam, 0);
              const awayTeamLogo = teamLogo(awayTeam, 1);
              const venueNode = node.querySelector(
                '[class*="venue"],[class*="stadium"],[data-venue]'
              );
              const venue = (venueNode && venueNode.textContent || '')
                .replace(/\\s+/g, ' ').trim();
              const participants = pair.length > 1 ? [
                { name: homeTeam, imageUrl: homeTeamLogo, country: '', role: 'home' },
                { name: awayTeam, imageUrl: awayTeamLogo, country: '', role: 'away' }
              ] : [];
              found.push({
                id: String(eventId),
                title: title,
                sport: sport,
                competition: competition,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                homeTeamLogo: homeTeamLogo,
                awayTeamLogo: awayTeamLogo,
                participants: participants,
                imageUrl: pair.length > 1 ? '' : resolveImage(imageNodes[0]),
                venue: venue,
                startsAt: iso,
                endsAt: endIso,
                detailUrl: eventUrl
              });
            }
            if (window.flutter_inappwebview) {
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
                              'Agenda: solo datos deportivos. No se reproducen vídeos incrustados; la APK busca las señales por separado en listas M3U y guías EPG.',
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
                                .map(SportsAgendaEvent.fromJson)
                                .whereType<SportsAgendaEvent>()
                                .toList(growable: false);
                            await SportsAgendaStore.save(events);
                            return events.length;
                          },
                        );
                      },
                      onLoadStart: (controller, url) {
                        _loadTimeoutTimer?.cancel();
                        _loadTimeoutTimer = Timer(const Duration(seconds: 25), () {
                          if (!mounted || !_loading) return;
                          setState(() {
                            _loading = false;
                            _errorMessage = 'MARCA está tardando demasiado en responder. Comprueba tu conexión y pulsa Recargar.';
                          });
                        });
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
                        _loadTimeoutTimer?.cancel();
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
                        _loadTimeoutTimer?.cancel();
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
                          _loadTimeoutTimer?.cancel();
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
              'La programación de MARCA es un servicio externo; sus reproductores no se utilizan. '
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