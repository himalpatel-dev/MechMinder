import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct

class UpcomingRemindersTab extends StatefulWidget {
  final int vehicleId;
  const UpcomingRemindersTab({super.key, required this.vehicleId});

  @override
  State<UpcomingRemindersTab> createState() => _UpcomingRemindersTabState();
}

class _UpcomingRemindersTabState extends State<UpcomingRemindersTab> {
  final dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;

  List<Map<String, dynamic>> _overdueReminders = [];
  List<Map<String, dynamic>> _comingSoonReminders = [];

  // --- NEW: Controllers for the manual add dialog ---
  final TextEditingController _manualNameController = TextEditingController();
  final TextEditingController _manualDateController = TextEditingController();
  final TextEditingController _manualOdoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshReminderList();
  }

  Future<void> _refreshReminderList() async {
    final allReminders = await dbHelper.queryRemindersForVehicle(
      widget.vehicleId,
    );

    final List<Map<String, dynamic>> overdue = [];
    final List<Map<String, dynamic>> comingSoon = [];
    final String today = DateTime.now().toIso8601String().split('T')[0];

    for (var reminder in allReminders) {
      final String? dueDate = reminder[DatabaseHelper.columnDueDate];
      // Check for date-based reminders
      if (dueDate != null && dueDate.compareTo(today) < 0) {
        overdue.add(reminder);
      } else {
        // All others (future date or odo-only) are "coming soon"
        comingSoon.add(reminder);
      }
    }

    setState(() {
      _overdueReminders = overdue;
      _comingSoonReminders = comingSoon;
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
              _refreshReminderList();
            },
            child: const Text('Snooze'),
          ),
        ],
      ),
    );
  }

  // --- NEW: FUNCTION TO ADD A MANUAL REMINDER ---
  void _showAddManualReminderDialog(SettingsProvider settings) {
    // Clear old text
    _manualNameController.clear();
    _manualDateController.clear();
    _manualOdoController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Manual Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _manualNameController,
              decoration: const InputDecoration(
                labelText: 'Reminder Name (e.g., Wash Car)',
              ),
              autofocus: true,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final String name = _manualNameController.text;
              final String? date = _manualDateController.text.isNotEmpty
                  ? _manualDateController.text
                  : null;
              final int? odo = int.tryParse(_manualOdoController.text);

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a name for the reminder.'),
                  ),
                );
                return;
              }
              if (date == null && odo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please set a due date or odometer.'),
                  ),
                );
                return;
              }

              // Save to DB (templateId is null)
              await dbHelper.insertReminder({
                DatabaseHelper.columnVehicleId: widget.vehicleId,
                DatabaseHelper.columnTemplateId: null,
                DatabaseHelper.columnDueDate: date,
                DatabaseHelper.columnDueOdometer: odo,
                DatabaseHelper.columnNotes:
                    name, // We use the NOTES column for the name
              });

              if (mounted) {
                Navigator.of(ctx).pop(); // Close the dialog
              }
              _refreshReminderList(); // Refresh the list
            },
            child: const Text('Save Reminder'),
          ),
        ],
      ),
    );
  }
  // --- END OF NEW FUNCTION ---

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_overdueReminders.isEmpty && _comingSoonReminders.isEmpty)
          ? const Center(
              child: Text(
                'No reminders found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView(
              children: [
                // --- OVERDUE SECTION ---
                if (_overdueReminders.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Overdue (${_overdueReminders.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                  ListView.builder(
                    itemCount: _overdueReminders.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final reminder = _overdueReminders[index];
                      return _buildReminderTile(
                        reminder,
                        settings,
                        isOverdue: true,
                      );
                    },
                  ),
                  const Divider(height: 20),
                ],

                // --- COMING SOON SECTION ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Coming Soon (${_comingSoonReminders.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                _comingSoonReminders.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          'No upcoming reminders.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _comingSoonReminders.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final reminder = _comingSoonReminders[index];
                          return _buildReminderTile(
                            reminder,
                            settings,
                            isOverdue: false,
                          );
                        },
                      ),
              ],
            ),

      // --- NEW: FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddManualReminderDialog(settings);
        },
        child: const Icon(Icons.add),
      ),
      // --- END OF NEW BUTTON ---
    );
  }

  // --- UPDATED: HELPER WIDGET ---
  Widget _buildReminderTile(
    Map<String, dynamic> reminder,
    SettingsProvider settings, {
    bool isOverdue = false,
  }) {
    String dueDate = reminder[DatabaseHelper.columnDueDate] ?? 'N/A';
    String dueOdo =
        reminder[DatabaseHelper.columnDueOdometer]?.toString() ?? 'N/A';

    // --- FIX: Use template_name first, then fall back to notes ---
    String title =
        reminder['template_name'] ??
        reminder[DatabaseHelper.columnNotes] ??
        'Reminder';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.notifications_active,
          color: isOverdue ? Colors.red[700] : Colors.orange,
        ),
        title: Text(
          title, // Use the new title
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Due Date: $dueDate\nDue Odometer: $dueOdo ${settings.unitType}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Snooze" Button
            IconButton(
              icon: const Icon(Icons.snooze, color: Colors.blue),
              tooltip: 'Snooze Reminder',
              onPressed: () {
                _showSnoozeDialog(reminder, settings);
              },
            ),
            // "Complete" Button
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
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
                _refreshReminderList();
              },
            ),
          ],
        ),
      ),
    );
  }
}
