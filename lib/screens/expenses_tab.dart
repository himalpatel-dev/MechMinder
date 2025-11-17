import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart'; // Make sure this path is correct
import '../service/settings_provider.dart'; // Make sure this path is correct

enum ExpenseGrouping { byDate, byCategory }

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
  ExpenseGrouping _currentGrouping = ExpenseGrouping.byDate;

  // --- THIS IS THE FIX: A FormKey for the dialog ---
  final _expenseFormKey = GlobalKey<FormState>();

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
          content: SizedBox(
            // --- THIS IS THE FIX ---
            // You can set any width you want.
            // Using MediaQuery makes it responsive (e.g., 90% of screen width)
            width: MediaQuery.of(context).size.width * 0.9,

            // --- END OF FIX ---
            child: SingleChildScrollView(
              // --- THIS IS THE FIX: Wrap content in a Form ---
              child: Form(
                key: _expenseFormKey, // Assign the key
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Date',
                        suffixIcon: Icon(
                          Icons.calendar_today,
                          color: settings.primaryColor,
                        ),
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
                          _dateController.text = pickedDate
                              .toIso8601String()
                              .split('T')[0];
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
                              // --- THIS IS THE FIX: Add validator ---
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a category';
                                }
                                return null;
                              },
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
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final String option = options
                                              .elementAt(index);
                                          return InkWell(
                                            onTap: () {
                                              onSelected(option);
                                            },
                                            child: ListTile(
                                              title: Text(option),
                                            ),
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
                      // --- THIS IS THE FIX: Add validator ---
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
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
                // --- THIS IS THE FIX: Check form validity ---
                if (_expenseFormKey.currentState!.validate()) {
                  _saveExpense(expense);
                  Navigator.of(context).pop();
                }
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
          //  style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.black,
            ),
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

    // (Grouping logic is unchanged)
    final Map<String, List<Map<String, dynamic>>> groupedExpenses = {};
    if (_currentGrouping == ExpenseGrouping.byDate) {
      for (var expense in _expenses) {
        final String monthYear = expense[DatabaseHelper.columnServiceDate]
            .substring(0, 7);
        if (groupedExpenses[monthYear] == null) {
          groupedExpenses[monthYear] = [];
        }
        groupedExpenses[monthYear]!.add(expense);
      }
    } else {
      for (var expense in _expenses) {
        final String category =
            expense[DatabaseHelper.columnCategory] ?? 'Uncategorized';
        if (groupedExpenses[category] == null) {
          groupedExpenses[category] = [];
        }
        groupedExpenses[category]!.add(expense);
      }
    }
    final sortedGroups = groupedExpenses.keys.toList();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // (Toggle button is unchanged)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SegmentedButton<ExpenseGrouping>(
                    segments: [
                      ButtonSegment(
                        value: ExpenseGrouping.byDate,
                        label: Text('By Date'),
                        icon: Icon(
                          Icons.calendar_month,
                          color: settings.primaryColor,
                        ),
                      ),
                      ButtonSegment(
                        value: ExpenseGrouping.byCategory,
                        label: Text('By Category'),
                        icon: Icon(Icons.label, color: settings.primaryColor),
                      ),
                    ],
                    selected: {_currentGrouping},
                    onSelectionChanged: (Set<ExpenseGrouping> newSelection) {
                      setState(() {
                        _currentGrouping = newSelection.first;
                      });
                    },
                  ),
                ),

                Expanded(
                  child: _expenses.isEmpty
                      ? const Center(
                          child: Text(
                            'No expenses found. \nTap the "+" button to add one!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: sortedGroups.length,
                          itemBuilder: (context, index) {
                            final groupName = sortedGroups[index];
                            final expensesForGroup =
                                groupedExpenses[groupName]!;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              elevation: 2,
                              clipBehavior: Clip.antiAlias,
                              child: ExpansionTile(
                                shape: const Border(),
                                collapsedShape: const Border(),
                                title: Text(
                                  _currentGrouping == ExpenseGrouping.byDate
                                      ? _formatMonthHeader(groupName)
                                      : groupName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    // color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                initiallyExpanded: false,
                                children: expensesForGroup.map((expense) {
                                  return _buildExpenseCard(expense, settings);
                                }).toList(),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddExpenseDialog(settings, expense: null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // (This widget builds the individual expense card - unchanged)
  Widget _buildExpenseCard(
    Map<String, dynamic> expense,
    SettingsProvider settings,
  ) {
    final String? notes = expense[DatabaseHelper.columnNotes];
    final String date = expense[DatabaseHelper.columnServiceDate];
    String subtitleText = 'Date: $date';
    if (notes != null && notes.isNotEmpty) {
      subtitleText += ' ($notes)';
    }

    return InkWell(
      onTap: () {
        _showAddExpenseDialog(settings, expense: expense);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: ListTile(
          leading: Icon(
            _getIconForCategory(expense[DatabaseHelper.columnCategory]),
            color: settings.primaryColor,
            size: 36,
          ),
          title: Text(
            expense[DatabaseHelper.columnCategory] ?? 'Expense',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            subtitleText,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: false,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
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
        ),
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
    return Icons.monetization_on;
  }

  // (Helper to format "2025-11" - unchanged)
  String _formatMonthHeader(String monthYear) {
    try {
      final parts = monthYear.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = DateTime(year, month);

      const monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${monthNames[date.month - 1]} $year';
    } catch (e) {
      return monthYear;
    }
  }
}
