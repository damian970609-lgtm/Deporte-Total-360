import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'automatic_live_service.dart';

const Color _ottfoxBg = Color(0xFF030814);
const Color _ottfoxPanel = Color(0xFF071326);
const Color _ottfoxCyan = Color(0xFF00E5FF);
const Color _ottfoxMuted = Color(0xFFA9BDD6);

/// Lee únicamente la biblioteca local del OTTFOX abierto en este WebView.
/// No realiza peticiones a servidores externos ni intenta acceder al Chrome
/// instalado fuera de la aplicación.
const String _ottfoxLibraryExportScript = r'''
(async () => {
  const found = [];
  const seenM3u = new Set();
  const epgUrls = new Set();
  const playlistUrls = new Set();
  const visited = new WeakSet();
  let totalChars = 0;

  const isHttp = value => typeof value === 'string' && /^https?:\/\//i.test(value.trim());
  const field = (object, names) => {
    if (!object || typeof object !== 'object') return '';
    const entries = Object.entries(object);
    for (const wanted of names) {
      const item = entries.find(([key]) => key.toLowerCase().replace(/[_-]/g, '') === wanted);
      if (item && item[1] != null) {
        const value = item[1];
        if (typeof value === 'string' || typeof value === 'number') return String(value).trim();
        if (value && typeof value === 'object' && typeof value.href === 'string') return value.href.trim();
      }
    }
    return '';
  };

  const addEpg = (key, value) => {
    if (!/(epg|xmltv|guide|tvguide)/i.test(key)) return;
    const values = Array.isArray(value) ? value : [value];
    for (const item of values) {
      if (isHttp(item)) epgUrls.add(item.trim());
    }
  };

  const addPlaylistUrl = value => {
    if (isHttp(value) && playlistUrls.size < 60) {
      playlistUrls.add(value.trim());
    }
  };

  const addM3u = (name, text) => {
    if (typeof text !== 'string') return;
    const body = text.trim();
    if (!/^#EXTM3U/i.test(body) || body.length < 20 || body.length > 3 * 1024 * 1024) return;
    if (seenM3u.has(body) || found.length >= 30 || totalChars + body.length > 12 * 1024 * 1024) return;
    seenM3u.add(body);
    totalChars += body.length;
    found.push({name: String(name || ('Lista OTTFOX ' + (found.length + 1))).slice(0, 100), m3u: body});
    const header = body.split(/\r?\n/).find(line => /^#EXTM3U/i.test(line)) || '';
    const matches = header.matchAll(/(?:url-tvg|x-tvg-url)\s*=\s*["']([^"']+)["']/ig);
    for (const match of matches) {
      for (const url of (match[1] || '').split(/[;,\s]+/)) {
        if (isHttp(url)) epgUrls.add(url.trim());
      }
    }
  };

  const rowsToM3u = (rows, label) => {
    if (!Array.isArray(rows)) return;
    const channels = [];
    for (const row of rows) {
      if (!row || typeof row !== 'object' || Array.isArray(row)) continue;
      const url = field(row, ['url', 'streamurl', 'stream', 'src', 'sourceurl', 'playurl', 'link', 'uri']);
      const name = field(row, ['name', 'title', 'channel', 'label', 'displayname', 'tvgname']);
      if (!isHttp(url) || !name) continue;
      const id = field(row, ['tvgid', 'channelid']);
      const group = field(row, ['grouptitle', 'group', 'category']);
      const logo = field(row, ['tvglogo', 'logo', 'icon', 'image']);
      const esc = value => String(value || '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/[\r\n]/g, ' ').trim();
      const attrs = [
        id ? 'tvg-id="' + esc(id) + '"' : '',
        logo ? 'tvg-logo="' + esc(logo) + '"' : '',
        group ? 'group-title="' + esc(group) + '"' : ''
      ].filter(Boolean).join(' ');
      channels.push('#EXTINF:-1' + (attrs ? ' ' + attrs : '') + ',' + esc(name) + '\n' + url.trim());
    }
    if (channels.length) addM3u(label, '#EXTM3U\n' + channels.join('\n') + '\n');
  };

  const walk = (value, path, depth) => {
    if (depth > 9 || found.length >= 30 || totalChars >= 12 * 1024 * 1024) return;
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (/^#EXTM3U/i.test(trimmed)) {
        addM3u(path, trimmed);
        return;
      }
      if ((trimmed.startsWith('{') || trimmed.startsWith('[')) && trimmed.length < 12 * 1024 * 1024) {
        try { walk(JSON.parse(trimmed), path, depth + 1); } catch (_) {}
      }
      return;
    }
    if (!value || typeof value !== 'object' || visited.has(value)) return;
    visited.add(value);

    const explicitPlaylistUrl = field(value, ['playlisturl', 'm3uurl', 'playlisturi', 'm3uuri']);
    if (explicitPlaylistUrl) addPlaylistUrl(explicitPlaylistUrl);

    if (Array.isArray(value)) {
      rowsToM3u(value, path);
      for (let index = 0; index < value.length; index++) walk(value[index], path + '[' + index + ']', depth + 1);
      return;
    }

    for (const [key, item] of Object.entries(value)) {
      addEpg(key, item);
      if (/(playlist|m3u)(url|uri|source)?/i.test(key)) addPlaylistUrl(item);
      walk(item, path + '/' + key, depth + 1);
    }
  };

  for (const store of [window.localStorage, window.sessionStorage]) {
    try {
      for (let index = 0; index < store.length; index++) {
        const key = store.key(index) || ('entry-' + index);
        walk(store.getItem(key), 'OTTFOX/' + key, 0);
      }
    } catch (_) {}
  }

  try {
    if (window.indexedDB && typeof indexedDB.databases === 'function') {
      const databases = await indexedDB.databases();
      for (const metadata of databases.slice(0, 12)) {
        if (!metadata || !metadata.name) continue;
        try {
          const db = await new Promise((resolve, reject) => {
            const request = indexedDB.open(metadata.name);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
            request.onblocked = () => reject(new Error('IndexedDB blocked'));
          });
          for (const storeName of Array.from(db.objectStoreNames).slice(0, 20)) {
            try {
              const records = await new Promise((resolve, reject) => {
                const transaction = db.transaction(storeName, 'readonly');
                const request = transaction.objectStore(storeName).getAll();
                request.onsuccess = () => resolve(request.result || []);
                request.onerror = () => reject(request.error);
              });
              walk(records, 'OTTFOX/IndexedDB/' + metadata.name + '/' + storeName, 0);
            } catch (_) {}
          }
          db.close();
        } catch (_) {}
      }
    }
  } catch (_) {}

  return JSON.stringify({
    playlists: found,
    playlistUrls: Array.from(playlistUrls).slice(0, 60),
    epgUrls: Array.from(epgUrls).slice(0, 40)
  });
})()
''';

/// OTTFOX integrado a pantalla completa. Después de cargar la página, sincroniza
/// gradualmente las listas que OTTFOX haya guardado en el almacenamiento local
/// de este mismo WebView con el catálogo nativo de Deporte Total 360°.
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
  String _syncStatus = '';
  bool _syncing = false;

  void _setSyncStatus(String value) {
    if (!mounted) return;
    setState(() => _syncStatus = value);
  }

  List<String> _epgUrlsFromM3u(String text) {
    final header = text
        .split(RegExp(r'[\r\n]'))
        .map((line) => line.trim())
        .firstWhere(
          (line) => line.toUpperCase().startsWith('#EXTM3U'),
          orElse: () => '',
        );
    if (header.isEmpty) return <String>[];
    final result = <String>{};
    final expression = RegExp(
      r'''(?:url-tvg|x-tvg-url)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final match in expression.allMatches(header)) {
      for (final raw in (match.group(1) ?? '').split(RegExp(r'[;,\s]+'))) {
        final url = raw.trim();
        if (isSafeHttpUrl(url)) result.add(url);
      }
    }
    return result.toList(growable: false);
  }

  Future<void> _syncOttfoxLibrary({
    required InAppWebViewController controller,
    bool manual = false,
  }) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    _setSyncStatus('Buscando listas guardadas en OTTFOX…');

    try {
      final jsResult = await controller.callAsyncJavaScript(
        functionBody: 'return await ' + _ottfoxLibraryExportScript + ';',
      );
      if (jsResult?.error != null) {
        throw FormatException('OTTFOX no pudo leer su biblioteca local: ${jsResult!.error}');
      }
      final raw = jsResult?.value;
      if (raw == null) {
        throw const FormatException('OTTFOX no devolvió su biblioteca local.');
      }
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) {
        throw const FormatException('La biblioteca OTTFOX tiene un formato inesperado.');
      }

      final records = decoded['playlists'];
      final urlRecords = decoded['playlistUrls'];
      final epgRecords = decoded['epgUrls'];
      final candidates = records is List ? records : const <dynamic>[];
      final discoveredPlaylistUrls = <String>{};
      final discoveredEpg = <String>{};
      if (urlRecords is List) {
        for (final value in urlRecords) {
          if (value is String && isSafeHttpUrl(value)) discoveredPlaylistUrls.add(value);
        }
      }
      if (epgRecords is List) {
        for (final value in epgRecords) {
          if (value is String && isSafeHttpUrl(value)) discoveredEpg.add(value);
        }
      }

      final settings = await AutoLiveSettings.load();
      final savedPlaylists = <String>[...settings.localPlaylistTexts];
      final known = savedPlaylists.toSet();
      final playlistUrls = <String>{...settings.playlistUrls, ...discoveredPlaylistUrls};
      final epgUrls = <String>{...settings.epgUrls, ...discoveredEpg};

      if (candidates.isEmpty) {
        if (playlistUrls.join('\n') != settings.playlistUrls.join('\n') ||
            epgUrls.join('\n') != settings.epgUrls.join('\n')) {
          await AutoLiveSettings.save(
            playlistUrl: playlistUrls.join('\n'),
            epgUrl: epgUrls.join('\n'),
            authorizationConfirmed: true,
            playlistText: '',
            playlistTexts: savedPlaylists,
          );
        }
        _setSyncStatus(
          (discoveredPlaylistUrls.isNotEmpty
              ? 'Se añadieron ' + discoveredPlaylistUrls.length.toString() + ' fuente(s) M3U por URL. '
              : 'No se encontraron listas M3U locales en OTTFOX. ') +
          (epgUrls.length > settings.epgUrls.length
              ? 'Se añadieron guías EPG detectadas. '
              : '') +
          'Las fuentes se cargarán gradualmente en el catálogo nativo.',
        );
        if (manual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay listas M3U compatibles guardadas en el OTTFOX integrado.'),
            ),
          );
        }
        return;
      }
      var newPlaylists = 0;
      var totalChannels = 0;
      var skipped = 0;

      for (var index = 0; index < candidates.length; index++) {
        final record = candidates[index];
        if (record is! Map) {
          skipped++;
          continue;
        }
        final name = (record['name'] ?? ('Lista OTTFOX ' + (index + 1).toString())).toString();
        final text = (record['m3u'] ?? '').toString().trim();
        if (text.isEmpty || text.length > 3 * 1024 * 1024 || !text.toUpperCase().startsWith('#EXTM3U')) {
          skipped++;
          continue;
        }
        for (final url in _epgUrlsFromM3u(text)) {
          epgUrls.add(url);
        }
        if (known.contains(text)) {
          _setSyncStatus('Revisando biblioteca OTTFOX: ' + (index + 1).toString() + ' de ' + candidates.length.toString());
          continue;
        }

        _setSyncStatus('Analizando lista ' + (index + 1).toString() + ' de ' + candidates.length.toString() + ': ' + name);
        final channels = await Isolate.run(
          () => AutomaticLiveService.parseM3u(
            text,
            sourceUrl: 'OTTFOX · $name',
          ),
        );
        if (channels.isEmpty) {
          skipped++;
          continue;
        }

        savedPlaylists.add(text);
        known.add(text);
        totalChannels += channels.length;
        newPlaylists++;

        // Guarda una lista cada vez. Si una lista posterior falla, las
        // anteriores ya quedan disponibles en la búsqueda automática.
        await AutoLiveSettings.save(
          playlistUrl: playlistUrls.join('\n'),
          epgUrl: epgUrls.join('\n'),
          authorizationConfirmed: true,
          playlistText: '',
          playlistTexts: savedPlaylists,
        );
        if (!mounted) return;
        _setSyncStatus(
          'Importadas ' + newPlaylists.toString() + ' listas nuevas · ' +
          totalChannels.toString() + ' canales. Procesando ' +
          (index + 1).toString() + ' de ' + candidates.length.toString() + '…',
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }

      if (playlistUrls.join('\n') != settings.playlistUrls.join('\n') ||
          epgUrls.join('\n') != settings.epgUrls.join('\n')) {
        // Guarda también las guías detectadas cuando todas las listas ya
        // estaban importadas y no hubo ninguna M3U nueva que persistir.
        await AutoLiveSettings.save(
          playlistUrl: playlistUrls.join('\n'),
          epgUrl: epgUrls.join('\n'),
          authorizationConfirmed: true,
          playlistText: '',
          playlistTexts: savedPlaylists,
        );
      }

      if (newPlaylists == 0) {
        _setSyncStatus(
          'Biblioteca revisada: no hay listas nuevas compatibles. ' +
          (skipped > 0 ? skipped.toString() + ' entrada(s) se omitieron.' : 'Las listas existentes ya están sincronizadas.'),
        );
      } else {
        _setSyncStatus(
          'Sincronización terminada: ' + newPlaylists.toString() +
          ' listas nuevas y ' + totalChannels.toString() +
          ' canales guardados para la carga automática.',
        );
      }
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newPlaylists == 0
                  ? 'No se encontraron listas nuevas para importar.'
                  : 'OTTFOX: ' + newPlaylists.toString() + ' listas y ' + totalChannels.toString() + ' canales añadidos.',
            ),
          ),
        );
      }
    } catch (error) {
      _setSyncStatus('No se pudo sincronizar la biblioteca OTTFOX: $error');
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar las listas OTTFOX: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

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
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: _ottfoxCyan),
        ),
        actions: <Widget>[
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(strokeWidth: 2, color: _ottfoxCyan),
              ),
            )
          else
            IconButton(
              tooltip: 'Importar biblioteca de OTTFOX',
              onPressed: _controller == null
                  ? null
                  : () => _syncOttfoxLibrary(
                        controller: _controller!,
                        manual: true,
                      ),
              icon: const Icon(Icons.sync_rounded, color: _ottfoxCyan),
            ),
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
          if (_syncStatus.isNotEmpty)
            Container(
              width: double.infinity,
              color: _ottfoxPanel,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                _syncStatus,
                style: const TextStyle(
                  color: _ottfoxMuted,
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
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
                await Future<void>.delayed(const Duration(milliseconds: 450));
                if (mounted) {
                  await _syncOttfoxLibrary(controller: controller);
                }
              },
              onReceivedError: (controller, request, error) {
                if (!mounted || request.isForMainFrame != true) return;
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
              'OTTFOX abre directamente dentro de Deporte Total 360°. '
              'Las listas guardadas aquí se incorporan una por una al catálogo nativo. '
              'La biblioteca de Chrome no se comparte automáticamente con este WebView.',
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
