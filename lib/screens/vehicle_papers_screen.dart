import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../service/database_helper.dart';
import '../service/settings_provider.dart';
import '../widgets/common_popup.dart';

class VehiclePapersScreen extends StatefulWidget {
  final int vehicleId;
  const VehiclePapersScreen({super.key, required this.vehicleId});

  @override
  State<VehiclePapersScreen> createState() => _VehiclePapersScreenState();
}

class _VehiclePapersScreenState extends State<VehiclePapersScreen> {
  final dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _papers = [];

  final _paperFormKey = GlobalKey<FormState>();

  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _referenceNoController = TextEditingController();
  final TextEditingController _providerNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    _refreshPapersList();
  }

  @override
  void dispose() {
    _typeController.dispose();
    _referenceNoController.dispose();
    _providerNameController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _refreshPapersList() async {
    final allPapers = await dbHelper.queryVehiclePapersForVehicle(
      widget.vehicleId,
    );
    setState(() {
      _papers = allPapers;
      _isLoading = false;
    });
  }

  Future<void> _pickFile(Function setDialogState) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setDialogState(() {
        _tempFilePath = result.files.single.path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File attached: ${p.basename(_tempFilePath!)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showAddEditPaperDialog({Map<String, dynamic>? paper}) async {
    final bool isEditing = paper != null;

    _typeController.clear();
    _referenceNoController.clear();
    _providerNameController.clear();
    _descriptionController.clear();
    _costController.clear();
    _expiryDateController.clear();
    _tempFilePath = null;

    if (isEditing) {
      _typeController.text = paper[DatabaseHelper.columnPaperType] ?? '';
      _referenceNoController.text =
          paper[DatabaseHelper.columnReferenceNo] ?? '';
      _providerNameController.text =
          paper[DatabaseHelper.columnProviderName] ?? '';
      _descriptionController.text =
          paper[DatabaseHelper.columnDescription] ?? '';
      _costController.text = (paper[DatabaseHelper.columnCost] ?? '')
          .toString();
      _expiryDateController.text =
          paper[DatabaseHelper.columnPaperExpiryDate] ?? '';
      _tempFilePath = paper[DatabaseHelper.columnFilePath];
    } else {
      _typeController.text = 'Insurance';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CommonPopup(
              title: isEditing ? 'Edit Paper' : 'Add New Paper',
              content: Form(
                key: _paperFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _typeController.text,
                      decoration: InputDecoration(
                        labelText: 'Document Type',
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: ['Insurance', 'PUC', 'Battery', 'Other'].map((
                        String type,
                      ) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          _typeController.text = newValue ?? 'Other';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _referenceNoController,
                      'Reference No (e.g., Policy #)',
                      Icons.numbers,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter a reference'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _providerNameController,
                      'Provider (e.g., HDFC Ergo)',
                      Icons.business,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _descriptionController,
                      'Description (Optional)',
                      Icons.description,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _costController,
                      'Cost (Optional)',
                      Icons.attach_money,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _expiryDateController,
                      'Expiry Date (Optional)',
                      Icons.calendar_today,
                      readOnly: true,
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          _expiryDateController.text = pickedDate
                              .toIso8601String()
                              .split('T')[0];
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _tempFilePath == null
                                  ? 'No file attached'
                                  : p.basename(_tempFilePath!),
                              style: TextStyle(
                                color: _tempFilePath == null
                                    ? Colors.grey
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                fontWeight: _tempFilePath == null
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.upload_file),
                            onPressed: () => _pickFile(setDialogState),
                            tooltip: "Pick File",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showDeleteConfirmation(paper[DatabaseHelper.columnId]);
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_paperFormKey.currentState!.validate()) {
                      await _savePaper(
                        widget.vehicleId,
                        isEditing ? paper[DatabaseHelper.columnId] : null,
                      );
                      if (mounted) {
                        Navigator.of(ctx).pop();
                      }
                      _refreshPapersList();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Provider.of<SettingsProvider>(
                      context,
                      listen: false,
                    ).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Future<void> _savePaper(int? vehicleId, int? paperId) async {
    String? finalFilePath = _tempFilePath;

    if (_tempFilePath != null) {
      final appDir = await getApplicationDocumentsDirectory();
      if (!_tempFilePath!.startsWith(appDir.path)) {
        final String newPath = p.join(
          appDir.path,
          'vehicle_papers',
          p.basename(_tempFilePath!),
        );
        final newFile = File(newPath);
        await newFile.parent.create(recursive: true);
        await File(_tempFilePath!).copy(newPath);
        finalFilePath = newPath;
      }
    }

    Map<String, dynamic> row = {
      DatabaseHelper.columnVehicleId: vehicleId,
      DatabaseHelper.columnPaperType: _typeController.text,
      DatabaseHelper.columnReferenceNo: _referenceNoController.text,
      DatabaseHelper.columnProviderName: _providerNameController.text.isNotEmpty
          ? _providerNameController.text
          : null,
      DatabaseHelper.columnDescription: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      DatabaseHelper.columnCost: double.tryParse(_costController.text),
      DatabaseHelper.columnPaperExpiryDate:
          _expiryDateController.text.isNotEmpty
          ? _expiryDateController.text
          : null,
      DatabaseHelper.columnCreatedAt: DateTime.now().toIso8601String(),
      DatabaseHelper.columnFilePath: finalFilePath,
    };

    if (paperId != null) {
      row[DatabaseHelper.columnId] = paperId;
      await dbHelper.updateVehiclePaper(row);
    } else {
      await dbHelper.insertVehiclePaper(row);
    }
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Paper?'),
        content: const Text(
          'Are you sure you want to permanently delete this paper? The attached file will also be deleted.',
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
            ),
            onPressed: () async {
              final paper = await dbHelper.queryVehiclePaperById(id);
              if (paper != null &&
                  paper[DatabaseHelper.columnFilePath] != null) {
                final file = File(paper[DatabaseHelper.columnFilePath]);
                if (await file.exists()) {
                  try {
                    await file.delete();
                  } catch (e) {
                    print("Error deleting file: $e");
                  }
                }
              }
              await dbHelper.deleteVehiclePaper(id);
              if (mounted) {
                Navigator.of(ctx).pop();
              }
              _refreshPapersList();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _papers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Papers Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add documents.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _papers.length,
              itemBuilder: (context, index) {
                final paper = _papers[index];
                return _buildPaperCard(paper, settings, isDark, primaryColor);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddEditPaperDialog(paper: null);
        },
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Paper",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPaperCard(
    Map<String, dynamic> paper,
    SettingsProvider settings,
    bool isDark,
    Color primaryColor,
  ) {
    final String type = paper[DatabaseHelper.columnPaperType];
    final String referenceNo = paper[DatabaseHelper.columnReferenceNo] ?? 'N/A';
    final String? providerName = paper[DatabaseHelper.columnProviderName];
    final String? description = paper[DatabaseHelper.columnDescription];
    final double? cost = paper[DatabaseHelper.columnCost];
    final String? expiryDate = paper[DatabaseHelper.columnPaperExpiryDate];
    final String? filePath = paper[DatabaseHelper.columnFilePath];

    bool isExpired = false;
    if (expiryDate != null) {
      final String today = DateTime.now().toIso8601String().split('T')[0];
      isExpired = expiryDate.compareTo(today) < 0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isExpired
            ? Border.all(color: Colors.red.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showAddEditPaperDialog(paper: paper);
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.red.withOpacity(0.1)
                            : primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForPaperType(type),
                        color: isExpired ? Colors.red : primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark
                                  ? Colors.white
                                  : Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (providerName != null && providerName.isNotEmpty)
                            Text(
                              providerName,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else
                            Text(
                              referenceNo,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          if (providerName != null &&
                              providerName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Ref: $referenceNo',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (filePath != null)
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        color: primaryColor,
                        tooltip: 'View Document',
                        onPressed: () async {
                          final result = await OpenFile.open(filePath);
                          if (result.type != ResultType.done) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${result.message}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (expiryDate != null)
                      Row(
                        children: [
                          Icon(
                            isExpired
                                ? Icons.error_outline
                                : Icons.calendar_today,
                            size: 14,
                            color: isExpired ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpired
                                ? 'Expired: $expiryDate'
                                : 'Expires: $expiryDate',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isExpired ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(), // Spacer if no expiry date
                    if (cost != null && cost > 0)
                      Text(
                        '${settings.currencySymbol}${cost.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForPaperType(String type) {
    switch (type.toLowerCase()) {
      case 'insurance':
        return Icons.shield;
      case 'puc':
        return Icons.cloud_outlined;
      case 'registration':
        return Icons.badge;
      case 'battery':
        return Icons.battery_charging_full;
      default:
        return Icons.description;
    }
  }
}
