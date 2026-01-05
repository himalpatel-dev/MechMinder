import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/database_helper.dart';
import '../service/settings_provider.dart';
import '../widgets/common_popup.dart';

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

  final _expenseFormKey = GlobalKey<FormState>();

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
        return CommonPopup(
          title: isEditing ? 'Edit Expense' : 'Add New Expense',
          content: Form(
            key: _expenseFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  _dateController,
                  "Date",
                  Icons.calendar_today,
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
                const SizedBox(height: 12),
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

                        return _buildTextField(
                          fieldController,
                          "Category (e.g., Fuel)",
                          Icons.category,
                          focusNode: fieldFocusNode,
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
                            borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 12),
                _buildTextField(
                  _amountController,
                  "Amount",
                  Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                const SizedBox(height: 12),
                _buildTextField(
                  _notesController,
                  "Notes",
                  Icons.notes,
                  maxLines: 2,
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
                if (_expenseFormKey.currentState!.validate()) {
                  _saveExpense(expense);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: settings.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
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
    int maxLines = 1,
    FocusNode? focusNode,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      focusNode: focusNode,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

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
    if (_currentGrouping == ExpenseGrouping.byDate) {
      sortedGroups.sort((a, b) => b.compareTo(a)); // Descending date
    } else {
      sortedGroups.sort(); // Alphabetical category
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildCustomSegmentedControl(isDark, primaryColor),
                ),

                Expanded(
                  child: _expenses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Expenses Yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to add one.',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: sortedGroups.length,
                          itemBuilder: (context, index) {
                            final groupName = sortedGroups[index];
                            final expensesForGroup =
                                groupedExpenses[groupName]!;

                            // Calculate total for this group
                            double groupTotal = 0;
                            for (var e in expensesForGroup) {
                              groupTotal +=
                                  (e[DatabaseHelper.columnTotalCost] ?? 0.0)
                                      as double;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 4.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _currentGrouping ==
                                                ExpenseGrouping.byDate
                                            ? _formatMonthHeader(groupName)
                                            : groupName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey.shade800,
                                        ),
                                      ),
                                      Text(
                                        '${settings.currencySymbol}${groupTotal.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...expensesForGroup.map((expense) {
                                  return _buildExpenseCard(
                                    expense,
                                    settings,
                                    isDark,
                                    primaryColor,
                                  );
                                }),
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddExpenseDialog(settings, expense: null);
        },
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Expense",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(
    Map<String, dynamic> expense,
    SettingsProvider settings,
    bool isDark,
    Color primaryColor,
  ) {
    final String? notes = expense[DatabaseHelper.columnNotes];
    final String date = expense[DatabaseHelper.columnServiceDate];
    final String category =
        expense[DatabaseHelper.columnCategory] ?? 'Uncategorized';

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
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showAddExpenseDialog(settings, expense: expense);
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForCategory(category),
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
                        category,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (notes != null && notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            notes,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${settings.currencySymbol}${expense[DatabaseHelper.columnTotalCost] ?? '0.00'}',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForCategory(String? category) {
    if (category == null) return Icons.monetization_on;
    String catLower = category.toLowerCase();
    if (catLower.contains('fuel') ||
        catLower.contains('petrol') ||
        catLower.contains('gas')) {
      return Icons.local_gas_station;
    }
    if (catLower.contains('insurance') || catLower.contains('policy')) {
      return Icons.shield;
    }
    if (catLower.contains('wash') ||
        catLower.contains('clean') ||
        catLower.contains('detailing')) {
      return Icons.wash;
    }
    if (catLower.contains('parking') || catLower.contains('park')) {
      return Icons.local_parking;
    }
    if (catLower.contains('tire') ||
        catLower.contains('tyre') ||
        catLower.contains('tyres')) {
      return Icons.tire_repair;
    }
    if (catLower.contains('service') ||
        catLower.contains('maintenance') ||
        catLower.contains('checkup') ||
        catLower.contains('inspection')) {
      return Icons.build;
    }
    if (catLower.contains('oil') || catLower.contains('engine oil')) {
      return Icons.oil_barrel;
    }
    if (catLower.contains('brake')) {
      return Icons.car_repair;
    }
    if (catLower.contains('battery') || catLower.contains('accumulator')) {
      return Icons.battery_charging_full;
    }
    if (catLower.contains('filter')) {
      return Icons.filter_alt;
    }
    if (catLower.contains('light') ||
        catLower.contains('bulb') ||
        catLower.contains('indicator')) {
      return Icons.lightbulb;
    }
    if (catLower.contains('accessory') ||
        catLower.contains('modification') ||
        catLower.contains('sticker')) {
      return Icons.car_repair;
    }
    if (catLower.contains('spare') ||
        catLower.contains('parts') ||
        catLower.contains('tool')) {
      return Icons.handyman;
    }
    if (catLower.contains('vehicle') ||
        catLower.contains('car') ||
        catLower.contains('bike')) {
      return Icons.directions_car;
    }
    if (catLower.contains('rto') ||
        catLower.contains('tax') ||
        catLower.contains('registration') ||
        catLower.contains('license')) {
      return Icons.receipt_long;
    }
    if (catLower.contains('trip') ||
        catLower.contains('toll') ||
        catLower.contains('highway') ||
        catLower.contains('travel')) {
      return Icons.add_road;
    }
    if (catLower.contains('breakdown') ||
        catLower.contains('towing') ||
        catLower.contains('emergency')) {
      return Icons.warning;
    }
    if (catLower.contains('chain') || catLower.contains('sprocket')) {
      return Icons.settings;
    }
    if (catLower.contains('coolant')) {
      return Icons.ac_unit;
    }
    if (catLower.contains('driver') || catLower.contains('labour')) {
      return Icons.person;
    }
    if (catLower.contains('garage') ||
        catLower.contains('workshop') ||
        catLower.contains('mechanic')) {
      return Icons.garage;
    }
    return Icons.monetization_on;
  }

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

  Widget _buildCustomSegmentedControl(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildSegmentButton(
            text: 'By Date',
            icon: Icons.calendar_month,
            isSelected: _currentGrouping == ExpenseGrouping.byDate,
            onTap: () =>
                setState(() => _currentGrouping = ExpenseGrouping.byDate),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          _buildSegmentButton(
            text: 'By Category',
            icon: Icons.category,
            isSelected: _currentGrouping == ExpenseGrouping.byCategory,
            onTap: () =>
                setState(() => _currentGrouping = ExpenseGrouping.byCategory),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String text,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF424242) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.grey : Colors.grey.shade600),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.grey : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
