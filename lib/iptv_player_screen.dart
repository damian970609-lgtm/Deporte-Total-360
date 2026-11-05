import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'automatic_live_service.dart';
import 'live_channels_screen.dart';

const Color _iptvBg = Color(0xFF030814);
const Color _iptvPanel = Color(0xFF071326);
const Color _iptvLine = Color(0xFF123D65);
const Color _iptvCyan = Color(0xFF00E5FF);
const Color _iptvGreen = Color(0xFF39FF9C);
const Color _iptvPink = Color(0xFFFF28CF);
const Color _iptvMuted = Color(0xFFA9BDD6);

const String _playlistUrlsKey = 'dt360_secret_iptv_playlist_urls_v1';
const String _playlistTextsKey = 'dt360_secret_iptv_playlist_texts_v1';
const String _favoriteUrlsKey = 'dt360_secret_iptv_favorite_urls_v1';

class IntegratedIptvPlayerScreen extends StatefulWidget {
  const IntegratedIptvPlayerScreen({
    super.key,
    this.parseInBackground = true,
  });

  final bool parseInBackground;

  @override
  State<IntegratedIptvPlayerScreen> createState() =>
      _IntegratedIptvPlayerScreenState();
}

class _IptvChannelGroup {
  const _IptvChannelGroup(this.channels);
  final List<M3uChannel> channels;
  M3uChannel get primary => channels.first;
}

class _IntegratedIptvPlayerScreenState
    extends State<IntegratedIptvPlayerScreen> {
  final AutomaticLiveService _service = AutomaticLiveService();
  final TextEditingController _searchController = TextEditingController();

  List<String> _playlistUrls = <String>[];
  List<String> _playlistTexts = <String>[];
  List<_IptvChannelGroup> _channels = <_IptvChannelGroup>[];
  final Set<String> _favoriteUrls = <String>{};

  bool _loading = true;
  bool _refreshing = false;
  bool _showFavoritesOnly = false;
  String? _error;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadSavedSources();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _service.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _playlistUrls = (prefs.getStringList(_playlistUrlsKey) ?? <String>[])
            .where(isSafeHttpUrl)
            .toList(growable: true);
        _playlistTexts =
            prefs.getStringList(_playlistTextsKey) ?? <String>[];
        _favoriteUrls
          ..clear()
          ..addAll(prefs.getStringList(_favoriteUrlsKey) ?? <String>[]);
        _loading = false;
      });
      await _refreshCatalog(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo leer la biblioteca guardada: ' + error.toString();
      });
    }
  }

  Future<void> _persistSources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_playlistUrlsKey, _playlistUrls);
    await prefs.setStringList(_playlistTextsKey, _playlistTexts);
  }

  Future<void> _refreshCatalog({bool showLoading = true}) async {
    if (_refreshing) return;
    if (_playlistUrls.isEmpty && _playlistTexts.isEmpty) {
      if (!mounted) return;
      setState(() {
        _channels = <_IptvChannelGroup>[];
        _error = null;
        _warning = null;
        _loading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _refreshing = true;
        if (showLoading && _channels.isEmpty) _loading = true;
        _error = null;
        _warning = null;
      });
    }

    final failedSources = <String>{};
    try {
      final catalog = await _service.loadCatalog(
        playlistUrl: _playlistUrls.join('\n'),
        epgUrl: '',
        playlistTexts: _playlistTexts,
        forceRefresh: true,
        parseInBackground: widget.parseInBackground,
        downloadBatchSize: 4,
        batchPause: Duration.zero,
        maxPlaylistBytes: 8 * 1024 * 1024,
        maxEpgBytes: 1024 * 1024,
        onSourceError: (url, _) {
          final host = Uri.tryParse(url)?.host;
          failedSources.add(host == null || host.isEmpty ? 'fuente local' : host);
        },
      );
      final merged = _mergeChannels(catalog.channels);
      if (!mounted) return;
      setState(() {
        _channels = merged;
        _warning = failedSources.isEmpty
            ? null
            : 'Algunas listas no respondieron: ' +
                failedSources.take(3).join(', ') +
                '. Las demás siguen disponibles.';
        _error = merged.isEmpty
            ? 'Las listas guardadas no contienen canales directos compatibles.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _channels.isEmpty
            ? 'No se pudieron cargar los canales. Comprueba las URLs M3U/M3U8 y tu conexión. ' +
                error.toString()
            : null;
        _warning = _channels.isEmpty
            ? null
            : 'No se pudieron actualizar todas las fuentes. Se conserva la lista que ya estaba cargada.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _loading = false;
        });
      }
    }
  }

  List<_IptvChannelGroup> _mergeChannels(List<M3uChannel> channels) {
    final grouped = <String, List<M3uChannel>>{};
    for (final channel in channels) {
      final id = AutomaticLiveService.normalizeText(channel.tvgId);
      final displayName =
          channel.tvgName.trim().isNotEmpty ? channel.tvgName : channel.name;
      final normalizedName = AutomaticLiveService.normalizeText(displayName);
      final normalizedGroup =
          AutomaticLiveService.normalizeText(channel.group);
      final key =
          id.isNotEmpty ? 'id:' + id : 'name:' + normalizedName + '|' + normalizedGroup;
      if (normalizedName.isEmpty && id.isEmpty) continue;
      final alternatives = grouped.putIfAbsent(key, () => <M3uChannel>[]);
      if (!alternatives.any((item) => item.url == channel.url)) {
        alternatives.add(channel);
      }
    }
    final result = grouped.values
        .map((items) => _IptvChannelGroup(
              List<M3uChannel>.unmodifiable(items),
            ))
        .toList(growable: false)
      ..sort((a, b) =>
          a.primary.name.toLowerCase().compareTo(b.primary.name.toLowerCase()));
    return result;
  }

  List<String> _splitUrls(String raw) => raw
      .split(RegExp(r'[\r\n;]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);

  Future<void> _addPlaylistUrls(String raw) async {
    final incoming = _splitUrls(raw);
    if (incoming.isEmpty || !incoming.every(isSafeHttpUrl)) {
      _showMessage('Introduce una o varias URLs HTTP/HTTPS válidas.');
      return;
    }
    final newUrls =
        incoming.where((url) => !_playlistUrls.contains(url)).toList();
    if (newUrls.isEmpty) {
      _showMessage('Esas listas ya están guardadas.');
      return;
    }
    setState(() {
      _playlistUrls.addAll(newUrls);
      _error = null;
    });
    try {
      await _persistSources();
      _showMessage(newUrls.length.toString() +
          ' lista(s) añadida(s). Unificando canales…');
      await _refreshCatalog();
    } catch (error) {
      _showMessage('No se pudieron guardar las listas: ' + error.toString());
    }
  }

  Future<void> _showAddListsDialog() async {
    var value = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _iptvPanel,
        title: const Text(
          'Agregar listas M3U / M3U8',
          style: TextStyle(color: _iptvCyan, fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (text) => value = text,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'URLs de tus listas (una por línea)',
              hintText: 'https://servidor/lista-deportes.m3u\nhttps://otro-servidor/canales.m3u8',
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, value),
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('AGREGAR'),
          ),
        ],
      ),
    );
    if (result != null && mounted) await _addPlaylistUrls(result);
  }

  Future<void> _importM3uText(String raw) async {
    final text = raw.trim();
    if (!text.toUpperCase().startsWith('#EXTM3U')) {
      _showMessage('El contenido no parece una lista M3U. Debe comenzar con #EXTM3U.');
      return;
    }
    if (text.length > 8 * 1024 * 1024) {
      _showMessage('La lista supera 8 MB. Divídela en varias listas antes de importarla.');
      return;
    }
    try {
      final parsed = widget.parseInBackground
          ? await Isolate.run(
              () => AutomaticLiveService.parseM3u(
                text,
                sourceUrl: 'Lista pegada',
              ),
            )
          : AutomaticLiveService.parseM3u(
              text,
              sourceUrl: 'Lista pegada',
            );
      if (!mounted) return;
      if (parsed.isEmpty) {
        _showMessage('No encontré canales directos compatibles en esa lista.');
        return;
      }
      if (!_playlistTexts.contains(text)) _playlistTexts.add(text);
      await _persistSources();
      await _refreshCatalog();
      if (mounted) {
        _showMessage('Lista importada: ' + parsed.length.toString() + ' canales detectados.');
      }
    } catch (error) {
      _showMessage('No se pudo importar la lista: ' + error.toString());
    }
  }

  Future<void> _showPasteListDialog() async {
    var value = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _iptvPanel,
        title: const Text(
          'Pegar contenido M3U',
          style: TextStyle(color: _iptvCyan, fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            autofocus: true,
            minLines: 7,
            maxLines: 14,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (text) => value = text,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              hintText: 'Pega aquí el contenido completo que comienza con #EXTM3U',
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value),
            child: const Text('IMPORTAR'),
          ),
        ],
      ),
    );
    if (result != null && mounted) await _importM3uText(result);
  }

  Future<void> _importClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        _showMessage('Copia primero una URL M3U o el contenido de una lista.');
        return;
      }
      if (text.toUpperCase().startsWith('#EXTM3U')) {
        await _importM3uText(text);
      } else {
        await _addPlaylistUrls(text);
      }
    } catch (error) {
      _showMessage('No se pudo leer el portapapeles: ' + error.toString());
    }
  }

  Future<void> _removePlaylistUrl(String url) async {
    setState(() => _playlistUrls.remove(url));
    await _persistSources();
    await _refreshCatalog();
  }

  Future<void> _removePastedList(int index) async {
    if (index < 0 || index >= _playlistTexts.length) return;
    setState(() => _playlistTexts.removeAt(index));
    await _persistSources();
    await _refreshCatalog();
  }

  Future<void> _showSources() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _iptvPanel,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * .72,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'MIS LISTAS GUARDADAS',
                    style: TextStyle(
                      color: _iptvCyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: <Widget>[
                        for (final url in _playlistUrls)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.link_rounded, color: _iptvGreen),
                            title: Text(
                              Uri.tryParse(url)?.host ?? url,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            subtitle: Text(
                              url,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _iptvMuted, fontSize: 10),
                            ),
                            trailing: IconButton(
                              tooltip: 'Eliminar lista',
                              onPressed: () async {
                                await _removePlaylistUrl(url);
                                if (sheetContext.mounted) setSheetState(() {});
                              },
                              icon: const Icon(Icons.delete_outline_rounded, color: _iptvPink),
                            ),
                          ),
                        for (var i = 0; i < _playlistTexts.length; i++)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.description_rounded, color: _iptvCyan),
                            title: Text(
                              'Lista pegada ' + (i + 1).toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            subtitle: const Text(
                              'Contenido M3U guardado en este dispositivo',
                              style: TextStyle(color: _iptvMuted, fontSize: 10),
                            ),
                            trailing: IconButton(
                              tooltip: 'Eliminar lista',
                              onPressed: () async {
                                await _removePastedList(i);
                                if (sheetContext.mounted) setSheetState(() {});
                              },
                              icon: const Icon(Icons.delete_outline_rounded, color: _iptvPink),
                            ),
                          ),
                        if (_playlistUrls.isEmpty && _playlistTexts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'Todavía no has añadido listas.',
                              style: TextStyle(color: _iptvMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isFavorite(_IptvChannelGroup entry) =>
      entry.channels.any((channel) => _favoriteUrls.contains(channel.url));

  Future<void> _toggleFavorite(_IptvChannelGroup entry) async {
    final channel = entry.primary;
    final removing = _favoriteUrls.remove(channel.url);
    if (!removing) _favoriteUrls.add(channel.url);
    if (mounted) setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _favoriteUrlsKey,
        _favoriteUrls.toList(growable: false),
      );
      if (mounted) {
        _showMessage(
          removing
              ? channel.name + ' eliminado de favoritos.'
              : channel.name + ' agregado a favoritos.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (removing) {
        _favoriteUrls.add(channel.url);
      } else {
        _favoriteUrls.remove(channel.url);
      }
      setState(() {});
      _showMessage('No se pudo guardar el favorito: ' + error.toString());
    }
  }

  Future<void> _copyChannelUrl(M3uChannel channel) async {
    try {
      await Clipboard.setData(ClipboardData(text: channel.url));
      if (mounted) _showMessage('URL de ' + channel.name + ' copiada.');
    } catch (error) {
      _showMessage('No se pudo copiar la URL: ' + error.toString());
    }
  }

  Future<void> _playChannel(M3uChannel channel) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerGridScreen(
          sources: <LivePlayerSource>[
            LivePlayerSource(
              title: channel.name,
              url: channel.url,
              subtitle: channel.group.isEmpty ? 'Canal IPTV' : channel.group,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlternatives(_IptvChannelGroup entry) async {
    if (entry.channels.length < 2) {
      await _playChannel(entry.primary);
      return;
    }
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
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.channels.length.toString() + ' fuentes para este canal',
                style: const TextStyle(color: _iptvMuted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entry.channels.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: _iptvLine, height: 1),
                  itemBuilder: (context, index) {
                    final channel = entry.channels[index];
                    return ListTile(
                      leading: const Icon(Icons.play_circle_fill_rounded, color: _iptvGreen),
                      title: Text(
                        channel.name,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      subtitle: Text(
                        Uri.tryParse(channel.sourceUrl)?.host ?? 'Fuente IPTV',
                        style: const TextStyle(color: _iptvMuted, fontSize: 10),
                      ),
                      trailing: IconButton(
                        tooltip: 'Copiar URL del canal',
                        onPressed: () => _copyChannelUrl(channel),
                        icon: const Icon(Icons.copy_rounded, color: _iptvCyan),
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
    if (selected != null && mounted) await _playChannel(selected);
  }

  List<_IptvChannelGroup> get _filteredChannels {
    final query = AutomaticLiveService.normalizeText(_searchController.text);
    return _channels.where((entry) {
      if (_showFavoritesOnly && !_isFavorite(entry)) return false;
      if (query.isEmpty) return true;
      return entry.channels.any((channel) =>
          AutomaticLiveService.normalizeText(
            channel.name + ' ' + channel.tvgName + ' ' +
                channel.tvgId + ' ' + channel.group,
          ).contains(query));
    }).toList(growable: false);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildChannelTile(_IptvChannelGroup entry) {
    final channel = entry.primary;
    final favorite = _isFavorite(entry);
    final logo = channel.logo.trim();
    final details = <String>[
      if (channel.group.trim().isNotEmpty) channel.group,
      if (entry.channels.length > 1)
        entry.channels.length.toString() + ' fuentes disponibles',
    ].join(' · ');

    return Material(
      color: _iptvPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _iptvLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 45,
            height: 45,
            child: logo.isNotEmpty && isSafeHttpUrl(logo)
                ? Image.network(
                    logo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.live_tv_rounded,
                      color: _iptvCyan,
                      size: 27,
                    ),
                  )
                : const Icon(
                    Icons.live_tv_rounded,
                    color: _iptvCyan,
                    size: 27,
                  ),
          ),
        ),
        title: Text(
          channel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          details.isEmpty ? 'Canal en directo' : details,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _iptvMuted, fontSize: 10),
        ),
        trailing: Wrap(
          spacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (entry.channels.length > 1)
              IconButton(
                tooltip: 'Elegir fuente alternativa',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showAlternatives(entry),
                icon: const Icon(Icons.more_horiz_rounded, color: _iptvMuted),
              ),
            IconButton(
              tooltip: favorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
              visualDensity: VisualDensity.compact,
              onPressed: () => _toggleFavorite(entry),
              icon: Icon(
                favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: favorite ? _iptvPink : _iptvMuted,
              ),
            ),
            IconButton(
              tooltip: 'Copiar URL del canal',
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyChannelUrl(channel),
              icon: const Icon(Icons.copy_rounded, color: _iptvCyan),
            ),
          ],
        ),
        onTap: () => _playChannel(channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredChannels;
    final favoriteCount = _channels.where(_isFavorite).length;
    final sourceCount = _playlistUrls.length + _playlistTexts.length;

    return Scaffold(
      backgroundColor: _iptvBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text(
          'REPRODUCTOR IPTV',
          style: TextStyle(
            color: _iptvCyan,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar canales',
            onPressed: _refreshing ? null : () => _refreshCatalog(),
            icon: Icon(
              Icons.refresh_rounded,
              color: _refreshing ? _iptvMuted : _iptvCyan,
            ),
          ),
          IconButton(
            tooltip: 'Mis listas guardadas',
            onPressed: _showSources,
            icon: const Icon(Icons.playlist_play_rounded, color: _iptvGreen),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFF0B2440),
                    Color(0xFF10142E),
                    Color(0xFF1D0D31),
                  ],
                ),
                border: Border(bottom: BorderSide(color: _iptvLine)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'TODOS TUS CANALES EN UNA SOLA LISTA',
                    style: TextStyle(
                      color: _iptvGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: .35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Agrega tus listas M3U/M3U8. La app reúne los canales, agrupa duplicados y los abre aquí en el reproductor integrado.',
                    style: TextStyle(
                      color: _iptvMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _showAddListsDialog,
                        icon: const Icon(Icons.add_link_rounded),
                        label: const Text('AÑADIR LISTAS'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _iptvCyan,
                          foregroundColor: _iptvBg,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importClipboard,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('IMPORTAR PEGADA'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _iptvGreen,
                          side: const BorderSide(color: _iptvGreen),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showPasteListDialog,
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('PEGAR LISTA M3U'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _iptvPink,
                          side: const BorderSide(color: _iptvPink),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar canales por nombre, deporte o grupo…',
                      prefixIcon: Icon(Icons.search_rounded, color: _iptvCyan),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _channels.length.toString() + ' canales · ' +
                              sourceCount.toString() + ' listas',
                          style: const TextStyle(
                            color: _iptvMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilterChip(
                        selected: _showFavoritesOnly,
                        onSelected: (value) =>
                            setState(() => _showFavoritesOnly = value),
                        avatar: const Icon(
                          Icons.favorite_border_rounded,
                          size: 16,
                          color: _iptvPink,
                        ),
                        label: Text('FAVORITOS (' + favoriteCount.toString() + ')'),
                        selectedColor: _iptvPink.withAlpha(35),
                        side: BorderSide(color: _iptvPink.withAlpha(160)),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_refreshing)
              const LinearProgressIndicator(
                minHeight: 2,
                color: _iptvCyan,
                backgroundColor: _iptvPanel,
              ),
            if (_warning != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Text(
                  _warning!,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _iptvCyan),
                    )
                  : _channels.isEmpty
                      ? _buildEmptyState()
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                _showFavoritesOnly
                                    ? 'No tienes favoritos que coincidan con la búsqueda.'
                                    : 'No hay canales que coincidan con tu búsqueda.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _iptvMuted),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 7),
                              itemBuilder: (_, index) =>
                                  _buildChannelTile(filtered[index]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.live_tv_rounded, color: _iptvCyan, size: 58),
            const SizedBox(height: 14),
            const Text(
              'TU REPRODUCTOR ESTÁ LISTO',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _iptvCyan,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ??
                  'Añade una o varias listas IPTV para que todos sus canales aparezcan aquí juntos.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _iptvMuted,
                height: 1.45,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _showAddListsDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('AGREGAR MI PRIMERA LISTA'),
              style: FilledButton.styleFrom(
                backgroundColor: _iptvGreen,
                foregroundColor: _iptvBg,
              ),
            ),
            const SizedBox(height: 7),
            TextButton(
              onPressed: _showPasteListDialog,
              child: const Text('Pegar contenido M3U'),
            ),
          ],
        ),
      ),
    );
  }
}
