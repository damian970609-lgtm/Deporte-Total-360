import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/notification_service.dart';

void main() {
  test('el identificador de recordatorio es estable y cambia con el horario', () {
    final start = DateTime(2032, 5, 12, 18);
    int id(DateTime date, int minutes) =>
        NotificationService.matchReminderNotificationId(
          sport: 'Fútbol',
          eventId: 'fixture-123',
          startsAt: date,
          minutesBefore: minutes,
        );

    expect(id(start, 15), id(start, 15));
    expect(
      id(start, 15),
      isNot(id(start.add(const Duration(minutes: 1)), 15)),
    );
    expect(id(start, 15), isNot(id(start, 30)));
  });
}
