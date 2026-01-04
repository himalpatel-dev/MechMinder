import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/database_helper.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';

class ServiceTemplatesScreen extends StatefulWidget {
  const ServiceTemplatesScreen({super.key});

  @override
  // --- Back to a private State class ---
  State<ServiceTemplatesScreen> createState() => _ServiceTemplatesScreenState();
}

// --- Back to a private State class ---
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

  // --- Back to a private method ---
  Future<void> _refreshTemplateList() async {
    final allTemplates = await dbHelper.queryAllServiceTemplates();
    setState(() {
      _templates = allTemplates;
    });
  }

  // --- Back to a private method ---
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
          title: Text(isEditing ? 'Edit Auto Part' : 'Add New Auto Part'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Auto Part Name'),
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

    _refreshTemplateList();
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Auto Part?'),
        content: const Text(
          'Are you sure you want to permanently delete this Auto Part? This will not affect existing reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.black,
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
    final settings = Provider.of<SettingsProvider>(context);

    // --- ADD Scaffold AND AppBar BACK ---
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Auto Parts')),
      // --- END ADD ---
      body: _templates.isEmpty
          ? const Center(
              child: Text('No Auto Parts found. Tap "+" to add one.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 60),
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
                    leading: Icon(
                      _getIconForCategory(template[DatabaseHelper.columnName]),
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
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                    onTap: () {
                      // --- Call private method ---
                      _showAddEditTemplateDialog(template: template);
                    },
                  ),
                );
              },
            ),
      // --- ADD FloatingActionButton BACK ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddEditTemplateDialog(template: null);
        },
        child: const Icon(Icons.add),
      ),
      // --- END ADD ---
    );
  }

  IconData _getIconForCategory(String? category) {
    if (category == null) return Icons.monetization_on;
    String catLower = category.toLowerCase();
    if (catLower.contains('fuel') ||
        catLower.contains('petrol') ||
        catLower.contains('gas')) {
      return Icons.local_gas_station;
    }

    // 🛡 Insurance
    if (catLower.contains('insurance') || catLower.contains('policy')) {
      return Icons.shield;
    }

    // 🧼 Washing / Cleaning
    if (catLower.contains('wash') ||
        catLower.contains('clean') ||
        catLower.contains('detailing')) {
      return Icons.wash;
    }

    // 🅿 Parking
    if (catLower.contains('parking') || catLower.contains('park')) {
      return Icons.local_parking;
    }

    // 🛞 Tyres
    if (catLower.contains('tire') ||
        catLower.contains('tyre') ||
        catLower.contains('tyres')) {
      return Icons.tire_repair;
    }

    // ⚙ Servicing / Maintenance
    if (catLower.contains('service') ||
        catLower.contains('maintenance') ||
        catLower.contains('checkup') ||
        catLower.contains('inspection')) {
      return Icons.build;
    }

    // 🛢 Oil change
    if (catLower.contains('oil') || catLower.contains('engine oil')) {
      return Icons.oil_barrel;
    }

    // 🧯 Brake pads / brake oil
    if (catLower.contains('brake') ||
        catLower.contains('brakes') ||
        catLower.contains('break')) {
      return Icons.car_repair;
    }

    // 🔋 Battery
    if (catLower.contains('battery') || catLower.contains('accumulator')) {
      return Icons.battery_charging_full;
    }

    // 💨 Air filter / filter replacement
    if (catLower.contains('filter')) {
      return Icons.filter_alt;
    }

    // 💡 Lights / bulbs / indicators
    if (catLower.contains('light') ||
        catLower.contains('bulb') ||
        catLower.contains('indicator')) {
      return Icons.lightbulb;
    }

    // 🚙 Accessories / modification
    if (catLower.contains('accessory') ||
        catLower.contains('modification') ||
        catLower.contains('sticker')) {
      return Icons.car_repair;
    }

    // 🧰 Tools / spare parts
    if (catLower.contains('spare') ||
        catLower.contains('parts') ||
        catLower.contains('tool')) {
      return Icons.handyman;
    }

    // 🚗 General vehicle cost
    if (catLower.contains('vehicle') ||
        catLower.contains('car') ||
        catLower.contains('bike')) {
      return Icons.directions_car;
    }

    // 🧾 Tax / RTO / registration / license
    if (catLower.contains('rto') ||
        catLower.contains('tax') ||
        catLower.contains('registration') ||
        catLower.contains('license')) {
      return Icons.receipt_long;
    }

    // 🧳 Trip / travel / toll / highway
    if (catLower.contains('trip') ||
        catLower.contains('toll') ||
        catLower.contains('highway') ||
        catLower.contains('travel')) {
      return Icons.add_road;
    }

    // 🧯 Emergency / breakdown / towing
    if (catLower.contains('breakdown') ||
        catLower.contains('towing') ||
        catLower.contains('emergency')) {
      return Icons.warning;
    }

    // ⛓ Chain / sprocket (for bikes)
    if (catLower.contains('chain') || catLower.contains('sprocket')) {
      return Icons.settings;
    }

    // 🧊 Coolant
    if (catLower.contains('coolant')) {
      return Icons.ac_unit;
    }

    // 🧍 Driver / labour charge
    if (catLower.contains('driver') || catLower.contains('labour')) {
      return Icons.person;
    }

    // 🏪 Workshop / garage visit
    if (catLower.contains('garage') ||
        catLower.contains('workshop') ||
        catLower.contains('mechanic')) {
      return Icons.garage;
    }
    return Icons.handyman;
  }
}
