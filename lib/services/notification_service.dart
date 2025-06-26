// lib/services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  /// Permet d'accéder au plugin pour
  /// NotificationService.plugin.getNotificationAppLaunchDetails()
  static FlutterLocalNotificationsPlugin get plugin => _plugin;
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// 1️⃣ Initialisation : fuseaux + canaux + callback
  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) {
        debugPrint('🔔 Notification tapée – payload=${resp.payload}');
        // Si vous utilisez navigatorKey :
        // navigatorKey.currentState?.pushNamed('/vocab', arguments: resp.payload);
      },
    );

    debugPrint('▶ NotificationService initialized');
  }

  /// 2️⃣ Notification de test immédiate
  static Future<void> showTestNotification() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Test Channel',
        channelDescription: 'Channel pour notifications de test',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      0,
      '🔔 Notification de test',
      'Ceci est une notification envoyée immédiatement.',
      details,
      payload: 'test_payload',
    );
  }

  /// 3️⃣ Planifier une notification **exacte** dans 1 minute
  static Future<void> scheduleInOneMinute() async {
    final now = tz.TZDateTime.now(tz.local);
    final inOneMin = now.add(const Duration(minutes: 1));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Test Channel',
        channelDescription: 'Channel pour notifications de test',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      1,
      '⏱️ Dans une minute',
      'Cette notification arrivera dans 1 minute.',
      inOneMin,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // pas de dateInterpretation ni uiLocalNotification… sur v19+
      payload: 'one_minute_payload',
    );
  }

  /// 4️⃣ Planifier le rappel quotidien
  static Future<void> scheduleDailyReminder(TimeOfDay t) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Daily study reminder',
        channelDescription: 'Vos rappels journaliers pour apprendre',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      100,
      'C’est l’heure d’apprendre !',
      'Ouvre VocabElevate et continue ton apprentissage.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_reminder',
    );
  }

  /// 5️⃣ Annuler le rappel quotidien
  static Future<void> cancelReminder() async {
    await _plugin.cancel(100);
  }
}
