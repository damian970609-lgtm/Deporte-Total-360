import 'dart:async';

import 'agenda_live_service.dart';

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
      await controller.evaluateJavascript(source: _agendaLiveCaptureScript);
      await controller.evaluateJavascript(source: _agendaOnlyScript);
    } catch (error) {
      debugPrint('No se pudo aplicar el filtro o leer los eventos de Agenda: $error');
    }
  }

  Future<void> _storeCapturedAgendaEvents(dynamic payload) async {
    try {
      await AgendaLiveService().captureAgendaEvents(payload);
    } catch (error) {
      debugPrint('No se pudieron guardar las referencias de canales de Agenda: $error');
    }
  }

  Future<void> _storeCapturedAgendaChannels(dynamic payload) async {
    try {
      await AgendaLiveService().captureAgendaChannels(payload);
    } catch (error) {
      debugPrint('No se pudieron guardar los canales publicados en Agenda: $error');
    }
  }

  void _registerAgendaBridge(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'dt360AgendaEvents',
      callback: (arguments) {
        if (arguments.isNotEmpty) {
          unawaited(_storeCapturedAgendaEvents(arguments.first));
        }
        return true;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'dt360AgendaChannels',
      callback: (arguments) {
        if (arguments.isNotEmpty) {
          unawaited(_storeCapturedAgendaChannels(arguments.first));
        }
        return true;
      },
    );
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
                      _registerAgendaBridge(controller);
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
        'a[href*="discord"], a[href*="#canales"], a[href*="#preguntas"] { display:none !important; }',
        '[data-dt360-event-card="true"] { background:linear-gradient(135deg,#111c2b,#080b11) !important; border:1px solid rgba(0,163,255,.42) !important; border-radius:14px !important; padding:10px !important; margin:8px 0 !important; box-shadow:0 5px 16px rgba(0,0,0,.34) !important; }',
        '[data-dt360-event-card="true"] time, [data-dt360-event-card="true"] [class*="time"] { color:#39ff14 !important; font-weight:900 !important; }',
        '[data-dt360-event-card="true"] a { border-radius:8px !important; }'
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

    document.querySelectorAll('a').forEach((link) => {
      const label = normalize(link.textContent);
      const href = String(link.getAttribute('href') || '').toLowerCase();
      if (label === 'futbol libre' || href.includes('discord') ||
          href.includes('#canales') || href.includes('#preguntas')) {
        link.style.setProperty('display', 'none', 'important');
      }
    });

    // Marca las fichas de la fecha local actual y oculta las que indiquen
    // explícitamente otra fecha. La agenda no inventa una fecha si el sitio
    // solo publica la hora dentro de la programación del día.
    const now = new Date();
    const todayKey = [now.getFullYear(), String(now.getMonth() + 1).padStart(2, '0'), String(now.getDate()).padStart(2, '0')].join('-');
    function localDateKey(date) {
      return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, '0'), String(date.getDate()).padStart(2, '0')].join('-');
    }
    function dateKeyFromValue(value) {
      const raw = String(value || '').trim();
      if (!raw || /^\d{1,2}:\d{2}$/.test(raw)) return null;
      const parsed = new Date(raw);
      if (!Number.isNaN(parsed.getTime())) return localDateKey(parsed);
      const match = raw.match(/\b(\d{1,2})[\/. -](\d{1,2})(?:[\/. -](\d{2,4}))?\b/);
      if (!match) return null;
      const year = match[3] ? Number(match[3].length === 2 ? '20' + match[3] : match[3]) : now.getFullYear();
      return [String(year).padStart(4, '0'), String(Number(match[2])).padStart(2, '0'), String(Number(match[1])).padStart(2, '0')].join('-');
    }
    function eventCardFor(node) {
      let current = node && node.parentElement;
      let best = current;
      for (let depth = 0; depth < 9 && current && current !== document.body && current !== document.documentElement; depth += 1) {
        const value = String(current.innerText || current.textContent || '');
        const clocks = (value.match(/\b(?:[01]?\d|2[0-3]):[0-5]\d\b/g) || []).length;
        if (value.length > 950 || clocks > 2) break;
        if (value.trim().length >= 18 && clocks >= 1) best = current;
        const className = String(current.className || '').toLowerCase();
        if (/event|match|fixture|partido|encuentro/.test(className) && clocks >= 1) return current;
        current = current.parentElement;
      }
      return best;
    }
    const timeNodes = document.querySelectorAll('time[datetime], [data-start], [data-start-time], [data-time], time');
    timeNodes.forEach((node) => {
      const card = eventCardFor(node);
      if (!card) return;
      card.setAttribute('data-dt360-event-card', 'true');
      const rawDate = node.getAttribute('datetime') || node.getAttribute('data-start') || node.getAttribute('data-start-time') || node.getAttribute('data-time') || '';
      const cardText = String(card.innerText || card.textContent || '');
      const dateKey = dateKeyFromValue(rawDate) || dateKeyFromValue(cardText);
      if (dateKey && dateKey !== todayKey) {
        card.style.setProperty('display', 'none', 'important');
      }
    });

    // Quita las tarjetas independientes de canales de debajo de la agenda.
    // Las fichas que contienen una hora de evento se conservan.
    const channelAction = /(abrir canal|ver canal|reproducir canal|watch channel|open channel)/i;
    document.querySelectorAll('a[href], button[data-href], button[data-url], [role="link"][href], [role="button"][data-href], [role="button"][data-url]').forEach((element) => {
      const label = visibleLabel(element);
      if (!channelAction.test(label)) return;
      let candidate = element;
      let target = element;
      for (let depth = 0; depth < 8 && candidate && candidate !== document.body; depth += 1) {
        const value = normalize(candidate.innerText || candidate.textContent || '');
        const clocks = (value.match(/\b(?:[01]?\d|2[0-3]):[0-5]\d\b/g) || []).length;
        if (clocks > 0 || /\b(?:vs?\.?|versus)\b/i.test(value)) {
          target = element;
          break;
        }
        if (value.length >= 3 && value.length <= 900) target = candidate;
        const className = String(candidate.className || '').toLowerCase();
        if (candidate.matches('article, li, section') || /card|channel|station/.test(className)) break;
        candidate = candidate.parentElement;
      }
      target.style.setProperty('display', 'none', 'important');
    });

    function visibleLabel(element) {
      return normalize(element.innerText || element.textContent ||
        element.getAttribute('aria-label') || element.getAttribute('title') || '');
    }

    // Tocar una ficha de evento en Agenda no navega ni expande nada.
    if (!window.__dt360AgendaEventTapDisabled) {
      document.addEventListener('click', (clickEvent) => {
        let candidate = clickEvent.target;
        for (let depth = 0; depth < 9 && candidate && candidate !== document.body; depth += 1) {
          const value = normalize(candidate.innerText || candidate.textContent || '');
          const clocks = (value.match(/\b(?:[01]?\d|2[0-3]):[0-5]\d\b/g) || []).length;
          if (clocks > 0 && clocks <= 2 && value.length >= 18 && value.length <= 950) {
            clickEvent.preventDefault();
            clickEvent.stopPropagation();
            if (clickEvent.stopImmediatePropagation) clickEvent.stopImmediatePropagation();
            return;
          }
          if (clocks > 2 || value.length > 950) return;
          candidate = candidate.parentElement;
        }
      }, true);
      window.__dt360AgendaEventTapDisabled = true;
    }
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


const String _agendaLiveCaptureScript = r'''
(function () {
  if (window.__dt360AgendaCaptureInstalled) {
    if (window.__dt360EmitAgendaEvents) window.__dt360EmitAgendaEvents();
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
  const referencePattern = /(?:fuente|canal|señal|senal|opción|opcion)\s*\d+\s*[:\-]?\s*(.*?)(?=(?:fuente|canal|señal|senal|opción|opcion)\s*\d+|[\n|•]|$)/gi;

  function visibleText(element) {
    return String(element && (element.innerText || element.textContent) || '')
      .replace(/\u00a0/g, ' ')
      .replace(/[\t ]+/g, ' ')
      .trim();
  }

  function cleanReference(value) {
    return String(value || '')
      .replace(/\b(?:abrir partido|abrir canal|ver partido|reproducir)\b/gi, '')
      .replace(/\b(?:español|espanol|english|inglés|ingles|portugués|portugues|brasil|latino)\b/gi, '')
      .replace(/[·•|].*$/, '')
      .replace(/^\s*(?:fuente|canal|señal|senal|opción|opcion)\s*\d+\s*[:\-]?/i, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function findEventCard(timeNode) {
    let current = timeNode && timeNode.parentElement;
    let best = current;
    for (let depth = 0; depth < 9 && current &&
        current !== document.body && current !== document.documentElement; depth += 1) {
      const value = visibleText(current);
      const times = (value.match(timeGlobalPattern) || []).length;
      if (value.length > 950 || times > 2) break;
      if (value.length >= 18 && times >= 1) best = current;
      const className = String(current.className || '').toLowerCase();
      const looksLikeEvent = current.hasAttribute('data-event-id') ||
        /event|match|fixture|partido|encuentro/.test(className);
      if (looksLikeEvent && value.length >= 18 && times >= 1) return current;
      current = current.parentElement;
    }
    return best;
  }

  function readStartAt(card, text) {
    const timeElement = card.querySelector('time[datetime], [data-start], [data-start-time], [data-time]');
    const explicit = timeElement
      ? (timeElement.getAttribute('datetime') || timeElement.getAttribute('data-start') ||
         timeElement.getAttribute('data-start-time') || timeElement.getAttribute('data-time') || '')
      : '';
    if (explicit) {
      const parsed = new Date(explicit);
      if (!Number.isNaN(parsed.getTime())) {
        const local = new Date(parsed.getTime() - parsed.getTimezoneOffset() * 60000);
        return local.toISOString().slice(0, 19);
      }
    }
    const match = text.match(timePattern);
    if (!match) return '';
    const now = new Date();
    const hour = Number(match[1]);
    const minute = Number(match[2]);
    const start = new Date(
      now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0, 0
    );
    const pad = (number) => String(number).padStart(2, '0');
    return String(start.getFullYear()).padStart(4, '0') + '-' +
      pad(start.getMonth() + 1) + '-' + pad(start.getDate()) + 'T' +
      pad(hour) + ':' + pad(minute) + ':00';
  }

  function readEndAt(card) {
    const element = card.querySelector('[data-end], [data-end-time], time[aria-label*="fin"]');
    if (!element) return '';
    const value = element.getAttribute('datetime') ||
      element.getAttribute('data-end') || element.getAttribute('data-end-time') || '';
    if (!value) return '';
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return '';
    const local = new Date(parsed.getTime() - parsed.getTimezoneOffset() * 60000);
    return local.toISOString().slice(0, 19);
  }

  function readChannelReferences(card, cardText) {
    const found = [];
    const generic = new Set([
      'abrir', 'canal', 'senal', 'fuente', 'ver partido',
      'programacion deportiva', 'mas informacion', 'disponible',
      'canales de referencia', 'senales disponibles', 'fuentes disponibles'
    ]);
    const add = (raw) => {
      const clean = cleanReference(raw);
      if (clean.length < 2 || clean.length > 70) return;
      const key = normalize(clean);
      if (!key || generic.has(key) ||
          found.some((item) => normalize(item) === key)) return;
      found.push(clean);
    };
    const addDelimited = (raw) => {
      String(raw || '').split(/[,;\n•|]+/).forEach((item) => add(item));
    };

    // Formato habitual: "Fuente 1: ESPN 2", "Canal 2: DSports".
    let marker;
    while ((marker = referencePattern.exec(cardText)) !== null) add(marker[1]);
    referencePattern.lastIndex = 0;

    // Algunas fichas publican los nombres agrupados en una línea/lista,
    // sin numerar cada fuente. Captura solo el valor posterior al encabezado.
    const sectionPatterns = [
      /(?:canales?|señales|fuentes)\s+(?:de\s+)?(?:referencia|disponibles|publicadas|recomendadas|posibles)\s*:?\s*([^\n]{2,180})/gi,
      /(?:transmisiones?|señales)\s+(?:posibles|disponibles)\s*:?\s*([^\n]{2,180})/gi
    ];
    sectionPatterns.forEach((pattern) => {
      let section;
      while ((section = pattern.exec(cardText)) !== null) {
        addDelimited(section[1]);
      }
      pattern.lastIndex = 0;
    });

    const referenceNodes = card.querySelectorAll(
      '[data-channel], [data-channel-name], [data-source], [data-signal], ' +
      '[class*="channel"], [class*="source"], [class*="signal"], [class*="stream"], ' +
      '[class*="broadcast"], [class*="transmission"]'
    );
    referenceNodes.forEach((element) => {
      add(element.getAttribute('data-channel'));
      add(element.getAttribute('data-channel-name'));
      add(element.getAttribute('data-source'));
      add(element.getAttribute('data-signal'));
      add(element.getAttribute('aria-label'));
      add(element.getAttribute('title'));
      add(element.getAttribute('alt'));
      const value = visibleText(element);
      if (value.length <= 180) {
        let match;
        while ((match = referencePattern.exec(value)) !== null) add(match[1]);
        referencePattern.lastIndex = 0;
        sectionPatterns.forEach((pattern) => {
          let section;
          while ((section = pattern.exec(value)) !== null) {
            addDelimited(section[1]);
          }
          pattern.lastIndex = 0;
        });
        if (element.matches('a, button, [role="button"]') &&
            !/abrir partido|abrir canal|ver partido/i.test(value)) add(value);
      }
    });
    return found;
  }


  function readTransmissionOptions(root) {
    const found = [];
    const selector = 'a[href], button[data-href], button[data-url], ' +
      '[role="link"][href], [role="button"][data-href], [role="button"][data-url], ' +
      '[data-channel-url], [data-source-url], [data-stream-url], [data-player-url], ' +
      '[data-watch-url], [data-broadcast-url], [data-href], [data-url]';
    const elements = Array.from(root.querySelectorAll(selector));
    if (root.matches && root.matches(selector)) elements.unshift(root);
    elements.forEach((element, index) => {
      const label = visibleText(element) ||
        element.getAttribute('data-channel-name') ||
        element.getAttribute('data-source-name') ||
        element.getAttribute('data-name') ||
        element.getAttribute('aria-label') ||
        element.getAttribute('title') || ('Transmisión ' + (index + 1));
      const metadata = [
        label,
        element.className,
        element.getAttribute('aria-label'),
        element.getAttribute('title'),
        element.getAttribute('data-type'),
        element.getAttribute('data-role')
      ].join(' ').toLowerCase();

      const rawUrl = element.href ||
        element.getAttribute('data-channel-url') ||
        element.getAttribute('data-source-url') ||
        element.getAttribute('data-stream-url') ||
        element.getAttribute('data-player-url') ||
        element.getAttribute('data-watch-url') ||
        element.getAttribute('data-broadcast-url') ||
        element.getAttribute('data-href') ||
        element.getAttribute('data-url') || '';
      let url = '';
      try {
        url = new URL(rawUrl, document.baseURI).href;
      } catch (_) {
        return;
      }
      const channelMetadata = /(canal|fuente|señal|senal|opci[oó]n|transmisi[oó]n|stream|player|watch|ver directo|abrir canal|broadcast)/i.test(metadata);
      const channelUrl = /(?:canal|channel|fuente|source|senal|signal|stream|player|watch|broadcast|transmision|directo)/i.test(url);
      if (!channelMetadata && !channelUrl) return;
      if (!/^https:\/\//i.test(url)) return;
      const normalizedLabel = normalize(label);
      let parsedUrl;
      try { parsedUrl = new URL(url); } catch (_) { return; }
      const rootAgenda = parsedUrl.hostname.replace(/^www\./i, '') === 'futbol-libre.cam' &&
        (parsedUrl.pathname === '/' || parsedUrl.pathname === '');
      const agendaRoute = /\/(?:agenda|programacion|calendario)(?:\/|$)/i.test(parsedUrl.pathname);
      if (normalizedLabel.includes('agenda') || rootAgenda || agendaRoute) return;

      const popularityText = [
        element.getAttribute('data-popularity'),
        element.getAttribute('data-views'),
        element.getAttribute('data-votes'),
        element.getAttribute('data-rating')
      ].join(' ');
      const metricMatch = popularityText.match(/[0-9]+/);
      let popularityScore = metricMatch ? Number(metricMatch[0]) : 0;
      if (/(popular|destacad[oa]|recomendad[oa]|principal|m[aá]s visto|top)/i.test(metadata)) {
        popularityScore = Math.max(popularityScore, 1000000);
      }
      if (!label || label.length > 100) return;
      if (found.some((item) => item.url === url)) return;
      found.push({
        id: String(index) + '-' + url,
        name: label,
        url: url,
        order: index,
        popularityScore: popularityScore
      });
    });
    return found;
  }

  function readStandaloneChannels(root) {
    const found = [];
    const controls = Array.from(root.querySelectorAll(
      'a[href], button[data-href], button[data-url], [role="link"][href], [role="button"][data-href], [role="button"][data-url]'
    ));
    controls.forEach((element, index) => {
      const actionText = visibleText(element) ||
        element.getAttribute('aria-label') || element.getAttribute('title') || '';
      const metadata = [
        actionText, element.className,
        element.getAttribute('aria-label'), element.getAttribute('title')
      ].join(' ');
      if (!/(abrir canal|ver canal|reproducir canal|watch channel|open channel|channel|canal)/i.test(metadata)) return;

      const rawUrl = element.href ||
        element.getAttribute('data-href') ||
        element.getAttribute('data-url') || '';
      let url = '';
      try { url = new URL(rawUrl, document.baseURI).href; } catch (_) { return; }
      if (!/^https:\/\//i.test(url)) return;

      let card = element;
      let best = element;
      for (let depth = 0; depth < 8 && card && card !== document.body; depth += 1) {
        const value = visibleText(card);
        const clocks = (value.match(timeGlobalPattern) || []).length;
        if (clocks > 0 || /\b(?:vs?\.?|versus)\b/i.test(value)) return;
        if (value.length >= 2 && value.length <= 900) best = card;
        const className = String(card.className || '').toLowerCase();
        if (card.matches('article, li, section') || /card|channel|station/.test(className)) break;
        card = card.parentElement;
      }

      const titleNodes = Array.from(best.querySelectorAll(
        'h1, h2, h3, h4, [class*="title"], strong, b'
      ));
      const ignored = /^(canal|channel|abrir canal|ver canal|reproducir|play|watch|en vivo|live)$/i;
      const titleNode = titleNodes.find((node) => {
        const value = visibleText(node);
        return value.length >= 2 && value.length <= 70 && !ignored.test(value);
      });
      let name = titleNode ? visibleText(titleNode) : '';
      if (!name) {
        const lines = visibleText(best).split(/\n+/).map((line) => line.trim()).filter(Boolean);
        name = lines.find((line) => line.length >= 2 && line.length <= 70 &&
          !ignored.test(line) && !/(programación deportiva|grandes torneos|abrir canal|ver canal)/i.test(line)) || '';
      }
      if (!name) return;
      if (found.some((item) => item.url === url)) return;
      best.setAttribute('data-dt360-standalone-channel', 'true');
      found.push({
        id: 'channel-' + index + '-' + url,
        name: name,
        url: url,
        order: index,
        popularityScore: 0
      });
    });
    return found;
  }


  // Oculta las tarjetas independientes de canales una vez guardadas.
  // Las fichas de eventos nunca se marcan como canales independientes.
  function hideCapturedStandaloneChannelCards() {
    document.querySelectorAll('[data-dt360-standalone-channel="true"]').forEach((card) => {
      card.style.setProperty('display', 'none', 'important');
    });
  }

  // Oculta únicamente las opciones de transmisión de cada evento después de
  // guardar sus enlaces visibles. La agenda y sus fichas permanecen.
  function hideCapturedTransmissionOptions() {
    const selector = 'a[href], button[data-href], button[data-url], ' +
      '[role="link"][href], [role="button"][data-href], [role="button"][data-url]';
    const optionPattern =
      /(canal|fuente|señal|senal|opci[oó]n|transmisi[oó]n|stream|player|watch|ver directo|abrir canal)/i;
    document.querySelectorAll(selector).forEach((element) => {
      const metadata = [
        visibleText(element),
        element.className,
        element.getAttribute('aria-label'),
        element.getAttribute('title')
      ].join(' ');
      if (!optionPattern.test(metadata)) return;

      const container = element.closest(
        '[class*="channel"], [class*="source"], [class*="signal"], ' +
        '[class*="stream"], [class*="broadcast"], [class*="transmission"]'
      );
      const target = container || element;
      const targetClass = String(target.className || '').toLowerCase();
      const isEventCard = /event|match|fixture|partido|encuentro/.test(targetClass) ||
        !!target.querySelector('time[datetime], [data-time], [data-start-time]');
      const safeTarget = isEventCard ? element : target;
      safeTarget.style.setProperty('display', 'none', 'important');
    });
  }


  function readEvent(card) {
    const text = visibleText(card);
    const startAt = readStartAt(card, text);
    if (!startAt) return null;
    const lines = text.split(/\n+/).map((line) => line.trim()).filter(Boolean);
    const titleNode = card.querySelector(
      '[data-event-title], [class*="event-title"], [class*="match-title"], h2, h3, h4, strong'
    );
    const titleFromNode = visibleText(titleNode);
    const matchup = lines.find((line) =>
      /\b(?:vs?\.?|versus)\b/i.test(line)
    ) || '';
    card.setAttribute('data-dt360-event-card', 'true');
    const title = (matchup || titleFromNode ||
      lines.find((line) => line.length > 5 && !timePattern.test(line)) || '')
      .replace(timeGlobalPattern, '')
      .replace(/\s+/g, ' ')
      .trim();
    if (!title || title.length > 160) return null;

    const competition = lines.find((line) =>
      /liga|league|copa|cup|torneo|tournament|premier|champions|concacaf|conmebol|uefa|tenis|tennis|atp|wta|formula|motogp|futbol|football|soccer|baloncesto|basquet|basketball|nba|beisbol|baseball|mlb|hockey|nhl|rugby|voleibol|volleyball|cricket|golf|boxeo|boxing|mma|ufc|ciclismo|cycling/i.test(line) &&
      line !== title
    ) || '';
    const lower = normalize(text);
    let status = 'unknown';
    if (/\b(finalizado|finalizada|terminado|terminada|finished|completed|full time|cancelado|cancelada|suspended)\b/.test(lower)) {
      status = 'finished';
    } else if (/\b(en vivo|live|1st half|2nd half|primer tiempo|segundo tiempo|entretiempo|halftime)\b/.test(lower)) {
      status = 'live';
    } else if (/\b(proximo|proxima|scheduled|por comenzar)\b/.test(lower)) {
      status = 'scheduled';
    }

    const channelReferences = readChannelReferences(card, text);
    const elementId = card.getAttribute('data-event-id') ||
      card.getAttribute('data-id') || card.id || '';
    const id = elementId && elementId.length < 100
      ? elementId
      : normalize(title).replace(/[^a-z0-9]+/g, '-') + '_' + startAt;
    const eventLink = card.querySelector(
      'a[href*="partido"], a[href*="evento"], a[href*="match"], a[href*="event"]'
    );
    return {
      id: id,
      title: title,
      competition: competition,
      startsAt: startAt,
      endsAt: readEndAt(card),
      status: status,
      channelReferences: channelReferences,
      transmissionOptions: readTransmissionOptions(card),
      detailUrl: eventLink ? eventLink.href : location.href,
      updatedAt: new Date().toISOString()
    };
  }

  let lastSignature = '';
  let lastChannelSignature = '';
  let queued = false;
  function emitAgendaEvents() {
    queued = false;
    if (!window.flutter_inappwebview ||
        typeof window.flutter_inappwebview.callHandler !== 'function') return;
    const timeNodes = Array.from(document.querySelectorAll(
      'time, [data-time], [class*="time"], span, strong, small, div'
    )).filter((element) => element.children.length === 0 &&
      timePattern.test(visibleText(element)));
    const seenCards = new Set();
    const events = [];
    for (const node of timeNodes) {
      const card = findEventCard(node);
      if (!card || seenCards.has(card)) continue;
      seenCards.add(card);
      const event = readEvent(card);
      if (event) events.push(event);
    }
    const unique = [];
    const keys = new Set();
    for (const event of events) {
      const key = event.id + '|' + event.startsAt;
      if (keys.has(key)) continue;
      keys.add(key);
      unique.push(event);
    }

    const channels = readStandaloneChannels(document.body);
    const channelSignature = JSON.stringify(channels);
    if (channels.length > 0 && channelSignature !== lastChannelSignature) {
      lastChannelSignature = channelSignature;
      window.flutter_inappwebview.callHandler('dt360AgendaChannels', channels);
    }
    if (channels.length > 0) {
      window.setTimeout(hideCapturedStandaloneChannelCards, 0);
    }
    if (unique.length === 0) return;
    const today = new Date();
    const todaysEvents = unique.filter((event) => {
      const startsAt = new Date(event.startsAt);
      return !Number.isNaN(startsAt.getTime()) &&
        startsAt.getFullYear() === today.getFullYear() &&
        startsAt.getMonth() === today.getMonth() &&
        startsAt.getDate() === today.getDate();
    });
    if (todaysEvents.length === 0) return;
    const signature = JSON.stringify(todaysEvents);
    if (signature === lastSignature) return;
    lastSignature = signature;
    const hasTransmissionOptions = todaysEvents.some((event) =>
      Array.isArray(event.transmissionOptions) &&
      event.transmissionOptions.length > 0
    );
    window.flutter_inappwebview.callHandler('dt360AgendaEvents', todaysEvents);
    // La aplicación ya recibió las opciones publicadas; se retiran solo sus
    // botones/cuadros del área de agenda, no los controles del reproductor.
    if (hasTransmissionOptions) {
      window.setTimeout(hideCapturedTransmissionOptions, 0);
    }
  }

  function queueEmit() {
    if (queued) return;
    queued = true;
    window.setTimeout(emitAgendaEvents, 250);
  }

  document.addEventListener('click', () => {
    window.setTimeout(queueEmit, 250);
  }, true);

  const observer = new MutationObserver(queueEmit);
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
    characterData: true
  });
  window.__dt360EmitAgendaEvents = emitAgendaEvents;
  window.__dt360AgendaCaptureObserver = observer;
  window.__dt360AgendaCaptureInstalled = true;
  emitAgendaEvents();
  window.setInterval(emitAgendaEvents, 20000);
})();
''';
