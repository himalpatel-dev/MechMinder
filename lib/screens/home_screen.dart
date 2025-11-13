import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart'; // Make sure path is correct
import 'vehicle_list.dart'; // Corrected import name based on previous context
import 'vendor_list_screen.dart';
import 'service_templates_screen.dart';
import 'app_settings_screen.dart';
import 'add_vehicle.dart'; // Corrected import name based on previous context

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  // GlobalKeys to refresh our lists
  final GlobalKey<VehicleListScreenState> _vehicleListKey = GlobalKey();
  final GlobalKey<VendorListScreenState> _vendorListKey = GlobalKey();
  final GlobalKey<ServiceTemplatesScreenState> _templateListKey = GlobalKey();

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
  
  // --- NEW: FUNCTION TO TOGGLE THEME DIRECTLY ---
  void _toggleTheme(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final ThemeMode currentMode = settings.themeMode;
    ThemeMode nextMode;

    // Cycle: System -> Light -> Dark -> System
    if (currentMode == ThemeMode.system) {
      nextMode = ThemeMode.light;
    } else if (currentMode == ThemeMode.light) {
      nextMode = ThemeMode.dark;
    } else {
      nextMode = ThemeMode.system;
    }

    settings.updateThemeMode(nextMode);
  }
  // --- END OF NEW FUNCTION ---

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
      case 1: // Vendors Tab
        return FloatingActionButton(
          onPressed: () {
            _vendorListKey.currentState?.showAddEditVendorDialog(vendor: null);
          },
          child: const Icon(Icons.add),
        );
      case 2: // Templates Tab
        return FloatingActionButton(
          onPressed: () {
            _templateListKey.currentState?.showAddEditTemplateDialog(template: null);
          },
          child: const Icon(Icons.add),
        );
      case 3: 
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    // Determine background color based on theme
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barColor = isDark ? Colors.grey[900]! : Colors.white;
    
    // Determine which icon to show
    IconData themeIcon;
    if (settings.themeMode == ThemeMode.light) {
      themeIcon = Icons.light_mode; // Sun
    } else if (settings.themeMode == ThemeMode.dark) {
      themeIcon = Icons.dark_mode; // Moon
    } else {
      themeIcon = Icons.brightness_auto; // System (A)
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('MechMinder'),
        actions: [
          // --- UPDATED BUTTON ---
          IconButton(
            icon: Icon(themeIcon),
            tooltip: 'Toggle Theme',
            onPressed: () {
              // Call the direct toggle function
              _toggleTheme(context);
            },
          ),
          // --- END UPDATED BUTTON ---
        ],
      ),
      
      body: TabBarView(
        controller: _tabController,
        children: [
          VehicleListScreen(key: _vehicleListKey),
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
            
            tabs: const [
              Tab(icon: Icon(Icons.directions_car), text: 'Vehicles'),
              Tab(icon: Icon(Icons.store), text: 'Workshop'),
              Tab(icon: Icon(Icons.list_alt), text: 'AutoSet'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}