import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/database_helper.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';
import '../widgets/common_popup.dart';

class ServiceTemplatesScreen extends StatefulWidget {
  const ServiceTemplatesScreen({super.key});

  @override
  State<ServiceTemplatesScreen> createState() => _ServiceTemplatesScreenState();
}

class _ServiceTemplatesScreenState extends State<ServiceTemplatesScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshTemplateList();
  }

  Future<void> _refreshTemplateList() async {
    setState(() => _isLoading = true);
    final allTemplates = await dbHelper.queryAllServiceTemplates();
    setState(() {
      _templates = allTemplates;
      _isLoading = false;
    });
  }

  // --- DIALOGS ---
  void _showAddEditTemplateDialog({Map<String, dynamic>? template}) {
    bool isEditing = template != null;

    if (isEditing) {
      _nameController.text = template[DatabaseHelper.columnName] ?? '';
      _daysController.text = (template[DatabaseHelper.columnIntervalDays] ?? '')
          .toString();
      _kmController.text = (template[DatabaseHelper.columnIntervalKm] ?? '')
          .toString();
    } else {
      _nameController.clear();
      _daysController.clear();
      _kmController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        final primaryColor = Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).primaryColor;
        return CommonPopup(
          title: isEditing ? 'Edit Auto Part' : 'Add New Auto Part',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                _nameController,
                "Auto Part Name",
                Icons.build_circle_outlined,
                primaryColor,
                true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _daysController,
                "Days",
                Icons.calendar_today,
                primaryColor,
                false,
                TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _kmController,
                "Interval (km)",
                Icons.speed,
                primaryColor,
                false,
                TextInputType.number,
              ),
              const SizedBox(height: 8),
              Text(
                "Set default intervals for this part.",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          actions: [
            if (isEditing) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmation(template[DatabaseHelper.columnId]);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Delete'),
              ),
              const Spacer(),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                _saveTemplate(template);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    Color color,
    bool autofocus, [
    TextInputType? type,
  ]) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: type,
      inputFormatters: type == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : [],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }

  void _saveTemplate(Map<String, dynamic>? template) async {
    bool isEditing = template != null;

    Map<String, dynamic> row = {
      DatabaseHelper.columnName: _nameController.text.trim(),
      DatabaseHelper.columnIntervalDays: int.tryParse(_daysController.text),
      DatabaseHelper.columnIntervalKm: int.tryParse(_kmController.text),
    };

    if (row[DatabaseHelper.columnName] == null ||
        row[DatabaseHelper.columnName].isEmpty) {
      return;
    }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Auto Part?'),
        content: const Text(
          'Are you sure you want to permanently delete this Auto Part?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

  // --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Manage Auto Parts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey.shade900,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.grey.shade900,
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _templates.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _templates.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final template = _templates[index];
                return _buildTemplateCard(
                  template,
                  isDark,
                  primaryColor,
                  settings.unitType,
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditTemplateDialog(template: null),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Auto Part",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.build_circle_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "No Auto Parts Found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Define standard parts and service intervals.",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(
    Map<String, dynamic> template,
    bool isDark,
    Color primaryColor,
    String unit,
  ) {
    final name = template[DatabaseHelper.columnName] ?? 'Unknown Part';
    final days = template[DatabaseHelper.columnIntervalDays];
    final km = template[DatabaseHelper.columnIntervalKm];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAddEditTemplateDialog(template: template),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForCategory(name),
                    color: primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (days != null && days > 0) ...[
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$days Days",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (km != null && km > 0) ...[
                            Icon(
                              Icons.speed,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$km $unit",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          if ((days == null || days == 0) &&
                              (km == null || km == 0))
                            Text(
                              "No default interval",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Icon
                Icon(
                  Icons.edit_outlined,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForCategory(String? category) {
    if (category == null) return Icons.build;
    String catLower = category.toLowerCase();

    // Fuel & Engine
    if (catLower.contains('fuel') ||
        catLower.contains('gas') ||
        catLower.contains('petrol')) {
      return Icons.local_gas_station;
    }
    if (catLower.contains('oil') || catLower.contains('fluid')) {
      return Icons.oil_barrel;
    }
    if (catLower.contains('coolant')) return Icons.ac_unit;
    if (catLower.contains('battery')) return Icons.battery_charging_full;

    // Externals
    if (catLower.contains('tire') ||
        catLower.contains('tyre') ||
        catLower.contains('wheel')) {
      return Icons.tire_repair;
    }
    if (catLower.contains('light') ||
        catLower.contains('bulb') ||
        catLower.contains('lamp')) {
      return Icons.lightbulb;
    }
    if (catLower.contains('wash') || catLower.contains('clean')) {
      return Icons.wash;
    }

    // Mechanical
    if (catLower.contains('brake') ||
        catLower.contains('pad') ||
        catLower.contains('disk')) {
      return Icons.car_repair;
    }
    if (catLower.contains('filter')) return Icons.filter_alt;
    if (catLower.contains('chain') || catLower.contains('belt')) {
      return Icons.settings;
    }
    if (catLower.contains('insurance') || catLower.contains('policy')) {
      return Icons.shield;
    }

    return Icons.build_circle_outlined;
  }
}
