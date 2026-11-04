import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'automatic_live_service.dart';

const Color _iptvBg = Color(0xFF030814);
const Color _iptvPanel = Color(0xFF071326);
const Color _iptvLine = Color(0xFF123D65);
const Color _iptvCyan = Color(0xFF00E5FF);
const Color _iptvPink = Color(0xFFFF28CF);
const Color _iptvGreen = Color(0xFF39FF9C);
const Color _iptvMuted = Color(0xFFA9BDD6);

/// Reproductor de prueba para las listas y guías que ya utiliza la APK.
/// No descarga señales de sitios externos: reproduce únicamente las URLs
/// directas encontradas en las listas M3U configuradas por el usuario.
class IptvTestPlayerScreen extends StatefulWidget {
  const IptvTestPlayerScreen({
    super.key,
    this.initialCatalog,
  });

  final AutoLiveCatalog? initialCatalog;

  @override
  State<IptvTestPlayerScreen> createState() => _IptvTestPlayerScreenState();
}

class _IptvTestPlayerScreenState extends State<IptvTestPlayerScreen> {
  final AutomaticLiveService _service = AutomaticLiveService();
  AutoLiveCatalog? _catalog;
  VideoPlayerController? _controller;
  M3uChannel? _selectedChannel;
  Map<String, List<XmltvProgramme>> _programmeIndex =
      <String, List<XmltvProgramme>>{};
  String _query = '';
  String _selectedGroup = 'Todos';
  bool _loading = false;
  bool _playing = false;
  String? _error;
  String? _playerError;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _catalog = widget.initialCatalog;
    if (_catalog != null) {
      _indexProgrammes(_catalog!);
    } else {
      unawaited(_loadCatalog());
    }
  }

  @override
  void dispose() {
    _requestVersion++;
    _controller?.dispose();
    _service.dispose();
    super.dispose();
  }

  void _indexProgrammes(AutoLiveCatalog catalog) {
    final index = <String, List<XmltvProgramme>>{};
    for (final programme in catalog.programmes) {
      final keys = <String>{
        programme.channelId.trim().toLowerCase(),
        AutomaticLiveService.normalizeText(programme.channelName),
      }..removeWhere((key) => key.isEmpty);
      for (final key in keys) {
        index.putIfAbsent(key, () => <XmltvProgramme>[]).add(programme);
      }
    }
    for (final items in index.values) {
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }
    _programmeIndex = index;
  }

  Future<void> _loadCatalog({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await AutoLiveSettings.load();
      if (!settings.isConfigured) {
        throw const FormatException(
          'Configura al menos una lista M3U y una guía EPG válida en Ajustes.',
        );
      }
      final catalog = await _service.loadCatalog(
        playlistUrl: settings.playlistUrl,
        epgUrl: settings.epgUrl,
        forceRefresh: forceRefresh,
        allowEmptyEpg: true,
        downloadBatchSize: 2,
        batchPause: const Duration(milliseconds: 180),
        maxEpgBytes: 12 * 1024 * 1024,
      );
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _indexProgrammes(catalog);
        _loading = false;
        _error = catalog.channels.isEmpty
            ? 'No se encontraron canales directos compatibles en las listas configuradas.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  List<String> get _groups {
    final groups = <String>{'Todos'};
    for (final channel in _catalog?.channels ?? const <M3uChannel>[]) {
      final group = channel.group.trim();
      if (group.isNotEmpty) groups.add(group);
    }
    return groups.toList(growable: false);
  }

  List<M3uChannel> get _visibleChannels {
    final catalog = _catalog;
    if (catalog == null) return <M3uChannel>[];
    final query = AutomaticLiveService.normalizeText(_query);
    return catalog.channels.where((channel) {
      if (_selectedGroup != 'Todos' && channel.group != _selectedGroup) {
        return false;
      }
      if (query.isEmpty) return true;
      final metadata = AutomaticLiveService.normalizeText(
        '${channel.name} ${channel.tvgName} ${channel.group} ${channel.language}',
      );
      return metadata.contains(query);
    }).toList(growable: false);
  }

  List<XmltvProgramme> _programmesFor(M3uChannel channel) {
    final keys = <String>{
      channel.tvgId.trim().toLowerCase(),
      AutomaticLiveService.normalizeText(channel.tvgName),
      AutomaticLiveService.normalizeText(channel.name),
    }..removeWhere((key) => key.isEmpty);
    final seen = <String>{};
    final result = <XmltvProgramme>[];
    for (final key in keys) {
      for (final programme in _programmeIndex[key] ?? const <XmltvProgramme>[]) {
        final identity = '${programme.channelId}|${programme.title}|'
            '${programme.startsAt.toUtc().millisecondsSinceEpoch}';
        if (seen.add(identity)) result.add(programme);
      }
    }
    result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return result;
  }

  ({XmltvProgramme? current, XmltvProgramme? next}) _nowNext(
    M3uChannel channel,
  ) {
    final now = DateTime.now();
    XmltvProgramme? current;
    XmltvProgramme? next;
    for (final programme in _programmesFor(channel)) {
      if (!now.isBefore(programme.startsAt) && now.isBefore(programme.endsAt)) {
        current ??= programme;
      } else if (programme.startsAt.isAfter(now) &&
          (next == null || programme.startsAt.isBefore(next.startsAt))) {
        next = programme;
      }
    }
    return (current: current, next: next);
  }

  String _clock(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _playChannel(M3uChannel channel) async {
    final requestVersion = ++_requestVersion;
    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();
    if (!mounted || requestVersion != _requestVersion) return;
    setState(() {
      _selectedChannel = channel;
      _loading = true;
      _playing = false;
      _playerError = null;
    });

    final uri = Uri.tryParse(channel.url.trim());
    if (uri == null ||
        !isDirectPlayableStream(channel.url) ||
        !<String>{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _loading = false;
          _playerError = 'Esta entrada no es una URL de vídeo directa compatible.';
        });
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted || requestVersion != _requestVersion) {
        await controller.dispose();
        return;
      }
      await controller.play();
      if (!mounted || requestVersion != _requestVersion) {
        await controller.dispose();
        return;
      }
      setState(() {
        _loading = false;
        _playing = controller.value.isPlaying;
      });
    } catch (error) {
      await controller.dispose();
      if (!mounted || requestVersion != _requestVersion) return;
      _controller = null;
      setState(() {
        _loading = false;
        _playing = false;
        _playerError = 'No se pudo reproducir este canal: $error';
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
      if (mounted) setState(() => _playing = controller.value.isPlaying);
    } catch (error) {
      if (mounted) setState(() => _playerError = error.toString());
    }
  }

  Widget _programmeLine(String label, XmltvProgramme? programme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 45,
            child: Text(
              label,
              style: const TextStyle(
                color: _iptvCyan,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              programme == null
                  ? 'Sin información EPG'
                  : '${_clock(programme.startsAt)} · ${programme.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _iptvMuted,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerPanel() {
    final controller = _controller;
    final channel = _selectedChannel;
    final initialized = controller?.value.isInitialized == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _iptvPanel,
        border: Border.all(color: _iptvLine),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: AspectRatio(
              aspectRatio: initialized
                  ? controller!.value.aspectRatio
                  : 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (initialized)
                      VideoPlayer(controller!)
                    else
                      const Icon(
                        Icons.live_tv_rounded,
                        size: 48,
                        color: _iptvMuted,
                      ),
                    if (_loading)
                      const CircularProgressIndicator(color: _iptvCyan),
                    if (initialized)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: VideoProgressIndicator(
                          controller!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: _iptvPink,
                            bufferedColor: _iptvMuted,
                            backgroundColor: Color(0x55333333),
                          ),
                        ),
                      ),
                    if (initialized)
                      IconButton.filled(
                        onPressed: _togglePlayback,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x99000000),
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 34,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            channel?.name ?? 'SELECCIONA UN CANAL PARA PROBARLO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (channel != null) ...<Widget>[
            Text(
              channel.group.isEmpty ? 'Sin categoría' : channel.group,
              style: const TextStyle(color: _iptvMuted, fontSize: 9),
            ),
            const SizedBox(height: 4),
            if (_playerError != null)
              Text(
                _playerError!,
                style: const TextStyle(
                  color: _iptvPink,
                  fontSize: 10,
                  height: 1.35,
                ),
              )
            else ...<Widget>[
              _programmeLine('AHORA', _nowNext(channel).current),
              _programmeLine('SIGUIENTE', _nowNext(channel).next),
            ],
          ],
        ],
      ),
    );
  }

  Widget _channelTile(M3uChannel channel) {
    final selected = identical(channel, _selectedChannel) ||
        channel.url == _selectedChannel?.url;
    final schedule = _nowNext(channel);
    return Material(
      color: _iptvPanel,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: _loading ? null : () => _playChannel(channel),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? _iptvCyan : _iptvLine,
            ),
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: channel.logo.startsWith('http')
                      ? Image.network(
                          channel.logo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.tv_rounded,
                            color: _iptvCyan,
                          ),
                        )
                      : const Icon(Icons.tv_rounded, color: _iptvCyan),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      channel.group.isEmpty ? 'Deportes' : channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _iptvMuted, fontSize: 8),
                    ),
                    if (schedule.current != null)
                      Text(
                        'AHORA: ${schedule.current!.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _iptvGreen,
                          fontSize: 8,
                        ),
                      )
                    else if (schedule.next != null)
                      Text(
                        'SIGUE ${_clock(schedule.next!.startsAt)}: ${schedule.next!.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _iptvMuted, fontSize: 8),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                selected && _playing
                    ? Icons.graphic_eq_rounded
                    : Icons.play_circle_outline_rounded,
                color: selected ? _iptvPink : _iptvCyan,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final channels = _visibleChannels;
    final groups = _groups;
    return Scaffold(
      backgroundColor: _iptvBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text(
          'REPRODUCTOR IPTV · PRUEBAS',
          style: TextStyle(
            color: _iptvCyan,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Volver a descargar M3U y EPG',
            onPressed: _loading ? null : () => _loadCatalog(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded, color: _iptvCyan),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: _iptvCyan,
              backgroundColor: _iptvPanel,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 7),
            child: Column(
              children: <Widget>[
                _playerPanel(),
                const SizedBox(height: 8),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _iptvPanel,
                      border: Border.all(color: _iptvPink),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: _iptvMuted, fontSize: 10),
                    ),
                  ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        catalog == null
                            ? 'CARGANDO LISTAS Y GUÍAS…'
                            : '${catalog.channels.length} CANALES · '
                                '${catalog.programmes.length} PROGRAMAS EPG',
                        style: const TextStyle(
                          color: _iptvGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${channels.length} visibles',
                      style: const TextStyle(color: _iptvMuted, fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: 'Buscar canal, equipo o categoría…',
                    prefixIcon: Icon(Icons.search_rounded, color: _iptvCyan),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ChoiceChip(
                        label: Text(group, style: const TextStyle(fontSize: 9)),
                        selected: _selectedGroup == group,
                        selectedColor: _iptvCyan,
                        backgroundColor: _iptvPanel,
                        side: const BorderSide(color: _iptvLine),
                        onSelected: (_) => setState(() => _selectedGroup = group),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: catalog == null && _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _iptvCyan),
                  )
                : channels.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(22),
                          child: Text(
                            'No hay canales para mostrar con este filtro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _iptvMuted, fontSize: 11),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(11, 0, 11, 18),
                        itemCount: channels.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) => _channelTile(channels[index]),
                      ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 5, 10, 8),
            child: Text(
              'Prueba enlaces directos HLS, DASH o MP4 compatibles. Una señal puede fallar por caducidad, geobloqueo, cabeceras requeridas o DRM; el reproductor no elimina esas restricciones.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _iptvMuted, fontSize: 8, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
