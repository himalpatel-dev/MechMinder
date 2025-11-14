import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/database_helper.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';

class ServiceTemplatesScreen extends StatefulWidget {
  const ServiceTemplatesScreen({super.key});

  @override
  // --- FIX 1: Public State Class ---
  State<ServiceTemplatesScreen> createState() => ServiceTemplatesScreenState();
}

// --- FIX 1: Public State Class ---
class ServiceTemplatesScreenState extends State<ServiceTemplatesScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _templates = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    refreshTemplateList(); // Use public name
  }

  // --- FIX 2: Public Method (No underscore) ---
  Future<void> refreshTemplateList() async {
    final allTemplates = await dbHelper.queryAllServiceTemplates();
    setState(() {
      _templates = allTemplates;
    });
  }

  // --- FIX 2: Public Method (No underscore) ---
  void showAddEditTemplateDialog({Map<String, dynamic>? template}) {
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

    refreshTemplateList(); // Use public name
  }

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await dbHelper.deleteServiceTemplate(id);
              Navigator.of(ctx).pop();
              refreshTemplateList(); // Use public name
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return _templates.isEmpty
        ? const Center(child: Text('No templates found. Tap "+" to add one.'))
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _templates.length,
            itemBuilder: (context, index) {
              final template = _templates[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                child: ListTile(
                  leading: Icon(
                    Icons.list_alt,
                    color: settings.primaryColor,
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
                    'Interval: ${template[DatabaseHelper.columnIntervalDays] ?? 'N/A'} days / ${template[DatabaseHelper.columnIntervalKm] ?? 'N/A'} ${settings.unitType}',
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {
                    // --- FIX 3: Call the public method ---
                    showAddEditTemplateDialog(template: template);
                  },
                ),
              );
            },
          );
  }
}
