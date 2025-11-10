import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/database_helper.dart';
import 'dart:io'; // Required to display File objects
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';

class AddVehicleScreen extends StatefulWidget {
  final int? vehicleId;

  const AddVehicleScreen({
    super.key,
    this.vehicleId, // Make it optional
  });

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final dbHelper = DatabaseHelper.instance;

  // Controllers to get the text from the form fields
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();

  final _formKey = GlobalKey<FormState>(); // For form validation

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImageFiles = [];
  List<Map<String, dynamic>> _existingPhotos = [];

  Map<String, dynamic>? _existingVehicle;
  bool _isEditMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // --- CHECK FOR EDIT MODE ---
    if (widget.vehicleId != null) {
      _isEditMode = true;
      _loadVehicleData();
    }
  }

  void _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery, // Or use ImageSource.camera
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

  void _saveVehicle() async {
    if (_formKey.currentState!.validate()) {
      // --- 1. CREATE THE DATA ROW ---
      Map<String, dynamic> row = {
        DatabaseHelper.columnMake: _makeController.text,
        DatabaseHelper.columnModel: _modelController.text,
        DatabaseHelper.columnYear: int.tryParse(_yearController.text),
        DatabaseHelper.columnRegNo: _regNoController.text,
        // Only update current odometer, not initial
        DatabaseHelper.columnCurrentOdometer: int.tryParse(
          _odometerController.text,
        ),
      };

      int vehicleId;

      // --- 2. CHECK IF EDITING OR INSERTING ---
      if (_isEditMode) {
        // This is an UPDATE
        row[DatabaseHelper.columnId] = widget.vehicleId!;
        // We don't update initial odometer, so we fetch it
        row[DatabaseHelper.columnInitialOdometer] =
            _existingVehicle![DatabaseHelper.columnInitialOdometer];

        await dbHelper.updateVehicle(row);
        vehicleId = widget.vehicleId!;
        print('Updated vehicle with id: $vehicleId');
      } else {
        // This is a NEW vehicle
        row[DatabaseHelper.columnInitialOdometer] = int.tryParse(
          _odometerController.text,
        );

        vehicleId = await dbHelper.insertVehicle(row);
        print('Inserted vehicle with id: $vehicleId');
      }

      // --- 3. SAVE NEW PHOTOS ---
      // (This loop only saves *newly added* photos)
      for (var imageFile in _newImageFiles) {
        // <-- CHECK THIS LINE
        Map<String, dynamic> photoRow = {
          DatabaseHelper.columnParentId: vehicleId,
          DatabaseHelper.columnParentType: 'vehicle',
          DatabaseHelper.columnUri: imageFile.path,
        };
        await dbHelper.insertPhoto(photoRow);
      }
      print(
        'Saved ${_newImageFiles.length} new photos.',
      ); // <-- CHECK THIS LINE

      // --- 4. GO BACK ---
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadVehicleData() async {
    setState(() {
      _isLoading = true;
    });
    _existingVehicle = await dbHelper.queryVehicleById(widget.vehicleId!);
    _existingPhotos = List.from(
      await dbHelper.queryPhotosForParent(widget.vehicleId!, 'vehicle'),
    );

    // Pre-fill controllers
    if (_existingVehicle != null) {
      _makeController.text = _existingVehicle![DatabaseHelper.columnMake];
      _modelController.text = _existingVehicle![DatabaseHelper.columnModel];
      _yearController.text =
          (_existingVehicle![DatabaseHelper.columnYear] ?? '').toString();
      _regNoController.text =
          _existingVehicle![DatabaseHelper.columnRegNo] ?? '';
      _odometerController.text =
          (_existingVehicle![DatabaseHelper.columnCurrentOdometer] ?? '')
              .toString();
    }

    // We'll load the existing photos in a future step.
    // For now, this just edits the text.

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Vehicle' : 'Add New Vehicle'),
      ),
      body:
          _isLoading // --- ADD LOADING CHECK ---
          ? const Center(child: CircularProgressIndicator())
          : Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey, // Assign key to the form
                    child: ListView(
                      children: [
                        // --- Make ---
                        TextFormField(
                          controller: _makeController,
                          decoration: const InputDecoration(
                            labelText: 'Make (e.g., Honda)',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a make';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // --- Model ---
                        TextFormField(
                          controller: _modelController,
                          decoration: const InputDecoration(
                            labelText: 'Model (e.g., CB Shine)',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a model';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // --- Year ---
                        TextFormField(
                          controller: _yearController,
                          decoration: const InputDecoration(
                            labelText: 'Year (e.g., 2023)',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 10),

                        // --- Registration No ---
                        TextFormField(
                          controller: _regNoController,
                          decoration: const InputDecoration(
                            labelText: 'Registration No (e.g., GJ 05 AB 1234)',
                          ),
                        ),
                        const SizedBox(height: 10),

                        // --- Initial Odometer ---
                        // --- Initial Odometer ---
                        TextFormField(
                          controller: _odometerController,
                          decoration: InputDecoration(
                            labelText: _isEditMode
                                ? 'Current Odometer'
                                : 'Initial Odometer',
                            suffixText: settings.unitType,

                            // --- THIS IS THE FIX ---
                            // We will manually fill the box with a gray color
                            // when in edit mode to make it look disabled.
                            filled:
                                _isEditMode, // Tell it to fill the background
                            fillColor: _isEditMode
                                ? Colors.grey[200]
                                : null, // Set the color
                            // --- END OF FIX ---
                          ),
                          enabled:
                              !_isEditMode, // This stops the user from tapping it
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- ADD THIS NEW PHOTO SECTION ---
                        const Text(
                          'Add Photos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            // The new count is OLD photos + NEW photos + 1 (for add button)
                            itemCount:
                                _existingPhotos.length +
                                _newImageFiles.length +
                                1,
                            itemBuilder: (context, index) {
                              // --- BUILD THE "ADD" BUTTON ---
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

                              // --- BUILD AN "EXISTING PHOTO" TILE ---
                              if (index < _existingPhotos.length) {
                                final photo = _existingPhotos[index];
                                final photoPath =
                                    photo[DatabaseHelper.columnUri];
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
                                    // --- DELETE BUTTON for EXISTING photo ---
                                    Positioned(
                                      top: 0,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () async {
                                          // 1. Delete from database
                                          await dbHelper.deletePhoto(
                                            photo[DatabaseHelper.columnId],
                                          );
                                          // 2. Remove from list and update UI
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
                                  // --- DELETE BUTTON for NEW photo ---
                                  Positioned(
                                    top: 0,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () {
                                        // Just remove from the list
                                        setState(() {
                                          _newImageFiles.removeAt(
                                            newPhotoIndex,
                                          );
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
                        // --- END OF PHOTO SECTION ---

                        // --- Save Button ---
                        ElevatedButton(
                          onPressed: _saveVehicle,
                          child: const Text('Save Vehicle'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
