import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'app_i18n.dart';

const Color _summaryBg = Color(0xFF030814);
const Color _summaryPanel = Color(0xFF071326);
const Color _summaryLine = Color(0xFF123D65);
const Color _summaryCyan = Color(0xFF00E5FF);
const Color _summaryPink = Color(0xFFFF28CF);
const Color _summaryMuted = Color(0xFFA9BDD6);

class _SummaryCategory {
  const _SummaryCategory(this.name, this.query, this.icon, this.color);

  final String name;
  final String query;
  final IconData icon;
  final Color color;
}

/// Abre búsquedas de resúmenes y mejores jugadas en YouTube.
/// El vídeo lo sirve su canal original; la aplicación no descarga ni redistribuye contenido.
class SportsSummariesScreen extends StatelessWidget {
  const SportsSummariesScreen({super.key});

  static const List<_SummaryCategory> _categories = <_SummaryCategory>[
    _SummaryCategory('Fútbol', 'resumenes futbol partidos oficiales', Icons.sports_soccer_rounded, _summaryCyan),
    _SummaryCategory('NBA', 'NBA official highlights', Icons.sports_basketball_rounded, _summaryPink),
    _SummaryCategory('Béisbol', 'MLB official highlights', Icons.sports_baseball_rounded, _summaryCyan),
    _SummaryCategory('NFL', 'NFL official highlights', Icons.sports_football_rounded, _summaryPink),
    _SummaryCategory('Fórmula 1', 'Formula 1 official race highlights', Icons.sports_motorsports_rounded, _summaryCyan),
    _SummaryCategory('MMA / UFC', 'UFC official fight highlights', Icons.sports_mma_rounded, _summaryPink),
    _SummaryCategory('Rugby', 'rugby official match highlights', Icons.sports_rugby_rounded, _summaryCyan),
    _SummaryCategory('Vóley', 'volleyball official match highlights', Icons.sports_volleyball_rounded, _summaryPink),
  ];

  Future<void> _openSearch(BuildContext context, _SummaryCategory category) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => YouTubeHighlightsPlayerScreen(
          title: category.name,
          query: category.query,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _summaryBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: Text(
          appText('RESÚMENES DEPORTIVOS', 'SPORTS HIGHLIGHTS', 'RESUMOS ESPORTIVOS', 'RÉSUMÉS SPORTIFS'),
          style: const TextStyle(
            color: _summaryCyan,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _summaryPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _summaryLine),
            ),
            child: Text(
              appText(
                'Encuentra resúmenes, goles y mejores jugadas por deporte. Se abrirán resultados de YouTube de los canales que publican cada vídeo.',
                'Find match recaps, goals and highlights by sport. YouTube results from the channels publishing each video will open.',
                'Encontre resumos, gols e melhores jogadas por esporte. Serão abertos resultados do YouTube dos canais que publicam cada vídeo.',
                'Trouvez des résumés, des buts et les meilleurs moments par sport. Les résultats YouTube des chaînes qui publient chaque vidéo s’ouvriront.',
              ),
              style: const TextStyle(color: _summaryMuted, height: 1.45, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          for (final category in _categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: _summaryPanel,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => _openSearch(context, category),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: category.color.withAlpha(150)),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(category.icon, color: category.color, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Icon(Icons.play_circle_outline_rounded, color: _summaryCyan),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// Reproduce los resultados de YouTube dentro de la APK, sin descargar ni
/// redistribuir vídeos. La reproducción y sus restricciones pertenecen a YouTube.
class YouTubeHighlightsPlayerScreen extends StatefulWidget {
  const YouTubeHighlightsPlayerScreen({
    super.key,
    required this.title,
    required this.query,
  });

  final String title;
  final String query;

  @override
  State<YouTubeHighlightsPlayerScreen> createState() =>
      _YouTubeHighlightsPlayerScreenState();
}

class _YouTubeHighlightsPlayerScreenState
    extends State<YouTubeHighlightsPlayerScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = true;
  bool _allowPop = false;
  bool _handlingBack = false;

  WebUri get _searchUrl => WebUri(
        'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(widget.query)}',
      );

  Future<void> _handleBack() async {
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
          // Si YouTube no expone historial, se permite salir de esta vista.
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

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: _summaryBg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF020B19),
          leading: IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded, color: _summaryCyan),
          ),
          title: Text(
            'RESÚMENES · ${widget.title.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _summaryCyan,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: appText('Recargar', 'Reload', 'Recarregar', 'Recharger'),
              onPressed: () => _controller?.reload(),
              icon: const Icon(Icons.refresh_rounded, color: _summaryCyan),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            if (_loading)
              LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 2,
                color: _summaryCyan,
                backgroundColor: _summaryPanel,
              ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: _searchUrl),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  mediaPlaybackRequiresUserGesture: true,
                  allowsInlineMediaPlayback: true,
                  iframeAllowFullscreen: true,
                  isElementFullscreenEnabled: true,
                  hardwareAcceleration: true,
                  safeBrowsingEnabled: true,
                ),
                onWebViewCreated: (controller) => _controller = controller,
                onProgressChanged: (controller, progress) {
                  if (!mounted) return;
                  setState(() {
                    _progress = progress / 100;
                    _loading = progress < 100;
                  });
                },
                onLoadStop: (controller, url) {
                  if (mounted) setState(() => _loading = false);
                },
                onCreateWindow: (controller, action) async {
                  final target = action.request.url;
                  if (target == null || target.scheme != 'https') return false;
                  try {
                    await controller.loadUrl(
                      urlRequest: action.request,
                    );
                  } catch (_) {
                    // No se abre una ventana externa si falla la navegación.
                  }
                  return false;
                },
                shouldOverrideUrlLoading: (controller, action) async {
                  final target = action.request.url;
                  if (target == null || target.scheme != 'https') {
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame == true && mounted) {
                    setState(() => _loading = false);
                  }
                },
              ),
            ),
            Container(
              width: double.infinity,
              color: _summaryPanel,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                appText(
                  'Reproducción desde YouTube. La disponibilidad y las restricciones dependen de YouTube y del canal original.',
                  'Playback is provided by YouTube. Availability and restrictions depend on YouTube and the original channel.',
                  'A reprodução é fornecida pelo YouTube. A disponibilidade e as restrições dependem do YouTube e do canal original.',
                  'La lecture est fournie par YouTube. La disponibilité et les restrictions dépendent de YouTube et de la chaîne d’origine.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _summaryMuted,
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
}
