import 'package:flutter/material.dart';
import '../service/database_helper.dart'; // Make sure this path is correct

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({super.key});

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _vendors = [];

  // Controllers for the Add/Edit dialog
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

  // --- THIS FUNCTION IS NOW UPGRADED ---
  // It can now handle both ADDING (vendor == null)
  // and EDITING (vendor != null)
  void _showAddEditVendorDialog({Map<String, dynamic>? vendor}) {
    bool isEditing = vendor != null;

    if (isEditing) {
      // Pre-fill controllers for editing
      _nameController.text = vendor[DatabaseHelper.columnName] ?? '';
      _phoneController.text = vendor[DatabaseHelper.columnPhone] ?? '';
      _addressController.text = vendor[DatabaseHelper.columnAddress] ?? '';
    } else {
      // Clear for adding
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
            // --- ADD DELETE BUTTON (only for editing) ---
            if (isEditing)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the edit dialog
                  _showDeleteConfirmation(vendor[DatabaseHelper.columnId]);
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
                _saveVendor(vendor); // Pass the vendor to save
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

    _refreshVendorList(); // Refresh the list
  }

  // --- NEW FUNCTION: DELETE CONFIRMATION ---
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              await dbHelper.deleteVendor(id);
              Navigator.of(ctx).pop();
              _refreshVendorList(); // Refresh the list
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
      appBar: AppBar(title: const Text('Manage Vendors')),
      body: _vendors.isEmpty
          ? const Center(
              child: Text('No vendors added yet. Tap "+" to add one.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // For the button
              itemCount: _vendors.length,
              itemBuilder: (context, index) {
                final vendor = _vendors[index];

                // --- THIS IS THE NEW REDESIGNED TILE ---
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(
                      Icons.store,
                      color: Colors.blue,
                      size: 36,
                    ),
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
                      // This now opens the "Edit" dialog
                      _showAddEditVendorDialog(vendor: vendor);
                    },
                  ),
                );
                // --- END OF NEW TILE ---
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // This now opens the "Add" dialog
          _showAddEditVendorDialog(vendor: null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
