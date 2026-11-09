import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_i18n.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _pushInitialized = false;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static final ValueNotifier<String?> liveEventNotification =
      ValueNotifier<String?>(null);
  static final ValueNotifier<bool> matchRemindersEnabled =
      ValueNotifier<bool>(false);

  static const String _liveTopic = 'deporte_total_360_live';
  static const String _firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');
  static const String _firebaseAppId =
      String.fromEnvironment('FIREBASE_APP_ID');
  static const String _firebaseSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get _firebaseConfigured =>
      _firebaseApiKey.isNotEmpty &&
      _firebaseAppId.isNotEmpty &&
      _firebaseSenderId.isNotEmpty &&
      _firebaseProjectId.isNotEmpty;
  static const int _matchNotificationFloor = 1000000000;

  /// Inicializa Crashlytics sin bloquear el primer render de la app.
  /// Si faltan las credenciales Firebase, la aplicación sigue funcionando
  /// y continúa usando el registro local de errores.
  static Future<void> initializeCrashlytics() async {
    if (!_firebaseConfigured) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: _firebaseApiKey,
            appId: _firebaseAppId,
            messagingSenderId: _firebaseSenderId,
            projectId: _firebaseProjectId,
          ),
        );
      }
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(recordFlutterFatalError(details));
      };
    } catch (error, stackTrace) {
      debugPrint('Crashlytics no pudo inicializarse: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> recordFlutterFatalError(
    FlutterErrorDetails details,
  ) async {
    if (!_firebaseConfigured || Firebase.apps.isEmpty) return;
    try {
      await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (error) {
      debugPrint('No se pudo registrar el error Flutter: $error');
    }
  }

  static Future<void> recordFatalError(
    Object error,
    StackTrace stackTrace,
  ) async {
    if (!_firebaseConfigured || Firebase.apps.isEmpty) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: true,
      );
    } catch (reportError) {
      debugPrint('No se pudo registrar el error fatal: $reportError');
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
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
    _initialized = true;
    final androidNotifications = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        'sports_live_events',
        'Transmisiones deportivas',
        description: 'Avisos de transmisiones deportivas disponibles.',
        importance: Importance.max,
      ),
    );
    await _initializeFirebasePush();
  }

  static Future<bool> requestPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final localGranted =
        await android?.requestNotificationsPermission() ?? false;
    if (!_firebaseConfigured || Firebase.apps.isEmpty) return localGranted;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final pushGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    return localGranted && pushGranted;
  }


  static Future<void> _initializeFirebasePush() async {
    if (_pushInitialized || !_firebaseConfigured) return;
    try {
      final options = FirebaseOptions(
        apiKey: _firebaseApiKey,
        appId: _firebaseAppId,
        messagingSenderId: _firebaseSenderId,
        projectId: _firebaseProjectId,
      );
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      FirebaseMessaging.onBackgroundMessage(
        deporteTotalFirebaseMessagingBackgroundHandler,
      );
      final messaging = FirebaseMessaging.instance;
      _foregroundSubscription ??=
          FirebaseMessaging.onMessage.listen(_showRemoteNotification);
      _openedSubscription ??=
          FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteOpen);
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleRemoteOpen(initialMessage);
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notifications_enabled') ?? false) {
        await messaging.subscribeToTopic(_liveTopic);
      }
      _pushInitialized = true;
    } catch (_) {
      // Sin los datos Firebase del proyecto, las notificaciones locales
      // existentes siguen funcionando y la app no se bloquea.
    }
  }

  static Future<void> registerCurrentDevice() async {
    if (!_firebaseConfigured || Firebase.apps.isEmpty) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(_liveTopic);
    } catch (_) {}
  }

  static Future<void> unregisterCurrentDevice() async {
    if (!_firebaseConfigured || Firebase.apps.isEmpty) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_liveTopic);
    } catch (_) {}
  }

  static void _handleRemoteOpen(RemoteMessage message) {
    final eventId = message.data['eventId']?.toString();
    if (eventId != null && eventId.isNotEmpty) {
      liveEventNotification.value = eventId;
    }
  }

  static void _handleLocalNotificationResponse(
    NotificationResponse response,
  ) {
    final eventId = response.payload;
    if (eventId != null && eventId.isNotEmpty) {
      liveEventNotification.value = eventId;
    }
  }

  static Future<void> _showRemoteNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? tr('title');
    final body = message.notification?.body ??
        appText(
          'Hay una transmisión deportiva disponible.',
          'A sports stream is available.',
          'Há uma transmissão esportiva disponível.',
          'Une diffusion sportive est disponible.',
        );
    await _plugin.show(
      id: _stableId('fcm:${message.data['eventId'] ?? message.messageId ?? body}'),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'sports_live_events',
          appText('Transmisiones deportivas', 'Sports streams',
              'Transmissões esportivas', 'Diffusions sportives'),
          channelDescription: appText(
            'Avisos de transmisiones deportivas disponibles.',
            'Alerts when sports streams become available.',
            'Avisos de transmissões esportivas disponíveis.',
            'Alertes de diffusions sportives disponibles.',
          ),
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.event,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['eventId']?.toString(),
    );
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

  @visibleForTesting
  static int matchReminderNotificationId({
    required String sport,
    required String eventId,
    required DateTime startsAt,
    required int minutesBefore,
  }) =>
      _stableId(
        sport + ':' + eventId + ':' + minutesBefore.toString() + ':' +
            startsAt.millisecondsSinceEpoch.toString(),
      );

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

    final id = matchReminderNotificationId(
      sport: sport,
      eventId: eventId,
      startsAt: startsAt,
      minutesBefore: minutesBefore,
    );
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
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? false;
    if (!enabled) {
      await cancelMatchReminders();
      return;
    }

    final ordered = List<Map<String, Object>>.from(events)
      ..sort((a, b) {
        final left = a['startsAt'] as DateTime;
        final right = b['startsAt'] as DateTime;
        return left.compareTo(right);
      });
    final selected = ordered.take(40).toList(growable: false);
    final now = DateTime.now();
    final desiredIds = <int>{};
    for (final event in selected) {
      final start = (event['startsAt'] as DateTime).toLocal();
      for (final minutesBefore in <int>[60, 30, 15, 5]) {
        if (start.subtract(Duration(minutes: minutesBefore)).isAfter(now)) {
          desiredIds.add(matchReminderNotificationId(
            sport: event['sport'].toString(),
            eventId: event['id'].toString(),
            startsAt: start,
            minutesBefore: minutesBefore,
          ));
        }
      }
    }

    final pending = await _plugin.pendingNotificationRequests();
    final pendingIds = pending.map((item) => item.id).toSet();
    for (final request in pending) {
      if (request.id >= _matchNotificationFloor &&
          !desiredIds.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }

    for (final event in selected) {
      final start = (event['startsAt'] as DateTime).toLocal();
      for (final minutesBefore in <int>[60, 30, 15, 5]) {
        final reminderAt = start.subtract(Duration(minutes: minutesBefore));
        final id = matchReminderNotificationId(
          sport: event['sport'].toString(),
          eventId: event['id'].toString(),
          startsAt: start,
          minutesBefore: minutesBefore,
        );
        if (!reminderAt.isAfter(now) || pendingIds.contains(id)) continue;
        await scheduleMatchReminder(
          eventId: event['id'] as String,
          sport: event['sport'] as String,
          homeTeam: event['homeTeam'] as String,
          awayTeam: event['awayTeam'] as String,
          startsAt: start,
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


/// Firebase invoca este punto de entrada en el isolate de segundo plano.
/// Los mensajes llevan un bloque notification para que Android los presente.
@pragma('vm:entry-point')
Future<void> deporteTotalFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // No se inicia reproducción desde segundo plano: Android exige interacción.
}
