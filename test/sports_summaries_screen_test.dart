import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/sports_summaries_screen.dart';

void main() {
  testWidgets('muestra las diez categorías deportivas favoritas en resúmenes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SportsSummariesScreen()),
    );

    expect(find.text('RESÚMENES DEPORTIVOS'), findsOneWidget);

    const sports = <String>[
      'Fútbol',
      'Baloncesto',
      'Béisbol',
      'Hockey sobre hielo',
      'Voleibol',
      'MMA',
      'Fútbol sala',
      'Ciclismo',
      'Deportes de motor',
      'Balonmano',
    ];

    final scrollable = find.byType(Scrollable).first;
    for (final sport in sports) {
      await tester.scrollUntilVisible(
        find.text(sport),
        220,
        scrollable: scrollable,
      );
      expect(find.text(sport), findsOneWidget, reason: 'Falta la categoría $sport');
    }
  });
}
