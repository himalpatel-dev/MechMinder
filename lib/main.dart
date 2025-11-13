import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:mechminder/service/database_helper.dart';
import 'package:mechminder/service/notification_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:provider/provider.dart';  
import 'service/settings_provider.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("--- Background Task Started ---");

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

Future<void> main() async {
  // (Your main function is unchanged)
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper.instance.database;
  print("[Main] Database is initialized and ready.");

  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  await Workmanager().registerPeriodicTask(
    "1",
    "checkVehicleReminders",
    frequency: const Duration(days: 1),
    initialDelay: const Duration(minutes: 15),
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final Color myAppColor = settings.primaryColor;

        // --- THIS IS THE FIX ---
        // We define the bordered style here
        final MenuStyle borderedMenuStyle = MenuStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
              side: BorderSide(
                // Use a subtle border color that works in both themes
                color: Colors.grey.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
        );
        // --- END OF FIX ---

        return MaterialApp(
          title: 'MechMinder',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,

          // --- 2. DEFINE THE LIGHT THEME ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: myAppColor,
              brightness: Brightness.light,
            ),
            // --- ADD THIS ---
            dropdownMenuTheme: DropdownMenuThemeData(
              menuStyle: borderedMenuStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.white),
                surfaceTintColor: MaterialStateProperty.all(Colors.white),
              ),
            ),
            // --- END ADD ---
          ),

          // --- 3. DEFINE THE DARK THEME ---
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: myAppColor,
              brightness: Brightness.dark,
            ),

            // --- ADD THIS ---
            dropdownMenuTheme: DropdownMenuThemeData(
              menuStyle: borderedMenuStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.grey[800]),
                surfaceTintColor: MaterialStateProperty.all(Colors.grey[800]),
              ),
            ),

            // --- END ADD ---
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: myAppColor,
                foregroundColor: Colors.white,
              ),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: myAppColor,
              foregroundColor: Colors.white,
            ),
          ),

          home: const HomeScreen(),
        );
      },
    );
  }
}
