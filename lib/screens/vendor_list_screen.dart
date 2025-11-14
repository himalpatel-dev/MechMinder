import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';

class VendorListScreen extends StatefulWidget {
  // We accept a key
  const VendorListScreen({super.key});

  @override
  // --- FIX 1: Public State Class ---
  State<VendorListScreen> createState() => VendorListScreenState();
}

// --- FIX 1: Public State Class ---
class VendorListScreenState extends State<VendorListScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _vendors = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    refreshVendorList(); // Use public name
  }

  // --- FIX 2: Public Method (No underscore) ---
  Future<void> refreshVendorList() async {
    final allVendors = await dbHelper.queryAllVendors();
    setState(() {
      _vendors = allVendors;
    });
  }

  // --- FIX 2: Public Method (No underscore) ---
  void showAddEditVendorDialog({Map<String, dynamic>? vendor}) {
    bool isEditing = vendor != null;

    if (isEditing) {
      _nameController.text = vendor[DatabaseHelper.columnName] ?? '';
      _phoneController.text = vendor[DatabaseHelper.columnPhone] ?? '';
      _addressController.text = vendor[DatabaseHelper.columnAddress] ?? '';
    } else {
      _nameController.text = '';
      _phoneController.text = '';
      _addressController.text = '';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Vendor' : 'Add New Vendor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Vendor Name'),
                autofocus: true,
              ),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmation(vendor[DatabaseHelper.columnId]);
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
                _saveVendor(vendor);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _saveVendor(Map<String, dynamic>? vendor) async {
    bool isEditing = vendor != null;
    Map<String, dynamic> row = {
      DatabaseHelper.columnName: _nameController.text,
      DatabaseHelper.columnPhone: _phoneController.text,
      DatabaseHelper.columnAddress: _addressController.text,
    };

    if (isEditing) {
      row[DatabaseHelper.columnId] = vendor[DatabaseHelper.columnId];
      await dbHelper.updateVendor(row);
    } else {
      await dbHelper.insertVendor(row);
    }

    refreshVendorList(); // Use public name
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vendor?'),
        content: const Text(
          'Are you sure you want to permanently delete this vendor? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await dbHelper.deleteVendor(id);
              Navigator.of(ctx).pop();
              refreshVendorList(); // Use public name
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

    return _vendors.isEmpty
        ? const Center(child: Text('No vendors added yet. Tap "+" to add one.'))
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _vendors.length,
            itemBuilder: (context, index) {
              final vendor = _vendors[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    // --- FIX 3: Call the public method ---
                    showAddEditVendorDialog(vendor: vendor);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.store,
                          color: settings.primaryColor,
                          size: 30,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vendor[DatabaseHelper.columnName],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildIconRow(
                                Icons.phone,
                                vendor[DatabaseHelper.columnPhone] ?? 'N/A',
                              ),
                              const SizedBox(height: 2),
                              _buildIconRow(
                                Icons.location_on,
                                vendor[DatabaseHelper.columnAddress] ?? 'N/A',
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildIconRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
