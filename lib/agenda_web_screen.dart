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
      await controller.evaluateJavascript(source: _agendaOnlyScript);
      await controller.evaluateJavascript(source: _agendaLiveCaptureScript);
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
      '[role="link"][href], [role="button"][data-href], [role="button"][data-url]';
    const elements = Array.from(root.querySelectorAll(selector));
    elements.forEach((element, index) => {
      // Incluye enlaces ya presentes en el DOM aunque la tarjeta los oculte por CSS.
      const label = visibleText(element) ||
        element.getAttribute('aria-label') ||
        element.getAttribute('title') || '';
      const metadata = [
        label,
        element.className,
        element.getAttribute('aria-label'),
        element.getAttribute('title')
      ].join(' ').toLowerCase();
      if (!/(canal|fuente|señal|senal|opci[oó]n|transmisi[oó]n|stream|player|watch|ver directo|abrir canal)/i.test(metadata)) return;

      const rawUrl = element.href ||
        element.getAttribute('data-href') ||
        element.getAttribute('data-url') || '';
      let url = '';
      try {
        url = new URL(rawUrl, document.baseURI).href;
      } catch (_) {
        return;
      }
      if (!/^https:\/\//i.test(url)) return;

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



  function readSportsChannels(root) {
    const found = [];
    const seen = new Set();
    const selector = 'a[href], button[data-href], button[data-url], ' +
      '[role="link"][href], [role="button"][data-href], [role="button"][data-url]';
    const headings = Array.from(root.querySelectorAll(
      'h1, h2, h3, h4, h5, [role="heading"]'
    )).filter((heading) => {
      const label = normalize(visibleText(heading));
      return /canales? (?:deportivos?|en vivo|y transmisiones?|y disponibilidad)|señales deportivas/.test(label);
    });

    headings.forEach((heading) => {
      let scope = heading.closest('section, article') || heading.parentElement;
      let bestScope = scope;
      for (let depth = 0; depth < 6 && scope &&
          scope !== document.body && scope !== document.documentElement; depth += 1) {
        const count = scope.querySelectorAll(selector).length;
        if (count > 0 && count <= 160) {
          bestScope = scope;
          if (count > 1 || depth > 1) break;
        }
        scope = scope.parentElement;
      }
      if (!bestScope) return;

      Array.from(bestScope.querySelectorAll(selector)).forEach((element) => {
        const rawUrl = element.href ||
          element.getAttribute('data-href') ||
          element.getAttribute('data-url') || '';
        let url = '';
        try {
          url = new URL(rawUrl, document.baseURI).href;
        } catch (_) {
          return;
        }
        if (!/^https:\/\//i.test(url)) return;

        let card = element.closest('article, li, [class*="channel"], [class*="card"]') ||
          element.parentElement || element;
        let titleNode = card.querySelector(
          '[data-channel-name], h2, h3, h4, h5, [class*="channel-title"], [class*="title"]'
        );
        let name = visibleText(titleNode);
        const image = card.querySelector('img');
        if (!name && image) name = image.getAttribute('alt') || '';
        if (!name) name = visibleText(element) ||
          element.getAttribute('aria-label') || element.getAttribute('title') || '';
        name = String(name || '')
          .replace(/\b(?:ver en vivo|ver canal|ver online|reproducir|en vivo)\b/gi, '')
          .replace(/\s+/g, ' ')
          .trim();
        const normalizedName = normalize(name);
        if (!normalizedName || normalizedName.length < 2 ||
            /^(canales? deportivos?|canales? en vivo|ver|reproducir|abrir)$/.test(normalizedName)) return;

        const key = normalizedName;
        if (seen.has(key)) return;
        seen.add(key);

        let logoUrl = '';
        if (image) {
          const rawLogo = image.currentSrc || image.src ||
            image.getAttribute('data-src') || '';
          try {
            const parsedLogo = new URL(rawLogo, document.baseURI);
            if (parsedLogo.protocol === 'https:') logoUrl = parsedLogo.href;
          } catch (_) {}
        }
        const popularityText = [
          element.getAttribute('data-popularity'),
          element.getAttribute('data-views'),
          element.getAttribute('data-votes'),
          element.getAttribute('data-rating'),
          card.getAttribute('data-popularity'),
          card.getAttribute('data-views')
        ].join(' ');
        const metricMatch = popularityText.match(/[0-9]+/);
        let popularityScore = metricMatch ? Number(metricMatch[0]) : 0;
        if (/(popular|destacad[oa]|recomendad[oa]|principal|m[aá]s visto|top)/i.test(
          popularityText + ' ' + element.className + ' ' + card.className
        )) popularityScore = Math.max(popularityScore, 1000000);

        found.push({
          id: key,
          name: name,
          url: url,
          logoUrl: logoUrl,
          order: found.length,
          popularityScore: popularityScore
        });
      });
    });
    return found;
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
    const title = (matchup || titleFromNode ||
      lines.find((line) => line.length > 5 && !timePattern.test(line)) || '')
      .replace(timeGlobalPattern, '')
      .replace(/\s+/g, ' ')
      .trim();
    if (!title || title.length > 160) return null;

    const competition = lines.find((line) =>
      /liga|league|copa|cup|torneo|tournament|premier|champions|concacaf|conmebol|uefa|nba|mlb|nhl/i.test(line) &&
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
      'a[href*="partido"], a[href*="evento"], a[href*="match"], ' +
      'a[href*="event"], a[href*="en-vivo"], a[href*="live"], ' +
      'a[data-event-link], [data-event-url]'
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
  let queued = false;
  let activeEvent = null;
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
    if (activeEvent) {
      const expandedOptions = readTransmissionOptions(document.body);
      if (expandedOptions.length > 0) {
        activeEvent.transmissionOptions = expandedOptions;
        const existingIndex = unique.findIndex((event) => event.id === activeEvent.id);
        if (existingIndex >= 0) unique[existingIndex] = activeEvent;
        else unique.push(activeEvent);
      }
    }
    const channels = readSportsChannels(document.body);
    if (unique.length === 0 && channels.length === 0) return;
    const payload = { events: unique, channels: channels };
    const signature = JSON.stringify(payload);
    if (signature === lastSignature) return;
    lastSignature = signature;
    window.flutter_inappwebview.callHandler('dt360AgendaEvents', payload);
  }

  function queueEmit() {
    if (queued) return;
    queued = true;
    window.setTimeout(emitAgendaEvents, 250);
  }

  document.addEventListener('click', (clickEvent) => {
    const target = clickEvent.target && clickEvent.target.closest
      ? clickEvent.target.closest('a, button, [role="button"], [data-event-id]')
      : null;
    if (target) {
      let candidate = target;
      for (let depth = 0; depth < 9 && candidate &&
          candidate !== document.body && candidate !== document.documentElement; depth += 1) {
        const timeNode = candidate.querySelector &&
          candidate.querySelector('time[datetime], [data-time], [data-start-time], time');
        const containsClock = timePattern.test(visibleText(candidate));
        if (timeNode || containsClock) {
          const card = timeNode ? findEventCard(timeNode) : candidate;
          const event = readEvent(card);
          if (event) {
            const clickedUrl = target.matches('a[href]')
              ? target.href
              : target.getAttribute('data-event-url') ||
                target.getAttribute('data-href') ||
                target.getAttribute('data-url') || '';
            if (clickedUrl) {
              try {
                const parsed = new URL(clickedUrl, document.baseURI);
                if (parsed.protocol === 'https:' && !parsed.username &&
                    !parsed.password) event.detailUrl = parsed.href;
              } catch (_) {}
            }
            activeEvent = event;
            // Guarda la ficha seleccionada antes de que el sitio navegue a ella.
            // Así En vivo conserva la URL exacta incluso si la página cambia rápido.
            if (window.flutter_inappwebview &&
                typeof window.flutter_inappwebview.callHandler === 'function') {
              window.flutter_inappwebview.callHandler(
                'dt360AgendaEvents',
                { events: [event], channels: [] }
              );
            }
            break;
          }
        }
        candidate = candidate.parentElement;
      }
    }
    window.setTimeout(queueEmit, 250);
    window.setTimeout(queueEmit, 900);
    window.setTimeout(queueEmit, 1800);
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
