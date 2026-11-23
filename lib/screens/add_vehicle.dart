import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart'; // <-- ADDED
import '../service/database_helper.dart'; // Make sure this path is correct
import 'package:provider/provider.dart';
import '../service/settings_provider.dart'; // Make sure this path is correct
import '../widgets/full_screen_photo_viewer.dart'; // <-- ADDED
import '../service/notification_service.dart'; // Add this line
import '../service/file_storage.dart';

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
  // Existing photos the user removed; deleted only when the form is saved.
  final Set<int> _removedPhotoIds = {};
  // --- END PHOTO STATE ---

  bool _isEditMode = false;
  bool _isLoading = true;
  bool _isSaving = false;
  // True once the user changed something; leaving then asks first.
  bool _isDirty = false;

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

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

    if (!mounted) return;
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
        _isDirty = true;
      });
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _saveVehicle() async {
    // Ignore extra taps while saving (a double tap created two vehicles).
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final unitType = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).unitType;

    try {
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

      if (widget.vehicleId != null) {
        row[DatabaseHelper.columnId] = widget.vehicleId!;
      }

      // Copy photos out of the picker's cache into app storage, then save
      // the vehicle and its photos together.
      final List<String> photoPaths = [];
      for (final imageFile in _newImageFiles) {
        photoPaths.add(
          await FileStorage.importFile(
            imageFile.path,
            FileStorage.photosFolder,
          ),
        );
      }
      final int vehicleId = await dbHelper.saveVehicleWithPhotos(
        vehicleRow: row,
        newPhotoPaths: photoPaths,
      );
      await dbHelper.deletePhotosByIds(_removedPhotoIds);

      await NotificationService().checkAndShowOdometerReminders(
        vehicleId: vehicleId,
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
          content: Text('Could not save the vehicle: $e'),
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
        content: const Text('Your changes to this vehicle will be lost.'),
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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // --- MODERN INPUT DECORATION HELPER ---
    InputDecoration modernInputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
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
            _isEditMode ? 'Edit Vehicle' : 'Add New Vehicle',
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
                      _buildSectionHeader("Vehicle Details", isDark),
                      const SizedBox(height: 16),

                      // --- ROW 1: BRAND ---
                      TextFormField(
                        controller: _makeController,
                        decoration: modernInputDecoration(
                          "Company",
                          Icons.directions_car,
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // --- ROW 2: MODEL ---
                      TextFormField(
                        controller: _modelController,
                        decoration: modernInputDecoration(
                          "Model",
                          Icons.directions_car_filled,
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // --- ROW 3: VARIANT & DATE ---
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _variantController,
                              decoration: modernInputDecoration(
                                "Variant (Opt)",
                                Icons.merge_type,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
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
                                  _markDirty();
                                }
                              },
                              child: AbsorbPointer(
                                child: TextFormField(
                                  controller: _purchaseDateController,
                                  decoration: modernInputDecoration(
                                    "Purchase Date",
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
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- ROW 4: COLOR & FUEL TYPE ---
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _colorController,
                              decoration: modernInputDecoration(
                                "Color",
                                Icons.palette,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedFuelType,
                              decoration: modernInputDecoration(
                                "Fuel Type",
                                Icons.local_gas_station,
                              ),
                              items:
                                  [
                                        'Petrol',
                                        'Diesel',
                                        'Electric',
                                        'Hybrid',
                                        'CNG',
                                      ]
                                      .map(
                                        (label) => DropdownMenuItem(
                                          value: label,
                                          child: Text(label),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedFuelType = val),
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader("Registration & Owner", isDark),
                      const SizedBox(height: 16),

                      // --- REG NO ---
                      TextFormField(
                        controller: _regNoController,
                        decoration: modernInputDecoration(
                          "Registration No.",
                          Icons.featured_video,
                        ),
                        textCapitalization:
                            TextCapitalization.characters, // Auto-caps
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // --- OWNER NAME ---
                      TextFormField(
                        controller: _ownerNameController,
                        decoration: modernInputDecoration(
                          "Owner Name",
                          Icons.person,
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // --- ODOMETER ---
                      TextFormField(
                        controller: _odometerController,
                        decoration: modernInputDecoration(
                          _isEditMode ? 'Current Odometer' : 'Initial Odometer',
                          Icons.speed,
                        ).copyWith(suffixText: settings.unitType),
                        enabled: !_isEditMode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Required'
                            : null,
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader("Gallery", isDark),
                      const SizedBox(height: 16),

                      // --- MODERN PHOTO PICKER ---
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
                    onPressed: _isSaving ? null : _saveVehicle,
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
                            _isEditMode ? 'UPDATE VEHICLE' : 'SAVE VEHICLE',
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

  // --- HELPER WRAPPERS ---
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

  Widget _buildPhotoPicker(bool isDark, Color primaryColor) {
    return Column(
      children: [
        if (_existingPhotos.isEmpty && _newImageFiles.isEmpty)
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade400,
                  style: BorderStyle.solid,
                ), // Dashed look simulated with grey
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 48,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap to add photos",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Add Button
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade900
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Center(
                      child: Icon(Icons.add, size: 40, color: primaryColor),
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
                      // Deleted when the form is saved, so Back keeps it.
                      setState(() {
                        _removedPhotoIds.add(
                          photo[DatabaseHelper.columnId] as int,
                        );
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
                  return _buildPhotoItem(
                    File(file.path),
                    null, // No full screen for unsaved yet, or could add
                    () {
                      setState(() {
                        _newImageFiles.removeAt(index);
                      });
                    },
                  );
                }),
              ],
            ),
          ),
      ],
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
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade300,
              image: DecorationImage(
                // Decode at thumbnail size instead of the full photo.
                image: ResizeImage(FileImage(file), width: 360),
                fit: BoxFit.cover,
                onError: (_, _) {},
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 16, // Adjust for margin
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
