import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/agenda_web_screen.dart';

void main() {
  test('formatea la fecha local de la Agenda en español', () {
    expect(
      formatAgendaDate(DateTime(2026, 11, 16)),
      'lunes, 16 de noviembre de 2026',
    );
  });

  testWidgets('el cartel muestra la identidad de la app y la fecha', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgendaBrandBanner(
            date: DateTime(2026, 11, 16),
            onRefresh: () {},
          ),
        ),
      ),
    );

    expect(find.text('DEPORTE TOTAL 360°'), findsOneWidget);
    expect(find.text('AGENDA DEPORTIVA DEL DÍA'), findsOneWidget);
    expect(find.text('lunes, 16 de noviembre de 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
