import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/sports_api_service.dart';

void main() {
  group('SportsApiService', () {
    test('expone las doce categorías multideporte configuradas', () {
      expect(SportsApiService.supportedSports.length, 12);
      expect(SportsApiService.supportedSports['Fútbol'], 'football');
      expect(SportsApiService.supportedSports['NBA'], 'nba');
      expect(SportsApiService.supportedSports['Fútbol americano'], 'american-football');
      expect(SportsApiService.supportedSports['Fórmula 1'], 'formula-1');
      expect(SportsApiService.supportedSports['MMA'], 'mma');
    });

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
