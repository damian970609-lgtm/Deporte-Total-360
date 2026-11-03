import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/futbol_libre_agenda.dart';

void main() {
  group('FutbolLibreAgenda', () {
    test('normaliza eventos y canales publicados por la WebView', () {
      final events = FutbolLibreEvent.parsePayload(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'match-2',
          'sport': 'Fútbol',
          'competition': 'Liga de prueba',
          'homeTeam': 'Equipo A',
          'awayTeam': 'Equipo B',
          'startsAt': '2026-11-03T20:00:00Z',
          'status': 'EN VIVO',
          'detailUrl': 'https://futbol-libre.cam/partido/2',
          'channels': <Map<String, String>>[
            <String, String>{
              'name': 'ESPN 2',
              'url': 'https://futbol-libre.cam/canal/espn-2',
            },
          ],
        },
        <String, dynamic>{
          'id': 'match-1',
          'sport': 'NBA',
          'competition': 'NBA',
          'homeTeam': 'Local',
          'awayTeam': 'Visitante',
          'startsAt': '2026-11-03T18:00:00Z',
          'status': 'PROGRAMADO',
        },
      ]);

      expect(events, hasLength(2));
      expect(events.first.id, 'match-1');
      expect(events.last.status, FutbolLibreEventStatus.live);
      expect(events.last.channels.single.name, 'ESPN 2');
      expect(
        events.last.channels.single.url,
        'https://futbol-libre.cam/canal/espn-2',
      );
      expect(events.last.detailUrl, 'https://futbol-libre.cam/partido/2');
    });

    test('ignora eventos incompletos y canales no web', () {
      final events = FutbolLibreEvent.parsePayload(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'invalid',
          'homeTeam': 'Equipo A',
          'awayTeam': 'Equipo B',
        },
        <String, dynamic>{
          'id': 'valid',
          'homeTeam': 'Equipo A',
          'awayTeam': 'Equipo B',
          'startsAt': '2026-11-03T19:00:00Z',
          'channels': <Map<String, String>>[
            <String, String>{'name': 'No seguro', 'url': 'javascript:alert(1)'},
          ],
        },
      ]);

      expect(events, hasLength(1));
      expect(events.single.channels, isEmpty);
    });
  });
}
