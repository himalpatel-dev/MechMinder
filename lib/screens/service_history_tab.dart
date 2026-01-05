import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart';
import '../service/settings_provider.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    // --- Grouping Logic ---
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

    // Sort the months in descending order (latest first)
    sortedMonths.sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _serviceRecords.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_edu_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Service History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to add a record.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: sortedMonths.length,
              itemBuilder: (context, index) {
                final monthYear = sortedMonths[index];
                final servicesForMonth = groupedServices[monthYear]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Header
                    // Month Header
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        child: Text(
                          _formatMonthHeader(monthYear),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    // List of Services for this Month
                    ...servicesForMonth.map((record) {
                      return _buildServiceCard(
                        record,
                        settings,
                        isDark,
                        primaryColor,
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
      floatingActionButton: Visibility(
        visible: _isFabVisible,
        child: FloatingActionButton.extended(
          onPressed: _navigateToAddService,
          backgroundColor: primaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Add Service",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    Map<String, dynamic> record,
    SettingsProvider settings,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.build_circle_outlined,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record[DatabaseHelper.columnServiceName] ??
                                'Service',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark
                                  ? Colors.white
                                  : Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record['vendor_name'] ?? 'Unknown Workshop',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${settings.currencySymbol}${record[DatabaseHelper.columnTotalCost] ?? '0.00'}',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoChip(
                      Icons.calendar_today,
                      record[DatabaseHelper.columnServiceDate],
                      isDark,
                    ),
                    _buildInfoChip(
                      Icons.speed,
                      '${record[DatabaseHelper.columnOdometer] ?? 'N/A'} ${settings.unitType}',
                      isDark,
                    ),
                    _buildInfoChip(
                      Icons.receipt_long,
                      '${record['item_count']} Items',
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

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
