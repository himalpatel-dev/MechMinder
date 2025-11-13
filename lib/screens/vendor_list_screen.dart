import 'package:flutter/material.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import 'package:provider/provider.dart'; // --- THIS IS THE FIX ---
import '../service/settings_provider.dart'; // --- THIS IS THE FIX ---

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({super.key});

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _vendors = [];

  // (Controllers are unchanged)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshVendorList();
  }

  Future<void> _refreshVendorList() async {
    final allVendors = await dbHelper.queryAllVendors();
    setState(() {
      _vendors = allVendors;
    });
  }

  // (This function is unchanged)
  void _showAddEditVendorDialog({Map<String, dynamic>? vendor}) {
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

  // (This function is unchanged)
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

    _refreshVendorList();
  }

  // (This function is unchanged)
  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vendor?'),
        content: const Text(
          'Are you sure you want to permanently delete this vendor? This cannot be undone.',
          // style: ... (removed)
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
              await dbHelper.deleteVendor(id);
              Navigator.of(ctx).pop();
              _refreshVendorList();
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
      appBar: AppBar(title: const Text('Manage Vendors')),
      body: _vendors.isEmpty
          ? const Center(
              child: Text('No vendors added yet. Tap "+" to add one.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _vendors.length,
              itemBuilder: (context, index) {
                final vendor = _vendors[index];

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
                      Icons.store,
                      color: settings.primaryColor,
                      size: 36,
                    ),
                    // --- END OF FIX ---
                    title: Text(
                      vendor[DatabaseHelper.columnName],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Phone: ${vendor[DatabaseHelper.columnPhone] ?? 'N/A'}\nAddress: ${vendor[DatabaseHelper.columnAddress] ?? 'N/A'}',
                    ),
                    isThreeLine: true,
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                    onTap: () {
                      _showAddEditVendorDialog(vendor: vendor);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddEditVendorDialog(vendor: null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
