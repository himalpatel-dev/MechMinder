import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/database_helper.dart';
import 'dart:io'; // Required to display File objects
import 'package:image_picker/image_picker.dart';

class AddServiceScreen extends StatefulWidget {
  final int vehicleId;
  // We'll get the vehicle's current odometer to pre-fill the form
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

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _totalCostController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _allVendors = [];
  int? _selectedVendorId;
  bool _isLoadingVendors = true;

  List<Map<String, dynamic>> _allTemplates = [];
  int? _selectedTemplateId;
  bool _isLoadingTemplates = true;
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImageFiles = []; // This will hold the picked images
  final List<ServiceItem> _serviceItems = [
    ServiceItem(),
  ]; // Start with one empty item

  List<Map<String, dynamic>> _existingPhotos = []; // For photos already in DB
  bool _isEditMode = false;
  bool _isLoading = true; // Start in loading state

  void _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        setState(() {
          // --- THIS IS THE FIX ---
          _newImageFiles.add(pickedFile);
          // --- END OF FIX ---
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.serviceId != null) {
      // --- WE ARE IN EDIT MODE ---
      _isEditMode = true;
      _loadServiceData(); // Load all the existing data
    } else {
      // --- WE ARE IN "ADD NEW" MODE ---
      _dateController.text = DateTime.now().toIso8601String().split('T')[0];
      _odometerController.text = widget.currentOdometer.toString();
      _loadVendors();
      _loadTemplates();
      setState(() {
        _isLoading = false; // Done loading
      });
    }
  }

  Future<void> _loadServiceData() async {
    // Load all data concurrently
    final data = await Future.wait([
      dbHelper.queryServiceById(widget.serviceId!),
      dbHelper.queryServiceItems(widget.serviceId!),
      dbHelper.queryPhotosForParent(widget.serviceId!, 'service'),
      dbHelper.queryAllVendors(),
      dbHelper.queryAllServiceTemplates(),
    ]);

    // Assign the data
    final service = data[0] as Map<String, dynamic>?;
    final items = data[1] as List<Map<String, dynamic>>;
    _existingPhotos = List.from(data[2] as List<Map<String, dynamic>>);
    _allVendors = data[3] as List<Map<String, dynamic>>;
    _allTemplates = data[4] as List<Map<String, dynamic>>;

    if (service == null) {
      // Handle error, service not found
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Service record not found.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    // Pre-fill controllers
    _dateController.text = service[DatabaseHelper.columnServiceDate] ?? '';
    _odometerController.text = (service[DatabaseHelper.columnOdometer] ?? '')
        .toString();
    _totalCostController.text = (service[DatabaseHelper.columnTotalCost] ?? '')
        .toString();
    _notesController.text = service[DatabaseHelper.columnNotes] ?? '';
    _selectedVendorId = service[DatabaseHelper.columnVendorId];
    _selectedTemplateId = service[DatabaseHelper.columnTemplateId];
    // We don't know the template, but we can pre-fill notes.

    // Pre-fill service items
    _serviceItems.clear(); // Remove the initial blank one
    if (items.isEmpty) {
      _serviceItems.add(ServiceItem()); // Add one blank if none exist
    } else {
      for (var item in items) {
        _serviceItems.add(
          ServiceItem(
            name: item[DatabaseHelper.columnName],
            qty: (item[DatabaseHelper.columnQty] as num).toDouble(),
            cost: (item[DatabaseHelper.columnUnitCost] as num).toDouble(),
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
      _isLoadingVendors = false; // <-- ADD THIS LINE
      _isLoadingTemplates = false; // <-- ADD THIS LINE
    });
  }

  void _loadVendors() async {
    final vendors = await dbHelper.queryAllVendors();
    setState(() {
      _allVendors = vendors;
      _isLoadingVendors = false;
    });
  }

  void _loadTemplates() async {
    final templates = await dbHelper.queryAllServiceTemplates();
    setState(() {
      _allTemplates = templates;
      _isLoadingTemplates = false;
    });
  }

  void _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        _dateController.text = pickedDate.toIso8601String().split('T')[0];
      });
    }
  }

  void _saveService() async {
    if (_formKey.currentState!.validate()) {
      // --- 1. DEFINE THE SERVICE ROW ---
      Map<String, dynamic> serviceRow = {
        DatabaseHelper.columnVehicleId: widget.vehicleId,
        DatabaseHelper.columnServiceDate: _dateController.text,
        DatabaseHelper.columnOdometer: int.tryParse(_odometerController.text),
        DatabaseHelper.columnTotalCost: double.tryParse(
          _totalCostController.text,
        ),
        DatabaseHelper.columnNotes: _notesController.text,
        DatabaseHelper.columnVendorId: _selectedVendorId,
        DatabaseHelper.columnTemplateId: _selectedTemplateId,
      };

      int serviceId;

      // --- 2. CHECK IF EDITING OR ADDING ---
      if (_isEditMode) {
        // --- THIS IS AN UPDATE ---
        serviceId = widget.serviceId!;
        serviceRow[DatabaseHelper.columnId] =
            serviceId; // Add the ID for the update query
        await dbHelper.updateService(serviceRow);
        print('Updated service with ID: $serviceId');

        // We don't auto-create reminders on an edit, to avoid duplicates.
        // (We could add logic to update the reminder, but that's more complex)
      } else {
        // --- THIS IS A NEW SERVICE ---
        serviceId = await dbHelper.insertService(serviceRow);
        print('Inserted new service with ID: $serviceId');

        // We ONLY create a new reminder when ADDING a new service
        if (_selectedTemplateId != null) {
          final template = await dbHelper.queryTemplateById(
            _selectedTemplateId!,
          );
          if (template != null) {
            // (All your existing reminder-creation logic)
            int? intervalDays = template[DatabaseHelper.columnIntervalDays];
            int? intervalKm = template[DatabaseHelper.columnIntervalKm];
            int currentOdo = int.tryParse(_odometerController.text) ?? 0;
            String? nextDueDate;
            int? nextDueOdometer;

            if (intervalDays != null && intervalDays > 0) {
              DateTime serviceDate = DateTime.parse(_dateController.text);
              DateTime dueDate = serviceDate.add(Duration(days: intervalDays));
              nextDueDate = dueDate.toIso8601String().split('T')[0];
            }
            if (intervalKm != null && intervalKm > 0) {
              nextDueOdometer = currentOdo + intervalKm;
            }
            if (nextDueDate != null || nextDueOdometer != null) {
              Map<String, dynamic> reminderRow = {
                DatabaseHelper.columnVehicleId: widget.vehicleId,
                DatabaseHelper.columnTemplateId: _selectedTemplateId,
                DatabaseHelper.columnDueDate: nextDueDate,
                DatabaseHelper.columnDueOdometer: nextDueOdometer,
              };
              await dbHelper.insertReminder(reminderRow);
              print('Created new reminder based on template.');
            }
          }
        }
      }

      // --- 3. WIPE AND RE-SAVE ALL SERVICE ITEMS ---
      // This is the easiest way to handle edits to the parts list.
      await dbHelper.deleteAllServiceItemsForService(serviceId);
      for (var item in _serviceItems) {
        String name = item.nameController.text;
        double qty = double.tryParse(item.qtyController.text) ?? 1.0;
        double cost = double.tryParse(item.costController.text) ?? 0.0;
        if (name.isNotEmpty) {
          Map<String, dynamic> itemRow = {
            DatabaseHelper.columnServiceId: serviceId,
            DatabaseHelper.columnName: name,
            DatabaseHelper.columnQty: qty,
            DatabaseHelper.columnUnitCost: cost,
            DatabaseHelper.columnTotalCost: (qty * cost),
          };
          await dbHelper.insertServiceItem(itemRow);
        }
      }

      // --- 4. (Optional) Update the vehicle's current odometer ---
      int newOdometer = int.tryParse(_odometerController.text) ?? 0;
      if (newOdometer > widget.currentOdometer) {
        await dbHelper.updateVehicleOdometer(widget.vehicleId, newOdometer);
      }

      // --- 5. SAVE ANY *NEWLY ADDED* PHOTOS ---
      // (Deleting old photos is already handled by the button)
      for (var imageFile in _newImageFiles) {
        Map<String, dynamic> photoRow = {
          DatabaseHelper.columnParentId: serviceId,
          DatabaseHelper.columnParentType: 'service',
          DatabaseHelper.columnUri: imageFile.path,
        };
        await dbHelper.insertPhoto(photoRow);
      }

      // --- 6. GO BACK ---
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildServiceItemRow(ServiceItem item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // "Name" field
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: item.nameController,
              decoration: const InputDecoration(labelText: 'Part Name'),
            ),
          ),
          const SizedBox(width: 8),

          // "Qty" field
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: item.qtyController,
              decoration: const InputDecoration(labelText: 'Qty'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),

          // "Cost" field
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: item.costController,
              decoration: const InputDecoration(labelText: 'Cost'),
              keyboardType: TextInputType.number,
            ),
          ),

          // "Delete" button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              setState(() {
                if (_serviceItems.length > 1) {
                  _serviceItems.removeAt(index);
                } else {
                  // If it's the last one, just clear it
                  item.nameController.text = '';
                  item.qtyController.text = '1.0';
                  item.costController.text = '0.0';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  _isLoadingTemplates
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<int>(
                          initialValue: _selectedTemplateId,
                          hint: const Text(
                            'Select Service Template (Optional)',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Template',
                          ),
                          items: _allTemplates.map((template) {
                            return DropdownMenuItem<int>(
                              value: template[DatabaseHelper.columnId],
                              child: Text(template[DatabaseHelper.columnName]),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            setState(() {
                              _selectedTemplateId = newValue;
                              if (newValue != null) {
                                // Find the selected template in our list
                                final selectedTemplate = _allTemplates
                                    .firstWhere(
                                      (t) =>
                                          t[DatabaseHelper.columnId] ==
                                          newValue,
                                    );
                                // Auto-fill the notes field!
                                _notesController.text =
                                    selectedTemplate[DatabaseHelper.columnName];
                              } else {
                                // Clear the notes if no template is selected
                                _notesController.text = '';
                              }
                            });
                          },
                        ),
                  const SizedBox(height: 10),

                  // --- Service Date ---
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Service Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true, // Make it read-only
                    onTap: _pickDate, // Show date picker on tap
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // --- Odometer ---
                  TextFormField(
                    controller: _odometerController,
                    decoration: const InputDecoration(
                      labelText: 'Odometer',
                      suffixText: 'km',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the odometer reading';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // --- Total Cost ---
                  TextFormField(
                    controller: _totalCostController,
                    decoration: const InputDecoration(
                      labelText: 'Total Cost',
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  const SizedBox(height: 10),
                  _isLoadingVendors
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<int>(
                          initialValue: _selectedVendorId,
                          hint: const Text('Select Vendor'),
                          decoration: const InputDecoration(
                            labelText: 'Vendor',
                          ),
                          items: _allVendors.map((vendor) {
                            return DropdownMenuItem<int>(
                              value: vendor[DatabaseHelper.columnId],
                              child: Text(vendor[DatabaseHelper.columnName]),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            setState(() {
                              _selectedVendorId = newValue;
                            });
                          },
                        ),

                  // --- END OF NEW DROPDOWN ---
                  const SizedBox(height: 10),
                  // --- Notes ---
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (e.g., Oil change, brake pads)',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  // --- ADD THIS ENTIRE "SERVICE ITEMS" SECTION ---
                  Text(
                    'Parts / Items',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),

                  // This builds our list of item text fields
                  ListView.builder(
                    shrinkWrap: true, // Allows ListView inside a ListView
                    physics:
                        const NeverScrollableScrollPhysics(), // Stops nested scrolling
                    itemCount: _serviceItems.length,
                    itemBuilder: (context, index) {
                      return _buildServiceItemRow(_serviceItems[index], index);
                    },
                  ),

                  // "Add Item" Button
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                    onPressed: () {
                      setState(() {
                        _serviceItems.add(
                          ServiceItem(),
                        ); // Add a new blank item
                      });
                    },
                  ),

                  // --- END OF NEW SECTION ---
                  const SizedBox(height: 20),

                  // --- REPLACE THE "Add Photos" SECTION ---
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
                        // --- BUILD THE "ADD" BUTTON ---
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

                        // --- BUILD AN "EXISTING PHOTO" TILE ---
                        if (index < _existingPhotos.length) {
                          final photo = _existingPhotos[index];
                          final photoPath = photo[DatabaseHelper.columnUri];
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(File(photoPath)),
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

                        // --- BUILD A "NEW PHOTO" TILE ---
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

                  // --- END OF REPLACED SECTION ---
                  const SizedBox(height: 20),

                  // --- Save Button ---
                  ElevatedButton(
                    onPressed: _saveService,
                    child: const Text('Save Service'),
                  ),
                ],
              ),
            ),
    );
  }
}

class ServiceItem {
  String name;
  double qty;
  double cost;

  // Controllers for the TextFields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController costController = TextEditingController();

  ServiceItem({this.name = '', this.qty = 1.0, this.cost = 0.0}) {
    nameController.text = name;
    qtyController.text = qty.toString();
    costController.text = cost.toString();
  }
}
