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

        // Se l'orario è dopo mezzanotte (es. 01:00 AM) ma fa parte della dieta del
        // "giorno" logico corrente, scheduliamo la notifica tecnicamente al giorno dopo.
        int targetDay = time.hour < 5 ? scheduledDate.day + 1 : scheduledDate.day;

        DateTime finalTime = tz.TZDateTime(
          tz.local,
          scheduledDate.year,
          scheduledDate.month,
          targetDay,
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

  // --- WORKOUT REMINDER ---
  // Notifiche locali ricorrenti per i giorni di allenamento. Usa ID
  // dedicati [9000-9006] (uno per giorno settimana) per non collidere
  // con quelle pasti (che partono da 0).
  // Le preferenze sono salvate in SharedPreferences:
  //   workout_reminder_enabled: bool
  //   workout_reminder_time: "HH:mm"
  //   workout_reminder_days: List<int> (1=Lun..7=Dom)
  static const int _workoutReminderIdBase = 9000;

  Future<void> cancelWorkoutReminders() async {
    for (int i = 0; i < 7; i++) {
      await _localNotifications.cancel(_workoutReminderIdBase + i);
    }
  }

  Future<Map<String, dynamic>> loadWorkoutReminderPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool('workout_reminder_enabled') ?? false,
      'time': prefs.getString('workout_reminder_time') ?? '18:00',
      'days': prefs.getStringList('workout_reminder_days') ??
          ['1', '3', '5'], // lun-mer-ven default
    };
  }

  /// Salva le preferenze del reminder workout e (ri)schedula le notifiche.
  /// Se [enabled]=false cancella tutte le notifiche workout.
  Future<void> saveWorkoutReminder({
    required bool enabled,
    required TimeOfDay time,
    required List<int> weekdays, // 1=Lun..7=Dom
  }) async {
    if (!_isInitialized) await init();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('workout_reminder_enabled', enabled);
    await prefs.setString(
      'workout_reminder_time',
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    );
    await prefs.setStringList(
      'workout_reminder_days',
      weekdays.map((d) => d.toString()).toList(),
    );

    await cancelWorkoutReminders();

    if (!enabled || weekdays.isEmpty) {
      debugPrint('🔕 Workout reminder disabilitato');
      return;
    }

    final now = DateTime.now();
    for (final wd in weekdays) {
      // Trova il prossimo occurrence per questo weekday a quell'ora
      DateTime target = _nextWeekday(wd, now);
      DateTime fire = DateTime(
          target.year, target.month, target.day, time.hour, time.minute);
      if (fire.isBefore(now)) fire = fire.add(const Duration(days: 7));

      try {
        await _localNotifications.zonedSchedule(
          _workoutReminderIdBase + (wd - 1),
          '💪 Ora di allenarti!',
          'Apri Kybo per iniziare la tua sessione.',
          tz.TZDateTime.from(fire, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'kybo_workout_channel_v1',
              'Promemoria Workout',
              channelDescription: 'Notifiche per i giorni di allenamento',
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
          // Ripetizione settimanale stesso giorno+ora
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint('❌ Errore schedule workout reminder $wd: $e');
      }
    }
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    debugPrint(
        '🔔 Schedulati ${weekdays.length} workout reminder alle $hh:$mm');
  }

  void dispose() {
    _messageSubscription?.cancel();
    debugPrint("🧹 NotificationService disposed");
  }
}
