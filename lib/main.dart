import 'package:flutter/material.dart';
import 'package:mechminder/screens/vehicle_list.dart';
// --- 1. IMPORT YOUR DATABASE HELPER ---
import 'package:mechminder/service/database_helper.dart';

// --- 2. MAKE THE main FUNCTION "async" ---
Future<void> main() async {
  // This is needed to make sure database plugins are ready
  WidgetsFlutterBinding.ensureInitialized();

  // --- 3. ADD THIS LINE ---
  // This line tells the app to "await" (wait) until the database
  // is fully initialized before doing anything else.
  await DatabaseHelper.instance.database;
  print("[Main] Database is initialized and ready.");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Manager',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,

      home: const VehicleListScreen(),
    );
  }
}
