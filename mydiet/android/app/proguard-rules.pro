-keep class com.google.gson.** { *; }
-keep class androidx.window.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }

# Prevent R8 from stripping standard Flutter classes needed by plugins
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }