import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sports_api_service.dart';
import 'automatic_live_service.dart';

/// Cliente seguro del adaptador SportsAPI.app publicado en Cloudflare.
/// La clave del proveedor nunca se incluye en la APK.
class SportsAgendaWindow {
  const SportsAgendaWindow({
    required this.startDate,
    required this.days,
    required this.events,
    this.unavailableDates = const <DateTime>[],
  });

  final DateTime startDate;
  final int days;
  final List<SportsAgendaEvent> events;
  final List<DateTime> unavailableDates;
}

class _AgendaDayResult {
  const _AgendaDayResult({
    required this.date,
    required this.events,
    this.failed = false,
    this.incomplete = false,
  });

  final DateTime date;
  final List<SportsAgendaEvent> events;
  final bool failed;
  final bool incomplete;
}

class _AgendaSportsResult {
  const _AgendaSportsResult({
    required this.events,
    this.incomplete = false,
  });

  final List<SportsAgendaEvent> events;
  final bool incomplete;
}

class _AgendaSportResult {
  const _AgendaSportResult({
    required this.events,
    this.failed = false,
  });

  final List<SportsAgendaEvent> events;
  final bool failed;
}


String _normalizeAgendaFilterText(String value) {
  return value.trim().toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _normalizeAgendaSportId(String value) {
  final normalized = _normalizeAgendaFilterText(value)
      .replaceAll(RegExp(r'[ _]+'), '-');
  const aliases = <String, String>{
    'soccer': 'football', 'futbol': 'football', 'icehockey': 'ice-hockey',
    'hockey': 'ice-hockey', 'volley-ball': 'volleyball',
    'road-cycling': 'cycling', 'formula-1': 'motorsport',
    'formula1': 'motorsport', 'f1': 'motorsport',
    'motor-racing': 'motorsport', 'racing': 'motorsport',
  };
  return aliases[normalized] ?? normalized;
}

bool _isTruthy(dynamic value) {
  if (value == true) return true;
  if (value is num) return value != 0;
  if (value is String) {
    return const <String>{'true', '1', 'yes', 'on', 'enabled', 'selected'}
        .contains(value.trim().toLowerCase());
  }
  return false;
}

void _addCompetitionSelection(String raw, Set<String> ids, Set<String> names) {
  final value = raw.trim();
  if (value.isEmpty) return;
  if (int.tryParse(value) != null) {
    ids.add(value);
  } else {
    names.add(_normalizeAgendaFilterText(value));
  }
}

class _FavoriteAgendaSport {
  const _FavoriteAgendaSport({
    required this.id,
    required this.name,
    required this.competitionIds,
    required this.competitionNames,
    required this.allCompetitions,
  });

  final String id;
  final String name;
  final Set<String> competitionIds;
  final Set<String> competitionNames;
  final bool allCompetitions;

  bool _matchesCompetition({required String id, required String name}) {
    if (allCompetitions) return true;
    if (id.isNotEmpty && competitionIds.contains(id)) return true;

    final normalizedName = _normalizeAgendaFilterText(name);
    if (normalizedName.isEmpty) return false;

    // SportsAPI puede añadir patrocinadores, sufijos o variantes de nombre
    // sin cambiar la competición (p. ej. "LaLiga EA SPORTS").
    return competitionNames.any((selectedName) {
      if (selectedName == normalizedName) return true;
      return (selectedName.length >= 5 &&
              normalizedName.startsWith('$selectedName ')) ||
          (normalizedName.length >= 5 &&
              selectedName.startsWith('$normalizedName '));
    });
  }

  bool matchesRow(Map<String, dynamic> row, {required bool isRace}) {
    // Ciclismo se selecciona por carrera (row.name), no por la serie general.
    dynamic raw = this.id == 'cycling' && isRace
        ? row['name']
        : row[isRace ? 'series' : 'league'] ?? row['competition'];
    for (final wrapperKey in const <String>['fixture', 'event', 'game']) {
      final wrapper = row[wrapperKey];
      if (raw == null && wrapper is Map) {
        raw = wrapper[isRace ? 'series' : 'league'] ?? wrapper['competition'];
      }
    }
    final competition = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final id = (competition['id'] ??
            competition[isRace ? 'seriesId' : 'leagueId'] ??
            competition['competitionId'] ??
            '').toString().trim();
    final name = (competition['name'] ??
            competition['title'] ??
            (raw is String ? raw : ''))
        .toString()
        .trim();
    return _matchesCompetition(id: id, name: name);
  }

  bool matchesEvent(SportsAgendaEvent event) {
    final id = (event.providerLeagueId ?? event.providerSeriesId)?.toString() ?? '';
    return _matchesCompetition(id: id, name: event.competition);
  }
}

class SportsApiAppService {
  SportsApiAppService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  bool _clientClosed = false;

  void _closeOwnedClient() {
    if (_ownsClient && !_clientClosed) {
      _clientClosed = true;
      _client.close();
    }
  }

  static const Duration _timeout = Duration(seconds: 45);
  static const Duration _windowTimeout = Duration(minutes: 20);
  static const Duration _favoritesCacheDuration = Duration(minutes: 2);

  static final Map<String, ({
    List<Map<String, dynamic>> sports,
    DateTime expiresAt,
  })> _favoriteSportsCache = <String, ({
    List<Map<String, dynamic>> sports,
    DateTime expiresAt,
  })>{};
  static final Map<String, Future<List<Map<String, dynamic>>>>
      _favoriteSportsInFlight =
      <String, Future<List<Map<String, dynamic>>>>{};

  Uri _uri(String route, [Map<String, String> query = const <String, String>{}]) {
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) {
      throw const SportsApiException('La URL del servidor deportivo no es válida.');
    }
    return Uri.parse('$base/api/sportsapi$route').replace(queryParameters: query.isEmpty ? null : query);
  }

  Future<dynamic> _get(
    String route, [
    Map<String, String> query = const <String, String>{},
    bool includeEnvelope = false,
  ]) async {
    try {
      final response = await _client.get(
        _uri(route, query),
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        var detail = '';
        try {
          final error = jsonDecode(response.body);
          if (error is Map && error['error'] != null) {
            final value = error['error'];
            detail = value is Map
                ? (value['message'] ?? value['code'] ?? '').toString()
                : value.toString();
          }
        } catch (_) {
          // Se conserva el código HTTP aunque el servidor no envíe JSON.
        }
        if (detail.length > 220) detail = '${detail.substring(0, 217)}…';
        final retryAfter = response.headers['retry-after'];
        throw SportsApiException(
          'El servidor SportsAPI respondió HTTP ${response.statusCode}'
          '${detail.isEmpty ? '.' : ': $detail'}'
          '${retryAfter == null ? '' : ' Retry-After: $retryAfter'}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SportsApiException('La respuesta de SportsAPI no tiene el formato esperado.');
      }
      if (route == '/favorites' || includeEnvelope) return decoded;
      if (!decoded.containsKey('data')) {
        throw const SportsApiException('La respuesta de SportsAPI no contiene el campo data.');
      }
      return decoded['data'];
    } on TimeoutException {
      throw const SportsApiException('La consulta de SportsAPI tardó demasiado.');
    } on SportsApiException {
      rethrow;
    } catch (_) {
      throw const SportsApiException('No se pudo conectar con SportsAPI. Comprueba el Worker y su secreto.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFavoriteSports({
    bool forceRefresh = false,
  }) async {
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) {
      throw const SportsApiException('La URL del servidor deportivo no es válida.');
    }
    if (forceRefresh) {
      _favoriteSportsCache.remove(base);
      _favoriteSportsInFlight.remove(base);
    }
    final now = DateTime.now();
    final cached = _favoriteSportsCache[base];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.sports;
    }
    final pending = _favoriteSportsInFlight[base];
    if (pending != null) return pending;

    final future = () async {
      final response = await _get('/favorites');
      if (response is! Map) return <Map<String, dynamic>>[];
      final data = response['data'];
      final dataMap = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final sports = response['sports'] ?? response['favorites'] ??
          dataMap['sports'] ?? dataMap['favorites'] ??
          (data is List ? data : null);
      if (sports is! List) {
        throw const SportsApiException(
          'Cloudflare no devolvió la lista de deportes favoritos. Se utilizará la agenda guardada.',
        );
      }
      return sports.whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }();
    _favoriteSportsInFlight[base] = future;
    return future.then((sports) {
      _favoriteSportsCache[base] = (
        sports: sports,
        expiresAt: DateTime.now().add(_favoritesCacheDuration),
      );
      return sports;
    }).whenComplete(() {
      _favoriteSportsInFlight.remove(base);
    });
  }

  Future<List<_FavoriteAgendaSport>> _loadFavoriteAgendaSports({
    bool forceRefresh = false,
  }) async {
    final favorites = await fetchFavoriteSports(forceRefresh: forceRefresh);
    final selected = <String, _FavoriteAgendaSport>{};

    for (final sport in favorites) {
      if (sport['enabled'] == false ||
          sport['active'] == false ||
          sport['selected'] == false) {
        continue;
      }

      final rawSportId = <dynamic>[
        sport['id'],
        sport['sportId'],
        sport['slug'],
        sport['sport'],
        sport['key'],
        sport['code'],
      ].firstWhere((value) => _text(value).isNotEmpty, orElse: () => null);
      var id = _normalizeAgendaSportId(_text(rawSportId));
      if (!_sportNames.containsKey(id)) {
        final normalizedName = _normalizeAgendaFilterText(
          _text(sport['name'] ?? sport['sportName']),
        );
        const nameAliases = <String, String>{
          'football': 'football', 'soccer': 'football', 'futbol': 'football',
          'basketball': 'basketball', 'baseball': 'baseball',
          'ice hockey': 'ice-hockey', 'hockey sobre hielo': 'ice-hockey',
          'volleyball': 'volleyball', 'mma': 'mma', 'futsal': 'futsal',
          'cycling': 'cycling', 'ciclismo': 'cycling', 'motorsport': 'motorsport',
          'motor sport': 'motorsport', 'formula 1': 'motorsport', 'f1': 'motorsport',
          'handball': 'handball',
        };
        id = nameAliases[normalizedName] ?? id;
        if (!_sportNames.containsKey(id)) {
          for (final entry in _sportNames.entries) {
            if (_normalizeAgendaFilterText(entry.key) == normalizedName ||
                _normalizeAgendaFilterText(entry.value) == normalizedName) {
              id = entry.key;
              break;
            }
          }
        }
      }
      if (!_sportNames.containsKey(id)) continue;

      final suppliedName = _text(sport['name'] ?? sport['sportName']);
      final name = suppliedName.isEmpty ? _sportNames[id]! : suppliedName;
      final competitionIds = <String>{};
      final competitionNames = <String>{};
      var allCompetitions = _isTruthy(sport['allCompetitions']) ||
          _isTruthy(sport['allLeagues']) || _isTruthy(sport['all']);

      void addSelection(String raw) {
        final normalized = _normalizeAgendaFilterText(raw);
        if (_isAllCompetitionsValue(normalized)) {
          allCompetitions = true;
        } else {
          _addCompetitionSelection(raw, competitionIds, competitionNames);
        }
      }

      void readCompetitionSelection(dynamic value) {
        if (value == null) return;
        if (value is List) {
          for (final item in value) {
            readCompetitionSelection(item);
          }
          return;
        }
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          if (map['enabled'] == false || map['active'] == false ||
              map['selected'] == false || map['isSelected'] == false) {
            return;
          }
          final rawId = map['id'] ?? map['leagueId'] ??
              map['competitionId'] ?? map['seriesId'];
          final rawName = map['name'] ?? map['title'] ?? map['label'] ??
              map['leagueName'] ?? map['competitionName'] ?? map['seriesName'];
          final idValue = _text(rawId);
          final nameValue = _text(rawName);
          if (idValue.isNotEmpty || nameValue.isNotEmpty) {
            if (idValue.isNotEmpty) competitionIds.add(idValue);
            if (nameValue.isNotEmpty) addSelection(nameValue);
            return;
          }
          // También admite mapas como {"39": true} o
          // {"Premier League": {"selected": true}}.
          for (final entry in map.entries) {
            final key = entry.key.trim();
            if (key.isEmpty || const <String>{
              'enabled', 'active', 'selected', 'isSelected',
              'all', 'allLeagues', 'allCompetitions',
            }.contains(key)) continue;
            final child = entry.value;
            if (_isTruthy(child)) {
              addSelection(key);
            } else if (child is Map) {
              final childMap = Map<String, dynamic>.from(child);
              if (childMap['enabled'] == false || childMap['active'] == false ||
                  childMap['selected'] == false || childMap['isSelected'] == false) {
                continue;
              }
              final explicitId = _text(childMap['id'] ?? childMap['leagueId'] ??
                  childMap['competitionId'] ?? childMap['seriesId']);
              final explicitName = _text(childMap['name'] ?? childMap['title'] ??
                  childMap['label'] ?? childMap['leagueName'] ??
                  childMap['competitionName'] ?? childMap['seriesName']);
              if (explicitId.isNotEmpty || explicitName.isNotEmpty) {
                if (explicitId.isNotEmpty) competitionIds.add(explicitId);
                if (explicitName.isNotEmpty) addSelection(explicitName);
              } else {
                if (_isTruthy(childMap['selected'] ?? childMap['enabled'])) {
                  addSelection(key);
                }
                readCompetitionSelection(child);
              }
            } else {
              readCompetitionSelection(child);
            }
          }
          return;
        }
        if (value is String || value is num) addSelection(value.toString());
      }

      // Fusionar campos: competitions: [] no debe ocultar selectedCompetitions.
      for (final key in const <String>[
        'competitions', 'leagues', 'selectedCompetitions', 'selectedLeagues',
        'competitionIds', 'leagueIds', 'seriesIds',
      ]) {
        if (sport.containsKey(key)) readCompetitionSelection(sport[key]);
      }

      // Incorpora los alias publicados por Cloudflare, pero solo para las
      // competiciones que el usuario tiene seleccionadas.
      final rawAliases = sport['competitionAliases'] ?? sport['aliases'];
      if (rawAliases is Map) {
        for (final entry in rawAliases.entries) {
          final canonical = _normalizeAgendaFilterText(entry.key.toString());
          final rawValues = entry.value;
          final aliases = rawValues is List ? rawValues : <dynamic>[rawValues];
          final normalizedNames = <String>{canonical};
          for (final alias in aliases) {
            final normalized = _normalizeAgendaFilterText(alias.toString());
            if (normalized.isNotEmpty) normalizedNames.add(normalized);
          }
          if (allCompetitions ||
              normalizedNames.any(competitionNames.contains)) {
            competitionNames.addAll(normalizedNames);
          }
        }
      }

      // Una selección sin ligas legibles no equivale a "todas".
      // Solo se permite cargar todas cuando el catálogo lo indica expresamente.
      if (competitionIds.isEmpty && competitionNames.isEmpty && !allCompetitions) {
        continue;
      }

      selected[id] = _FavoriteAgendaSport(
        id: id,
        name: name,
        competitionIds: competitionIds,
        competitionNames: competitionNames,
        allCompetitions: allCompetitions,
      );
    }
    return selected.values.toList(growable: false);
  }

  /// Aplica la misma selección a eventos restaurados desde el almacenamiento local.
  Future<List<SportsAgendaEvent>> filterFavoriteAgendaEvents(
    Iterable<SportsAgendaEvent> events,
  ) async {
    final selections = await _loadFavoriteAgendaSports();
    return events.where((event) {
      final sport = _normalizeAgendaFilterText(event.sport);
      for (final selection in selections) {
        if (sport == _normalizeAgendaFilterText(selection.id) ||
            sport == _normalizeAgendaFilterText(selection.name) ||
            sport ==
                _normalizeAgendaFilterText(_sportNames[selection.id] ?? '')) {
          if (selection.matchesEvent(event)) return true;
        }
      }
      return false;
    }).toList(growable: false);
  }

  /// Devuelve el catálogo de deportes seleccionados aunque todavía no tengan
  /// encuentros publicados dentro de la ventana actual.
  Future<List<String>> fetchFavoriteAgendaSportNames({
    bool forceRefresh = false,
  }) async {
    final sports = await _loadFavoriteAgendaSports(forceRefresh: forceRefresh);
    final names = sports.map((sport) => sport.name.trim())
        .where((name) => name.isNotEmpty).toSet().toList()
      ..sort();
    return names;
  }

  bool _isAllCompetitionsValue(String value) =>
      value == '*' ||
      value == 'all' ||
      value == 'todos' ||
      value == 'todas' ||
      value == 'all leagues' ||
      value == 'all competitions' ||
      value == 'todas las competiciones' ||
      value == 'todas las ligas';

  static const Map<String, String> _sportNames = <String, String>{
    'football': 'Fútbol',
    'basketball': 'Baloncesto',
    'baseball': 'Béisbol',
    'ice-hockey': 'Hockey sobre hielo',
    'volleyball': 'Voleibol',
    'mma': 'MMA',
    'futsal': 'Fútbol sala',
    'cycling': 'Ciclismo',
    'motorsport': 'Deportes de motor',
    'handball': 'Balonmano',
  };

  String _text(dynamic value) => value == null ? '' : value.toString().trim();

  String _image(dynamic value) {
    final raw = _text(value);
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? raw
        : '';
  }

  String _score(dynamic value) {
    if (value is Map) return _text(value['current']);
    return _text(value);
  }

  static final Map<String, _AgendaSportsResult> _agendaCache =
      <String, _AgendaSportsResult>{};
  static final Map<String, DateTime> _agendaCacheExpiry =
      <String, DateTime>{};
  static final Map<String, Future<_AgendaSportsResult>> _agendaInFlight =
      <String, Future<_AgendaSportsResult>>{};
  static final Map<String, ({
    SportsAgendaWindow window,
    DateTime expiresAt,
  })> _agendaWindowCache =
      <String, ({SportsAgendaWindow window, DateTime expiresAt})>{};
  static final Map<String, Future<SportsAgendaWindow>> _agendaWindowInFlight =
      <String, Future<SportsAgendaWindow>>{};


  Future<List<SportsAgendaEvent>> fetchFavoriteAgendaEvents({
    DateTime? date,
  }) async {
    final requested = date ?? DateTime.now().toUtc();
    final result = await _fetchCachedAgendaDay(requested);
    return result.events;
  }

  Future<_AgendaSportsResult> _fetchCachedAgendaDay(
    DateTime date, {
    bool forceRefresh = false,
    void Function(_AgendaSportsResult result)? onProgress,
  }) {
    final utcDay = DateTime.utc(date.year, date.month, date.day);
    final day = utcDay.year.toString().padLeft(4, '0') + '-' +
        utcDay.month.toString().padLeft(2, '0') + '-' +
        utcDay.day.toString().padLeft(2, '0');
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value) ??
        sportsApiBaseUrl.value.trim();
    final cacheKey = '$base:$day';
    final cached = _agendaCache[cacheKey];
    final expires = _agendaCacheExpiry[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        expires != null &&
        DateTime.now().isBefore(expires)) {
      onProgress?.call(cached);
      return Future<_AgendaSportsResult>.value(cached);
    }
    final pending = _agendaInFlight[cacheKey];
    if (pending != null) {
      if (forceRefresh) {
        return pending.then(
          (_) => _fetchCachedAgendaDay(
            date,
            forceRefresh: true,
            onProgress: onProgress,
          ),
          onError: (_) => _fetchCachedAgendaDay(
            date,
            forceRefresh: true,
            onProgress: onProgress,
          ),
        );
      }
      return pending.then((result) {
        onProgress?.call(result);
        return result;
      });
    }

    final future = _fetchFavoriteAgendaEvents(
      day,
      forceRefresh: forceRefresh,
      onProgress: onProgress,
    );
    _agendaInFlight[cacheKey] = future;
    return future.then((result) {
      _agendaCache[cacheKey] = result;
      final parsedDay = DateTime.tryParse(day);
      final todayUtc = DateTime.now().toUtc();
      final dayOffset = parsedDay == null
          ? 0
          : DateTime.utc(parsedDay.year, parsedDay.month, parsedDay.day)
              .difference(DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day))
              .inDays;
      _agendaCacheExpiry[cacheKey] = DateTime.now().add(
        result.incomplete
            ? const Duration(minutes: 1)
            : dayOffset == 0
                ? const Duration(minutes: 3)
                : dayOffset < 0
                    ? const Duration(hours: 6)
                    : const Duration(minutes: 15),
      );
      return result;
    }).whenComplete(() {
      _agendaInFlight.remove(cacheKey);
    });
  }

  /// Descarga hoy y los seis días siguientes. Las fechas y los deportes se
  /// consultan en serie para respetar el límite compartido de SportsAPI.
  Future<SportsAgendaWindow> fetchFavoriteAgendaWindow({
    DateTime? startDate,
    int days = 7,
    bool forceRefresh = false,
    void Function(SportsAgendaWindow window)? onProgress,
  }) {
    final requested = (startDate ?? DateTime.now()).toLocal();
    final firstDay = DateTime(requested.year, requested.month, requested.day);
    final safeDays = days.clamp(1, 7).toInt();
    final firstKey = firstDay.year.toString().padLeft(4, '0') + '-' +
        firstDay.month.toString().padLeft(2, '0') + '-' +
        firstDay.day.toString().padLeft(2, '0');
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value) ??
        sportsApiBaseUrl.value.trim();
    final cacheKey = base + ':' + firstKey + ':' + safeDays.toString();
    if (forceRefresh) {
      _agendaWindowCache.remove(cacheKey);
      _agendaCache.clear();
      _agendaCacheExpiry.clear();
      final normalizedBase =
          SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
      if (normalizedBase != null) {
        _favoriteSportsCache.remove(normalizedBase);
        _favoriteSportsInFlight.remove(normalizedBase);
      }
    }
    final now = DateTime.now();
    final cached = _agendaWindowCache[cacheKey];
    if (!forceRefresh && cached != null && now.isBefore(cached.expiresAt)) {
      onProgress?.call(cached.window);
      return Future<SportsAgendaWindow>.value(cached.window);
    }
    final pending = _agendaWindowInFlight[cacheKey];
    if (pending != null) {
      if (forceRefresh) {
        return pending.then(
          (_) => fetchFavoriteAgendaWindow(
            startDate: firstDay,
            days: safeDays,
            forceRefresh: true,
            onProgress: onProgress,
          ),
          onError: (_) => fetchFavoriteAgendaWindow(
            startDate: firstDay,
            days: safeDays,
            forceRefresh: true,
            onProgress: onProgress,
          ),
        );
      }
      return pending.then((window) {
        onProgress?.call(window);
        return window;
      });
    }

    final future = _fetchFavoriteAgendaWindow(
      firstDay,
      safeDays,
      forceRefresh: forceRefresh,
      onProgress: onProgress,
    ).timeout(
      _windowTimeout,
      onTimeout: () {
        _closeOwnedClient();
        throw const SportsApiException(
          'La agenda superó el tiempo máximo de carga. Comprueba la conexión y vuelve a intentarlo.',
        );
      },
    );
    _agendaWindowInFlight[cacheKey] = future;
    return future.then((window) {
      _agendaWindowCache[cacheKey] = (
        window: window,
        expiresAt: DateTime.now().add(
          window.unavailableDates.isNotEmpty
              ? const Duration(minutes: 1)
              : const Duration(minutes: 3),
        ),
      );
      return window;
    }).whenComplete(() {
      _agendaWindowInFlight.remove(cacheKey);
    });
  }

  Future<SportsAgendaWindow> _fetchFavoriteAgendaWindow(
    DateTime startDate,
    int days, {
    required bool forceRefresh,
    void Function(SportsAgendaWindow window)? onProgress,
  }) async {
    final localStart = DateTime(startDate.year, startDate.month, startDate.day);
    final localEnd = localStart.add(Duration(days: days));

    // En Guyana y otras zonas UTC-negativas, una ventana local de siete días
    // puede intersectar ocho fechas UTC. Consultamos todas las fechas necesarias.
    final firstUtcInstant = localStart.toUtc();
    final lastUtcInstant = localEnd.toUtc().subtract(
      const Duration(milliseconds: 1),
    );
    final firstUtcDay = DateTime.utc(
      firstUtcInstant.year,
      firstUtcInstant.month,
      firstUtcInstant.day,
    );
    final lastUtcDay = DateTime.utc(
      lastUtcInstant.year,
      lastUtcInstant.month,
      lastUtcInstant.day,
    );
    final utcDays = lastUtcDay.difference(firstUtcDay).inDays + 1;

    final eventsByUtcDay = <String, Map<String, SportsAgendaEvent>>{};
    final unavailableLocalDays = <DateTime>{};

    String utcDayKey(DateTime value) =>
        value.year.toString().padLeft(4, '0') + '-' +
        value.month.toString().padLeft(2, '0') + '-' +
        value.day.toString().padLeft(2, '0');

    void markUnavailableUtcDay(DateTime utcDay) {
      final utcEnd = utcDay
          .add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1));
      final firstLocal = utcDay.toLocal();
      final lastLocal = utcEnd.toLocal();
      var localDay = DateTime(
        firstLocal.year,
        firstLocal.month,
        firstLocal.day,
      );
      final lastLocalDay = DateTime(
        lastLocal.year,
        lastLocal.month,
        lastLocal.day,
      );
      while (!localDay.isAfter(lastLocalDay)) {
        if (!localDay.isBefore(localStart) && localDay.isBefore(localEnd)) {
          unavailableLocalDays.add(localDay);
        }
        localDay = localDay.add(const Duration(days: 1));
      }
    }

    SportsAgendaWindow currentWindow() {
      final unique = <String, SportsAgendaEvent>{};
      for (final dailyEvents in eventsByUtcDay.values) {
        unique.addAll(dailyEvents);
      }
      final events = unique.values.where((event) {
        final localEventStart = event.startsAt.toLocal();
        return !localEventStart.isBefore(localStart) &&
            localEventStart.isBefore(localEnd);
      }).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final unavailableDates = unavailableLocalDays.toList()
        ..sort((a, b) => a.compareTo(b));
      return SportsAgendaWindow(
        startDate: localStart,
        days: days,
        events: events,
        unavailableDates: unavailableDates,
      );
    }

    // Procesa fechas y deportes en serie para respetar el limitador global del
    // proveedor, pero publica cada deporte terminado para que la pantalla no
    // espere hasta finalizar toda la semana.
    var nextDayIndex = 0;
    Future<void> runUtcDayWorker() async {
      while (true) {
        final dayIndex = nextDayIndex++;
        if (dayIndex >= utcDays) return;
        final date = firstUtcDay.add(Duration(days: dayIndex));
        final key = utcDayKey(date);
        _AgendaDayResult result;
        try {
          final dayResult = await _fetchCachedAgendaDay(
            date,
            forceRefresh: forceRefresh,
            onProgress: (partial) {
              eventsByUtcDay[key] = <String, SportsAgendaEvent>{
                for (final event in partial.events) event.id: event,
              };
              if (partial.incomplete) markUnavailableUtcDay(date);
              onProgress?.call(currentWindow());
            },
          );
          result = _AgendaDayResult(
            date: date,
            events: dayResult.events,
            incomplete: dayResult.incomplete,
          );
        } catch (_) {
          result = _AgendaDayResult(
            date: date,
            events: const <SportsAgendaEvent>[],
            failed: true,
          );
        }
        eventsByUtcDay[key] = <String, SportsAgendaEvent>{
          for (final event in result.events) event.id: event,
        };
        if (result.failed || result.incomplete) {
          markUnavailableUtcDay(result.date);
        }
        onProgress?.call(currentWindow());
      }
    }

    await Future.wait<void>(List<Future<void>>.generate(
      1,
      (_) => runUtcDayWorker(),
      growable: false,
    ));

    return currentWindow();
  }

  Future<_AgendaSportsResult> _fetchFavoriteAgendaEvents(
    String day, {
    bool forceRefresh = false,
    void Function(_AgendaSportsResult result)? onProgress,
  }) async {
    Future<Map<String, dynamic>> fetchCompleteEnvelope(
      String route,
      Map<String, String> query,
    ) async {
      Future<Map<String, dynamic>> request() async {
        final requestQuery = <String, String>{
          ...query,
          if (forceRefresh) 'refresh': '1',
        };
        final raw = await _get(route, requestQuery, true);
        if (raw is! Map) {
          throw const FormatException(
            'SportsAPI devolvió una respuesta con formato inválido.',
          );
        }
        return Map<String, dynamic>.from(raw);
      }

      // Reintenta una vez ante 429/errores temporales respetando Retry-After.
      // Los errores de un deporte no eliminan los resultados de los demás.
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final envelope = await request();
          final meta = envelope['meta'] is Map
              ? Map<String, dynamic>.from(envelope['meta'] as Map)
              : <String, dynamic>{};
          if (meta['complete'] != false) return envelope;
          if (attempt == 1) {
            throw const SportsApiException(
              'SportsAPI devolvió datos incompletos en dos intentos.',
            );
          }
        } catch (error) {
          final message = error.toString();
          final retryable =
              RegExp(r'HTTP (408|429|5[0-9][0-9])').hasMatch(message) ||
              message.contains('No se pudo conectar');
          if (!retryable || attempt == 1) rethrow;

          final retryMatch =
              RegExp(r'Retry-After:\s*(\d+)', caseSensitive: false)
                  .firstMatch(message);
          final retrySeconds = int.tryParse(retryMatch?.group(1) ?? '');
          if (retrySeconds != null && retrySeconds > 10) rethrow;
          await Future<void>.delayed(
            Duration(seconds: retrySeconds ?? 7),
          );
          continue;
        }
        await Future<void>.delayed(
          Duration(milliseconds: 250 * (attempt + 1)),
        );
      }
      throw const SportsApiException(
        'SportsAPI no respondió con datos completos después de dos intentos.',
      );
    }

    final entries = await _loadFavoriteAgendaSports();
    if (entries.isEmpty) {
      return const _AgendaSportsResult(events: <SportsAgendaEvent>[]);
    }
    final resultsByIndex =
        List<_AgendaSportResult?>.filled(entries.length, null);
    var nextIndex = 0;

    void emitProgress() {
      final completed = resultsByIndex.whereType<_AgendaSportResult>().toList();
      if (completed.isEmpty) return;
      final unique = <String, SportsAgendaEvent>{};
      for (final result in completed) {
        for (final event in result.events) {
          unique[event.id] = event;
        }
      }
      final events = unique.values.toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final allCompleted = completed.length == entries.length;
      onProgress?.call(_AgendaSportsResult(
        events: events,
        incomplete: allCompleted && completed.any((result) => result.failed),
      ));
    }

    Future<void> runSportWorker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= entries.length) return;
        final entry = entries[index];
        try {
          final isRace =
              entry.id == 'cycling' || entry.id == 'motorsport';
          final rows = <Map<String, dynamic>>[];
          var finishedPages = false;
          for (var page = 0; page < 100; page++) {
            final envelope = await fetchCompleteEnvelope(
              isRace ? '/races' : '/fixtures',
              <String, String>{
                'date': day,
                'sport': entry.id,
                'page': page.toString(),
              },
            );
            final payload = envelope['data'];
            if (payload is! List) {
              throw FormatException(
                isRace
                    ? 'SportsAPI devolvió una agenda de carreras con formato inválido.'
                    : 'SportsAPI devolvió una agenda de partidos con formato inválido.',
              );
            }
            rows.addAll(payload.whereType<Map>().map(
              (raw) => Map<String, dynamic>.from(raw),
            ));
            final meta = envelope['meta'] is Map
                ? Map<String, dynamic>.from(envelope['meta'] as Map)
                : <String, dynamic>{};
            if (meta['hasNextPage'] != true) {
              finishedPages = true;
              break;
            }
          }
          if (!finishedPages) {
            throw SportsApiException(
              'SportsAPI superó el límite seguro de cien páginas para ${entry.name}.',
            );
          }

          // /favorites es la fuente de verdad. Flutter vuelve a aplicar los
          // filtros para no mostrar competiciones que no están seleccionadas.
          final selectedRows = rows.where(
            (row) => entry.matchesRow(row, isRace: isRace),
          ).toList(growable: false);
          final events = isRace
              ? selectedRows
                  .expand((row) => _raceEvents(
                        row,
                        entry.name,
                        day,
                        useRaceNameAsCompetition: entry.id == 'cycling',
                      ))
                  .toList(growable: false)
              : selectedRows
                  .map((row) => _fixtureEvent(row, entry.name))
                  .whereType<SportsAgendaEvent>()
                  .toList(growable: false);
          resultsByIndex[index] = _AgendaSportResult(events: events);
        } catch (_) {
          resultsByIndex[index] = const _AgendaSportResult(
            events: <SportsAgendaEvent>[],
            failed: true,
          );
        }
        emitProgress();
      }
    }

    await Future.wait<void>(List<Future<void>>.generate(
      1,
      (_) => runSportWorker(),
      growable: false,
    ));
    final results = resultsByIndex.cast<_AgendaSportResult>();
    final successfulSports =
        results.where((result) => !result.failed).length;
    if (successfulSports == 0) {
      throw const SportsApiException(
        'No se pudo consultar ninguno de tus deportes favoritos en SportsAPI.',
      );
    }
    final unique = <String, SportsAgendaEvent>{};
    for (final event in results.expand((result) => result.events)) {
      unique[event.id] = event;
    }
    final events = unique.values.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return _AgendaSportsResult(
      events: events,
      incomplete: results.any((result) => result.failed),
    );
  }

  SportsAgendaEvent? _fixtureEvent(
    Map<String, dynamic> row,
    String sportName,
  ) {
    final id = int.tryParse(_text(row['id']));
    final start = DateTime.tryParse(_text(row['startTime']));
    if (id == null || start == null) return null;
    final home = row['home'] is Map
        ? Map<String, dynamic>.from(row['home'])
        : <String, dynamic>{};
    final away = row['away'] is Map
        ? Map<String, dynamic>.from(row['away'])
        : <String, dynamic>{};
    final league = row['league'] is Map
        ? Map<String, dynamic>.from(row['league'])
        : <String, dynamic>{};
    final season = row['season'] is Map
        ? Map<String, dynamic>.from(row['season'])
        : <String, dynamic>{};
    final status = row['status'] is Map
        ? Map<String, dynamic>.from(row['status'])
        : <String, dynamic>{};
    final statusType = _text(status['type']).toLowerCase();
    final homeName = _text(home['name']);
    final awayName = _text(away['name']);
    final title = homeName.isNotEmpty && awayName.isNotEmpty
        ? '$homeName vs $awayName'
        : _text(row['name']).isNotEmpty
            ? _text(row['name'])
            : 'Evento de $sportName';
    return SportsAgendaEvent(
      id: 'sportsapi-fixture-$id',
      title: title,
      sport: sportName,
      competition: _text(league['name']),
      homeTeam: homeName,
      awayTeam: awayName,
      homeTeamLogo: _image(home['image']),
      awayTeamLogo: _image(away['image']),
      participants: <SportsAgendaParticipant>[
        if (homeName.isNotEmpty) SportsAgendaParticipant(name: homeName, imageUrl: _image(home['image'])),
        if (awayName.isNotEmpty) SportsAgendaParticipant(name: awayName, imageUrl: _image(away['image'])),
      ],
      status: statusType.isEmpty ? 'scheduled' : statusType,
      statusLabel: _text(status['description']),
      homeScore: _score(row['homeScore']),
      awayScore: _score(row['awayScore']),
      providerLeagueId: int.tryParse(_text(league['id'])),
      providerSeasonId: int.tryParse(_text(season['id'])),
      startsAt: start,
      venue: _text((row['venue'] is Map) ? row['venue']['name'] : row['venue']),
      detailUrl: 'https://deporte-total-360-api.damian970609.workers.dev/api/sportsapi/fixtures/$id',
    );
  }

  List<SportsAgendaEvent> _raceEvents(
    Map<String, dynamic> row,
    String sportName,
    String utcDay, {
    required bool useRaceNameAsCompetition,
  }) {
    final id = int.tryParse(_text(row['id']));
    if (id == null) return const <SportsAgendaEvent>[];
    final sessions = row['sessions'] is List
        ? (row['sessions'] as List).whereType<Map>().toList()
        : <Map>[];
    final dayEvents = <SportsAgendaEvent>[];

    final series = row['series'] is Map
        ? Map<String, dynamic>.from(row['series'])
        : <String, dynamic>{};
    final season = row['season'] is Map
        ? Map<String, dynamic>.from(row['season'])
        : <String, dynamic>{};
    final winner = row['winner'] is Map
        ? Map<String, dynamic>.from(row['winner'])
        : <String, dynamic>{};
    final winnerName = _text(winner['name']);
    final raceName = _text(row['name']).isEmpty
        ? sportName
        : _text(row['name']);
    final raceCompetition = useRaceNameAsCompetition
        ? raceName
        : _text(series['name']);
    final rawStatus = row['status'] is Map
        ? row['status']['type']
        : row['status'];
    final raceStatus = _text(rawStatus).isEmpty
        ? 'scheduled'
        : _text(rawStatus);

    for (final value in sessions) {
      final session = Map<String, dynamic>.from(value);
      final start = DateTime.tryParse(_text(session['startTime']));
      if (start == null) continue;
      final utcStart = start.toUtc();
      final sessionDay = utcStart.year.toString().padLeft(4, '0') + '-' +
          utcStart.month.toString().padLeft(2, '0') + '-' +
          utcStart.day.toString().padLeft(2, '0');
      if (sessionDay != utcDay) continue;

      final sessionId = int.tryParse(_text(session['id'])) ?? 0;
      final sessionType = _text(session['type'] ?? session['name']);
      final sessionStatus = _text(
        session['status'] is Map
            ? session['status']['type']
            : session['status'],
      );
      final title = sessionType.isEmpty
          ? raceName
          : raceName + ' · ' + sessionType.toUpperCase();

      dayEvents.add(SportsAgendaEvent(
        id: 'sportsapi-race-$id-$sessionId',
        title: title,
        sport: sportName,
        competition: raceCompetition,
        participants: winnerName.isEmpty
            ? const <SportsAgendaParticipant>[]
            : <SportsAgendaParticipant>[
                SportsAgendaParticipant(
                  name: winnerName,
                  imageUrl: _image(winner['image']),
                ),
              ],
        homeTeam: winnerName,
        homeTeamLogo: _image(winner['image']),
        status: sessionStatus.isEmpty ? raceStatus : sessionStatus,
        providerSeriesId: int.tryParse(_text(series['id'])),
        providerSeasonId: int.tryParse(_text(season['id'])),
        startsAt: start,
        detailUrl:
            'https://deporte-total-360-api.damian970609.workers.dev/api/sportsapi/races/$id',
      ));
    }

    // Some race records have no sessions. Show a date-only event only on
    // their published start date; do not copy it into every following day.
    if (dayEvents.isEmpty && sessions.isEmpty) {
      final startDate = _text(row['startDate']);
      if (startDate == utcDay) {
        final start = DateTime.tryParse(startDate);
        if (start != null) {
          dayEvents.add(SportsAgendaEvent(
            id: 'sportsapi-race-$id-0',
            title: raceName,
            sport: sportName,
            competition: raceCompetition,
            participants: winnerName.isEmpty
                ? const <SportsAgendaParticipant>[]
                : <SportsAgendaParticipant>[
                    SportsAgendaParticipant(
                      name: winnerName,
                      imageUrl: _image(winner['image']),
                    ),
                  ],
            homeTeam: winnerName,
            homeTeamLogo: _image(winner['image']),
            status: raceStatus,
            providerSeriesId: int.tryParse(_text(series['id'])),
            providerSeasonId: int.tryParse(_text(season['id'])),
            startsAt: start,
            detailUrl:
                'https://deporte-total-360-api.damian970609.workers.dev/api/sportsapi/races/$id',
          ));
        }
      }
    }
    return dayEvents;
  }

    Future<dynamic> fetchFixtureStatistics(int fixtureId) {
    return _get('/fixtures/$fixtureId/statistics');
  }

  Future<dynamic> fetchRaceResults(int raceId, {int? sessionId}) {
    return _get('/races/$raceId/results', <String, String>{
      if (sessionId != null && sessionId > 0) 'session': sessionId.toString(),
    });
  }

  Future<dynamic> fetchLeagueStandings({
    required int leagueId,
    required int seasonId,
  }) {
    return _get('/leagues/$leagueId/standings', <String, String>{
      'season': seasonId.toString(),
    });
  }

  Future<dynamic> fetchSeriesStandings({
    required int seriesId,
    required int seasonId,
  }) {
    return _get('/series/$seriesId/standings', <String, String>{
      'season': seasonId.toString(),
      'type': 'competitors',
    });
  }
}
