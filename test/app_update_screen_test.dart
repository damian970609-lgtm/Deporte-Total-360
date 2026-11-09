import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:deporte_total_360/app_update_screen.dart';

void main() {
  testWidgets('muestra la descarga cuando GitHub publica una versión superior',
      (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/repos/damian970609-lgtm/Deporte-Total-360/releases/latest');
      return http.Response(
        jsonEncode(<String, Object>{
          'tag_name': 'v1.0.6+200',
          'html_url': 'https://github.com/damian970609-lgtm/Deporte-Total-360/releases/tag/v1.0.6+200',
          'assets': <Object>[
            <String, String>{
              'name': 'Deporte-Total-360.apk',
              'browser_download_url': 'https://github.com/damian970609-lgtm/Deporte-Total-360/releases/download/v1.0.6%2B200/Deporte-Total-360.apk',
            },
          ],
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(home: AppUpdateScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('NUEVA VERSIÓN DISPONIBLE'), findsOneWidget);
    expect(find.text('Publicación: v1.0.6+200'), findsOneWidget);
    expect(find.text('DESCARGAR APK'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('maneja con normalidad que todavía no exista una publicación',
      (tester) async {
    final client = MockClient((_) async => http.Response('', 404));
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(home: AppUpdateScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ESTADO DE LA APLICACIÓN'), findsOneWidget);
    expect(find.text('COMPROBAR ACTUALIZACIONES'), findsOneWidget);
    expect(find.textContaining('Todavía no hay una publicación oficial'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('muestra un error recuperable si GitHub no responde',
      (tester) async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(home: AppUpdateScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMPROBACIÓN PENDIENTE'), findsOneWidget);
    expect(find.text('COMPROBAR ACTUALIZACIONES'), findsOneWidget);
    expect(find.textContaining('GitHub respondió con el código 503'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
