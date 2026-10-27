import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String _agendaUrl = 'https://futbol-libre.cam/';
const String _fallbackAgendaUrl = 'https://www.espn.com/soccer/scoreboard';

const Color _navy = Color(0xFF020817);
const Color _panel = Color(0xFF071B35);
const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF28CF);
const Color _green = Color(0xFF39FF9C);
const Color _yellow = Color(0xFFFFD600);
const Color _red = Color(0xFFFF1744);
const Color _muted = Color(0xFFB4C4D9);

class WebAgendaScreen extends StatefulWidget {
  const WebAgendaScreen({
    super.key,
    this.initialUrl = _agendaUrl,
    this.pageTitle = 'AGENDA DE PARTIDOS',
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
  bool _isPopping = false;
  double _progress = 0;

  String? _error;
  String _logoDataUrl = '';

  int _viewKey = 0;

  static const List<String> _blockedHosts = <String>[
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.com',
    'adnxs.com',
    'adsrvr.org',
    'ad-delivery.net',
    'adsterra.com',
    'adsterratools.com',
    'popads.net',
    'popcash.net',
    'exoclick.com',
    'onclickads.net',
    'onclickalgo.com',
    'propellerads.com',
    'trafficjunky.com',
    'trafficjunky.net',
    'juicyads.com',
    'richpush.co',
    'taboola.com',
    'outbrain.com',
    'revcontent.com',
    'mgid.com',
    'criteo.com',
    'smartadserver.com',
    'media.net',
    'bidvertiser.com',
    'monetag.com',
    'admaven.com',
    'ero-advertising.com',
    'popunder.net',
    'pushground.com',
    'push-house.net',
  ];

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.initialUrl;
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/app_icon.png');

      if (!mounted) return;

      setState(() {
        _logoDataUrl =
            'data:image/png;base64,${base64Encode(data.buffer.asUint8List())}';
      });

      final controller = _controller;
      if (controller != null) {
        await _applyBranding(controller);
      }
    } catch (_) {
      // La web seguirá funcionando aunque no cargue el fondo.
    }
  }

  bool _hostMatches(String host, String domain) {
    final value = host.toLowerCase();
    return value == domain || value.endsWith('.$domain');
  }

  bool _isBlockedUri(Uri uri) {
    final host = uri.host.toLowerCase();

    if (_blockedHosts.any((domain) => _hostMatches(host, domain))) {
      return true;
    }

    final address = '${uri.host}${uri.path}${uri.query}'.toLowerCase();

    return RegExp(
      r'(popunder|clickunder|popup-ad|pop-up-ad|'
      r'interstitial-ad|redirect-ad|adult-content|'
      r'porn-video|xxx-video|hentai-video|camgirl)',
    ).hasMatch(address);
  }

  bool _isAllowedUri(Uri uri) {
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
        !_isBlockedUri(uri);
  }

  Future<NavigationActionPolicy> _handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final rawUrl = action.request.url?.toString() ?? '';
    final uri = Uri.tryParse(rawUrl);

    if (uri == null || !_isAllowedUri(uri)) {
      return NavigationActionPolicy.CANCEL;
    }

    // No se bloquea un reproductor solo porque esté alojado
    // en un dominio diferente al de la agenda.
    return NavigationActionPolicy.ALLOW;
  }

  Future<WebResourceResponse?> _interceptRequest(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    final uri = Uri.tryParse(request.url.toString());

    if (uri != null && _isBlockedUri(uri)) {
      return WebResourceResponse(
        contentType: 'text/plain',
        data: Uint8List(0),
        statusCode: 204,
        reasonPhrase: 'Blocked',
      );
    }

    return null;
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);

    if (uri == null || !_isAllowedUri(uri)) {
      _showMessage('No se puede abrir ese enlace.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _activeUrl = uri.toString();
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
        urlRequest: URLRequest(url: WebUri(uri.toString())),
      );
    } catch (_) {
      _setError('No se pudo abrir la página. Comprueba tu conexión.');
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
      await controller.reload();
    } catch (_) {
      _setError('No se pudo recargar la página.');
    }
  }

  Future<void> _goBack() async {
    if (_isPopping) return;

    final controller = _controller;

    if (controller != null) {
      try {
        if (await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
      } catch (_) {
        // Si no queda historial, se cierra la pantalla.
      }
    }

    if (!mounted) return;

    _isPopping = true;
    Navigator.of(context).pop();
  }

  void _setError(String message) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = message;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _panel,
      ),
    );
  }

  Future<void> _applyBranding(
    InAppWebViewController controller,
  ) async {
    try {
      const rawScript = r'''
        (function () {
          if (!document.documentElement) return;

          const logoData = '__DT360_LOGO__';

          const blockedHosts = [
            'doubleclick.net',
            'googlesyndication.com',
            'googleadservices.com',
            'adservice.google.com',
            'adnxs.com',
            'adsrvr.org',
            'adsterra.com',
            'adsterratools.com',
            'popads.net',
            'popcash.net',
            'exoclick.com',
            'onclickads.net',
            'onclickalgo.com',
            'propellerads.com',
            'trafficjunky.com',
            'trafficjunky.net',
            'juicyads.com',
            'taboola.com',
            'outbrain.com',
            'revcontent.com',
            'mgid.com',
            'criteo.com',
            'smartadserver.com',
            'media.net',
            'bidvertiser.com',
            'monetag.com',
            'admaven.com',
            'popunder.net',
            'pushground.com',
            'push-house.net'
          ];

          function blockedUrl(value) {
            try {
              const u = new URL(value, location.href);
              if (!/^https?:$/.test(u.protocol)) return false;

              const host = u.hostname.toLowerCase();

              if (blockedHosts.some(
                d => host === d || host.endsWith('.' + d)
              )) {
                return true;
              }

              return /(popunder|clickunder|popup-ad|pop-up-ad|interstitial-ad)/i
                .test(host + u.pathname + u.search);
            } catch (_) {
              return false;
            }
          }

          function hideElement(element) {
            if (!element || element === document.body) return;
            element.style.setProperty('display', 'none', 'important');
            element.style.setProperty('visibility', 'hidden', 'important');
          }

          function installStyles() {
            let style = document.getElementById('dt360-app-style');

            if (!style) {
              style = document.createElement('style');
              style.id = 'dt360-app-style';
              (document.head || document.documentElement)
                .appendChild(style);
            }

            // Solo se inyecta el CSS una vez por documento.
            if (style.dataset.dt360Version !== '2') {
              style.textContent = `
                html, body {
                  color: #f4f8ff !important;
                  color-scheme: dark !important;
                  background-color: #020817 !important;
                  background-image:
                    linear-gradient(
                      rgba(2, 8, 23, .88),
                      rgba(2, 8, 23, .94)
                    ),
                    url("${logoData}") !important;
                  background-repeat: no-repeat, no-repeat !important;
                  background-position: center, center !important;
                  background-size: cover, min(78vw, 440px) auto !important;
                  background-attachment: fixed, fixed !important;
                }

                body {
                  min-height: 100vh !important;
                  margin: 0 !important;
                  overflow-x: hidden !important;
                  font-family: Arial, Helvetica, sans-serif !important;
                }

                a, a:visited {
                  color: #00e5ff !important;
                }

                .dt360-play-link,
                a.dt360-play-link,
                button.dt360-play-link,
                .dt360-reload-button {
                  display: inline-flex !important;
                  align-items: center !important;
                  justify-content: center !important;
                  box-sizing: border-box !important;
                  min-height: 42px !important;
                  padding: 10px 16px !important;
                  margin: 6px 4px !important;
                  border: 1px solid #ff7f96 !important;
                  border-radius: 12px !important;
                  background: linear-gradient(
                    180deg, #ff4268 0%, #f00038 100%
                  ) !important;
                  color: #ffffff !important;
                  font: 900 14px Arial, sans-serif !important;
                  letter-spacing: .5px !important;
                  text-decoration: none !important;
                  text-align: center !important;
                  text-shadow: 0 1px 2px #73001b !important;
                  box-shadow:
                    0 5px 0 #8f0024,
                    0 0 14px rgba(255, 23, 68, .55) !important;
                  transform: translateY(-1px) !important;
                }

                .dt360-play-link:active,
                .dt360-reload-button:active {
                  transform: translateY(3px) !important;
                  box-shadow: 0 2px 0 #8f0024 !important;
                }

                button, input[type="button"], input[type="submit"],
                [role="button"], .btn {
                  border-radius: 12px !important;
                  font-weight: 900 !important;
                }

                iframe[src*="doubleclick" i],
                iframe[src*="googlesyndication" i],
                iframe[src*="adsterra" i],
                iframe[src*="popads" i],
                iframe[src*="popcash" i],
                iframe[src*="popunder" i],
                iframe[src*="onclickads" i],
                iframe[src*="exoclick" i],
                [class*="adsbygoogle" i],
                [id*="google_ads" i],
                [class*="advertisement" i],
                [id*="advertisement" i],
                [class*="popunder" i],
                [id*="popunder" i],
                [class*="ad-container" i],
                [id*="ad-container" i],
                [class*="discord" i],
                [id*="discord" i],
                a[href*="discord.com" i],
                iframe[src*="discord.com" i],
                footer, .site-footer, #footer {
                  display: none !important;
                  visibility: hidden !important;
                  pointer-events: none !important;
                }

                video {
                  display: block !important;
                  width: 100% !important;
                  max-width: 100% !important;
                  height: auto !important;
                  background: #000 !important;
                  object-fit: contain !important;
                }

                iframe {
                  max-width: 100% !important;
                  background: #000 !important;
                }

                .video-js, .jwplayer, #player, #video-player,
                .player-container, .video-container {
                  max-width: 100% !important;
                  background: #000 !important;
                  border-radius: 10px !important;
                  overflow: hidden !important;
                }
              `;

              style.dataset.dt360Version = '2';
            }

            // Quita banners duplicados de versiones anteriores.
            document.getElementById('dt360-page-banner')?.remove();
            document.getElementById('dt360-status-legend')?.remove();
          }

          function setText(element, value) {
            if (element.tagName === 'INPUT') {
              if (element.value !== value) element.value = value;
              return;
            }

            if ((element.textContent || '').trim() !== value) {
              element.textContent = value;
            }
          }

          function hideSiteHeader() {
            document.querySelectorAll(
              'header, .site-header, .main-header, .mobile-header, ' +
              '.desktop-header, .navbar-header, .site-navbar, ' +
              '#header, #navbar, .navbar'
            ).forEach(element => {
              if (!element.querySelector('video, iframe, embed, object')) {
                hideElement(element);
              }
            });

            // Busca títulos que solo dicen "Fútbol Libre".
            const leaves = Array.from(document.querySelectorAll('body *'))
              .filter(element => {
                if (element.children.length > 2) return false;

                const text = (
                  element.innerText || element.textContent || ''
                ).replace(/\s+/g, ' ').trim();

                return /^f[úu]tbol libre(?: tv)?$/i.test(text);
              });

            leaves.forEach(leaf => {
              let candidate = leaf;

              for (let i = 0; i < 6 && candidate; i++) {
                const rect = candidate.getBoundingClientRect();
                const text = (
                  candidate.innerText || candidate.textContent || ''
                ).replace(/\s+/g, ' ').trim();

                const hasMedia = candidate.querySelector &&
                  candidate.querySelector('video, iframe, embed, object');

                if (
                  i >= 1 &&
                  rect.width >= window.innerWidth * .65 &&
                  rect.height >= 30 &&
                  rect.height <= 180 &&
                  text.length < 220 &&
                  !hasMedia
                ) {
                  hideElement(candidate);
                  break;
                }

                candidate = candidate.parentElement;
              }
            });
          }

          function hidePromotionalBlocks() {
            document.querySelectorAll(
              'a[href*="discord" i], iframe[src*="discord" i], ' +
              '[class*="discord" i], [id*="discord" i], ' +
              '.social-links, .social-share, .site-footer, footer'
            ).forEach(hideElement);

            const patterns = [
              /información de la señal/i,
              /selecciona el reproductor para iniciar/i,
              /si tarda en cargar.*botón de recarga/i,
              /únete a nuestro discord/i,
              /join our discord/i
            ];

            patterns.forEach(pattern => {
              const leaves = Array.from(document.querySelectorAll('body *'))
                .filter(element => {
                  if (element.children.length > 2) return false;

                  const text = (
                    element.innerText || element.textContent || ''
                  ).replace(/\s+/g, ' ').trim();

                  return text.length > 0 &&
                    text.length < 200 &&
                    pattern.test(text);
                });

              leaves.forEach(leaf => {
                let candidate = leaf;

                for (let i = 0; i < 5 && candidate; i++) {
                  const text = (
                    candidate.innerText || candidate.textContent || ''
                  ).replace(/\s+/g, ' ').trim();

                  const hasMedia = candidate.querySelector &&
                    candidate.querySelector('video, iframe, embed, object');

                  const hasReload =
                    /recargar señal|recargar canal|reload/i.test(text);

                  if (
                    i >= 1 &&
                    text.length < 1200 &&
                    !hasMedia &&
                    !hasReload
                  ) {
                    hideElement(candidate);
                    break;
                  }

                  candidate = candidate.parentElement;
                }
              });
            });
          }

          function validLink(link) {
            if (!link || !link.href) return false;

            try {
              const url = new URL(link.href, location.href);
              return /^https?:$/.test(url.protocol) && !blockedUrl(url.href);
            } catch (_) {
              return false;
            }
          }

          function isPlayerLink(element) {
            const label = (
              element.innerText ||
              element.value ||
              element.getAttribute('aria-label') ||
              element.textContent ||
              ''
            ).replace(/\s+/g, ' ').trim();

            const href = (
              element.href ||
              element.getAttribute('href') ||
              ''
            ).toLowerCase();

            const textLooksLikePlay =
              /^(ver|ver partido|ver canal|ver en vivo|reproducir|play|watch|live|en vivo|en vivo aquí|vivo|canal\s*\d*|transmitir|transmisión|esperando transmisión)$/i
                .test(label);

            const urlLooksLikePlayer =
              /\/(player|watch|live|stream|video|canal|partido|match)(\/|$|[?#])/i
                .test(href);

            return textLooksLikePlay || urlLooksLikePlayer;
          }

          function enhancePlayButtons() {
            document.querySelectorAll('.dt360-status-pill').forEach(
              element => element.remove()
            );

            const candidates = document.querySelectorAll(
              'a[href], button, [role="button"], ' +
              'input[type="button"], input[type="submit"]'
            );

            candidates.forEach(element => {
              const label = (
                element.innerText ||
                element.value ||
                element.getAttribute('aria-label') ||
                element.textContent ||
                ''
              ).replace(/\s+/g, ' ').trim();

              const reload =
                /recargar señal|recargar canal|reload signal|reload channel/i
                  .test(label);

              if (reload) {
                setText(element, 'RECARGAR CANAL');
                element.classList.add('dt360-reload-button');
                element.style.setProperty('width', 'calc(100% - 16px)');
                return;
              }

              const clickable = element.tagName === 'A' ||
                element.tagName === 'BUTTON' ||
                element.getAttribute('role') === 'button';

              if (!clickable || !isPlayerLink(element)) return;

              if (element.tagName === 'A' && !validLink(element)) {
                element.removeAttribute('href');
                return;
              }

              setText(element, 'VIVO');
              element.setAttribute('aria-label', 'VIVO');
              element.classList.add('dt360-play-link');

              if (element.tagName === 'A') {
                element.target = '_self';
                element.rel = 'noopener noreferrer';
              }
            });

            // Cambia el mensaje de espera solo si encontramos un enlace
            // de reproductor real en esa tarjeta. No inventa una URL.
            const waitingNodes = Array.from(
              document.querySelectorAll('span, small, div, p')
            ).filter(element => {
              if (element.children.length > 0) return false;

              return /^esperando transmisión$/i.test(
                (element.textContent || '').trim()
              );
            });

            waitingNodes.forEach(element => {
              const card = element.closest(
                'article, li, [class*="match" i], ' +
                '[class*="partido" i], [data-match]'
              );

              const possibleLinks = card
                ? Array.from(card.querySelectorAll('a[href]'))
                : [];

              const playerLink = possibleLinks.find(link =>
                validLink(link) && isPlayerLink(link)
              );

              if (playerLink) {
                const button = document.createElement('a');
                button.href = playerLink.href;
                button.target = '_self';
                button.rel = 'noopener noreferrer';
                button.className = 'dt360-play-link';
                button.textContent = 'VIVO';
                element.replaceWith(button);
              }
            });
          }

          function tryVideos() {
            document.querySelectorAll('video').forEach(video => {
              video.playsInline = true;
              video.setAttribute('playsinline', '');
              video.setAttribute('webkit-playsinline', '');

              if (video.dataset.dt360Listeners !== '1') {
                video.dataset.dt360Listeners = '1';

                const retryPlay = function () {
                  if (video.paused && video.readyState >= 2) {
                    try {
                      const result = video.play();
                      if (result && result.catch) {
                        result.catch(function () {
                          // El navegador puede exigir una pulsación manual.
                        });
                      }
                    } catch (_) {}
                  }
                };

                video.addEventListener('loadeddata', retryPlay, {once: true});
                video.addEventListener('canplay', retryPlay, {once: true});
              }

              if (video.paused && video.readyState >= 2) {
                try {
                  const result = video.play();

                  if (result && result.catch) {
                    result.catch(function () {
                      // Android puede exigir que el usuario toque Play.
                    });
                  }
                } catch (_) {}
              }
            });
          }

          function compactPlayerPage() {
            const text = (
              document.body.innerText || document.body.textContent || ''
            ).toLowerCase();

            const playerPage =
              /fútbol libre tv|recargar señal|información de la señal|selecciona el reproductor/
                .test(text);

            if (!playerPage) return;

            hidePromotionalBlocks();

            document.querySelectorAll(
              'header, .site-header, .main-header, .navbar, ' +
              '.site-footer, footer'
            ).forEach(element => {
              if (!element.querySelector('video, iframe, embed, object')) {
                hideElement(element);
              }
            });

            document.querySelectorAll('h1, h2, h3, h4, p, section, article')
              .forEach(element => {
                const label = (
                  element.innerText || element.textContent || ''
                ).replace(/\s+/g, ' ').trim();

                if (
                  /información de la señal|selecciona el reproductor|únete a nuestro discord/i
                    .test(label) &&
                  !element.querySelector('video, iframe, embed, object')
                ) {
                  hideElement(element);
                }
              });
          }

          function redirectAllowedPopupsIntoThisView() {
            if (window.__dt360PopupPatch) return;
            window.__dt360PopupPatch = true;

            // Permite enlaces de vídeo legítimos en la misma ventana.
            window.open = function (value) {
              if (!value) return null;

              try {
                const url = new URL(value, location.href);

                if (
                  !/^https?:$/.test(url.protocol) ||
                  blockedUrl(url.href)
                ) {
                  return null;
                }

                location.href = url.href;
                return window;
              } catch (_) {
                return null;
              }
            };

            document.addEventListener('click', function (event) {
              const target = event.target;
              const link = target && target.closest
                ? target.closest('a[href]')
                : null;

              if (link && blockedUrl(link.href)) {
                event.preventDefault();
                event.stopPropagation();
                event.stopImmediatePropagation();
                return;
              }

              const playControl = target && target.closest
                ? target.closest(
                    'video, .vjs-big-play-button, ' +
                    '.jw-icon-playback, .plyr__control--overlaid, ' +
                    '[aria-label*="play" i], [title*="play" i]'
                  )
                : null;

              if (playControl) {
                setTimeout(tryVideos, 250);
                setTimeout(tryVideos, 800);
              }
            }, true);

            document.addEventListener('submit', function (event) {
              const form = event.target;
              if (!form || !form.action) return;

              if (blockedUrl(form.action)) {
                event.preventDefault();
                event.stopPropagation();
                event.stopImmediatePropagation();
              }
            }, true);
          }

          function updatePage() {
            if (!document.body) return;

            installStyles();
            hideSiteHeader();
            enhancePlayButtons();
            compactPlayerPage();
            redirectAllowedPopupsIntoThisView();
            tryVideos();
          }

          updatePage();

          if (!window.__dt360Observer) {
            window.__dt360Observer = new MutationObserver(function () {
              clearTimeout(window.__dt360UpdateTimer);
              window.__dt360UpdateTimer = setTimeout(updatePage, 250);
            });

            window.__dt360Observer.observe(document.documentElement, {
              childList: true,
              subtree: true,
              attributes: true,
              attributeFilter: ['href', 'class', 'id']
            });
          }

          // Intenta iniciar vídeos que aparezcan después de cargar la agenda.
          setTimeout(tryVideos, 350);
          setTimeout(tryVideos, 1200);
          setTimeout(tryVideos, 2500);
        })();
      ''';

      final script = rawScript.replaceAll(
        '__DT360_LOGO__',
        _logoDataUrl,
      );

      await controller.evaluateJavascript(source: script);
    } catch (_) {
      // La página seguirá funcionando si rechaza la personalización.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _panel,
          leading: IconButton(
            onPressed: _goBack,
            tooltip: 'Atrás',
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _cyan,
            ),
          ),
          title: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sports_soccer_rounded,
                    color: _cyan,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'DEPORTE TOTAL 360°',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Recargar página',
              onPressed: _reload,
              icon: const Icon(
                Icons.refresh_rounded,
                color: _green,
              ),
            ),
            IconButton(
              tooltip: 'Agenda alternativa',
              onPressed: () => _openUrl(_fallbackAgendaUrl),
              icon: const Icon(
                Icons.sports_soccer_rounded,
                color: _yellow,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: _loading ? null : _progress,
              minHeight: 3,
              backgroundColor: _panel,
              valueColor: const AlwaysStoppedAnimation<Color>(_pink),
            ),
          ),
        ),
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Opacity(
                opacity: .12,
                child: Image.asset(
                  'assets/images/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const Positioned.fill(
              child: ColoredBox(color: Color(0xE8020817)),
            ),
            Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Color(0xFF0B1D35),
                        Color(0xFF10132D),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: _cyan,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: const Text(
                    '🔴 EN VIVO  •  ⚪ TERMINADO  •  🟡 AGENDA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      InAppWebView(
                        key: ValueKey<int>(_viewKey),
                        initialUrlRequest: URLRequest(
                          url: WebUri(_activeUrl),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          javaScriptCanOpenWindowsAutomatically: false,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                          thirdPartyCookiesEnabled: true,
                          supportMultipleWindows: false,
                          useShouldOverrideUrlLoading: true,
                          useShouldInterceptRequest: true,
                          mediaPlaybackRequiresUserGesture: false,
                          allowsInlineMediaPlayback: true,
                          useWideViewPort: true,
                          loadWithOverviewMode: true,
                          supportZoom: false,
                          builtInZoomControls: false,
                          displayZoomControls: false,
                          cacheEnabled: true,
                          transparentBackground: false,
                        ),
                        onWebViewCreated: (controller) {
                          _controller = controller;

                          if (_logoDataUrl.isNotEmpty) {
                            _applyBranding(controller);
                          }
                        },
                        onCreateWindow: (
                          controller,
                          createWindowAction,
                        ) async {
                          // Los anuncios no deben crear ventanas nuevas.
                          // window.open de vídeo se redirige mediante JS.
                          return false;
                        },
                        shouldOverrideUrlLoading: _handleNavigation,
                        shouldInterceptRequest: _interceptRequest,
                        onLoadStart: (controller, url) {
                          final uri = Uri.tryParse(url?.toString() ?? '');

                          if (uri != null && _isBlockedUri(uri)) {
                            controller.stopLoading();
                            return;
                          }

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
                          final uri = Uri.tryParse(url?.toString() ?? '');

                          if (uri != null && _isBlockedUri(uri)) {
                            await controller.stopLoading();
                            return;
                          }

                          await _applyBranding(controller);

                          if (!mounted) return;

                          setState(() {
                            _loading = false;
                            _progress = 1;
                            _error = null;

                            if (uri != null && _isAllowedUri(uri)) {
                              _activeUrl = uri.toString();
                            }
                          });
                        },
                        onReceivedError: (
                          controller,
                          request,
                          error,
                        ) {
                          if (request.isForMainFrame != true) return;

                          _setError(
                            'La página no respondió. '
                            'Comprueba tu conexión.\n\n'
                            '${error.description}',
                          );
                        },
                        onReceivedHttpError: (
                          controller,
                          request,
                          response,
                        ) {
                          if (request.isForMainFrame != true) return;

                          final status = response.statusCode;

                          if (status != null && status >= 400) {
                            _setError(
                              'El servidor respondió HTTP $status. '
                              'Puede estar temporalmente fuera de servicio.',
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
                          child: Container(
                            color: _navy.withOpacity(.94),
                            padding: const EdgeInsets.all(22),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _panel,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _red),
                                  boxShadow: const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x55FF1744),
                                      blurRadius: 18,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.wifi_off_rounded,
                                      color: _red,
                                      size: 42,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'NO SE PUDO CARGAR',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _cyan,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: _muted,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _reload,
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                        ),
                                        label: const Text('RECARGAR CANAL'),
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: _red,
                                          elevation: 7,
                                          shadowColor: _red,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
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
          ],
        ),
      ),
    );
  }
}