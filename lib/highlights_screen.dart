import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'app_i18n.dart';

const Color _bg = Color(0xFF030814);
const Color _panel = Color(0xFF071326);
const Color _line = Color(0xFF123D65);
const Color _cyan = Color(0xFF00E5FF);
const Color _muted = Color(0xFFA9BDD6);

/// Busca y reproduce resúmenes desde YouTube dentro de la aplicación.
/// El contenido y la reproducción siguen sujetos a YouTube y a cada canal.
class HighlightsScreen extends StatefulWidget {
  const HighlightsScreen({super.key});

  @override
  State<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends State<HighlightsScreen> {
  InAppWebViewController? _controller;
  bool _loading = true;
  double _progress = 0;
  String _query = 'resúmenes deportivos de hoy';

  WebUri get _searchUri => WebUri(
        'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(_query)}',
      );

  Future<void> _search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    setState(() {
      _query = clean;
      _loading = true;
      _progress = 0;
    });
    try {
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: _searchUri),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _message('No se pudo cargar la búsqueda. Comprueba tu conexión.');
      }
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> _back() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'RESÚMENES DEPORTIVOS',
          style: TextStyle(color: _cyan, fontWeight: FontWeight.w900, fontSize: 14),
        ),
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_rounded, color: _cyan),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: appText('Recargar', 'Reload', 'Recarregar', 'Recharger'),
            onPressed: () => _controller?.reload(),
            icon: const Icon(Icons.refresh_rounded, color: _cyan),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
              color: _panel,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: TextEditingController(text: _query)
                    ..selection = TextSelection.collapsed(offset: _query.length),
                  onSubmitted: _search,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar resúmenes, goles o highlights',
                    prefixIcon: const Icon(Icons.search_rounded, color: _cyan),
                    suffixIcon: IconButton(
                      onPressed: () => _search(_query),
                      icon: const Icon(Icons.arrow_forward_rounded, color: _cyan),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF020B19),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _line),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _QueryChip(label: 'Fútbol', onTap: () => _search('resúmenes fútbol de hoy')),
                      _QueryChip(label: 'Champions', onTap: () => _search('resúmenes UEFA Champions League')),
                      _QueryChip(label: 'NBA', onTap: () => _search('NBA highlights')),
                      _QueryChip(label: 'Todos los deportes', onTap: () => _search('resúmenes deportivos de hoy')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              minHeight: 2,
              color: _cyan,
              backgroundColor: _panel,
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: _searchUri),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                thirdPartyCookiesEnabled: true,
                mediaPlaybackRequiresUserGesture: true,
                allowsInlineMediaPlayback: true,
                iframeAllowFullscreen: true,
                isElementFullscreenEnabled: true,
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: true,
                hardwareAcceleration: true,
                safeBrowsingEnabled: true,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onProgressChanged: (controller, progress) {
                if (mounted) setState(() {
                  _progress = progress / 100;
                  _loading = progress < 100;
                });
              },
              onLoadStop: (controller, url) {
                if (mounted) setState(() => _loading = false);
              },
              shouldOverrideUrlLoading: (controller, action) async {
                final uri = action.request.url;
                if (uri == null || uri.scheme != 'https') {
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
            color: _panel,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: const Text(
              'Los vídeos se reproducen desde YouTube. La disponibilidad, anuncios y restricciones dependen de YouTube y del canal que publicó cada vídeo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 9, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueryChip extends StatelessWidget {
  const _QueryChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ActionChip(
          label: Text(label, style: const TextStyle(fontSize: 10)),
          onPressed: onTap,
          backgroundColor: const Color(0xFF10243A),
          side: const BorderSide(color: _line),
          labelStyle: const TextStyle(color: _cyan),
        ),
      );
}
