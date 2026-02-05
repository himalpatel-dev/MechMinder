import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/database_helper.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';
import '../widgets/common_popup.dart';

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({super.key});

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshVendorList();
  }

  Future<void> _refreshVendorList() async {
    setState(() => _isLoading = true);
    final allVendors = await dbHelper.queryAllVendors();
    setState(() {
      _vendors = allVendors;
      _isLoading = false;
    });
  }

  // --- DIALOG LOGIC ---
  void _showAddEditVendorDialog({Map<String, dynamic>? vendor}) {
    bool isEditing = vendor != null;

    if (isEditing) {
      _nameController.text = vendor[DatabaseHelper.columnName] ?? '';
      _phoneController.text = vendor[DatabaseHelper.columnPhone] ?? '';
      _addressController.text = vendor[DatabaseHelper.columnAddress] ?? '';
    } else {
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        final primaryColor = Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).primaryColor;
        return CommonPopup(
          title: isEditing ? 'Edit Workshop' : 'Add New Workshop',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                _nameController,
                "Workshop Name",
                Icons.store,
                primaryColor,
                true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _phoneController,
                "Phone",
                Icons.phone,
                primaryColor,
                false,
                TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _addressController,
                "Address",
                Icons.location_on,
                primaryColor,
                false,
              ),
            ],
          ),
          actions: [
            if (isEditing) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmation(
                    vendor[DatabaseHelper.columnId],
                    primaryColor,
                  );
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
                _saveVendor(vendor);
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

  void _saveVendor(Map<String, dynamic>? vendor) async {
    bool isEditing = vendor != null;
    Map<String, dynamic> row = {
      DatabaseHelper.columnName: _nameController.text.trim(),
      DatabaseHelper.columnPhone: _phoneController.text.trim(),
      DatabaseHelper.columnAddress: _addressController.text.trim(),
    };

    if (row[DatabaseHelper.columnName] == null ||
        row[DatabaseHelper.columnName].isEmpty) {
      return; // Basic validation
    }

    if (isEditing) {
      row[DatabaseHelper.columnId] = vendor[DatabaseHelper.columnId];
      await dbHelper.updateVendor(row);
    } else {
      await dbHelper.insertVendor(row);
    }

    _refreshVendorList();
  }

  void _showDeleteConfirmation(int id, Color primaryColor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Workshop?'),
        content: const Text(
          'Are you sure you want to permanently delete this Workshop?',
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

  // --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(
          'Manage Workshops',
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
          : _vendors.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _vendors.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vendor = _vendors[index];
                return _buildVendorCard(vendor, isDark, primaryColor);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditVendorDialog(vendor: null),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Workshop",
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
          Icon(Icons.store_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "No Workshops Found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add your trusted mechanics and service centers.",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(
    Map<String, dynamic> vendor,
    bool isDark,
    Color primaryColor,
  ) {
    final name = vendor[DatabaseHelper.columnName] ?? 'Unknown';
    final phone = vendor[DatabaseHelper.columnPhone] ?? '';
    final address = vendor[DatabaseHelper.columnAddress] ?? '';

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
          onTap: () => _showAddEditVendorDialog(vendor: vendor),
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
                  child: Icon(Icons.store, color: primaryColor, size: 28),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                      if (phone.isNotEmpty || address.isNotEmpty)
                        const SizedBox(height: 6),
                      if (phone.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      if (phone.isNotEmpty && address.isNotEmpty)
                        const SizedBox(height: 4),
                      if (address.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
}
