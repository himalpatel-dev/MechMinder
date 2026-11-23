import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/notification_service.dart'; // Add this line
import '../widgets/full_screen_photo_viewer.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart'; // Make sure this path is correct
import '../service/file_storage.dart';
import '../utils/formatters.dart';

/// Digits with an optional decimal part (up to 2 places). Blocks "-" and ","
/// that the number keyboard offers.
final _decimalInput = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d{0,2}'),
);

// --- (UPDATED HELPER CLASS) ---
class ServiceItem {
  String name;
  double qty;
  double cost;
  int? templateId;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  ServiceItem({
    this.name = '',
    this.qty = 1.0,
    this.cost = 0.0,
    this.templateId,
  }) {
    nameController.text = name;
    // "1" instead of "1.0", but keep real decimals: 249.5 must not become 250.
    qtyController.text = Fmt.editable(qty);
    costController.text = Fmt.editable(cost);
  }

  /// Blank quantity means 1, both for the shown total and when saving.
  double get parsedQty {
    final text = qtyController.text.trim();
    if (text.isEmpty) return 1.0;
    return double.tryParse(text) ?? 1.0;
  }

  double get parsedCost => double.tryParse(costController.text.trim()) ?? 0.0;

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    costController.dispose();
  }
}
// --- End of helper class ---

class AddServiceScreen extends StatefulWidget {
  final int vehicleId;
  final int currentOdometer;
  final int? serviceId;
  const AddServiceScreen({
    super.key,
    required this.vehicleId,
    required this.currentOdometer,
    this.serviceId,
  });
  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  // (Controllers)
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _totalCostController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // (State for Dropdowns and Lists)
  List<Map<String, dynamic>> _allVendors = [];
  int? _selectedVendorId;
  List<Map<String, dynamic>> _allTemplates = [];
  final List<ServiceItem> _serviceItems = [ServiceItem()];
  int? _selectedTemplateId;

  // (State for Photos)
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImageFiles = [];
  List<Map<String, dynamic>> _existingPhotos = [];
  // Existing photos the user removed; deleted only when the form is saved.
  final Set<int> _removedPhotoIds = {};

  // (State for Loading/Editing)
  bool _isEditMode = false;
  bool _isLoading = true;
  bool _isLoadingVendors = true;
  bool _isLoadingTemplates = true;
  bool _isSaving = false;
  // True once the user changed something; leaving then asks first.
  bool _isDirty = false;

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void initState() {
    super.initState();
    if (widget.serviceId != null) {
      _isEditMode = true;
      _loadServiceData();
    } else {
      _dateController.text = DateTime.now().toIso8601String().split('T')[0];
      _odometerController.text = widget.currentOdometer.toString();
      _loadDropdownData();
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- DATA LOADING FUNCTIONS ---
  Future<void> _loadDropdownData() async {
    // (This function is unchanged)
    final vendors = await dbHelper.queryAllVendors();
    final templates = await dbHelper.queryAllServiceTemplates();
    if (!mounted) return;
    setState(() {
      _allVendors = vendors;
      _allTemplates = templates;
      _isLoadingVendors = false;
      _isLoadingTemplates = false;
    });
  }

  Future<void> _loadServiceData() async {
    // (This function is unchanged)
    await _loadDropdownData();
    final data = await Future.wait([
      dbHelper.queryServiceById(widget.serviceId!),
      dbHelper.queryServiceItems(widget.serviceId!),
      dbHelper.queryPhotosForParent(widget.serviceId!, 'service'),
    ]);
    if (!mounted) return;
    final service = data[0] as Map<String, dynamic>?;
    final items = data[1] as List<Map<String, dynamic>>;
    _existingPhotos = List.from(data[2] as List<Map<String, dynamic>>);
    if (service == null) {
      // Deleted elsewhere: don't leave the spinner running forever.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This service no longer exists.')),
      );
      Navigator.of(context).pop();
      return;
    }
    _serviceNameController.text =
        service[DatabaseHelper.columnServiceName] ?? '';
    _dateController.text = service[DatabaseHelper.columnServiceDate] ?? '';
    _odometerController.text = (service[DatabaseHelper.columnOdometer] ?? '')
        .toString();
    _totalCostController.text = (service[DatabaseHelper.columnTotalCost] ?? '')
        .toString();
    _notesController.text = service[DatabaseHelper.columnNotes] ?? '';
    _selectedVendorId = service[DatabaseHelper.columnVendorId];
    _serviceItems.clear();
    if (items.isEmpty) {
      _serviceItems.add(ServiceItem());
    } else {
      for (var item in items) {
        _serviceItems.add(
          ServiceItem(
            name: item[DatabaseHelper.columnName],
            qty: (item[DatabaseHelper.columnQty] as num?)?.toDouble() ?? 1.0,
            cost:
                (item[DatabaseHelper.columnUnitCost] as num?)?.toDouble() ??
                0.0,
            templateId: item[DatabaseHelper.columnTemplateId],
          ),
        );
      }
    }
    setState(() {
      _isLoading = false;
      _updateTotalCost();
    });
  }

  // --- UI HELPER FUNCTIONS ---
  void _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        _dateController.text = pickedDate.toIso8601String().split('T')[0];
        _isDirty = true;
      });
    }
  }

  void _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // Optimized: Reduces 12MP photos to ~1MP
        imageQuality: 70, // Optimized: Good quality, typically 10x smaller file
      );
      if (pickedFile != null) {
        setState(() {
          _newImageFiles.add(pickedFile);
          _isDirty = true;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  void _addPartFromTemplate() {
    // (This function is unchanged)
    if (_selectedTemplateId == null) {
      return;
    }
    final templateToAdd = _allTemplates.firstWhere(
      (t) => t[DatabaseHelper.columnId] == _selectedTemplateId,
    );
    _selectedTemplateId = null;
    setState(() {
      _isDirty = true;
      if (_serviceItems.length == 1 &&
          _serviceItems[0].nameController.text.isEmpty) {
        _serviceItems[0].nameController.text =
            templateToAdd[DatabaseHelper.columnName];
        _serviceItems[0].qtyController.text = '1'; // Use "1"
        _serviceItems[0].costController.text = '0'; // Use "0"
        _serviceItems[0].templateId = templateToAdd[DatabaseHelper.columnId];
      } else {
        _serviceItems.add(
          ServiceItem(
            name: templateToAdd[DatabaseHelper.columnName],
            qty: 1.0,
            cost: 0.0,
            templateId: templateToAdd[DatabaseHelper.columnId],
          ),
        );
      }
    });
    _updateTotalCost();
  }

  void _updateTotalCost() {
    // (This function is unchanged)
    double total = 0.0;
    for (var item in _serviceItems) {
      // Same qty/cost rules as when saving, so the total always matches.
      total += item.parsedQty * item.parsedCost;
    }
    setState(() {
      _totalCostController.text = total.toStringAsFixed(2);
    });
  }

  Future<void> _saveService() async {
    // Ignore extra taps while a save is running (prevented duplicates).
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    _updateTotalCost();
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final unitType = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).unitType;

    try {
      final Map<String, dynamic> serviceRow = {
        DatabaseHelper.columnVehicleId: widget.vehicleId,
        DatabaseHelper.columnServiceName: _serviceNameController.text,
        DatabaseHelper.columnServiceDate: _dateController.text,
        DatabaseHelper.columnOdometer: int.tryParse(_odometerController.text),
        DatabaseHelper.columnTotalCost: double.tryParse(
          _totalCostController.text,
        ),
        DatabaseHelper.columnVendorId: _selectedVendorId,
        DatabaseHelper.columnNotes: _notesController.text,
      };

      final List<Map<String, dynamic>> items = [];
      for (final item in _serviceItems) {
        final name = item.nameController.text;
        if (name.isEmpty) continue;
        final qty = item.parsedQty;
        final cost = item.parsedCost;
        items.add({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnQty: qty,
          DatabaseHelper.columnUnitCost: cost,
          DatabaseHelper.columnTotalCost: qty * cost,
          DatabaseHelper.columnTemplateId: item.templateId,
        });
      }

      // Copy bill photos out of the picker's cache into app storage first.
      final List<String> photoPaths = [];
      for (final file in _newImageFiles) {
        photoPaths.add(
          await FileStorage.importFile(file.path, FileStorage.photosFolder),
        );
      }

      // Service, parts, reminders and photos are saved together: either all
      // of it is written or none of it.
      await dbHelper.saveServiceWithItems(
        serviceId: _isEditMode ? widget.serviceId : null,
        serviceRow: serviceRow,
        items: items,
        newPhotoPaths: photoPaths,
      );
      await dbHelper.deletePhotosByIds(_removedPhotoIds);

      // Show alerts this new odometer reading may have triggered.
      await NotificationService().checkAndShowOdometerReminders(
        vehicleId: widget.vehicleId,
        currentOdometer: int.tryParse(_odometerController.text) ?? 0,
        unitType: unitType,
      );

      if (!mounted) return;
      _isDirty = false;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save the service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Asks before throwing away unsaved changes.
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this service will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _isDirty = false;
      Navigator.of(context).pop();
    }
  }

  // --- MAIN BUILD METHOD (unchanged) ---
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    final usedTemplateIds = _serviceItems
        .where((item) => item.templateId != null)
        .map((item) => item.templateId)
        .toSet();
    final availableTemplates = _allTemplates
        .where(
          (template) =>
              !usedTemplateIds.contains(template[DatabaseHelper.columnId]),
        )
        .toList();

    // --- MODERN INPUT DECORATION HELPER ---
    InputDecoration modernInputDecoration(
      String label,
      IconData icon, {
      String? suffixText,
    }) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        suffixText: suffixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      // Back with unsaved changes asks first instead of losing the entry.
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSaving) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          systemOverlayStyle: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          title: Text(
            _isEditMode ? 'Edit Service' : 'Add Service Record',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: isDark ? Colors.white : Colors.black,
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Form(
                  key: _formKey,
                  onChanged: _markDirty,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("Service Details", isDark),
                      const SizedBox(height: 16),

                      // --- SERVICE NAME ---
                      TextFormField(
                        controller: _serviceNameController,
                        decoration: modernInputDecoration(
                          "Service Name",
                          Icons.build,
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // --- DATE & ODOMETER ---
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickDate,
                              child: AbsorbPointer(
                                child: TextFormField(
                                  controller: _dateController,
                                  decoration: modernInputDecoration(
                                    "Date",
                                    Icons.calendar_today,
                                  ),
                                  validator: (value) =>
                                      (value == null || value.isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _odometerController,
                              decoration: modernInputDecoration(
                                "Odometer",
                                Icons.speed,
                                suffixText: settings.unitType,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader("Parts & Cost", isDark),
                      const SizedBox(height: 16),

                      // --- PARTS SELECTION ---
                      _isLoadingTemplates
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedTemplateId,
                                    decoration: modernInputDecoration(
                                      "Add from Auto Parts",
                                      Icons.build_circle,
                                    ),
                                    items: availableTemplates.map((template) {
                                      return DropdownMenuItem<int>(
                                        value:
                                            template[DatabaseHelper.columnId],
                                        child: Text(
                                          template[DatabaseHelper.columnName],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (int? newId) {
                                      setState(() {
                                        _selectedTemplateId = newId;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.add, color: primaryColor),
                                    onPressed: _addPartFromTemplate,
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 16),

                      // --- SERVICE ITEMS LIST ---
                      ..._serviceItems.asMap().entries.map((entry) {
                        return _buildServiceItemRow(
                          entry.value,
                          entry.key,
                          isDark,
                          primaryColor,
                          settings.currencySymbol,
                        );
                      }),

                      const SizedBox(height: 16),
                      // Add Manual Item Button
                      Center(
                        child: TextButton.icon(
                          icon: Icon(Icons.add, color: primaryColor),
                          label: Text(
                            'Add Manual Item',
                            style: TextStyle(
                              fontSize: 16,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _serviceItems.add(ServiceItem());
                              _isDirty = true;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 16),
                      // --- TOTAL COST ---
                      TextFormField(
                        controller: _totalCostController,
                        decoration:
                            modernInputDecoration(
                              "Total Cost",
                              Icons.attach_money, // Or generic money icon
                            ).copyWith(
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  settings.currencySymbol,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ),
                        readOnly: true,
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader("Workshop & Notes", isDark),
                      const SizedBox(height: 16),

                      // --- VENDOR ---
                      _isLoadingVendors
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<int>(
                              value: _selectedVendorId,
                              decoration: modernInputDecoration(
                                "Workshop / Garage",
                                Icons.store,
                              ),
                              items: _allVendors.map((vendor) {
                                return DropdownMenuItem<int>(
                                  value: vendor[DatabaseHelper.columnId],
                                  child: Text(
                                    vendor[DatabaseHelper.columnName],
                                  ),
                                );
                              }).toList(),
                              onChanged: (int? newValue) {
                                setState(() => _selectedVendorId = newValue);
                              },
                            ),
                      const SizedBox(height: 16),

                      // --- NOTES ---
                      TextFormField(
                        controller: _notesController,
                        decoration: modernInputDecoration(
                          "Notes (Optional)",
                          Icons.notes,
                        ),
                        maxLines: 3,
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader("Upload Bill", isDark),
                      const SizedBox(height: 16),
                      _buildPhotoPicker(isDark, primaryColor),
                    ],
                  ),
                ),
              ),
            ),

            // --- STICKY BOTTOM BUTTON ---
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _isSaving ? null : _saveService,
                    child: _isSaving
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: settings.onPrimaryColor,
                            ),
                          )
                        : Text(
                            _isEditMode ? 'UPDATE SERVICE' : 'SAVE SERVICE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: settings.onPrimaryColor,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceItemRow(
    ServiceItem item,
    int index,
    bool isDark,
    Color primaryColor,
    String currencySymbol,
  ) {
    // Mini-decoration helper for these smaller fields
    InputDecoration itemDecoration(String label) {
      return InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        filled: true,
        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: item.nameController,
              decoration: itemDecoration("Part/Service"),
              validator: (val) => val == null || val.isEmpty ? 'Req' : null,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: item.qtyController,
              decoration: itemDecoration("Qty"),
              // Decimals allowed (e.g. 3.5 L of oil). Blank counts as 1.
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimalInput],
              validator: (val) {
                final text = val?.trim() ?? '';
                if (text.isEmpty) return null;
                final qty = double.tryParse(text);
                return (qty == null || qty <= 0) ? '>0' : null;
              },
              onChanged: (_) => _updateTotalCost(),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 2, // Gave it a bit more space
            child: TextFormField(
              controller: item.costController,
              decoration: itemDecoration(
                "Cost",
              ), // Removed prefix to save space, or could add partial
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimalInput],
              onTap: () {
                if (item.costController.text == '0') {
                  item.costController.clear();
                }
              },
              onChanged: (_) => _updateTotalCost(),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () {
              setState(() {
                _isDirty = true;
                if (_serviceItems.length > 1) {
                  item.dispose();
                  _serviceItems.removeAt(index);
                } else {
                  // Clear the first item if it's the only one
                  _serviceItems[index].nameController.clear();
                  _serviceItems[index].qtyController.text = '1';
                  _serviceItems[index].costController.text = '0';
                  _serviceItems[index].templateId = null;
                }
                _updateTotalCost();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker(bool isDark, Color primaryColor) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add Button
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Center(
                child: Icon(
                  Icons.add_a_photo_outlined,
                  size: 28,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          // Existing Photos
          ..._existingPhotos.asMap().entries.map((entry) {
            final index = entry.key;
            final photo = entry.value;
            return _buildPhotoItem(
              File(photo[DatabaseHelper.columnUri]),
              () {
                final paths = _existingPhotos
                    .map((p) => p[DatabaseHelper.columnUri] as String)
                    .toList();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenPhotoViewer(
                      photoPaths: paths,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              () {
                // Deleted when the form is saved, so Back/Discard keeps it.
                setState(() {
                  _removedPhotoIds.add(photo[DatabaseHelper.columnId] as int);
                  _existingPhotos.removeAt(index);
                  _isDirty = true;
                });
              },
            );
          }),
          // New Photos
          ..._newImageFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return _buildPhotoItem(File(file.path), null, () {
              setState(() {
                _newImageFiles.removeAt(index);
              });
            });
          }),
        ],
      ),
    );
  }

  Widget _buildPhotoItem(
    File file,
    VoidCallback? onTap,
    VoidCallback onDelete,
  ) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade300,
              image: DecorationImage(
                // Decode at thumbnail size instead of the full 1024px photo.
                image: ResizeImage(FileImage(file), width: 240),
                fit: BoxFit.cover,
                onError: (_, _) {},
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 14,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    _dateController.dispose();
    _odometerController.dispose();
    _totalCostController.dispose();
    _notesController.dispose();
    for (var item in _serviceItems) {
      item.dispose();
    }
    super.dispose();
  }
}
