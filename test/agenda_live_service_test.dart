import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deporte_total_360/agenda_live_service.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';

SportsChannel _channel({
  required String id,
  required String name,
  required String url,
  bool visible = true,
  bool isSports = true,
  String language = 'es',
}) {
  return SportsChannel(
    id: id,
    identifier: id,
    name: name,
    url: url,
    isSports: isSports,
    visible: visible,
    language: language,
  );
}

Map<String, Object?> _event({
  String id = 'match-1',
  String title = 'Equipo Azul vs Equipo Rojo',
  required DateTime startsAt,
  DateTime? endsAt,
  List<String> channels = const <String>['Fuente 1 ESPN 2 · Español'],
  String status = 'unknown',
}) {
  return <String, Object?>{
    'id': id,
    'title': title,
    'competition': 'Liga de prueba',
    'startsAt': startsAt.toIso8601String(),
    if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
    'channelReferences': channels,
    'status': status,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('normaliza referencias conservando el número del canal', () {
    expect(
      normalizeAgendaChannelReference('Fuente 1: ESPN 2 HD · Español'),
      'espn 2',
    );
    expect(
      normalizeAgendaChannelReference('Canal 2 - DSports 2 UHD'),
      'dsports 2',
    );
    expect(
      normalizeAgendaChannelReference('ESPN 7'),
      isNot(normalizeAgendaChannelReference('ESPN 2')),
    );
    expect(
      normalizeAgendaChannelReference('ESPN2 HD'),
      normalizeAgendaChannelReference('ESPN 2'),
    );
  });

  test('prepara una señal dentro de los cinco minutos previos al evento', () async {
    final service = AgendaLiveService();
    final now = DateTime(2026, 11, 16, 18, 0);
    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: now.add(const Duration(minutes: 4))),
    ]);

    final beforeWindow = await service.buildBoardState(
      now: now.subtract(const Duration(minutes: 2)),
      channels: <SportsChannel>[
        _channel(
          id: 'espn-2',
          name: 'ESPN 2 HD',
          url: 'https://media.example/espn2.m3u8',
        ),
      ],
    );
    expect(beforeWindow.assignments, isEmpty);

    final insideWindow = await service.buildBoardState(
      now: now,
      channels: <SportsChannel>[
        _channel(
          id: 'espn-2',
          name: 'ESPN 2 HD',
          url: 'https://media.example/espn2.m3u8',
        ),
      ],
    );
    expect(insideWindow.assignments, hasLength(1));
    expect(insideWindow.assignments.single.channel.id, 'espn-2');
    expect(insideWindow.assignments.single.event.id, 'match-1');
  });

  test('solo usa canales deportivos visibles con URL directa compatible', () async {
    final service = AgendaLiveService();
    final now = DateTime(2026, 11, 16, 18, 0);
    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: now.add(const Duration(minutes: 2))),
    ]);

    final state = await service.buildBoardState(
      now: now,
      channels: <SportsChannel>[
        _channel(
          id: 'hidden',
          name: 'ESPN 2',
          url: 'https://media.example/hidden.m3u8',
          visible: false,
        ),
        _channel(
          id: 'not-sport',
          name: 'ESPN 2',
          url: 'https://media.example/general.m3u8',
          isSports: false,
        ),
        _channel(
          id: 'web-page',
          name: 'ESPN 2',
          url: 'https://media.example/watch',
        ),
      ],
    );

    expect(state.assignments, isEmpty);
    expect(state.pending, hasLength(1));
    expect(state.pending.single.status, 'BUSCANDO EN CANALES DEPORTIVOS');
  });

  test('no asigna más de un reproductor a la misma URL de canal', () async {
    final service = AgendaLiveService();
    final now = DateTime(2026, 11, 16, 18, 0);
    await service.captureAgendaEvents(<dynamic>[
      _event(
        id: 'match-1',
        title: 'Equipo Azul vs Equipo Rojo',
        startsAt: now.add(const Duration(minutes: 2)),
      ),
      _event(
        id: 'match-2',
        title: 'Equipo Verde vs Equipo Blanco',
        startsAt: now.add(const Duration(minutes: 3)),
      ),
    ]);

    final state = await service.buildBoardState(
      now: now,
      channels: <SportsChannel>[
        _channel(
          id: 'espn-2',
          name: 'ESPN 2',
          url: 'https://media.example/espn2.m3u8',
        ),
      ],
    );

    expect(state.assignments, hasLength(1));
    expect(state.assignments.single.event.id, 'match-1');
    expect(state.pending, hasLength(1));
  });

  test('conserva los canales ya capturados si una actualización de la agenda no los incluye', () async {
    final service = AgendaLiveService();
    final startsAt = DateTime(2026, 11, 16, 19, 0);
    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: startsAt),
    ]);
    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: startsAt, channels: const <String>[]),
    ]);

    final events = await service.loadCapturedEvents();
    expect(events, hasLength(1));
    expect(events.single.channelReferences, <String>['espn 2']);
  });

  test('retira el evento y libera su asignación cuando la Agenda lo marca finalizado', () async {
    final service = AgendaLiveService();
    final now = DateTime(2026, 11, 16, 20, 0);
    final startsAt = now.subtract(const Duration(hours: 1));
    final channel = _channel(
      id: 'espn-2',
      name: 'ESPN 2',
      url: 'https://media.example/espn2.m3u8',
    );
    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: startsAt),
    ]);
    final playing = await service.buildBoardState(
      now: now,
      channels: <SportsChannel>[channel],
    );
    expect(playing.assignments, hasLength(1));

    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: startsAt, status: 'finished'),
    ]);
    final finished = await service.buildBoardState(
      now: now,
      channels: <SportsChannel>[channel],
    );

    expect(finished.assignments, isEmpty);
    expect(await service.loadCapturedEvents(), isEmpty);
  });

  test('libera el canal al llegar la hora de fin y asigna el siguiente evento', () async {
    final service = AgendaLiveService();
    final now = DateTime(2026, 11, 16, 20, 0);
    await service.captureAgendaEvents(<dynamic>[
      _event(
        id: 'old-match',
        title: 'Equipo Azul vs Equipo Rojo',
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.subtract(const Duration(minutes: 1)),
      ),
      _event(
        id: 'next-match',
        title: 'Equipo Verde vs Equipo Blanco',
        startsAt: now.add(const Duration(minutes: 2)),
      ),
    ]);

    final state = await service.buildBoardState(
      now: now,
      channels: <SportsChannel>[
        _channel(
          id: 'espn-2',
          name: 'ESPN 2',
          url: 'https://media.example/espn2.m3u8',
        ),
      ],
    );

    expect(state.assignments, hasLength(1));
    expect(state.assignments.single.event.id, 'next-match');
    expect(
      (await service.loadCapturedEvents()).map((event) => event.id),
      <String>['next-match'],
    );
  });
}
