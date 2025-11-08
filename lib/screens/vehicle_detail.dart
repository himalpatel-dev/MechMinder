import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'overview_tab.dart';
import 'service_history_tab.dart';
import 'upcoming_reminders_tab.dart';
import 'expenses_tab.dart';
import 'stats_tab.dart';
import 'vehicle_settings_tab.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId; // We will pass this ID from the list screen

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

// Add "with TickerProviderStateMixin" for the TabController animation
class _VehicleDetailScreenState extends State<VehicleDetailScreen>
    with TickerProviderStateMixin {
  final dbHelper = DatabaseHelper.instance;
  late TabController _tabController;

  Map<String, dynamic>? _vehicle;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize the TabController with 5 tabs
    _tabController = TabController(length: 6, vsync: this);
    _loadVehicleDetails();
  }

  void _loadVehicleDetails() async {
    final vehicleData = await dbHelper.queryVehicleById(widget.vehicleId);
    setState(() {
      _vehicle = vehicleData;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose(); // Always dispose of controllers
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading screen until the vehicle data is fetched
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get the vehicle's name for the title
    String vehicleName = "Vehicle Detail";
    if (_vehicle != null) {
      vehicleName =
          '${_vehicle![DatabaseHelper.columnMake]} ${_vehicle![DatabaseHelper.columnModel]}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicleName),
        // This is where the TabBar goes
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Allows tabs to scroll if they don't fit
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Service History'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Stats'),
            Tab(text: 'Expenses'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      // This TabBarView holds the content for each tab
      body: TabBarView(
        controller: _tabController,
        children: [
          // This is our new, real tab
          OverviewTab(vehicleId: widget.vehicleId), // <-- REPLACED
          // The rest are still placeholders
          ServiceHistoryTab(vehicleId: widget.vehicleId),
          UpcomingRemindersTab(vehicleId: widget.vehicleId),
          StatsTab(vehicleId: widget.vehicleId),
          ExpensesTab(vehicleId: widget.vehicleId),
          _vehicle == null
              ? const Center(child: Text('Error: Vehicle data not found.'))
              : VehicleSettingsTab(
                  vehicle: _vehicle!, // This is now safe
                  onVehicleUpdated: _loadVehicleDetails,
                ),
        ],
      ),
    );
  }
}
