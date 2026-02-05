import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../widgets/full_screen_photo_viewer.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart'; // Make sure this path is correct

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
    // --- FIX 1: Show "1" instead of "1.0" ---
    qtyController.text = qty.toStringAsFixed(0);
    // --- FIX 2: Show "0" instead of "0.0" ---
    costController.text = cost.toStringAsFixed(0);
  }

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

  // (State for Loading/Editing)
  bool _isEditMode = false;
  bool _isLoading = true;
  bool _isLoadingVendors = true;
  bool _isLoadingTemplates = true;

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
    final service = data[0] as Map<String, dynamic>?;
    final items = data[1] as List<Map<String, dynamic>>;
    _existingPhotos = List.from(data[2] as List<Map<String, dynamic>>);
    if (service == null) {
      /* (Error handling) */
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
            qty: (item[DatabaseHelper.columnQty] as num).toDouble(),
            cost: (item[DatabaseHelper.columnUnitCost] as num).toDouble(),
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
      final qty = double.tryParse(item.qtyController.text) ?? 0.0;
      final cost = double.tryParse(item.costController.text) ?? 0.0;
      total += qty * cost;
    }
    setState(() {
      _totalCostController.text = total.toStringAsFixed(2);
    });
  }

  // --- SAVE FUNCTION (unchanged) ---
  // Future<void> _saveService() async {
  //   print(
  //     "[DEBUG] Save button pressed. Service Name is: '${_serviceNameController.text}'",
  //   );
  //   if (_formKey.currentState!.validate()) {
  //     _updateTotalCost(); // Recalculate total

  //     Map<String, dynamic> serviceRow = {
  //       DatabaseHelper.columnVehicleId: widget.vehicleId,
  //       DatabaseHelper.columnServiceName: _serviceNameController.text,
  //       DatabaseHelper.columnServiceDate: _dateController.text,
  //       DatabaseHelper.columnOdometer: int.tryParse(_odometerController.text),
  //       DatabaseHelper.columnTotalCost: double.tryParse(
  //         _totalCostController.text,
  //       ),
  //       DatabaseHelper.columnVendorId: _selectedVendorId,
  //       DatabaseHelper.columnNotes: _notesController.text,
  //     };
  //     int serviceId;

  //     if (_isEditMode) {
  //       serviceId = widget.serviceId!;
  //       serviceRow[DatabaseHelper.columnId] = serviceId;
  //       await dbHelper.updateService(serviceRow);
  //     } else {
  //       serviceId = await dbHelper.insertService(serviceRow);
  //     }

  //     // --- 2. DELETE AND RE-SAVE ALL ITEMS ---
  //     await dbHelper.deleteAllServiceItemsForService(serviceId);
  //     List<int> templateIdsUsed =
  //         []; // This is the list of templates in *this* service

  //     for (var item in _serviceItems) {
  //       String name = item.nameController.text;
  //       if (name.isNotEmpty) {
  //         double qty = double.tryParse(item.qtyController.text) ?? 1.0;
  //         double cost = double.tryParse(item.costController.text) ?? 0.0;
  //         Map<String, dynamic> itemRow = {
  //           DatabaseHelper.columnServiceId: serviceId,
  //           DatabaseHelper.columnName: name,
  //           DatabaseHelper.columnQty: qty,
  //           DatabaseHelper.columnUnitCost: cost,
  //           DatabaseHelper.columnTotalCost: (qty * cost),
  //           DatabaseHelper.columnTemplateId: item.templateId,
  //         };
  //         await dbHelper.insertServiceItem(itemRow);
  //         if (item.templateId != null) {
  //           templateIdsUsed.add(item.templateId!);
  //         }
  //       }
  //     }

  //     int newOdometer = int.tryParse(_odometerController.text) ?? 0;
  //     if (newOdometer > widget.currentOdometer) {
  //       await dbHelper.updateVehicleOdometer(widget.vehicleId, newOdometer);
  //     }

  //     // --- 3. "AUTO-COMPLETE" AND CREATE REMINDERS (THE CORRECT LOGIC) ---
  //     // This new logic only touches reminders for templates
  //     // that are part of this service.

  //     if (templateIdsUsed.isNotEmpty) {
  //       print(
  //         "Auto-completing and creating ${templateIdsUsed.length} new reminders...",
  //       );

  //       for (int templateId in templateIdsUsed.toSet()) {
  //         // 1. "AUTO-COMPLETE": Delete any old, pending reminder for this template.
  //         print(
  //           "  > Deleting old reminder for template $templateId (if one exists)...",
  //         );
  //         await dbHelper.deleteRemindersByTemplate(
  //           widget.vehicleId,
  //           templateId,
  //         );

  //         // 2. "CREATE NEW": Add the new reminder with the calculated due date.
  //         final template = await dbHelper.queryTemplateById(templateId);
  //         if (template != null) {
  //           int? intervalDays = template[DatabaseHelper.columnIntervalDays];
  //           int? intervalKm = template[DatabaseHelper.columnIntervalKm];
  //           String? nextDueDate;
  //           int? nextDueOdometer;

  //           if (intervalDays != null && intervalDays >= 0) {
  //             // Use >=
  //             DateTime serviceDate = DateTime.parse(_dateController.text);
  //             nextDueDate = serviceDate
  //                 .add(Duration(days: intervalDays))
  //                 .toIso8601String()
  //                 .split('T')[0];
  //           }
  //           if (intervalKm != null && intervalKm > 0) {
  //             nextDueOdometer = newOdometer + intervalKm;
  //           }
  //           if (nextDueDate != null || nextDueOdometer != null) {
  //             print("  > Creating new reminder for template $templateId");

  //             await dbHelper.insertReminder({
  //               DatabaseHelper.columnVehicleId: widget.vehicleId,
  //               DatabaseHelper.columnTemplateId: templateId,
  //               DatabaseHelper.columnDueDate: nextDueDate,
  //               DatabaseHelper.columnDueOdometer: nextDueOdometer,
  //             });

  //             // We are not scheduling notifications, the background task will.
  //           }
  //         }
  //       }
  //     }
  //     print("--- REMINDER SYNC COMPLETE ---");
  //     // --- END OF NEW LOGIC ---

  //     // ... (Save Photos logic) ...
  //     for (var imageFile in _newImageFiles) {
  //       await dbHelper.insertPhoto({
  //         DatabaseHelper.columnParentId: serviceId,
  //         DatabaseHelper.columnParentType: 'service',
  //         DatabaseHelper.columnUri: imageFile.path,
  //       });
  //     }

  //     if (mounted) {
  //       Navigator.of(context).pop();
  //     }
  //   }
  // }

  Future<void> _saveService() async {
    if (_formKey.currentState!.validate()) {
      _updateTotalCost();
      Map<String, dynamic> serviceRow = {
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

      int serviceId;
      if (_isEditMode) {
        serviceId = widget.serviceId!;
        serviceRow[DatabaseHelper.columnId] = serviceId;
        await dbHelper.updateService(serviceRow);
      } else {
        serviceId = await dbHelper.insertService(serviceRow);
      }

      // --- 1. RESET ALL REMINDERS LINKED TO THIS SERVICE ---
      // This is the "un-complete" step you wanted!
      print("--- STARTING REMINDER SYNC ---");
      print(
        "  > [EDIT]: Un-completing any reminders previously completed by service $serviceId",
      );
      await dbHelper.uncompleteRemindersByService(serviceId);

      // 2. Delete all reminders CREATED BY this service (we will re-create them)
      print("  > [EDIT]: Deleting all reminders created by service $serviceId");
      await dbHelper.deleteRemindersByService(serviceId);

      // 3. Delete and re-save all parts (unchanged)
      await dbHelper.deleteAllServiceItemsForService(serviceId);
      List<int> newTemplateIdsUsed =
          []; // Get list of templates *now* in this service

      for (var item in _serviceItems) {
        String name = item.nameController.text;
        if (name.isNotEmpty) {
          double qty = double.tryParse(item.qtyController.text) ?? 1.0;
          double cost = double.tryParse(item.costController.text) ?? 0.0;
          Map<String, dynamic> itemRow = {
            DatabaseHelper.columnServiceId: serviceId,
            DatabaseHelper.columnName: name,
            DatabaseHelper.columnQty: qty,
            DatabaseHelper.columnUnitCost: cost,
            DatabaseHelper.columnTotalCost: (qty * cost),
            DatabaseHelper.columnTemplateId: item.templateId,
          };
          await dbHelper.insertServiceItem(itemRow);
          if (item.templateId != null) {
            newTemplateIdsUsed.add(item.templateId!);
          }
        }
      }

      int newOdometer = int.tryParse(_odometerController.text) ?? 0;
      if (newOdometer > widget.currentOdometer) {
        await dbHelper.updateVehicleOdometer(widget.vehicleId, newOdometer);
      }

      // 4. For each part, complete old reminders and create new ones
      final newTemplateIdSet = newTemplateIdsUsed.toSet();
      print(
        "  > [SAVE]: Found ${newTemplateIdSet.length} templates in this service.",
      );

      if (newTemplateIdSet.isNotEmpty) {
        for (int templateId in newTemplateIdSet) {
          // 4a. "AUTO-COMPLETE": Mark any old 'pending' reminders as 'completed'
          print(
            "  > [SAVE]: Completing old 'pending' reminders for template $templateId...",
          );
          await dbHelper.completeRemindersByTemplate(
            widget.vehicleId,
            templateId,
            serviceId,
          );

          // 4b. "CREATE NEW": Add the new 'pending' reminder for the future
          final template = await dbHelper.queryTemplateById(templateId);
          if (template != null) {
            int? intervalDays = template[DatabaseHelper.columnIntervalDays];
            int? intervalKm = template[DatabaseHelper.columnIntervalKm];
            String? nextDueDate;
            int? nextDueOdometer;

            if (intervalDays != null && intervalDays >= 0) {
              DateTime serviceDate = DateTime.parse(_dateController.text);
              nextDueDate = serviceDate
                  .add(Duration(days: intervalDays))
                  .toIso8601String()
                  .split('T')[0];
            }
            if (intervalKm != null && intervalKm > 0) {
              nextDueOdometer = newOdometer + intervalKm;
            }
            if (nextDueDate != null || nextDueOdometer != null) {
              print(
                "  > [SAVE]: Creating new reminder for template $templateId",
              );

              await dbHelper.insertReminder({
                DatabaseHelper.columnVehicleId: widget.vehicleId,
                DatabaseHelper.columnServiceId:
                    serviceId, // Link to this service
                DatabaseHelper.columnTemplateId: templateId,
                DatabaseHelper.columnDueDate: nextDueDate,
                DatabaseHelper.columnDueOdometer: nextDueOdometer,
                DatabaseHelper.columnStatus: 'pending', // <-- NEW
              });
            }
          }
        }
      }
      print("--- REMINDER SYNC COMPLETE ---");

      // (Save Photos logic is unchanged)
      for (var imageFile in _newImageFiles) {
        await dbHelper.insertPhoto({
          DatabaseHelper.columnParentId: serviceId,
          DatabaseHelper.columnParentType: 'service',
          DatabaseHelper.columnUri: imageFile.path,
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
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

    return Scaffold(
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
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Required' : null,
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
                                      value: template[DatabaseHelper.columnId],
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
                                child: Text(vendor[DatabaseHelper.columnName]),
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
                  onPressed: _saveService,
                  child: Text(
                    _isEditMode ? 'UPDATE SERVICE' : 'SAVE SERVICE',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
              decoration: itemDecoration(""),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              () async {
                await dbHelper.deletePhoto(photo[DatabaseHelper.columnId]);
                setState(() {
                  _existingPhotos.removeAt(index);
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
              image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
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
