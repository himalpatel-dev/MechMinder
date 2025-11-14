import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart'; // Make sure path is correct
import 'vehicle_list.dart';
import 'vendor_list_screen.dart';
import 'service_templates_screen.dart';
import 'app_settings_screen.dart';
import 'add_vehicle.dart';
import 'all_reminders_screen.dart'; // Make sure this is imported

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  // --- THIS IS THE FIX ---
  // We use the new, public state class names
  final GlobalKey<VehicleListScreenState> _vehicleListKey = GlobalKey();
  final GlobalKey<VendorListScreenState> _vendorListKey = GlobalKey();
  final GlobalKey<ServiceTemplatesScreenState> _templateListKey = GlobalKey();
  final GlobalKey<AllRemindersScreenState> _allRemindersKey =
      GlobalKey(); // <-- FIX
  // --- END OF FIX ---

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // 5 tabs
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
            // --- THIS IS THE FIX ---
            // Call the new, public function
            _allRemindersKey.currentState?.showAddManualReminderDialog(
              settings,
            );
            // --- END OF FIX ---
          },
          child: const Icon(Icons.add),
        );
      case 2: // Vendors Tab
        return FloatingActionButton(
          onPressed: () {
            // --- THIS IS THE FIX ---
            // We remove the 'settings' argument, it's not needed
            _vendorListKey.currentState?.showAddEditVendorDialog(vendor: null);
            // --- END OF FIX ---
          },
          child: const Icon(Icons.add),
        );
      case 3: // Templates Tab
        return FloatingActionButton(
          onPressed: () {
            _templateListKey.currentState?.showAddEditTemplateDialog(
              template: null,
            );
          },
          child: const Icon(Icons.add),
        );
      case 4: // Settings Tab
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barColor = isDark ? Colors.grey[900]! : Colors.white;

    IconData themeIcon;
    if (settings.themeMode == ThemeMode.light) {
      themeIcon = Icons.light_mode;
    } else if (settings.themeMode == ThemeMode.dark) {
      themeIcon = Icons.dark_mode;
    } else {
      themeIcon = Icons.brightness_auto;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MechMinder'),
        actions: [
          IconButton(
            icon: Icon(themeIcon),
            tooltip: 'Toggle Theme',
            onPressed: () {
              final ThemeMode currentMode = settings.themeMode;
              ThemeMode nextMode;
              if (currentMode == ThemeMode.system) {
                nextMode = ThemeMode.light;
              } else if (currentMode == ThemeMode.light) {
                nextMode = ThemeMode.dark;
              } else {
                nextMode = ThemeMode.system;
              }
              settings.updateThemeMode(nextMode);
            },
          ),
        ],
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          VehicleListScreen(key: _vehicleListKey),
          AllRemindersScreen(key: _allRemindersKey), // <-- FIX
          VendorListScreen(key: _vendorListKey),
          ServiceTemplatesScreen(key: _templateListKey),
          const AppSettingsScreen(),
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
              Tab(icon: Icon(Icons.store), text: 'Vendors'),
              Tab(icon: Icon(Icons.list_alt), text: 'Templates'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
