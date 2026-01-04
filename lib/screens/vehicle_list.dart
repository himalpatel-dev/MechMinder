import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'vehicle_detail.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';
import 'dart:io';
import '../widgets/mini_spending_chart.dart'; // Make sure this path is correct
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => VehicleListScreenState();
}

class VehicleListScreenState extends State<VehicleListScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshVehicleList();
  }

  void refreshVehicleList() async {
    // (This function is unchanged)
    setState(() {
      _isLoading = true;
    });
    final allVehicles = await dbHelper.queryAllVehiclesWithNextReminder();
    List<Map<String, dynamic>> vehiclesWithSpending = [];
    for (var vehicle in allVehicles) {
      final serviceTotal = await dbHelper.queryTotalSpendingForType(
        vehicle[DatabaseHelper.columnId],
        'services',
      );
      final expenseTotal = await dbHelper.queryTotalSpendingForType(
        vehicle[DatabaseHelper.columnId],
        'expenses',
      );
      Map<String, dynamic> vehicleData = Map.from(vehicle);
      vehicleData['service_total'] = serviceTotal;
      vehicleData['expense_total'] = expenseTotal;
      vehiclesWithSpending.add(vehicleData);
    }
    setState(() {
      _vehicles = vehiclesWithSpending;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("Loading dashboard..."),
              ],
            ),
          )
        : _vehicles.isEmpty
        ? const Center(
            // (Empty list text is unchanged)
            child: Text(
              'No vehicles found. \nTap the "+" button to add one!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          )
        : AnimationLimiter(
            child: ListView.builder(
              // (Your animated list is unchanged)
              padding: const EdgeInsets.all(8.0),
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];

                // (All your data logic is unchanged)
                String nextReminderText = "No upcoming reminders";
                final String? nextTemplate = vehicle['template_name'];
                final String? nextDate = vehicle[DatabaseHelper.columnDueDate];
                final int? nextOdo = vehicle[DatabaseHelper.columnDueOdometer];
                if (nextTemplate != null) {
                  if (nextDate != null) {
                    nextReminderText = 'Next: $nextTemplate (by $nextDate)';
                  } else if (nextOdo != null) {
                    nextReminderText =
                        'Next: $nextTemplate (by $nextOdo ${settings.unitType})';
                  }
                }
                final double serviceTotal = vehicle['service_total'] ?? 0.0;
                final double expenseTotal = vehicle['expense_total'] ?? 0.0;
                final double totalSpending = serviceTotal + expenseTotal;

                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Card(
                        // (Your beautiful card UI is unchanged)
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            final int vehicleId =
                                vehicle[DatabaseHelper.columnId];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VehicleDetailScreen(vehicleId: vehicleId),
                              ),
                            ).then((_) {
                              refreshVehicleList();
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: _buildVehicleImage(
                                      vehicle['photo_uri'],
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black.withOpacity(0.8),
                                            Colors.transparent,
                                          ],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    right: 12,
                                    child: Text(
                                      '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${vehicle[DatabaseHelper.columnPurchaseDate] ?? 'N/A'} | ${vehicle[DatabaseHelper.columnRegNo] ?? 'N/A'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'NEXT REMINDER',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            nextReminderText,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (totalSpending == 0)
                                            Column(
                                              children: [
                                                Icon(
                                                  Icons.pie_chart_outline,
                                                  size: 40,
                                                  color: Colors.grey[300],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${settings.currencySymbol}0 total',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Column(
                                              children: [
                                                SizedBox(
                                                  width: 50,
                                                  height: 50,
                                                  child: MiniSpendingChart(
                                                    serviceSpending:
                                                        serviceTotal,
                                                    expenseSpending:
                                                        expenseTotal,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${settings.currencySymbol}${totalSpending.toStringAsFixed(0)} total',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
  }

  // (This helper function is unchanged)
  Widget _buildVehicleImage(String? photoPath) {
    if (photoPath != null && photoPath.isNotEmpty) {
      return Image.file(
        File(photoPath),
        fit: BoxFit.cover,
        cacheWidth: 800, // Optimize memory for list items

        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
          );
        },
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.directions_car, color: Colors.grey[400], size: 60),
      );
    }
  }
}
