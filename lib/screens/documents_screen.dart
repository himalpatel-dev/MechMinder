import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // For path manipulation
import '../service/database_helper.dart';
import '../service/settings_provider.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;

  Map<String, List<Map<String, dynamic>>> _groupedDocuments = {};
  List<String> _groupTitles = [];
  final Set<String> _expandedGroups = {};

  // (Controllers for the dialog)
  final _docFormKey = GlobalKey<FormState>();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _customTypeController =
      TextEditingController(); // <-- NEW
  final TextEditingController _descriptionController = TextEditingController();

  String? _tempFilePath;

  // --- Define the standard list of types ---
  final List<String> _docTypes = ['License', 'Registration', 'Other'];

  @override
  void initState() {
    super.initState();
    _refreshDocumentList();
  }

  @override
  void dispose() {
    _typeController.dispose();
    _customTypeController.dispose(); // <-- NEW
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _refreshDocumentList() async {
    // (This function is unchanged)
    final allDocs = await dbHelper.queryAllGeneralDocuments();
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final List<String> groupTitles = [];
    const String generalGroup = 'General Documents';

    for (var doc in allDocs) {
      String vehicleName;
      if (doc[DatabaseHelper.columnVehicleId] == null) {
        vehicleName = generalGroup;
      } else {
        vehicleName =
            '${doc[DatabaseHelper.columnMake]} ${doc[DatabaseHelper.columnModel]}';
      }

      if (grouped[vehicleName] == null) {
        grouped[vehicleName] = [];
        groupTitles.add(vehicleName);
      }
      grouped[vehicleName]!.add(doc);
    }

    groupTitles.sort((a, b) {
      if (a == generalGroup) return -1;
      if (b == generalGroup) return 1;
      return a.compareTo(b);
    });

    if (groupTitles.isNotEmpty && _expandedGroups.isEmpty) {
      _expandedGroups.add(groupTitles.first);
    }

    setState(() {
      _groupedDocuments = grouped;
      _groupTitles = groupTitles;
      _isLoading = false;
    });
  }

  Future<void> _pickFile(Function setDialogState) async {
    // (This function is unchanged)
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

  // --- THIS IS THE UPDATED "ADD" DIALOG ---
  void _showAddDocumentDialog() async {
    final allVehicles = await dbHelper.queryAllVehiclesWithNextReminder();
    if (!mounted) return;

    int? selectedVehicleId;

    _typeController.text = 'License'; // Default
    _customTypeController.clear();
    _descriptionController.clear();
    _tempFilePath = null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Document'),
              content: SingleChildScrollView(
                child: Form(
                  key: _docFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedVehicleId,
                        hint: const Text('None (General)'),
                        decoration: const InputDecoration(
                          labelText: 'Vehicle (Optional)',
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('None (General)'),
                          ),
                          ...allVehicles.map((vehicle) {
                            return DropdownMenuItem<int>(
                              value: vehicle[DatabaseHelper.columnId],
                              child: Text(
                                '${vehicle[DatabaseHelper.columnMake]} ${vehicle[DatabaseHelper.columnModel]}',
                              ),
                            );
                          }),
                        ],
                        onChanged: (int? newValue) {
                          setDialogState(() {
                            selectedVehicleId = newValue;
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: _typeController.text,
                        decoration: const InputDecoration(
                          labelText: 'Document Type',
                        ),
                        items: _docTypes.map((String type) {
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

                      // --- THIS IS THE FIX ---
                      // Show this field ONLY if "Other" is selected
                      if (_typeController.text == 'Other')
                        TextFormField(
                          controller: _customTypeController,
                          decoration: const InputDecoration(
                            labelText: 'Please specify type',
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Please specify a type'
                              : null,
                        ),

                      // --- END OF FIX ---
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_tempFilePath == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please attach a file.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (_docFormKey.currentState!.validate()) {
                      await _saveDocument(selectedVehicleId);
                      if (mounted) {
                        Navigator.of(ctx).pop();
                      }
                      _refreshDocumentList();
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
  Future<void> _saveDocument(int? vehicleId) async {
    String? finalFilePath = _tempFilePath;

    // 1. Copy file to a permanent location
    if (_tempFilePath != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final String newPath = p.join(
        appDir.path,
        'general_documents',
        p.basename(_tempFilePath!),
      );
      final newFile = File(newPath);

      await newFile.parent.create(recursive: true);
      await File(_tempFilePath!).copy(newPath);
      finalFilePath = newPath;
      print("Saved document to: $finalFilePath");
    } else {
      return;
    }

    // --- THIS IS THE FIX ---
    // 2. Get the correct doc type
    String finalDocType;
    if (_typeController.text == 'Other') {
      finalDocType = _customTypeController.text;
    } else {
      finalDocType = _typeController.text;
    }
    // --- END OF FIX ---

    // 3. Create the row for the database
    Map<String, dynamic> row = {
      DatabaseHelper.columnVehicleId: vehicleId,
      DatabaseHelper.columnDocType: finalDocType, // <-- Use the final type
      DatabaseHelper.columnDescription: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      DatabaseHelper.columnFilePath: finalFilePath,
    };

    // 4. Insert
    await dbHelper.insertGeneralDocument(row);
  }

  // (Delete function is unchanged)
  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: const Text(
          'Are you sure you want to permanently delete this document? The attached file will also be deleted.',
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
              final doc = await dbHelper.queryGeneralDocumentById(id);
              if (doc != null && doc[DatabaseHelper.columnFilePath] != null) {
                final file = File(doc[DatabaseHelper.columnFilePath]);
                if (await file.exists()) {
                  await file.delete();
                }
              }
              await dbHelper.deleteGeneralDocument(id);
              if (mounted) {
                Navigator.of(ctx).pop();
              }
              _refreshDocumentList();
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
      appBar: AppBar(title: const Text('Manage Documents')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedDocuments.isEmpty
          ? const Center(
              child: Text(
                'No documents found. Tap "+" to add one.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0).copyWith(bottom: 80),
              itemCount: _groupTitles.length,
              itemBuilder: (context, index) {
                final groupName = _groupTitles[index];
                final documentsForGroup = _groupedDocuments[groupName]!;
                final bool isExpanded = _expandedGroups.contains(groupName);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Theme.of(context).highlightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Theme.of(context).highlightColor,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedGroups.remove(groupName);
                              } else {
                                _expandedGroups.add(groupName);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    groupName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Column(
                        children: [
                          if (isExpanded)
                            ...documentsForGroup.map((doc) {
                              return _buildDocumentCard(doc, settings);
                            }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddDocumentDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // (This helper is unchanged)
  Widget _buildDocumentCard(
    Map<String, dynamic> doc,
    SettingsProvider settings,
  ) {
    final String type = doc[DatabaseHelper.columnDocType] ?? 'Document';
    final String? description = doc[DatabaseHelper.columnDescription];
    final String? filePath = doc[DatabaseHelper.columnFilePath];

    return Card(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              // keep original color preference — used settings.primaryColor
              color: settings.primaryColor,
              width: 4,
            ),
          ),
        ),
        child: ListTile(
          leading: Icon(
            _getIconForDocType(type),
            color: settings.primaryColor,
            size: 30,
          ),
          title: Text(
            type,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: (description != null && description.isNotEmpty)
              ? Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                )
              : null,
          // keep single-line behavior if no subtitle; if description long, ListTile will handle it
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (filePath != null)
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.blue),
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
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete Document',
                onPressed: () {
                  _showDeleteConfirmation(doc[DatabaseHelper.columnId]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (This helper is unchanged)
  IconData _getIconForDocType(String type) {
    switch (type.toLowerCase()) {
      case 'license':
        return Icons.badge;
      case 'registration':
        return Icons.article;
      default:
        return Icons.description;
    }
  }
}
