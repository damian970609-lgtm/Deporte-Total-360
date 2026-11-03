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
    expect(find.text('Equipo A vs Equipo B'), findsOneWidget);
    expect(find.text('Liga de prueba'), findsOneWidget);
    expect(find.text('VER TRANSMISIONES'), findsOneWidget);
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
