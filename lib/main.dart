import 'package:flutter/material.dart';
import 'package:mechminder/widgets/splash_screen.dart'; // <-- NEW: Start on Splash Screen
import 'package:provider/provider.dart';
import 'service/settings_provider.dart';

// --- REMOVED ALL OTHER IMPORTS (like workmanager, database, etc.) ---

// --- REMOVED callbackDispatcher() ---
// (We will move this to the splash screen)

Future<void> main() async {
  // 1. Ensure all Flutter bindings are ready
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Run the app
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

        return MaterialApp(
          title: 'MechMinder',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,

          // (Light Theme is unchanged)
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: myAppColor,
              brightness: Brightness.light,
            ),
            dropdownMenuTheme: DropdownMenuThemeData(
              menuStyle: MenuStyle(
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(
                      color: Colors.grey.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                ),
                backgroundColor: MaterialStateProperty.all(Colors.white),
                surfaceTintColor: MaterialStateProperty.all(Colors.white),
              ),
            ),
          ),

          // (Dark Theme is unchanged)
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: myAppColor,
              brightness: Brightness.dark,
            ),
            dropdownMenuTheme: DropdownMenuThemeData(
              menuStyle: MenuStyle(
                backgroundColor: MaterialStateProperty.all(Colors.grey[800]),
                surfaceTintColor: MaterialStateProperty.all(Colors.grey[800]),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(color: Colors.grey[600]!, width: 1),
                  ),
                ),
              ),
            ),
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

          // --- FIX: Start on the SplashScreen ---
          home: const SplashScreen(),
        );
      },
    );
  }
}
