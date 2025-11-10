import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MiniSpendingChart extends StatelessWidget {
  // We'll pass in the two main spending numbers
  final double serviceSpending;
  final double expenseSpending;

  const MiniSpendingChart({
    super.key,
    required this.serviceSpending,
    required this.expenseSpending,
  });

  @override
  Widget build(BuildContext context) {
    final double totalSpending = serviceSpending + expenseSpending;

    // Don't show a chart if there's no data
    if (totalSpending == 0) {
      return const Center(
        child: Text(
          'No spending data',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return PieChart(
      PieChartData(
        // We don't want labels on the chart itself
        pieTouchData: PieTouchData(touchCallback: (evt, resp) {}),
        sectionsSpace: 2,
        centerSpaceRadius: 15, // Make it a "donut" chart
        sections: [
          // Section 1: Services
          PieChartSectionData(
            value: serviceSpending,
            color: Colors.blue.shade400,
            radius: 10,
            showTitle: false,
          ),
          // Section 2: Other Expenses (like fuel)
          PieChartSectionData(
            value: expenseSpending,
            color: Colors.orange.shade400,
            radius: 10,
            showTitle: false,
          ),
        ],
      ),
    );
  }
}
