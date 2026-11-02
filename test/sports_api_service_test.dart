import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/sports_api_service.dart';

void main() {
  group('SportsApiService.normalizeBaseUrl', () {
    test('normaliza HTTPS y elimina barras finales', () {
      expect(
        SportsApiService.normalizeBaseUrl('  https://example.com/api///  '),
        'https://example.com/api',
      );
    });

    test('rechaza HTTP y URLs con credenciales o parámetros', () {
      expect(SportsApiService.normalizeBaseUrl('http://example.com'), isNull);
      expect(
        SportsApiService.normalizeBaseUrl('https://user:pass@example.com'),
        isNull,
      );
      expect(
        SportsApiService.normalizeBaseUrl('https://example.com?token=x'),
        isNull,
      );
    });
  });
}
