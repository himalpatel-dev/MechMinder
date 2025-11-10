import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct

class ExpensesTab extends StatefulWidget {
  final int vehicleId;
  const ExpensesTab({super.key, required this.vehicleId});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  List<String> _allCategories = [];

  // Controllers (unchanged)
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshExpenseList();
  }

  Future<void> _refreshExpenseList() async {
    // (This function is unchanged)
    final data = await Future.wait([
      dbHelper.queryExpensesForVehicle(widget.vehicleId),
      dbHelper.queryDistinctExpenseCategories(),
    ]);

    final allExpenses = data[0] as List<Map<String, dynamic>>;
    final allCategories = data[1] as List<String>;

    setState(() {
      _expenses = allExpenses;
      _allCategories = allCategories;
      _isLoading = false;
    });
  }

  void _showAddExpenseDialog(
    SettingsProvider settings, {
    Map<String, dynamic>? expense,
  }) {
    // (This function is unchanged)
    bool isEditing = expense != null;

    if (isEditing) {
      _dateController.text = expense[DatabaseHelper.columnServiceDate] ?? '';
      _categoryController.text = expense[DatabaseHelper.columnCategory] ?? '';
      _amountController.text = (expense[DatabaseHelper.columnTotalCost] ?? '')
          .toString();
      _notesController.text = expense[DatabaseHelper.columnNotes] ?? '';
    } else {
      _dateController.text = DateTime.now().toIso8601String().split('T')[0];
      _categoryController.text = '';
      _amountController.text = '';
      _notesController.text = '';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Expense' : 'Add New Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
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
                      _dateController.text = pickedDate.toIso8601String().split(
                        'T',
                      )[0];
                    }
                  },
                ),
                Autocomplete<String>(
                  initialValue: TextEditingValue(
                    text: _categoryController.text,
                  ),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return _allCategories.where((String option) {
                      return option.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  onSelected: (String selection) {
                    _categoryController.text = selection;
                  },
                  fieldViewBuilder:
                      (
                        BuildContext context,
                        TextEditingController fieldController,
                        FocusNode fieldFocusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        _categoryController.text = fieldController.text;
                        fieldController.addListener(() {
                          _categoryController.text = fieldController.text;
                        });

                        return TextFormField(
                          controller: fieldController,
                          focusNode: fieldFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Category (e.g., Fuel, Insurance)',
                          ),
                        );
                      },
                  optionsViewBuilder:
                      (
                        BuildContext context,
                        AutocompleteOnSelected<String> onSelected,
                        Iterable<String> options,
                      ) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(
                                    index,
                                  );
                                  return InkWell(
                                    onTap: () {
                                      onSelected(option);
                                    },
                                    child: ListTile(title: Text(option)),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                ),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: settings.currencySymbol,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmation(expense[DatabaseHelper.columnId]);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveExpense(expense);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // (This function is unchanged)
  void _saveExpense(Map<String, dynamic>? expense) async {
    bool isEditing = expense != null;
    Map<String, dynamic> row = {
      DatabaseHelper.columnVehicleId: widget.vehicleId,
      DatabaseHelper.columnServiceDate: _dateController.text,
      DatabaseHelper.columnCategory: _categoryController.text,
      DatabaseHelper.columnTotalCost: double.tryParse(_amountController.text),
      DatabaseHelper.columnNotes: _notesController.text,
    };
    if (isEditing) {
      row[DatabaseHelper.columnId] = expense[DatabaseHelper.columnId];
      await dbHelper.updateExpense(row);
    } else {
      await dbHelper.insertExpense(row);
    }
    _refreshExpenseList();
  }

  // (This function is unchanged)
  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text(
          'Are you sure you want to permanently delete this expense?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await dbHelper.deleteExpense(id);
              Navigator.of(ctx).pop();
              _refreshExpenseList();
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

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
          ? const Center(
              child: Text(
                'No expenses found. \nTap the "+" button to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final expense = _expenses[index];

                // --- THIS IS THE NEW LOGIC ---
                final String? notes = expense[DatabaseHelper.columnNotes];
                final String date = expense[DatabaseHelper.columnServiceDate];

                // Create the subtitle text
                String subtitleText = 'Date: $date';
                if (notes != null && notes.isNotEmpty) {
                  subtitleText += ' ($notes)'; // Add notes in parentheses
                }
                // --- END OF NEW LOGIC ---

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(
                      _getIconForCategory(
                        expense[DatabaseHelper.columnCategory],
                      ),
                      color: Colors.green[700],
                      size: 36,
                    ),

                    title: Text(
                      expense[DatabaseHelper.columnCategory] ?? 'Expense',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    // --- THIS IS THE NEW SUBTITLE ---
                    subtitle: Text(
                      subtitleText,
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      maxLines: 1, // Will truncate with "..."
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: false, // We only have two lines now
                    // --- END OF NEW SUBTITLE ---
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min, // Keep row compact
                      children: [
                        Text(
                          '${settings.currencySymbol}${expense[DatabaseHelper.columnTotalCost] ?? '0.00'}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: Colors.grey[400]),
                      ],
                    ),

                    onTap: () {
                      _showAddExpenseDialog(settings, expense: expense);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddExpenseDialog(settings, expense: null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // (Helper for smart icons - unchanged)
  IconData _getIconForCategory(String? category) {
    if (category == null) return Icons.monetization_on;
    String catLower = category.toLowerCase();
    if (catLower.contains('fuel') ||
        catLower.contains('petrol') ||
        catLower.contains('gas')) {
      return Icons.local_gas_station;
    }

    // 🛡 Insurance
    if (catLower.contains('insurance') || catLower.contains('policy')) {
      return Icons.shield;
    }

    // 🧼 Washing / Cleaning
    if (catLower.contains('wash') ||
        catLower.contains('clean') ||
        catLower.contains('detailing')) {
      return Icons.wash;
    }

    // 🅿 Parking
    if (catLower.contains('parking') || catLower.contains('park')) {
      return Icons.local_parking;
    }

    // 🛞 Tyres
    if (catLower.contains('tire') ||
        catLower.contains('tyre') ||
        catLower.contains('tyres')) {
      return Icons.tire_repair;
    }

    // ⚙ Servicing / Maintenance
    if (catLower.contains('service') ||
        catLower.contains('maintenance') ||
        catLower.contains('checkup') ||
        catLower.contains('inspection')) {
      return Icons.build;
    }

    // 🛢 Oil change
    if (catLower.contains('oil') || catLower.contains('engine oil')) {
      return Icons.oil_barrel;
    }

    // 🧯 Brake pads / brake oil
    if (catLower.contains('brake')) {
      return Icons.car_repair;
    }

    // 🔋 Battery
    if (catLower.contains('battery') || catLower.contains('accumulator')) {
      return Icons.battery_charging_full;
    }

    // 💨 Air filter / filter replacement
    if (catLower.contains('filter')) {
      return Icons.filter_alt;
    }

    // 💡 Lights / bulbs / indicators
    if (catLower.contains('light') ||
        catLower.contains('bulb') ||
        catLower.contains('indicator')) {
      return Icons.lightbulb;
    }

    // 🚙 Accessories / modification
    if (catLower.contains('accessory') ||
        catLower.contains('modification') ||
        catLower.contains('sticker')) {
      return Icons.car_repair;
    }

    // 🧰 Tools / spare parts
    if (catLower.contains('spare') ||
        catLower.contains('parts') ||
        catLower.contains('tool')) {
      return Icons.handyman;
    }

    // 🚗 General vehicle cost
    if (catLower.contains('vehicle') ||
        catLower.contains('car') ||
        catLower.contains('bike')) {
      return Icons.directions_car;
    }

    // 🧾 Tax / RTO / registration / license
    if (catLower.contains('rto') ||
        catLower.contains('tax') ||
        catLower.contains('registration') ||
        catLower.contains('license')) {
      return Icons.receipt_long;
    }

    // 🧳 Trip / travel / toll / highway
    if (catLower.contains('trip') ||
        catLower.contains('toll') ||
        catLower.contains('highway') ||
        catLower.contains('travel')) {
      return Icons.add_road;
    }

    // 🧯 Emergency / breakdown / towing
    if (catLower.contains('breakdown') ||
        catLower.contains('towing') ||
        catLower.contains('emergency')) {
      return Icons.warning;
    }

    // ⛓ Chain / sprocket (for bikes)
    if (catLower.contains('chain') || catLower.contains('sprocket')) {
      return Icons.settings;
    }

    // 🧊 Coolant
    if (catLower.contains('coolant')) {
      return Icons.ac_unit;
    }

    // 🧍 Driver / labour charge
    if (catLower.contains('driver') || catLower.contains('labour')) {
      return Icons.person;
    }

    // 🏪 Workshop / garage visit
    if (catLower.contains('garage') ||
        catLower.contains('workshop') ||
        catLower.contains('mechanic')) {
      return Icons.garage;
    }
    return Icons.monetization_on; // Default
  }

  // --- WE NO LONGER NEED THE _buildIconRow HELPER ---
}
