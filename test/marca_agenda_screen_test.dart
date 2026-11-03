import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/automatic_live_service.dart';
import 'package:deporte_total_360/marca_agenda_screen.dart';

void main() {
  testWidgets('muestra los eventos que publica la agenda sincronizada', (tester) async {
    final start = DateTime.now().add(const Duration(hours: 2));
    await tester.pumpWidget(
      MaterialApp(
        home: MarcaAgendaScreen(
          isActive: false,
          onOpenLive: () {},
          loadEvents: () async => <SportsAgendaEvent>[
            SportsAgendaEvent(
              id: 'marca-test-1',
              title: 'Equipo A vs Equipo B',
              sport: 'Fútbol',
              competition: 'Liga de prueba',
              homeTeam: 'Equipo A',
              awayTeam: 'Equipo B',
              homeTeamLogo: 'https://img.example/equipo-a.png',
              awayTeamLogo: 'https://img.example/equipo-b.png',
              startsAt: start,
              detailUrl: 'https://www.marca.com/programacion-tv.html',
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
    final start = DateTime.now().add(const Duration(hours: 2));
    await tester.pumpWidget(
      MaterialApp(
        home: MarcaAgendaScreen(
          isActive: false,
          onOpenLive: () {},
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
              detailUrl: 'https://www.marca.com/programacion-tv.html',
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


  testWidgets('solo muestra la jornada local de hoy y permite desplazarse por una agenda extensa', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mixedEvents = <SportsAgendaEvent>[
      for (var index = 0; index < 40; index++)
        SportsAgendaEvent(
          id: 'today-$index',
          title: 'Evento de hoy $index',
          sport: 'Fútbol',
          startsAt: today.add(Duration(minutes: index * 10)),
          detailUrl: 'https://www.marca.com/programacion-tv.html',
        ),
      for (var index = 0; index < 63; index++)
        SportsAgendaEvent(
          id: 'other-day-$index',
          title: 'Evento de otra jornada $index',
          sport: 'Tenis',
          startsAt: today.add(Duration(days: index.isEven ? 1 : -1, minutes: index)),
          detailUrl: 'https://www.marca.com/programacion-tv.html',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MarcaAgendaScreen(
          isActive: false,
          onOpenLive: () {},
          loadEvents: () async => mixedEvents,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('40 eventos en la agenda'), findsOneWidget);
    expect(find.text('Evento de hoy 0'), findsOneWidget);
    expect(find.text('Evento de otra jornada 0'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Evento de hoy 39'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    expect(find.text('Evento de hoy 39'), findsOneWidget);
    expect(find.text('Evento de otra jornada 62'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra un estado visible cuando el servidor aún no publica eventos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarcaAgendaScreen(
          isActive: false,
          onOpenLive: () {},
          loadEvents: () async => <SportsAgendaEvent>[],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('AÚN NO HAY EVENTOS PUBLICADOS'), findsOneWidget);
    expect(find.text('ABRIR MARCA'), findsOneWidget);
  });
}
