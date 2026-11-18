import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deporte_total_360/agenda_live_service.dart';

Map<String, Object?> _option({
  required String name,
  required String url,
  int order = 0,
  int popularityScore = 0,
}) => <String, Object?>{
      'name': name,
      'url': url,
      'order': order,
      'popularityScore': popularityScore,
    };

Map<String, Object?> _event({
  String id = 'match-1',
  String title = 'Equipo Azul vs Equipo Rojo',
  required DateTime startsAt,
  DateTime? endsAt,
  List<Map<String, Object?>> options = const <Map<String, Object?>>[],
  String status = 'unknown',
}) => <String, Object?>{
      'id': id,
      'title': title,
      'competition': 'Liga de prueba',
      'startsAt': startsAt.toIso8601String(),
      if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
      'channelReferences': const <String>['ESPN 2'],
      'transmissionOptions': options,
      'status': status,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('normaliza nombres conservando el número del canal', () {
    expect(normalizeAgendaChannelReference('Fuente 1: ESPN 2 HD · Español'), 'espn 2');
    expect(normalizeAgendaChannelReference('Canal 2 - DSports 2 UHD'), 'dsports 2');
    expect(normalizeAgendaChannelReference('ESPN 7'),
        isNot(normalizeAgendaChannelReference('ESPN 2')));
  });

  test('En vivo solo incluye eventos desde cinco minutos antes hasta su fin', () {
    final startsAt = DateTime(2026, 11, 18, 19);
    final event = AgendaEventReference.tryParse(
      _event(startsAt: startsAt),
    )!;

    expect(
      isAgendaEventWithinLiveWindow(
        event,
        startsAt.subtract(const Duration(minutes: 5, seconds: 1)),
      ),
      isFalse,
    );
    expect(
      isAgendaEventWithinLiveWindow(
        event,
        startsAt.subtract(const Duration(minutes: 5)),
      ),
      isTrue,
    );
    expect(
      isAgendaEventWithinLiveWindow(event, startsAt),
      isTrue,
    );
    expect(
      isAgendaEventWithinLiveWindow(
        event,
        startsAt.add(const Duration(hours: 3)),
      ),
      isFalse,
    );
  });

  test('guarda canales independientes publicados debajo de la agenda', () async {
    final service = AgendaLiveService();
    await service.captureAgendaChannels(<Map<String, Object?>>[
      <String, Object?>{
        'name': 'ESPN',
        'url': 'https://channels.example/espn',
        'order': 0,
      },
      <String, Object?>{
        'name': 'ESPN 2',
        'url': 'https://channels.example/espn2',
        'order': 1,
      },
    ]);

    final channels = await service.loadCapturedChannels();
    expect(channels.map((channel) => channel.name), <String>['ESPN', 'ESPN 2']);
    expect(
      channels.map((channel) => channel.url),
      <String>[
        'https://channels.example/espn',
        'https://channels.example/espn2',
      ],
    );
  });

  test('prepara una transmisión dentro de los cinco minutos previos', () async {
    final service = AgendaLiveService();
    final now = DateTime.now();
    await service.captureAgendaEvents(<dynamic>[
      _event(
        startsAt: now.add(const Duration(minutes: 4)),
        options: <Map<String, Object?>>[
          _option(name: 'Canal principal', url: 'https://player.example/event'),
        ],
      ),
    ]);
    expect(
      (await service.buildBoardState(
        now: now.subtract(const Duration(minutes: 2)),
      )).assignments,
      isEmpty,
    );

    final insideWindow = await service.buildBoardState(now: now);
    expect(insideWindow.assignments, hasLength(1));
    expect(insideWindow.assignments.single.option.name, 'Canal principal');
  });

  test('selecciona la opción con mayor popularidad pública', () async {
    final service = AgendaLiveService();
    final now = DateTime.now();
    await service.captureAgendaEvents(<dynamic>[
      _event(
        startsAt: now.subtract(const Duration(minutes: 1)),
        options: <Map<String, Object?>>[
          _option(name: 'Primera opción', url: 'https://player.example/first'),
          _option(
            name: 'Más popular',
            url: 'https://player.example/popular',
            order: 1,
            popularityScore: 14500,
          ),
        ],
      ),
    ]);
    final state = await service.buildBoardState(now: now);
    expect(state.assignments.single.option.name, 'Más popular');
    expect(state.assignments.single.option.popularityScore, 14500);
  });

  test('cuando no hay métricas conserva el orden publicado', () {
    final ranked = rankAgendaTransmissionOptions(<AgendaTransmissionOption>[
      const AgendaTransmissionOption(
        id: 'second', name: 'Segunda',
        url: 'https://player.example/second', order: 1,
      ),
      const AgendaTransmissionOption(
        id: 'first', name: 'Primera',
        url: 'https://player.example/first', order: 0,
      ),
    ]);
    expect(ranked.first.name, 'Primera');
  });

  test('solo acepta enlaces HTTPS sin credenciales', () {
    expect(isSafeAgendaTransmissionUrl('https://player.example/event'), isTrue);
    expect(isSafeAgendaTransmissionUrl('http://player.example/event'), isFalse);
    expect(isSafeAgendaTransmissionUrl('javascript:alert(1)'), isFalse);
    expect(isSafeAgendaTransmissionUrl('https://user:pass@player.example/event'), isFalse);
  });

  test('no usa listas IPTV como respaldo si no hay opciones web', () async {
    final service = AgendaLiveService();
    final now = DateTime.now();
    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: now.subtract(const Duration(minutes: 1))),
    ]);
    final state = await service.buildBoardState(now: now);
    expect(state.assignments, isEmpty);
    expect(state.pending.single.status, 'FALTAN OPCIONES DE TRANSMISIÓN');
  });

  test('no asigna la misma página a dos eventos simultáneos', () async {
    final service = AgendaLiveService();
    final now = DateTime.now();
    final sameOption = <Map<String, Object?>>[
      _option(name: 'Señal única', url: 'https://player.example/shared'),
    ];
    await service.captureAgendaEvents(<dynamic>[
      _event(id: 'match-1',
        startsAt: now.subtract(const Duration(minutes: 1)),
        options: sameOption),
      _event(id: 'match-2', title: 'Equipo Verde vs Equipo Blanco',
        startsAt: now.subtract(const Duration(minutes: 1)),
        options: sameOption),
    ]);
    final state = await service.buildBoardState(now: now);
    expect(state.assignments, hasLength(1));
    expect(state.assignments.single.event.id, 'match-1');
    expect(state.pending, hasLength(1));
  });

  test('conserva opciones ya capturadas si una actualización no las incluye', () async {
    final service = AgendaLiveService();
    final startsAt = DateTime.now().add(const Duration(minutes: 30));
    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: startsAt, options: <Map<String, Object?>>[
        _option(name: 'Canal oficial', url: 'https://player.example/one'),
      ]),
    ]);
    await service.captureAgendaEvents(<dynamic>[_event(startsAt: startsAt)]);
    final events = await service.loadCapturedEvents();
    expect(events, hasLength(1));
    expect(events.single.transmissionOptions.single.name, 'Canal oficial');
  });

  test('asigna una transmisión a más de ocho eventos activos sin limitar el tablero', () async {
    final service = AgendaLiveService();
    final now = DateTime.now();
    final events = List<Map<String, Object?>>.generate(10, (index) {
      return _event(
        id: 'active-match-$index',
        title: 'Equipo $index vs Rival $index',
        startsAt: now.subtract(const Duration(minutes: 1)),
        options: <Map<String, Object?>>[
          _option(
            name: 'Transmisión $index',
            url: 'https://player.example/live-$index',
            order: index,
          ),
        ],
      );
    });

    await service.captureAgendaEvents(events);
    final state = await service.buildBoardState(now: now);

    expect(state.assignments, hasLength(10));
    expect(state.pending, isEmpty);
    expect(
      state.assignments.map((assignment) => assignment.event.id).toSet(),
      hasLength(10),
    );
  });

  test('retira el evento cuando la agenda lo marca finalizado', () async {
    final service = AgendaLiveService();
    final now = DateTime.now();
    final startsAt = now.subtract(const Duration(hours: 1));
    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: startsAt, options: <Map<String, Object?>>[
        _option(name: 'Transmisión', url: 'https://player.example/live'),
      ]),
    ]);
    expect((await service.buildBoardState(now: now)).assignments, hasLength(1));
    await service.captureAgendaEvents(<dynamic>[
      _event(startsAt: startsAt, status: 'finished'),
    ]);
    expect((await service.buildBoardState(now: now)).assignments, isEmpty);
    expect(await service.loadCapturedEvents(), isEmpty);
  });

  test('libera el reproductor al llegar la hora de fin del evento', () async {
    final service = AgendaLiveService();
    final now = DateTime.now();
    await service.captureAgendaEvents(<dynamic>[
      _event(
        id: 'old-match',
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.subtract(const Duration(minutes: 1)),
        options: <Map<String, Object?>>[
          _option(name: 'Antigua', url: 'https://player.example/old'),
        ],
      ),
      _event(
        id: 'next-match',
        title: 'Equipo Verde vs Equipo Blanco',
        startsAt: now.subtract(const Duration(minutes: 1)),
        options: <Map<String, Object?>>[
          _option(name: 'Siguiente', url: 'https://player.example/next'),
        ],
      ),
    ]);
    final state = await service.buildBoardState(now: now);
    expect(state.assignments, hasLength(1));
    expect(state.assignments.single.event.id, 'next-match');
  });

  test('solo conserva eventos cuya fecha local coincide con hoy', () async {
    final service = AgendaLiveService();
    final now = DateTime(2026, 11, 18, 12);
    await service.captureAgendaEvents(<dynamic>[
      _event(
        id: 'today',
        startsAt: now.add(const Duration(hours: 1)),
        options: <Map<String, Object?>>[
          _option(name: 'Canal de hoy', url: 'https://player.example/today'),
        ],
      ),
      _event(
        id: 'yesterday',
        startsAt: now.subtract(const Duration(days: 1)),
        options: <Map<String, Object?>>[
          _option(name: 'Canal anterior', url: 'https://player.example/yesterday'),
        ],
      ),
      _event(
        id: 'tomorrow',
        startsAt: now.add(const Duration(days: 1)),
        options: <Map<String, Object?>>[
          _option(name: 'Canal futuro', url: 'https://player.example/tomorrow'),
        ],
      ),
    ], now: now);

    final events = await service.loadCapturedEvents();
    expect(events.map((event) => event.id), <String>['today']);
  });

  test('Canales deportivos reúne las fuentes de los eventos de hoy y excluye la Agenda', () async {
    final service = AgendaLiveService();
    final now = DateTime(2026, 11, 18, 12);
    await service.captureAgendaEvents(<dynamic>[
      _event(
        id: 'match-today',
        title: 'Equipo Azul vs Equipo Rojo',
        startsAt: now.add(const Duration(minutes: 20)),
        options: <Map<String, Object?>>[
          _option(
            name: 'Agenda',
            url: 'https://futbol-libre.cam/',
            order: 0,
          ),
          _option(
            name: 'ESPN 2 · Español',
            url: 'https://channels.example/espn2',
            order: 1,
          ),
        ],
      ),
    ]);
    await service.captureAgendaChannels(<Map<String, Object?>>[
      <String, Object?>{
        'name': 'Agenda deportiva',
        'url': 'https://futbol-libre.cam/',
        'order': 0,
      },
      <String, Object?>{
        'name': 'ESPN 2',
        'url': 'https://channels.example/espn2',
        'order': 1,
      },
      <String, Object?>{
        'name': 'Fox Deportes',
        'url': 'https://channels.example/fox',
        'order': 2,
      },
    ], now: now);

    final entries = await service.loadChannelsForCurrentDay(now: now);

    expect(entries, hasLength(2));
    expect(entries.first.option.name, 'ESPN 2 · Español');
    expect(entries.first.eventId, 'match-today');
    expect(entries.first.eventTitle, 'Equipo Azul vs Equipo Rojo');
    expect(entries.last.option.name, 'Fox Deportes');
    expect(
      isAgendaLandingPageReference('Canal de agenda', 'https://example.org/live'),
      isTrue,
    );
  });

  test('retira de Canales deportivos la opción cuando termina su evento', () async {
    final service = AgendaLiveService();
    final now = DateTime(2026, 11, 18, 18);
    await service.captureAgendaEvents(<dynamic>[
      _event(
        id: 'finished-match',
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.subtract(const Duration(minutes: 1)),
        options: <Map<String, Object?>>[
          _option(name: 'Transmisión terminada', url: 'https://player.example/ended'),
        ],
      ),
    ], now: now);

    expect(
      await service.loadChannelsForCurrentDay(now: now),
      isEmpty,
    );
    expect(
      (await service.buildBoardState(now: now)).assignments,
      isEmpty,
    );
  });

}
