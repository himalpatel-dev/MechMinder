import 'package:flutter/material.dart';
import '../service/database_helper.dart';

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({super.key});

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _vendors = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshVendorList();
  }

  void _refreshVendorList() async {
    final allVendors = await dbHelper.queryAllVendors();
    setState(() {
      _vendors = allVendors;
    });
  }

  void _showAddVendorDialog() {
    // Clear old text
    _nameController.text = '';
    _phoneController.text = '';
    _addressController.text = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Vendor'),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(onPressed: _saveVendor, child: const Text('Save')),
          ],
        );
      },
    );
  }

  void _saveVendor() async {
    Map<String, dynamic> row = {
      DatabaseHelper.columnName: _nameController.text,
      DatabaseHelper.columnPhone: _phoneController.text,
      DatabaseHelper.columnAddress: _addressController.text,
    };

    await dbHelper.insertVendor(row);

    if (mounted) {
      Navigator.of(context).pop(); // Close the dialog
    }
    _refreshVendorList(); // Refresh the list in the background
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
              itemCount: _vendors.length,
              itemBuilder: (context, index) {
                final vendor = _vendors[index];
                return ListTile(
                  title: Text(vendor[DatabaseHelper.columnName]),
                  subtitle: Text(
                    'Phone: ${vendor[DatabaseHelper.columnPhone] ?? 'N/A'}\nAddress: ${vendor[DatabaseHelper.columnAddress] ?? 'N/A'}',
                  ),
                  isThreeLine: true,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVendorDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
