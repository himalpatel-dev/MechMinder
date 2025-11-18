import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct
// Make sure this path is correct
import '../widgets/full_screen_photo_viewer.dart'; // Make sure this path is correct
import 'package:carousel_slider/carousel_slider.dart';
import '../service/notification_service.dart'; // Make sure this path is correct

class OverviewTab extends StatefulWidget {
  final int vehicleId;
  final int dataVersion;

  const OverviewTab({
    super.key,
    required this.vehicleId,
    required this.dataVersion,
  });

  @override
  State<OverviewTab> createState() => OverviewTabState();
}

class OverviewTabState extends State<OverviewTab> {
  final dbHelper = DatabaseHelper.instance;
  final TextEditingController _odometerController = TextEditingController();

  // ignore: unused_field
  Map<String, dynamic>? _vehicle;
  List<Map<String, dynamic>> _vehiclePhotos = [];

  // --- NEW: Lists for reminders ---
  List<Map<String, dynamic>> _overdueReminders = [];
  List<Map<String, dynamic>> _comingSoonReminders = [];
  int _currentOdo = 0;
  // --- END NEW ---

  bool _isLoading = true;
  String? _errorMessage;

  int _currentPhotoIndex = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void didUpdateWidget(OverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataVersion != oldWidget.dataVersion) {
      loadData();
    }
  }

  // --- UPDATED: This now loads reminders too ---
  Future<void> loadData() async {
    try {
      // 1. Get all data
      final data = await Future.wait([
        dbHelper.queryVehicleById(widget.vehicleId),
        dbHelper.queryRemindersForVehicle(widget.vehicleId),
        dbHelper.queryPhotosForParent(widget.vehicleId, 'vehicle'),
        dbHelper.queryVehiclePapersForVehicle(
          widget.vehicleId,
        ), // <-- NEW: Get papers
      ]);
      if (!mounted) return;

      final vehicleData = data[0] as Map<String, dynamic>?;
      final serviceReminders = data[1] as List<Map<String, dynamic>>;
      final photos = data[2] as List<Map<String, dynamic>>;
      final paperReminders = data[3] as List<Map<String, dynamic>>; // <-- NEW

      if (vehicleData == null) {
        throw Exception("Vehicle data not found (ID: ${widget.vehicleId})");
      }

      // --- 2. Combine and Process Reminders ---
      _currentOdo = vehicleData[DatabaseHelper.columnCurrentOdometer] ?? 0;
      final String today = DateTime.now().toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> overdue = [];
      final List<Map<String, dynamic>> comingSoon = [];

      // Add service/manual reminders
      for (var reminder in serviceReminders) {
        bool isDateOverdue = false;
        bool isOdoOverdue = false;
        final String? dueDate = reminder[DatabaseHelper.columnDueDate];
        if (dueDate != null && dueDate.compareTo(today) < 0) {
          isDateOverdue = true;
        }
        final int? dueOdo = reminder[DatabaseHelper.columnDueOdometer];
        if (dueOdo != null && _currentOdo >= dueOdo) {
          isOdoOverdue = true;
        }
        if (isDateOverdue || isOdoOverdue) {
          overdue.add(reminder);
        } else {
          comingSoon.add(reminder);
        }
      }

      // --- NEW: Add paper reminders ---
      for (var paper in paperReminders) {
        final String? expiryDate = paper[DatabaseHelper.columnPaperExpiryDate];
        if (expiryDate != null && expiryDate.isNotEmpty) {
          final paperReminder = {...paper, 'isPaperReminder': true};
          if (expiryDate.compareTo(today) < 0) {
            overdue.add(paperReminder);
          } else {
            comingSoon.add(paperReminder);
          }
        }
      }
      // --- END NEW ---

      setState(() {
        _vehicle = vehicleData;
        _odometerController.text = _currentOdo.toString();
        _vehiclePhotos = List.from(photos);
        _overdueReminders = overdue;
        _comingSoonReminders = comingSoon;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      print("[DEBUG OverviewTab] !!!--- ERROR in _loadData ---!!!");
      print(e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _saveOdometer() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    int newOdometer = int.tryParse(_odometerController.text) ?? 0;

    // 1. Save the new odometer (unchanged)
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

    // --- THIS IS THE FIX ---
    // 2. Get all *pending* reminders
    final allReminders = await dbHelper.queryRemindersForVehicle(
      widget.vehicleId,
    );

    for (var reminder in allReminders) {
      final dueOdometer = reminder[DatabaseHelper.columnDueOdometer];

      // 3. If this reminder is now due...
      if (dueOdometer != null && newOdometer >= dueOdometer) {
        final int reminderId = reminder[DatabaseHelper.columnId];
        final String templateName =
            reminder['template_name'] ??
            reminder[DatabaseHelper.columnNotes] ??
            'Service';
        print("  > Odometer due for '$templateName'! Sending notification.");

        // 4. Send notification
        await NotificationService().showImmediateReminder(
          id: reminderId,
          title: 'Vehicle Service Due',
          body:
              'Your "$templateName" service is due! (Reached $dueOdometer km).',
        );
      }
    }
    // --- END OF FIX ---

    // 6. Reload all data
    loadData();
  }

  // --- NEW: Copied from Reminders Tab ---
  void _showSnoozeDialog(
    Map<String, dynamic> reminder,
    SettingsProvider settings,
  ) {
    final int reminderId = reminder[DatabaseHelper.columnId];
    String? currentDueDate = reminder[DatabaseHelper.columnDueDate];
    int? currentDueOdo = reminder[DatabaseHelper.columnDueOdometer];
    final TextEditingController daysController = TextEditingController(
      text: '7',
    );
    final TextEditingController odoController = TextEditingController(
      text: '100',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Snooze Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Snooze by days (e.g., 7):'),
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            Text('Snooze by ${settings.unitType} (e.g., 100):'),
            TextField(
              controller: odoController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              int? daysToAdd = int.tryParse(daysController.text);
              int? odoToAdd = int.tryParse(odoController.text);
              String? newDueDate = currentDueDate;
              int? newDueOdometer = currentDueOdo;

              if (daysToAdd != null &&
                  daysToAdd > 0 &&
                  currentDueDate != null) {
                DateTime oldDate = DateTime.parse(currentDueDate);
                newDueDate = oldDate
                    .add(Duration(days: daysToAdd))
                    .toIso8601String()
                    .split('T')[0];
              }
              if (odoToAdd != null && odoToAdd > 0 && currentDueOdo != null) {
                newDueOdometer = currentDueOdo + odoToAdd;
              }

              await dbHelper.updateReminder(
                reminderId,
                newDueDate,
                newDueOdometer,
              );

              if (mounted) {
                Navigator.of(ctx).pop();
              }
              loadData(); // Use the main refresh function
            },
            child: const Text('Snooze'),
          ),
        ],
      ),
    );
  }
  // --- END NEW ---

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

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
      padding: const EdgeInsets.all(16.0).copyWith(top: 0),
      child: Column(
        children: [
          _buildPhotoGalleryCard(settings),

          Card(
            elevation: 4,
            margin: const EdgeInsets.only(top: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed, size: 14, color: settings.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'CURRENT ODOMETER',
                        style: TextStyle(
                          fontSize: 12,
                          color: settings.primaryColor,
                        ),
                      ),
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

          // --- REMOVED THE OLD "NEXT DUE" CARD ---

          // --- NEW: ADD THE REMINDER LISTS ---
          const SizedBox(height: 20),

          // --- OVERDUE SECTION ---
          if (_overdueReminders.isNotEmpty) ...[
            _buildSectionHeader('Overdue', Colors.red[700]!),
            ..._overdueReminders.map(
              (r) => _buildReminderTile(r, settings, isOverdue: true),
            ),
          ],

          // --- COMING SOON SECTION ---
          const SizedBox(height: 16),
          _buildSectionHeader('Upcoming', Colors.blue[700]!),
          if (_comingSoonReminders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No upcoming reminders.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._comingSoonReminders.map(
              (r) => _buildReminderTile(r, settings, isOverdue: false),
            ),
          // --- END NEW ---
        ],
      ),
    );
  }

  // (Photo Gallery card is unchanged)
  Widget _buildPhotoGalleryCard(SettingsProvider settings) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_vehiclePhotos.isEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.grey[200],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library,
                        color: Colors.grey[400],
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No photos added yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const Text(
                        'Edit vehicle to add photos.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            CarouselSlider(
              carouselController: _carouselController,
              options: CarouselOptions(
                height: 200.0,
                viewportFraction: 1.0,
                enableInfiniteScroll: true,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentPhotoIndex = index;
                  });
                },
              ),
              items: _vehiclePhotos.map((photo) {
                final photoPath = photo[DatabaseHelper.columnUri];
                return Builder(
                  builder: (BuildContext context) {
                    return GestureDetector(
                      onTap: () {
                        final paths = _vehiclePhotos
                            .map((p) => p[DatabaseHelper.columnUri] as String)
                            .toList();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenPhotoViewer(
                              photoPaths: paths,
                              initialIndex: _currentPhotoIndex,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: FileImage(File(photoPath)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          if (_vehiclePhotos.length > 1)
            Positioned(
              bottom: 10.0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _vehiclePhotos.asMap().entries.map((entry) {
                  return Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 4.0,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(
                        _currentPhotoIndex == entry.key ? 0.9 : 0.4,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (_vehiclePhotos.length > 1)
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () => _carouselController.previousPage(),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onPressed: () => _carouselController.nextPage(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- REMOVED _buildDetailTile ---

  // --- NEW: Copied from Reminders Tab ---
  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 14,
        ),
      ),
    );
  }

  // --- NEW: Copied from Reminders Tab ---
  Widget _buildReminderTile(
    Map<String, dynamic> reminder,
    SettingsProvider settings, {
    bool isOverdue = false,
  }) {
    bool isPaper = reminder['isPaperReminder'] ?? false;
    String title;
    String dueDate;
    String dueOdo;
    IconData icon;
    if (isPaper) {
      // It's a Vehicle Paper
      title = reminder[DatabaseHelper.columnPaperType] ?? 'Paper';
      dueDate = reminder[DatabaseHelper.columnPaperExpiryDate] ?? 'N/A';
      dueOdo = 'N/A'; // Papers don't have odometer
      icon = _getIconForPaperType(title);
    } else {
      dueDate = reminder[DatabaseHelper.columnDueDate] ?? 'N/A';
      dueOdo = reminder[DatabaseHelper.columnDueOdometer]?.toString() ?? 'N/A';
      title =
          reminder['template_name'] ??
          reminder[DatabaseHelper.columnNotes] ??
          'Reminder';
      icon = Icons.notifications_active;
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: isOverdue ? Colors.red : Colors.orange,
              width: 4,
            ),
          ),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: isOverdue ? Colors.red[700] : Colors.orange,
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Date: $dueDate'
            '${isPaper ? '' : '\nOdometer: $dueOdo ${settings.unitType}'}',
          ),
          isThreeLine: false,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.snooze, color: Colors.blue),
                tooltip: 'Snooze Reminder',
                onPressed: () {
                  _showSnoozeDialog(reminder, settings);
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                tooltip: 'Mark as Complete',
                onPressed: () async {
                  int id = reminder[DatabaseHelper.columnId];
                  await dbHelper.deleteReminder(id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reminder marked as complete!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  loadData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForPaperType(String type) {
    switch (type.toLowerCase()) {
      case 'insurance':
        return Icons.shield;
      case 'puc':
        return Icons.cloud_outlined;
      case 'registration':
        return Icons.badge;
      default:
        return Icons.description;
    }
  }
}
