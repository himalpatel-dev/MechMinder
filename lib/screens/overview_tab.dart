import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct
import '../service/notification_service.dart'; // Make sure this path is correct
import '../widgets/full_screen_photo_viewer.dart'; // Make sure this path is correct

class OverviewTab extends StatefulWidget {
  final int vehicleId;
  const OverviewTab({super.key, required this.vehicleId});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final dbHelper = DatabaseHelper.instance;
  final TextEditingController _odometerController = TextEditingController();

  Map<String, dynamic>? _nextDueDateReminder;
  Map<String, dynamic>? _nextOdometerReminder;
  List<Map<String, dynamic>> _vehiclePhotos = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // (This function is unchanged)
    try {
      final data = await Future.wait([
        dbHelper.queryVehicleById(widget.vehicleId),
        dbHelper.queryNextDueSummary(widget.vehicleId),
        dbHelper.queryPhotosForParent(widget.vehicleId, 'vehicle'),
      ]);
      final vehicleData = data[0] as Map<String, dynamic>?;
      final summary = data[1] as Map<String, Map<String, dynamic>?>;
      final photos = data[2] as List<Map<String, dynamic>>;
      if (vehicleData == null) {
        throw Exception("Vehicle data not found (ID: ${widget.vehicleId})");
      }
      setState(() {
        _odometerController.text =
            (vehicleData[DatabaseHelper.columnCurrentOdometer] ?? 0).toString();
        _nextDueDateReminder = summary['nextByDate'];
        _nextOdometerReminder = summary['nextByOdometer'];
        _vehiclePhotos = List.from(photos);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      print("[DEBUG OverviewTab] !!!--- ERROR in _loadData ---!!!");
      print(e);
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _saveOdometer() async {
    // (This function is unchanged)
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    int newOdometer = int.tryParse(_odometerController.text) ?? 0;
    await dbHelper.updateVehicleOdometer(widget.vehicleId, newOdometer);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Odometer updated!'),
        backgroundColor: Colors.green,
      ),
    );
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
    final allReminders = await dbHelper.queryRemindersForVehicle(
      widget.vehicleId,
    );
    for (var reminder in allReminders) {
      final dueOdometer = reminder[DatabaseHelper.columnDueOdometer];
      if (dueOdometer != null && newOdometer >= dueOdometer) {
        final int reminderId = reminder[DatabaseHelper.columnId];
        final String templateName = reminder['template_name'] ?? 'Service';
        print("  > Odometer due for '$templateName'! Sending notification.");
        await NotificationService().showImmediateReminder(
          id: reminderId,
          title: 'Vehicle Service Due',
          body:
              'Your "$templateName" service is due! (Reached $dueOdometer km).',
        );
      }
    }
    _refreshReminderSummary();
  }

  Future<void> _refreshReminderSummary() async {
    // (This function is unchanged)
    final summary = await dbHelper.queryNextDueSummary(widget.vehicleId);
    setState(() {
      _nextDueDateReminder = summary['nextByDate'];
      _nextOdometerReminder = summary['nextByOdometer'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final Color myAppColor = settings.primaryColor;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error loading data:\n\n$_errorMessage',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // --- 1. Odometer Card (UPDATED) ---
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // --- THIS IS THE FIX ---
                      Icon(Icons.speed, size: 14, color: settings.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'CURRENT ODOMETER',
                        style: TextStyle(
                          fontSize: 12,
                          color: settings.primaryColor,
                        ),
                      ),
                      // --- END OF FIX ---
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _odometerController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            suffixText: settings.unitType,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saveOdometer,
                        child: const Text('UPDATE'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- 2. Next Due Summary Card (Unchanged) ---
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            child: Column(
              children: [
                const ListTile(
                  title: Text(
                    'Next Due Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildDetailTile(
                  icon: Icons.calendar_today,
                  title:
                      _nextDueDateReminder?['template_name'] ??
                      'No date-based reminders',
                  subtitle: _nextDueDateReminder != null
                      ? 'Due by: ${_nextDueDateReminder![DatabaseHelper.columnDueDate]}'
                      : 'All caught up!',
                  isFaded: _nextDueDateReminder == null,
                  primaryColor: myAppColor,
                ),
                _buildDetailTile(
                  icon: Icons.speed,
                  title:
                      _nextOdometerReminder?['template_name'] ??
                      'No odometer-based reminders',
                  subtitle: _nextOdometerReminder != null
                      ? 'Due by: ${_nextOdometerReminder![DatabaseHelper.columnDueOdometer]} ${settings.unitType}'
                      : 'All caught up!',
                  isFaded: _nextOdometerReminder == null,
                  primaryColor: myAppColor,
                ),
              ],
            ),
          ),

          // --- 3. Photo Gallery Card (Unchanged) ---
          const SizedBox(height: 20),
          Card(
            // (This card is unchanged)
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'PHOTO GALLERY',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                Container(
                  height: 120,
                  child: _vehiclePhotos.isEmpty
                      ? const Center(child: Text('No photos added yet.'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _vehiclePhotos.length,
                          itemBuilder: (context, index) {
                            final photo = _vehiclePhotos[index];
                            final photoPath = photo[DatabaseHelper.columnUri];

                            return GestureDetector(
                              onTap: () {
                                final paths = _vehiclePhotos
                                    .map(
                                      (photo) =>
                                          photo[DatabaseHelper.columnUri]
                                              as String,
                                    )
                                    .toList();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenPhotoViewer(
                                      photoPaths: paths,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 120,
                                height: 120,
                                margin: const EdgeInsets.only(right: 8.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(File(photoPath)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // (This helper is unchanged and already uses the theme color)
  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color primaryColor,
    bool isFaded = false,
  }) {
    final Color? activeColor = primaryColor;
    final Color? fadedColor = Theme.of(context).disabledColor;

    return ListTile(
      leading: Icon(icon, color: isFaded ? fadedColor : activeColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isFaded ? fadedColor : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 14, color: isFaded ? fadedColor : null),
      ),
    );
  }
}
