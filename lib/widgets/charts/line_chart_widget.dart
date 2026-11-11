import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartWidget extends StatelessWidget {
  final List<double> dataPoints;
  final Color lineColor;
  final bool isPercent;
  final double maxScale;
  final String unit;
  final String timeframe;

  const LineChartWidget({
    Key? key,
    required this.dataPoints,
    this.lineColor = const Color(0xFF00E5FF),
    this.isPercent = true,
    this.maxScale = 100.0,
    this.unit = '%',
    this.timeframe = '24 Hours',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white.withOpacity(0.3) : const Color(0xFF64748B);
    final gridColor = isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0);

    if (dataPoints.isEmpty) {
      return Center(
        child: Text(
          'No history data available',
          style: TextStyle(color: labelColor),
        ),
      );
    }

    const double minY = 0.0;
    const double maxY = 1.0;

    List<FlSpot> spots = [];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i].clamp(0.0, 1.0)));
    }
    if (spots.length == 1) {
      spots.add(FlSpot(1.0, spots[0].y));
    }

    return LineChart(
      LineChartData(
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
              interval: 0.25,
              getTitlesWidget: (value, meta) {
                final displayVal = isPercent ? (value * 100).toInt() : (value * maxScale).toInt();
                return Text(
                  '$displayVal$unit',
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1.0,
              getTitlesWidget: (value, meta) {
                final int idx = value.toInt();
                if (idx < 0 || idx >= spots.length) return const SizedBox.shrink();
                
                final int total = spots.length;
                bool shouldShow = false;
                if (idx == total - 1) {
                  shouldShow = true;
                } else if (idx == 0) {
                  shouldShow = true;
                } else if (total >= 6 && idx == (total / 2).floor()) {
                  shouldShow = true;
                } else if (total >= 10 && (idx == (total / 4).floor() || idx == (3 * total / 4).floor())) {
                  shouldShow = true;
                }

                if (!shouldShow) return const SizedBox.shrink();

                String label = '';
                if (idx == total - 1) {
                  label = 'Now';
                } else {
                  final int stepsFromEnd = total - 1 - idx;
                  if (timeframe == '1 Hour') {
                    final int mins = ((stepsFromEnd / (total - 1)) * 60).round();
                    label = '${mins}m';
                  } else if (timeframe == '6 Hours') {
                    final int hrs = ((stepsFromEnd / (total - 1)) * 6).round();
                    label = '${hrs}h';
                  } else if (timeframe == '7 Days') {
                    final int days = ((stepsFromEnd / (total - 1)) * 7).round();
                    label = '${days}d';
                  } else {
                    final int hrs = ((stepsFromEnd / (total - 1)) * 24).round();
                    label = '${hrs}h';
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                lineColor,
                lineColor.withOpacity(0.6),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  lineColor.withOpacity(0.2),
                  lineColor.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color(0xFF0F172A).withOpacity(0.9),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final displayVal = isPercent 
                    ? (barSpot.y * 100).toStringAsFixed(1) 
                    : (barSpot.y * maxScale).toStringAsFixed(0);
                return LineTooltipItem(
                  '${isPercent ? "Level" : "Rate"}: $displayVal$unit',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
