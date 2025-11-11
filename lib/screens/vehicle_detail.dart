import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct
import 'overview_tab.dart'; // Make sure all your tabs are imported
import 'service_history_tab.dart';
import 'upcoming_reminders_tab.dart';
import 'stats_tab.dart';
import 'expenses_tab.dart';
import 'vehicle_settings_tab.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen>
    with TickerProviderStateMixin {
  final dbHelper = DatabaseHelper.instance;
  late TabController _tabController;

  Map<String, dynamic>? _vehicle;
  bool _isLoading = true;

  // We need to fetch the odometer here to pass it to the service screen
  // ignore: unused_field
  int _currentOdometer = 0;

  @override
  void initState() {
    super.initState();
    // --- UPDATED: We now have 6 tabs ---
    _tabController = TabController(length: 6, vsync: this);
    _loadVehicleDetails();
  }

  void _loadVehicleDetails() async {
    final vehicleData = await dbHelper.queryVehicleById(widget.vehicleId);
    setState(() {
      _vehicle = vehicleData;
      if (vehicleData != null) {
        _currentOdometer =
            vehicleData[DatabaseHelper.columnCurrentOdometer] ?? 0;
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final settings = Provider.of<SettingsProvider>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    String vehicleName = "Vehicle Detail";
    if (_vehicle != null) {
      vehicleName =
          '${_vehicle![DatabaseHelper.columnMake]} ${_vehicle![DatabaseHelper.columnModel]}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicleName),

        // --- THIS IS THE REDESIGNED TABBAR ---
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Keep it scrollable for 6 items
          // --- NEW PROPERTIES ---
          indicatorWeight: 4.0, // Make the line thicker
          unselectedLabelColor: Colors.black54, // Fades out inactive tabs
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabAlignment: TabAlignment.start, // Aligns tabs to the start
          padding: const EdgeInsets.symmetric(
            horizontal: 8.0,
          ), // Reduces the side margin
          labelPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
          ), // Space between tabs
          // --- END OF NEW PROPERTIES ---
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'History'), // Shortened from "Service History"
            Tab(text: 'Upcoming'),
            Tab(text: 'Stats'),
            Tab(text: 'Expenses'),
            Tab(text: 'Settings'),
          ],
        ),
        // --- END OF REDESIGN ---
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OverviewTab(vehicleId: widget.vehicleId),
          ServiceHistoryTab(vehicleId: widget.vehicleId),
          UpcomingRemindersTab(vehicleId: widget.vehicleId),
          StatsTab(vehicleId: widget.vehicleId),
          ExpensesTab(vehicleId: widget.vehicleId),
          _vehicle == null
              ? const Center(child: Text('Error: Vehicle data not found.'))
              : VehicleSettingsTab(
                  vehicle: _vehicle!,
                  onVehicleUpdated: _loadVehicleDetails,
                ),
        ],
      ),
    );
  }
}
