## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Allow missing Play Store classes for deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Workmanager
-keep class dev.fluttercommunity.plus.workmanager.** { *; }
-keep class androidx.work.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# Keep callback dispatcher and entry point
-keep class io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin
-keep class * extends io.flutter.app.FlutterApplication
-keep class * extends io.flutter.embedding.android.FlutterActivity
-keep class * extends io.flutter.embedding.android.FlutterFragmentActivity
-keep class * extends io.flutter.embedding.android.FlutterService
-keep class * extends io.flutter.embedding.android.FlutterBroadcastReceiver

# Keep models and service classes to prevent obfuscation issues in background tasks
-keep class com.himal.mechminder.service.** { *; }
-keep class com.himal.mechminder.models.** { *; }
