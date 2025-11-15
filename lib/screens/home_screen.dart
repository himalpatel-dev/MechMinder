import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart'; // Make sure path is correct
import 'vehicle_list.dart';
import 'all_reminders_screen.dart';
import 'master_screen.dart';
import 'app_settings_screen.dart';
import 'add_vehicle.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  // (Keys are unchanged)
  final GlobalKey<VehicleListScreenState> _vehicleListKey = GlobalKey();
  final GlobalKey<AllRemindersScreenState> _allRemindersKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- (This function is unchanged) ---
  Widget? _buildFloatingActionButton() {
    switch (_currentTabIndex) {
      case 0: // Vehicles Tab
        return FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
            ).then((_) {
              _vehicleListKey.currentState?.refreshVehicleList();
            });
          },
          child: const Icon(Icons.add),
        );
      case 1: // Reminders Tab
        return FloatingActionButton(
          onPressed: () {
            final settings = Provider.of<SettingsProvider>(
              context,
              listen: false,
            );
            _allRemindersKey.currentState?.showAddManualReminderDialog(
              settings,
            );
          },
          child: const Icon(Icons.add),
        );
      case 2: // Master Tab
      case 3: // Settings Tab
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barColor = isDark ? Colors.grey[900]! : Colors.white;

    // --- FIX: Simplified Icon Logic ---
    IconData themeIcon;
    if (settings.themeMode == ThemeMode.dark) {
      themeIcon = Icons.dark_mode; // Moon
    } else {
      themeIcon = Icons.light_mode; // Sun
    }
    // --- END FIX ---

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MechMinder'),
          actions: [
            // --- UPDATED BUTTON ---
            IconButton(
              icon: Icon(themeIcon),
              tooltip: 'Toggle Theme',
              onPressed: () {
                // --- FIX: Simplified Toggle Logic ---
                final ThemeMode currentMode = settings.themeMode;
                if (currentMode == ThemeMode.light) {
                  settings.updateThemeMode(ThemeMode.dark);
                } else {
                  settings.updateThemeMode(ThemeMode.light);
                }
                // --- END FIX ---
              },
            ),
          ],
        ),

        // (The rest of the file is unchanged)
        body: TabBarView(
          controller: _tabController,
          children: [
            VehicleListScreen(key: _vehicleListKey),
            AllRemindersScreen(key: _allRemindersKey),
            const MasterScreen(),
            AppSettingsScreen(
              vehicleListKey: _vehicleListKey,
              allRemindersKey: _allRemindersKey,
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
        bottomNavigationBar: Material(
          color: barColor,
          elevation: 8,
          child: SafeArea(
            child: TabBar(
              controller: _tabController,
              labelColor: settings.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: settings.primaryColor,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 10),
              tabs: const [
                Tab(icon: Icon(Icons.directions_car), text: 'Vehicles'),
                Tab(icon: Icon(Icons.notifications_active), text: 'Reminders'),
                Tab(icon: Icon(Icons.apps), text: 'Master'),
                Tab(icon: Icon(Icons.settings), text: 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
