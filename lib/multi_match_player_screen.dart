import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'agenda_screen.dart';

class MultiMatchPlayerScreen extends StatefulWidget {
  const MultiMatchPlayerScreen({super.key, required this.matches});
  final List<MatchEvent> matches;
  @override
  State<MultiMatchPlayerScreen> createState() => _MultiMatchPlayerScreenState();
}

class _MultiMatchPlayerScreenState extends State<MultiMatchPlayerScreen> {
  static const int _playersPerPage = 4;
  int _page = 0;
  String? _audioEventId;

  List<MatchEvent> get _playableMatches => widget.matches
      .where((event) =>
          event.status != MatchStatus.finished &&
          event.streamSources.any((source) => source.validatedUri != null))
      .toList(growable: false);
  int get _pageCount => (_playableMatches.length / _playersPerPage).ceil();
  List<MatchEvent> get _pageMatches => _playableMatches
      .skip(_page * _playersPerPage)
      .take(_playersPerPage)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final matches = _playableMatches;
    if (matches.isNotEmpty) _audioEventId = matches.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final matches = _playableMatches;
    final pageCount = _pageCount;
    return Scaffold(
      backgroundColor: const Color(0xFF030814),
      appBar: AppBar(
        title: const Text('MULTIPANTALLA EN VIVO', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.w900)),
      ),
      body: matches.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay partidos con señales autorizadas vinculadas. Configura una lista M3U y una guía XMLTV para buscar emisiones coincidentes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFA9BDD6), height: 1.5),
                ),
              ),
            )
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${matches.length} partidos · hasta \$_playersPerPage ventanas simultáneas',
                          style: const TextStyle(color: Color(0xFFA9BDD6), fontSize: 11),
                        ),
                      ),
                      if (pageCount > 1) ...<Widget>[
                        IconButton(
                          onPressed: _page > 0 ? () => setState(() => _page--) : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: const Color(0xFF00E5FF),
                          disabledColor: const Color(0xFF506176),
                          tooltip: 'Partidos anteriores',
                        ),
                        Text(
                          '${_page + 1}/$pageCount',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                        IconButton(
                          onPressed: _page + 1 < pageCount ? () => setState(() => _page++) : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: const Color(0xFF00E5FF),
                          disabledColor: const Color(0xFF506176),
                          tooltip: 'Más partidos',
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                    itemCount: _pageMatches.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 9,
                      childAspectRatio: .92,
                    ),
                    itemBuilder: (context, index) {
                      final event = _pageMatches[index];
                      return _MultiMatchPlayerTile(
                        key: ValueKey<String>(event.id),
                        event: event,
                        audioEnabled: _audioEventId == event.id,
                        onToggleAudio: () => setState(() {
                          _audioEventId = _audioEventId == event.id ? null : event.id;
                        }),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Text(
                    'Solo una ventana mantiene el audio activo para evitar sonidos superpuestos. El número de ventanas que el teléfono puede decodificar depende de su hardware.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8195AE), fontSize: 9, height: 1.35),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MultiMatchPlayerTile extends StatefulWidget {
  const _MultiMatchPlayerTile({
    super.key,
    required this.event,
    required this.audioEnabled,
    required this.onToggleAudio,
  });
  final MatchEvent event;
  final bool audioEnabled;
  final VoidCallback onToggleAudio;
  @override
  State<_MultiMatchPlayerTile> createState() => _MultiMatchPlayerTileState();
}

class _MultiMatchPlayerTileState extends State<_MultiMatchPlayerTile> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _waitingForKickoff = false;
  Timer? _kickoffTimer;
  String? _error;

  MatchStreamSource? get _source {
    for (final source in widget.event.streamSources) {
      if (source.validatedUri != null) return source;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _MultiMatchPlayerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioEnabled != widget.audioEnabled) {
      final controller = _controller;
      if (controller?.value.isInitialized == true) {
        controller.setVolume(widget.audioEnabled ? 1 : 0);
      }
    }
  }

  Future<void> _initialize() async {
    final source = _source;
    final uri = source?.validatedUri;
    if (source == null || uri == null) {
      if (mounted) setState(() { _loading = false; _error = 'Fuente no válida'; });
      return;
    }
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    final path = uri.path.toLowerCase();
    final format = path.endsWith('.m3u8')
        ? VideoFormat.hls
        : path.endsWith('.mpd')
            ? VideoFormat.dash
            : VideoFormat.other;
    final controller = VideoPlayerController.networkUrl(uri, formatHint: format, httpHeaders: source.httpHeaders);
    _controller = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 25));
      await controller.setLooping(false);
      await controller.setVolume(widget.audioEnabled ? 1 : 0);
      if (!mounted) {
        await controller.dispose();
        return;
      }

      final kickoffDelay = widget.event.startsAt.difference(DateTime.now());
      if (widget.event.status == MatchStatus.scheduled &&
          kickoffDelay > Duration.zero) {
        setState(() {
          _loading = false;
          _waitingForKickoff = true;
        });
        _kickoffTimer = Timer(kickoffDelay, () => _playAtKickoff(controller));
        return;
      }

      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _loading = false);
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      if (identical(_controller, controller)) _controller = null;
      setState(() { _loading = false; _error = 'No se pudo reproducir esta señal.'; });
    }
  }

  Future<void> _playAtKickoff(VideoPlayerController controller) async {
    if (!mounted || !identical(_controller, controller)) return;
    try {
      await controller.play();
      if (mounted) {
        setState(() => _waitingForKickoff = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _waitingForKickoff = false;
          _error = 'No se pudo iniciar la señal a la hora del partido.';
        });
      }
    }
  }

  @override
  void dispose() {
    _kickoffTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final source = _source;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071326),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF123D65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 4, 5),
            child: Row(
              children: <Widget>[
                const Icon(Icons.circle, color: Color(0xFFFF3155), size: 7),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${widget.event.homeTeam} vs ${widget.event.awayTeam}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  padding: EdgeInsets.zero,
                  onPressed: widget.onToggleAudio,
                  icon: Icon(
                    widget.audioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    size: 15,
                    color: widget.audioEnabled ? const Color(0xFF39FF9C) : const Color(0xFFA9BDD6),
                  ),
                  tooltip: widget.audioEnabled ? 'Silenciar' : 'Activar audio',
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: _loading
                  ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF))))
                  : _error != null || controller == null || !controller.value.isInitialized
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.signal_wifi_connected_no_internet_4_rounded, color: Color(0xFFFF3155), size: 23),
                              const SizedBox(height: 5),
                              Text(_error ?? 'Sin señal', style: const TextStyle(color: Color(0xFFA9BDD6), fontSize: 9)),
                              TextButton(onPressed: _initialize, child: const Text('Reintentar', style: TextStyle(fontSize: 10))),
                            ],
                          ),
                        )
                      : _waitingForKickoff
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(Icons.schedule_rounded, color: Color(0xFF00E5FF), size: 25),
                                  const SizedBox(height: 6),
                                  const Text('ESPERANDO EL INICIO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                  Text(
                                    'Comienza a las ${widget.event.startsAt.hour.toString().padLeft(2, '0')}:${widget.event.startsAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Color(0xFFA9BDD6), fontSize: 9),
                                  ),
                                ],
                              ),
                            )
                          : ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, _) => Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: <Widget>[
                              VideoPlayer(controller),
                              if (!value.isPlaying)
                                Center(
                                  child: IconButton.filled(
                                    onPressed: () => controller.play(),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    color: Colors.white,
                                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF087BFF)),
                                  ),
                                ),
                            ],
                          ),
                        ),
            ),
          ),
          SizedBox(
            height: 25,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Text(
                      source?.name ?? 'Fuente de vídeo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (controller?.value.isInitialized == true && !_waitingForKickoff)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 27, height: 25),
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      if (controller.value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                      if (mounted) setState(() {});
                    },
                    icon: Icon(controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16, color: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
