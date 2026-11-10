import 'package:shared_preferences/shared_preferences.dart';

const String regionalPlaybackCountryPreferenceKey =
    'dt360_regional_playback_country_v1';
const String defaultRegionalPlaybackCountry = 'GY';

/// Una fuente solo se excluye cuando el proveedor declara explícitamente que
/// no está disponible en la región elegida. Los metadatos ausentes se tratan
/// como desconocidos, no como una autorización ni como una prohibición.
class RegionalStreamCandidate {
  const RegionalStreamCandidate({
    required this.url,
    this.label = '',
    this.availableCountries = const <String>[],
  });

  final String url;
  final String label;
  final List<String> availableCountries;
}

String normalizeRegionalCountryCode(String value) {
  final code = value.trim().toUpperCase();
  return RegExp(r'^[A-Z]{2}$').hasMatch(code) ? code : '';
}

/// Admite listas JSON y cadenas delimitadas que algunos catálogos M3U/API usan.
/// Los países de origen de la emisora (por ejemplo tvg-country) no deben
/// pasarse aquí: esta lista representa disponibilidad territorial confirmada.
List<String> parseAvailableCountryCodes(dynamic value) {
  final values = value is List
      ? value
      : value is String
          ? value.split(RegExp(r'[,;|\s]+'))
          : const <dynamic>[];
  final result = <String>{};
  for (final item in values) {
    final raw = item.toString().trim().toUpperCase();
    if (raw == '*' || raw == 'WORLD' || raw == 'GLOBAL') {
      result.add('*');
      continue;
    }
    final code = normalizeRegionalCountryCode(raw);
    if (code.isNotEmpty) result.add(code);
  }
  return result.toList(growable: false);
}

bool isRegionalStreamCandidateAllowed(
  RegionalStreamCandidate source,
  String regionCode,
) {
  final countries = parseAvailableCountryCodes(source.availableCountries);
  if (countries.isEmpty) return true; // disponibilidad desconocida
  final region = normalizeRegionalCountryCode(regionCode);
  return countries.contains('*') || (region.isNotEmpty && countries.contains(region));
}

/// Prioriza las fuentes declaradas disponibles en la región, conserva después
/// las de disponibilidad desconocida y excluye solo las declaradas no
/// disponibles. Mantiene el orden original dentro de cada grupo y elimina URL
/// duplicadas sin modificar las direcciones originales.
List<RegionalStreamCandidate> prioritizeRegionalStreamCandidates(
  Iterable<RegionalStreamCandidate> sources, {
  required String regionCode,
}) {
  final region = normalizeRegionalCountryCode(regionCode);
  final allowed = <RegionalStreamCandidate>[];
  final unknown = <RegionalStreamCandidate>[];
  final seenUrls = <String>{};

  for (final source in sources) {
    final url = source.url.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        !seenUrls.add(url)) {
      continue;
    }
    final countries = parseAvailableCountryCodes(source.availableCountries);
    if (countries.isEmpty) {
      unknown.add(source);
    } else if (countries.contains('*') ||
        (region.isNotEmpty && countries.contains(region))) {
      allowed.add(source);
    }
    // Si existe una lista de disponibilidad y no incluye la región, no se
    // prueba esa fuente desde esta región.
  }
  return <RegionalStreamCandidate>[...allowed, ...unknown];
}

class RegionalPlaybackPreferences {
  static Future<String> getRegionCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = normalizeRegionalCountryCode(
        prefs.getString(regionalPlaybackCountryPreferenceKey) ?? '',
      );
      return saved.isEmpty ? defaultRegionalPlaybackCountry : saved;
    } catch (_) {
      return defaultRegionalPlaybackCountry;
    }
  }

  /// Preferencia de región de reproducción, no cambia la IP ni crea una VPN.
  static Future<void> setRegionCode(String value) async {
    final code = normalizeRegionalCountryCode(value);
    if (code.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Usa un código ISO 3166-1 alpha-2.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(regionalPlaybackCountryPreferenceKey, code);
  }
}
