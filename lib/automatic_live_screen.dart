import 'app_section_design.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'automatic_live_service.dart';
import 'channel_catalog_service.dart';
import 'sportsapi_app_service.dart';
import 'live_channels_screen.dart';

const Color _autoBg = Color(0xFF000000);
const Color _autoCyan = Color(0xFF00A3FF);

class AutomaticLiveScreen extends StatefulWidget {
  const AutomaticLiveScreen({
    super.key,
    required this.onOpenAgenda,
    this.isActive = true,
    this.selectedEventId,
  });

  final VoidCallback onOpenAgenda;
  final bool isActive;
  final String? selectedEventId;

  @override
  State<AutomaticLiveScreen> createState() => _AutomaticLiveScreenState();
}

class _AutomaticLiveScreenState extends State<AutomaticLiveScreen>
    with WidgetsBindingObserver {
  final AutomaticLiveService _service = AutomaticLiveService();
  final ChannelCatalogService _channelCatalog = channelCatalogService;
  List<SportsChannel>? _selectedChannelCache;
  DateTime? _selectedChannelCacheAt;
  List<ScheduledLiveEvent> _scheduled = <ScheduledLiveEvent>[];
  List<SportsAgendaEvent> _agendaEvents = <SportsAgendaEvent>[];
  final Map<String, DateTime> _knownEventEndTimes = <String, DateTime>{};
  Timer? _refreshTimer;
  Timer? _eventBoundaryTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // La búsqueda previa al evento continúa aunque el usuario esté en otra
    // pestaña. El tablero de vídeo sigue respetando widget.isActive.
    _refresh(force: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant AutomaticLiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.isActive && widget.isActive) ||
        oldWidget.selectedEventId != widget.selectedEventId) {
      _refresh(force: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _eventBoundaryTimer?.cancel();
    super.dispose();
  }

  Future<List<M3uChannel>> _loadSelectedSportsChannels({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cached = _selectedChannelCache;
    if (!forceRefresh && cached != null && _selectedChannelCacheAt != null &&
        now.difference(_selectedChannelCacheAt!) < const Duration(minutes: 30)) {
      return cached.map((channel) => M3uChannel(
        name: channel.name, url: channel.url, tvgId: channel.identifier,
        tvgName: channel.name, group: channel.groupTitle, language: channel.language,
      )).toList(growable: false);
    }
    final selected = <SportsChannel>[];
    var offset = 0;
    for (var pageNumber = 0; pageNumber < 100; pageNumber++) {
      final page = await _channelCatalog.fetchPublicChannelPage(offset: offset, limit: 2000);
      selected.addAll(page.channels.where((channel) => channel.isSports && channel.visible));
      if (!page.hasMore || page.channels.isEmpty) break;
      if (pageNumber == 99) {
        throw StateError('El catálogo seleccionado supera el límite seguro de páginas.');
      }
      final nextOffset = page.offset + page.channels.length;
      if (nextOffset <= offset) throw StateError('El catálogo no avanzó a la siguiente página.');
      offset = nextOffset;
    }
    _selectedChannelCache = List<SportsChannel>.unmodifiable(selected);
    _selectedChannelCacheAt = now;
    return selected.map((channel) => M3uChannel(
      name: channel.name, url: channel.url, tvgId: channel.identifier,
      tvgName: channel.name, group: channel.groupTitle, language: channel.language,
    )).toList(growable: false);
  }

  Future<void> _refresh({bool force = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});

    try {
      // SportsAPI proporciona el calendario; el catálogo del propietario
      // aporta las URL directas que se pueden asignar a cada evento.
      final settings = await AutoLiveSettings.load();
      final localEvents = await SportsAgendaStore.load();
      List<SportsAgendaEvent> events;
      try {
        // El tablero Live obtiene primero los diez deportes favoritos, aunque
        // el usuario nunca haya abierto la pestaña Agenda.
        final window = await SportsApiAppService().fetchFavoriteAgendaWindow(
          startDate: DateTime.now(),
          days: 7,
        );
        events = window.events;
        await SportsAgendaStore.saveWindow(
          events,
          startDate: window.startDate,
          days: window.days,
        );
      } catch (_) {
        events = localEvents;
      }

      // Primero se consume el calendario persistente que prepara Cloudflare
      // aunque ningún teléfono tenga la APK abierta. Si el Worker aún no lo ha
      // generado o está temporalmente fuera de línea, se conserva el motor local.
      final published = await _service.fetchPublishedSchedule();
      List<ScheduledLiveEvent> latest;
      if (published != null) {
        latest = published;
      } else {
        final selectedChannels =
            await _loadSelectedSportsChannels(forceRefresh: force);
        latest = selectedChannels.isNotEmpty
            ? await _service.schedule(
                events: events,
                now: DateTime.now(),
                settings: settings,
                availableChannels: selectedChannels,
                forceRefresh: force,
              )
            : <ScheduledLiveEvent>[];
      }      if (!mounted) return;
      setState(() {
        _agendaEvents = events;
        _scheduled = latest;
      });
      _scheduleEventBoundaryRefresh();
    } catch (_) {
      // Un fallo temporal no borra las asignaciones vigentes.
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  /// Cada evento puede ocupar dos cuadros: mejor canal español y mejor inglés.
  List<LivePlayerSource> _playerSources() {
    final now = DateTime.now();
    final ordered = List<ScheduledLiveEvent>.of(_scheduled)
      ..sort((a, b) {
        final aSelected = a.event.id == widget.selectedEventId;
        final bSelected = b.event.id == widget.selectedEventId;
        if (aSelected != bSelected) return aSelected ? -1 : 1;
        return a.event.startsAt.compareTo(b.event.startsAt);
      });
    final usedUrls = <String>{};
    final result = <LivePlayerSource>[];
    for (final item in ordered) {
      if (result.length >= 8) break;
      if (now.isBefore(item.event.startsAt) || !now.isBefore(item.removeAt)) continue;
      final event = item.event;
      final teams = event.homeTeam.isNotEmpty && event.awayTeam.isNotEmpty
          ? '${event.homeTeam} vs ${event.awayTeam}'
          : event.title;
      for (final candidate in item.sources) {
        if (result.length >= 8) break;
        if (!candidate.available || !isDirectPlayableStream(candidate.url) ||
            !usedUrls.add(candidate.url)) continue;
        final languageLabel = candidate.languagePriority == 2
            ? 'ESPAÑOL'
            : candidate.languagePriority == 1 ? 'ENGLISH' : 'IDIOMA NO CONFIRMADO';
        final details = <String>[
          event.sport,
          if (event.competition.isNotEmpty) event.competition,
          teams, languageLabel, candidate.channelName,
        ];
        result.add(LivePlayerSource(
          title: 'DEPORTE TOTAL 360° CANAL ${result.length + 1} · $languageLabel',
          url: candidate.url,
          subtitle: details.join(' · '),
          eventId: event.id,
        ));
      }
    }
    return result;
  }

  List<LivePlayerWaitingEvent> _waitingEvents(
    List<LivePlayerSource> activeSources,
  ) {
    final now = DateTime.now();
    final activeEventIds = activeSources
        .map((source) => source.eventId)
        .whereType<String>()
        .toSet();
    final upcoming = _agendaEvents.where((event) {
      if (activeEventIds.contains(event.id)) return false;
      if (const <String>{'finished', 'cancelled', 'postponed'}
          .contains(event.status.toLowerCase())) return false;
      final end = _knownEventEndTimes[event.id] ??
          event.endsAt ??
          event.startsAt.add(const Duration(hours: 3));
      return now.isBefore(end);
    }).toList()
      ..sort((a, b) {
        final aSelected = a.id == widget.selectedEventId;
        final bSelected = b.id == widget.selectedEventId;
        if (aSelected != bSelected) return aSelected ? -1 : 1;
        return a.startsAt.compareTo(b.startsAt);
      });

    return upcoming
        .take(8 - activeSources.length)
        .map((event) {
          final teams = event.homeTeam.isNotEmpty && event.awayTeam.isNotEmpty
              ? '${event.homeTeam} vs ${event.awayTeam}'
              : event.title;
          final localStart = event.startsAt.toLocal();
          final time =
              '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}';
          final heading = event.competition.isNotEmpty
              ? '${event.sport} · ${event.competition}'
              : event.sport;
          final startLabel = now.isBefore(event.startsAt)
              ? 'Comienza $time'
              : 'Evento iniciado · $time';
          return LivePlayerWaitingEvent(
            heading: heading,
            match: teams,
            startLabel: startLabel,
          );
        })
        .toList(growable: false);
  }

  /// Actualiza justo al inicio o al fin del evento, además del control
  /// periódico del catálogo que continúa ejecutándose cada 45 segundos.
  void _scheduleEventBoundaryRefresh() {
    _eventBoundaryTimer?.cancel();
    final now = DateTime.now();
    final boundaries = <DateTime>[
      for (final item in _scheduled) ...<DateTime>[
        item.event.startsAt,
        item.removeAt,
      ],
    ].where((date) => date.isAfter(now)).toList()
      ..sort();

    if (boundaries.isEmpty) return;
    final delay = boundaries.first.difference(now) +
        const Duration(milliseconds: 150);
    _eventBoundaryTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleEventBoundaryRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeSources = _playerSources();
    final waitingEvents = _waitingEvents(activeSources);
    return Scaffold(
      backgroundColor: _autoBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        title: const AppSectionTitle(
          icon: Icons.live_tv_rounded,
          title: 'TRANSMISIONES EN VIVO',
          accent: _autoCyan,
          subtitle: 'PARTIDOS Y EVENTOS EN DIRECTO',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _refreshing ? null : () => _refresh(force: true),
            tooltip: 'Actualizar transmisiones',
            icon: Icon(
              Icons.refresh_rounded,
              color: _refreshing ? _autoCyan.withAlpha(110) : _autoCyan,
            ),
          ),
        ],
      ),
      body: LivePlayerBoard(
        sources: activeSources,
        waitingEvents: waitingEvents,
        isActive: widget.isActive,
        prioritizedEventId: widget.selectedEventId,
      ),
    );
  }
}
