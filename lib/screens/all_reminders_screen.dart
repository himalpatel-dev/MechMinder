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
  final Set<String> _expandedVehicles = {}; // To track expanded groups

  Map<String, List<Map<String, dynamic>>> _groupedReminders = {};

  // Controllers for Manual Reminder Dialog
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
    setState(() => _isLoading = true);
    final serviceReminders = await dbHelper.queryAllRemindersGroupedByVehicle();
    final paperReminders = await dbHelper.queryAllExpiringPapers();

    final List<Map<String, dynamic>> allReminders = [];
    allReminders.addAll(serviceReminders);

    for (var paper in paperReminders) {
      allReminders.add({...paper, 'isPaperReminder': true});
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var reminder in allReminders) {
      final vehicleName = '${reminder[DatabaseHelper.columnModel]}';
      if (grouped[vehicleName] == null) {
        grouped[vehicleName] = [];
      }
      grouped[vehicleName]!.add(reminder);
    }

    // Auto-expand first group if nothing expanded
    if (grouped.isNotEmpty && _expandedVehicles.isEmpty) {
      _expandedVehicles.add(grouped.keys.first);
    }

    setState(() {
      _groupedReminders = grouped;
      _isLoading = false;
    });
  }

  // --- DIALOGS ---
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
    final primaryColor = settings.primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Snooze Reminder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogTextField(
              daysController,
              'Days to Add',
              Icons.calendar_today,
              primaryColor,
              TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildDialogTextField(
              odoController,
              'Odometer (${settings.unitType})',
              Icons.speed,
              primaryColor,
              TextInputType.number,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
              if (mounted) Navigator.of(ctx).pop();
              refreshReminderList();
            },
            child: const Text('Snooze', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void showAddManualReminderDialog(SettingsProvider settings) async {
    final allVehicles = await dbHelper.queryAllVehiclesWithNextReminder();
    if (!mounted) return;

    final primaryColor = settings.primaryColor;
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Add Manual Reminder',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: _manualReminderFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedVehicleId,
                        decoration: _inputDecoration(
                          'Select Vehicle',
                          Icons.directions_car,
                          primaryColor,
                        ),
                        items: allVehicles.map((vehicle) {
                          return DropdownMenuItem<int>(
                            value: vehicle[DatabaseHelper.columnId],
                            child: Text(
                              '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}',
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedVehicleId = val),
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _manualNameController,
                        decoration: _inputDecoration(
                          'Reminder Name',
                          Icons.edit,
                          primaryColor,
                        ),
                        validator: (val) =>
                            (val == null || val.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) {
                            _manualDateController.text = picked
                                .toIso8601String()
                                .split('T')[0];
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _manualDateController,
                            decoration: _inputDecoration(
                              'Due Date (Optional)',
                              Icons.calendar_today,
                              primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _manualOdoController,
                        decoration: _inputDecoration(
                          'Due ${settings.unitType} (Optional)',
                          Icons.speed,
                          primaryColor,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                            content: Text('Set a date or odometer.'),
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

                      if (mounted) Navigator.of(ctx).pop();
                      refreshReminderList();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, Color color) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: color, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      isDense: true,
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    Color color,
    TextInputType type,
  ) {
    return TextField(
      controller: controller,
      keyboardType: type,
      inputFormatters: type == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : [],
      decoration: _inputDecoration(label, icon, color),
    );
  }

  // --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final sortedVehicleNames = _groupedReminders.keys.toList()..sort();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _groupedReminders.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
              itemCount: sortedVehicleNames.length,
              itemBuilder: (context, index) {
                final vehicleName = sortedVehicleNames[index];
                final remindersForVehicle = _groupedReminders[vehicleName]!;
                final isExpanded = _expandedVehicles.contains(vehicleName);

                // Calc Overdue/Upcoming counts
                int overdueCount = 0;
                final String today = DateTime.now().toIso8601String().split(
                  'T',
                )[0];
                final int currentOdo =
                    remindersForVehicle.first[DatabaseHelper
                        .columnCurrentOdometer] ??
                    0;

                for (var r in remindersForVehicle) {
                  bool isOver = false;
                  final String? d =
                      r[DatabaseHelper.columnDueDate] ??
                      r[DatabaseHelper.columnPaperExpiryDate];
                  if (d != null && d.compareTo(today) < 0) isOver = true;
                  final int? o = r[DatabaseHelper.columnDueOdometer];
                  if (o != null && currentOdo >= o) isOver = true;
                  if (isOver) overdueCount++;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Parent Header (Vehicle Group)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedVehicles.remove(vehicleName);
                          } else {
                            _expandedVehicles.add(vehicleName);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black26
                                  : Colors.grey.shade200,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                vehicleName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            if (overdueCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "$overdueCount DUE",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Child Reminders
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: isExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                children: remindersForVehicle.map((reminder) {
                                  // Re-calc overdue for card logic
                                  bool isOverdue = false;
                                  final String? dueDate =
                                      reminder[DatabaseHelper.columnDueDate] ??
                                      reminder[DatabaseHelper
                                          .columnPaperExpiryDate];
                                  if (dueDate != null &&
                                      dueDate.compareTo(today) < 0)
                                    isOverdue = true;
                                  final int? dueOdo =
                                      reminder[DatabaseHelper
                                          .columnDueOdometer];
                                  if (dueOdo != null && currentOdo >= dueOdo)
                                    isOverdue = true;

                                  return _buildReminderCard(
                                    reminder,
                                    settings,
                                    isDark,
                                    primaryColor,
                                    isOverdue,
                                  );
                                }).toList(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
      // REMOVED FLOATING ACTION BUTTON HERE as per request
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "No Reminders",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You are all caught up!",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(
    Map<String, dynamic> reminder,
    SettingsProvider settings,
    bool isDark,
    Color primaryColor,
    bool isOverdue,
  ) {
    bool isPaper = reminder['isPaperReminder'] ?? false;
    String title;
    String dueDateStr = 'N/A';
    String dueOdoStr = 'N/A';
    IconData icon;

    if (isPaper) {
      title = reminder[DatabaseHelper.columnPaperType] ?? 'Paper';
      dueDateStr = reminder[DatabaseHelper.columnPaperExpiryDate] ?? 'N/A';
      icon = _getIconForPaperType(title);
    } else {
      title =
          reminder['template_name'] ??
          reminder[DatabaseHelper.columnNotes] ??
          'Reminder';
      dueDateStr = reminder[DatabaseHelper.columnDueDate] ?? 'N/A';
      dueOdoStr =
          reminder[DatabaseHelper.columnDueOdometer]?.toString() ?? 'N/A';
      icon = isOverdue ? Icons.warning_amber_rounded : Icons.notifications_none;
    }

    final Color statusColor = isOverdue ? Colors.red : primaryColor;
    final Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Build subtitle safely
    String dateSubtitle = 'Due: $dueDateStr';

    bool hasOdo = !isPaper && dueOdoStr != 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isOverdue
              ? Colors.red.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.transparent),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8, // Added a bit more vertical padding for 3-line look
          ),
          dense: true,
          isThreeLine: hasOdo, // Enable 3-line layout if we have 3rd line data
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.grey.shade800,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Keep compact
            children: [
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? Colors.red.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (hasOdo) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '$dueOdoStr ${settings.unitType}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.snooze, size: 20, color: Colors.blue.shade400),
                tooltip: 'Snooze',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showSnoozeDialog(reminder, settings),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.green,
                ),
                tooltip: 'Complete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  int id = reminder[DatabaseHelper.columnId];
                  if (isPaper) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cannot complete Paper reminders here.'),
                      ),
                    );
                  } else {
                    await dbHelper.deleteReminder(id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Marked as complete!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    refreshReminderList();
                  }
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
        return Icons.shield_outlined;
      case 'puc':
        return Icons.cloud_done_outlined;
      case 'registration':
      case 'rc':
        return Icons.featured_play_list_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
