import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sports_api_service.dart';

/// Cliente seguro del adaptador SportsAPI.app publicado en Cloudflare.
/// La clave del proveedor nunca se incluye en la APK.
class SportsApiAppService {
  SportsApiAppService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 15);

  Uri _uri(String route, [Map<String, String> query = const <String, String>{}]) {
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) {
      throw const SportsApiException('La URL del servidor deportivo no es válida.');
    }
    return Uri.parse('$base$route').replace(queryParameters: query.isEmpty ? null : query);
  }

  Future<dynamic> _get(String route, [Map<String, String> query = const <String, String>{}]) async {
    try {
      final response = await _client.get(
        _uri(route, query),
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        String message = 'El servidor SportsAPI respondió HTTP ${response.statusCode}.';
        try {
          final error = jsonDecode(response.body);
          if (error is Map && error['error'] != null) {
            final value = error['error'];
            message = value is Map
                ? (value['message'] ?? value['code'] ?? message).toString()
                : value.toString();
          }
        } catch (_) {
          // Conserva el código HTTP si el servidor no devuelve JSON.
        }
        throw SportsApiException(message);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || !decoded.containsKey('data')) {
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

  Future<List<Map<String, dynamic>>> fetchFavoriteSports() async {
    final response = await _get('/api/sportsapi/favorites');
    if (response is! Map) return <Map<String, dynamic>>[];
    final sports = response['sports'];
    if (sports is! List) return <Map<String, dynamic>>[];
    return sports.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<dynamic> fetchFixtureStatistics(int fixtureId) {
    return _get('/api/sportsapi/statistics', <String, String>{
      'type': 'fixture-statistics',
      'id': fixtureId.toString(),
    });
  }

  Future<dynamic> fetchRaceResults(int raceId, {int? sessionId}) {
    return _get('/api/sportsapi/statistics', <String, String>{
      'type': 'race-results',
      'id': raceId.toString(),
      if (sessionId != null) 'session': sessionId.toString(),
    });
  }

  Future<dynamic> fetchLeagueStandings({
    required int leagueId,
    required int seasonId,
  }) {
    return _get('/api/sportsapi/statistics', <String, String>{
      'type': 'league-standings',
      'id': leagueId.toString(),
      'season': seasonId.toString(),
    });
  }

  Future<dynamic> fetchSeriesStandings({
    required int seriesId,
    required int seasonId,
  }) {
    return _get('/api/sportsapi/statistics', <String, String>{
      'type': 'series-standings',
      'id': seriesId.toString(),
      'season': seasonId.toString(),
    });
  }
}
