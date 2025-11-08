import 'package:flutter/material.dart';
import '../service/database_helper.dart';
import 'stats_pie_chart.dart';

class StatsTab extends StatefulWidget {
  final int vehicleId;
  const StatsTab({super.key, required this.vehicleId});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final dbHelper = DatabaseHelper.instance;
  double _totalSpending = 0.0;
  List<Map<String, dynamic>> _spendingByCategory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final total = await dbHelper.queryTotalSpending(widget.vehicleId);
    final byCategory = await dbHelper.querySpendingByCategory(widget.vehicleId);

    // Sort categories from most to least expensive
    byCategory.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));

    setState(() {
      _totalSpending = total;
      _spendingByCategory = byCategory;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // --- Total Spending Card ---
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'TOTAL LIFETIME SPENDING',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '\$${_totalSpending.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const SizedBox(height: 20),
          StatsPieChart(spendingData: _spendingByCategory),

          // --- END OF NEW WIDGET ---
          const SizedBox(height: 20),

          // --- Spending by Category Card ---
          Card(
            elevation: 4,
            child: Column(
              children: [
                const ListTile(
                  title: Text(
                    'Spending by Category',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const Divider(height: 1),
                if (_spendingByCategory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No spending data found.'),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _spendingByCategory.length,
                    itemBuilder: (context, index) {
                      final item = _spendingByCategory[index];
                      String category = item[DatabaseHelper.columnCategory];
                      double total = (item['total'] as num).toDouble();

                      return ListTile(
                        title: Text(category),
                        trailing: Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // We can add charts here later
        ],
      ),
    );
  }
}
