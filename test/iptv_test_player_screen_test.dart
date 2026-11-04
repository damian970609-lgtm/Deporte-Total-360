import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/automatic_live_service.dart';
import 'package:deporte_total_360/iptv_test_player_screen.dart';

void main() {
  testWidgets('busca canales por nombre y permite limpiar el filtro', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const catalog = AutoLiveCatalog(
      channels: <M3uChannel>[
        M3uChannel(
          name: 'Canal Alfa Deportes',
          url: 'https://media.example/alfa.m3u8',
          group: 'Fútbol',
        ),
        M3uChannel(
          name: 'Canal Beta Deportes',
          url: 'https://media.example/beta.m3u8',
          group: 'Baloncesto',
        ),
      ],
      programmes: <XmltvProgramme>[],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: IptvTestPlayerScreen(initialCatalog: catalog),
      ),
    );
    await tester.pump();

    expect(find.text('Canal Alfa Deportes'), findsOneWidget);
    expect(find.text('Canal Beta Deportes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'canal beta');
    await tester.pump();

    expect(find.text('Canal Alfa Deportes'), findsNothing);
    expect(find.text('Canal Beta Deportes'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pump();

    expect(find.text('Canal Alfa Deportes'), findsOneWidget);
    expect(find.text('Canal Beta Deportes'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
