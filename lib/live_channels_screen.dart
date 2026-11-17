import 'dart:async';

import 'agenda_live_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'live_media_format.dart';
import 'stream_diagnostics.dart';


const Color _liveBg = Color(0xFF000000);
const Color _livePanel = Color(0xFF07090D);
const Color _livePanel2 = Color(0xFF0D1118);
const Color _liveLine = Color(0xFF0047FF);
const Color _liveCyan = Color(0xFF00A3FF);
const Color _livePink = Color(0xFFFF1744);
const Color _liveGreen = Color(0xFF39FF14);
const Color _liveRed = Color(0xFFFF1744);
const Color _liveMuted = Color(0xFFEAF0F8);


bool isSupportedAuthorizedMediaUrl(String value) =>
    liveMediaFormatForUrl(value) != null;

/// Pantalla visible con los ocho reproductores preparados.
/// La configuración de señales anterior se ha retirado; se conectará un
/// método nuevo en una actualización posterior.
class LiveChannelsScreen extends StatefulWidget {
  const LiveChannelsScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen>
    with WidgetsBindingObserver {
  final AgendaLiveService _agendaLive = AgendaLiveService();
  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _loading = true;
  String? _notice;
  AgendaLiveBoardState _board = const AgendaLiveBoardState(
    assignments: <AgendaLiveAssignment>[],
    pending: <AgendaLivePendingEvent>[],
    transmissionOptionCount: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_clearLegacyTransmissionConfiguration());
    if (widget.isActive) unawaited(_refreshBoard());
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_refreshBoard());
      }
    });
  }

  @override
  void didUpdateWidget(covariant LiveChannelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_refreshBoard());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshBoard());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _clearLegacyTransmissionConfiguration() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final key in <String>[
        'deporte_total_authorized_live_sources_v1',
        'deporte_total_live_favorites_v1',
      ]) {
        await preferences.remove(key);
      }
      await preferences.setString('dt360_auto_live_playlist_url_v1', '');
      await preferences.setString('dt360_auto_live_epg_url_v1', '');
      await preferences.setBool('dt360_auto_live_authorized_v1', false);
    } catch (error) {
      debugPrint('No se pudo limpiar la configuración antigua de IPTV: $error');
    }
  }

  Future<void> _refreshBoard() async {
    if (_refreshing || !mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    _refreshing = true;
    try {
      final next = await _agendaLive.buildBoardState(now: DateTime.now());
      if (!mounted) return;
      setState(() {
        _board = next;
        _loading = false;
        _notice = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notice = 'No se pudo consultar Canales deportivos. Se conservarán las referencias de Agenda y se volverá a intentar automáticamente.';
      });
      debugPrint('Error al preparar las transmisiones de Agenda: $error');
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  List<LivePlayerSource> _playerSources() {
    return _board.assignments.map((assignment) {
      final event = assignment.event;
      final option = assignment.option;
      final details = <String>[
        if (event.competition.isNotEmpty) event.competition,
        event.title,
        option.name,
      ];
      return LivePlayerSource(
        title: 'DEPORTE TOTAL 360° · ${option.name}',
        url: option.url,
        subtitle: details.join(' · '),
        eventId: event.id,
        startAt: event.startsAt,
        useEmbeddedPage: liveMediaFormatForUrl(option.url) == null,
      );
    }).toList(growable: false);
  }

  List<LivePlayerWaitingEvent> _waitingEvents() {
    final now = DateTime.now();
    return _board.pending.map((pending) {
      final event = pending.event;
      final start = event.startsAt.toLocal();
      final time = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      final heading = event.competition.isNotEmpty
          ? event.competition
          : 'AGENDA DEPORTIVA';
      final startLabel = now.isBefore(event.startsAt)
          ? 'Comienza a las $time'
          : 'Evento iniciado · $time';
      return LivePlayerWaitingEvent(
        heading: heading,
        match: event.title,
        startLabel: startLabel,
        processStatus: pending.status,
        processDetail: pending.detail,
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final sources = _playerSources();
    final waiting = _waitingEvents();
    return Scaffold(
      backgroundColor: _liveBg,
      appBar: AppBar(
        backgroundColor: _liveBg,
        title: const Text(
          'DEPORTES EN VIVO',
          style: TextStyle(
            color: _liveCyan,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _refreshing ? null : _refreshBoard,
            tooltip: 'Actualizar asignación de transmisiones',
            icon: Icon(
              Icons.refresh_rounded,
              color: _refreshing ? _liveCyan.withAlpha(110) : _liveCyan,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
            decoration: const BoxDecoration(
              color: _livePanel,
              border: Border(bottom: BorderSide(color: _liveLine)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'UN REPRODUCTOR POR PARTIDO',
                  style: TextStyle(
                    color: _liveCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'CAPTURA DE OPCIONES DESDE LA AGENDA',
                  style: TextStyle(
                    color: _livePink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .55,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Cada partido conserva el reproductor de su propia página. La opción con mayor popularidad publicada se coloca primero; si no hay métricas, se respeta el orden de la Agenda. Solo el primer cuadro se inicia automáticamente para evitar demasiadas conexiones.',
                  style: TextStyle(
                    color: _liveMuted,
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${sources.length} partidos con opción asignada · ${waiting.length} pendientes · ${_board.transmissionOptionCount} opciones capturadas',
                  style: const TextStyle(
                    color: _liveCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_loading || _refreshing)
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: _liveCyan,
                      backgroundColor: _livePanel2,
                    ),
                  ),
                if (_notice != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    _notice!,
                    style: const TextStyle(
                      color: Color(0xFFFFB4C0),
                      fontSize: 9,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: LivePlayerBoard(
              sources: sources,
              waitingEvents: waiting,
              isActive: widget.isActive,
            ),
          ),
        ],
      ),
    );
  }
}

class LivePlayerSource {
  const LivePlayerSource({
    required this.title,
    required this.url,
    this.subtitle,
    this.eventId,
    this.startAt,
    this.useEmbeddedPage = false,
  });

  final String title;
  final String url;
  final String? subtitle;
  final String? eventId;
  final DateTime? startAt;
  final bool useEmbeddedPage;
}

class LivePlayerWaitingEvent {
  const LivePlayerWaitingEvent({
    required this.heading,
    required this.match,
    required this.startLabel,
    this.processStatus = 'ESPERANDO COMPROBACIÓN',
    this.processDetail = '',
  });

  final String heading;
  final String match;
  final String startLabel;
  final String processStatus;
  final String processDetail;
}

/// Solo arranca automáticamente el primer canal para evitar ocho
/// conexiones simultáneas en teléfonos con memoria/ancho de banda limitados.
bool shouldAutomaticallyStartLiveSource({
  required int index,
  required bool isActive,
}) => isActive && index == 0;

/// Formato de resolución legible para el selector de calidad.
String videoTrackResolutionLabel(VideoTrack track) {
  final height = track.height;
  if (height != null && height > 0) return '${height}p';
  final label = track.label?.trim();
  if (label != null && label.isNotEmpty) return label;
  final bitrate = track.bitrate;
  if (bitrate != null && bitrate > 0) {
    return '${(bitrate / 1000).round()} kbps';
  }
  return 'Calidad disponible';
}

class LivePlayerBoard extends StatelessWidget {
  const LivePlayerBoard({
    super.key,
    required this.sources,
    this.waitingEvents = const <LivePlayerWaitingEvent>[],
    this.isActive = true,
    this.prioritizedEventId,
  });

  final List<LivePlayerSource> sources;
  final List<LivePlayerWaitingEvent> waitingEvents;
  final bool isActive;
  final String? prioritizedEventId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > constraints.maxHeight ? 3 : 2;
        final activeSources = sources.toList(growable: false);
        final waiting = waitingEvents.toList(growable: false);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: activeSources.isEmpty && waiting.isEmpty
                  ? 8
                  : activeSources.length + waiting.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.40,
              ),
              itemBuilder: (context, index) {
                final channelNumber = index + 1;
                if (index < activeSources.length) {
                  final source = activeSources[index];
                  if (source.startAt != null &&
                      DateTime.now().isBefore(source.startAt!)) {
                    final start = source.startAt!.toLocal();
                    final startLabel = 'Comienza ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                    return _WaitingLivePlayerTile(
                      channelNumber: channelNumber,
                      event: LivePlayerWaitingEvent(
                        heading: 'TRANSMISIÓN PREPARADA',
                        match: source.subtitle ?? source.title,
                        startLabel: startLabel,
                        processStatus: 'CANAL ASIGNADO',
                        processDetail: 'El reproductor se activará al comenzar el evento.',
                      ),
                    );
                  }
                  return Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _livePanel,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: _liveCyan.withAlpha(150), width: 1.1),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: _liveCyan.withAlpha(24), blurRadius: 12),
                      ],
                    ),
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: source.useEmbeddedPage
                                  ? _LiveWebPageTile(
                                      key: ValueKey<String>(
                                        'board-page-$channelNumber-${source.eventId ?? ''}-${source.url}',
                                      ),
                                      source: source,
                                      autoStart: shouldAutomaticallyStartLiveSource(
                                        index: index,
                                        isActive: isActive,
                                      ),
                                      isActive: isActive,
                                    )
                                  : _LiveVideoTile(
                                      key: ValueKey<String>(
                                        'board-$channelNumber-${source.eventId ?? ''}-${source.url}',
                                      ),
                                      source: source,
                                      initiallyMuted: index > 0,
                                      autoStart: shouldAutomaticallyStartLiveSource(
                                        index: index,
                                        isActive: isActive,
                                      ),
                                      isActive: isActive,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 29,
                          child: Text(
                            source.subtitle ?? 'Transmisión en directo',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _liveMuted,
                              fontSize: 9,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final waitingIndex = index - activeSources.length;
                if (waitingIndex < waiting.length) {
                  return _WaitingLivePlayerTile(
                    channelNumber: channelNumber,
                    event: waiting[waitingIndex],
                  );
                }
                return _WaitingLivePlayerTile(channelNumber: channelNumber);
              },
            ),
          ),
        );
      },
    );
  }
}

class _OfflineSportsArtwork extends StatelessWidget {
  const _OfflineSportsArtwork({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF07090D),
            Color(0xFF000000),
            Color(0xFF0D1118),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: -22,
            right: -18,
            child: Icon(
              Icons.sports_soccer_rounded,
              size: compact ? 78 : 112,
              color: _liveCyan.withAlpha(24),
            ),
          ),
          Positioned(
            bottom: -26,
            left: -20,
            child: Icon(
              Icons.sports_basketball_rounded,
              size: compact ? 78 : 112,
              color: _livePink.withAlpha(22),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.sports_soccer_rounded,
                size: compact ? 21 : 38,
                color: _liveCyan,
              ),
              SizedBox(height: compact ? 2 : 3),
              Text(
                'DEPORTE TOTAL 360°',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _liveCyan,
                  fontSize: compact ? 7 : 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 2 : 5),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 14,
                  vertical: compact ? 2 : 5,
                ),
                decoration: BoxDecoration(
                  color: _liveRed.withAlpha(28),
                  border: Border.all(color: _liveRed, width: 1.2),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: _liveRed.withAlpha(55), blurRadius: 12),
                  ],
                ),
                child: Text(
                  'SEÑAL PENDIENTE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _liveRed,
                    fontSize: compact ? 7 : 12,
                    letterSpacing: compact ? .6 : 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!compact) ...<Widget>[
                const SizedBox(height: 5),
                const Text(
                  'CONSULTA EL ESTADO DEL PROCESO',
                  style: TextStyle(
                    color: _liveMuted,
                    fontSize: 8,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingLivePlayerTile extends StatelessWidget {
  const _WaitingLivePlayerTile({
    required this.channelNumber,
    this.event,
  });

  final int channelNumber;
  final LivePlayerWaitingEvent? event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07090D),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _livePink.withAlpha(170), width: 1.1),
          boxShadow: <BoxShadow>[
            BoxShadow(color: _livePink.withAlpha(22), blurRadius: 10),
          ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            color: _livePanel,
            child: Text(
              'DEPORTE TOTAL 360° CANAL $channelNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _liveCyan,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: Column(
                children: <Widget>[
                  const Expanded(
                    child: _OfflineSportsArtwork(compact: true),
                  ),
                  if (event != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      event!.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _liveCyan,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      event!.match,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      event!.startLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _liveMuted,
                        fontSize: 7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      decoration: BoxDecoration(
                        color: _liveCyan.withAlpha(12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _liveCyan.withAlpha(100)),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            event!.processStatus,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _liveCyan,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (event!.processDetail.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              event!.processDetail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _liveMuted,
                                fontSize: 6,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 7, left: 4, right: 4),
            child: Text(
              'ESPERANDO TRANSMISIÓN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _liveMuted,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multivista de hasta ocho cuadros. Cada cuadro administra su propio player nativo.
class LivePlayerGridScreen extends StatefulWidget {
  const LivePlayerGridScreen({
    super.key,
    required this.sources,
    this.refreshSources,
    this.refreshInterval = const Duration(seconds: 30),
  });

  final List<LivePlayerSource> sources;
  final Future<List<LivePlayerSource>> Function()? refreshSources;
  final Duration refreshInterval;

  @override
  State<LivePlayerGridScreen> createState() => _LivePlayerGridScreenState();
}

class _LivePlayerGridScreenState extends State<LivePlayerGridScreen> {
  late List<LivePlayerSource> _sources;
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _sources = List<LivePlayerSource>.of(widget.sources);
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant LivePlayerGridScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSources != widget.refreshSources ||
        oldWidget.refreshInterval != widget.refreshInterval) {
      _refreshTimer?.cancel();
      _startRefreshTimer();
    }
    if (oldWidget.sources != widget.sources) {
      _sources = List<LivePlayerSource>.of(widget.sources);
    }
  }

  void _startRefreshTimer() {
    if (widget.refreshSources == null) return;
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) => _refreshSources());
  }

  Future<void> _refreshSources() async {
    final loader = widget.refreshSources;
    if (loader == null || _refreshing || !mounted) return;
    _refreshing = true;
    try {
      final updated = await loader();
      if (!mounted) return;
      final next = updated
          .where((source) => isSupportedAuthorizedMediaUrl(source.url))
          .take(8)
          .toList(growable: false);
      setState(() => _sources = next);
    } catch (_) {
      // Se mantienen los cuadros actuales si falla una actualización puntual.
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeSources = _sources
        .where((source) => isSupportedAuthorizedMediaUrl(source.url))
        .take(8)
        .toList(growable: false);
    final columns = safeSources.length <= 1 ? 1 :
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height ? 3 : 2;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        title: Text(
          safeSources.length == 1
              ? 'REPRODUCTOR EN VIVO'
              : 'MULTIVISTA · ${safeSources.length}/8 EVENTOS',
          style: const TextStyle(
            color: _liveCyan,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          if (widget.refreshSources != null)
            IconButton(
              tooltip: 'Actualizar eventos del reproductor',
              onPressed: _refreshing ? null : _refreshSources,
              icon: const Icon(Icons.sync_rounded, color: _liveCyan),
            ),
        ],
      ),
      body: safeSources.isEmpty
          ? const Center(
              child: Text(
                'No hay una fuente multimedia válida.',
                style: TextStyle(color: Colors.white),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(7),
              itemCount: safeSources.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: safeSources.length == 1 ? 16 / 9 : 1.42,
              ),
              itemBuilder: (context, index) => _LiveVideoTile(
                key: ValueKey<String>(safeSources[index].url),
                source: safeSources[index],
                initiallyMuted: index > 0,
              ),
            ),
    );
  }
}

class _LiveWebPageTile extends StatefulWidget {
  const _LiveWebPageTile({
    super.key,
    required this.source,
    required this.autoStart,
    required this.isActive,
  });

  final LivePlayerSource source;
  final bool autoStart;
  final bool isActive;

  @override
  State<_LiveWebPageTile> createState() => _LiveWebPageTileState();
}

class _LiveWebPageTileState extends State<_LiveWebPageTile> {
  bool _started = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _started = widget.autoStart && widget.isActive;
  }

  @override
  void didUpdateWidget(covariant _LiveWebPageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive && widget.autoStart) {
      setState(() => _started = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return Container(
        color: const Color(0xFF07090D),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.play_circle_outline_rounded,
                color: _liveCyan, size: 34),
            const SizedBox(height: 4),
            TextButton(
              onPressed: widget.isActive
                  ? () => setState(() => _started = true)
                  : null,
              child: const Text('CARGAR TRANSMISIÓN',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }

    if (!isSafeAgendaTransmissionUrl(widget.source.url)) {
      return const Center(
        child: Text(
          'Enlace HTTPS no válido',
          style: TextStyle(color: Colors.white, fontSize: 9),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.source.url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            useShouldOverrideUrlLoading: true,
            javaScriptCanOpenWindowsAutomatically: false,
            supportMultipleWindows: false,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            supportZoom: false,
          ),
          shouldOverrideUrlLoading: (controller, action) async {
            final target = action.request.url;
            if (target == null) return NavigationActionPolicy.CANCEL;
            if (target.scheme == 'about') return NavigationActionPolicy.ALLOW;
            return target.scheme == 'https' && target.userInfo.isEmpty
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL;
          },
          onLoadStart: (controller, url) {
            if (mounted) setState(() => _loading = true);
          },
          onLoadStop: (controller, url) {
            if (mounted) setState(() => _loading = false);
          },
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame == false || !mounted) return;
            setState(() {
              _loading = false;
              _error = 'No se pudo cargar esta página de transmisión.';
            });
          },
        ),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _liveCyan,
            ),
          ),
        if (_error != null)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xE8000000),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveVideoTile extends StatefulWidget {
  const _LiveVideoTile({
    super.key,
    required this.source,
    required this.initiallyMuted,
    this.autoStart = true,
    this.isActive = true,
  });

  final LivePlayerSource source;
  final bool initiallyMuted;
  final bool autoStart;
  final bool isActive;

  @override
  State<_LiveVideoTile> createState() => _LiveVideoTileState();
}

class _LiveVideoTileState extends State<_LiveVideoTile> {
  VideoPlayerController? _controller;
  String? _error;
  List<VideoTrack> _videoTracks = <VideoTrack>[];
  String? _manualQualityTrackId;
  bool _loading = false;
  bool _showControls = true;
  bool _muted = false;
  bool _isFullscreen = false;
  bool _compactPlayback = false;

  @override
  void initState() {
    super.initState();
    _muted = widget.initiallyMuted;
    if (widget.autoStart) _initialize();
  }

  @override
  void didUpdateWidget(covariant _LiveVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _compactPlayback = false;
      final controller = _controller;
      if (controller?.value.isPlaying == true) {
        unawaited(controller!.pause());
      }
    } else if (!oldWidget.isActive && widget.isActive && widget.autoStart) {
      unawaited(_initialize());
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    unawaited(_disposeControllerSafely(controller));
    super.dispose();
  }

  Future<void> _disposeControllerSafely(
    VideoPlayerController? controller,
  ) async {
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (error, stackTrace) {
      // Un fallo al liberar el player no debe propagarse y cerrar la APK.
      debugPrint('No se pudo liberar el reproductor de vídeo: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<VideoTrack>> _readVideoTracks(
    VideoPlayerController controller,
  ) async {
    try {
      if (!controller.isVideoTrackSupportAvailable()) {
        return <VideoTrack>[];
      }
      final tracks = await controller.getVideoTracks();
      return tracks.toList(growable: false)
        ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    } catch (_) {
      return <VideoTrack>[];
    }
  }

  Future<void> _initialize() async {
    if (!widget.isActive) return;
    final old = _controller;
    _controller = null;
    await _disposeControllerSafely(old);
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _videoTracks = <VideoTrack>[];
      _manualQualityTrackId = null;
      _compactPlayback = false;
      _isFullscreen = false;
    });

    final uri = Uri.tryParse(widget.source.url.trim());
    if (uri == null || !isSupportedAuthorizedMediaUrl(uri.toString())) {
      setState(() {
        _loading = false;
        _error = 'La URL no es una señal multimedia directa válida.';
      });
      return;
    }

    final controller = createCompatibleNetworkVideoController(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(_muted ? 0 : 1);
      final tracks = await _readVideoTracks(controller);
      if (!mounted || !widget.isActive) {
        await _disposeControllerSafely(controller);
        if (identical(_controller, controller)) _controller = null;
        return;
      }
      setState(() {
        _videoTracks = tracks;
        _loading = false;
      });
      await controller.play();
      if (!mounted) {
        await _disposeControllerSafely(controller);
        if (identical(_controller, controller)) _controller = null;
        return;
      }
      setState(() {});
    } catch (error) {
      if (!mounted) {
        await _disposeControllerSafely(controller);
        if (identical(_controller, controller)) _controller = null;
        return;
      }
      setState(() {
        _loading = false;
        _error = explainVideoPlayerError(error);
      });
      await _disposeControllerSafely(controller);
      if (identical(_controller, controller)) _controller = null;
    }
  }

  Future<void> _togglePlayback() async {
    if (!widget.isActive) return;
    var controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      await _initialize();
      controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      if (controller.value.isPlaying) {
        await _openFullscreen(controller);
      }
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
      if (mounted) setState(() {});
      return;
    }

    await controller.play();
    if (mounted) setState(() {});
    await _openFullscreen(controller);
  }

  Future<void> _toggleMute() async {
    if (!widget.isActive) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  void _applyQuality(VideoTrack? track) {
    // El selector ya aplicó la pista en ExoPlayer; aquí solo se actualiza
    // la etiqueta del canal sin duplicar la orden nativa.
    if (mounted) setState(() => _manualQualityTrackId = track?.id);
  }

  Future<void> _openFullscreen(VideoPlayerController controller) async {
    if (!widget.isActive || !controller.value.isInitialized) return;
    setState(() => _isFullscreen = true);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _LiveFullscreenPlayer(
          title: widget.source.title,
          controller: controller,
          initiallyMuted: _muted,
          initialQualityTrackId: _manualQualityTrackId,
          onQualityChanged: (track) {
            if (!mounted || !identical(_controller, controller)) return;
            setState(() => _manualQualityTrackId = track?.id);
          },
        ),
      ),
    );

    if (!mounted || !identical(_controller, controller)) return;
    setState(() {
      _isFullscreen = false;
      _muted = controller.value.volume == 0;
      // Primera pulsación de atrás: regresar a la miniatura y conservar vídeo.
      // Se marca antes de consultar las pistas para que la siguiente pulsación
      // ya quede interceptada y pueda detener el directo.
      _compactPlayback = controller.value.isInitialized;
    });
    final tracks = await _readVideoTracks(controller);
    if (!mounted || !identical(_controller, controller)) return;
    setState(() => _videoTracks = tracks);
  }

  Future<void> _stopCompactPlayback() async {
    final controller = _controller;
    if (controller == null) {
      if (mounted) setState(() => _compactPlayback = false);
      return;
    }
    _compactPlayback = false;
    try {
      if (controller.value.isInitialized) await controller.pause();
      await controller.dispose();
    } catch (_) {
      // El controlador puede haberse cerrado al cambiar el evento.
    }
    if (!mounted || !identical(_controller, controller)) return;
    setState(() {
      _controller = null;
      _videoTracks = <VideoTrack>[];
      _manualQualityTrackId = null;
      _loading = false;
      _error = null;
      _isFullscreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    final isPlaying = controller?.value.isPlaying ?? false;

    return PopScope<void>(
      canPop: !_compactPlayback,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _compactPlayback) {
          unawaited(_stopCompactPlayback());
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF07090D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _liveLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (initialized && !_isFullscreen)
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (isPlaying) {
                      unawaited(_openFullscreen(controller));
                    } else {
                      setState(() => _showControls = !_showControls);
                    }
                  },
                  child: AspectRatio(
                    aspectRatio: controller!.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            else
              const _OfflineSportsArtwork(compact: true),
            if (!_loading &&
                _error == null &&
                (!initialized || !isPlaying) &&
                !_isFullscreen)
              Center(
                child: IconButton.filled(
                  onPressed: _togglePlayback,
                  iconSize: 39,
                  icon: const Icon(Icons.play_arrow_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: _liveCyan,
                    foregroundColor: Colors.black,
                  ),
                  tooltip: 'Reproducir en pantalla completa',
                ),
              ),
            if (_loading)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(190),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _liveCyan.withAlpha(130)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: _liveCyan,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'CONECTANDO A LA SEÑAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _liveCyan,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const _OfflineSportsArtwork(compact: true),
                  Container(
                    color: Colors.black.withAlpha(185),
                    padding: const EdgeInsets.fromLTRB(7, 5, 7, 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        const Text(
                          'ERROR DE REPRODUCCIÓN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFF6B7D),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _error!,
                          key: const ValueKey<String>('live-player-error-detail'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        TextButton.icon(
                          onPressed: _initialize,
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          label: const Text('REINTENTAR'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.black.withAlpha(170),
                            textStyle: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        StreamDiagnosticButton(
                          url: widget.source.url,
                          compact: true,
                          color: _liveCyan,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (initialized && controller!.value.isBuffering && !_isFullscreen)
              const Positioned(
                top: 42,
                right: 8,
                child: SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _liveCyan,
                  ),
                ),
              ),
            if (!_isFullscreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  color: Colors.black.withAlpha(150),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        isPlaying ? Icons.circle : Icons.circle_outlined,
                        color: isPlaying ? _liveRed : _liveMuted,
                        size: 7,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.source.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (initialized && _showControls && !_isFullscreen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withAlpha(165),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _togglePlayback,
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        tooltip: 'Pausar o reproducir',
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _toggleMute,
                        icon: Icon(
                          _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        tooltip: _muted ? 'Activar sonido' : 'Silenciar',
                      ),
                      _VideoQualityPickerButton(
                        controller: controller!,
                        tracks: _videoTracks,
                        selectedTrackId: _manualQualityTrackId,
                        onChanged: _applyQuality,
                        compact: true,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openFullscreen(controller),
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        tooltip: 'Pantalla completa',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoQualityPickerButton extends StatelessWidget {
  const _VideoQualityPickerButton({
    required this.controller,
    required this.tracks,
    required this.selectedTrackId,
    required this.onChanged,
    this.compact = false,
  });

  final VideoPlayerController controller;
  final List<VideoTrack> tracks;
  final String? selectedTrackId;
  final ValueChanged<VideoTrack?> onChanged;
  final bool compact;

  String _details(VideoTrack track) {
    final parts = <String>[];
    final bitrate = track.bitrate;
    if (bitrate != null && bitrate > 0) {
      parts.add('${(bitrate / 1000).round()} kb/s');
    }
    if (track.codec != null && track.codec!.isNotEmpty) {
      parts.add(track.codec!);
    }
    return parts.join(' · ');
  }

  Future<void> _openPicker(BuildContext context) async {
    final sorted = List<VideoTrack>.of(tracks)
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _livePanel,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 5, 18, 13),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.high_quality_rounded, color: _liveCyan),
                    SizedBox(width: 10),
                    Text(
                      'CALIDAD DE TRANSMISIÓN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded, color: _liveCyan),
                title: const Text(
                  'Automática',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Se adapta al ancho de banda disponible',
                  style: TextStyle(color: _liveMuted, fontSize: 11),
                ),
                trailing: selectedTrackId == null
                    ? const Icon(Icons.check_circle_rounded, color: _liveGreen)
                    : null,
                onTap: () async {
                  try {
                    await controller.selectVideoTrack(null);
                    onChanged(null);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No se pudo activar calidad automática: $error')),
                      );
                    }
                  }
                },
              ),
              if (sorted.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: Text(
                    'Esta señal no publica varias resoluciones. Se mantiene la calidad automática disponible.',
                    style: TextStyle(color: _liveMuted, fontSize: 12),
                  ),
                ),
              for (final track in sorted)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.hd_rounded, color: _liveMuted),
                  title: Text(
                    videoTrackResolutionLabel(track),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _details(track).isEmpty ? 'Resolución del proveedor' : _details(track),
                    style: const TextStyle(color: _liveMuted, fontSize: 11),
                  ),
                  trailing: selectedTrackId == track.id
                      ? const Icon(Icons.check_circle_rounded, color: _liveGreen)
                      : null,
                  onTap: () async {
                    try {
                      await controller.selectVideoTrack(track);
                      onChanged(track);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No se pudo cambiar la resolución: $error')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _buttonLabel() {
    if (selectedTrackId == null) return 'AUTO';
    for (final track in tracks) {
      if (track.id == selectedTrackId) {
        return videoTrackResolutionLabel(track);
      }
    }
    return 'CALIDAD';
  }

  @override
  Widget build(BuildContext context) {
    final label = _buttonLabel();
    return TextButton.icon(
      onPressed: () => _openPicker(context),
      icon: const Icon(Icons.high_quality_rounded, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
      style: TextButton.styleFrom(
        foregroundColor: selectedTrackId == null ? _liveCyan : _liveGreen,
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 3)
            : const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size(compact ? 35 : 52, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _LiveFullscreenPlayer extends StatefulWidget {
  const _LiveFullscreenPlayer({
    required this.title,
    required this.controller,
    required this.initiallyMuted,
    required this.initialQualityTrackId,
    required this.onQualityChanged,
  });

  final String title;
  final VideoPlayerController controller;
  final bool initiallyMuted;
  final String? initialQualityTrackId;
  final ValueChanged<VideoTrack?> onQualityChanged;

  @override
  State<_LiveFullscreenPlayer> createState() => _LiveFullscreenPlayerState();
}

class _LiveFullscreenPlayerState extends State<_LiveFullscreenPlayer> {
  List<VideoTrack> _videoTracks = <VideoTrack>[];
  String? _manualQualityTrackId;
  bool _muted = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _muted = widget.initiallyMuted;
    _manualQualityTrackId = widget.initialQualityTrackId;
    unawaited(SystemChrome.setPreferredOrientations(
      const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    try {
      final controller = widget.controller;
      if (!controller.isVideoTrackSupportAvailable()) return;
      final tracks = await controller.getVideoTracks();
      if (!mounted) return;
      setState(() {
        _videoTracks = tracks.toList(growable: false)
          ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
      });
    } catch (_) {
      // La calidad automática sigue disponible aunque el proveedor no exponga pistas.
    }
  }

  @override
  void dispose() {
    // El controlador pertenece a la miniatura; no se detiene al cerrar fullscreen.
    unawaited(SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = widget.controller;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await widget.controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  void _qualityChanged(VideoTrack? track) {
    _manualQualityTrackId = track?.id;
    widget.onQualityChanged(track);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio > 0
                      ? controller.value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            if (controller.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(color: _liveCyan),
              ),
            if (_showControls)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      tooltip: 'Volver al reproductor pequeño',
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _VideoQualityPickerButton(
                      controller: controller,
                      tracks: _videoTracks,
                      selectedTrackId: _manualQualityTrackId,
                      onChanged: _qualityChanged,
                    ),
                  ],
                ),
              ),
            if (_showControls)
              Positioned(
                bottom: 15,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton.filledTonal(
                      onPressed: _togglePlayback,
                      icon: Icon(
                        controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton.filledTonal(
                      onPressed: _toggleMute,
                      icon: Icon(
                        _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
