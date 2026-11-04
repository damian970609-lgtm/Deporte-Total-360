import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'automatic_live_service.dart';
import 'live_channels_screen.dart';

const Color _iptvBg = Color(0xFF030814);
const Color _iptvPanel = Color(0xFF071326);
const Color _iptvPanel2 = Color(0xFF0B1B31);
const Color _iptvLine = Color(0xFF123D65);
const Color _iptvCyan = Color(0xFF00E5FF);
const Color _iptvGreen = Color(0xFF39FF9C);
const Color _iptvPink = Color(0xFFFF28CF);
const Color _iptvYellow = Color(0xFFFFD600);
const Color _iptvMuted = Color(0xFFA9BDD6);

const String _manualPlaylistUrlsKey = 'dt360_secret_iptv_playlist_urls_v1';
const String _manualPlaylistTextsKey = 'dt360_secret_iptv_playlist_texts_v1';
const String _manualEpgUrlsKey = 'dt360_secret_iptv_epg_urls_v1';
const String _manualFavoriteUrlsKey = 'dt360_secret_iptv_favorite_urls_v1';
const String _sharedFavoriteUrlsKey = 'dt360_iptv_favorite_urls_v1';

class IptvSourcesScreen extends StatefulWidget {
  const IptvSourcesScreen({
    super.key,
    this.manualOnly = false,
    this.parseInBackground = true,
  });

  /// Usa una biblioteca independiente sin listas públicas precargadas.
  final bool manualOnly;

  /// Permite pruebas deterministas sin aislar el análisis de listas pequeñas.
  /// En producción permanece activado para no bloquear la interfaz.
  final bool parseInBackground;

  @override
  State<IptvSourcesScreen> createState() => _IptvSourcesScreenState();
}

class _MergedM3uChannel {
  const _MergedM3uChannel(this.channels);

  final List<M3uChannel> channels;

  M3uChannel get primary => channels.first;
}

class _IptvSourcesScreenState extends State<IptvSourcesScreen> {
  final AutomaticLiveService _service = AutomaticLiveService();
  final TextEditingController _searchController = TextEditingController();

  List<String> _playlistUrls = <String>[];
  List<String> _epgUrls = <String>[];
  String _playlistText = '';
  List<String> _playlistTexts = <String>[];
  List<_MergedM3uChannel> _mergedChannels = <_MergedM3uChannel>[];
  final Set<String> _favoriteUrls = <String>{};
  final List<M3uChannel> _multiViewQueue = <M3uChannel>[];
  bool _showFavoritesOnly = false;
  bool _showAllChannels = false;
  AutoLiveCatalog? _catalog;
  Map<String, List<XmltvProgramme>> _epgIndex = <String, List<XmltvProgramme>>{};
  String _progressMessage = '';
  String? _sourceWarning;
  int _programmeCount = 0;
  int _rawChannelCount = 0;
  bool _loading = true;
  bool _saving = false;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      if (widget.manualOnly) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        setState(() {
          _playlistUrls = (prefs.getStringList(_manualPlaylistUrlsKey) ?? <String>[])
              .where(isSafeHttpUrl)
              .toList(growable: true);
          _epgUrls = (prefs.getStringList(_manualEpgUrlsKey) ?? <String>[])
              .where(isSafeHttpUrl)
              .toList(growable: true);
          _playlistTexts = prefs.getStringList(_manualPlaylistTextsKey) ?? <String>[];
          _favoriteUrls
            ..clear()
            ..addAll(prefs.getStringList(_manualFavoriteUrlsKey) ?? <String>[]);
          _playlistText = '';
          _loading = false;
        });
      } else {
        final settings = await AutoLiveSettings.load();
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        setState(() {
          _favoriteUrls
            ..clear()
            ..addAll(prefs.getStringList(_sharedFavoriteUrlsKey) ?? <String>[]);
          _playlistUrls = List<String>.of(settings.playlistUrls);
          _epgUrls = List<String>.of(settings.epgUrls);
          _playlistText = '';
          _playlistTexts = List<String>.of(settings.localPlaylistTexts);
          _loading = false;
        });
      }
      if (mounted) await _refreshCatalog();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la configuración de listas.';
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (widget.manualOnly) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_manualPlaylistUrlsKey, _playlistUrls);
        await prefs.setStringList(_manualEpgUrlsKey, _epgUrls);
        await prefs.setStringList(_manualPlaylistTextsKey, _playlistTexts);
      } else {
        await AutoLiveSettings.save(
          playlistUrl: _playlistUrls.join('\n'),
          epgUrl: _epgUrls.join('\n'),
          authorizationConfirmed: true,
          playlistText: _playlistText,
          playlistTexts: _playlistTexts,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.manualOnly
                  ? 'Tus listas del reproductor quedaron guardadas.'
                  : 'Listas M3U y guías EPG guardadas.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron guardar las fuentes: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }



  Future<void> _importClipboardPlaylist() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text ?? '';
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El portapapeles está vacío. Copia primero el contenido de una lista M3U.')),
        );
        return;
      }
      await _importPlaylistText(text);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo leer la lista copiada: $error')),
      );
    }
  }

  Future<void> _pastePlaylistText() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _iptvPanel,
        title: const Text(
          'Importar contenido M3U',
          style: TextStyle(color: _iptvCyan, fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 6,
            maxLines: 12,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              hintText: 'Pega aquí el contenido de la lista que comienza con #EXTM3U',
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && mounted) await _importPlaylistText(text);
  }

  List<String> _epgUrlsFromM3uHeader(String text) {
    final header = text
        .split(RegExp(r'[\r\n]'))
        .map((line) => line.trim())
        .firstWhere(
          (line) => line.toUpperCase().startsWith('#EXTM3U'),
          orElse: () => '',
        );
    if (header.isEmpty) return <String>[];
    final found = <String>{};
    final attribute = RegExp(
      r'''(?:url-tvg|x-tvg-url)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final match in attribute.allMatches(header)) {
      for (final raw in (match.group(1) ?? '').split(RegExp(r'[;,\s]+'))) {
        final url = raw.trim();
        if (url.isNotEmpty && isSafeHttpUrl(url)) found.add(url);
      }
    }
    return found.toList(growable: false);
  }

  Future<void> _importPlaylistText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || !text.toUpperCase().startsWith('#EXTM3U')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El contenido no es una lista M3U válida. Debe comenzar con #EXTM3U.')),
      );
      return;
    }
    if (text.length > 3 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La lista supera 3 MB. Divídela en varias listas antes de importarla.')),
      );
      return;
    }

    try {
      final channels = await Isolate.run(
        () => AutomaticLiveService.parseM3u(
          text,
          sourceUrl: 'Lista importada · local',
        ),
      );
      if (!mounted) return;
      if (channels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La M3U no contiene enlaces directos compatibles. Comprueba que tenga URLs HLS (.m3u8), DASH (.mpd), TS o MP4 directas.')),
        );
        return;
      }

      final discoveredEpg = _epgUrlsFromM3uHeader(text);
      var addedEpg = 0;
      setState(() {
        if (!_playlistTexts.contains(text)) _playlistTexts.add(text);
        _playlistText = '';
        for (final url in discoveredEpg) {
          if (!_epgUrls.contains(url)) {
            _epgUrls.add(url);
            addedEpg++;
          }
        }
      });
      await _saveSettings();
      if (mounted) await _refreshCatalog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lista importada: ${channels.length} canales${addedEpg > 0 ? ' y $addedEpg guía(s) EPG añadida(s)' : ''}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar la lista M3U: $error')),
      );
    }
  }

  Future<void> _addSource({required bool epg}) async {
    final controller = TextEditingController();
    var validationError = '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: _iptvPanel,
          title: Text(
            epg ? 'Agregar guía EPG / XMLTV' : 'Agregar lista M3U / M3U8',
            style: const TextStyle(
              color: _iptvCyan,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                minLines: 2,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  labelText: epg
                      ? 'Direcciones de guías EPG (una por línea)'
                      : 'Direcciones de listas M3U (una por línea)',
                  hintText: 'https://servidor-autorizado/lista.m3u\\nhttps://otro-servidor/lista.m3u8',
                  prefixIcon: const Icon(Icons.link_rounded),
                ),
              ),
              if (validationError.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    validationError,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Usa fuentes propias o autorizadas. La aplicación no proporciona canales ni suscripciones.',
                style: const TextStyle(
                  color: _iptvMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final urls = controller.text
                    .split(RegExp(r'[\r\n;]+'))
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toSet()
                    .toList(growable: false);
                final ottfoxPage = urls.any((item) {
                  final host = Uri.tryParse(item)?.host.toLowerCase() ?? '';
                  return host == 'ottfox.net' || host.endsWith('.ottfox.net');
                });
                if (ottfoxPage) {
                  setDialogState(() {
                    validationError =
                        'Ese enlace abre una página web, no un archivo M3U ni una guía EPG. Añade la dirección directa de tu lista o guía.';
                  });
                  return;
                }
                if (urls.isEmpty || !urls.every(isSafeHttpUrl)) {
                  setDialogState(() {
                    validationError =
                        'Revisa las direcciones: cada línea debe ser una URL HTTP o HTTPS válida.';
                  });
                  return;
                }
                Navigator.pop(dialogContext, urls.join('\n'));
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;

    final list = epg ? _epgUrls : _playlistUrls;
    final incoming = value
        .split(RegExp(r'[\r\n;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
    var added = 0;
    setState(() {
      for (final url in incoming) {
        if (isSafeHttpUrl(url) && !list.contains(url)) {
          list.add(url);
          added++;
        }
      }
      _error = null;
    });
    if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se agregaron fuentes nuevas; revisa si ya estaban guardadas.')),
      );
      return;
    }
    await _saveSettings();
    if (mounted) await _refreshCatalog();
    if (mounted && added > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se agregaron $added fuentes correctamente.')),
      );
    }
  }

  Future<void> _removeSource({required bool epg, required int index}) async {
    final list = epg ? _epgUrls : _playlistUrls;
    if (list.length <= 1 && !widget.manualOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            epg
                ? 'Conserva al menos una guía EPG para mantener la programación.'
                : 'Conserva al menos una lista M3U para mantener las señales.',
          ),
        ),
      );
      return;
    }
    setState(() => list.removeAt(index));
    await _saveSettings();
    if (mounted && !epg) await _refreshCatalog();
  }


  Future<void> _moveSource({
    required bool epg,
    required int index,
    required int offset,
  }) async {
    final list = epg ? _epgUrls : _playlistUrls;
    final target = index + offset;
    if (target < 0 || target >= list.length) return;
    setState(() {
      final item = list.removeAt(index);
      list.insert(target, item);
    });
    await _saveSettings();
  }

  String _hostLabel(String value) {
    final uri = Uri.tryParse(value);
    return uri?.host.isNotEmpty == true ? uri!.host : 'Fuente remota';
  }

  Widget _sourceSection({
    required String title,
    required String description,
    required List<String> urls,
    required bool epg,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _iptvPanel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _iptvLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                epg ? Icons.event_note_rounded : Icons.playlist_play_rounded,
                color: epg ? _iptvPink : _iptvCyan,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: epg ? _iptvPink : _iptvCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                urls.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(
              color: _iptvMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < urls.length; index++)
            Container(
              margin: const EdgeInsets.only(top: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _iptvPanel2,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 25,
                    child: Text(
                      (index + 1).toString(),
                      style: const TextStyle(
                        color: _iptvMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _hostLabel(urls[index]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          epg ? 'Guía XMLTV' : 'Lista de canales',
                          style: const TextStyle(
                            color: _iptvMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Subir prioridad',
                    onPressed: index == 0
                        ? null
                        : () => _moveSource(
                              epg: epg,
                              index: index,
                              offset: -1,
                            ),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 19),
                    color: _iptvCyan,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Bajar prioridad',
                    onPressed: index == urls.length - 1
                        ? null
                        : () => _moveSource(
                              epg: epg,
                              index: index,
                              offset: 1,
                            ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
                    color: _iptvCyan,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Eliminar fuente',
                    onPressed: () => _removeSource(epg: epg, index: index),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: _iptvPink,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : () => _addSource(epg: epg),
              icon: const Icon(Icons.add_rounded),
              label: Text(epg ? 'AGREGAR GUÍA EPG' : 'AGREGAR LISTA M3U'),
              style: OutlinedButton.styleFrom(
                foregroundColor: epg ? _iptvPink : _iptvCyan,
                side: BorderSide(color: epg ? _iptvPink : _iptvCyan),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_MergedM3uChannel> _groupChannels(List<M3uChannel> channels) {
    final grouped = <String, List<M3uChannel>>{};
    for (final channel in channels) {
      final id = AutomaticLiveService.normalizeText(channel.tvgId);
      final displayName = channel.tvgName.isNotEmpty
          ? channel.tvgName
          : channel.name;
      final normalizedName = AutomaticLiveService.normalizeText(displayName);
      final normalizedGroup = AutomaticLiveService.normalizeText(channel.group);
      final key = id.isNotEmpty
          ? 'id:$id'
          : 'name:$normalizedName|$normalizedGroup';
      if (normalizedName.isEmpty && id.isEmpty) continue;
      final alternatives = grouped.putIfAbsent(key, () => <M3uChannel>[]);
      if (!alternatives.any((item) => item.url == channel.url)) {
        alternatives.add(channel);
      }
    }

    final result = grouped.values
        .map((items) => _MergedM3uChannel(List<M3uChannel>.unmodifiable(items)))
        .toList(growable: false)
      ..sort((a, b) => a.primary.name.toLowerCase().compareTo(
            b.primary.name.toLowerCase(),
          ));
    return result;
  }

  Future<void> _refreshCatalog() async {
    if (_refreshing) return;
    if (_playlistUrls.isEmpty &&
        _playlistTexts.isEmpty &&
        _playlistText.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _catalog = null;
        _mergedChannels = <_MergedM3uChannel>[];
        _epgIndex = <String, List<XmltvProgramme>>{};
        _programmeCount = 0;
        _rawChannelCount = 0;
        _sourceWarning = null;
        _error = null;
        _progressMessage = '';
      });
      return;
    }
    setState(() {
      _refreshing = true;
      _error = null;
      _progressMessage = 'Preparando las fuentes…';
      _sourceWarning = null;
    });
    final failedSources = <String>{};
    try {
      final catalog = await _service.loadCatalog(
        playlistUrl: _playlistUrls.join('\n'),
        epgUrl: _epgUrls.join('\n'),
        playlistText: _playlistText,
        playlistTexts: _playlistTexts,
        forceRefresh: true,
        downloadBatchSize: 4,
        batchPause: widget.parseInBackground
            ? const Duration(milliseconds: 100)
            : Duration.zero,
        parseInBackground: widget.parseInBackground,
        maxPlaylistBytes: 8 * 1024 * 1024,
        maxEpgBytes: 12 * 1024 * 1024,
        onChannelsLoaded: (channels) {
          if (!mounted) return;
          final partialCatalog = AutoLiveCatalog(
            channels: channels,
            programmes: const <XmltvProgramme>[],
          );
          setState(() {
            _catalog = partialCatalog;
            _rawChannelCount = channels.length;
            _mergedChannels = _groupChannels(channels);
          });
        },
        onSourceError: (url, _) => failedSources.add(_hostLabel(url)),
        onProgress: (phase, completed, total) {
          if (!mounted) return;
          setState(() {
            _progressMessage = phase == 'LOCAL'
                ? 'Analizando listas guardadas: $completed de $total'
                : phase == 'M3U'
                    ? 'Extrayendo listas M3U: $completed de $total'
                    : 'Procesando guías EPG: $completed de $total';
          });
        },
      );
      final grouped = _groupChannels(catalog.channels);
      final epgIndex = _buildEpgIndex(catalog.programmes);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _epgIndex = epgIndex;
        _rawChannelCount = catalog.channels.length;
        _programmeCount = catalog.programmes.length;
        _mergedChannels = grouped;
        _sourceWarning = failedSources.isEmpty
            ? null
            : '${failedSources.length} fuente(s) no respondieron o no contienen enlaces compatibles: ${failedSources.take(3).join(', ')}';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _sourceWarning = failedSources.isEmpty
              ? null
              : 'Fuentes con problemas: ${failedSources.take(3).join(', ')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _progressMessage = '';
        });
      }
    }
  }

  Future<void> _copyCombinedPlaylist() async {
    final catalog = _catalog;
    if (catalog == null || catalog.channels.isEmpty) return;
    final merged = AutomaticLiveService.buildMergedM3u(
      catalog,
      epgUrls: _epgUrls,
    );
    try {
      await Clipboard.setData(ClipboardData(text: merged));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lista combinada copiada: ${catalog.channels.length} señales únicas y ${_epgUrls.length} referencias EPG.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo copiar la lista combinada: $error')),
      );
    }
  }

  Map<String, List<XmltvProgramme>> _buildEpgIndex(
    List<XmltvProgramme> programmes,
  ) {
    final index = <String, List<XmltvProgramme>>{};
    for (final programme in programmes) {
      final id = AutomaticLiveService.normalizeText(programme.channelId);
      final name = AutomaticLiveService.normalizeText(programme.channelName);
      if (id.isNotEmpty) index.putIfAbsent(id, () => <XmltvProgramme>[]).add(programme);
      if (name.isNotEmpty && name != id) {
        index.putIfAbsent(name, () => <XmltvProgramme>[]).add(programme);
      }
    }
    for (final rows in index.values) {
      rows.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }
    return index;
  }

  String _programmeLabel(M3uChannel channel) {
    final keys = <String>[
      channel.tvgId,
      channel.tvgName,
      channel.name,
    ].map(AutomaticLiveService.normalizeText).where((key) => key.isNotEmpty);
    List<XmltvProgramme>? matching;
    for (final key in keys) {
      final rows = _epgIndex[key];
      if (rows != null && rows.isNotEmpty) {
        matching = rows;
        break;
      }
    }
    if (matching == null) return '';
    final now = DateTime.now();
    XmltvProgramme? current;
    XmltvProgramme? next;
    for (final programme in matching) {
      if (!now.isBefore(programme.startsAt) && now.isBefore(programme.endsAt)) {
        current = programme;
        break;
      }
      if (programme.startsAt.isAfter(now)) {
        next = programme;
        break;
      }
    }
    String timeLabel(DateTime value) =>
        "${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}";
    if (current != null) return 'AHORA ${timeLabel(current.startsAt)} · ${current.title}';
    if (next != null) return 'SIGUE ${timeLabel(next.startsAt)} · ${next.title}';
    return '';
  }

  void _addToMultiview(M3uChannel channel) {
    if (_multiViewQueue.any((item) => item.url == channel.url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese canal ya está en la multivista.')),
      );
      return;
    }
    if (_multiViewQueue.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La multivista admite un máximo de ocho señales.')),
      );
      return;
    }
    setState(() => _multiViewQueue.add(channel));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${channel.name} añadido a multivista (${_multiViewQueue.length}/8).')),
    );
  }

  Future<void> _playMultiView() async {
    if (_multiViewQueue.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerGridScreen(
          sources: _multiViewQueue.map((channel) => LivePlayerSource(
            title: channel.name,
            url: channel.url,
            subtitle: channel.group.isEmpty ? 'Canal IPTV autorizado' : channel.group,
          )).toList(growable: false),
        ),
      ),
    );
  }

  bool _isFavorite(M3uChannel channel) => _favoriteUrls.contains(channel.url);

  Future<void> _toggleFavorite(M3uChannel channel) async {
    final isRemoving = _favoriteUrls.remove(channel.url);
    if (!isRemoving) _favoriteUrls.add(channel.url);
    if (mounted) setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        widget.manualOnly ? _manualFavoriteUrlsKey : _sharedFavoriteUrlsKey,
        _favoriteUrls.toList(growable: false),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRemoving
                ? '${channel.name} eliminado de favoritos.'
                : '${channel.name} agregado a favoritos.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (isRemoving) {
        _favoriteUrls.add(channel.url);
      } else {
        _favoriteUrls.remove(channel.url);
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el favorito: $error')),
      );
    }
  }

  Future<void> _copyChannelUrl(M3uChannel channel) async {
    try {
      await Clipboard.setData(ClipboardData(text: channel.url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('URL de ${channel.name} copiada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo copiar la URL: $error')),
      );
    }
  }

  List<_MergedM3uChannel> get _filteredChannels {
    final query = AutomaticLiveService.normalizeText(_searchController.text);
    return _mergedChannels.where((entry) {
      if (_showFavoritesOnly &&
          !entry.channels.any((channel) => _favoriteUrls.contains(channel.url))) {
        return false;
      }
      if (query.isEmpty) return true;
      return entry.channels.any((channel) =>
          AutomaticLiveService.normalizeText(
            channel.name + ' ' + channel.tvgName + ' ' +
                channel.tvgId + ' ' + channel.group,
          ).contains(query));
    }).toList(growable: false);
  }

  int _qualityRank(M3uChannel channel) {
    final text = AutomaticLiveService.normalizeText(
      channel.name + ' ' + channel.tvgName,
    );
    if (text.contains('4k') || text.contains('uhd') || text.contains('2160')) {
      return 500;
    }
    if (text.contains('1080') || text.contains('fhd')) return 400;
    if (text.contains('720') || text.contains('hd')) return 300;
    if (text.contains('576') || text.contains('480')) return 200;
    return 100;
  }

  String _qualityLabel(M3uChannel channel) {
    final rank = _qualityRank(channel);
    if (rank >= 500) return '4K';
    if (rank >= 400) return '1080p';
    if (rank >= 300) return 'HD';
    return 'Directo';
  }

  Future<void> _showAlternatives(_MergedM3uChannel entry) async {
    final sorted = List<M3uChannel>.of(entry.channels)
      ..sort((a, b) => _qualityRank(b).compareTo(_qualityRank(a)));
    final selected = await showModalBottomSheet<M3uChannel>(
      context: context,
      backgroundColor: _iptvPanel,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.primary.name,
                style: const TextStyle(
                  color: _iptvCyan,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                sorted.length.toString() + ' fuente(s) disponibles',
                style: const TextStyle(color: _iptvMuted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: _iptvLine, height: 1),
                  itemBuilder: (context, index) {
                    final channel = sorted[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        index == 0
                            ? Icons.verified_rounded
                            : Icons.swap_horiz_rounded,
                        color: index == 0 ? _iptvGreen : _iptvCyan,
                      ),
                      title: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _hostLabel(channel.sourceUrl) + ' · ' +
                            _qualityLabel(channel),
                        style: const TextStyle(
                          color: _iptvMuted,
                          fontSize: 10,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Copiar URL directa',
                        onPressed: () => _copyChannelUrl(channel),
                        icon: const Icon(Icons.copy_rounded),
                        color: _iptvCyan,
                        visualDensity: VisualDensity.compact,
                      ),
                      onTap: () => Navigator.pop(sheetContext, channel),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await _playChannel(selected);
  }

  Future<void> _playChannel(M3uChannel channel) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerGridScreen(
          sources: <LivePlayerSource>[
            LivePlayerSource(
              title: channel.name,
              url: channel.url,
              subtitle: channel.group.isEmpty
                  ? 'Canal IPTV autorizado'
                  : channel.group,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredChannels;
    final favoriteCount = _mergedChannels
        .where((entry) => entry.channels.any(_isFavorite))
        .length;
    final visibleChannels = _showAllChannels
        ? filtered
        : filtered.take(250).toList(growable: false);
    return Scaffold(
      backgroundColor: _iptvBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text(
          'REPRODUCTOR IPTV · LISTAS Y CANALES',
          style: TextStyle(
            color: _iptvCyan,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar catálogo unificado',
            onPressed: _refreshing ? null : _refreshCatalog,
            icon: Icon(
              Icons.refresh_rounded,
              color: _refreshing ? _iptvMuted : _iptvCyan,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _iptvCyan),
            )
          : ListView(
              padding: const EdgeInsets.all(14),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _iptvPanel2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _iptvCyan.withAlpha(150)),
                  ),
                  child: Text(
                    widget.manualOnly
                        ? 'Agrega manualmente tus listas IPTV. Se guardan en este dispositivo y no se carga ninguna lista pública automáticamente. Busca tus canales y reprodúcelos aquí mismo con el reproductor integrado, controles de calidad y pantalla completa.'
                        : 'Gestiona listas M3U/M3U8 y guías XMLTV/EPG desde un único centro. El extractor combina fuentes, elimina duplicados y conserva alternativas. El reproductor nativo abre canales directos compatibles con controles de calidad y pantalla completa; los ocho espacios multivista de la app se mantienen. El análisis pesado se procesa fuera de la interfaz.',
                    style: const TextStyle(
                      color: _iptvMuted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(13),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _iptvPanel2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _iptvGreen.withAlpha(135)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'IMPORTAR TUS LISTAS M3U',
                        style: TextStyle(
                          color: _iptvGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .35,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.manualOnly
                            ? 'Añade una URL M3U/M3U8 o pega el contenido de una lista que ya tengas. Puedes agregar varias, guardarlas y reproducir sus canales en el reproductor integrado.'
                            : 'Las listas públicas se descargan automáticamente al abrir esta pantalla. También puedes añadir direcciones M3U/M3U8 propias o importar contenido copiado; los canales aparecerán en el catálogo nativo.',
                        style: const TextStyle(color: _iptvMuted, fontSize: 11, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _importClipboardPlaylist,
                            icon: const Icon(Icons.playlist_add_check_rounded),
                            label: const Text('IMPORTAR LISTA COPIADA'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _iptvGreen,
                              foregroundColor: _iptvBg,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pastePlaylistText,
                            icon: const Icon(Icons.content_paste_rounded),
                            label: const Text('PEGAR CONTENIDO M3U'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _iptvPink,
                              side: const BorderSide(color: _iptvPink),
                            ),
                          ),
                        ],
                      ),
                      if (_playlistTexts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Listas guardadas en este dispositivo: \${_playlistTexts.length}',
                            style: const TextStyle(color: _iptvGreen, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
                _sourceSection(
                  title: 'LISTAS DE CANALES M3U / M3U8',
                  description: widget.manualOnly
                      ? 'Tus listas añadidas manualmente. Puedes cambiar su prioridad o eliminar cualquiera cuando quieras.'
                      : 'Las listas se descargan en lotes pequeños. Puedes cambiar el orden de prioridad o quitar una fuente sin borrar las demás.',
                  urls: _playlistUrls,
                  epg: false,
                ),
                _sourceSection(
                  title: 'GUÍAS DE PROGRAMACIÓN EPG / XMLTV',
                  description:
                      'Se fusionan varias guías. Una fuente caída no impide utilizar las otras guías que respondan correctamente.',
                  urls: _epgUrls,
                  epg: true,
                ),
                if (_refreshing)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _iptvPanel2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _iptvCyan.withAlpha(120)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _iptvCyan,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            _progressMessage,
                            style: const TextStyle(
                              color: _iptvMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(13),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _iptvPanel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _iptvLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'CATÁLOGO UNIFICADO',
                        style: TextStyle(
                          color: _iptvGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.manualOnly
                            ? 'Combina únicamente las listas que agregaste. Los canales repetidos se agrupan y conservan sus alternativas. La guía EPG es opcional.'
                            : 'Descarga y combina todas las listas. Las guías EPG se incorporan cuando responden; los canales no desaparecen si una guía falla. Los canales repetidos se agrupan por tvg-id o nombre y conservan sus alternativas.',
                        style: const TextStyle(
                          color: _iptvMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _Metric(
                              value: _rawChannelCount.toString(),
                              label: 'señales',
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              value: _mergedChannels.length.toString(),
                              label: 'canales únicos',
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              value: (_rawChannelCount -
                                      _mergedChannels.length)
                                  .clamp(0, 1 << 30)
                                  .toString(),
                              label: 'alternativas',
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              value: _programmeCount.toString(),
                              label: 'programas EPG',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _refreshing ? null : _refreshCatalog,
                          icon: _refreshing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded),
                          label: Text(
                            _refreshing
                                ? 'CARGANDO TUS LISTAS…'
                                : widget.manualOnly
                                    ? 'CARGAR MIS LISTAS Y CANALES'
                                    : 'EXTRAER Y FUSIONAR TODAS LAS FUENTES',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _iptvGreen,
                            foregroundColor: _iptvBg,
                          ),
                        ),
                      ),
                      if (_catalog != null) ...<Widget>[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _copyCombinedPlaylist,
                            icon: const Icon(Icons.copy_all_rounded),
                            label: const Text('COPIAR LISTA M3U + REFERENCIAS EPG'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _iptvCyan,
                              side: const BorderSide(color: _iptvCyan),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_sourceWarning != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2412),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orangeAccent.withAlpha(100)),
                    ),
                    child: Text(
                      _sourceWarning!,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
                    ),
                  ),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(11),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF321421),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (_mergedChannels.isEmpty && !_refreshing && _error == null)
                  Container(
                    padding: const EdgeInsets.all(13),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _iptvPanel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _iptvLine),
                    ),
                    child: const Text(
                      'No se encontraron canales en las fuentes actuales. Comprueba la conexión o agrega una URL M3U autorizada y vuelve a actualizar.',
                      style: TextStyle(color: _iptvMuted, fontSize: 11, height: 1.4),
                    ),
                  ),
                if (_mergedChannels.isNotEmpty) ...<Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        avatar: const Icon(Icons.grid_view_rounded, size: 16),
                        label: Text('TODOS LOS CANALES (${_mergedChannels.length})'),
                        selected: !_showFavoritesOnly,
                        onSelected: (_) => setState(() => _showFavoritesOnly = false),
                        selectedColor: _iptvCyan.withAlpha(35),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      ChoiceChip(
                        avatar: Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: _showFavoritesOnly ? _iptvBg : _iptvYellow,
                        ),
                        label: Text('FAVORITOS ($favoriteCount)'),
                        selected: _showFavoritesOnly,
                        onSelected: (_) => setState(() => _showFavoritesOnly = true),
                        selectedColor: _iptvGreen,
                        labelStyle: TextStyle(
                          color: _showFavoritesOnly ? _iptvBg : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Buscar canal, categoría o tvg-id',
                      suffixIcon: IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'MULTIVISTA ${_multiViewQueue.length}/8',
                          style: const TextStyle(
                            color: _iptvGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _multiViewQueue.isEmpty ? null : _playMultiView,
                        icon: const Icon(Icons.grid_view_rounded, size: 17),
                        label: const Text('REPRODUCIR SELECCIÓN'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _iptvGreen,
                          side: const BorderSide(color: _iptvGreen),
                        ),
                      ),
                    ],
                  ),
                  if (_multiViewQueue.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      children: _multiViewQueue.map((channel) => Chip(
                        label: Text(
                          channel.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                        onDeleted: () => setState(() => _multiViewQueue.remove(channel)),
                        visualDensity: VisualDensity.compact,
                      )).toList(growable: false),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _showFavoritesOnly
                        ? 'MIS CANALES FAVORITOS (' + filtered.length.toString() + ')'
                        : 'TODOS LOS CANALES (' + filtered.length.toString() + ')',
                    style: const TextStyle(
                      color: _iptvCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (_showFavoritesOnly && filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        _favoriteUrls.isEmpty
                            ? 'Todavía no tienes favoritos. Pulsa la estrella de un canal para guardarlo aquí.'
                            : 'Ningún favorito coincide con tu búsqueda actual.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _iptvMuted, fontSize: 11, height: 1.45),
                      ),
                    ),
                  for (final entry in visibleChannels)
                    Card(
                      color: _iptvPanel,
                      margin: const EdgeInsets.only(bottom: 5),
                      child: ListTile(
                        dense: true,
                        leading: entry.primary.logo.isEmpty
                            ? const Icon(Icons.live_tv_rounded, color: _iptvCyan)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.network(
                                  entry.primary.logo,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.live_tv_rounded,
                                    color: _iptvCyan,
                                  ),
                                ),
                              ),
                        title: Text(
                          entry.primary.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          <String>[
                            (entry.primary.group.isEmpty
                                    ? 'Deportes / TV'
                                    : entry.primary.group) +
                                ' · ' +
                                entry.channels.length.toString() +
                                ' fuente(s)',
                            if (_programmeLabel(entry.primary).isNotEmpty)
                              _programmeLabel(entry.primary),
                          ].join('\n'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _iptvMuted,
                            fontSize: 10,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: _isFavorite(entry.primary)
                                  ? 'Quitar de favoritos'
                                  : 'Agregar a favoritos',
                              onPressed: () => _toggleFavorite(entry.primary),
                              icon: Icon(
                                _isFavorite(entry.primary)
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                              ),
                              color: _isFavorite(entry.primary) ? _iptvYellow : _iptvMuted,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(width: 32, height: 36),
                            ),
                            IconButton(
                              tooltip: 'Copiar URL del canal',
                              onPressed: () => _copyChannelUrl(entry.primary),
                              icon: const Icon(Icons.link_rounded),
                              color: _iptvCyan,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(width: 32, height: 36),
                            ),
                            IconButton(
                              tooltip: 'Reproducir con el reproductor nativo',
                              onPressed: () => _playChannel(entry.primary),
                              icon: const Icon(Icons.play_circle_fill_rounded),
                              color: _iptvGreen,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(width: 32, height: 36),
                            ),
                            IconButton(
                              tooltip: 'Añadir a multivista',
                              onPressed: () => _addToMultiview(entry.primary),
                              icon: const Icon(Icons.add_to_photos_rounded),
                              color: _iptvCyan,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(width: 32, height: 36),
                            ),
                          ],
                        ),
                        onTap: () => _showAlternatives(entry),
                      ),
                    ),
                  if (filtered.length > 250)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showAllChannels = !_showAllChannels),
                        icon: Icon(
                          _showAllChannels
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.expand_more_rounded,
                        ),
                        label: Text(
                          _showAllChannels
                              ? 'MOSTRAR MENOS CANALES'
                              : 'VER TODOS LOS CANALES (${filtered.length})',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
                        ),
                        style: TextButton.styleFrom(foregroundColor: _iptvCyan),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Compatibilidad actual: listas M3U/M3U8 y guías XMLTV/EPG por URL. El reproductor integrado utiliza los formatos directos que ya admite Deporte Total 360°. No se extraen enlaces de páginas web, no se elude DRM ni se omiten credenciales o restricciones del proveedor.',
                  style: TextStyle(
                    color: _iptvMuted,
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _iptvCyan,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _iptvMuted,
              fontSize: 8,
            ),
          ),
        ],
      );
}
