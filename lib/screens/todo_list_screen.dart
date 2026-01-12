import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => TodoListScreenState();
}

class TodoListScreenState extends State<TodoListScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _todos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshTodoList();
  }

  void refreshTodoList() async {
    setState(() {
      _isLoading = true;
    });
    final todos = await dbHelper.queryAllPendingTodos();
    setState(() {
      _todos = todos;
      _isLoading = false;
    });
  }

  void showAddTodoDialog() async {
    // Get all vehicles for dropdown
    final vehicles = await dbHelper.queryAllRows(DatabaseHelper.tableVehicles);

    if (!mounted) return;

    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a vehicle first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int? selectedVehicleId = vehicles.first[DatabaseHelper.columnId];
    final partNameController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final primaryColor = settings.primaryColor;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              backgroundColor: Theme.of(context).cardColor,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9 > 400
                    ? 400
                    : MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add Todo Item',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Vehicle Dropdown
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<int>(
                                value: selectedVehicleId,
                                decoration: InputDecoration(
                                  labelText: 'Vehicle',
                                  prefixIcon: Icon(
                                    Icons.directions_car,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  isDense: true,
                                ),
                                items: vehicles.map((vehicle) {
                                  return DropdownMenuItem<int>(
                                    value: vehicle[DatabaseHelper.columnId],
                                    child: Text(
                                      '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedVehicleId = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Part Name
                            TextField(
                              controller: partNameController,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Part Name',
                                hintText: 'e.g., Brake Pads, Oil Filter',
                                prefixIcon: Icon(
                                  Icons.build_circle_outlined,
                                  color: primaryColor,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Notes
                            TextField(
                              controller: notesController,
                              decoration: InputDecoration(
                                labelText: 'Notes (Optional)',
                                hintText: 'Additional details...',
                                prefixIcon: Icon(
                                  Icons.notes,
                                  color: primaryColor,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                isDense: true,
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add parts that need service or replacement.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (partNameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a part name'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            await dbHelper.insertTodoItem({
                              DatabaseHelper.columnVehicleId: selectedVehicleId,
                              DatabaseHelper.columnPartName: partNameController
                                  .text
                                  .trim(),
                              DatabaseHelper.columnNotes: notesController.text
                                  .trim(),
                              DatabaseHelper.columnStatus: 'pending',
                            });

                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            refreshTodoList();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Todo item added successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _markAsCompleted(int id) async {
    await dbHelper.updateTodoStatus(id, 'completed');
    refreshTodoList();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todo marked as completed!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _deleteTodo(int id) async {
    await dbHelper.deleteTodoItem(id);
    refreshTodoList();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todo deleted!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void showCompletedTodosDialog() async {
    final completedTodos = await dbHelper.queryAllCompletedTodos();

    if (!mounted) return;

    if (completedTodos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed todos yet!'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Theme.of(context).cardColor,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95 > 500
                ? 500
                : MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.history,
                            color: Colors.green,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Completed Todos',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${completedTodos.length} ${completedTodos.length == 1 ? 'item' : 'items'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Divider
                Divider(color: Colors.grey.shade300, height: 1),
                const SizedBox(height: 16),

                // Content - List of completed todos
                Expanded(
                  child: ListView.separated(
                    itemCount: completedTodos.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final todo = completedTodos[index];
                      final vehicleName =
                          '${todo[DatabaseHelper.columnMake] ?? 'Unknown'} ${todo[DatabaseHelper.columnModel] ?? ''}';
                      final regNo = todo[DatabaseHelper.columnRegNo] ?? '';
                      final partName = todo[DatabaseHelper.columnPartName];
                      final notes = todo[DatabaseHelper.columnNotes] ?? '';
                      final updatedAt = todo[DatabaseHelper.columnUpdatedAt];

                      // Format the completion date
                      String completionDate = 'Completed';
                      String completionTime = '';
                      if (updatedAt != null && updatedAt.isNotEmpty) {
                        try {
                          final dateTime = DateTime.parse(updatedAt);
                          completionDate =
                              '${dateTime.day}/${dateTime.month}/${dateTime.year}';
                          completionTime =
                              '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                        } catch (e) {
                          completionDate = 'Completed';
                        }
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Content (removed the icon avatar)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Part Name
                                    Text(
                                      partName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // Vehicle Info
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.directions_car,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '$vehicleName${regNo.isNotEmpty ? ' • $regNo' : ''}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                            // Removed overflow: TextOverflow.ellipsis
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Notes
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.notes,
                                            size: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              notes,
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              // Removed maxLines and overflow to show full text
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                    // Completion Date & Time
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 12,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            completionTime.isNotEmpty
                                                ? '$completionDate at $completionTime'
                                                : completionDate,
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _todos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending todos',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to add a service reminder',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _todos.length,
              itemBuilder: (context, index) {
                final todo = _todos[index];
                final vehicleName =
                    '${todo[DatabaseHelper.columnMake]} ${todo[DatabaseHelper.columnModel]}';
                final regNo = todo[DatabaseHelper.columnRegNo] ?? '';
                final partName = todo[DatabaseHelper.columnPartName];
                final notes = todo[DatabaseHelper.columnNotes] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: settings.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.build, color: settings.primaryColor),
                    ),
                    title: Text(
                      partName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '$vehicleName${regNo.isNotEmpty ? ' • $regNo' : ''}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            notes,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          tooltip: 'Mark as completed',
                          onPressed: () {
                            _markAsCompleted(todo[DatabaseHelper.columnId]);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red,
                          tooltip: 'Delete',
                          onPressed: () {
                            _deleteTodo(todo[DatabaseHelper.columnId]);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
