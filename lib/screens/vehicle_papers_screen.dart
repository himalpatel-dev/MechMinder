import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // For path manipulation
import '../service/database_helper.dart';
import '../service/settings_provider.dart';

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

  // --- NEW CONTROLLERS ---
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _referenceNoController = TextEditingController();
  final TextEditingController _providerNameController =
      TextEditingController(); // <-- NEW
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  // --- END NEW ---

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
    _providerNameController.dispose(); // <-- NEW
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

  // --- UPDATED DIALOG ---
  void _showAddEditPaperDialog({Map<String, dynamic>? paper}) async {
    final bool isEditing = paper != null;

    _typeController.clear();
    _referenceNoController.clear();
    _providerNameController.clear(); // <-- NEW
    _descriptionController.clear();
    _costController.clear();
    _expiryDateController.clear();
    _tempFilePath = null;

    if (isEditing) {
      _typeController.text = paper[DatabaseHelper.columnPaperType] ?? '';
      _referenceNoController.text =
          paper[DatabaseHelper.columnReferenceNo] ?? '';
      _providerNameController.text =
          paper[DatabaseHelper.columnProviderName] ?? ''; // <-- NEW
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
            return AlertDialog(
              title: Text(isEditing ? 'Edit Paper' : 'Add New Paper'),
              content: SizedBox(
                // --- THIS IS THE FIX ---
                // You can set any width you want.
                // Using MediaQuery makes it responsive (e.g., 90% of screen width)
                width: MediaQuery.of(context).size.width * 0.9,

                // --- END OF FIX ---
                child: SingleChildScrollView(
                  child: Form(
                    key: _paperFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _typeController.text,
                          decoration: const InputDecoration(
                            labelText: 'Document Type',
                          ),
                          autofocus: true,
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
                        TextFormField(
                          controller: _referenceNoController,
                          decoration: const InputDecoration(
                            labelText: 'Reference No (e.g., Policy #)',
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Please enter a reference'
                              : null,
                        ),
                        // --- NEW FIELD ---
                        TextFormField(
                          controller: _providerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Provider (e.g., HDFC Ergo)',
                          ),
                        ),
                        // --- END NEW ---
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                          ),
                        ),
                        TextFormField(
                          controller: _costController,
                          decoration: InputDecoration(
                            labelText: 'Cost (Optional)',
                            prefixText: Provider.of<SettingsProvider>(
                              context,
                              listen: false,
                            ).currencySymbol,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        GestureDetector(
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
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _expiryDateController,
                              decoration: const InputDecoration(
                                labelText: 'Expiry Date (Optional)',
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _tempFilePath == null
                                    ? 'No file attached'
                                    : p.basename(_tempFilePath!),
                                style: const TextStyle(color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.attach_file),
                              onPressed: () => _pickFile(setDialogState),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- UPDATED SAVE FUNCTION ---
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
        print("Saved file to: $finalFilePath");
      }
    }

    Map<String, dynamic> row = {
      DatabaseHelper.columnVehicleId: vehicleId,
      DatabaseHelper.columnPaperType: _typeController.text,
      DatabaseHelper.columnReferenceNo: _referenceNoController.text,
      DatabaseHelper.columnProviderName: _providerNameController.text.isNotEmpty
          ? _providerNameController.text
          : null, // <-- NEW
      DatabaseHelper.columnDescription: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      DatabaseHelper.columnCost: double.tryParse(_costController.text),
      DatabaseHelper.columnPaperExpiryDate:
          _expiryDateController.text.isNotEmpty
          ? _expiryDateController.text
          : null,
      DatabaseHelper.columnFilePath: finalFilePath,
    };

    if (paperId != null) {
      row[DatabaseHelper.columnId] = paperId;
      await dbHelper.updateVehiclePaper(row);
    } else {
      await dbHelper.insertVehiclePaper(row);
    }
  }

  // (Delete function is unchanged)
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
              foregroundColor: Colors.black,
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

  // (Build method is unchanged)
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _papers.isEmpty
          ? const Center(
              child: Text(
                'No vehicle papers found. Tap "+" to add one.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0).copyWith(bottom: 80),
              itemCount: _papers.length,
              itemBuilder: (context, index) {
                final paper = _papers[index];
                return _buildPaperCard(paper, settings);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddEditPaperDialog(paper: null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- UPDATED PAPER CARD ---
  Widget _buildPaperCard(
    Map<String, dynamic> paper,
    SettingsProvider settings,
  ) {
    final String type = paper[DatabaseHelper.columnPaperType];
    final String referenceNo = paper[DatabaseHelper.columnReferenceNo] ?? 'N/A';
    final String? providerName =
        paper[DatabaseHelper.columnProviderName]; // <-- NEW
    final String? description = paper[DatabaseHelper.columnDescription];
    final double? cost = paper[DatabaseHelper.columnCost];
    final String? expiryDate = paper[DatabaseHelper.columnPaperExpiryDate];
    final String? filePath = paper[DatabaseHelper.columnFilePath];

    bool isExpired = false;
    if (expiryDate != null) {
      final String today = DateTime.now().toIso8601String().split('T')[0];
      isExpired = expiryDate.compareTo(today) < 0;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          _showAddEditPaperDialog(paper: paper);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getIconForPaperType(type),
                    color: isExpired ? Colors.red[700] : settings.primaryColor,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // --- NEW: Show Provider Name if it exists ---
                        if (providerName != null && providerName.isNotEmpty)
                          Text(
                            providerName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          Text(
                            // Fallback to reference number
                            referenceNo,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (cost != null && cost > 0)
                    Text(
                      '${settings.currencySymbol}${cost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  if (filePath != null)
                    IconButton(
                      icon: const Icon(
                        Icons.document_scanner,
                        color: Colors.blue,
                      ),
                      tooltip: 'Open File',
                      onPressed: () async {
                        final result = await OpenFile.open(filePath);
                        if (result.type != ResultType.done) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${result.message}')),
                          );
                        }
                      },
                    ),
                ],
              ),
              // --- NEW: Show Reference No here if Provider exists ---
              if (providerName != null && providerName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Ref: $referenceNo',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (expiryDate != null) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.event_busy,
                      color: isExpired ? Colors.red[700] : Colors.grey[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isExpired
                          ? 'EXPIRED: $expiryDate'
                          : 'Expires: $expiryDate',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isExpired ? Colors.red[700] : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // (This helper is unchanged)
  IconData _getIconForPaperType(String type) {
    switch (type.toLowerCase()) {
      case 'insurance':
        return Icons.shield;
      case 'puc':
        return Icons.cloud_outlined;
      case 'registration':
        return Icons.badge;
      default:
        return Icons.description;
    }
  }
}
