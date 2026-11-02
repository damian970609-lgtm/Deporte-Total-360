import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_i18n.dart';

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
  int _webViewGeneration = 0;

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
          _error = appText('No se pudo abrir esta sección de Mister Fantasy.', 'Could not open this Mister Fantasy section.', 'Não foi possível abrir esta seção do Mister Fantasy.', 'Impossible d’ouvrir cette section de Mister Fantasy.');
          _loading = false;
        });
      }
    }
    return false;
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      _controller = null;
      _webViewGeneration++;
      _loading = true;
      _progress = 0;
      _error = null;
    });
  }

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null) {
      await _retry();
      return;
    }

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
        _error = appText('No se pudo recargar Mister Fantasy. Comprueba tu conexión.', 'Could not reload Mister Fantasy. Check your connection.', 'Não foi possível recarregar o Mister Fantasy. Verifique sua conexão.', 'Impossible de recharger Mister Fantasy. Vérifiez votre connexion.');
      });
    }
  }

  Future<void> _checkForBlankPage(InAppWebViewController controller) async {
    await Future<void>.delayed(const Duration(seconds: 7));
    if (!mounted || !identical(_controller, controller) || _loading || _error != null) {
      return;
    }

    try {
      final visible = await controller.evaluateJavascript(source: r'''
        (() => {
          const body = document.body;
          if (!body) return false;
          const text = (body.innerText || '').trim();
          const content = body.querySelector(
            'main,[role="main"],iframe,video,canvas,img,svg,#root > *,#app > *'
          );
          return text.length > 20 || content !== null;
        })()
      ''');
      final value = visible?.toString().toLowerCase();
      if (visible == false || value == 'false' || value == '0' || value == 'null') {
        if (!mounted) return;
        setState(() {
          _error = appText(
            'El sitio oficial abrió, pero no mostró contenido dentro del navegador integrado. Puede ser una limitación de WebView, conexión o disponibilidad regional.',
            'The official site opened but did not render content in the in-app browser. This may be a WebView, network, or regional availability limitation.',
            'O site oficial abriu, mas não mostrou conteúdo no navegador integrado. Pode ser uma limitação do WebView, da conexão ou da disponibilidade regional.',
            'Le site officiel s’est ouvert, mais n’a affiché aucun contenu dans le navigateur intégré. Cela peut venir du WebView, du réseau ou de la disponibilité régionale.',
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = appText(
          'No se pudo comprobar si Mister Fantasy terminó de dibujar la página. Puedes reintentar o abrir el sitio oficial en Chrome.',
          'Could not verify whether Mister Fantasy finished rendering. Retry or open the official site in Chrome.',
          'Não foi possível verificar se o Mister Fantasy terminou de renderizar a página. Tente novamente ou abra o site oficial no Chrome.',
          'Impossible de vérifier si Mister Fantasy a terminé le rendu. Réessayez ou ouvrez le site officiel dans Chrome.',
        );
      });
    }
  }

  Future<void> _openInBrowser() async {
    final opened = await launchUrl(
      Uri.parse(FantasyScreen.officialUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appText(
          'No se pudo abrir el navegador externo.',
          'Could not open the external browser.',
          'Não foi possível abrir o navegador externo.',
          'Impossible d’ouvrir le navigateur externe.',
        ))),
      );
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
            tooltip: appText('Atrás', 'Back', 'Voltar', 'Retour'),
            onPressed: _handleBackRequest,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _fantasyCyan,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                appText('FANTASY DEPORTE TOTAL 360°', 'TOTAL SPORTS 360° FANTASY', 'FANTASY ESPORTE TOTAL 360°', 'FANTASY SPORT TOTAL 360°'),
                style: TextStyle(
                  color: _fantasyCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                appText('Servicio oficial de Mister Fantasy', 'Official Mister Fantasy service', 'Serviço oficial do Mister Fantasy', 'Service officiel de Mister Fantasy'),
                style: TextStyle(
                  color: _fantasyMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: appText('Recargar', 'Reload', 'Recarregar', 'Recharger'),
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
                      key: ValueKey<int>(_webViewGeneration),
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
                        transparentBackground: true,
                        underPageBackgroundColor: _fantasyBg,
                        cacheEnabled: true,
                        useOnRenderProcessGone: true,
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
                        unawaited(_checkForBlankPage(controller));
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
                      androidOnRenderProcessGone: (controller, detail) {
                        if (!mounted) return;
                        _controller = null;
                        setState(() {
                          _loading = false;
                          _error = appText(
                            'Android cerró el proceso gráfico de la página. Pulsa Reintentar para crear un navegador nuevo.',
                            'Android closed the page renderer. Tap Retry to create a new browser.',
                            'O Android encerrou o processo gráfico da página. Toque em Tentar novamente para criar um novo navegador.',
                            'Android a fermé le processus graphique de la page. Appuyez sur Réessayer pour créer un nouveau navigateur.',
                          );
                        });
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
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(appText('REINTENTAR', 'RETRY', 'TENTAR NOVAMENTE', 'RÉESSAYER')),
              style: FilledButton.styleFrom(
                backgroundColor: _fantasyBlue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: Text(appText(
                'ABRIR MISTER EN CHROME',
                'OPEN MISTER IN BROWSER',
                'ABRIR MISTER NO NAVEGADOR',
                'OUVRIR MISTER DANS LE NAVIGATEUR',
              )),
              style: OutlinedButton.styleFrom(
                foregroundColor: _fantasyCyan,
                side: const BorderSide(color: _fantasyCyan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}