// Gestisce notifiche locali e push Firebase: inizializzazione, schedulazione pasti e permessi.
// scheduleDietNotifications — schedula notifiche settimanali per ogni pasto/giorno del piano dieta.
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diet_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin =>
      _localNotifications;

  bool _isInitialized = false;
  static const String _iconName = '@mipmap/launcher_icon';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings(_iconName);

      final DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint("🔔 Notifica locale cliccata: ${details.payload}");
        },
      );

      _messageSubscription?.cancel();
      _messageSubscription =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
            "📩 Push Notification Ricevuta: ${message.notification?.title}");
        _showLocalNotification(message);
      });

      _isInitialized = true;
      debugPrint("✅ Notification Service Initialized (Local + Remote)");
    } catch (e) {
      debugPrint("⚠️ Notification Init Error: $e");
    }
  }

  Future<void> requestPermissions() async {
    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (Platform.isAndroid) {
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
        await androidPlugin?.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint("Permission Error: $e");
    }
  }

  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      debugPrint("FCM Token Error: $e");
      return null;
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'kybo_push_channel',
            'Avvisi Manutenzione',
            channelDescription: 'Notifiche importanti dal server',
            importance: Importance.max,
            priority: Priority.high,
            icon: _iconName,
            color: Color(0xFF4CAF50),
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  Future<void> scheduleDietNotifications(
      Map<String, Map<String, List<Dish>>> plan,
      {List<String>? days}) async {
    if (!_isInitialized) await init();

    await cancelAllNotifications();

    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString('meal_alarms');
    Map<String, TimeOfDay> alarmSettings = {};

    if (alarmsJson != null) {
      try {
        final decoded = jsonDecode(alarmsJson) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          final parts = val.toString().split(':');
          alarmSettings[key] = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        });
      } catch (e) {
        debugPrint("⚠️ Errore parsing orari: $e");
      }
    }

    if (alarmSettings.isEmpty) return;

    int notificationId = 0;
    final now = DateTime.now();

    final effectiveDays = days ?? (plan.isNotEmpty ? plan.keys.toList() : []);

    final daysMap = {
      for (int i = 0; i < effectiveDays.length; i++) effectiveDays[i]: i + 1
    };

    for (var entry in plan.entries) {
      String dayName = entry.key;
      var mealsMap = entry.value;

      int? targetWeekday = daysMap[dayName];
      if (targetWeekday == null) continue;

      DateTime scheduledDate = _nextWeekday(targetWeekday, now);

      for (var mealEntry in mealsMap.entries) {
        String mealType = mealEntry.key;
        List<Dish> dishes = mealEntry.value;

        if (!alarmSettings.containsKey(mealType)) continue;

        String body = dishes.map((d) => d.name).take(2).join(", ");
        if (dishes.length > 2) body += " e altri...";
        if (body.isEmpty) body = "Controlla il tuo piano alimentare";

        final time = alarmSettings[mealType]!;

        DateTime finalTime = tz.TZDateTime(
          tz.local,
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          time.hour,
          time.minute,
        );

        if (finalTime.isBefore(now)) {
          finalTime = finalTime.add(const Duration(days: 7));
        }

        await _scheduleSingleNotification(
          notificationId++,
          "È ora di $mealType!",
          "In menu: $body",
          finalTime,
        );
      }
    }
    debugPrint("🔔 Schedulate $notificationId notifiche pasti.");
  }

  DateTime _nextWeekday(int targetWeekday, DateTime from) {
    int diff = targetWeekday - from.weekday;
    if (diff < 0) diff += 7;
    return from.add(Duration(days: diff));
  }

  Future<void> _scheduleSingleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
  ) async {
    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'kybo_meals_channel_v4',
            'Promemoria Pasti',
            channelDescription: 'Notifiche per i pasti della dieta',
            importance: Importance.high,
            priority: Priority.high,
            icon: _iconName,
            color: Color(0xFF4CAF50),
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint("❌ Errore schedulazione ID $id: $e");
    }
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  void dispose() {
    _messageSubscription?.cancel();
    debugPrint("🧹 NotificationService disposed");
  }
}
