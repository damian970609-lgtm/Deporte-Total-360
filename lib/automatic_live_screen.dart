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
    if (widget.isActive) _refresh();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      // El tablero no consulta API/Cloudflare cuando el usuario está en otra
      // pestaña o Android mantiene la app en segundo plano.
      if (mounted &&
          widget.isActive &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _refresh();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AutomaticLiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive &&
        (!oldWidget.isActive ||
            oldWidget.selectedEventId != widget.selectedEventId)) {
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      // Solo la pestaña visible se actualiza al volver a primer plano.
      // Se respeta el snapshot local y sus tiempos de validez.
      _refresh();
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
    const snapshotMaxAge = Duration(minutes: 15);
    const memoryMaxAge = Duration(minutes: 15);

    List<M3uChannel> asM3u(List<SportsChannel> channels) => channels
        .map((channel) => M3uChannel(
              name: channel.name,
              url: channel.url,
              tvgId: channel.identifier,
              tvgName: channel.name,
              group: channel.groupTitle,
              language: channel.language,
            ))
        .toList(growable: false);

    if (!forceRefresh && cached != null && _selectedChannelCacheAt != null &&
        now.difference(_selectedChannelCacheAt!) < memoryMaxAge) {
      return asM3u(cached);
    }

    // Primero usamos el snapshot local. Solo consultamos todas las páginas del
    // Durable Object cuando el snapshot tiene más de 15 minutos o no existe.
    var localSnapshot = <SportsChannel>[];
    if (!forceRefresh) {
      localSnapshot = await loadCachedVisibleSportsChannels();
      if (localSnapshot.isNotEmpty &&
          await isCachedPublicChannelSnapshotFresh(maxAge: snapshotMaxAge)) {
        _selectedChannelCache = List<SportsChannel>.unmodifiable(localSnapshot);
        _selectedChannelCacheAt = now;
        return asM3u(localSnapshot);
      }
    }

    try {
      final allChannels = <SportsChannel>[];
      var offset = 0;
      for (var pageNumber = 0; pageNumber < 100; pageNumber++) {
        final page = await _channelCatalog.fetchPublicChannelPage(
          offset: offset,
          limit: 2000,
        );
        if (page.channels.isEmpty && page.hasMore) {
          throw StateError('El catálogo no entregó la siguiente página.');
        }
        allChannels.addAll(page.channels);
        if (!page.hasMore || page.channels.isEmpty) break;
        if (pageNumber == 99) {
          throw StateError('El catálogo seleccionado supera el límite seguro de páginas.');
        }
        final nextOffset = page.offset + page.channels.length;
        if (nextOffset <= offset) {
          throw StateError('El catálogo no avanzó a la siguiente página.');
        }
        offset = nextOffset;
      }

      await saveCachedPublicChannelSnapshot(allChannels);
      final selected = allChannels
          .where((channel) => channel.isSports && channel.visible)
          .toList(growable: false);
      _selectedChannelCache = List<SportsChannel>.unmodifiable(selected);
      _selectedChannelCacheAt = now;
      return asM3u(selected);
    } catch (_) {
      // El tablero conserva la última selección confirmada aunque Cloudflare
      // esté limitado. No se sustituye por listas genéricas ni por canales ocultos.
      final local = localSnapshot.isNotEmpty
          ? localSnapshot
          : (cached != null && cached.isNotEmpty
              ? cached
              : await loadCachedVisibleSportsChannels());
      if (local.isNotEmpty) {
        _selectedChannelCache = List<SportsChannel>.unmodifiable(local);
        _selectedChannelCacheAt = now;
        return asM3u(local);
      }
      rethrow;
    }
  }

  Future<void> _refresh({bool force = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});

    try {
      final settings = await AutoLiveSettings.load();
      final today = DateTime.now();
      // En Vivo lee primero exactamente la jornada local que Agenda ya guardó.
      // Solo vuelve a SportsAPI si esa captura diaria falta o venció; el sondeo
      // de dos minutos queda limitado al cálculo local de señales/horarios.
      var events = await SportsAgendaStore.loadWindow(
        startDate: today,
        days: 1,
      );
      final agendaIsFresh = await SportsAgendaStore.isWindowFresh(
        startDate: today,
        maxAge: const Duration(hours: 24),
      );
      if (!agendaIsFresh || force) {
        try {
          final window = await SportsApiAppService().fetchFavoriteAgendaWindow(
            startDate: today,
            days: 1,
          );
          events = window.events;
          await SportsAgendaStore.saveWindow(
            events,
            startDate: window.startDate,
            days: 1,
          );
        } catch (_) {
          // La copia del teléfono se conserva cuando el Worker/API está limitado.
        }
      }

      // No consultar /api/live/auto/schedule: esa ruta no está implementada en
      // el Worker. La asignación se calcula con los canales visibles escogidos
      // en Damián APK y las guías EPG configuradas en este dispositivo.
      final selectedChannels =
          await _loadSelectedSportsChannels(forceRefresh: force);
      final latest = selectedChannels.isNotEmpty
          ? await _service.schedule(
              events: events,
              now: DateTime.now(),
              settings: settings,
              availableChannels: selectedChannels,
              forceRefresh: force,
            )
          : <ScheduledLiveEvent>[];

      if (!mounted) return;
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

  /// Recalcula los límites de inicio y fin de evento sin consultar servicios.
  /// Las consultas de red solo se ejecutan mientras En Vivo está visible.
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
