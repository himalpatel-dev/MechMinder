import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../service/database_helper.dart';

class StatsPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> spendingData;
  const StatsPieChart({super.key, required this.spendingData});

  @override
  State<StatsPieChart> createState() => _StatsPieChartState();
}

class _StatsPieChartState extends State<StatsPieChart> {
  int touchedIndex = -1;

  // A list of pre-defined colors for the chart
  final List<Color> _chartColors = [
    Colors.blue.shade400,
    Colors.red.shade400,
    Colors.green.shade400,
    Colors.orange.shade400,
    Colors.purple.shade400,
    Colors.yellow.shade700,
    Colors.teal.shade400,
    Colors.pink.shade400,
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.spendingData.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no data
    }

    double total = widget.spendingData.fold(
      0.0,
      (sum, item) => sum + (item['total'] as num),
    );

    return AspectRatio(
      aspectRatio: 1.3,
      child: Card(
        elevation: 0,
        color: Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Spending Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!
                            .touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _buildChartSections(total),
                ),
              ),
            ),
            // This builds the "legend" or key for the chart
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center,
              children: _buildChartLegend(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // This function converts our data into chart sections
  List<PieChartSectionData> _buildChartSections(double totalValue) {
    return List.generate(widget.spendingData.length, (i) {
      final isTouched = (i == touchedIndex);
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final item = widget.spendingData[i];
      final double value = (item['total'] as num).toDouble();
      final double percentage = (value / totalValue) * 100;

      return PieChartSectionData(
        color: _chartColors[i % _chartColors.length], // Cycle through colors
        value: value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  // This function builds the little colored squares for the legend
  List<Widget> _buildChartLegend() {
    return List.generate(widget.spendingData.length, (i) {
      final item = widget.spendingData[i];
      final String category = item[DatabaseHelper.columnCategory];

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              color: _chartColors[i % _chartColors.length],
            ),
            const SizedBox(width: 4),
            Text(category),
          ],
        ),
      );
    });
  }
}
