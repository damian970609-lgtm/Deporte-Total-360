import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:deporte_total_360/public_chat_screen.dart';

void main() {
  group('PublicChatMessage', () {
    test('lee mensajes públicos conservando emojis, fecha e identidad propia', () {
      final message = PublicChatMessage.fromJson(<String, dynamic>{
        'id': 'message-1',
        'name': 'Invitado',
        'text': '¡Vamos equipo! ⚽🔥',
        'createdAt': '2026-11-02T14:30:00Z',
        'isMine': true,
      });

      expect(message.id, 'message-1');
      expect(message.name, 'Invitado');
      expect(message.text, '¡Vamos equipo! ⚽🔥');
      expect(message.createdAt.toUtc(), DateTime.utc(2026, 11, 2, 14, 30));
      expect(message.isMine, isTrue);
      expect(message.deleted, isFalse);
    });

    test('aplica valores seguros cuando faltan campos del servidor', () {
      final message = PublicChatMessage.fromJson(<String, dynamic>{});

      expect(message.id, isEmpty);
      expect(message.name, 'Invitado');
      expect(message.text, isEmpty);
      expect(message.isMine, isFalse);
      expect(message.deleted, isFalse);
    });

    test('representa mensajes eliminados por moderación', () {
      final message = PublicChatMessage.fromJson(<String, dynamic>{
        'id': 'message-2',
        'name': 'Comprador',
        'text': 'Este mensaje fue eliminado por moderación.',
        'createdAt': '2026-11-02T14:30:00Z',
        'deleted': true,
      });

      expect(message.deleted, isTrue);
      expect(message.text, contains('eliminado por moderación'));
    });
  });

  test('limita alias y mensajes desde la interfaz', () {
    expect(PublicChatService.maxNameLength, 24);
    expect(PublicChatService.maxMessageLength, 500);
  });

  test('las lecturas del Chat envían el token de la cuenta autorizada', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, Object>{
          'canModerate': false,
          'messages': <Map<String, Object>>[
            <String, Object>{
              'id': 'message-1',
              'name': 'Comprador',
              'text': 'Hola comunidad',
              'createdAt': '2026-11-06T16:00:00Z',
              'isMine': true,
            },
          ],
        }),
        200,
      );
    });
    final service = PublicChatService(
      client: client,
      authHeadersProvider: () async => <String, String>{
        'Authorization': 'Bearer verified-google-id-token',
      },
    );

    final messages = await service.loadMessages();

    expect(captured?.method, 'GET');
    expect(captured?.headers['Authorization'], 'Bearer verified-google-id-token');
    expect(messages, hasLength(1));
    expect(messages.single.isMine, isTrue);
    expect(service.canModerate, isFalse);
    client.close();
  });

  test('el envío conserva la autenticación y devuelve el mensaje confirmado', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, Object>{
          'message': <String, Object>{
            'id': 'sent-1',
            'name': 'Comprador',
            'text': '¡Vamos!',
            'createdAt': '2026-11-06T16:00:00Z',
            'isMine': true,
          },
        }),
        201,
      );
    });
    final service = PublicChatService(
      client: client,
      authHeadersProvider: () async => <String, String>{
        'Authorization': 'Bearer verified-google-id-token',
      },
    );

    final sent = await service.sendMessage(name: 'Comprador', text: '¡Vamos!');

    expect(captured?.method, 'POST');
    expect(captured?.headers['Authorization'], 'Bearer verified-google-id-token');
    expect(captured?.headers['Content-Type'], 'application/json');
    expect(jsonDecode(captured!.body), <String, String>{
      'name': 'Comprador',
      'text': '¡Vamos!',
    });
    expect(sent.id, 'sent-1');
    client.close();
  });

  test('la acción de moderación usa DELETE autenticado', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{"deleted":true}', 200);
    });
    final service = PublicChatService(
      client: client,
      authHeadersProvider: () async => <String, String>{
        'Authorization': 'Bearer owner-google-id-token',
      },
    );

    await service.deleteMessage('message-123');

    expect(captured?.method, 'DELETE');
    expect(captured?.url.path, endsWith('/api/chat/messages/message-123'));
    expect(captured?.headers['Authorization'], 'Bearer owner-google-id-token');
    client.close();
  });

  test('recupera el alias estable de la cuenta desde el servidor', () async {
    final client = MockClient((request) async => http.Response(
      jsonEncode(<String, Object>{
        'canModerate': false,
        'profile': <String, String>{'name': 'AliasFijo'},
        'messages': <Object>[],
      }),
      200,
    ));
    final service = PublicChatService(
      client: client,
      authHeadersProvider: () async => <String, String>{
        'Authorization': 'Bearer verified-google-id-token',
      },
    );

    await service.loadMessages();

    expect(service.currentAlias, 'AliasFijo');
    client.close();
  });

  test('denuncia un mensaje ajeno con autenticación y motivo', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{"reported":true}', 201);
    });
    final service = PublicChatService(
      client: client,
      authHeadersProvider: () async => <String, String>{
        'Authorization': 'Bearer verified-google-id-token',
      },
    );

    await service.reportMessage('message-456', 'spam');

    expect(captured?.method, 'POST');
    expect(captured?.url.path, endsWith('/api/chat/messages/message-456/report'));
    expect(captured?.headers['Authorization'], 'Bearer verified-google-id-token');
    expect(jsonDecode(captured!.body), <String, String>{'reason': 'spam'});
    client.close();
  });

  test('consulta y resuelve denuncias con la cuenta administradora', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode(<String, Object>{
          'reports': <Map<String, Object>>[
            <String, Object>{
              'id': 'report-1',
              'messageId': 'message-1',
              'reporterName': 'Comprador',
              'reason': 'abuse',
              'status': 'pending',
              'createdAt': '2026-11-06T16:00:00Z',
              'messageName': 'Otro usuario',
              'messageText': 'Mensaje denunciado',
            },
          ],
        }), 200);
      }
      return http.Response('{"updated":true}', 200);
    });
    final service = PublicChatService(
      client: client,
      authHeadersProvider: () async => <String, String>{
        'Authorization': 'Bearer owner-google-id-token',
      },
    );

    final reports = await service.fetchReports();
    await service.updateReport('report-1', 'resolved');

    expect(reports, hasLength(1));
    expect(reports.single.messageText, 'Mensaje denunciado');
    expect(requests.first.url.path, endsWith('/api/chat/reports'));
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.path, endsWith('/api/chat/reports/report-1'));
    expect(jsonDecode(requests.last.body), <String, String>{'status': 'resolved'});
    client.close();
  });

  test('rechaza IDs no seguros antes de llamar al servidor', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });
    final service = PublicChatService(
      client: client,
      authHeadersProvider: () async => <String, String>{
        'Authorization': 'Bearer owner-google-id-token',
      },
    );

    await expectLater(
      service.deleteMessage('../another-user'),
      throwsException,
    );
    expect(called, isFalse);
    client.close();
  });
}
