import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct
import 'add_service_screen.dart';
import 'service_detail_screen.dart';
import 'package:flutter/rendering.dart';

class ServiceHistoryTab extends StatefulWidget {
  final int vehicleId;
  const ServiceHistoryTab({super.key, required this.vehicleId});

  @override
  State<ServiceHistoryTab> createState() => _ServiceHistoryTabState();
}

class _ServiceHistoryTabState extends State<ServiceHistoryTab> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _serviceRecords = [];
  bool _isLoading = true;
  int _currentOdometer = 0;
  late ScrollController _scrollController;
  bool _isFabVisible = true;
  @override
  void initState() {
    super.initState();
    _refreshServiceList();

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
  }

  Future<void> _refreshServiceList() async {
    // (This function is unchanged)
    final data = await Future.wait([
      dbHelper.queryServicesForVehicle(widget.vehicleId),
      dbHelper.queryVehicleById(widget.vehicleId),
    ]);

    final services = data[0] as List<Map<String, dynamic>>;
    final vehicle = data[1] as Map<String, dynamic>?;

    setState(() {
      _serviceRecords = services;
      _currentOdometer = vehicle?[DatabaseHelper.columnCurrentOdometer] ?? 0;
      _isLoading = false;
    });
  }

  void _navigateToAddService() {
    // (This function is unchanged)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddServiceScreen(
          vehicleId: widget.vehicleId,
          currentOdometer: _currentOdometer,
        ),
      ),
    ).then((_) {
      _refreshServiceList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    // --- NEW: Grouping Logic ---
    final Map<String, List<Map<String, dynamic>>> groupedServices = {};
    for (var service in _serviceRecords) {
      final String monthYear = service[DatabaseHelper.columnServiceDate]
          .substring(0, 7);
      if (groupedServices[monthYear] == null) {
        groupedServices[monthYear] = [];
      }
      groupedServices[monthYear]!.add(service);
    }
    final sortedMonths = groupedServices.keys.toList();

    // --- THIS IS THE FIX ---
    // Sort the months in descending order (latest first)
    sortedMonths.sort((a, b) => b.compareTo(a));
    // --- END OF FIX ---

    // --- END OF NEW LOGIC ---

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _serviceRecords.isEmpty
          ? const Center(
              child: Text(
                'No service records found. \nTap the "+" button to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: sortedMonths.length,
              itemBuilder: (context, index) {
                final monthYear = sortedMonths[index];
                final servicesForMonth = groupedServices[monthYear]!;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      _formatMonthHeader(monthYear),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        //color: Theme.of(context).primaryColor,
                      ),
                    ),
                    // Expand the first (latest) month by default
                    initiallyExpanded: index == 0,
                    children: servicesForMonth.map((record) {
                      return _buildServiceCard(record, settings);
                    }).toList(),
                  ),
                );
              },
            ),
      floatingActionButton: Visibility(
        visible: _isFabVisible,
        child: FloatingActionButton(
          onPressed: _navigateToAddService,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // (This widget builds the individual service card - unchanged)
  Widget _buildServiceCard(
    Map<String, dynamic> record,
    SettingsProvider settings,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailScreen(
              serviceId: record[DatabaseHelper.columnId],
              vehicleId: widget.vehicleId,
              currentOdometer: _currentOdometer,
            ),
          ),
        ).then((_) {
          _refreshServiceList();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              const Icon(Icons.build, color: Colors.blue, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record[DatabaseHelper.columnServiceName] ?? 'Service',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildIconRow(
                      Icons.calendar_today,
                      record[DatabaseHelper.columnServiceDate],
                    ),
                    const SizedBox(height: 2),
                    _buildIconRow(
                      Icons.speed,
                      '${record[DatabaseHelper.columnOdometer] ?? 'N/A'} ${settings.unitType}',
                    ),
                    const SizedBox(height: 2),
                    _buildIconRow(Icons.store, record['vendor_name'] ?? 'N/A'),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${settings.currencySymbol}${record[DatabaseHelper.columnTotalCost] ?? '0.00'}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record['item_count']} items',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (Helper for icon rows - unchanged)
  Widget _buildIconRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // (Helper to format "2025-11" - unchanged)
  String _formatMonthHeader(String monthYear) {
    try {
      final parts = monthYear.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = DateTime(year, month);

      const monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${monthNames[date.month - 1]} $year';
    } catch (e) {
      return monthYear;
    }
  }
}
