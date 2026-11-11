import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class BarChartWidget extends StatelessWidget {
  final List<double> dailyConsumption;
  final Color barColor;

  const BarChartWidget({
    Key? key,
    required this.dailyConsumption,
    this.barColor = Colors.tealAccent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white.withOpacity(0.3) : const Color(0xFF64748B);
    final gridColor = isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFE2E8F0);

    if (dailyConsumption.isEmpty) {
      return Center(
        child: Text(
          'No consumption data available',
          style: TextStyle(color: labelColor),
        ),
      );
    }

    final double maxVal = dailyConsumption.reduce((curr, next) => curr > next ? curr : next);
    // Round max value up to nearest 500 or 1000 for nice axis grid
    final double maxAxisY = (maxVal * 1.15 / 500).ceil() * 500;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxAxisY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => const Color(0xFF0F172A).withOpacity(0.9),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.round()} L',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text('');
                return Text(
                  '${(value / 1000).toStringAsFixed(1)}k L',
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final int index = dailyConsumption.length - 1 - value.toInt();
                if (index >= 0 && index < dailyConsumption.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'D-$index',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: gridColor,
              strokeWidth: 1.0,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(dailyConsumption.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: dailyConsumption[index],
                gradient: LinearGradient(
                  colors: [
                    barColor.withOpacity(0.6),
                    barColor,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 12,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxAxisY,
                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
