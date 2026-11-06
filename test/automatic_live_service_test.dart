import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deporte_total_360/automatic_live_service.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';
import 'package:deporte_total_360/live_channels_screen.dart';
import 'package:deporte_total_360/live_media_format.dart';
import 'package:deporte_total_360/sports_api_service.dart';

String _xmlTime(DateTime date) {
  final utc = date.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}${two(utc.hour)}${two(utc.minute)}${two(utc.second)} +0000';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sportsApiBaseUrl.value = defaultSportsApiBaseUrl;
  });

  group('configuración EPG', () {
    test('migra la EPG predeterminada anterior sin borrar preferencias personalizadas', () async {
      await AutoLiveSettings.save(
        playlistUrl: defaultAutoLivePlaylistUrls,
        epgUrl: previousDefaultAutoLiveEpgUrl,
        authorizationConfirmed: true,
      );

      final settings = await AutoLiveSettings.load();

      expect(settings.epgUrl, defaultAutoLiveEpgUrl);
      expect(settings.epgUrls, contains('https://iptv-epg.org/files/epg-do.xml'));
      expect(settings.epgUrls, contains('https://iptv-epg.org/files/epg-gb.xml'));
    });
  });

  group('agenda deportiva MARCA', () {
    test('no reutiliza eventos persistidos por la agenda anterior', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'dt360_futbol_libre_events_v1':
            '[{"id":"legacy","title":"Evento antiguo","sport":"Fútbol",'
            '"startsAt":"2026-11-03T18:00:00.000",'
            '"detailUrl":"https://futbol-libre.cam/legacy"}]',
      });

      expect(await SportsAgendaStore.load(), isEmpty);
    });

    test('guarda y recupera eventos de la agenda nueva', () async {
      final event = SportsAgendaEvent(
        id: 'marca-event-1',
        title: 'Equipo Azul vs Equipo Rojo',
        sport: 'Fútbol',
        competition: 'Liga de prueba',
        homeTeam: 'Equipo Azul',
        awayTeam: 'Equipo Rojo',
        homeTeamLogo: 'https://img.example/azul.png',
        awayTeamLogo: 'https://img.example/rojo.png',
        participants: const <SportsAgendaParticipant>[
          SportsAgendaParticipant(
            name: 'Carlos Alcaraz',
            imageUrl: 'https://img.example/alcaraz.png',
            country: 'España',
          ),
        ],
        venue: 'Estadio de prueba',
        startsAt: DateTime.now().add(const Duration(hours: 1)),
        detailUrl: 'https://www.marca.com/programacion-tv.html',
      );

      await SportsAgendaStore.save(<SportsAgendaEvent>[event]);
      final saved = await SportsAgendaStore.load();

      expect(saved, hasLength(1));
      expect(saved.single.id, 'marca-event-1');
      expect(saved.single.homeTeamLogo, 'https://img.example/azul.png');
      expect(saved.single.awayTeamLogo, 'https://img.example/rojo.png');
      expect(saved.single.participants.single.name, 'Carlos Alcaraz');
      expect(saved.single.participants.single.imageUrl, 'https://img.example/alcaraz.png');
      expect(saved.single.venue, 'Estadio de prueba');
      expect(saved.single.detailUrl, 'https://www.marca.com/programacion-tv.html');
    });
  });

  group('agenda y transmisiones publicadas desde Cloudflare', () {
    test('recibe eventos y señales verificadas desde el endpoint central', () async {
      final start = DateTime.now().add(const Duration(minutes: 5));
      final stop = start.add(const Duration(hours: 2));
      sportsApiBaseUrl.value = 'https://worker.example';
      final client = MockClient((request) async {
        expect(request.url.path, '/api/live/auto/schedule');
        return http.Response(jsonEncode(<String, dynamic>{
          'status': 'ok',
          'source': 'marca',
          'events': <Map<String, dynamic>>[
            <String, dynamic>{
              'event': <String, dynamic>{
                'id': 'cloud-event-1',
                'title': 'Equipo Azul vs Equipo Rojo',
                'sport': 'Fútbol',
                'competition': 'Liga de prueba',
                'homeTeam': 'Equipo Azul',
                'awayTeam': 'Equipo Rojo',
                'homeTeamLogo': <String, dynamic>{
                  'url': '//img.example/azul.png',
                },
                'awayTeamLogo': <String, dynamic>{
                  'contentUrl': '/assets/escudos/rojo.svg',
                },
                'participants': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': 'Equipo Azul',
                    'imageUrl': <String, dynamic>{
                      'src': '//img.example/azul.png',
                    },
                    'country': 'España',
                    'role': 'home',
                  },
                ],
                'venue': 'Estadio de prueba',
                'startsAt': start.toUtc().toIso8601String(),
                'endsAt': stop.toUtc().toIso8601String(),
                'detailUrl': 'https://www.marca.com/programacion-tv.html',
              },
              'removeAt': stop.toUtc().toIso8601String(),
              'state': 'verified',
              'sources': <Map<String, dynamic>>[
                <String, dynamic>{
                  'channelName': 'Canal Deportes ES',
                  'url': 'https://media.example/live.m3u8',
                  'programmeTitle': 'Equipo Azul vs Equipo Rojo',
                  'programmeEndsAt': stop.toUtc().toIso8601String(),
                  'qualityScore': 400,
                  'languagePriority': 2,
                  'available': true,
                },
              ],
            },
          ],
        }), 200);
      });

      final result = await AutomaticLiveService(client: client)
          .fetchPublishedSchedule();

      expect(result, hasLength(1));
      expect(result!.single.event.id, 'cloud-event-1');
      expect(result.single.event.homeTeamLogo, 'https://img.example/azul.png');
      expect(result.single.event.awayTeamLogo,
          'https://www.marca.com/assets/escudos/rojo.svg');
      expect(result.single.event.participants.single.name, 'Equipo Azul');
      expect(result.single.event.participants.single.country, 'España');
      expect(result.single.event.venue, 'Estadio de prueba');
      expect(result.single.sources.single.channelName, 'Canal Deportes ES');
      expect(result.single.sources.single.languagePriority, 2);
      expect(result.single.sources.single.available, isTrue);
    });

    test('una respuesta remota válida sin eventos no reutiliza la agenda local antigua', () async {
      sportsApiBaseUrl.value = 'https://worker.example';
      final client = MockClient((request) async => http.Response(
        jsonEncode(<String, dynamic>{
          'status': 'ok',
          'source': 'marca',
          'events': <dynamic>[],
        }),
        200,
      ));

      final result = await AutomaticLiveService(client: client)
          .fetchPublishedSchedule();

      expect(result, isEmpty);
    });

    test('usa la agenda local si el Worker todavía no publica el nuevo endpoint', () async {
      sportsApiBaseUrl.value = 'https://worker.example';
      final client = MockClient((request) async =>
          http.Response('{"error":"not found"}', 404));

      final result = await AutomaticLiveService(client: client)
          .fetchPublishedSchedule();

      expect(result, isNull);
      sportsApiBaseUrl.value = defaultSportsApiBaseUrl;
    });
  });

  group('tablero fijo de transmisiones', () {
    testWidgets('mantiene seis cuadros visibles con desplazamiento cuando es necesario', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LivePlayerBoard(sources: <LivePlayerSource>[]),
          ),
        ),
      );

      for (var channel = 1; channel <= 6; channel++) {
        expect(
          find.text('DEPORTE TOTAL 360° CANAL $channel'),
          findsOneWidget,
        );
      }
      expect(find.text('ESPERANDO TRANSMISIÓN'), findsNWidgets(6));
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.physics, isA<BouncingScrollPhysics>());
    });

    testWidgets('muestra el próximo evento con su horario mientras espera la señal', (tester) async {
      const waitingEvent = LivePlayerWaitingEvent(
        heading: 'Fútbol · Liga de prueba',
        match: 'Equipo Azul vs Equipo Rojo',
        startLabel: 'Comienza 19:30',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LivePlayerBoard(
              sources: <LivePlayerSource>[],
              waitingEvents: <LivePlayerWaitingEvent>[waitingEvent],
            ),
          ),
        ),
      );

      expect(find.text('Fútbol · Liga de prueba'), findsOneWidget);
      expect(find.text('Equipo Azul vs Equipo Rojo'), findsOneWidget);
      expect(find.text('Comienza 19:30'), findsOneWidget);
      expect(find.text('ESPERANDO TRANSMISIÓN'), findsNWidgets(6));
    });

    testWidgets('muestra el evento asignado y espera en los otros cinco canales', (tester) async {
      const source = LivePlayerSource(
        title: 'DEPORTE TOTAL 360° CANAL 1',
        url: 'https://media.example/evento.m3u8',
        subtitle: 'Fútbol · Liga · Tigres vs Atlas',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LivePlayerBoard(sources: <LivePlayerSource>[source]),
          ),
        ),
      );

      expect(find.text('DEPORTE TOTAL 360° CANAL 1'), findsOneWidget);
      expect(find.text('Fútbol · Liga · Tigres vs Atlas'), findsOneWidget);
      expect(find.byTooltip('Reproducir en pantalla completa'), findsOneWidget);
      expect(find.text('ESPERANDO TRANSMISIÓN'), findsNWidgets(5));
    });
  });

  group('configuración internacional', () {
    test('carga siete listas automáticamente y diecinueve EPG sin pedir validación', () async {
      final settings = await AutoLiveSettings.load();

      expect(settings.playlistUrls, hasLength(12));
      expect(settings.playlistUrls.every(isSafeHttpUrl), isTrue);
      expect(settings.epgUrls, hasLength(20));
      expect(settings.epgUrls.every(isSafeHttpUrl), isTrue);
      expect(settings.playlistUrls.first, contains('teleonline'));
      expect(settings.playlistUrls[1], contains('languages/spa.m3u'));
      expect(settings.playlistUrls[2], contains('countries/es.m3u'));
      expect(settings.epgUrls.first, contains('epg-es.xml'));
      expect(settings.epgUrls[18], contains('teleonline/listas/main/epg.xml.gz'));
      expect(settings.isConfigured, isTrue);
    });

    test('migra las listas antiguas sin pedir autorización manual', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'dt360_auto_live_playlist_url_v1': legacyDefaultAutoLivePlaylistUrls,
        'dt360_auto_live_epg_url_v1': legacyDefaultAutoLiveEpgUrl,
        'dt360_auto_live_authorized_v1': true,
      });

      final settings = await AutoLiveSettings.load();

      expect(settings.playlistUrls, hasLength(12));
      expect(settings.epgUrls, hasLength(20));
      expect(settings.authorizationConfirmed, isTrue);
      expect(settings.isConfigured, isTrue);
    });

    test('restaura fuentes automáticas cuando una versión anterior dejó las listas vacías', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'dt360_auto_live_playlist_url_v1': '',
        'dt360_auto_live_epg_url_v1': '',
        'dt360_auto_live_authorized_v1': false,
      });

      final settings = await AutoLiveSettings.load();

      expect(settings.isConfigured, isTrue);
      expect(settings.playlistUrls, hasLength(12));
      expect(settings.epgUrls, hasLength(20));
    });
  });

  group('captura de agenda', () {
    test('reemplaza los eventos anteriores y borra los que ya no aparecen', () async {
      final now = DateTime.now();
      SportsAgendaEvent event(String id) => SportsAgendaEvent(
        id: id,
        title: 'Equipo $id vs Rival $id',
        sport: 'Fútbol',
        startsAt: now.add(const Duration(hours: 1)),
        detailUrl: 'https://www.marca.com/programacion-tv.html$id',
      );

      await SportsAgendaStore.save(<SportsAgendaEvent>[event('anterior')]);
      expect((await SportsAgendaStore.load()).single.id, 'anterior');

      await SportsAgendaStore.save(<SportsAgendaEvent>[event('actual')]);
      expect((await SportsAgendaStore.load()).map((row) => row.id), <String>['actual']);

      await SportsAgendaStore.save(const <SportsAgendaEvent>[]);
      expect(await SportsAgendaStore.load(), isEmpty);
    });
  });

  group('formatos multimedia de las listas M3U', () {
    test('clasifica HLS, DASH, Smooth Streaming y contenedores directos', () {
      expect(
        liveMediaFormatForUrl('https://cdn.example/live/master.m3u8?token=abc'),
        LiveMediaFormat.hls,
      );
      expect(
        liveMediaFormatForUrl('https://cdn.example/live/manifest.mpd?sig=123'),
        LiveMediaFormat.dash,
      );
      expect(
        liveMediaFormatForUrl('https://cdn.example/channel.ism/Manifest'),
        LiveMediaFormat.smoothStreaming,
      );
      expect(
        liveMediaFormatForUrl('https://cdn.example/channel.ts'),
        LiveMediaFormat.progressive,
      );
      expect(
        liveMediaFormatForUrl('https://cdn.example/channel.mp4'),
        LiveMediaFormat.progressive,
      );
      expect(
        liveMediaFormatForUrl('https://cdn.example/channel.webm'),
        LiveMediaFormat.progressive,
      );
    });

    test('no confunde una lista M3U o una página HTML con una señal de vídeo', () {
      expect(liveMediaFormatForUrl('https://cdn.example/channels.m3u'), isNull);
      expect(liveMediaFormatForUrl('https://cdn.example/watch?id=22'), isNull);
      expect(liveMediaFormatForUrl('https://cdn.example/live.m3u8'), LiveMediaFormat.hls);
      expect(liveMediaFormatForUrl('rtmp://cdn.example/live/channel'), isNull);
      expect(liveMediaFormatForUrl('https://user:pass@cdn.example/live.m3u8'), isNull);
    });

    test('resuelve enlaces relativos de una playlist M3U contra su URL', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="dash.event",Canal DASH
../streams/event.mpd?token=ok
#EXTINF:-1 tvg-id="raw.ts",Canal TS
https://cdn.example/live/event.ts
''';

      final channels = AutomaticLiveService.parseM3u(
        playlist,
        baseUri: Uri.parse('https://catalog.example/lists/today/sports.m3u'),
      );

      expect(channels, hasLength(2));
      expect(
        channels.map((channel) => channel.url).toList(),
        <String>[
          'https://catalog.example/lists/streams/event.mpd?token=ok',
          'https://cdn.example/live/event.ts',
        ],
      );
    });
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

    test('lee idioma y país del canal para priorizar el español', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="es.sports" tvg-language="Spanish" tvg-country="ES" group-title="Sports",Teledeporte
https://media.example/teledeporte.m3u8
''';
      final channel = AutomaticLiveService.parseM3u(playlist).single;

      expect(channel.language, 'Spanish');
      expect(channel.country, 'ES');
      expect(channel.languagePriority, 2);
    });

    test('usa la segunda lista M3U si la primera está caída', () async {
      final start = DateTime.now().toUtc().add(const Duration(hours: 1));
      final stop = start.add(const Duration(hours: 2));
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="sports.backup",Sports Backup HD
https://media.example/backup.m3u8
''';
      final xml = '<tv><channel id="sports.backup"><display-name>Sports Backup</display-name></channel>'
          '<programme channel="sports.backup" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}">'
          '<title>Equipo Azul vs Equipo Rojo</title></programme></tv>';
      final client = MockClient((request) async {
        if (request.url.host == 'offline.example' ||
            request.url.host == 'offline-guide.example') {
          return http.Response('offline', 503);
        }
        if (request.url.host == 'backup.example') return http.Response(playlist, 200);
        if (request.url.host == 'guide.example') return http.Response(xml, 200);
        return http.Response('', 404);
      });

      final catalog = await AutomaticLiveService(client: client).loadCatalog(
        playlistUrl: 'https://offline.example/sports.m3u\nhttps://backup.example/sports.m3u',
        epgUrl: 'https://offline-guide.example/guide.xml\nhttps://guide.example/guide.xml',
      );

      expect(catalog.channels, hasLength(1));
      expect(catalog.channels.single.tvgId, 'sports.backup');
      expect(catalog.programmes, hasLength(1));
    });

    test('acepta enlaces DASH en el catálogo de canales', () {
      final channel = SportsChannel.fromJson(<String, dynamic>{
        'id': 'dash-1',
        'identifier': 'dash-1',
        'name': 'Canal DASH',
        'url': 'https://media.example/live/manifest.mpd',
        'isSports': true,
        'visible': true,
      });

      expect(channel.url, 'https://media.example/live/manifest.mpd');
    });

    test('clasifica un 403 como posible bloqueo regional', () async {
      final client = MockClient((request) async =>
          http.Response('Forbidden', 403));
      final service = ChannelCatalogService(
        client: client,
        googleServerClientId: 'test-client',
      );

      final result = await service.diagnoseStream(
        'https://media.example/sports.m3u8',
      );

      expect(result, contains('posible restricción regional'));
      expect(result, contains('No se puede confirmar'));
    });

    test('mantiene los canales aunque todas las guías EPG estén caídas', () async {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="sports.available",Sports Available
https://media.example/sports.m3u8
''';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('.m3u')) {
          return http.Response(playlist, 200);
        }
        return http.Response('temporarily unavailable', 503);
      });

      final catalog = await AutomaticLiveService(client: client).loadCatalog(
        playlistUrl: 'https://playlist.example/sports.m3u',
        epgUrl: 'https://epg.example/guide.xml',
      );

      expect(catalog.channels, hasLength(1));
      expect(catalog.programmes, isEmpty);
    });

    test('combina programas de varias guías EPG y sigue si una falla', () async {
      final start = DateTime.now().toUtc().add(const Duration(hours: 1));
      final stop = start.add(const Duration(hours: 2));
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="sports.backup" group-title="Deportes",Sports Backup HD
https://media.example/backup.m3u8
''';
      final guideOne = '<tv><programme channel="sports.backup" '
          'start="${_xmlTime(start)}" stop="${_xmlTime(stop)}">'
          '<title>Equipo Azul vs Equipo Rojo</title></programme></tv>';
      final guideTwo = '<tv><programme channel="sports.backup" '
          'start="${_xmlTime(start)}" stop="${_xmlTime(stop)}">'
          '<title>Equipo Verde vs Equipo Blanco</title></programme></tv>';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('.m3u')) return http.Response(playlist, 200);
        if (request.url.host == 'epg-offline.example') {
          return http.Response('unavailable', 503);
        }
        if (request.url.host == 'epg-one.example') return http.Response(guideOne, 200);
        if (request.url.host == 'epg-two.example') return http.Response(guideTwo, 200);
        return http.Response('', 404);
      });

      final catalog = await AutomaticLiveService(client: client).loadCatalog(
        playlistUrl: 'https://playlist.example/sports.m3u',
        epgUrl: 'https://epg-offline.example/guide.xml\n'
            'https://epg-one.example/guide.xml\n'
            'https://epg-two.example/guide.xml',
      );

      expect(catalog.channels, hasLength(1));
      expect(catalog.programmes, hasLength(2));
      expect(
        catalog.programmes.map((programme) => programme.title).toSet(),
        containsAll(<String>[
          'Equipo Azul vs Equipo Rojo',
          'Equipo Verde vs Equipo Blanco',
        ]),
      );
    });

    test('asocia el ID XMLTV con el nombre publicado del canal', () {
      final start = DateTime.utc(2026, 11, 3, 14);
      final stop = start.add(const Duration(hours: 2));
      final xml = '<tv><channel id="sports.id"><display-name>Sports HD</display-name></channel>'
          '<programme channel="sports.id" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}">'
          '<title>Equipo Azul vs Equipo Rojo</title></programme></tv>';
      final rows = AutomaticLiveService.parseXmltv(xml);
      expect(rows, hasLength(1));
      expect(rows.single.channelId, 'sports.id');
      expect(rows.single.channelName, 'Sports HD');
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
      final start = DateTime.fromMillisecondsSinceEpoch((DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000) * 1000);
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
        if (request.url.path.endsWith('.ts')) return http.Response('segment bytes', 200);
        if (request.url.path.endsWith('.m3u8')) {
          return http.Response('#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,\nsegment.ts\n', 200);
        }
        return http.Response('', 404);
      });
      final service = AutomaticLiveService(client: client);
      const settings = AutoLiveSettings(
        playlistUrl: 'https://provider.example/channels.m3u',
        epgUrl: 'https://provider.example/guide.xml',
        authorizationConfirmed: true,
      );
      final event = SportsAgendaEvent(
        id: 'match-1',
        title: 'Equipo Azul vs Equipo Rojo',
        sport: 'Fútbol',
        homeTeam: 'Equipo Azul',
        awayTeam: 'Equipo Rojo',
        startsAt: start,
        detailUrl: 'https://www.marca.com/programacion-tv.html',
      );

      final tooEarly = await service.schedule(
        events: <SportsAgendaEvent>[event],
        now: start.subtract(const Duration(minutes: 11)),
        settings: settings,
      );
      expect(tooEarly, isEmpty);

      final prepared = await service.schedule(
        events: <SportsAgendaEvent>[event],
        now: start.subtract(const Duration(minutes: 10)),
        settings: settings,
      );
      expect(prepared, hasLength(1));
      expect(prepared.single.sources, hasLength(1));
      expect(prepared.single.sources.single.channelName, 'Sports HD 1080p');
      expect(prepared.single.sources.single.url, 'https://media.example/sports-hd.m3u8');
      expect(prepared.single.sources.single.available, isTrue);
      expect(prepared.single.removeAt, stop);
    });


    test('verifica un manifiesto DASH antes de asignarlo al evento', () async {
      final start = DateTime.now().add(const Duration(minutes: 10));
      final stop = start.add(const Duration(hours: 2));
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="dash.sports",Sports DASH HD
https://media.example/sports.mpd
''';
      final xml = '<tv><channel id="dash.sports">'
          '<display-name>Sports DASH</display-name></channel>'
          '<programme channel="dash.sports" start="' + _xmlTime(start) + '" '
          'stop="' + _xmlTime(stop) + '"><title>Equipo Azul vs Equipo Rojo</title>'
          '</programme></tv>';
      const mpd = '''<?xml version="1.0"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="dynamic">
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation id="video-1" bandwidth="1200000">
        <BaseURL>video.mp4</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('.m3u')) return http.Response(playlist, 200);
        if (request.url.path.endsWith('.xml')) return http.Response(xml, 200);
        if (request.url.path.endsWith('.mpd')) return http.Response(mpd, 200);
        return http.Response('', 404);
      });
      final event = SportsAgendaEvent(
        id: 'dash-event',
        title: 'Equipo Azul vs Equipo Rojo',
        sport: 'Fútbol',
        homeTeam: 'Equipo Azul',
        awayTeam: 'Equipo Rojo',
        startsAt: start,
        detailUrl: 'https://www.marca.com/programacion-tv.html',
      );

      final result = await AutomaticLiveService(client: client).schedule(
        events: <SportsAgendaEvent>[event],
        now: start.subtract(const Duration(minutes: 10)),
        settings: const AutoLiveSettings(
          playlistUrl: 'https://provider.example/channels.m3u',
          epgUrl: 'https://provider.example/guide.xml',
          authorizationConfirmed: true,
        ),
      );

      expect(result, hasLength(1));
      expect(result.single.sources.single.url, 'https://media.example/sports.mpd');
      expect(result.single.sources.single.available, isTrue);
    });

    test('prioriza un canal en español antes que una señal extranjera de mayor resolución', () async {
      final start = DateTime.now().add(const Duration(minutes: 10));
      final stop = start.add(const Duration(hours: 2));
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="sports.en" tvg-language="English" group-title="Sports",Sports HD 1080p
https://media.example/english.m3u8
#EXTINF:-1 tvg-id="sports.es" tvg-language="Spanish" tvg-country="ES" group-title="Sports",Teledeporte
https://media.example/spanish.m3u8
''';
      final xml = '<tv>'
          '<programme channel="sports.en" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}"><title>Equipo Azul vs Equipo Rojo</title></programme>'
          '<programme channel="sports.es" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}"><title>Equipo Azul vs Equipo Rojo</title></programme>'
          '</tv>';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('.m3u')) return http.Response(playlist, 200);
        if (request.url.path.endsWith('.xml')) return http.Response(xml, 200);
        if (request.url.path.endsWith('.ts')) return http.Response('segment bytes', 200);
        if (request.url.path.endsWith('.m3u8')) {
          return http.Response('#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,\nsegment.ts\n', 200);
        }
        return http.Response('', 404);
      });
      final event = SportsAgendaEvent(
        id: 'spanish-priority',
        title: 'Equipo Azul vs Equipo Rojo',
        sport: 'Fútbol',
        homeTeam: 'Equipo Azul',
        awayTeam: 'Equipo Rojo',
        startsAt: start,
        detailUrl: 'https://www.marca.com/programacion-tv.html',
      );
      final result = await AutomaticLiveService(client: client).schedule(
        events: <SportsAgendaEvent>[event],
        now: start.subtract(const Duration(minutes: 10)),
        settings: const AutoLiveSettings(
          playlistUrl: 'https://provider.example/channels.m3u',
          epgUrl: 'https://provider.example/guide.xml',
          authorizationConfirmed: false,
        ),
      );

      expect(result, hasLength(1));
      expect(result.single.sources.single.channelName, 'Teledeporte');
      expect(result.single.sources.single.languagePriority, 2);
    });

    test('usa otros idiomas solo cuando ninguna señal española está disponible', () async {
      final start = DateTime.now().add(const Duration(minutes: 10));
      final stop = start.add(const Duration(hours: 2));
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="sports.es" tvg-language="Spanish" group-title="Sports",Teledeporte
https://media.example/spanish.m3u8
#EXTINF:-1 tvg-id="sports.en" tvg-language="English" group-title="Sports",Sports International HD
https://media.example/international.m3u8
''';
      final xml = '<tv>'
          '<programme channel="sports.es" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}"><title>Equipo Azul vs Equipo Rojo</title></programme>'
          '<programme channel="sports.en" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}"><title>Equipo Azul vs Equipo Rojo</title></programme>'
          '</tv>';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('.m3u')) return http.Response(playlist, 200);
        if (request.url.path.endsWith('.xml')) return http.Response(xml, 200);
        if (request.url.path.endsWith('spanish.m3u8')) return http.Response('offline', 503);
        if (request.url.path.endsWith('.ts')) return http.Response('segment bytes', 200);
        if (request.url.path.endsWith('international.m3u8')) {
          return http.Response('#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,\nsegment.ts\n', 200);
        }
        return http.Response('', 404);
      });
      final event = SportsAgendaEvent(
        id: 'language-fallback',
        title: 'Equipo Azul vs Equipo Rojo',
        sport: 'Fútbol',
        homeTeam: 'Equipo Azul',
        awayTeam: 'Equipo Rojo',
        startsAt: start,
        detailUrl: 'https://www.marca.com/programacion-tv.html',
      );
      final result = await AutomaticLiveService(client: client).schedule(
        events: <SportsAgendaEvent>[event],
        now: start.subtract(const Duration(minutes: 10)),
        settings: const AutoLiveSettings(
          playlistUrl: 'https://provider.example/channels.m3u',
          epgUrl: 'https://provider.example/guide.xml',
          authorizationConfirmed: false,
        ),
      );

      expect(result, hasLength(1));
      expect(result.single.sources.single.channelName, 'Sports International HD');
    });

    test('reconoce abreviaturas de equipos al cruzar el EPG', () {
      final event = SportsAgendaEvent(
        id: 'alias-match',
        title: 'Manchester United vs Paris Saint-Germain',
        sport: 'Fútbol',
        homeTeam: 'Manchester United',
        awayTeam: 'Paris Saint-Germain',
        startsAt: DateTime.now().add(const Duration(hours: 1)),
        detailUrl: 'https://www.marca.com/programacion-tv.html',
      );

      expect(
        AutomaticLiveService.programmeMatchesEvent('Man Utd vs PSG', event),
        isTrue,
      );
    });

    test('mantiene varios eventos simultáneos en entradas separadas', () async {
      final start = DateTime.now().add(const Duration(minutes: 10));
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
      final client = MockClient((request) async {
        if (request.url.path.endsWith('.m3u')) return http.Response(playlist, 200);
        if (request.url.path.endsWith('.xml')) return http.Response(xml, 200);
        if (request.url.path.endsWith('.ts')) return http.Response('segment bytes', 200);
        if (request.url.path.endsWith('.m3u8')) {
          return http.Response('#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,\nsegment.ts\n', 200);
        }
        return http.Response('', 404);
      });
      final events = <SportsAgendaEvent>[
        SportsAgendaEvent(
          id: 'one', title: 'Azul vs Rojo', sport: 'Fútbol',
          startsAt: start, detailUrl: 'https://www.marca.com/programacion-tv.html',
        ),
        SportsAgendaEvent(
          id: 'two', title: 'Verde vs Blanco', sport: 'Fútbol',
          startsAt: start,
          detailUrl: 'https://www.marca.com/programacion-tv.html',
        ),
      ];
      final result = await AutomaticLiveService(client: client).schedule(
        events: events,
        now: start.subtract(const Duration(minutes: 10)),
        settings: const AutoLiveSettings(
          playlistUrl: 'https://provider.example/channels.m3u',
          epgUrl: 'https://provider.example/guide.xml',
          authorizationConfirmed: true,
        ),
      );
      expect(result.map((item) => item.event.id), <String>['one', 'two']);
      expect(result.every((item) => item.sources.length == 1), isTrue);
      expect(result.every((item) => item.sources.single.available), isTrue);
    });

    test('no asigna una señal cuando falla la comprobación de disponibilidad', () async {
      final start = DateTime.now().add(const Duration(minutes: 10));
      final stop = start.add(const Duration(hours: 1));
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="football.one",Football HD
https://media.example/offline.m3u8
''';
      final xml = '<tv>'
          '<programme channel="football.one" start="${_xmlTime(start)}" stop="${_xmlTime(stop)}"><title>Azul vs Rojo</title></programme>'
          '</tv>';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('.m3u')) return http.Response(playlist, 200);
        if (request.url.path.endsWith('.xml')) return http.Response(xml, 200);
        if (request.url.path.endsWith('.m3u8')) return http.Response('offline', 503);
        return http.Response('', 404);
      });
      final event = SportsAgendaEvent(
        id: 'offline',
        title: 'Azul vs Rojo',
        sport: 'Fútbol',
        startsAt: start,
        detailUrl: 'https://www.marca.com/programacion-tv.html',
      );
      final result = await AutomaticLiveService(client: client).schedule(
        events: <SportsAgendaEvent>[event],
        now: start.subtract(const Duration(minutes: 10)),
        settings: const AutoLiveSettings(
          playlistUrl: 'https://provider.example/channels.m3u',
          epgUrl: 'https://provider.example/guide.xml',
          authorizationConfirmed: true,
        ),
      );

      expect(result, isEmpty);
    });

    test('no empareja un programa que pertenece a otro evento', () {
      final event = SportsAgendaEvent(
        id: 'match',
        title: 'Equipo Azul vs Equipo Rojo',
        sport: 'Fútbol',
        startsAt: DateTime.now().add(const Duration(hours: 1)),
        detailUrl: 'https://www.marca.com/programacion-tv.html',
      );
      expect(
        AutomaticLiveService.programmeMatchesEvent(
          'Equipo Verde vs Equipo Blanco',
          event,
        ),
        isFalse,
      );
    });
    test('matches a motorsport race using its race name and series', () {
      final event = SportsAgendaEvent(
        id: 'sportsapi-race-10-20',
        title: 'Singapore GP',
        sport: 'Deportes de motor',
        competition: 'Formula 1',
        startsAt: DateTime.now().add(const Duration(hours: 1)),
        detailUrl: 'https://deporte-total-360-api.damian970609.workers.dev/api/sportsapi/races/10',
      );
      expect(
        AutomaticLiveService.programmeMatchesEvent(
          'Formula 1 Singapore Grand Prix',
          event,
        ),
        isTrue,
      );
    });

    test('matches UFC broadcasts by competition when fighter names are absent', () {
      final event = SportsAgendaEvent(
        id: 'sportsapi-fixture-20',
        title: 'Fighter One vs Fighter Two',
        sport: 'MMA',
        competition: 'UFC',
        homeTeam: 'Fighter One',
        awayTeam: 'Fighter Two',
        startsAt: DateTime.now().add(const Duration(hours: 1)),
        detailUrl: 'https://deporte-total-360-api.damian970609.workers.dev/api/sportsapi/fixtures/20',
      );
      expect(
        AutomaticLiveService.programmeMatchesEvent('UFC Fight Night live', event),
        isTrue,
      );
    });

  });
}
