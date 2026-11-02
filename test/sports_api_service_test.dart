import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/sports_api_service.dart';

void main() {
  group('SportsApiService.sportIdFor', () {
    test('expone identificadores para los deportes del Worker', () {
      expect(SportsApiService.sportIdFor('Fútbol'), 'football');
      expect(SportsApiService.sportIdFor('Básquet'), 'basketball');
      expect(SportsApiService.sportIdFor('NBA'), 'nba');
      expect(SportsApiService.sportIdFor('Fórmula 1'), 'formula-1');
      expect(SportsApiService.sportIdFor('MMA'), 'mma');
      expect(SportsApiService.sportIdFor('Deporte desconocido'), isNull);
    });
  });

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
