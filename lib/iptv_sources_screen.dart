import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'automatic_live_service.dart';
import 'live_channels_screen.dart';

const Color _iptvBg = Color(0xFF030814);
const Color _iptvPanel = Color(0xFF071326);
const Color _iptvPanel2 = Color(0xFF0B1B31);
const Color _iptvLine = Color(0xFF123D65);
const Color _iptvCyan = Color(0xFF00E5FF);
const Color _iptvGreen = Color(0xFF39FF9C);
const Color _iptvPink = Color(0xFFFF28CF);
const Color _iptvMuted = Color(0xFFA9BDD6);

class IptvSourcesScreen extends StatefulWidget {
  const IptvSourcesScreen({super.key});

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
  List<_MergedM3uChannel> _mergedChannels = <_MergedM3uChannel>[];
  AutoLiveCatalog? _catalog;
  String _progressMessage = '';
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
      final settings = await AutoLiveSettings.load();
      if (!mounted) return;
      setState(() {
        _playlistUrls = List<String>.of(settings.playlistUrls);
        _epgUrls = List<String>.of(settings.epgUrls);
        _loading = false;
      });
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
      await AutoLiveSettings.save(
        playlistUrl: _playlistUrls.join('\n'),
        epgUrl: _epgUrls.join('\n'),
        authorizationConfirmed: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listas M3U y guías EPG guardadas.')),
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
    if (mounted && added > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se agregaron $added fuentes correctamente.')),
      );
    }
  }

  Future<void> _removeSource({required bool epg, required int index}) async {
    final list = epg ? _epgUrls : _playlistUrls;
    if (list.length <= 1) {
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
    if (_refreshing || _playlistUrls.isEmpty) return;
    setState(() {
      _refreshing = true;
      _error = null;
      _progressMessage = 'Preparando las fuentes…';
    });
    try {
      final catalog = await _service.loadCatalog(
        playlistUrl: _playlistUrls.join('\\n'),
        epgUrl: _epgUrls.join('\\n'),
        forceRefresh: true,
        downloadBatchSize: 2,
        batchPause: const Duration(milliseconds: 160),
        maxPlaylistBytes: 8 * 1024 * 1024,
        maxEpgBytes: 12 * 1024 * 1024,
        onProgress: (phase, completed, total) {
          if (!mounted) return;
          setState(() {
            _progressMessage = phase == 'M3U'
                ? 'Extrayendo listas M3U: $completed de $total'
                : 'Procesando guías EPG: $completed de $total';
          });
        },
      );
      final grouped = _groupChannels(catalog.channels);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _rawChannelCount = catalog.channels.length;
        _programmeCount = catalog.programmes.length;
        _mergedChannels = grouped;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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

  List<_MergedM3uChannel> get _filteredChannels {
    final query = AutomaticLiveService.normalizeText(_searchController.text);
    if (query.isEmpty) return _mergedChannels;
    return _mergedChannels.where((entry) {
      final channel = entry.primary;
      return AutomaticLiveService.normalizeText(
        channel.name + ' ' + channel.tvgName + ' ' +
            channel.tvgId + ' ' + channel.group,
      ).contains(query);
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
                      trailing: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: _iptvGreen,
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerGridScreen(
          sources: <LivePlayerSource>[
            LivePlayerSource(
              title: selected.name,
              url: selected.url,
              subtitle: selected.group.isEmpty
                  ? 'Canal IPTV autorizado'
                  : selected.group,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredChannels;
    return Scaffold(
      backgroundColor: _iptvBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text(
          'GESTOR IPTV · LISTAS Y EPG',
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
                  child: const Text(
                    'Gestiona listas M3U/M3U8 y guías XMLTV/EPG desde un único centro. El extractor combina fuentes, elimina duplicados y conserva alternativas. El reproductor nativo abre canales directos compatibles con controles de calidad y pantalla completa; los ocho espacios multivista de la app se mantienen. El análisis pesado se procesa fuera de la interfaz.',
                    style: TextStyle(
                      color: _iptvMuted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
                _sourceSection(
                  title: 'LISTAS DE CANALES M3U / M3U8',
                  description:
                      'Las listas se descargan en lotes pequeños. Puedes cambiar el orden de prioridad o quitar una fuente sin borrar las demás.',
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
                      const Text(
                        'Descarga y combina todas las listas. Las guías EPG se incorporan cuando responden; los canales no desaparecen si una guía falla. Los canales repetidos se agrupan por tvg-id o nombre y conservan sus alternativas.',
                        style: TextStyle(
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
                                ? 'EXTRAYENDO LISTAS Y EPG…'
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
                if (_mergedChannels.isNotEmpty) ...<Widget>[
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
                  const SizedBox(height: 8),
                  Text(
                    'CANALES (' + filtered.length.toString() + ')',
                    style: const TextStyle(
                      color: _iptvCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  for (final entry in filtered.take(250))
                    Card(
                      color: _iptvPanel,
                      margin: const EdgeInsets.only(bottom: 5),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.live_tv_rounded,
                          color: _iptvCyan,
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
                          (entry.primary.group.isEmpty
                                  ? 'Deportes / TV'
                                  : entry.primary.group) +
                              ' · ' +
                              entry.channels.length.toString() +
                              ' fuente(s)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _iptvMuted,
                            fontSize: 10,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: _iptvGreen,
                        ),
                        onTap: () => _showAlternatives(entry),
                      ),
                    ),
                  if (filtered.length > 250)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Se muestran los primeros 250 resultados. Usa el buscador para encontrar otros canales.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _iptvMuted, fontSize: 10),
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
