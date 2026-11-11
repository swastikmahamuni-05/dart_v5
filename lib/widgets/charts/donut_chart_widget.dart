import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/tank.dart';

class DonutChartWidget extends StatelessWidget {
  final List<Tank> tanks;

  const DonutChartWidget({
    Key? key,
    required this.tanks,
  }) : super(key: key);

  Color _getTankColor(int index) {
    final List<Color> colors = [
      const Color(0xFF00B0FF), // Neon Blue
      const Color(0xFF1DE9B6), // Neon Teal
      const Color(0xFFE040FB), // Neon Purple
      const Color(0xFFFFB300), // Neon Amber
      const Color(0xFFFF3366), // Neon Pink
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);

    if (tanks.isEmpty) {
      return Center(
        child: Text(
          'No tank data available',
          style: TextStyle(color: textMutedColor),
        ),
      );
    }

    final double totalVolume = tanks.fold(0.0, (sum, tank) => sum + tank.currentVolumeLitres);

    List<PieChartSectionData> sections = [];
    for (int i = 0; i < tanks.length; i++) {
      final tank = tanks[i];
      final double volume = tank.currentVolumeLitres;
      final double percentage = totalVolume > 0 ? (volume / totalVolume) * 100 : 0.0;

      sections.add(
        PieChartSectionData(
          color: _getTankColor(i),
          value: volume > 0 ? volume : 1.0, // avoid division issues
          title: percentage > 8 ? '${percentage.toStringAsFixed(0)}%' : '',
          radius: 35,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Row(
      children: [
        // The Donut Pie Chart
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 42,
                    sections: sections,
                  ),
                ),
                // Center labels inside the hole
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        color: textMutedColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(totalVolume / 1000).toStringAsFixed(1)}k L',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Legend sidebar
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(tanks.length, (index) {
              final tank = tanks[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getTankColor(index),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tank.tankName,
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(tank.currentVolumeLitres / 1000).toStringAsFixed(1)}k L',
                      style: TextStyle(
                        color: textMutedColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
