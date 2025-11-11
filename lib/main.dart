import 'package:flutter/material.dart';
import 'package:mechminder/screens/vehicle_list.dart';
// --- 1. IMPORT YOUR DATABASE HELPER ---
import 'package:mechminder/service/database_helper.dart';
import 'package:mechminder/service/notification_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:provider/provider.dart'; // The package we just added
import 'service/settings_provider.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("--- Background Task Started ---");

    // 1. Initialize services (required for background tasks)
    await DatabaseHelper.instance.database;
    await NotificationService().initialize();

    // 2. Get today's date
    final String today = DateTime.now().toIso8601String().split('T')[0];
    print("Checking for reminders due on: $today");

    // 3. Check the database for reminders
    final reminders = await DatabaseHelper.instance.queryRemindersDueOn(today);
    print("Found ${reminders.length} reminders due today.");

    // 4. Fire a notification for each reminder
    for (final reminder in reminders) {
      final title = 'Vehicle Service Due';
      final servicedue = reminder['template_name'] ?? 'Service Due';
      final body = 'Your "$servicedue" service is due today!';

      await NotificationService().showImmediateReminder(
        id: reminder[DatabaseHelper.columnId],
        title: title,
        body: body,
      );
    }

    print("--- Background Task Complete ---");
    return Future.value(true);
  });
}
// --- END OF BACKGROUND TASK ---

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper.instance.database;
  print("[Main] Database is initialized and ready.");

  // --- INITIALIZE NOTIFICATIONS AND WORKMANAGER ---
  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher, // The function to run in the background
    isInDebugMode: true, // Shows logs in the console
  );

  // Register the periodic task
  await Workmanager().registerPeriodicTask(
    "1", // A unique ID for this task
    "checkVehicleReminders", // The name of the task
    frequency: const Duration(days: 1), // How often to run
    initialDelay: const Duration(minutes: 15), // When to start the first check
  );

  // 6. Run the app
  runApp(
    // This "provides" your settings brain to all widgets below it
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

// --- THIS IS YOUR APP CLASS (UNCHANGED) ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MechMinder – Never Miss a Service Again',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const VehicleListScreen(),
    );
  }
}
