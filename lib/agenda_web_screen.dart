import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String agendaWebSourceUrl = 'https://futbol-libre.cam/';

/// Formatea la fecha local del teléfono sin depender de una zona horaria fija.
String formatAgendaDate(DateTime date) {
  const weekdays = <String>[
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];
  const months = <String>[
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} de '
      '${months[date.month - 1]} de ${date.year}';
}

class AgendaBrandBanner extends StatelessWidget {
  const AgendaBrandBanner({
    super.key,
    required this.date,
    required this.onRefresh,
  });

  final DateTime date;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('agenda-brand-banner'),
      margin: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      padding: const EdgeInsets.fromLTRB(11, 10, 6, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF071B31), Color(0xFF0B1019), Color(0xFF250B12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00A3FF), width: 1.1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF00A3FF).withAlpha(45),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 43,
              height: 43,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 43,
                height: 43,
                child: Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'DEPORTE TOTAL 360°',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'AGENDA DEPORTIVA DEL DÍA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF00A3FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatAgendaDate(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEAF0F8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar agenda',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF39FF14), size: 23),
          ),
        ],
      ),
    );
  }
}

class AgendaWebScreen extends StatefulWidget {
  const AgendaWebScreen({super.key});

  @override
  State<AgendaWebScreen> createState() => _AgendaWebScreenState();
}

class _AgendaWebScreenState extends State<AgendaWebScreen> {
  InAppWebViewController? _controller;
  Timer? _dateTimer;
  DateTime _displayDate = DateTime.now();
  bool _isLoading = true;
  int _progress = 0;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _dateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      if (!_sameDay(now, _displayDate) && mounted) {
        setState(() => _displayDate = now);
      }
    });
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    super.dispose();
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month &&
      first.day == second.day;

  bool _isAllowedHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'futbol-libre.cam' ||
        normalized.endsWith('.futbol-libre.cam');
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _progress = 0;
      _pageError = null;
    });
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _pageError = 'No se pudo recargar la agenda. Comprueba tu conexión.';
      });
      debugPrint('Error al recargar la agenda: $error');
    }
  }

  Future<void> _applyAgendaOnlyView(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: _agendaOnlyScript);
      await controller.evaluateJavascript(source: _agendaInlinePlayerScript);
    } catch (error) {
      debugPrint('No se pudo aplicar el filtro o leer los eventos de Agenda: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AgendaBrandBanner(date: _displayDate, onRefresh: _reload),
            if (_isLoading)
              LinearProgressIndicator(
                minHeight: 2,
                value: _progress > 0 ? _progress / 100 : null,
                backgroundColor: const Color(0xFF101722),
                color: const Color(0xFF39FF14),
              ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  InAppWebView(
                    key: const ValueKey<String>('agenda-webview'),
                    initialUrlRequest: URLRequest(url: WebUri(agendaWebSourceUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      useShouldOverrideUrlLoading: true,
                      javaScriptCanOpenWindowsAutomatically: false,
                      supportZoom: false,
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                    onLoadStart: (controller, url) {
                      if (!mounted) return;
                      setState(() {
                        _isLoading = true;
                        _progress = 0;
                        _pageError = null;
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      if (mounted) setState(() => _progress = progress);
                    },
                    onLoadStop: (controller, url) async {
                      await _applyAgendaOnlyView(controller);
                      if (!mounted) return;
                      setState(() {
                        _isLoading = false;
                        _progress = 100;
                        _pageError = null;
                      });
                    },
                    shouldOverrideUrlLoading: (controller, action) async {
                      final target = action.request.url;
                      if (target == null) return NavigationActionPolicy.CANCEL;
                      if (target.scheme == 'about') return NavigationActionPolicy.ALLOW;
                      // El reproductor original se carga como subframe dentro
                      // de la tarjeta; la navegación principal sigue limitada
                      // al dominio de la Agenda.
                      if (action.isForMainFrame == false) {
                        return NavigationActionPolicy.ALLOW;
                      }
                      return _isAllowedHost(target.host)
                          ? NavigationActionPolicy.ALLOW
                          : NavigationActionPolicy.CANCEL;
                    },
                    onReceivedError: (controller, request, error) {
                      if (request.isForMainFrame == false || !mounted) return;
                      setState(() {
                        _isLoading = false;
                        _pageError =
                            'No se pudo cargar la agenda. Comprueba tu conexión y vuelve a intentarlo.';
                      });
                    },
                  ),
                  if (_pageError != null)
                    Positioned.fill(
                      child: ColoredBox(
                        color: const Color(0xE9000000),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.cloud_off_rounded, color: Color(0xFFFF1744), size: 42),
                                const SizedBox(height: 12),
                                Text(
                                  _pageError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, height: 1.4),
                                ),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  onPressed: _reload,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('RECARGAR AGENDA'),
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

const String _agendaOnlyScript = r'''
(function () {
  if (window.__dt360AgendaObserver) {
    if (window.__dt360ApplyAgendaFilter) window.__dt360ApplyAgendaFilter();
    return;
  }

  const normalize = (value) => String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();

  const excludedHeadings = [
    'canales y transmisiones',
    'como usar la agenda',
    'canales y disponibilidad',
    'consulta desde el movil',
    'preguntas frecuentes'
  ];

  function hideHeadingBlock(heading) {
    const block = heading.closest('section, article');
    if (block) {
      const containsAgendaHeading = Array.from(
        block.querySelectorAll('h1, h2, h3, h4')
      ).some((candidate) =>
        normalize(candidate.textContent).includes('programacion del dia'));
      if (!containsAgendaHeading) {
        block.style.setProperty('display', 'none', 'important');
      } else {
        heading.style.setProperty('display', 'none', 'important');
      }
      return;
    }
    let candidate = heading;
    let parent = heading.parentElement;
    while (parent && parent !== document.body && parent !== document.documentElement) {
      if (parent.querySelectorAll('h1, h2').length > 1) break;
      candidate = parent;
      parent = parent.parentElement;
    }
    if (candidate !== document.body && candidate !== document.documentElement) {
      candidate.style.setProperty('display', 'none', 'important');
    }
  }

  function applyAgendaFilter() {
    const styleId = 'dt360-agenda-only-style';
    if (!document.getElementById(styleId)) {
      const style = document.createElement('style');
      style.id = styleId;
      style.textContent = [
        'html, body { background:#05070b !important; margin:0 !important; width:100% !important; }',
        'body { overflow-x:hidden !important; }',
        'header, nav, footer, [role="navigation"], .site-header, .site-footer, .navbar, .topbar, .hero, .hero-section { display:none !important; }',
        'main { margin:0 !important; padding:6px 8px 18px !important; max-width:100% !important; }',
        'a[href*="discord"], a[href*="#canales"], a[href*="#preguntas"] { display:none !important; }'
      ].join('\n');
      (document.head || document.documentElement).appendChild(style);
    }

    document.querySelectorAll('h1, h2, h3, h4').forEach((heading) => {
      const label = normalize(heading.textContent);
      if (excludedHeadings.some((part) => label.includes(part))) hideHeadingBlock(heading);
      if (heading.tagName === 'H1' && !label.includes('programacion del dia')) {
        heading.style.setProperty('display', 'none', 'important');
      }
    });

    // Oculta también las tarjetas de canal, incluso si la web no las agrupa
    // dentro de un <section> semántico.
    const channelActions = Array.from(
      document.querySelectorAll('a, button, [role="button"]')
    ).filter((element) =>
      normalize(element.textContent).startsWith('abrir canal')
    );

    if (channelActions.length > 1) {
      let channelContainer = channelActions[0];
      while (channelContainer.parentElement &&
          channelContainer.parentElement !== document.body &&
          channelContainer.parentElement !== document.documentElement &&
          !channelActions.every((action) => channelContainer.contains(action))) {
        channelContainer = channelContainer.parentElement;
      }

      const hasAgenda = Array.from(
        channelContainer.querySelectorAll('h1, h2, h3, h4')
      ).some((heading) =>
        normalize(heading.textContent).includes('programacion del dia'));

      if (channelContainer !== document.body &&
          channelContainer !== document.documentElement && !hasAgenda) {
        channelContainer.style.setProperty('display', 'none', 'important');
      } else {
        // Si la web comparte el contenedor, oculta cada tarjeta individual.
        channelActions.forEach((action) => {
          let card = action;
          for (let depth = 0; depth < 8; depth += 1) {
            const parent = card.parentElement;
            if (!parent || parent === document.body ||
                parent === document.documentElement || parent === channelContainer) break;
            card = parent;
            const actionCount = Array.from(
              card.querySelectorAll('a, button, [role="button"]')
            ).filter((element) =>
              normalize(element.textContent).startsWith('abrir canal')
            ).length;
            const hasChannelTitle = card.querySelector('h3, h4, img, picture');
            if (actionCount === 1 && hasChannelTitle) break;
          }
          card.style.setProperty('display', 'none', 'important');
        });
      }
    }

    document.querySelectorAll('a').forEach((link) => {
      const label = normalize(link.textContent);
      const href = String(link.getAttribute('href') || '').toLowerCase();
      if (label === 'futbol libre' || href.includes('discord') ||
          href.includes('#canales') || href.includes('#preguntas')) {
        link.style.setProperty('display', 'none', 'important');
      }
    });

  }

  window.__dt360ApplyAgendaFilter = applyAgendaFilter;
  applyAgendaFilter();
  const observer = new MutationObserver(() => {
    if (window.__dt360AgendaFilterQueued) return;
    window.__dt360AgendaFilterQueued = true;
    window.requestAnimationFrame(() => {
      window.__dt360AgendaFilterQueued = false;
      applyAgendaFilter();
    });
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
  window.__dt360AgendaObserver = observer;
})();
''';


const String _agendaInlinePlayerScript = r'''
(function () {
  if (window.__dt360InlinePlayersInstalled) {
    if (window.__dt360RefreshInlinePlayers) window.__dt360RefreshInlinePlayers();
    return;
  }

  const normalize = (value) => String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
  const timePattern = /\b([01]?\d|2[0-3]):([0-5]\d)\b/;
  const timeGlobalPattern = /\b(?:[01]?\d|2[0-3]):[0-5]\d\b/g;

  function visibleText(element) {
    return String(element && (element.innerText || element.textContent) || '')
      .replace(/\u00a0/g, ' ')
      .replace(/[\t ]+/g, ' ')
      .trim();
  }

  function rawText(element) {
    return String(element && element.textContent || '')
      .replace(/\u00a0/g, ' ')
      .replace(/[\t ]+/g, ' ')
      .trim();
  }

  function findEventCard(node) {
    let current = node && (node.nodeType === 1 ? node : node.parentElement);
    let best = null;
    for (let depth = 0; depth < 10 && current &&
        current !== document.body && current !== document.documentElement; depth += 1) {
      const value = visibleText(current);
      const times = (value.match(timeGlobalPattern) || []).length;
      if (value.length > 1100 || times > 2) break;
      if (value.length >= 12 && times >= 1 && times <= 2) best = current;
      const className = String(current.className || '').toLowerCase();
      const looksLikeEvent = current.hasAttribute('data-event-id') ||
        /event|match|fixture|partido|encuentro/.test(className);
      if (looksLikeEvent && value.length >= 12 && times >= 1 && times <= 2) {
        return current;
      }
      current = current.parentElement;
    }
    return best;
  }

  function safePlayerPage(raw) {
    if (!raw) return '';
    let url;
    try {
      url = new URL(String(raw), location.href);
    } catch (_) {
      return '';
    }
    if (url.protocol !== 'https:' || url.username || url.password) return '';
    const host = url.hostname.toLowerCase();
    const agendaHost = host === 'futbol-libre.cam' || host.endsWith('.futbol-libre.cam');
    const playerHost = host === 'tvf90.com' || host.endsWith('.tvf90.com');
    if (!agendaHost && !playerHost) return '';
    if (agendaHost &&
        !/^\/(?:canal|player|play|reproducir|transmision|partido|evento|match|event)\//i.test(url.pathname)) {
      return '';
    }
    if (/\.(?:m3u8|mpd|mp4|m4v|mov|mkv|webm|ts|mpeg|mpg)$/i.test(url.pathname)) {
      return '';
    }
    return url.href;
  }

  function playerTargetForCard(card) {
    const nodes = Array.from(card.querySelectorAll(
      'iframe[src], a[href], [data-player-url], [data-play-url], ' +
      '[data-stream-url], [data-channel-url], [data-href], [data-url]'
    ));
    const candidates = [];
    nodes.forEach((element) => {
      const raw = element.getAttribute('src') ||
        element.getAttribute('data-player-url') ||
        element.getAttribute('data-play-url') ||
        element.getAttribute('data-stream-url') ||
        element.getAttribute('data-channel-url') ||
        element.getAttribute('data-href') ||
        element.getAttribute('data-url') ||
        element.getAttribute('href') || '';
      const url = safePlayerPage(raw);
      if (!url) return;
      const parsed = new URL(url);
      const label = normalize(rawText(element));
      const host = parsed.hostname.toLowerCase();
      const isAgendaHost = host === 'futbol-libre.cam' || host.endsWith('.futbol-libre.cam');
      let score = 0;
      if (host === 'tvf90.com' || host.endsWith('.tvf90.com')) score += 120;
      if (parsed.searchParams.has('stream')) score += 35;
      if (/\.(?:php|html?)$/i.test(parsed.pathname)) score += 15;
      if (/abrir canal|ver canal|ver señal|ver senal|abrir partido|ver partido|reproducir|transmision|en vivo/.test(label)) {
        score += 25;
      }
      if (isAgendaHost && /\/(?:partido|evento|match|event)\//i.test(parsed.pathname)) {
        // La ficha de partido de la propia Agenda contiene el reproductor
        // original y prevalece sobre enlaces genéricos de canal.
        score += 200;
      }
      if (element.tagName === 'IFRAME') score += 30;
      if (isAgendaHost && /\/canal\//i.test(parsed.pathname)) score += 70;
      candidates.push({url: url, score: score});
    });
    candidates.sort((a, b) => b.score - a.score);
    return candidates.length ? candidates[0].url : '';
  }

  function setPanelStatus(panel, message) {
    const status = panel.querySelector('.dt360-player-status');
    if (status) status.textContent = message;
  }

  function loadPlayer(panel, url) {
    const safeUrl = safePlayerPage(url);
    if (!safeUrl) {
      setPanelStatus(panel, 'El destino del reproductor no es una página HTTPS admitida.');
      return;
    }

    document.querySelectorAll('.dt360-inline-player iframe').forEach((frame) => {
      frame.remove();
    });
    document.querySelectorAll('.dt360-inline-player').forEach((other) => {
      if (other !== panel) {
        const otherButton = other.querySelector('.dt360-player-button');
        if (otherButton) otherButton.textContent = 'REPRODUCIR';
        setPanelStatus(other, 'Toca REPRODUCIR para abrir la señal de este evento.');
      }
    });

    const holder = panel.querySelector('.dt360-player-frame-holder');
    if (!holder) return;
    holder.replaceChildren();

    const frame = document.createElement('iframe');
    frame.className = 'dt360-inline-frame';
    frame.src = safeUrl;
    frame.title = 'Reproductor del evento';
    frame.loading = 'lazy';
    frame.allow = 'autoplay; encrypted-media; fullscreen; picture-in-picture';
    frame.setAttribute('allowfullscreen', '');
    frame.referrerPolicy = 'strict-origin-when-cross-origin';
    frame.style.cssText =
      'display:block;width:100%;height:230px;border:0;border-radius:8px;background:#000;';
    frame.addEventListener('load', () => {
      setPanelStatus(panel, 'Página del reproductor cargada. Pulsa PLAY dentro de la señal.');
    });
    frame.addEventListener('error', () => {
      setPanelStatus(panel, 'No se pudo cargar la página del reproductor.');
    });
    holder.appendChild(frame);

    const button = panel.querySelector('.dt360-player-button');
    if (button) button.textContent = 'RECARGAR';
    setPanelStatus(
      panel,
      'Abriendo el reproductor original del evento. Si el proveedor bloquea la inserción, puede que no aparezca aquí.'
    );
  }

  function ensurePlayerPanel(card, url, title) {
    if (!card || !card.parentElement) return null;
    let panel = card.nextElementSibling;
    if (!panel || !panel.classList.contains('dt360-inline-player')) {
      panel = document.createElement('section');
      panel.className = 'dt360-inline-player';
      panel.style.cssText =
        'box-sizing:border-box;margin:8px 0 14px;padding:10px;background:#0b1724;' +
        'border:1px solid #16415b;border-radius:10px;color:#eaf3ff;';
      const heading = document.createElement('div');
      heading.className = 'dt360-player-heading';
      heading.textContent = 'REPRODUCTOR DEL EVENTO';
      heading.style.cssText =
        'margin:0 0 8px;color:#00a3ff;font-size:12px;font-weight:900;letter-spacing:.5px;';
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'dt360-player-button';
      button.textContent = 'REPRODUCIR';
      button.style.cssText =
        'display:block;width:100%;min-height:42px;padding:9px 12px;border:1px solid #1d9d69;' +
        'border-radius:8px;background:#073a27;color:#39ff85;font-size:13px;font-weight:900;';
      const status = document.createElement('div');
      status.className = 'dt360-player-status';
      status.textContent = 'Toca REPRODUCIR para abrir la señal de este evento.';
      status.style.cssText =
        'margin-top:7px;color:#b8c5d8;font-size:11px;line-height:1.4;';
      const holder = document.createElement('div');
      holder.className = 'dt360-player-frame-holder';
      holder.style.cssText = 'margin-top:8px;width:100%;';
      panel.appendChild(heading);
      panel.appendChild(button);
      panel.appendChild(status);
      panel.appendChild(holder);
      button.addEventListener('click', () => loadPlayer(panel, panel.dataset.playerUrl || ''));
      card.insertAdjacentElement('afterend', panel);
    }

    if (panel.dataset.playerUrl !== url) panel.dataset.playerUrl = url;
    const eventTitle = title || 'Evento';
    if (panel.dataset.eventTitle !== eventTitle) {
      panel.dataset.eventTitle = eventTitle;
    }
    const heading = panel.querySelector('.dt360-player-heading');
    const headingText = 'REPRODUCTOR · ' + (title || 'EVENTO');
    if (heading && heading.textContent !== headingText) {
      heading.textContent = headingText;
    }
    const button = panel.querySelector('.dt360-player-button');
    const frame = panel.querySelector('iframe');
    if (button) button.disabled = !url;
    if (!url) {
      if (frame) frame.remove();
      if (button) button.textContent = 'SIN REPRODUCTOR';
      setPanelStatus(
        panel,
        'La Agenda todavía no ha publicado un destino de reproducción para este evento.'
      );
    } else if (frame && frame.src !== url) {
      frame.remove();
      if (button) button.textContent = 'REPRODUCIR';
      setPanelStatus(panel, 'Toca REPRODUCIR para abrir la señal actualizada.');
    } else if (!frame && button) {
      button.textContent = 'REPRODUCIR';
      setPanelStatus(panel, 'Se ha seleccionado una sola reproducción original para este evento.');
    }
    return panel;
  }

  function refreshInlinePlayers() {
    const timeNodes = Array.from(document.querySelectorAll(
      'time, [data-time], [class*="time"], span, strong, small, div'
    )).filter((element) =>
      element.children.length === 0 && timePattern.test(visibleText(element))
    );
    const seenCards = new Set();
    timeNodes.forEach((node) => {
      const card = findEventCard(node);
      if (!card || seenCards.has(card)) return;
      seenCards.add(card);
      const titleNode = card.querySelector(
        '[data-event-title], [class*="event-title"], [class*="match-title"], h2, h3, h4, strong'
      );
      const title = visibleText(titleNode) ||
        visibleText(card).replace(timeGlobalPattern, '').trim().slice(0, 100);
      // Se reserva un cuadro para cada evento; cuando la ficha publica
      // una sola opción válida, se conecta al reproductor original.
      const url = playerTargetForCard(card);
      ensurePlayerPanel(card, url, title);
    });
  }

  document.addEventListener('click', (event) => {
    const target = event.target && event.target.closest
      ? event.target.closest('a[href]')
      : null;
    if (!target) return;
    const url = safePlayerPage(target.href);
    if (!url) return;
    const card = findEventCard(target);
    if (!card) return;
    event.preventDefault();
    event.stopPropagation();
    const titleNode = card.querySelector(
      '[data-event-title], [class*="event-title"], [class*="match-title"], h2, h3, h4, strong'
    );
    const title = visibleText(titleNode) ||
      visibleText(card).replace(timeGlobalPattern, '').trim().slice(0, 100);
    const panel = ensurePlayerPanel(card, url, title);
    if (panel) loadPlayer(panel, url);
  }, true);

  let queued = false;
  function queueRefresh() {
    if (queued) return;
    queued = true;
    window.setTimeout(() => {
      queued = false;
      refreshInlinePlayers();
    }, 300);
  }

  const observer = new MutationObserver(queueRefresh);
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
    characterData: true,
    attributes: true,
    attributeFilter: ['href', 'src', 'data-player-url', 'data-play-url', 'data-channel-url']
  });

  window.__dt360RefreshInlinePlayers = refreshInlinePlayers;
  window.__dt360InlinePlayerObserver = observer;
  window.__dt360InlinePlayersInstalled = true;
  refreshInlinePlayers();
  window.setInterval(refreshInlinePlayers, 10000);
})();
''';
