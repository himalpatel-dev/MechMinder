import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';
import 'vehicle_list.dart';
import 'all_reminders_screen.dart';
import 'master_screen.dart';
import 'app_settings_screen.dart';
import 'add_vehicle.dart';

// --- NEW: Define the structure for the navigation items ---
class BottomNavItem {
  final IconData icon;
  final String title;
  BottomNavItem({required this.icon, required this.title});
}
// --- END NEW ---

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0; // Tracks the visible page

  // GlobalKeys to refresh our lists
  final GlobalKey<VehicleListScreenState> _vehicleListKey = GlobalKey();
  final GlobalKey<AllRemindersScreenState> _allRemindersKey = GlobalKey();

  // --- NEW: Define the items for the bottom bar ---
  final List<BottomNavItem> _navItems = [
    BottomNavItem(icon: Icons.directions_car, title: 'Vehicles'),
    BottomNavItem(icon: Icons.notifications_active, title: 'Reminders'),
    BottomNavItem(icon: Icons.apps, title: 'Master'),
    BottomNavItem(icon: Icons.settings, title: 'Settings'),
  ];
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _navItems.length, vsync: this);
    // Listener to update the Floating Action Button
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

  // --- (Floating Action Button logic is unchanged) ---
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

  // --- NEW: The custom item builder for the bottom bar ---
  Widget _buildBottomBarItem(
    BuildContext context,
    int index,
    SettingsProvider settings,
  ) {
    final bool isSelected = index == _currentTabIndex;
    final Color primaryColor = settings.primaryColor;

    return GestureDetector(
      onTap: () {
        // Change the view and the tab controller index
        _tabController.animateTo(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          // White pill for selected, transparent for unselected
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Icon
            Icon(
              _navItems[index].icon,
              size: 24,
              // Icon is Primary Color if selected (on White), White if unselected (on Primary Bar)
              color: isSelected ? primaryColor : Colors.white,
            ),
            // 2. Text (Revealed when selected)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: SizedBox(
                width: isSelected ? null : 0,
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          _navItems[index].title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor, // Text matches Icon color
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- END NEW ---

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    // Determine which icon to show (unchanged)
    IconData themeIcon;
    if (settings.themeMode == ThemeMode.dark) {
      themeIcon = Icons.dark_mode;
    } else {
      themeIcon = Icons.light_mode;
    }

    return DefaultTabController(
      length: _navItems.length,
      child: Scaffold(
        extendBody: true, // Allows body to go behind the floating bar
        appBar: AppBar(
          title: const Text('MechMinder'),
          actions: [
            IconButton(
              icon: Icon(themeIcon),
              tooltip: 'Toggle Theme',
              onPressed: () {
                final ThemeMode currentMode = settings.themeMode;
                if (currentMode == ThemeMode.light) {
                  settings.updateThemeMode(ThemeMode.dark);
                } else {
                  settings.updateThemeMode(ThemeMode.light);
                }
              },
            ),
          ],
          // --- REMOVED top TabBar ---
        ),

        body: TabBarView(
          // --- TabBarView uses the TabController ---
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

        // --- THIS IS THE FINAL, ANIMATED BOTTOM NAVIGATION ---
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Material(
              color: settings.primaryColor, // The Blue Background
              elevation: 8,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                height: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _navItems.asMap().entries.map((entry) {
                    return _buildBottomBarItem(context, entry.key, settings);
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        // --- END OF FINAL BOTTOM NAVIGATION ---
        // --- END OF FINAL BOTTOM NAVIGATION ---
      ),
    );
  }
}
