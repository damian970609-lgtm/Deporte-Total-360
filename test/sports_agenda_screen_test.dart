import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/automatic_live_service.dart';
import 'package:deporte_total_360/sports_agenda_screen.dart';

void main() {
  testWidgets('muestra los eventos que publica la agenda sincronizada', (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: SportsAgendaScreen(
          isActive: false,
          onOpenLive: (_) {},
          loadEvents: () async => <SportsAgendaEvent>[
            SportsAgendaEvent(
              id: 'sportsapi-test-1',
              title: 'Equipo A vs Equipo B',
              sport: 'Fútbol',
              competition: 'Liga de prueba',
              homeTeam: 'Equipo A',
              awayTeam: 'Equipo B',
              homeTeamLogo: 'https://img.example/equipo-a.png',
              awayTeamLogo: 'https://img.example/equipo-b.png',
              startsAt: start,
              detailUrl: 'https://sportsapi.app/',
            ),
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('AGENDA DEPORTIVA'), findsOneWidget);
    expect(find.text('Equipo A'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('Equipo B'), findsOneWidget);
    expect(find.text('Liga de prueba'), findsOneWidget);
    expect(find.text('VER TRANSMISIONES'), findsOneWidget);
  });


  testWidgets('muestra participantes y disciplina en eventos individuales', (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 14);
    await tester.pumpWidget(
      MaterialApp(
        home: SportsAgendaScreen(
          isActive: false,
          onOpenLive: (_) {},
          loadEvents: () async => <SportsAgendaEvent>[
            SportsAgendaEvent(
              id: 'tennis-final-1',
              title: 'Final individual masculina',
              sport: 'Tenis',
              competition: 'Torneo de prueba',
              participants: const <SportsAgendaParticipant>[
                SportsAgendaParticipant(
                  name: 'Carlos Alcaraz',
                  imageUrl: 'https://img.example/alcaraz.png',
                  country: 'España',
                ),
                SportsAgendaParticipant(
                  name: 'Jannik Sinner',
                  imageUrl: 'https://img.example/sinner.png',
                  country: 'Italia',
                ),
              ],
              startsAt: start,
              detailUrl: 'https://sportsapi.app/',
            ),
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('TENIS'), findsOneWidget);
    expect(find.text('Final individual masculina'), findsOneWidget);
    expect(find.text('Carlos Alcaraz'), findsOneWidget);
    expect(find.text('Jannik Sinner'), findsOneWidget);
    expect(find.text('ESPAÑA'), findsOneWidget);
    expect(find.text('ITALIA'), findsOneWidget);
  });


  testWidgets('muestra solo la fecha seleccionada y permite desplazarse por una agenda extensa', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mixedEvents = <SportsAgendaEvent>[
      for (var index = 0; index < 40; index++)
        SportsAgendaEvent(
          id: 'today-$index',
          title: 'Evento de hoy $index',
          sport: 'Fútbol',
          startsAt: today.add(Duration(minutes: index * 10)),
          detailUrl: 'https://sportsapi.app/',
        ),
      for (var index = 0; index < 63; index++)
        SportsAgendaEvent(
          id: 'other-day-$index',
          title: 'Evento de otra jornada $index',
          sport: 'Tenis',
          startsAt: today.add(Duration(days: index.isEven ? 1 : -1, minutes: index)),
          detailUrl: 'https://sportsapi.app/',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SportsAgendaScreen(
          isActive: false,
          onOpenLive: (_) {},
          loadEvents: () async => mixedEvents,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('40 eventos · HOY'), findsOneWidget);
    expect(find.text('Evento de hoy 0'), findsOneWidget);
    expect(find.text('Evento de otra jornada 0'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Evento de hoy 39'),
      500,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey<String>('agenda-event-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();

    expect(find.text('Evento de hoy 39'), findsOneWidget);
    expect(find.text('Evento de otra jornada 62'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite cambiar de fecha y abrir la transmisión del evento seleccionado', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String? openedEventId;

    await tester.pumpWidget(
      MaterialApp(
        home: SportsAgendaScreen(
          isActive: false,
          initialDate: today,
          onOpenLive: (eventId) => openedEventId = eventId,
          loadEvents: () async => <SportsAgendaEvent>[
            SportsAgendaEvent(
              id: 'event-today',
              title: 'Team A vs Team B',
              sport: 'Fútbol',
              homeTeam: 'Team A',
              awayTeam: 'Team B',
              startsAt: today.add(const Duration(hours: 2)),
              detailUrl: 'https://sportsapi.app/',
            ),
            SportsAgendaEvent(
              id: 'event-tomorrow',
              title: 'Team C vs Team D',
              sport: 'Baloncesto',
              homeTeam: 'Team C',
              awayTeam: 'Team D',
              startsAt: today.add(const Duration(days: 1, hours: 3)),
              detailUrl: 'https://sportsapi.app/',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Team A'), findsOneWidget);
    expect(find.text('Team C'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('agenda-day-1')));
    await tester.pump();

    expect(find.text('Team A'), findsNothing);
    expect(find.text('Team C'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('agenda-live-event-event-tomorrow')),
    );
    expect(openedEventId, 'event-tomorrow');
  });

  testWidgets('muestra un estado vacío cuando SportAPI no publica eventos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SportsAgendaScreen(
          isActive: false,
          onOpenLive: (_) {},
          loadEvents: () async => <SportsAgendaEvent>[],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('NO HAY EVENTOS PARA ESTA FECHA'), findsOneWidget);
    expect(find.text('ABRIR AGENDA WEB'), findsOneWidget);
  });
}
