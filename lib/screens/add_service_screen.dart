import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
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
      _updateTotalCost(); // Recalculate total

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

      // --- 2. DELETE AND RE-SAVE ALL ITEMS (unchanged) ---
      await dbHelper.deleteAllServiceItemsForService(serviceId);
      List<int> newTemplateIdsUsed =
          []; // Get list of templates in this service

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

      // --- 3. SYNC REMINDERS (THE NEW, PERFECT LOGIC) ---
      print("--- STARTING REMINDER SYNC ---");

      // 1. DELETE all reminders previously created by *this service*.
      // This fixes your "remove part" bug.
      print(
        "  > Deleting all old reminders linked to this service (ID: $serviceId)...",
      );
      await dbHelper.deleteRemindersByService(serviceId);

      // 2. Find reminders TO ADD (based on parts list)
      final remindersToAdd = newTemplateIdsUsed.toSet();
      print("[DEBUG] Reminders TO ADD (Template IDs): $remindersToAdd");

      if (remindersToAdd.isNotEmpty) {
        for (int templateIdToAdd in remindersToAdd) {
          final template = await dbHelper.queryTemplateById(templateIdToAdd);
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
              print("  > Creating new reminder for template $templateIdToAdd");

              await dbHelper.insertReminder({
                DatabaseHelper.columnVehicleId: widget.vehicleId,
                DatabaseHelper.columnServiceId: serviceId, // <-- THE FIX
                DatabaseHelper.columnTemplateId: templateIdToAdd,
                DatabaseHelper.columnDueDate: nextDueDate,
                DatabaseHelper.columnDueOdometer: nextDueOdometer,
              });
            }
          }
        }
      }
      print("--- REMINDER SYNC COMPLETE ---");
      // --- END OF NEW LOGIC ---

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

    // Define a standard border and fill color for all fields
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color? fillColor = isDarkMode ? Colors.grey[800] : Colors.grey[100];
    final InputBorder fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey[400]!),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Service' : 'Add Service Record'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- CARD 1: SERVICE DETAILS ---
                  _buildSectionCard(
                    title: 'Service Details',
                    children: [
                      TextFormField(
                        controller: _serviceNameController,
                        decoration: InputDecoration(
                          labelText: 'Service Name (e.g., General Service)',
                          icon: Icon(Icons.label, color: settings.primaryColor),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Please enter a service name'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _dateController,
                            decoration: InputDecoration(
                              labelText: 'Service Date',
                              icon: Icon(
                                Icons.calendar_today,
                                color: settings.primaryColor,
                              ),
                            ),
                            enabled: true,
                            // style: const TextStyle(color: Colors.black),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? 'Please enter a date'
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _odometerController,
                        decoration: InputDecoration(
                          labelText: 'Odometer',
                          icon: Icon(Icons.speed, color: settings.primaryColor),
                          suffixText: settings.unitType,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Please enter the odometer'
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- CARD 2: PARTS & COST ---
                  _buildSectionCard(
                    title: 'Parts & Cost',
                    children: [
                      _isLoadingTemplates
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedTemplateId,
                                    hint: const Text('Add part from AutoSet'),
                                    decoration: InputDecoration(
                                      border: fieldBorder,
                                      filled: true,
                                      fillColor: fillColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                            vertical: 15.0,
                                          ),
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
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.green,
                                    size: 30,
                                  ),
                                  tooltip: 'Add selected AutoSet',
                                  onPressed: _addPartFromTemplate,
                                ),
                              ],
                            ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          for (int i = 0; i < _serviceItems.length; i++)
                            _buildServiceItemRow(_serviceItems[i], i, settings),
                        ],
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.add, color: settings.primaryColor),
                        label: Text(
                          'Add Manual Item',
                          style: TextStyle(
                            fontSize: 16,
                            color: settings.primaryColor,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _serviceItems.add(ServiceItem());
                          });
                        },
                      ),
                      const Divider(height: 20),
                      TextFormField(
                        controller: _totalCostController,
                        decoration: InputDecoration(
                          labelText: 'Total Cost (Auto-calculated)',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(
                              top: 12,
                              left: 12,
                              right: 12,
                            ),
                            child: Text(
                              settings
                                  .currencySymbol, // This is your dynamic symbol
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: settings
                                    .primaryColor, // Uses your theme color
                              ),
                            ),
                          ),
                        ),
                        readOnly: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- CARD 3: VENDOR & NOTES ---
                  _buildSectionCard(
                    title: 'Workshop & Notes',
                    children: [
                      _isLoadingVendors
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<int>(
                              value: _selectedVendorId,
                              hint: const Text('Select Workshop'),
                              decoration: InputDecoration(
                                // <-- Use new style
                                labelText: 'Workshop',
                                prefixIcon: Icon(
                                  Icons.store,
                                  color: settings.primaryColor,
                                ),
                                border: fieldBorder,
                                filled: true,
                                fillColor: fillColor,
                              ),
                              items: _allVendors
                                  .map(
                                    (vendor) => DropdownMenuItem<int>(
                                      value: vendor[DatabaseHelper.columnId],
                                      child: Text(
                                        vendor[DatabaseHelper.columnName],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (int? newValue) {
                                setState(() {
                                  _selectedVendorId = newValue;
                                });
                              },
                            ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: 'Notes (Optional)',
                          icon: Icon(Icons.notes, color: settings.primaryColor),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- CARD 4: PHOTOS ---
                  _buildSectionCard(
                    title: 'Photos (Receipts, Parts, etc.)',
                    children: [
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              _existingPhotos.length +
                              _newImageFiles.length +
                              1,
                          itemBuilder: (context, index) {
                            // (All photo logic is unchanged)
                            if (index ==
                                _existingPhotos.length +
                                    _newImageFiles.length) {
                              return GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 100,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.add_a_photo,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }
                            if (index < _existingPhotos.length) {
                              final photo = _existingPhotos[index];
                              return Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(
                                          File(photo[DatabaseHelper.columnUri]),
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () async {
                                        await dbHelper.deletePhoto(
                                          photo[DatabaseHelper.columnId],
                                        );
                                        setState(() {
                                          _existingPhotos.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            final newPhotoIndex =
                                index - _existingPhotos.length;
                            final photoFile = _newImageFiles[newPhotoIndex];
                            return Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(File(photoFile.path)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _newImageFiles.removeAt(newPhotoIndex);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- SAVE BUTTON ---
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _saveService,
                    child: Text(
                      _isEditMode ? 'Update Service' : 'Save Service',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- NEW: Helper widget to build the Card sections ---
  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  // --- (UPDATED SERVICE ITEM ROW) ---
  Widget _buildServiceItemRow(
    ServiceItem item,
    int index,
    SettingsProvider settings,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: item.nameController,
              decoration: const InputDecoration(labelText: 'Part Name'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: item.qtyController,
              decoration: const InputDecoration(labelText: 'Qty'),
              keyboardType: TextInputType.number,
              // --- FIX 1: Allow only whole numbers ---
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _updateTotalCost(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: item.costController,
              decoration: InputDecoration(
                labelText: 'Cost',
                prefixText: settings.currencySymbol,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // --- FIX 3: Clear "0" on tap ---
              onTap: () {
                if (item.costController.text == '0') {
                  item.costController.clear();
                }
              },
              onChanged: (_) => _updateTotalCost(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              setState(() {
                if (_serviceItems.length > 1) {
                  // --- Must dispose before removing ---
                  item.dispose();
                  _serviceItems.removeAt(index);
                } else {
                  _serviceItems[index].dispose();
                  _serviceItems[index] = ServiceItem();
                }
                _updateTotalCost();
              });
            },
          ),
        ],
      ),
    );
  }

  // --- NEW: Add a dispose method ---
  @override
  void dispose() {
    // Dispose all controllers in the main state
    _serviceNameController.dispose();
    _dateController.dispose();
    _odometerController.dispose();
    _totalCostController.dispose();
    _notesController.dispose();

    // Loop and dispose all controllers in the items list
    for (var item in _serviceItems) {
      item.dispose();
    }

    super.dispose();
  }
}
