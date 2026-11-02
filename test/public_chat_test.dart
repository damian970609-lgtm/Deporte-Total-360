import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/public_chat_screen.dart';

void main() {
  group('PublicChatMessage', () {
    test('lee los mensajes públicos conservando emojis y fecha', () {
      final message = PublicChatMessage.fromJson(<String, dynamic>{
        'id': 'message-1',
        'name': 'Invitado',
        'text': '¡Vamos equipo! ⚽🔥',
        'createdAt': '2026-11-02T14:30:00Z',
      });

      expect(message.id, 'message-1');
      expect(message.name, 'Invitado');
      expect(message.text, '¡Vamos equipo! ⚽🔥');
      expect(message.createdAt.toUtc(), DateTime.utc(2026, 11, 2, 14, 30));
    });

    test('aplica valores seguros cuando faltan campos del servidor', () {
      final message = PublicChatMessage.fromJson(<String, dynamic>{});

      expect(message.id, isEmpty);
      expect(message.name, 'Invitado');
      expect(message.text, isEmpty);
    });
  });

  test('limita alias y mensajes desde la interfaz', () {
    expect(PublicChatService.maxNameLength, 24);
    expect(PublicChatService.maxMessageLength, 500);
  });
}
