import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/database_helper.dart'; // Make sure this path is correct

class ServiceTemplatesScreen extends StatefulWidget {
  const ServiceTemplatesScreen({super.key});

  @override
  State<ServiceTemplatesScreen> createState() => _ServiceTemplatesScreenState();
}

class _ServiceTemplatesScreenState extends State<ServiceTemplatesScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _templates = [];

  // Controllers for the Add/Edit dialog
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshTemplateList();
  }

  Future<void> _refreshTemplateList() async {
    final allTemplates = await dbHelper.queryAllServiceTemplates();
    setState(() {
      _templates = allTemplates;
    });
  }

  // --- THIS FUNCTION IS NOW UPGRADED ---
  // It can now handle both ADDING (template == null)
  // and EDITING (template != null)
  void _showAddEditTemplateDialog({Map<String, dynamic>? template}) {
    bool isEditing = template != null;

    if (isEditing) {
      // Pre-fill controllers for editing
      _nameController.text = template[DatabaseHelper.columnName] ?? '';
      _daysController.text = (template[DatabaseHelper.columnIntervalDays] ?? '')
          .toString();
      _kmController.text = (template[DatabaseHelper.columnIntervalKm] ?? '')
          .toString();
    } else {
      // Clear for adding
      _nameController.text = '';
      _daysController.text = '';
      _kmController.text = '';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Template' : 'Add New Template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Template Name'),
                autofocus: true,
              ),
              TextField(
                controller: _daysController,
                decoration: const InputDecoration(labelText: 'Interval (Days)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: _kmController,
                decoration: const InputDecoration(labelText: 'Interval (km)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
          actions: [
            // --- ADD DELETE BUTTON (only for editing) ---
            if (isEditing)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the edit dialog
                  _showDeleteConfirmation(template[DatabaseHelper.columnId]);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const Spacer(), // Pushes buttons to the right
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveTemplate(template); // Pass the template to save
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // --- THIS FUNCTION IS ALSO UPGRADED ---
  void _saveTemplate(Map<String, dynamic>? template) async {
    bool isEditing = template != null;

    Map<String, dynamic> row = {
      DatabaseHelper.columnName: _nameController.text,
      DatabaseHelper.columnIntervalDays: int.tryParse(_daysController.text),
      DatabaseHelper.columnIntervalKm: int.tryParse(_kmController.text),
    };

    if (isEditing) {
      row[DatabaseHelper.columnId] = template[DatabaseHelper.columnId];
      await dbHelper.updateServiceTemplate(row);
    } else {
      await dbHelper.insertServiceTemplate(row);
    }

    _refreshTemplateList(); // Refresh the list
  }

  // --- NEW FUNCTION: DELETE CONFIRMATION ---
  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template?'),
        content: const Text(
          'Are you sure you want to permanently delete this template? This will not affect existing reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              await dbHelper.deleteServiceTemplate(id);
              Navigator.of(ctx).pop();
              _refreshTemplateList(); // Refresh the list
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Service Templates')),
      body: _templates.isEmpty
          ? const Center(child: Text('No templates found. Tap "+" to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // For the button
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];

                // --- THIS IS THE NEW REDESIGNED TILE ---
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(
                      Icons.list_alt,
                      color: Colors.blue,
                      size: 36,
                    ),
                    title: Text(
                      template[DatabaseHelper.columnName],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Interval: ${template[DatabaseHelper.columnIntervalDays] ?? 'N/A'} days / ${template[DatabaseHelper.columnIntervalKm] ?? 'N/A'} km',
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                    onTap: () {
                      // This now opens the "Edit" dialog
                      _showAddEditTemplateDialog(template: template);
                    },
                  ),
                );
                // --- END OF NEW TILE ---
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // This now opens the "Add" dialog
          _showAddEditTemplateDialog(template: null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
