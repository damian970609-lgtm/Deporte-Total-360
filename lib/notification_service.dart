import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_i18n.dart';

class SportsAppNotification {
  const SportsAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.payload,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final String? payload;

  factory SportsAppNotification.fromJson(Map<String, dynamic> json) {
    return SportsAppNotification(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'sports').toString(),
      payload: json['payload']?.toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const int _matchNotificationFloor = 1000000000;
  static const String _historyKey = 'sports_notification_history';

  static Future<List<SportsAppNotification>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.trim().isEmpty) return <SportsAppNotification>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SportsAppNotification>[];
      final items = decoded
          .whereType<Map>()
          .map((item) => SportsAppNotification.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.id.isNotEmpty && item.body.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return <SportsAppNotification>[];
    }
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  static Future<void> _recordHistory({
    required String id,
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await loadHistory();
      final notification = SportsAppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        payload: payload,
        createdAt: DateTime.now(),
      );
      final updated = <SportsAppNotification>[
        notification,
        ...current.where((item) => item.id != id),
      ].take(100).map((item) => item.toJson()).toList(growable: false);
      await prefs.setString(_historyKey, jsonEncode(updated));
    } catch (_) {
      // El historial nunca debe impedir la notificación del sistema.
    }
  }

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
      final eventId = event['id'] as String;
      final sport = event['sport'] as String;
      final homeTeam = event['homeTeam'] as String;
      final awayTeam = event['awayTeam'] as String;
      final startsAt = event['startsAt'] as DateTime;
      await _recordHistory(
        id: 'reminder:$eventId',
        title: appText('Partido próximo', 'Upcoming match', 'Partida próxima', 'Match à venir'),
        body: '$sport: $homeTeam vs $awayTeam · $startsAt',
        type: 'reminder',
        payload: eventId,
      );
      for (final minutesBefore in <int>[60, 30, 15, 10, 5]) {
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

  static Future<void> showLiveScoreUpdate({
    required String eventId,
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required int? homeScore,
    required int? awayScore,
  }) async {
    if (homeScore == null && awayScore == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? false)) return;
    await initialize();
    final channelName = tr('notifications');
    await _plugin.show(
      id: _stableId('live-score:$eventId'),
      title: tr('title'),
      body: appText(
        'Marcador actualizado · $sport: $homeTeam $homeScore - $awayScore $awayTeam',
        'Score update · $sport: $homeTeam $homeScore - $awayScore $awayTeam',
        'Placar atualizado · $sport: $homeTeam $homeScore - $awayScore $awayTeam',
        'Score mis à jour · $sport : $homeTeam $homeScore - $awayScore $awayTeam',
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'sports_live_scores',
          channelName,
          channelDescription: appText(
            'Cambios de marcador de eventos en directo.',
            'Live event score updates.',
            'Atualizações de placar de eventos ao vivo.',
            'Mises à jour des scores des événements en direct.',
          ),
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.event,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: eventId,
    );
    await _recordHistory(
      id: 'score:$eventId:$homeScore-$awayScore',
      title: appText('Marcador actualizado', 'Score updated', 'Placar atualizado', 'Score mis à jour'),
      body: '$sport: $homeTeam $homeScore - $awayScore $awayTeam',
      type: 'score',
      payload: eventId,
    );
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
    await _recordHistory(
      id: 'test:${DateTime.now().millisecondsSinceEpoch}',
      title: tr('title'),
      body: appText(
        'Las notificaciones deportivas están activadas.',
        'Sports notifications are enabled.',
        'As notificações esportivas estão ativadas.',
        'Les notifications sportives sont activées.',
      ),
      type: 'test',
    );
  }
}
