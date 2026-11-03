import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/sports_summaries_screen.dart';

void main() {
  testWidgets('muestra la sección de resúmenes y categorías deportivas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SportsSummariesScreen()),
    );

    expect(find.text('RESÚMENES DEPORTIVOS'), findsOneWidget);
    expect(find.text('Fútbol'), findsOneWidget);
    expect(find.text('Baloncesto'), findsOneWidget);
    expect(find.text('Deportes de motor'), findsOneWidget);
    expect(find.text('Hockey sobre hielo'), findsOneWidget);
    expect(find.text('Ciclismo'), findsOneWidget);
    expect(find.text('Balonmano'), findsOneWidget);
  });
}
