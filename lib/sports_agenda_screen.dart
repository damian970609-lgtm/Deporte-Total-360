import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_section_design.dart';
import 'automatic_live_service.dart';
import 'notification_service.dart';
import 'sports_api_service.dart';
import 'sportsapi_app_service.dart';

const Color _agendaBg = Color(0xFF000000);
const Color _agendaPanel = Color(0xFF07090D);
const Color _agendaLine = Color(0xFF0047FF);
const Color _agendaCyan = Color(0xFF00A3FF);
const Color _agendaGreen = Color(0xFF39FF14);
const Color _agendaPink = Color(0xFFFF1744);
const Color _agendaMuted = Color(0xFFEAF0F8);
const Color _agendaRed = Color(0xFFFF1744);

typedef AgendaEventsLoader = Future<List<SportsAgendaEvent>?> Function();

/// Agenda principal: consulta hoy y los seis días siguientes, conserva una
/// caché por fecha y permite abrir en Deportes en vivo el evento seleccionado.
class SportsAgendaScreen extends StatefulWidget {
  const SportsAgendaScreen({
    super.key,
    required this.onOpenLive,
    this.isActive = true,
    this.loadEvents,
    this.initialDate,
  });

  final ValueChanged<String> onOpenLive;
  final bool isActive;
  final DateTime? initialDate;

  @visibleForTesting
  final AgendaEventsLoader? loadEvents;

  @override
  State<SportsAgendaScreen> createState() => _SportsAgendaScreenState();
}

class _SportsAgendaScreenState extends State<SportsAgendaScreen>
    with WidgetsBindingObserver {
  static const int _windowDays = 1;
  late DateTime _windowStartDate;
  late DateTime _selectedDate;

  List<SportsAgendaEvent> _events = <SportsAgendaEvent>[];
  List<DateTime> _unavailableDates = <DateTime>[];
  List<String> _favoriteSportNames = <String>[];
  Timer? _refreshTimer;
  bool _loading = true;
  bool _hasLoaded = false;
  bool _refreshing = false;
  String? _error;
  String _selectedSport = 'Todos';
  String _statusFilter = 'Todos';
  String _query = '';
  int _refreshVersion = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _windowStartDate = _dateOnly(DateTime.now());
    _selectedDate = _windowStartDate;
    if (_selectedDate.isBefore(_windowStartDate) ||
        !_selectedDate.isBefore(
          _windowStartDate.add(const Duration(days: _windowDays)),
        )) {
      _selectedDate = _windowStartDate;
    }
    NotificationService.matchRemindersEnabled.addListener(
      _onReminderPreferenceChanged,
    );
    _refresh();
    _syncRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant SportsAgendaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncRefreshTimer();
      if (widget.isActive) _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.matchRemindersEnabled.removeListener(
      _onReminderPreferenceChanged,
    );
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime first, DateTime second) {
    final a = first.toLocal();
    final b = second.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _syncRefreshTimer() {
    // La jornada se obtiene una vez y queda guardada en el teléfono.
    // No repetimos la descarga completa cada tres minutos ni al volver a la
    // pestaña; la actualización manual evita consumir cuota innecesaria.
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<SportsAgendaWindow> _loadWindow({
    bool forceRefresh = false,
    void Function(SportsAgendaWindow window)? onProgress,
  }) async {
    final injectedLoader = widget.loadEvents;
    if (injectedLoader != null) {
      final events = await injectedLoader() ?? <SportsAgendaEvent>[];
      final sports = events.map((event) => event.sport.trim())
          .where((sport) => sport.isNotEmpty).toSet().toList()..sort();
      if (mounted) setState(() => _favoriteSportNames = sports);
      final window = SportsAgendaWindow(
        startDate: _windowStartDate,
        days: _windowDays,
        events: events,
      );
      onProgress?.call(window);
      return window;
    }

    try {
      final agendaApi = SportsApiAppService();
      try {
        final sports = await agendaApi.fetchFavoriteAgendaSportNames(
          forceRefresh: forceRefresh,
        );
        if (mounted) setState(() => _favoriteSportNames = sports);
      } catch (_) {
        // La falta del catálogo no debe bloquear los eventos ni la caché local.
      }
      final window = await agendaApi.fetchFavoriteAgendaWindow(
        startDate: _windowStartDate,
        days: _windowDays,
        forceRefresh: forceRefresh,
        onProgress: onProgress,
      );
      if (window.unavailableDates.length == window.days &&
          window.events.isEmpty) {
        throw const SportsApiException(
          'No respondió ninguna fecha de la agenda.',
        );
      }

      var events = List<SportsAgendaEvent>.of(window.events);
      var unavailable = List<DateTime>.of(window.unavailableDates);
      if (unavailable.isNotEmpty) {
        final stored = await SportsAgendaStore.load();
        for (final event in stored) {
          if (unavailable.any((day) => _sameDay(day, event.startsAt))) {
            events.add(event);
          }
        }
        // Recuperar eventos guardados no convierte una fecha en completa:
        // puede seguir faltando el calendario de otro deporte o competición.
      }

      final unique = <String, SportsAgendaEvent>{
        for (final event in events) event.id: event,
      };
      final result = unique.values.toList(growable: false)
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      await SportsAgendaStore.saveWindow(
        result,
        startDate: window.startDate,
        days: window.days,
      );
      return SportsAgendaWindow(
        startDate: window.startDate,
        days: window.days,
        events: result,
        unavailableDates: unavailable,
      );
    } catch (_) {
      // El calendario automático puede contener solo el próximo evento.
      // Nunca debe sustituir silenciosamente la ventana completa de SportAPI.
      final end = _windowStartDate.add(const Duration(days: _windowDays));
      final byId = <String, SportsAgendaEvent>{};
      // SportsAgendaStore solo guarda eventos que ya pasaron por el filtro de
      // deportes y ligas favoritas. No volver a consultar /favorites aquí:
      // ese segundo viaje al Worker anulaba precisamente el respaldo sin cuota.
      final agendaApi = SportsApiAppService();
      try {
        final published = await AutomaticLiveService().fetchPublishedSchedule();
        if (published != null) {
          final filteredPublished = await agendaApi.filterFavoriteAgendaEvents(
            published.map((item) => item.event),
          );
          for (final event in filteredPublished) {
            final localStart = event.startsAt.toLocal();
            if (!localStart.isBefore(_windowStartDate) &&
                localStart.isBefore(end)) {
              byId[event.id] = event;
            }
          }
        }
      } catch (_) {
        // La copia persistente local sigue siendo suficiente para abrir Agenda.
      }
      final stored = await SportsAgendaStore.loadWindow(
        startDate: _windowStartDate,
        days: _windowDays,
      );
      final selectedStored =
          await agendaApi.filterFavoriteAgendaEvents(stored);
      for (final event in selectedStored) {
        byId.putIfAbsent(event.id, () => event);
      }
      if (mounted && _favoriteSportNames.isEmpty && selectedStored.isNotEmpty) {
        final cachedSports = selectedStored
            .map((event) => event.sport.trim())
            .where((sport) => sport.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        if (cachedSports.isNotEmpty) {
          setState(() => _favoriteSportNames = cachedSports);
        }
      }
      final fallbackEvents = byId.values.toList(growable: false)
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      if (fallbackEvents.isNotEmpty) {
        return SportsAgendaWindow(
          startDate: _windowStartDate,
          days: _windowDays,
          events: fallbackEvents,
          unavailableDates: List<DateTime>.generate(
            _windowDays,
            (index) => _windowStartDate.add(Duration(days: index)),
            growable: false,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _refresh({bool forceRefresh = false}) async {
    if (_refreshing) return;
    final today = _dateOnly(DateTime.now());
    final dayChanged = !_sameDay(today, _windowStartDate);
    if (dayChanged) {
      _windowStartDate = today;
      _selectedDate = today;
      _selectedSport = 'Todos';
      _statusFilter = 'Todos';
      _query = '';
      _searchController.clear();
      _events = <SportsAgendaEvent>[];
      _unavailableDates = <DateTime>[];
      _hasLoaded = false;
    }

    _refreshing = true;
    final version = ++_refreshVersion;

    // Primero pinta la jornada guardada. Si es del mismo día y sigue vigente,
    // no vuelve a consultar el calendario completo al abrir o reanudar la APK.
    if (!forceRefresh && widget.loadEvents == null) {
      try {
        final agendaApi = SportsApiAppService();
        final stored = await SportsAgendaStore.loadWindow(
          startDate: _windowStartDate,
          days: _windowDays,
        );
        final cached = await agendaApi.filterFavoriteAgendaEvents(stored);
        if (!mounted || version != _refreshVersion) return;
        if (cached.isNotEmpty || await SportsAgendaStore.isWindowFresh(
          startDate: _windowStartDate,
        )) {
          final sports = await agendaApi.fetchFavoriteAgendaSportNames();
          if (!mounted || version != _refreshVersion) return;
          setState(() {
            _events = cached;
            _favoriteSportNames = sports;
            _unavailableDates = <DateTime>[];
            _loading = false;
            _hasLoaded = true;
            _error = null;
          });
          unawaited(_syncMatchReminders(cached));
          if (await SportsAgendaStore.isWindowFresh(
            startDate: _windowStartDate,
          )) {
            _refreshing = false;
            return;
          }
        }
      } catch (_) {
        // Si la copia local no se puede leer o filtrar, se intenta actualizar.
      }
    }

    if (mounted) {
      setState(() {
        if (!_hasLoaded) _loading = true;
        _error = null;
      });
    }

    try {
      final window = await _loadWindow(
        forceRefresh: forceRefresh,
        onProgress: (partial) {
          if (!mounted || version != _refreshVersion) return;
          setState(() {
            _events = partial.events;
            _unavailableDates = partial.unavailableDates;
            _hasLoaded = true;
          });
        },
      );
      if (!mounted || version != _refreshVersion) return;
      final availableSports = <String>{
        ..._favoriteSportNames,
        ...window.events.map((event) => event.sport.trim())
            .where((sport) => sport.isNotEmpty),
      };
      setState(() {
        _events = window.events;
        if (!availableSports.contains(_selectedSport)) {
          _selectedSport = 'Todos';
        }
        _unavailableDates = window.unavailableDates;
        _loading = false;
        _hasLoaded = true;
      });
      unawaited(_syncMatchReminders(window.events));
    } catch (error) {
      if (!mounted || version != _refreshVersion) return;
      setState(() {
        _loading = false;
        _hasLoaded = true;
        _error =
            'No se pudo actualizar la agenda. Comprueba tu conexión e inténtalo de nuevo. ' +
            error.toString();
      });
    } finally {
      _refreshing = false;
    }
  }

  void _onReminderPreferenceChanged() {
    if (!mounted) return;
    if (NotificationService.matchRemindersEnabled.value) {
      unawaited(_syncMatchReminders(_events));
    } else {
      unawaited(NotificationService.cancelMatchReminders());
    }
  }

  Future<void> _syncMatchReminders(
    List<SportsAgendaEvent> events,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? false;
      if (!enabled) {
        await NotificationService.cancelMatchReminders();
        return;
      }
      final now = DateTime.now();
      final upcoming = events.where((event) {
        final status = event.status.toLowerCase();
        return event.startsAt.isAfter(now) &&
            status != 'finished' &&
            status != 'cancelled' &&
            status != 'postponed';
      }).take(40);
      final reminders = upcoming.map((event) => <String, Object>{
        'id': event.id,
        'sport': event.sport,
        'homeTeam': event.homeTeam.isNotEmpty ? event.homeTeam : event.title,
        'awayTeam': event.awayTeam,
        'startsAt': event.startsAt,
      }).toList(growable: false);
      await NotificationService.scheduleMatchReminders(events: reminders);
    } catch (_) {
      // Un fallo de notificaciones no debe ocultar ni bloquear la agenda.
    }
  }

  String _dayLabel(DateTime date) {
    final local = date.toLocal();
    final today = _dateOnly(DateTime.now());
    final day = _dateOnly(local);
    if (day == today) return 'HOY';
    if (day == today.add(const Duration(days: 1))) return 'MAÑANA';
    const weekdays = <String>[
      'DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB',
    ];
    return weekdays[local.weekday % 7] + ' ' + local.day.toString();
  }

  String _dateSubtitle(DateTime date) {
    final local = date.toLocal();
    const months = <String>[
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    return local.day.toString() + ' ' + months[local.month - 1];
  }

  String _timeLabel(DateTime date) {
    final local = date.toLocal();
    return local.hour.toString().padLeft(2, '0') +
        ':' +
        local.minute.toString().padLeft(2, '0');
  }

  bool _isLive(SportsAgendaEvent event) {
    final status = event.status.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (status == 'live' || status == 'inprogress' || status == 'inplay') {
      return true;
    }
    if (_isFinished(event)) return false;
    final now = DateTime.now();
    final end = event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
    return !now.isBefore(event.startsAt) && now.isBefore(end);
  }

  bool _isFinished(SportsAgendaEvent event) {
    final status = event.status.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (status == 'finished' ||
        status == 'complete' ||
        status == 'completed' ||
        status == 'final' ||
        status == 'cancelled' ||
        status == 'canceled' ||
        status == 'postponed' ||
        status == 'abandoned') {
      return true;
    }
    final end = event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
    return DateTime.now().isAfter(end);
  }

  List<String> get _sportOptions {
    final sports = <String>{
      ..._favoriteSportNames,
      ..._events.map((event) => event.sport.trim())
          .where((sport) => sport.isNotEmpty),
    }.toList()
      ..sort();
    return <String>['Todos', ...sports];
  }

  List<SportsAgendaEvent> get _filteredEvents {
    final selectedDay = _dateOnly(_selectedDate);
    final nextDay = selectedDay.add(const Duration(days: 1));
    final query = _query.trim().toLowerCase();
    return _events.where((event) {
      final start = event.startsAt.toLocal();
      if (start.isBefore(selectedDay) || !start.isBefore(nextDay)) return false;
      if (_selectedSport != 'Todos' && event.sport != _selectedSport) {
        return false;
      }
      final live = _isLive(event);
      final finished = _isFinished(event);
      if (_statusFilter == 'En vivo' && !live) return false;
      if (_statusFilter == 'Programados' && (live || finished)) return false;
      if (_statusFilter == 'Finalizados' && !finished) return false;
      if (query.isNotEmpty) {
        final searchable = <String>[
          event.title,
          event.sport,
          event.competition,
          event.homeTeam,
          event.awayTeam,
          event.venue,
        ].join(' ').toLowerCase();
        if (!searchable.contains(query)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  IconData _sportIcon(String sport) {
    final value = sport.toLowerCase();
    if (value.contains('fútbol') || value.contains('futbol')) return Icons.sports_soccer_rounded;
    if (value.contains('baloncesto') || value.contains('basket')) return Icons.sports_basketball_rounded;
    if (value.contains('béisbol') || value.contains('beisbol') || value.contains('baseball')) return Icons.sports_baseball_rounded;
    if (value.contains('hockey')) return Icons.sports_hockey_rounded;
    if (value.contains('voleibol') || value.contains('volleyball')) return Icons.sports_volleyball_rounded;
    if (value.contains('balonmano') || value.contains('handball')) return Icons.sports_handball_rounded;
    if (value.contains('mma') || value.contains('boxeo')) return Icons.sports_mma_rounded;
    if (value.contains('tenis')) return Icons.sports_tennis_rounded;
    if (value.contains('motor') || value.contains('f1')) return Icons.directions_car_rounded;
    if (value.contains('ciclismo')) return Icons.directions_bike_rounded;
    if (value.contains('atletismo') || value.contains('carrera')) return Icons.directions_run_rounded;
    if (value.contains('natación') || value.contains('natacion')) return Icons.pool_rounded;
    if (value.contains('golf')) return Icons.sports_golf_rounded;
    if (value.contains('rugby')) return Icons.sports_rugby_rounded;
    return Icons.emoji_events_rounded;
  }

  Widget _agendaImage(
    String imageUrl, {
    double size = 48,
    required IconData fallbackIcon,
    String fallbackLabel = '',
  }) {
    final uri = Uri.tryParse(imageUrl.trim());
    final valid = uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty;

    Widget fallback() {
      final parts = fallbackLabel.trim().split(RegExp(r'\s+'));
      final initials = parts
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => part.characters.first.toUpperCase())
          .join();
      return ColoredBox(
        color: const Color(0xFF0D1118),
        child: Center(
          child: initials.isNotEmpty
              ? Text(
                  initials,
                  style: const TextStyle(
                    color: _agendaCyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                )
              : Icon(fallbackIcon, color: _agendaCyan, size: 22),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0D1118),
        border: Border.all(color: _agendaLine, width: 1.2),
      ),
      child: ClipOval(
        child: valid
            ? Image.network(
                imageUrl,
                fit: BoxFit.contain,
                cacheWidth: (size * 2).round(),
                cacheHeight: (size * 2).round(),
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                    frame == null && !wasSynchronouslyLoaded ? fallback() : child,
                errorBuilder: (_, __, ___) => fallback(),
              )
            : fallback(),
      ),
    );
  }

  Widget _teamBlock(String name, String logo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _agendaImage(
          logo,
          size: 52,
          fallbackIcon: Icons.shield_rounded,
          fallbackLabel: name,
        ),
        const SizedBox(height: 7),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _participantBlock(SportsAgendaParticipant participant) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104, maxWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1118),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _agendaLine),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _agendaImage(
            participant.imageUrl,
            size: 44,
            fallbackIcon: Icons.person_rounded,
            fallbackLabel: participant.name,
          ),
          const SizedBox(height: 6),
          Text(
            participant.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (participant.country.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              participant.country.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _agendaMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    // La Agenda es deliberadamente diaria: no descarga ni presenta la semana.
    return const SizedBox.shrink();
  }

  Widget _buildFilters() {
    final sports = _sportOptions;
    final selectedSport = sports.contains(_selectedSport)
        ? _selectedSport
        : 'Todos';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 5),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('agenda-search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Buscar equipo, partido o competición',
                    hintStyle: const TextStyle(
                      color: _agendaMuted,
                      fontSize: 10,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _agendaCyan,
                      size: 19,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _agendaMuted,
                              size: 17,
                            ),
                          ),
                    filled: true,
                    fillColor: _agendaPanel,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _agendaLine),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: _agendaCyan,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: _agendaPanel,
                  border: Border.all(color: _agendaLine),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const ValueKey<String>('agenda-sport-filter'),
                    value: selectedSport,
                    dropdownColor: _agendaPanel,
                    iconEnabledColor: _agendaCyan,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    items: sports.map((sport) {
                      return DropdownMenuItem<String>(
                        value: sport,
                        child: Text(
                          sport == 'Todos' ? 'Deportes' : sport,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedSport = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <String>[
                'Todos',
                'En vivo',
                'Programados',
                'Finalizados',
              ].map((status) {
                final selected = _statusFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey<String>('agenda-status-' + status),
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      status,
                      style: TextStyle(
                        color: selected ? Colors.black : _agendaMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _statusFilter = status),
                    backgroundColor: _agendaPanel,
                    selectedColor: _agendaCyan,
                    side: BorderSide(
                      color: selected ? _agendaCyan : _agendaLine,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(SportsAgendaEvent event) {
    final live = _isLive(event);
    final finished = _isFinished(event);
    final hasScore =
        event.homeScore.isNotEmpty || event.awayScore.isNotEmpty;
    final scoreLabel = (event.homeScore.isEmpty ? '-' : event.homeScore) +
        ' : ' +
        (event.awayScore.isEmpty ? '-' : event.awayScore);
    final statusLabel = live
        ? '● EN VIVO'
        : finished
            ? 'FINALIZADO'
            : event.statusLabel.isNotEmpty
                ? event.statusLabel.toUpperCase()
                : 'PROGRAMADO';

    return Container(
      key: ValueKey<String>('agenda-event-' + event.id),
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _agendaPanel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: live ? _agendaRed.withAlpha(190) : _agendaLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_sportIcon(event.sport), color: _agendaCyan, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.sport.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _agendaMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    hasScore ? scoreLabel : _timeLabel(event.startsAt),
                    style: TextStyle(
                      color: live ? _agendaRed : _agendaGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: live ? _agendaRed : _agendaMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (event.homeTeam.isNotEmpty && event.awayTeam.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: _teamBlock(event.homeTeam, event.homeTeamLogo)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: _agendaPink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(child: _teamBlock(event.awayTeam, event.awayTeamLogo)),
              ],
            )
          else ...<Widget>[
            Text(
              event.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (event.participants.isNotEmpty) ...<Widget>[
              const SizedBox(height: 9),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: event.participants
                    .take(6)
                    .map(_participantBlock)
                    .toList(growable: false),
              ),
              if (event.participants.length > 6) ...<Widget>[
                const SizedBox(height: 5),
                Center(
                  child: Text(
                    '+' + (event.participants.length - 6).toString() +
                        ' participantes',
                    style: const TextStyle(
                      color: _agendaMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ] else if (event.imageUrl.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Center(
                child: _agendaImage(
                  event.imageUrl,
                  size: 58,
                  fallbackIcon: Icons.sports_rounded,
                ),
              ),
            ],
          ],
          if (event.competition.isNotEmpty) ...<Widget>[
            const SizedBox(height: 7),
            Text(
              event.competition,
              style: const TextStyle(
                color: _agendaMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (event.venue.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.location_on_outlined,
                  color: _agendaMuted,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _agendaMuted,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: ValueKey<String>('agenda-live-event-' + event.id),
              onPressed: () => widget.onOpenLive(event.id),
              icon: const Icon(
                Icons.live_tv_rounded,
                size: 15,
                color: _agendaPink,
              ),
              label: Text(
                'VER TRANSMISIONES',
                style: const TextStyle(
                  color: _agendaPink,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;
    return Scaffold(
      backgroundColor: _agendaBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        title: const AppSectionTitle(
          icon: Icons.calendar_month_rounded,
          title: 'AGENDA DEPORTIVA',
          accent: _agendaCyan,
          subtitle: 'JORNADA DE HOY · SPORTSAPI.APP',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar agenda',
            onPressed: _loading ? null : () => _refresh(forceRefresh: true),
            icon: Icon(
              Icons.refresh_rounded,
              color: _loading ? _agendaMuted : _agendaCyan,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: _agendaPanel,
              border: Border(bottom: BorderSide(color: _agendaLine)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.calendar_month_rounded,
                  color: _agendaCyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loading
                        ? 'Sincronizando la jornada de hoy…'
                        : events.length.toString() +
                            ' eventos · ' +
                            _dayLabel(_selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _agendaCyan,
                    ),
                  )
                else
                  const Text(
                    'JORNADA DIARIA · CACHÉ LOCAL',
                    style: TextStyle(
                      color: _agendaGreen,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
          _buildDateSelector(),
          _buildFilters(),
          if (_unavailableDates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 1, 14, 6),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _agendaGreen,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Cobertura parcial en: ' +
                          _unavailableDates.map(_dateSubtitle).join(', ') +
                          '. Una o más fuentes deportivas no respondieron; se conserva la caché cuando existe.',
                      style: const TextStyle(
                        color: _agendaMuted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading && (!_hasLoaded || events.isEmpty)
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircularProgressIndicator(color: _agendaCyan),
                        SizedBox(height: 12),
                        Text(
                          'Cargando eventos por deporte y fecha…',
                          style: TextStyle(color: _agendaMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : _error != null && events.isEmpty
                    ? _emptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'NO SE PUDO CARGAR LA AGENDA',
                        message: _error!,
                      )
                    : events.isEmpty
                        ? _emptyState(
                            icon: Icons.event_busy_rounded,
                            title: 'NO HAY EVENTOS PARA ESTA FECHA',
                            message: _events.isEmpty
                                ? 'No se encontraron eventos en los próximos siete días. Comprueba la conexión y vuelve a actualizar.'
                                : 'No hay eventos que coincidan con esta fecha y estos filtros. Prueba otro día o elimina los filtros.',
                          )
                        : RefreshIndicator(
                            color: _agendaCyan,
                            backgroundColor: _agendaPanel,
                            onRefresh: () => _refresh(forceRefresh: true),
                            child: ListView.builder(
                              key: const ValueKey<String>('agenda-event-list'),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                              cacheExtent: 240,
                              itemCount: events.length,
                              itemBuilder: (context, index) =>
                                  _buildEventCard(events[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _agendaPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _agendaLine),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: _agendaCyan, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _agendaMuted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('ACTUALIZAR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _agendaCyan,
                      side: const BorderSide(color: _agendaCyan),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
