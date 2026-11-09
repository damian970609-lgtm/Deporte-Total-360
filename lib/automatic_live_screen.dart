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
  AutoLiveProgress? _progress;
  String? _refreshNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // La pantalla se crea al abrir la pestaña; las consultas periódicas
    // solo continúan mientras En Vivo está visible y Android está en primer plano.
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
    _refreshNotice = null;
    if (mounted) {
      setState(() {
        _progress = AutoLiveProgress(
          stage: 'loading_events',
          message: 'Leyendo la Agenda guardada en este teléfono.',
        );
      });
    }

    var events = <SportsAgendaEvent>[];
    var selectedChannels = <M3uChannel>[];
    try {
      final settings = await AutoLiveSettings.load();
      final today = DateTime.now();
      // En Vivo reutiliza primero exactamente la jornada que Agenda guardó.
      // Solo vuelve a SportsAPI si la captura diaria falta o venció.
      events = await SportsAgendaStore.loadWindow(
        startDate: today,
        days: 1,
      );
      final agendaIsFresh = await SportsAgendaStore.isWindowFresh(
        startDate: today,
        maxAge: const Duration(hours: 24),
      );
      if (!agendaIsFresh || force) {
        if (mounted) {
          setState(() {
            _progress = AutoLiveProgress(
              stage: 'loading_events',
              message: 'La caché no está vigente. Consultando SportAPI para hoy.',
              eventCount: events.length,
            );
          });
        }
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
            complete: window.unavailableDates.isEmpty,
          );
        } catch (error) {
          _refreshNotice = 'No se pudo actualizar SportAPI; se conserva la agenda local. $error';
        }
      }

      if (mounted) {
        setState(() {
          _progress = AutoLiveProgress(
            stage: 'loading_channels',
            message: 'Agenda leída: ${events.length} evento(s). Leyendo los canales visibles de Damián APK.',
            eventCount: events.length,
          );
        });
      }
      // No consultar /api/live/auto/schedule: la asignación local se calcula
      // con los canales elegidos por el usuario y las guías EPG.
      selectedChannels = await _loadSelectedSportsChannels(forceRefresh: force);
      if (mounted) {
        setState(() {
          _progress = AutoLiveProgress(
            stage: 'loading_guides',
            message: 'Canales leídos. Iniciando cruce con las guías EPG.',
            eventCount: events.length,
            channelCount: selectedChannels.length,
            directChannelCount: selectedChannels.where(
              (channel) => isDirectPlayableStream(channel.url),
            ).length,
          );
        });
      }
      final latest = await _service.schedule(
        events: events,
        now: DateTime.now(),
        settings: settings,
        availableChannels: selectedChannels,
        forceRefresh: force,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );

      if (!mounted) return;
      setState(() {
        _agendaEvents = events;
        _scheduled = latest;
      });
      _scheduleEventBoundaryRefresh();
    } catch (error) {
      if (mounted) {
        final detail = error.toString();
        setState(() {
          _refreshNotice = detail;
          _progress = AutoLiveProgress(
            stage: 'error',
            message: 'El proceso se detuvo durante la carga: ${detail.length > 180 ? detail.substring(0, 180) + '…' : detail}',
            eventCount: events.length,
            channelCount: selectedChannels.length,
            directChannelCount: selectedChannels.where(
              (channel) => isDirectPlayableStream(channel.url),
            ).length,
          );
        });
      }
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
          final prepareAt = event.startsAt.subtract(const Duration(minutes: 10));
          final processStatus = now.isBefore(prepareAt)
              ? 'ESPERANDO VENTANA DE PREPARACIÓN'
              : now.isBefore(event.startsAt)
                  ? 'BUSCANDO SEÑAL ANTES DEL INICIO'
                  : _waitingProcessStatus();
          return LivePlayerWaitingEvent(
            heading: heading,
            match: teams,
            startLabel: startLabel,
            processStatus: processStatus,
            processDetail: _progress?.message ??
                'Se comprobarán los canales seleccionados y la guía EPG.',
          );
        })
        .toList(growable: false);
  }

  String _waitingProcessStatus() {
    switch (_progress?.stage ?? '') {
      case 'loading_events':
      case 'starting':
        return 'CARGANDO EVENTOS';
      case 'loading_channels':
      case 'channels_empty':
        return 'REVISANDO CANALES SELECCIONADOS';
      case 'loading_guides':
      case 'epg_empty':
      case 'epg_config_missing':
        return 'LEYENDO GUÍA EPG';
      case 'matching_epg':
      case 'programme_not_matched':
        return 'BUSCANDO COINCIDENCIA DEL EVENTO';
      case 'checking_signals':
      case 'signals_unavailable':
        return 'COMPROBANDO DISPONIBILIDAD DE LA SEÑAL';
      case 'channel_not_mapped':
        return 'CANAL SIN VINCULAR A LA GUÍA';
      case 'ready':
        return 'SEÑAL PREPARADA';
      case 'agenda_empty':
        return 'NO HAY EVENTOS EN LA AGENDA';
      case 'outside_window':
        return 'FUERA DE LA VENTANA DE PREPARACIÓN';
      case 'configuration_missing':
        return 'FALTA CONFIGURACIÓN';
      case 'error':
        return 'ERROR DURANTE LA COMPROBACIÓN';
      default:
        return _refreshing ? 'PROCESO EN CURSO' : 'ESPERANDO COMPROBACIÓN';
    }
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


  Widget _buildProcessPanel() {
    final progress = _progress;
    final stage = progress?.stage ?? '';
    final isError = const <String>{
      'error', 'signals_unavailable', 'programme_not_matched',
      'channel_not_mapped', 'epg_empty', 'channels_empty', 'agenda_empty',
      'epg_config_missing', 'configuration_missing',
    }.contains(stage);
    Widget metric(String label, int value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1118),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _autoCyan.withAlpha(75)),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(9, 8, 9, 3),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF07090D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? const Color(0xFFFF1744) : _autoCyan.withAlpha(150),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _refreshing
                    ? Icons.sync_rounded
                    : isError
                        ? Icons.warning_amber_rounded
                        : stage == 'ready'
                            ? Icons.check_circle_rounded
                            : Icons.monitor_heart_rounded,
                size: 15,
                color: isError ? const Color(0xFFFF1744) : _autoCyan,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'PROCESO DE TRANSMISIONES',
                  style: TextStyle(
                    color: _autoCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
                ),
              ),
              Text(
                _refreshing ? 'EN CURSO' : 'DIAGNÓSTICO',
                style: TextStyle(
                  color: _refreshing ? _autoCyan : Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            progress?.message ?? 'Esperando la primera comprobación.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: <Widget>[
              metric('Eventos', progress?.eventCount ?? _agendaEvents.length),
              metric('Canales', progress?.channelCount ?? 0),
              metric('Directos', progress?.directChannelCount ?? 0),
              metric('EPG', progress?.programmeCount ?? 0),
              metric('Coinciden', progress?.matchedEventCount ?? 0),
              metric('Candidatos', progress?.candidateCount ?? 0),
              metric('Probados', progress?.testedCandidateCount ?? 0),
              metric('Disponibles', progress?.availableCandidateCount ?? 0),
            ],
          ),
          if (_refreshNotice != null && _refreshNotice!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 5),
            Text(
              _refreshNotice!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFB4C0),
                fontSize: 8,
              ),
            ),
          ],
        ],
      ),
    );
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
      body: Column(
        children: <Widget>[
          _buildProcessPanel(),
          Expanded(
            child: LivePlayerBoard(
              sources: activeSources,
              waitingEvents: waitingEvents,
              isActive: widget.isActive,
              prioritizedEventId: widget.selectedEventId,
            ),
          ),
        ],
      ),
    );
  }
}
