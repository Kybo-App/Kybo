import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> init() async {
    await AwesomeNotifications().initialize(
      // [IMPORTANT] Ensure 'icon' exists in android/app/src/main/res/drawable
      // If using flutter_launcher_icons, you might need 'resource://mipmap/launcher_icon'
      'resource://drawable/icon',
      [
        NotificationChannel(
          channelGroupKey: 'meal_group',
          channelKey: 'meal_channel',
          channelName: 'Pasti e Promemoria',
          channelDescription: 'Notifiche per i pasti',
          defaultColor: const Color(0xFF2E7D32),
          ledColor: Colors.white,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          criticalAlerts: true,
          playSound: true,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'meal_group',
          channelGroupName: 'Diet Notifications',
        ),
      ],
      debug: true,
    );
  }

  /// Call this on the Notification Screen to force the permission dialog
  Future<void> checkPermissions(BuildContext context) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future<void> showInstantNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999,
        channelKey: 'meal_channel',
        title: 'Test Notifica',
        body: 'Se leggi questo, Awesome Notifications funziona!',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    // Automatically gets the device timezone
    String localTimeZone = await AwesomeNotifications()
        .getLocalTimeZoneIdentifier();

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'meal_channel',
        title: title,
        body: body,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        fullScreenIntent: true,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: time.hour,
        minute: time.minute,
        second: 0,
        millisecond: 0,
        timeZone: localTimeZone,
        repeats: true, // Daily repetition
        preciseAlarm: true, // Handles Exact Alarm permission automatically
        allowWhileIdle: true,
      ),
    );

    debugPrint(
      "✅ Scheduled ID:$id at ${time.hour}:${time.minute} ($localTimeZone)",
    );
  }

  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  Future<void> cancelAll() async {
    await AwesomeNotifications().cancelAll();
  }
}
