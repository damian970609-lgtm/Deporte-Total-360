import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Dirección pública del Cloudflare Worker. No contiene ni almacena secretos.
final ValueNotifier<String> sportsApiBaseUrl = ValueNotifier<String>('');

class SportsApiService {
  static const Duration _timeout = Duration(seconds: 20);

  static String? normalizeBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return uri.replace(path: path).toString().replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> checkHealth([String? baseUrl]) async {
    final base = normalizeBaseUrl(baseUrl ?? sportsApiBaseUrl.value);
    if (base == null) {
      throw const SportsApiException('La URL del Worker no es válida.');
    }

    final response = await http
        .get(Uri.parse('$base/health'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw SportsApiException('El servidor respondió HTTP ${response.statusCode}.');
    }

    // El código HTTP 200 confirma que la ruta de salud responde.
    // No dependemos de un nombre concreto de campo JSON del Worker.
  }

  Future<List<Map<String, dynamic>>> fetchFixtures() async {
    final base = normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) {
      throw const SportsApiException('Configura la URL del servidor en el menú técnico.');
    }

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 6));
    String dateParam(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse('$base/api/fixtures').replace(
      queryParameters: <String, String>{
        'from': dateParam(start),
        'to': dateParam(end),
        'timezone': 'America/Guyana',
      },
    );

    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode == 204) return <Map<String, dynamic>>[];
    if (response.statusCode != 200) {
      throw SportsApiException('El servidor de partidos respondió HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const SportsApiException('La respuesta de la API no tiene el formato esperado.');
    }
    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      throw SportsApiException('El proveedor de fútbol devolvió errores: $errors');
    }

    final rows = decoded['response'];
    if (rows is! List) {
      throw const SportsApiException('La respuesta no contiene la lista de partidos.');
    }
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}

class SportsApiException implements Exception {
  const SportsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
