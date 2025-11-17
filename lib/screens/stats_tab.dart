import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Import this to detect scroll direction
import 'package:provider/provider.dart';
import '../service/database_helper.dart';
import '../widgets/stats_pie_chart.dart'; // Make sure this path is correct
import '../service/settings_provider.dart';
import '../service/excel_service.dart';

class StatsTab extends StatefulWidget {
  final int vehicleId;
  const StatsTab({super.key, required this.vehicleId});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final dbHelper = DatabaseHelper.instance;
  double _totalSpending = 0.0;
  List<Map<String, dynamic>> _spendingByCategory = [];
  bool _isLoading = true;

  // --- NEW: Add a Scroll Controller and a visibility tracker ---
  late ScrollController _scrollController;
  bool _isFabVisible = true;
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    _loadStats();

    // --- NEW: Set up the scroll listener ---
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      // If user is scrolling down, hide the button
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_isFabVisible) {
          setState(() {
            _isFabVisible = false;
          });
        }
      }
      // If user is scrolling up, show the button
      else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (!_isFabVisible) {
          setState(() {
            _isFabVisible = true;
          });
        }
      }
    });
    // --- END NEW ---
  }

  @override
  void dispose() {
    // --- NEW: Dispose the controller ---
    _scrollController.dispose();
    // --- END NEW ---
    super.dispose();
  }

  Future<void> _loadStats() async {
    // (This function is unchanged)
    final total = await dbHelper.queryTotalSpending(widget.vehicleId);
    final byCategory = await dbHelper.querySpendingByCategory(widget.vehicleId);
    byCategory.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));
    setState(() {
      _totalSpending = total;
      _spendingByCategory = byCategory;
      _isLoading = false;
    });
  }

  Future<void> _exportToExcel(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    // (This function is unchanged)
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Creating report...')),
    );
    final vehicle = await dbHelper.queryVehicleById(widget.vehicleId);
    final vehicleName = (vehicle != null)
        ? '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}'
        : 'Vehicle_Report';

    final excelService = ExcelService(
      dbHelper: DatabaseHelper.instance,
      settings: settings,
    );

    final result = await excelService.createExcelReport(
      widget.vehicleId,
      vehicleName,
    );

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(result ?? 'An unknown error occurred.'),
        backgroundColor: result != null && result.startsWith('Report generated')
            ? Colors.green
            : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      // 1. We wrap the content in its own Scaffold
      body: SingleChildScrollView(
        // --- NEW: Attach the scroll controller ---
        controller: _scrollController,
        // --- END NEW ---
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // (Total Spending Card is unchanged)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL LIFETIME SPENDING',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${settings.currencySymbol}${_totalSpending.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // (Pie Chart is unchanged)
            StatsPieChart(spendingData: _spendingByCategory),
            const SizedBox(height: 20),

            // (Spending by Category Card is unchanged)
            Card(
              elevation: 4,
              child: Column(
                children: [
                  const ListTile(
                    title: Text(
                      'Spending by Category',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  if (_spendingByCategory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No spending data found.'),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _spendingByCategory.length,
                      itemBuilder: (context, index) {
                        final item = _spendingByCategory[index];
                        String category = item[DatabaseHelper.columnCategory];
                        double total = (item['total'] as num).toDouble();

                        return ListTile(
                          title: Text(category),
                          trailing: Text(
                            '${settings.currencySymbol}${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            // Add padding at the bottom for the FAB
            const SizedBox(height: 80),
          ],
        ),
      ),

      // --- NEW: Wrap the button in a Visibility widget ---
      floatingActionButton: Visibility(
        visible: _isFabVisible,
        child: FloatingActionButton(
          onPressed: () {
            _exportToExcel(context, settings);
          },
          tooltip: 'Export to Excel',
          child: const Icon(Icons.download_for_offline),
        ),
      ),
      // --- END NEW ---
    );
  }
}
