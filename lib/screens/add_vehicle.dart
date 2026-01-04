import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart'; // <-- ADDED
import '../service/database_helper.dart'; // Make sure this path is correct
import 'package:provider/provider.dart';
import '../service/settings_provider.dart'; // Make sure this path is correct
import '../widgets/full_screen_photo_viewer.dart'; // <-- ADDED

class AddVehicleScreen extends StatefulWidget {
  final int? vehicleId;
  const AddVehicleScreen({super.key, this.vehicleId});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  // --- CONTROLLERS ---
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _variantController = TextEditingController();
  final TextEditingController _purchaseDateController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();

  String? _selectedFuelType;

  // --- PHOTO STATE ---
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _existingPhotos = []; // Photos already saved in DB
  final List<XFile> _newImageFiles = []; // Photos picked in this session
  // --- END PHOTO STATE ---

  bool _isEditMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.vehicleId != null;
    _purchaseDateController.text = DateTime.now().toIso8601String().split(
      'T',
    )[0];
    if (_isEditMode) {
      _loadVehicleData();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _variantController.dispose();
    _purchaseDateController.dispose();
    _colorController.dispose();
    _regNoController.dispose();
    _ownerNameController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleData() async {
    final data = await Future.wait([
      dbHelper.queryVehicleById(widget.vehicleId!),
      dbHelper.queryPhotosForParent(
        widget.vehicleId!,
        'vehicle',
      ), // <-- FETCH PHOTOS
    ]);

    final vehicle = data[0] as Map<String, dynamic>?;
    _existingPhotos = List<Map<String, dynamic>>.from(
      data[1] as List,
    ); // <-- SET EXISTING PHOTOS

    if (vehicle != null) {
      _makeController.text = vehicle[DatabaseHelper.columnMake] ?? '';
      _modelController.text = vehicle[DatabaseHelper.columnModel] ?? '';
      _variantController.text = vehicle[DatabaseHelper.columnVariant] ?? '';
      _purchaseDateController.text =
          vehicle[DatabaseHelper.columnPurchaseDate] ?? '';
      _selectedFuelType = vehicle[DatabaseHelper.columnFuelType];
      _colorController.text = vehicle[DatabaseHelper.columnVehicleColor] ?? '';
      _regNoController.text = vehicle[DatabaseHelper.columnRegNo] ?? '';
      _ownerNameController.text = vehicle[DatabaseHelper.columnOwnerName] ?? '';
      _odometerController.text =
          (vehicle[DatabaseHelper.columnCurrentOdometer] ?? '').toString();
    }
    setState(() {
      _isLoading = false;
    });
  }

  // --- PHOTO PICKER FUNCTION ---
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // Optimized: Reduces 12MP photos to ~1MP
        imageQuality: 70, // Optimized: Good quality, typically 10x smaller file
      );
      if (pickedFile == null) return;
      setState(() {
        _newImageFiles.add(pickedFile);
      });
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _saveVehicle() async {
    if (_formKey.currentState!.validate()) {
      Map<String, dynamic> row = {
        DatabaseHelper.columnMake: _makeController.text,
        DatabaseHelper.columnModel: _modelController.text,
        DatabaseHelper.columnVariant: _variantController.text.isNotEmpty
            ? _variantController.text
            : null,
        DatabaseHelper.columnPurchaseDate: _purchaseDateController.text,
        DatabaseHelper.columnFuelType: _selectedFuelType,
        DatabaseHelper.columnVehicleColor: _colorController.text.isNotEmpty
            ? _colorController.text
            : null,
        DatabaseHelper.columnRegNo: _regNoController.text,
        DatabaseHelper.columnOwnerName: _ownerNameController.text,
        DatabaseHelper.columnInitialOdometer:
            int.tryParse(_odometerController.text) ?? 0,
        DatabaseHelper.columnCurrentOdometer:
            int.tryParse(_odometerController.text) ?? 0,
      };

      int vehicleId;
      if (widget.vehicleId != null) {
        vehicleId = widget.vehicleId!;
        row[DatabaseHelper.columnId] = vehicleId;
        await dbHelper.updateVehicle(row);
      } else {
        vehicleId = await dbHelper.insertVehicle(row);
      }

      // --- PHOTO SAVE LOGIC ---
      for (var imageFile in _newImageFiles) {
        await dbHelper.insertPhoto({
          DatabaseHelper.columnParentId: vehicleId,
          DatabaseHelper.columnParentType: 'vehicle',
          DatabaseHelper.columnUri: imageFile.path,
        });
      }
      // --- END PHOTO SAVE LOGIC ---

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Helper widget for card sections
    Widget buildSectionCard(String title, List<Widget> children) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Divider(height: 20),
              ...children,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Vehicle' : 'Add New Vehicle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 60),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- 1. BASIC INFORMATION ---
              buildSectionCard('BASIC INFORMATION', [
                TextFormField(
                  controller: _makeController,
                  decoration: const InputDecoration(labelText: 'Brand *'),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? 'Enter Brand' : null,
                ),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Model *'),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? 'Enter Model' : null,
                ),
                TextFormField(
                  controller: _variantController,
                  decoration: const InputDecoration(
                    labelText: 'Variant (Optional)',
                  ),
                ),
                Row(
                  children: [
                    // Purchase Date (replaces Year)
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(
                                  _purchaseDateController.text,
                                ) ??
                                DateTime.now(),
                            firstDate: DateTime(1950),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            _purchaseDateController.text = pickedDate
                                .toIso8601String()
                                .split('T')[0];
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _purchaseDateController,
                            decoration: const InputDecoration(
                              labelText: 'Purchase Date *',
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? 'Select Purchase Date'
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Fuel Type
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFuelType,
                        hint: const Text('Select'),
                        decoration: const InputDecoration(
                          labelText: 'Fuel Type *',
                        ),
                        items: ['Petrol', 'Diesel', 'Electric', 'Hybrid', 'CNG']
                            .map(
                              (label) => DropdownMenuItem(
                                value: label,
                                child: Text(label),
                              ),
                            )
                            .toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedFuelType = newValue;
                          });
                        },
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Select Fuel Type'
                            : null,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(
                    labelText: 'Color (Optional)',
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // --- 2. REGISTRATION DETAILS & ODOMETER ---
              buildSectionCard('REGISTRATION DETAILS', [
                TextFormField(
                  controller: _regNoController,
                  decoration: const InputDecoration(
                    labelText: 'Registration Number *',
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter Registration No.'
                      : null,
                ),
                TextFormField(
                  controller: _ownerNameController,
                  decoration: const InputDecoration(labelText: 'Owner Name *'),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter Owner Name'
                      : null,
                ),
                TextFormField(
                  controller: _odometerController,
                  decoration: InputDecoration(
                    labelText: _isEditMode
                        ? 'Current Odometer'
                        : 'Initial Odometer',
                    suffixText: settings.unitType,
                    // Use a theme-aware color for disabled state
                    filled: true,
                    fillColor: _isEditMode
                        ? Theme.of(context).disabledColor.withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  enabled: !_isEditMode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter Odometer'
                      : null,
                ),
              ]),

              const SizedBox(height: 20),

              // --- 3. PHOTO GALLERY ---
              buildSectionCard('PHOTO GALLERY', [
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        _existingPhotos.length + _newImageFiles.length + 1,
                    itemBuilder: (context, index) {
                      // ADD PHOTO BUTTON
                      if (index ==
                          _existingPhotos.length + _newImageFiles.length) {
                        return GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                Text(
                                  "Add Photo",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // EXISTING PHOTOS (already in DB)
                      if (index < _existingPhotos.length) {
                        final photo = _existingPhotos[index];
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                final paths = _existingPhotos
                                    .map(
                                      (p) =>
                                          p[DatabaseHelper.columnUri] as String,
                                    )
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
                              child: Container(
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

                      // NEW PHOTOS (picked in this session)
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
              ]),

              const SizedBox(height: 20),

              // --- SAVE BUTTON ---
              ElevatedButton(
                onPressed: _saveVehicle,
                child: Text(_isEditMode ? 'UPDATE VEHICLE' : 'ADD VEHICLE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
