import 'package:flutter/material.dart';
import 'package:mechminder/screens/vehicle_papers_screen.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct
import 'overview_tab.dart'; // Make sure all your tabs are imported
import 'service_history_tab.dart';
import 'stats_tab.dart';
import 'expenses_tab.dart';
import 'add_vehicle.dart'; // <-- NEW: Import AddVehicleScreen

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
  int _dataVersion = 0;
  // We need to fetch the odometer here to pass it to the service screen
  // ignore: unused_field
  int _currentOdometer = 0;

  String get _vehicleName {
    if (_vehicle == null) return 'this vehicle';
    return '${_vehicle![DatabaseHelper.columnMake]} ${_vehicle![DatabaseHelper.columnModel]}';
  }

  @override
  void initState() {
    super.initState();
    // --- UPDATED: We now have 6 tabs ---
    _tabController = TabController(length: 5, vsync: this);
    _loadVehicleDetails();
  }

  void _navigateToEditVehicle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(vehicleId: widget.vehicleId),
      ),
    ).then((_) {
      // 1. Reload the AppBar title
      _loadVehicleDetails();

      // --- THIS IS THE FIX ---
      // 2. Increment the version number. This will force
      //    the OverviewTab to reload its data.
      setState(() {
        _dataVersion++;
      });
      // --- END OF FIX ---
    });
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vehicle?'),
        content: Text(
          'Delete "$_vehicleName" permanently?\n\n'
          'This also deletes all of its:\n'
          '• services, parts and bill photos\n'
          '• expenses\n'
          '• reminders\n'
          '• papers (insurance, PUC, ...) and documents\n'
          '• to-do items\n'
          '• vehicle photos\n\n'
          'This can\'t be undone. Make a backup first (Settings → Backup) '
          'if you might need this data again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              try {
                await dbHelper.deleteVehicle(widget.vehicleId);
              } catch (e) {
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not delete: $e')),
                  );
                }
                return;
              }
              if (ctx.mounted) Navigator.of(ctx).pop(); // Close dialog
              if (context.mounted) {
                Navigator.of(context).pop(); // Go back to home screen
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _loadVehicleDetails() async {
    final vehicleData = await dbHelper.queryVehicleById(widget.vehicleId);
    if (!mounted) return;
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
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: settings.primaryColor),
            tooltip: 'Edit Vehicle',
            onPressed: () => _navigateToEditVehicle(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Delete Vehicle',
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
        // --- THIS IS THE REDESIGNED TABBAR ---
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Material(
            // Use material to get the proper background / ripple if needed
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: false, // <-- each tab will share available width
              indicatorWeight: 3.5,
              indicatorSize:
                  TabBarIndicatorSize.tab, // indicator fills the full tab
              // remove extra padding so tabs divide space cleanly
              labelPadding: EdgeInsets.zero,
              // styles
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: MediaQuery.of(context).size.width > 400 ? 15 : 13,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: MediaQuery.of(context).size.width > 400 ? 14 : 12,
              ),

              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Services'),
                Tab(text: 'Expenses'),
                Tab(text: 'Essentials'),
                Tab(text: 'Insights'),
              ],
            ),
          ),
        ),
        // --- END OF REDESIGN ---
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OverviewTab(
            vehicleId: widget.vehicleId,
            dataVersion: _dataVersion, // Pass the signal
            onOpenPapers: () => _tabController.animateTo(3), // Essentials
          ),
          ServiceHistoryTab(vehicleId: widget.vehicleId),
          ExpensesTab(vehicleId: widget.vehicleId),
          VehiclePapersScreen(vehicleId: widget.vehicleId), // <-- NEW PAGE
          StatsTab(vehicleId: widget.vehicleId),
        ],
      ),
    );
  }
}
