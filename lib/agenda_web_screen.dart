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
  return weekdays[date.weekday - 1] + ', ' + date.day.toString() + ' de ' +
      months[date.month - 1] + ' de ' + date.year.toString();
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
    } catch (error) {
      debugPrint('No se pudo aplicar el filtro visual de Agenda: $error');
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
                    onWebViewCreated: (controller) => _controller = controller,
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
      block.style.setProperty('display', 'none', 'important');
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

    document.querySelectorAll('section, article').forEach((block) => {
      const headings = Array.from(block.querySelectorAll('h1, h2, h3, h4'));
      if (headings.some((heading) =>
          excludedHeadings.some((part) => normalize(heading.textContent).includes(part)))) {
        block.style.setProperty('display', 'none', 'important');
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
