import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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

  final _docFormKey = GlobalKey<FormState>();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _customTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _tempFilePath;

  final List<String> _docTypes = [
    'License',
    'Registration',
    'Insurance',
    'PUC',
    'Invoice',
    'Warranty Card',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _refreshDocumentList();
  }

  @override
  void dispose() {
    _typeController.dispose();
    _customTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _refreshDocumentList() async {
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
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setDialogState(() {
        _tempFilePath = result.files.single.path;
      });
    }
  }

  void _showAddDocumentDialog() async {
    final allVehicles = await dbHelper.queryAllVehiclesWithNextReminder();
    if (!mounted) return;

    int? selectedVehicleId;
    _typeController.text = 'License';
    _customTypeController.clear();
    _descriptionController.clear();
    _tempFilePath = null;

    showDialog(
      context: context,
      builder: (ctx) {
        final primaryColor = Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).primaryColor;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Add Document',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _docFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedVehicleId,
                        isExpanded: true,
                        decoration: _inputDecoration(
                          'Related Vehicle (Optional)',
                          Icons.directions_car,
                          primaryColor,
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
                                overflow: TextOverflow.ellipsis,
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _typeController.text,
                        decoration: _inputDecoration(
                          'Document Type',
                          Icons.category,
                          primaryColor,
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
                      if (_typeController.text == 'Other') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _customTypeController,
                          decoration: _inputDecoration(
                            'Specify Type',
                            Icons.edit,
                            primaryColor,
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: _inputDecoration(
                          'Description (Optional)',
                          Icons.description,
                          primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // File Picker Area
                      InkWell(
                        onTap: () => _pickFile(setDialogState),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _tempFilePath == null
                                    ? Icons.attach_file
                                    : Icons.check_circle,
                                color: _tempFilePath == null
                                    ? Colors.grey
                                    : Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _tempFilePath == null
                                      ? 'Tap to attach file (PDF/Img)'
                                      : p.basename(_tempFilePath!),
                                  style: TextStyle(
                                    color: _tempFilePath == null
                                        ? Colors.grey.shade600
                                        : Colors.black87,
                                    fontWeight: _tempFilePath == null
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                      if (mounted) Navigator.of(ctx).pop();
                      _refreshDocumentList();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
    Color primaryColor,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      isDense: true,
    );
  }

  Future<void> _saveDocument(int? vehicleId) async {
    String? finalFilePath = _tempFilePath;

    if (_tempFilePath != null) {
      final appDir = await getApplicationDocumentsDirectory();
      // Ensure unique filename to prevent overwrites
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(_tempFilePath!)}';
      final String newPath = p.join(appDir.path, 'general_documents', fileName);
      final newFile = File(newPath);

      await newFile.parent.create(recursive: true);
      await File(_tempFilePath!).copy(newPath);
      finalFilePath = newPath;
    } else {
      return;
    }

    String finalDocType;
    if (_typeController.text == 'Other') {
      finalDocType = _customTypeController.text;
    } else {
      finalDocType = _typeController.text;
    }

    Map<String, dynamic> row = {
      DatabaseHelper.columnVehicleId: vehicleId,
      DatabaseHelper.columnDocType: finalDocType,
      DatabaseHelper.columnDescription: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      DatabaseHelper.columnFilePath: finalFilePath,
    };

    await dbHelper.insertGeneralDocument(row);
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
              if (mounted) Navigator.of(ctx).pop();
              _refreshDocumentList();
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
      appBar: AppBar(
        title: Text(
          'Manage Documents',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey.shade900,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.grey.shade900,
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _groupedDocuments.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _groupTitles.length,
              itemBuilder: (context, index) {
                final groupName = _groupTitles[index];
                final documentsForGroup = _groupedDocuments[groupName]!;
                final bool isExpanded = _expandedGroups.contains(groupName);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- PARENT HEADER ---
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedGroups.remove(groupName);
                          } else {
                            _expandedGroups.add(groupName);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black26
                                  : Colors.grey.shade200,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isExpanded ? Icons.folder_open : Icons.folder,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                groupName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${documentsForGroup.length}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- INDENTED CHILDREN ---
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: isExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                              ), // Indentation
                              child: Column(
                                children: documentsForGroup.map((doc) {
                                  return _buildDocumentCard(
                                    doc,
                                    isDark,
                                    primaryColor,
                                  );
                                }).toList(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDocumentDialog,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text(
          "Add Document",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
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
            "No Documents Found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Store licenses, insurance, invoices & more.",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(
    Map<String, dynamic> doc,
    bool isDark,
    Color primaryColor,
  ) {
    final String type = doc[DatabaseHelper.columnDocType] ?? 'Document';
    final String? description = doc[DatabaseHelper.columnDescription];
    final String? filePath = doc[DatabaseHelper.columnFilePath];

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ), // Removed side margins handled by parent padding
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 4, // Softer shadow for children
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: filePath != null
              ? () async {
                  final result = await OpenFile.open(filePath);
                  if (result.type != ResultType.done && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${result.message}')),
                    );
                  }
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForDocType(type),
                    color: primaryColor,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                      if (description != null && description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                    size: 22,
                  ),
                  onPressed: () =>
                      _showDeleteConfirmation(doc[DatabaseHelper.columnId]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForDocType(String type) {
    switch (type.toLowerCase()) {
      case 'license':
        return Icons.badge_outlined;
      case 'registration':
      case 'rc':
        return Icons.featured_play_list_outlined;
      case 'insurance':
        return Icons.shield_outlined;
      case 'puc':
        return Icons.eco_outlined;
      case 'invoice':
      case 'bill':
        return Icons.receipt_long_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
