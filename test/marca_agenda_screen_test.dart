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

    expect(find.text('AGENDA DE HOY'), findsOneWidget);
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
