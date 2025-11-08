import 'package:flutter/material.dart';
import '../service/database_helper.dart';

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

  // Controllers for the "Add Expense" dialog
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
    final allExpenses = await dbHelper.queryExpensesForVehicle(
      widget.vehicleId,
    );
    setState(() {
      _expenses = allExpenses;
      _isLoading = false;
    });
  }

  void _showAddExpenseDialog() {
    // Clear old text and set default date
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
    _categoryController.text = '';
    _amountController.text = '';
    _notesController.text = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Expense'),
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
                      initialDate: DateTime.now(),
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
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category (e.g., Fuel, Insurance)',
                  ),
                ),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$',
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(onPressed: _saveExpense, child: const Text('Save')),
          ],
        );
      },
    );
  }

  void _saveExpense() async {
    Map<String, dynamic> row = {
      DatabaseHelper.columnVehicleId: widget.vehicleId,
      DatabaseHelper.columnServiceDate:
          _dateController.text, // Using this column as 'date'
      DatabaseHelper.columnCategory: _categoryController.text,
      DatabaseHelper.columnTotalCost: double.tryParse(
        _amountController.text,
      ), // Using this column as 'amount'
      DatabaseHelper.columnNotes: _notesController.text,
    };

    await dbHelper.insertExpense(row);

    if (mounted) {
      Navigator.of(context).pop(); // Close the dialog
    }
    _refreshExpenseList(); // Refresh the list
  }

  @override
  Widget build(BuildContext context) {
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
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final expense = _expenses[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(
                      expense[DatabaseHelper.columnCategory] ?? 'Expense',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Date: ${expense[DatabaseHelper.columnServiceDate]}\nNotes: ${expense[DatabaseHelper.columnNotes] ?? 'N/A'}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '\$${expense[DatabaseHelper.columnTotalCost] ?? '0.00'}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
