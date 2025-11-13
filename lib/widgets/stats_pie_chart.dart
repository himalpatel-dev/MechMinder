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
      aspectRatio: 1.2,
      // --- THIS IS THE FIX ---
      child: Card(
        elevation: 4, // Add a standard elevation
        // We REMOVE the hard-coded color.
        // The card will now be white in Light Mode and dark gray in Dark Mode.
        // color: const Color.fromARGB(255, 255, 255, 255), // <-- REMOVED
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              'Spending Breakdown',
              // Use a theme-aware text style
              style: Theme.of(context).textTheme.titleLarge,
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
            const SizedBox(height: 16),
            // The legend
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
      // --- END OF FIX ---
    );
  }

  List<PieChartSectionData> _buildChartSections(double totalValue) {
    // (This function is unchanged, the white text with a shadow
    // already looks good on both light and dark backgrounds)
    return List.generate(widget.spendingData.length, (i) {
      final isTouched = (i == touchedIndex);
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final item = widget.spendingData[i];
      final double value = (item['total'] as num).toDouble();
      final double percentage = (value / totalValue) * 100;

      return PieChartSectionData(
        color: _chartColors[i % _chartColors.length],
        value: value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          // Add a shadow to make white text readable on light colors
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2),
          ],
        ),
      );
    });
  }

  List<Widget> _buildChartLegend() {
    // (This function is unchanged, the default text color
    // will be handled by the theme)
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
