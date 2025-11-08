import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/database_helper.dart';

class ServiceTemplatesScreen extends StatefulWidget {
  const ServiceTemplatesScreen({super.key});

  @override
  State<ServiceTemplatesScreen> createState() => _ServiceTemplatesScreenState();
}

class _ServiceTemplatesScreenState extends State<ServiceTemplatesScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _templates = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshTemplateList();
  }

  void _refreshTemplateList() async {
    final allTemplates = await dbHelper.queryAllServiceTemplates();
    setState(() {
      _templates = allTemplates;
    });
  }

  void _showAddTemplateDialog() {
    // Clear old text
    _nameController.text = '';
    _daysController.text = '';
    _kmController.text = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Template'),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(onPressed: _saveTemplate, child: const Text('Save')),
          ],
        );
      },
    );
  }

  void _saveTemplate() async {
    Map<String, dynamic> row = {
      DatabaseHelper.columnName: _nameController.text,
      DatabaseHelper.columnIntervalDays: int.tryParse(_daysController.text),
      DatabaseHelper.columnIntervalKm: int.tryParse(_kmController.text),
    };

    await dbHelper.insertServiceTemplate(row);

    if (mounted) {
      Navigator.of(context).pop(); // Close the dialog
    }
    _refreshTemplateList(); // Refresh the list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Service Templates')),
      body: _templates.isEmpty
          ? const Center(child: Text('No templates found. Tap "+" to add one.'))
          : ListView.builder(
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return ListTile(
                  title: Text(template[DatabaseHelper.columnName]),
                  subtitle: Text(
                    'Interval: ${template[DatabaseHelper.columnIntervalDays] ?? 'N/A'} days / ${template[DatabaseHelper.columnIntervalKm] ?? 'N/A'} km',
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTemplateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
