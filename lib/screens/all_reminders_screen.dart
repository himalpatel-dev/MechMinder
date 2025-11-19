import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart';
import '../service/settings_provider.dart';

class AllRemindersScreen extends StatefulWidget {
  const AllRemindersScreen({super.key});

  @override
  State<AllRemindersScreen> createState() => AllRemindersScreenState();
}

class AllRemindersScreenState extends State<AllRemindersScreen> {
  final dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  final Set<String> _expandedVehicles = {};

  Map<String, List<Map<String, dynamic>>> _groupedReminders = {};
  final _manualReminderFormKey = GlobalKey<FormState>();

  final TextEditingController _manualNameController = TextEditingController();
  final TextEditingController _manualDateController = TextEditingController();
  final TextEditingController _manualOdoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    refreshReminderList();
  }

  @override
  void dispose() {
    _manualNameController.dispose();
    _manualDateController.dispose();
    _manualOdoController.dispose();
    super.dispose();
  }

  Future<void> refreshReminderList() async {
    // 1. Get all service/manual reminders
    final serviceReminders = await dbHelper.queryAllRemindersGroupedByVehicle();

    // 2. Get all paper reminders
    final paperReminders = await dbHelper.queryAllExpiringPapers();

    // 3. Create a new, combined list
    final List<Map<String, dynamic>> allReminders = [];

    // Add service reminders
    allReminders.addAll(serviceReminders);

    // Add paper reminders (and mark them so we know how to build the card)
    for (var paper in paperReminders) {
      allReminders.add({
        ...paper, // Add all data from the paper
        'isPaperReminder': true, // This is our new flag
      });
    }

    // 4. Group the combined list by vehicle
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var reminder in allReminders) {
      final vehicleName = '${reminder[DatabaseHelper.columnModel]}';
      if (grouped[vehicleName] == null) {
        grouped[vehicleName] = [];
      }
      grouped[vehicleName]!.add(reminder);
    }

    if (grouped.isNotEmpty && _expandedVehicles.isEmpty) {
      _expandedVehicles.add(grouped.keys.first);
    }

    setState(() {
      _groupedReminders = grouped;
      _isLoading = false;
    });
  }

  void _showSnoozeDialog(
    Map<String, dynamic> reminder,
    SettingsProvider settings,
  ) {
    // (This function is unchanged)
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
              refreshReminderList();
            },
            child: const Text('Snooze'),
          ),
        ],
      ),
    );
  }

  // (This "Add Manual Reminder" function is unchanged)
  void showAddManualReminderDialog(SettingsProvider settings) async {
    final allVehicles = await dbHelper.queryAllVehiclesWithNextReminder();
    if (!mounted) return;

    _manualNameController.clear();
    _manualDateController.clear();
    _manualOdoController.clear();

    int? selectedVehicleId;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Manual Reminder'),
              content: Form(
                key: _manualReminderFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedVehicleId,
                      hint: const Text('Select Vehicle'),
                      decoration: const InputDecoration(labelText: 'Vehicle'),
                      autofocus: true,
                      items: allVehicles.map((vehicle) {
                        return DropdownMenuItem<int>(
                          value: vehicle[DatabaseHelper.columnId],
                          child: Text(
                            '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}',
                          ),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        setDialogState(() {
                          selectedVehicleId = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a vehicle' : null,
                    ),
                    TextFormField(
                      controller: _manualNameController,
                      decoration: const InputDecoration(
                        labelText: 'Reminder Name (e.g., Wash Car)',
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter a name'
                          : null,
                    ),
                    GestureDetector(
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          _manualDateController.text = pickedDate
                              .toIso8601String()
                              .split('T')[0];
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _manualDateController,
                          decoration: const InputDecoration(
                            labelText: 'Due Date (Optional)',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _manualOdoController,
                      decoration: InputDecoration(
                        labelText: 'Due Odometer (Optional)',
                        suffixText: settings.unitType,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_manualReminderFormKey.currentState!.validate()) {
                      final String name = _manualNameController.text;
                      final String? date = _manualDateController.text.isNotEmpty
                          ? _manualDateController.text
                          : null;
                      final int? odo = int.tryParse(_manualOdoController.text);

                      if (date == null && odo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please set a due date or odometer.'),
                          ),
                        );
                        return;
                      }

                      await dbHelper.insertReminder({
                        DatabaseHelper.columnVehicleId: selectedVehicleId,
                        DatabaseHelper.columnTemplateId: null,
                        DatabaseHelper.columnDueDate: date,
                        DatabaseHelper.columnDueOdometer: odo,
                        DatabaseHelper.columnNotes: name,
                      });

                      if (mounted) {
                        Navigator.of(ctx).pop();
                      }
                      refreshReminderList();
                    }
                  },
                  child: const Text('Save Reminder'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- THIS IS THE UPDATED BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final sortedVehicleNames = _groupedReminders.keys.toList()..sort();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedReminders.isEmpty
          ? const Center(
              child: Text(
                'No reminders found for any vehicle.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0).copyWith(bottom: 80),
              itemCount: sortedVehicleNames.length,
              itemBuilder: (context, index) {
                final vehicleName = sortedVehicleNames[index];
                final remindersForVehicle = _groupedReminders[vehicleName]!;

                final int currentOdo =
                    remindersForVehicle.first[DatabaseHelper
                        .columnCurrentOdometer] ??
                    0;
                int overdueCount = 0;
                int upcomingCount = 0;
                final String today = DateTime.now().toIso8601String().split(
                  'T',
                )[0];

                for (var reminder in remindersForVehicle) {
                  bool isDateOverdue = false;
                  bool isOdoOverdue = false;
                  final String? dueDate =
                      reminder[DatabaseHelper.columnDueDate] ??
                      reminder[DatabaseHelper.columnPaperExpiryDate];
                  if (dueDate != null && dueDate.compareTo(today) < 0) {
                    isDateOverdue = true;
                  }
                  final int? dueOdo =
                      reminder[DatabaseHelper.columnDueOdometer];
                  if (dueOdo != null && currentOdo >= dueOdo) {
                    isOdoOverdue = true;
                  }
                  if (isDateOverdue || isOdoOverdue) {
                    overdueCount++;
                  } else {
                    upcomingCount++;
                  }
                }

                // --- THIS IS THE FIX ---
                // We use a Container to create the border and shadow,
                // and a Material widget inside for the ripple effect.
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),

                  clipBehavior:
                      Clip.antiAlias, // Clips the ExpansionTile's corners
                  decoration: BoxDecoration(
                    color: Theme.of(context).highlightColor,
                    borderRadius: BorderRadius.circular(12),
                    // border: Border(
                    //   left: BorderSide(
                    //     color: settings.primaryColor, // Your theme color
                    //     width: 5, // The border width
                    //   ),
                    // ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),

                    title: _buildVehicleHeader(
                      vehicleName,
                      overdueCount,
                      upcomingCount,
                    ),
                    tilePadding: const EdgeInsets.only(
                      left: 16.0,
                      right: 8.0,
                    ), // Adjust padding
                    initiallyExpanded: false,
                    // The children (reminders)
                    children: remindersForVehicle.map((reminder) {
                      bool isOverdue = false;
                      final String? dueDate =
                          reminder[DatabaseHelper.columnDueDate] ??
                          reminder[DatabaseHelper.columnPaperExpiryDate];
                      if (dueDate != null && dueDate.compareTo(today) < 0) {
                        isOverdue = true;
                      }
                      final int? dueOdo =
                          reminder[DatabaseHelper.columnDueOdometer];
                      if (dueOdo != null && currentOdo >= dueOdo) {
                        isOverdue = true;
                      }
                      return _buildReminderCard(
                        reminder,
                        settings,
                        isOverdue: isOverdue,
                      );
                    }).toList(),
                  ),
                );
                // --- END OF FIX ---
              },
            ),
    );
  }

  // (This helper is unchanged)
  Widget _buildVehicleHeader(
    String vehicleName,
    int overdueCount,
    int upcomingCount,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // --- THIS IS THE FIX ---
        // 1. Wrap the Text in an Expanded widget.
        // This makes it take all available space on the left.
        Expanded(
          child: Text(
            vehicleName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis, // This will add "..."
            maxLines: 1, // Ensure it's only one line
          ),
        ),
        // --- END OF FIX ---

        // 2. Add a small space between the text and the chips
        const SizedBox(width: 8),

        // 3. This Row of chips will now be pushed to the right.
        Row(
          mainAxisSize: MainAxisSize.min, // Takes only the space it needs
          children: [
            if (overdueCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$overdueCount OVERDUE",
                  style: TextStyle(
                    color: Colors.red[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

            if (overdueCount > 0 && upcomingCount > 0) const SizedBox(width: 6),

            if (upcomingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$upcomingCount Upcoming",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- (Helper for the Reminder Card - UNCHANGED) ---
  Widget _buildReminderCard(
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
      icon = Icons.warning_amber_rounded;
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 10),
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
                  refreshReminderList();
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
