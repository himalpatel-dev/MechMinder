import 'package:flutter/material.dart';
import '../service/database_helper.dart';

class UpcomingRemindersTab extends StatefulWidget {
  final int vehicleId;
  const UpcomingRemindersTab({super.key, required this.vehicleId});

  @override
  State<UpcomingRemindersTab> createState() => _UpcomingRemindersTabState();
}

class _UpcomingRemindersTabState extends State<UpcomingRemindersTab> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshReminderList();
  }

  Future<void> _refreshReminderList() async {
    final allReminders = await dbHelper.queryRemindersForVehicle(
      widget.vehicleId,
    );
    setState(() {
      _reminders = allReminders;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
          ? const Center(
              child: Text(
                'No reminders found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final reminder = _reminders[index];

                // We need to fetch the template name, but for now
                // we'll just show the due dates.

                String dueDate =
                    reminder[DatabaseHelper.columnDueDate] ?? 'N/A';
                String dueOdo =
                    reminder[DatabaseHelper.columnDueOdometer]?.toString() ??
                    'N/A';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.notifications_active,
                      color: Colors.orange,
                    ),
                    title: Text(
                      // Use the template name, or 'Manual Reminder' if no template
                      reminder['template_name'] ?? 'Manual Reminder',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ), // We'll make this dynamic later
                    subtitle: Text(
                      'Due Date: $dueDate\nDue Odometer: $dueOdo km',
                    ),
                    isThreeLine: true,

                    // --- ADD THIS TRAILING WIDGET ---
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      tooltip: 'Mark as Complete',
                      onPressed: () async {
                        // Get the ID of the reminder
                        int id = reminder[DatabaseHelper.columnId];

                        // Delete it from the database
                        await dbHelper.deleteReminder(id);

                        // Show a confirmation message
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reminder marked as complete!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }

                        // Refresh the list to make it disappear
                        _refreshReminderList();
                      },
                    ),
                    // --- END OF NEW WIDGET ---
                  ),
                );
              },
            ),
      // We can add a FloatingActionButton here later to add a *manual* reminder
    );
  }
}
