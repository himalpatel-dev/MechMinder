import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';

// (Helper class is unchanged)
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
    qtyController.text = qty.toString();
    costController.text = cost.toString();
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

  // (Controllers are unchanged)
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _totalCostController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // (State for Dropdowns and Lists is unchanged)
  List<Map<String, dynamic>> _allVendors = [];
  int? _selectedVendorId;
  List<Map<String, dynamic>> _allTemplates = [];
  final List<ServiceItem> _serviceItems = [ServiceItem()];
  int? _selectedTemplateId;

  // (State for Photos is unchanged)
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImageFiles = [];
  List<Map<String, dynamic>> _existingPhotos = [];

  // (State for Loading/Editing is unchanged)
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

  // --- DATA LOADING FUNCTIONS (UPDATED) ---
  Future<void> _loadDropdownData() async {
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
      _updateTotalCost(); // --- NEW: Calculate total cost on load
    });
  }

  // --- UI HELPER FUNCTIONS ---
  void _pickDate() async {
    /* ... (unchanged) ... */
  }
  void _pickImage() async {
    /* ... (unchanged) ... */
  }

  void _addPartFromTemplate() {
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
        _serviceItems[0].qtyController.text = '1.0';
        _serviceItems[0].costController.text = '0.0';
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
    _updateTotalCost(); // --- NEW: Update total
  }

  // --- NEW: FUNCTION TO CALCULATE TOTAL COST ---
  void _updateTotalCost() {
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
  // --- END NEW ---

  // --- SAVE FUNCTION (UPDATED) ---
  Future<void> _saveService() async {
    print(
      "[DEBUG] Save button pressed. Service Name is: '${_serviceNameController.text}'",
    );
    if (_formKey.currentState!.validate()) {
      // --- NEW: Recalculate total one last time before saving ---
      _updateTotalCost();
      // --- END NEW ---

      Map<String, dynamic> serviceRow = {
        DatabaseHelper.columnVehicleId: widget.vehicleId,
        DatabaseHelper.columnServiceName: _serviceNameController.text,
        DatabaseHelper.columnServiceDate: _dateController.text,
        DatabaseHelper.columnOdometer: int.tryParse(_odometerController.text),
        // Read the auto-calculated value from the controller
        DatabaseHelper.columnTotalCost: double.tryParse(
          _totalCostController.text,
        ),
        DatabaseHelper.columnVendorId: _selectedVendorId,
        DatabaseHelper.columnNotes: _notesController.text,
      };

      // ... (Rest of save function is unchanged) ...
      int serviceId;
      final oldTemplateIds = _serviceItems
          .where((item) => item.templateId != null)
          .map((item) => item.templateId!)
          .toSet();
      if (_isEditMode) {
        serviceId = widget.serviceId!;
        serviceRow[DatabaseHelper.columnId] = serviceId;
        await dbHelper.updateService(serviceRow);
      } else {
        serviceId = await dbHelper.insertService(serviceRow);
      }
      await dbHelper.deleteAllServiceItemsForService(serviceId);
      List<int> newTemplateIdsUsed = [];
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
      print("--- STARTING REMINDER SYNC ---");
      final newTemplateIdSet = newTemplateIdsUsed.toSet();
      final oldReminders = await dbHelper.queryTemplateRemindersForVehicle(
        widget.vehicleId,
      );
      final oldTemplateIdsInDB = oldReminders
          .map((r) => r[DatabaseHelper.columnTemplateId] as int)
          .toSet();
      final remindersToDelete = oldTemplateIdsInDB.difference(newTemplateIdSet);
      if (remindersToDelete.isNotEmpty) {
        for (int templateIdToDelete in remindersToDelete) {
          final reminder = oldReminders.firstWhere(
            (r) => r[DatabaseHelper.columnTemplateId] == templateIdToDelete,
          );
          await dbHelper.deleteReminder(reminder[DatabaseHelper.columnId]);
        }
      }
      final remindersToAdd = newTemplateIdSet.difference(oldTemplateIdsInDB);
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
              await dbHelper.insertReminder({
                DatabaseHelper.columnVehicleId: widget.vehicleId,
                DatabaseHelper.columnTemplateId: templateIdToAdd,
                DatabaseHelper.columnDueDate: nextDueDate,
                DatabaseHelper.columnDueOdometer: nextDueOdometer,
              });
            }
          }
        }
      }
      print("--- REMINDER SYNC COMPLETE ---");
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

  // --- MAIN BUILD METHOD (UPDATED) ---
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
                  // (Service Name - unchanged)
                  TextFormField(
                    controller: _serviceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Service Name (e.g., General Service)',
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Please enter a service name'
                        : null,
                  ),
                  const SizedBox(height: 10),

                  // (Service Date - unchanged)
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Service Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(_dateController.text) ??
                            DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null) {
                        _dateController.text = pickedDate
                            .toIso8601String()
                            .split('T')[0];
                      }
                    }, // <-- THIS IS THE FIX
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Please enter a date'
                        : null,
                  ),
                  const SizedBox(height: 10),

                  // (Odometer - unchanged)
                  TextFormField(
                    controller: _odometerController,
                    decoration: InputDecoration(
                      labelText: 'Odometer',
                      suffixText: settings.unitType,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Please enter the odometer'
                        : null,
                  ),
                  const SizedBox(height: 10),

                  // --- TOTAL COST (UPDATED) ---
                  TextFormField(
                    controller: _totalCostController,
                    decoration: InputDecoration(
                      labelText: 'Total Cost (Auto-calculated)', // New label
                      prefixText: settings.currencySymbol,
                    ),
                    readOnly: true, // Make it read-only
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  // --- END UPDATE ---
                  const SizedBox(height: 10),

                  // (Vendor Dropdown - unchanged)
                  _isLoadingVendors
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<int>(
                          value: _selectedVendorId,
                          hint: const Text('Select Vendor (Optional)'),
                          decoration: const InputDecoration(
                            labelText: 'Vendor',
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

                  // (Notes - unchanged)
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  // (Parts / Items Section - unchanged)
                  Text(
                    'Parts / Items',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  _isLoadingTemplates
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedTemplateId,
                                hint: const Text('Add part from template'),
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
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                                size: 30,
                              ),
                              tooltip: 'Add selected template',
                              onPressed: _addPartFromTemplate,
                            ),
                          ],
                        ),
                  const SizedBox(height: 10),

                  // (Manual Parts List - UPDATED)
                  Column(
                    children: [
                      for (int i = 0; i < _serviceItems.length; i++)
                        // Pass the update function to the row
                        _buildServiceItemRow(_serviceItems[i], i, settings),
                    ],
                  ),

                  // (Add Manual Item - UPDATED)
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Manual Item'),
                    onPressed: () {
                      setState(() {
                        _serviceItems.add(ServiceItem());
                        // No need to update total here,
                        // it will be 0 until they type
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // (Photos Section - unchanged)
                  const Text(
                    'Add Photos (Receipts, Parts, etc.)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          _existingPhotos.length + _newImageFiles.length + 1,
                      itemBuilder: (context, index) {
                        // (All photo logic is unchanged)
                        if (index ==
                            _existingPhotos.length + _newImageFiles.length) {
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
                        final newPhotoIndex = index - _existingPhotos.length;
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
                  const SizedBox(height: 20),

                  // (Save Button - unchanged)
                  ElevatedButton(
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
              // --- NEW: Call update function on change ---
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
              keyboardType: TextInputType.number,
              // --- NEW: Call update function on change ---
              onChanged: (_) => _updateTotalCost(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              setState(() {
                if (_serviceItems.length > 1) {
                  _serviceItems.removeAt(index);
                } else {
                  _serviceItems[index] = ServiceItem();
                }
                _updateTotalCost(); // --- NEW: Call update function on delete ---
              });
            },
          ),
        ],
      ),
    );
  }
}
