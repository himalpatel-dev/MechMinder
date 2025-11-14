import 'package:flutter/material.dart';
import '../screens/home_screen.dart'; // Import your main home screen

// --- ADD ALL THE IMPORTS FROM MAIN.DART ---
import '../service/database_helper.dart';
import '../service/notification_service.dart';
import 'package:workmanager/workmanager.dart';
// --- END IMPORTS ---

// --- THIS IS THE BACKGROUND TASK ---
// It MUST be at the top level of a file.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("--- Background Task Started ---");

    // We must initialize the database *again* in this
    // separate background environment.
    await DatabaseHelper.instance.database;
    await NotificationService().initialize();

    final String today = DateTime.now().toIso8601String().split('T')[0];
    print("Checking for reminders due on: $today");

    final reminders = await DatabaseHelper.instance.queryRemindersDueOn(today);
    print("Found ${reminders.length} reminders due today.");

    for (final reminder in reminders) {
      final String appName = inputData?['appName'] ?? 'MechMinder';
      final serviceName = reminder['template_name'] ?? 'Service';
      final body = 'Your "$serviceName" service is due today!';

      await NotificationService().showImmediateReminder(
        id: reminder[DatabaseHelper.columnId],
        title: appName,
        body: body,
      );
    }

    print("--- Background Task Complete ---");
    return Future.value(true);
  });
}
// --- END OF BACKGROUND TASK ---

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start all the loading as soon as the splash screen appears
    _initializeAndNavigate();
  }

  // --- THIS IS THE NEW LOADING FUNCTION ---
  void _initializeAndNavigate() async {
    // 1. Run your 3-second GIF timer
    Future<void> gifTimer = Future.delayed(const Duration(seconds: 3));

    // 2. Run all your app setup
    Future<void> appSetup = () async {
      try {
        print("[Splash] Initializing Database...");
        await DatabaseHelper.instance.database;
        print("[Splash] Database is initialized.");

        print("[Splash] Initializing Notifications...");
        await NotificationService().initialize();
        await NotificationService().requestPermissions();
        print("[Splash] Notifications initialized.");

        print("[Splash] Initializing Workmanager...");
        await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

        await Workmanager().registerPeriodicTask(
          "1",
          "checkVehicleReminders",
          frequency: const Duration(days: 1),
          initialDelay: const Duration(minutes: 15),
        );
        print("[Splash] Workmanager task registered.");
      } catch (e) {
        print("!!! ERROR DURING APP INIT: $e");
        // We can show an error here if we want
      }
    }(); // The '()' here runs the function

    // 3. Wait for BOTH the 3-second timer AND your setup to finish
    await Future.wait([gifTimer, appSetup]);

    // 4. Now, navigate
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(252, 255, 255, 255),
      body: Center(child: Image.asset('assets/images/splash.gif')),
    );
  }
}
