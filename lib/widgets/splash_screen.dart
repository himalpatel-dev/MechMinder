import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Import Lottie
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart'; // Import your main home screen

// --- ADD ALL THE IMPORTS FROM MAIN.DART ---
import '../service/database_helper.dart';
import '../service/notification_service.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.database;
    await NotificationService().initialize();

    final String today = DateTime.now().toIso8601String().split('T')[0];
    print("Checking for reminders and papers due on: $today");

    // --- 1. Check for Service Reminders ---
    final allReminders = await dbHelper.queryAllPendingRemindersWithVehicle();

    for (final reminder in allReminders) {
      final int reminderId = reminder[DatabaseHelper.columnId];
      bool isDue = false;

      // Check if date is due
      final String? dueDate = reminder[DatabaseHelper.columnDueDate];
      if (dueDate != null && dueDate.compareTo(today) == 0) {
        // Only on the exact day
        isDue = true;
      }

      // Check if odometer is due
      final int? dueOdo = reminder[DatabaseHelper.columnDueOdometer];
      final int currentOdo =
          reminder[DatabaseHelper.columnCurrentOdometer] ?? 0;
      if (dueOdo != null && currentOdo >= dueOdo) {
        isDue = true;
      }

      if (isDue) {
        final String appName = inputData?['appName'] ?? 'MechMinder';
        final serviceName =
            reminder['template_name'] ??
            reminder[DatabaseHelper.columnNotes] ??
            'Service';
        final body = 'Your "$serviceName" service is due!';

        print(
          "  > Reminder $serviceName (ID: $reminderId) is DUE. Sending notification.",
        );

        await NotificationService().showImmediateReminder(
          id: reminderId,
          title: appName,
          body: body,
        );
      }
    }

    // --- 2. NEW: Check for Expiring Papers ---
    final expiringPapers = await dbHelper.queryVehiclePapersExpiringOn(today);
    print("Found ${expiringPapers.length} papers expiring today.");

    for (final paper in expiringPapers) {
      final String vehicleName =
          '${paper[DatabaseHelper.columnMake]} ${paper[DatabaseHelper.columnModel]}';
      final String paperType = paper[DatabaseHelper.columnPaperType] ?? 'Paper';
      final String body = 'Your $paperType for $vehicleName expires today!';

      print(
        "  > Paper $paperType (ID: ${paper[DatabaseHelper.columnId]}) is EXPIRING. Sending notification.",
      );

      // Use a high-level unique ID for paper notifications
      int notificationId = 100000 + (paper[DatabaseHelper.columnId] as int);

      await NotificationService().showImmediateReminder(
        id: notificationId,
        title: 'Vehicle Paper Expiring',
        body: body,
      );
    }
    // --- END NEW ---

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
    // 0. Give the UI a moment to paint the first frame.
    // This prevents "Skipped frames" right at the start.
    await Future.delayed(const Duration(milliseconds: 200));

    // 1. Run your GIF timer (Reduced to 3s for better UX, user can adjust)
    Future<void> gifTimer = Future.delayed(const Duration(seconds: 4));

    // 2. Run all your app setup
    Future<void> appSetup = () async {
      try {
        await DatabaseHelper.instance.database;
        await NotificationService().initialize();
        await NotificationService().requestPermissions();
        await Workmanager().initialize(
          callbackDispatcher,
          isInDebugMode: kDebugMode,
        );

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

    // 3. Wait for BOTH the timer AND your setup to finish
    await Future.wait([gifTimer, appSetup]);

    // 4. Check Onboarding Status
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // 5. Now, navigate
    if (mounted) {
      if (hasSeenOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.white, // Lottie usually looks best on white or transparent
      body: Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        child: Lottie.asset(
          'assets/animations/car_animation.json',
          width: double.infinity,
          fit: BoxFit.fitWidth,
        ),
      ),
    );
  }
}
