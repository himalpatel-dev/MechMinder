import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// --- THIS IS THE NEW CHANNEL WE WILL CREATE ---
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'vehicle_reminders', // id
  'Vehicle Reminders', // name
  description: 'Notifications for upcoming vehicle service', // description
  importance: Importance.max,
);
// --- END ---

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() {
    return _instance;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Setup Android Settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. Setup iOS Settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // 3. Initialize the Plugin
    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // --- THIS IS THE NEW, IMPORTANT PART ---
    // 4. Create the Android Notification Channel
    // This tells Android "this channel is important"
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    // --- END ---
  }

  // 5. Request Permissions (This is simpler now)
  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // 6. Handler for when a notification is tapped
  static void _onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      print('Notification payload: $payload');
    }
  }

  Future<void> showImmediateReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    // Use the same channel details as before
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channel.id, // Use the channel ID
          channel.name, // Use the channel name
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // --- Use .show() instead of .zonedSchedule() ---
    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: 'reminder_id_$id',
    );

    print("IMMEDIATE notification shown for ID: $id");
  }
}
