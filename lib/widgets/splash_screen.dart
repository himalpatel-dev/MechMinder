import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Import Lottie
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart'; // Import your main home screen
import '../screens/paywall_screen.dart';
import '../service/subscription_provider.dart';
import 'package:provider/provider.dart';

// --- ADD ALL THE IMPORTS FROM MAIN.DART ---
import '../service/database_helper.dart';
import '../service/notification_service.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await DatabaseHelper.instance.database;
      await NotificationService().initialize();
      // Service reminders (date and odometer, with advance warnings) and
      // paper expiry warnings. See NotificationService for the rules.
      await NotificationService().checkAllReminders();
    } catch (e) {
      if (kDebugMode) print("Background reminder task failed: $e");
    }
    if (kDebugMode) {
      print("--- Background Task Complete ---");
    }
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
    await Future.delayed(const Duration(milliseconds: 200));

    // 1. Run your GIF timer (Reduced to 3s for better UX, user can adjust)
    Future<void> gifTimer = Future.delayed(const Duration(seconds: 4));

    // 2. Run all your app setup
    Future<void> appSetup = () async {
      try {
        await DatabaseHelper.instance.database;
        await NotificationService().initialize();
        await NotificationService().requestPermissions();
        // isInDebugMode was removed: it's deprecated and has no effect.
        await Workmanager().initialize(callbackDispatcher);

        await Workmanager().registerPeriodicTask(
          "1",
          "checkVehicleReminders",
          frequency: const Duration(days: 1),
          initialDelay: const Duration(minutes: 15),
        );
        if (kDebugMode) {
          print("[Splash] Workmanager task registered.");
        }
      } catch (e) {
        if (kDebugMode) {
          print("!!! ERROR DURING APP INIT: $e");
        }
      }

      // Data maintenance from older versions. Each step is independent.
      try {
        // Photo rows left behind by deleted vehicles broke restore.
        await DatabaseHelper.instance.deleteOrphanPhotos();
      } catch (e) {
        if (kDebugMode) print("Orphan photo cleanup failed: $e");
      }
      try {
        // Photos used to be saved in the cache, which Android can clear.
        await DatabaseHelper.instance.moveExternalPhotosToAppStorage();
      } catch (e) {
        if (kDebugMode) print("Photo move failed: $e");
      }

      // Also check reminders on app start, in case Android delayed the
      // daily background task. Already-shown alerts are not repeated.
      await NotificationService().checkAllReminders();
    }();

    // 3. Wait for BOTH the timer AND your setup to finish
    await Future.wait([gifTimer, appSetup]);

    // 4. Check Subscription Status
    if (!mounted) return;
    final subProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    // Wait for provider to initialize just in case
    int retries = 0;
    while (subProvider.isLoading && retries < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }

    if (!subProvider.canAccessApp) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PaywallScreen(isBarrier: true),
          ),
        );
      }
      return;
    }

    // 5. Check Onboarding Status
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // 6. Now, navigate
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
