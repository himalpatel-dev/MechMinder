import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import 'package:provider/provider.dart'; // --- THIS IS THE FIX ---
import '../service/settings_provider.dart'; // --- THIS IS THE FIX ---

class ServiceTemplatesScreen extends StatefulWidget {
  const ServiceTemplatesScreen({super.key});

  @override
  State<ServiceTemplatesScreen> createState() => _ServiceTemplatesScreenState();
}

class _ServiceTemplatesScreenState extends State<ServiceTemplatesScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _templates = [];

  // (Controllers are unchanged)
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

  // (This function is unchanged)
  void _showAddEditTemplateDialog({Map<String, dynamic>? template}) {
    bool isEditing = template != null;

    if (isEditing) {
      _nameController.text = template[DatabaseHelper.columnName] ?? '';
      _daysController.text = (template[DatabaseHelper.columnIntervalDays] ?? '')
          .toString();
      _kmController.text = (template[DatabaseHelper.columnIntervalKm] ?? '')
          .toString();
    } else {
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
            if (isEditing)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmation(template[DatabaseHelper.columnId]);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveTemplate(template);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // (This function is unchanged)
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

    _refreshTemplateList();
  }

  // (This function is unchanged)
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
              backgroundColor: Colors.red,
              // foregroundColor: ... (removed)
            ),
            onPressed: () async {
              await dbHelper.deleteServiceTemplate(id);
              Navigator.of(ctx).pop();
              _refreshTemplateList();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- THIS IS THE FIX ---
    // Get the settings provider
    final settings = Provider.of<SettingsProvider>(context);
    // --- END OF FIX ---

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Service Templates')),
      body: _templates.isEmpty
          ? const Center(child: Text('No templates found. Tap "+" to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  elevation: 2,
                  child: ListTile(
                    // --- THIS IS THE FIX ---
                    // Use the dynamic color from settings
                    leading: Icon(
                      Icons.list_alt,
                      color: settings.primaryColor,
                      size: 36,
                    ),
                    // --- END OF FIX ---
                    title: Text(
                      template[DatabaseHelper.columnName],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Interval: ${template[DatabaseHelper.columnIntervalDays] ?? 'N/A'} days / ${template[DatabaseHelper.columnIntervalKm] ?? 'N/A'} ${settings.unitType}',
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                    onTap: () {
                      _showAddEditTemplateDialog(template: template);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddEditTemplateDialog(template: null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
