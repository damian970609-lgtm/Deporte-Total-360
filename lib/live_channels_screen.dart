import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

import 'agenda_live_service.dart';
import 'live_media_format.dart';

const Color _liveBackground = Color(0xFF05080E);
const Color _livePanel = Color(0xFF0A1220);
const Color _liveLine = Color(0xFF153451);
const Color _liveBlue = Color(0xFF00A3FF);
const Color _liveGreen = Color(0xFF39FF14);
const Color _liveRed = Color(0xFFFF365D);
const Color _liveMuted = Color(0xFFB8C5D8);

class LiveChannelsScreen extends StatefulWidget {
  const LiveChannelsScreen({
    super.key,
    required this.onOpenAgenda,
    this.isActive = true,
  });

  final VoidCallback onOpenAgenda;
  final bool isActive;

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen>
    with WidgetsBindingObserver {
  final AgendaLiveService _agendaService = AgendaLiveService();

  Timer? _refreshTimer;
  VideoPlayerController? _player;
  AgendaLiveBoardState _board = const AgendaLiveBoardState(
    assignments: <AgendaLiveAssignment>[],
    pending: <AgendaLivePendingEvent>[],
    catalogueChannelCount: 0,
  );

  String? _selectedEventId;
  String? _playerError;
  String? _notice;
  DateTime? _lastUpdated;
  bool _loadingBoard = true;
  bool _refreshing = false;
  bool _loadingPlayer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) unawaited(_refreshBoard());
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          widget.isActive &&
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
    if (oldWidget.isActive && !widget.isActive) {
      final controller = _player;
      if (controller?.value.isPlaying == true) {
        unawaited(controller!.pause());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      unawaited(_refreshBoard());
    } else if (state != AppLifecycleState.resumed) {
      final controller = _player;
      if (controller?.value.isPlaying == true) {
        unawaited(controller!.pause());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    final oldPlayer = _player;
    _player = null;
    unawaited(_disposePlayer(oldPlayer));
    super.dispose();
  }

  Future<void> _disposePlayer(VideoPlayerController? controller) async {
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (error) {
      debugPrint('No se pudo liberar el reproductor: $error');
    }
  }

  Future<void> _refreshBoard() async {
    if (_refreshing ||
        !mounted ||
        !widget.isActive ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    _refreshing = true;
    try {
      final next = await _agendaService.buildBoardState(now: DateTime.now());
      if (!mounted) return;

      final selectedStillExists = _selectedEventId == null ||
          next.assignments.any(
            (item) => item.event.id == _selectedEventId,
          );
      if (!selectedStillExists) {
        final oldPlayer = _player;
        _player = null;
        _selectedEventId = null;
        _playerError = null;
        await _disposePlayer(oldPlayer);
      }

      setState(() {
        _board = next;
        _loadingBoard = false;
        _notice = null;
        _lastUpdated = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBoard = false;
        _notice =
            'No se pudo actualizar el catálogo de señales. Se conserva la última agenda capturada.';
      });
      debugPrint('Error al actualizar Transmisión en vivo: $error');
    } finally {
      _refreshing = false;
    }
  }

  List<_LiveEventItem> _eventItems() {
    final items = <_LiveEventItem>[];
    final assignedIds = <String>{};

    for (final assignment in _board.assignments) {
      assignedIds.add(assignment.event.id);
      items.add(_LiveEventItem(
        event: assignment.event,
        assignment: assignment,
      ));
    }

    for (final pending in _board.pending) {
      if (assignedIds.add(pending.event.id)) {
        items.add(_LiveEventItem(
          event: pending.event,
          pending: pending,
        ));
      }
    }

    items.sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
    return items;
  }

  bool _isLiveNow(AgendaEventReference event, DateTime now) {
    return !event.isFinished &&
        !now.isBefore(event.startsAt) &&
        now.isBefore(event.effectiveEndsAt);
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _playAssignment(AgendaLiveAssignment assignment) async {
    if (!widget.isActive) return;

    final url = assignment.channel.url.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !isSupportedChannelPlaybackUrl(url)) {
      setState(() {
        _playerError = 'La fuente no es un enlace multimedia directo HTTPS compatible.';
      });
      return;
    }

    final oldPlayer = _player;
    _player = null;
    await _disposePlayer(oldPlayer);
    if (!mounted) return;

    setState(() {
      _selectedEventId = assignment.event.id;
      _loadingPlayer = true;
      _playerError = null;
    });

    VideoPlayerController? nextPlayer;
    try {
      nextPlayer = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await nextPlayer.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) {
        await _disposePlayer(nextPlayer);
        return;
      }
      await nextPlayer.setLooping(false);
      setState(() {
        _player = nextPlayer;
        _loadingPlayer = false;
        _playerError = null;
      });
      await nextPlayer.play();
    } catch (error) {
      await _disposePlayer(nextPlayer);
      if (!mounted) return;
      setState(() {
        _player = null;
        _loadingPlayer = false;
        _playerError =
            'No se pudo abrir esta señal. Puede estar caída, restringida por región o no ser compatible.';
      });
      debugPrint('Error del reproductor directo: $error');
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _player;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() => _playerError = 'No se pudo cambiar el estado del reproductor.');
      }
      debugPrint('Error al controlar el reproductor: $error');
    }
  }

  Future<void> _stopPlayback() async {
    final oldPlayer = _player;
    _player = null;
    await _disposePlayer(oldPlayer);
    if (!mounted) return;
    setState(() {
      _selectedEventId = null;
      _loadingPlayer = false;
      _playerError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = _eventItems();
    final liveItems = items
        .where((item) => _isLiveNow(item.event, now))
        .toList(growable: false);
    final upcomingItems = items
        .where((item) => now.isBefore(item.event.startsAt))
        .toList(growable: false);
    final selectedItem = items.where(
      (item) => item.event.id == _selectedEventId,
    ).firstOrNull;
    final player = _player;

    return Scaffold(
      backgroundColor: _liveBackground,
      appBar: AppBar(
        backgroundColor: _liveBackground,
        title: const Text(
          'TRANSMISIÓN EN VIVO',
          style: TextStyle(
            color: _liveBlue,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar eventos',
            onPressed: _refreshing ? null : _refreshBoard,
            icon: Icon(
              Icons.refresh_rounded,
              color: _refreshing ? _liveBlue.withAlpha(100) : _liveBlue,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildFixedPlayer(player, selectedItem),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: const BoxDecoration(
              color: _livePanel,
              border: Border(
                top: BorderSide(color: _liveLine),
                bottom: BorderSide(color: _liveLine),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.sensors_rounded, color: _liveGreen, size: 16),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${liveItems.length} en directo · ${upcomingItems.length} próximos · ${_board.catalogueChannelCount} señales revisadas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _liveMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_refreshing || _loadingBoard)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _liveBlue,
                    ),
                  ),
              ],
            ),
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                _notice!,
                style: const TextStyle(
                  color: Color(0xFFFFC3CE),
                  fontSize: 10,
                ),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshBoard,
                    color: _liveBlue,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                      children: <Widget>[
                        if (liveItems.isNotEmpty) ...<Widget>[
                          _sectionHeading('EN DIRECTO', liveItems.length, _liveGreen),
                          const SizedBox(height: 8),
                          for (final item in liveItems)
                            _eventCard(item, now),
                        ],
                        if (upcomingItems.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          _sectionHeading('PRÓXIMOS EVENTOS', upcomingItems.length, _liveBlue),
                          const SizedBox(height: 8),
                          for (final item in upcomingItems)
                            _eventCard(item, now),
                        ],
                        if (liveItems.isEmpty && upcomingItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'No hay eventos activos publicados en la agenda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _liveMuted),
                            ),
                          ),
                        if (_lastUpdated != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            'Actualizado ${_timeLabel(_lastUpdated!)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF7F91A8),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedPlayer(
    VideoPlayerController? player,
    _LiveEventItem? selectedItem,
  ) {
    final initialized = player?.value.isInitialized == true;
    final title = selectedItem?.event.title ?? 'Selecciona un evento para reproducirlo';

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 9),
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (initialized)
                    VideoPlayer(player!)
                  else
                    SvgPicture.asset(
                      'assets/images/live_theme.svg',
                      fit: BoxFit.cover,
                      placeholderBuilder: (_) => const ColoredBox(
                        color: Color(0xFF08172B),
                        child: Center(
                          child: Icon(
                            Icons.sports_soccer_rounded,
                            size: 55,
                            color: _liveBlue,
                          ),
                        ),
                      ),
                    ),
                  if (initialized)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 38,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              Color(0xD9000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (initialized)
                    Positioned(
                      left: 7,
                      bottom: 6,
                      child: IconButton.filled(
                        onPressed: _togglePlayback,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xCC07111F),
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          player!.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                  if (!initialized && !_loadingPlayer)
                    Container(
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(13),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Color(0xB8000000),
                          ],
                        ),
                      ),
                      child: const Text(
                        'DEPORTE TOTAL 360°  ·  CANCHA EN DIRECTO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  if (_loadingPlayer)
                    const ColoredBox(
                      color: Color(0x99000000),
                      child: Center(
                        child: CircularProgressIndicator(color: _liveGreen),
                      ),
                    ),
                  if (_playerError != null)
                    Container(
                      color: const Color(0xC9000000),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _playerError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              if (player != null || _selectedEventId != null)
                TextButton(
                  onPressed: _stopPlayback,
                  child: const Text(
                    'DETENER',
                    style: TextStyle(
                      color: _liveRed,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, int count, Color accent) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _eventCard(_LiveEventItem item, DateTime now) {
    final event = item.event;
    final assignment = item.assignment;
    final isLive = _isLiveNow(event, now);
    final isUpcoming = now.isBefore(event.startsAt);
    final channel = assignment?.channel;
    final canPlay = isLive &&
        channel != null &&
        isSupportedChannelPlaybackUrl(channel.url);
    final isSelected = _selectedEventId == event.id;
    final time = _timeLabel(event.startsAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _livePanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? _liveBlue : _liveLine,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: isLive
                  ? _liveGreen.withAlpha(18)
                  : _liveBlue.withAlpha(18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  isLive ? Icons.sensors_rounded : Icons.schedule_rounded,
                  color: isLive ? _liveGreen : _liveBlue,
                  size: 19,
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                if (event.competition.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    event.competition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _liveMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  channel?.name ??
                      item.pending?.status ??
                      'Buscando señal directa compatible',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: channel != null ? _liveBlue : _liveMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.pending != null && !isUpcoming)
                  Text(
                    item.pending!.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFC3CE),
                      fontSize: 8,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canPlay)
            FilledButton.icon(
              onPressed: () => _playAssignment(assignment!),
              icon: const Icon(Icons.play_arrow_rounded, size: 17),
              label: const Text('REPRODUCIR'),
              style: FilledButton.styleFrom(
                backgroundColor: _liveGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                textStyle: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(minWidth: 74),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(70),
                border: Border.all(color: _liveLine),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                isUpcoming
                    ? 'A LAS $time'
                    : 'SIN SEÑAL',
                textAlign: TextAlign.center,
                style: const TextStyle(
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

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 18),
        const Icon(
          Icons.event_busy_rounded,
          color: _liveBlue,
          size: 48,
        ),
        const SizedBox(height: 12),
        const Text(
          'Todavía no hay eventos capturados',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Abre Agenda para cargar la programación. La aplicación guarda los datos del evento y los nombres de canales publicados para organizarlos aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _liveMuted,
            fontSize: 11,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 15),
        Center(
          child: FilledButton.icon(
            onPressed: widget.onOpenAgenda,
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('ABRIR AGENDA'),
          ),
        ),
        if (_loadingBoard || _refreshing) ...<Widget>[
          const SizedBox(height: 18),
          const Center(
            child: CircularProgressIndicator(color: _liveGreen),
          ),
        ],
      ],
    );
  }
}

class _LiveEventItem {
  const _LiveEventItem({
    required this.event,
    this.assignment,
    this.pending,
  });

  final AgendaEventReference event;
  final AgendaLiveAssignment? assignment;
  final AgendaLivePendingEvent? pending;
}

extension _LiveFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
