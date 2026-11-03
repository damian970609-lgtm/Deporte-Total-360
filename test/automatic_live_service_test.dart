import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deporte_total_360/automatic_live_service.dart';

String _xmlTime(DateTime date) {
  final utc = date.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}${two(utc.hour)}${two(utc.minute)}${two(utc.second)} +0000';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('M3U y XMLTV', () {
    test('lee canales directos, tvg-id y calidad del canal', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="sports.hd" tvg-name="Sports HD" group-title="Deportes",Sports HD 1080p
https://media.example/sports-hd.m3u8
#EXTINF:-1 tvg-id="sports.web" group-title="Deportes",Player web
https://media.example/watch?id=123
''';
      final channels = AutomaticLiveService.parseM3u(playlist);
      expect(channels, hasLength(1));
      expect(channels.single.tvgId, 'sports.hd');
      expect(channels.single.name, 'Sports HD 1080p');
    });

    test('lee horarios XMLTV con zona UTC', () {
      final start = DateTime.utc(2026, 11, 3, 14);
      final stop = start.add(const Duration(hours: 2));
      final xml = '<tv><programme channel="sports.hd" '
          'start="${_xmlTime(start)}" stop="${_xmlTime(stop)}">'
          '<title>Equipo Azul vs Equipo Rojo</title></programme></tv>';
      final rows = AutomaticLiveService.parseXmltv(xml);
      expect(rows, hasLength(1));
      expect(rows.single.title, 'Equipo Azul vs Equipo Rojo');
      expect(rows.single.startsAt.toUtc(), start);
    });
  });

  group('programación automática', () {
    test('espera hasta diez minutos antes y elige una sola señal de mayor calidad', () async {
      final start = DateTime(2026, 11, 3, 10, 10);
      final stop = start.add(const Duration(hours: 2));
      final playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="channel.sd" group-title="Sports",Sports SD
https://media.example/sports-sd.m3u8
#EXTINF:-1 tvg-id="channel.hd" group-title="Sports",Sports HD 1080p
https://media.example/sports-hd.m3u8
''';
      final xml = '<tv>'
          '<programme channel="channel.sd" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}"><title>Equipo Azul vs Equipo Rojo</title></programme>'
          '<programme channel="channel.hd" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}"><title>Equipo Azul vs Equipo Rojo</title></programme>'
          '</tv>';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('.m3u')) return http.Response(playlist, 200);
        if (request.url.path.endsWith('.xml')) return http.Response(xml, 200);
        return http.Response('', 404);
      });
      final service = AutomaticLiveService(client: client);
      const settings = AutoLiveSettings(
        playlistUrl: 'https://provider.example/channels.m3u',
        epgUrl: 'https://provider.example/guide.xml',
        authorizationConfirmed: true,
      );
      final event = FutbolLibreEvent(
        id: 'match-1',
        title: 'Equipo Azul vs Equipo Rojo',
        sport: 'Fútbol',
        homeTeam: 'Equipo Azul',
        awayTeam: 'Equipo Rojo',
        startsAt: start,
        detailUrl: 'https://futbol-libre.cam/partido/match-1',
      );

      final tooEarly = await service.schedule(
        events: <FutbolLibreEvent>[event],
        now: start.subtract(const Duration(minutes: 11)),
        settings: settings,
      );
      expect(tooEarly, isEmpty);

      final prepared = await service.schedule(
        events: <FutbolLibreEvent>[event],
        now: start.subtract(const Duration(minutes: 10)),
        settings: settings,
      );
      expect(prepared, hasLength(1));
      expect(prepared.single.sources, hasLength(1));
      expect(prepared.single.sources.single.channelName, 'Sports HD 1080p');
      expect(prepared.single.sources.single.url, 'https://media.example/sports-hd.m3u8');
      expect(prepared.single.removeAt, stop);
    });

    test('mantiene partidos simultáneos en entradas separadas', () async {
      final start = DateTime(2026, 11, 3, 10);
      final stop = start.add(const Duration(hours: 2));
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="football.one",Football 1080p
https://media.example/one.m3u8
#EXTINF:-1 tvg-id="football.two",Football 720p
https://media.example/two.m3u8
''';
      final xml = '<tv>'
          '<programme channel="football.one" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}"><title>Azul vs Rojo</title></programme>'
          '<programme channel="football.two" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}"><title>Verde vs Blanco</title></programme>'
          '</tv>';
      final client = MockClient((request) async =>
          http.Response(request.url.path.endsWith('.m3u') ? playlist : xml, 200));
      final events = <FutbolLibreEvent>[
        FutbolLibreEvent(
          id: 'one', title: 'Azul vs Rojo', sport: 'Fútbol',
          startsAt: start, detailUrl: 'https://futbol-libre.cam/one',
        ),
        FutbolLibreEvent(
          id: 'two', title: 'Verde vs Blanco', sport: 'Fútbol',
          startsAt: start.add(const Duration(minutes: 20)),
          detailUrl: 'https://futbol-libre.cam/two',
        ),
      ];
      final result = await AutomaticLiveService(client: client).schedule(
        events: events,
        now: start,
        settings: const AutoLiveSettings(
          playlistUrl: 'https://provider.example/channels.m3u',
          epgUrl: 'https://provider.example/guide.xml',
          authorizationConfirmed: true,
        ),
      );
      expect(result.map((item) => item.event.id), <String>['one', 'two']);
      expect(result.every((item) => item.sources.length == 1), isTrue);
    });

    test('no empareja un programa que pertenece a otro evento', () {
      const event = FutbolLibreEvent(
        id: 'match',
        title: 'Equipo Azul vs Equipo Rojo',
        sport: 'Fútbol',
        startsAt: DateTime(2026, 11, 3, 10),
        detailUrl: 'https://futbol-libre.cam/match',
      );
      expect(
        AutomaticLiveService.programmeMatchesEvent(
          'Equipo Verde vs Equipo Blanco',
          event,
        ),
        isFalse,
      );
    });
  });
}
