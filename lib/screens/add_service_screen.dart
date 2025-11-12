import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import 'package:provider/provider.dart';
import '../service/settings_provider.dart'; // Make sure this path is correct
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
    qtyController.text = qty.toStringAsFixed(0);
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

  // (State for Photos & Scanning)
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  List<Map<String, dynamic>> _existingPhotos = [];
  final List<XFile> _newImageFiles = [];

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
      if (pickedFile == null) return;

      setState(() {
        _newImageFiles.add(pickedFile);
      });

      _scanImageForParts(pickedFile);
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
        _serviceItems[0].qtyController.text = '1';
        _serviceItems[0].costController.text = '0';
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
  Future<void> _saveService() async {
    // (This entire function is unchanged from your last version)
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

  // --- ALL SCANNING FUNCTIONS ARE NEW OR UPDATED ---

  Future<void> _scanImageForParts(XFile image) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanning image for parts...')),
      );

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      String fullText = recognizedText.text;
      print("--- SCANNED TEXT ---");
      print(fullText);
      print("---------------------");

      // --- 1. Find the Date and Total ---
      String? foundDate = _parseDate(fullText);
      String? foundTotal = _parseTotal(fullText);

      // --- 2. Find line items ---
      List<ServiceItem> foundItems = _parseLineItems(fullText);

      // Update the main form
      setState(() {
        if (foundDate != null) {
          _dateController.text = foundDate;
        }

        if (foundItems.isNotEmpty) {
          // Clear the initial blank item if it's there
          if (_serviceItems.length == 1 &&
              _serviceItems[0].nameController.text.isEmpty) {
            _serviceItems.clear();
          }
          _serviceItems.addAll(foundItems);
        }

        // --- Smart Total Logic ---
        // If we found a "Total Amount Due" on the receipt, use it.
        // It's usually more accurate than our line item total
        if (foundTotal != null) {
          _totalCostController.text = foundTotal;
        } else {
          // If no grand total, calculate it from the parts we found
          _updateTotalCost();
        }
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan complete! Added ${foundItems.length} parts.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error scanning receipt: $e");
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error scanning receipt.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- NEW: Smarter Date Parser ---
  String? _parseDate(String text) {
    // Regex 1: 2025-11-12
    // Regex 2: 12/11/2025 or 12-11-2025
    // Regex 3: April 15, 2050
    final RegExp dateRegex = RegExp(
      r'(\d{4}-\d{2}-\d{2})|(\d{2}[/-]\d{2}[/-]\d{4})|((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},\s+\d{4})',
      caseSensitive: false,
    );

    // Find *all* dates, not just the first one
    final matches = dateRegex.allMatches(text);
    if (matches.isEmpty) return null;

    // We'll take the first one we can successfully parse
    for (var match in matches) {
      String dateStr = match.group(0)!;
      try {
        if (dateStr.contains('/')) {
          final parts = dateStr.split('/'); // DD/MM/YYYY
          dateStr = '${parts[2]}-${parts[1]}-${parts[0]}';
        } else if (dateStr.contains('-') && dateStr.length != 10) {
          // DD-MM-YYYY
          final parts = dateStr.split('-');
          dateStr = '${parts[2]}-${parts[1]}-${parts[0]}';
        } else if (dateStr.contains(',')) {
          // "April 15, 2050"
          final DateTime parsedDate = DateTime.parse(dateStr);
          dateStr = parsedDate.toIso8601String().split('T')[0];
        }

        DateTime.parse(dateStr); // Final check to make sure it's valid
        return dateStr; // Return the first valid date
      } catch (e) {
        // This format failed, try the next match
        continue;
      }
    }
    return null;
  }

  // --- NEW: Smarter Total Parser ---
  String? _parseTotal(String text) {
    // Looks for "Total", "Amount Due", "Price", etc., followed by a price $123.45 or ₹ 123.45
    final RegExp totalRegex = RegExp(
      r'(?:total|amount|price|due|grand total|subtotal|total amount due|total customer amount)[\s:]*[\$₹]?\s*([\d,]+\.\d{2})',
      caseSensitive: false,
    );

    final matches = totalRegex.allMatches(text);
    if (matches.isEmpty) return null;

    double largestTotal = 0.0;
    for (var match in matches) {
      final String valueStr = match.group(1)!.replaceAll(',', '');
      final double value = double.tryParse(valueStr) ?? 0.0;
      if (value > largestTotal) {
        largestTotal = value;
      }
    }

    return largestTotal > 0 ? largestTotal.toStringAsFixed(2) : null;
  }

  // --- NEW: Smarter Line Item Parser for your invoice ---
  List<ServiceItem> _parseLineItems(String text) {
    final List<ServiceItem> items = [];

    // This new regex looks for 4 columns:
    // 1. Description (non-greedy)
    // 2. Quantity (one or more digits, with decimals)
    // 3. Unit Price (e.g., $50.00 or 50.00)
    // 4. Total Price (e.g., $100.00 or 100.00)
    final RegExp lineRegex = RegExp(
      // Group 1: Item Name (start of line, multiple words, numbers, slashes, dashes)
      // Group 2: Quantity (a number, possibly with a decimal)
      // Group 3: Unit Price (a number with a decimal)
      // Group 4: Total Price (a number with a decimal at the end of the line)
      r'^([a-zA-Z0-9\s\-/]+?)\s+([\d\.]+)\s+\$?([\d,]+\.\d{2})\s+.+\$?([\d,]+\.\d{2})$',
      multiLine: true,
      caseSensitive: false,
    );

    final matches = lineRegex.allMatches(text);
    print("--- Found ${matches.length} potential parts ---");

    for (var match in matches) {
      try {
        String name = match
            .group(1)!
            .trim(); // e.g., "Replacement of brake pads"
        double qty =
            double.tryParse(match.group(2)!) ?? 1.0; // e.g., "2" or "2.30"
        double cost =
            double.tryParse(match.group(3)!.replaceAll(',', '')) ??
            0.0; // e.g., "50.00"

        // Skip lines that are just table headers
        if (name.toLowerCase().contains('description') ||
            name.toLowerCase().contains('item')) {
          continue;
        }
        // Skip lines that are totals
        if (name.toLowerCase().contains('subtotal') ||
            name.toLowerCase().contains('tax')) {
          continue;
        }

        print("  > Found: $name, Qty: $qty, Cost: $cost");
        items.add(ServiceItem(name: name, qty: qty, cost: cost));
      } catch (e) {
        print("Error parsing line: ${match.group(0)}");
      }
    }
    return items;
  }
  // --- END OF NEW FUNCTIONS ---

  // --- MAIN BUILD METHOD (Unchanged) ---
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
                  _buildSectionCard(
                    title: 'Service Details',
                    children: [
                      TextFormField(
                        controller: _serviceNameController,
                        decoration: const InputDecoration(
                          labelText: 'Service Name (e.g., General Service)',
                          icon: Icon(Icons.label),
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
                            decoration: const InputDecoration(
                              labelText: 'Service Date',
                              icon: Icon(Icons.calendar_today),
                            ),
                            enabled: false,
                            style: const TextStyle(color: Colors.black),
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
                          icon: const Icon(Icons.speed),
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
                                    hint: const Text('Add part from template'),
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
                                  tooltip: 'Add selected template',
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
                        icon: const Icon(Icons.add),
                        label: const Text('Add Manual Item'),
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
                          icon: const Icon(Icons.attach_money),
                          prefixText: settings.currencySymbol,
                        ),
                        readOnly: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildSectionCard(
                    title: 'Vendor & Notes',
                    children: [
                      _isLoadingVendors
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<int>(
                              value: _selectedVendorId,
                              hint: const Text('Select Vendor (Optional)'),
                              decoration: const InputDecoration(
                                labelText: 'Vendor',
                                icon: Icon(Icons.store),
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
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          icon: Icon(Icons.notes),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

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
                            // "Add" button
                            if (index ==
                                _existingPhotos.length +
                                    _newImageFiles.length) {
                              return GestureDetector(
                                onTap:
                                    _pickImage, // This now calls the scanning function
                                child: Container(
                                  width: 100,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt,
                                        size: 30,
                                        color: Colors.grey,
                                      ),
                                      Text(
                                        "Scan Bill",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            // Existing photo
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
                            // New photo
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

  // (This helper is unchanged)
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

  // (This helper is unchanged)
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

  // (This helper is unchanged)
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

    _textRecognizer.close();

    super.dispose();
  }
}
