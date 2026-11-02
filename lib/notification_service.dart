import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_i18n.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const int _matchNotificationFloor = 1000000000;

  static Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // La app utiliza la hora local de Guyana como valor seguro por defecto.
    // Si el usuario cambia la zona horaria del teléfono, Android sigue aplicando
    // la zona horaria local al mostrar la alarma.
    try {
      tz.setLocalLocation(tz.getLocation('America/Guyana'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static int _stableId(String value) {
    // FNV-1a: conserva el mismo ID de notificación entre sesiones.
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return _matchNotificationFloor + (hash & 0x3fffffff);
  }

  static Future<void> scheduleMatchReminder({
    required String eventId,
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required DateTime startsAt,
    required int minutesBefore,
  }) async {
    await initialize();
    if (minutesBefore <= 0) return;
    final reminderAt = startsAt.toLocal().subtract(Duration(minutes: minutesBefore));
    if (!reminderAt.isAfter(DateTime.now())) return;

    final id = _stableId('$sport:$eventId:$minutesBefore');
    final channelName = tr('notifications');
    await _plugin.zonedSchedule(
      id: id,
      title: tr('title'),
      body: appText(
        '$sport: $homeTeam vs $awayTeam comienza en $minutesBefore minutos.',
        '$sport: $homeTeam vs $awayTeam starts in $minutesBefore minutes.',
        '$sport: $homeTeam vs $awayTeam começa em $minutesBefore minutos.',
        '$sport : $homeTeam vs $awayTeam commence dans $minutesBefore minutes.',
      ),
      scheduledDate: tz.TZDateTime.from(reminderAt, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'sports_match_reminders',
          channelName,
          channelDescription: 'Avisos previos al comienzo de eventos deportivos.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.event,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: eventId,
    );
  }

  static Future<void> scheduleMatchReminders({
    required List<Map<String, Object>> events,
  }) async {
    await initialize();
    await cancelMatchReminders();
    final ordered = List<Map<String, Object>>.from(events)
      ..sort((a, b) {
        final left = a['startsAt'] as DateTime;
        final right = b['startsAt'] as DateTime;
        return left.compareTo(right);
      });
    for (final event in ordered.take(40)) {
      for (final minutesBefore in <int>[60, 30, 15, 5]) {
        await scheduleMatchReminder(
          eventId: event['id'] as String,
          sport: event['sport'] as String,
          homeTeam: event['homeTeam'] as String,
          awayTeam: event['awayTeam'] as String,
          startsAt: event['startsAt'] as DateTime,
          minutesBefore: minutesBefore,
        );
      }
    }
  }

  static Future<void> cancelMatchReminders() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= _matchNotificationFloor) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  static Future<void> showTestNotification() async {
    await initialize();
    await _plugin.show(
      id: 360,
      title: tr('title'),
      body: appText(
        'Las notificaciones deportivas están activadas.',
        'Sports notifications are enabled.',
        'As notificações esportivas estão ativadas.',
        'Les notifications sportives sont activées.',
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sports_match_reminders',
          'Recordatorios deportivos',
          channelDescription: 'Avisos previos al comienzo de eventos deportivos.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
