import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const Color _ottfoxBg = Color(0xFF030814);
const Color _ottfoxPanel = Color(0xFF071326);
const Color _ottfoxCyan = Color(0xFF00E5FF);
const Color _ottfoxMuted = Color(0xFFA9BDD6);

/// OTTFOX funciona como herramienta externa de edición y conversión.
/// La biblioteca de OTTFOX permanece en el almacenamiento local de su WebView;
/// el usuario exporta/copia una M3U para importarla después al catálogo nativo.
class OttfoxWorkspaceScreen extends StatefulWidget {
  const OttfoxWorkspaceScreen({super.key});

  static const String initialUrl = 'https://ottfox.net/es/iptv-playlist-editor/';

  @override
  State<OttfoxWorkspaceScreen> createState() => _OttfoxWorkspaceScreenState();
}

class _OttfoxWorkspaceScreenState extends State<OttfoxWorkspaceScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ottfoxBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text(
          'OTTFOX · EDITOR IPTV',
          style: TextStyle(
            color: _ottfoxCyan,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        leading: IconButton(
          tooltip: 'Volver al centro IPTV',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: _ottfoxCyan),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Recargar OTTFOX',
            onPressed: () => _controller?.reload(),
            icon: const Icon(Icons.refresh_rounded, color: _ottfoxCyan),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_progress < 1)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              minHeight: 2,
              color: _ottfoxCyan,
              backgroundColor: _ottfoxPanel,
            ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: _ottfoxPanel,
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
              ),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(OttfoxWorkspaceScreen.initialUrl),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                supportZoom: true,
                allowsBackForwardNavigationGestures: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onLoadStart: (controller, url) {
                if (!mounted) return;
                setState(() {
                  _progress = 0;
                  _error = null;
                });
              },
              onProgressChanged: (controller, progress) {
                if (!mounted) return;
                setState(() => _progress = progress / 100);
              },
              onLoadStop: (controller, url) async {
                if (!mounted) return;
                setState(() {
                  _progress = 1;
                  _error = null;
                });
              },
              onReceivedError: (controller, request, error) {
                if (!mounted || !request.isForMainFrame) return;
                setState(() {
                  _error = 'No se pudo cargar OTTFOX. Comprueba la conexión y pulsa Recargar.';
                  _progress = 1;
                });
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            decoration: const BoxDecoration(
              color: _ottfoxPanel,
              border: Border(top: BorderSide(color: Color(0xFF123D65))),
            ),
            child: const Text(
              'Prepara tu lista en OTTFOX y copia o exporta el resultado en formato M3U. '
              'Después vuelve al Centro IPTV y pulsa «Importar lista copiada». '
              'OTTFOX no suministra canales ni transmisiones.',
              style: TextStyle(
                color: _ottfoxMuted,
                fontSize: 10,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
