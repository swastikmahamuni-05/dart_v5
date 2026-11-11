import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/historical_graph_config.dart';
import '../../models/tank.dart';
import '../../models/tank_history.dart';
import '../../providers/tank_provider.dart';
import '../../theme/app_theme.dart';

// Retain legacy enum for backwards compatibility across existing callers
enum ChartMetric {
  percentFull,
  waterHeight,
  waterAvailable,
  waterUsed,
}

extension ChartMetricExt on ChartMetric {
  String get label {
    switch (this) {
      case ChartMetric.percentFull:
        return 'Water Level';
      case ChartMetric.waterHeight:
        return 'Water Height';
      case ChartMetric.waterAvailable:
        return 'Water Available';
      case ChartMetric.waterUsed:
        return 'Water Used';
    }
  }

  String get unit {
    switch (this) {
      case ChartMetric.percentFull:
        return '%';
      case ChartMetric.waterHeight:
        return 'm';
      case ChartMetric.waterAvailable:
      case ChartMetric.waterUsed:
        return 'L';
    }
  }

  bool get isBarChart {
    return this == ChartMetric.waterUsed;
  }

  GraphMetricDefinition toDefinition() {
    switch (this) {
      case ChartMetric.percentFull:
        return GraphMetricDefinition.waterLevel;
      case ChartMetric.waterHeight:
        return GraphMetricDefinition.waterDepth;
      case ChartMetric.waterAvailable:
        return GraphMetricDefinition.waterAvailable;
      case ChartMetric.waterUsed:
        return GraphMetricDefinition.waterUsed;
    }
  }
}

class AnalyticsPoint {
  final DateTime timestamp;
  final double value;

  AnalyticsPoint({
    required this.timestamp,
    required this.value,
  });
}

/// Standard LEVELS Historical Graph Widget.
/// Adheres strictly to the 42 rules of the LEVELS Historical Graph Standard.
class TankAnalyticsGraph extends StatefulWidget {
  final Tank tank;
  final ChartMetric? lockedMetric;
  final GraphMetricDefinition? metricDefinition;

  const TankAnalyticsGraph({
    Key? key,
    required this.tank,
    this.lockedMetric,
    this.metricDefinition,
  }) : super(key: key);

  /// Largest-Triangle-Three-Buckets (LTTB) Downsampling Algorithm.
  /// Condenses high-density telemetry point series down to targetCount while
  /// preserving visual peaks, troughs, and data features with O(N) linear performance.
  static List<FlSpot> lttbDownsample(List<FlSpot> data, int targetCount) {
    if (data.length <= targetCount || targetCount < 3) {
      return data;
    }

    final List<FlSpot> sampled = [];
    final double bucketSize = (data.length - 2) / (targetCount - 2);

    int a = 0; // First point in data
    sampled.add(data[a]);

    for (int i = 0; i < targetCount - 2; i++) {
      // Calculate average point for next bucket (c)
      final int avgRangeStart = (1 + (i + 1) * bucketSize).floor().clamp(0, data.length);
      final int avgRangeEnd = (1 + (i + 2) * bucketSize).floor().clamp(0, data.length);
      final int avgRangeLength = avgRangeEnd - avgRangeStart;

      double avgX = 0.0;
      double avgY = 0.0;

      if (avgRangeLength > 0) {
        for (int j = avgRangeStart; j < avgRangeEnd; j++) {
          avgX += data[j].x;
          avgY += data[j].y;
        }
        avgX /= avgRangeLength;
        avgY /= avgRangeLength;
      } else if (avgRangeStart < data.length) {
        avgX = data[avgRangeStart].x;
        avgY = data[avgRangeStart].y;
      } else {
        avgX = data.last.x;
        avgY = data.last.y;
      }

      // Range for this bucket
      final int rangeOffs = (1 + i * bucketSize).floor().clamp(0, data.length);
      final int rangeTo = (1 + (i + 1) * bucketSize).floor().clamp(0, data.length);

      final double pointAx = data[a].x;
      final double pointAy = data[a].y;

      double maxArea = -1.0;
      int maxAreaIndex = rangeOffs;

      for (int j = rangeOffs; j < rangeTo; j++) {
        // Triangle area = 0.5 * |x_A(y_B - y_C) + x_B(y_C - y_A) + x_C(y_A - y_B)|
        final double area = ((pointAx - avgX) * (data[j].y - pointAy) -
                (pointAx - data[j].x) * (avgY - pointAy))
            .abs() * 0.5;

        if (area > maxArea) {
          maxArea = area;
          maxAreaIndex = j;
        }
      }

      sampled.add(data[maxAreaIndex]);
      a = maxAreaIndex;
    }

    // Always preserve the last point
    sampled.add(data.last);
    return sampled;
  }

  @override
  State<TankAnalyticsGraph> createState() => _TankAnalyticsGraphState();
}

class _TankAnalyticsGraphState extends State<TankAnalyticsGraph> {
  late GraphMetricDefinition _selectedMetric;
  String _selectedFrequency = 'Hourly'; // 'Hourly', 'Daily', 'Monthly', 'Yearly'
  String _selectedRange = '24h';

  List<String> get _rangeOptions {
    if (_selectedFrequency == 'Hourly') {
      return RangeDefinition.hourlyRanges;
    } else if (_selectedFrequency == 'Daily') {
      return RangeDefinition.dailyRanges;
    } else if (_selectedFrequency == 'Monthly') {
      return RangeDefinition.monthlyRanges;
    } else {
      return RangeDefinition.yearlyRanges;
    }
  }

  String get _backendRange => _selectedRange.toLowerCase();

  RangeDefinition get _rangeDef => RangeDefinition.get(_backendRange);

  void _fetchHistoryData({bool forceRefresh = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<TankProvider>(context, listen: false);
      provider.fetchHistory(
        widget.tank.deviceId,
        range: _backendRange,
        forceRefresh: forceRefresh,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.metricDefinition != null) {
      _selectedMetric = widget.metricDefinition!;
    } else if (widget.lockedMetric != null) {
      _selectedMetric = widget.lockedMetric!.toDefinition();
    } else {
      // Default to Water Level per Section 41
      _selectedMetric = GraphMetricDefinition.waterLevel;
    }
    _selectedRange = '24h';
    _fetchHistoryData();
  }

  @override
  void didUpdateWidget(covariant TankAnalyticsGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tank.deviceId != widget.tank.deviceId) {
      _fetchHistoryData();
    }
    if (widget.lockedMetric != null && widget.lockedMetric != oldWidget.lockedMetric) {
      setState(() {
        _selectedMetric = widget.lockedMetric!.toDefinition();
      });
    }
    if (widget.metricDefinition != null && widget.metricDefinition != oldWidget.metricDefinition) {
      setState(() {
        _selectedMetric = widget.metricDefinition!;
      });
    }
  }

  void _onFrequencyChanged(String freq) {
    setState(() {
      _selectedFrequency = freq;
      if (freq == 'Hourly') {
        _selectedRange = '24h';
      } else if (freq == 'Daily') {
        _selectedRange = '7d';
      }
    });
    if (freq == 'Hourly' || freq == 'Daily') {
      _fetchHistoryData();
    }
  }

  void _showMetricPickerModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Chart Metric',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...GraphMetricDefinition.allMetrics.map((metric) {
                  final isSelected = metric.id == _selectedMetric.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _selectedMetric = metric;
                      });
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            metric.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? Colors.white : AppTheme.primaryBlue)
                                  : (isDark ? Colors.white.withOpacity(0.7) : Colors.black87),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            metric.unit,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getAverageDisplay(HistorySummary? summary, List<TankHistory> readings, double capacity, double height) {
    if (_selectedMetric.type == GraphMetricType.waterUsed) {
      final buckets = GraphMetricDefinition.calculateUsageBuckets(
        readings: readings,
        tankCapacity: capacity,
        rangeKey: _backendRange,
      );
      if (buckets.isEmpty) return '--';
      final total = buckets.map((b) => b.litersUsed).fold(0.0, (a, b) => a + b);
      final avg = total / buckets.length;
      if (_selectedFrequency == 'Hourly' || _backendRange == '24h') {
        return 'Hourly Avg: ${avg.toStringAsFixed(0)} L/Hr (Total: ${total.toStringAsFixed(0)} L)';
      } else if (_selectedFrequency == 'Daily') {
        return 'Daily Avg: ${avg.toStringAsFixed(0)} L/Day (Total: ${total.toStringAsFixed(0)} L)';
      }
      return 'Total: ${_selectedMetric.formatValue(total)}   Avg: ${avg.toStringAsFixed(0)} L';
    }

    // Section 13: Summary corresponds strictly to selected range and metric
    double? avg = _selectedMetric.extractAverage(summary);

    if (avg == null && readings.isNotEmpty) {
      final validVals = readings
          .map((r) => _selectedMetric.extractPointValue(r, tankCapacity: capacity, tankHeight: height))
          .whereType<double>()
          .toList();
      if (validVals.isNotEmpty) {
        avg = validVals.reduce((a, b) => a + b) / validVals.length;
      }
    }

    if (avg == null) return '--';
    return _selectedMetric.formatValue(avg);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final provider = Provider.of<TankProvider>(context);
    final capacity = widget.tank.tankCapacity > 0 ? widget.tank.tankCapacity : 280000.0;
    final maxDepth = widget.tank.depth > 0 ? widget.tank.depth : (widget.tank.tankHeight / 1000.0);

    final rawReadings = provider.getHistoricalReadingsForRange(widget.tank.deviceId, _backendRange);
    final summary = provider.getHistorySummaryForRange(widget.tank.deviceId, _backendRange);
    final historyResult = provider.getHistoryResultForRange(widget.tank.deviceId, _backendRange);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Metric Title & Manual Refresh Action (Section 26)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.lockedMetric != null || widget.metricDefinition != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedMetric.isBarChart ? Icons.bar_chart_rounded : Icons.water_drop_rounded,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedMetric.displayName} (${_selectedMetric.unit})',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showMetricPickerModal(context, isDark),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selectedMetric.isBarChart ? Icons.bar_chart_rounded : Icons.show_chart_rounded,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedMetric.displayName,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, color: textMutedColor, size: 18),
                        ],
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.tank.lastUpdated,
                      style: TextStyle(
                        color: textMutedColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        provider.fetchLatestTelemetry(widget.tank.deviceId);
                        _fetchHistoryData(forceRefresh: true);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.refresh_rounded, color: AppTheme.primaryBlue, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Frequency Segmented Control [ Hourly | Daily | Monthly | Yearly ]
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: ['Hourly', 'Daily', 'Monthly', 'Yearly'].map((freq) {
                  final isSelected = freq == _selectedFrequency;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onFrequencyChanged(freq),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          freq,
                          style: TextStyle(
                            color: isSelected ? Colors.white : textMutedColor,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 3. Sub-Period Range Selector [ 1h | 6h | 24h | 2d | 7d ] (Section 3)
          if (_selectedFrequency != 'Monthly' && _selectedFrequency != 'Yearly')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _rangeOptions.map((range) {
                  final isSelected = range == _selectedRange;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRange = range;
                      });
                      _fetchHistoryData();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryBlue.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        range,
                        style: TextStyle(
                          color: isSelected ? AppTheme.primaryBlue : textMutedColor,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // 4. Aggregated Summary Row (Section 13)
          if (_selectedFrequency != 'Monthly' && _selectedFrequency != 'Yearly' && (rawReadings.isNotEmpty || summary != null))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: _selectedMetric.type == GraphMetricType.waterUsed
                  ? _buildWaterUsedSummaryStrip(rawReadings, capacity, isDark, textColor, textMutedColor)
                  : Row(
                      children: [
                        Text(
                          'Average: ',
                          style: TextStyle(
                            color: textMutedColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getAverageDisplay(summary, rawReadings, capacity, maxDepth),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),

          // 5. Interactive Visualization Area with Loading / Empty / Error / WIP States
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 14),
            child: SizedBox(
              height: 230,
              child: (_selectedFrequency == 'Monthly' || _selectedFrequency == 'Yearly')
                  ? _buildWorkInProgressState(isDark, textColor, textMutedColor, _selectedFrequency)
                  : (provider.isHistoryLoading && rawReadings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Loading historical data...',
                                style: TextStyle(color: textMutedColor, fontSize: 11),
                              ),
                            ],
                          ),
                        )
                      : (rawReadings.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    provider.historyError != null
                                        ? Icons.error_outline_rounded
                                        : Icons.history_toggle_off_rounded,
                                    size: 28,
                                    color: provider.historyError != null
                                        ? const Color(0xFFEF4444)
                                        : textMutedColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    provider.historyError != null
                                        ? 'Unable to load historical telemetry records'
                                        : 'No historical telemetry records found for this range',
                                    style: TextStyle(color: textMutedColor, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () => _fetchHistoryData(forceRefresh: true),
                                    icon: const Icon(Icons.refresh_rounded, size: 14),
                                    label: const Text('Retry', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : (_selectedMetric.isBarChart
                              ? _buildBarChart(
                                  readings: rawReadings,
                                  tankCapacity: capacity,
                                  isDark: isDark,
                                  labelColor: textMutedColor,
                                  gridColor: borderColor,
                                )
                              : _buildLineChart(
                                  readings: rawReadings,
                                  historyResult: historyResult,
                                  tankCapacity: capacity,
                                  tankHeight: maxDepth,
                                  isDark: isDark,
                                  labelColor: textMutedColor,
                                  gridColor: borderColor,
                                )))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart({
    required List<TankHistory> readings,
    required HistoryDataResult? historyResult,
    required double tankCapacity,
    required double tankHeight,
    required bool isDark,
    required Color labelColor,
    required Color gridColor,
  }) {
    if (readings.isEmpty) {
      return Center(child: Text('No historical data available', style: TextStyle(color: labelColor)));
    }

    int normalizeSec(int ts) => ts > 100000000000 ? (ts ~/ 1000) : ts;

    // Section 5: Time domain boundaries (chartStart -> chartEnd)
    int domainStart;
    int domainEnd;

    final apiStart = historyResult?.start;
    final apiEnd = historyResult?.end;

    if (apiStart != null && apiEnd != null && apiEnd > apiStart) {
      domainStart = normalizeSec(apiStart);
      domainEnd = normalizeSec(apiEnd);
    } else {
      final durationSec = _rangeDef.durationSeconds;
      final lastPointSec = normalizeSec(readings.last.timestamp);
      domainEnd = lastPointSec;
      domainStart = domainEnd - durationSec;
    }

    final double domainDuration = (domainEnd - domainStart).toDouble();
    final double minX = 0.0;
    final double maxX = domainDuration > 0 ? domainDuration : 86400.0;

    // Section 8 & 9: Truthful Data Gap Preservation
    // Segment readings into contiguous continuous lists
    final segments = GraphDataSegmenter.segmentReadings(readings, _rangeDef.expectedIntervalSeconds);

    final List<LineChartBarData> lineBars = [];
    final List<double> allPlottedValues = [];
    final Map<int, ({DateTime time, double value})> spotLookup = {};

    for (final seg in segments) {
      final List<FlSpot> segSpots = [];

      for (final r in seg) {
        final rSec = normalizeSec(r.timestamp);
        final spotX = (rSec - domainStart).toDouble();

        // Check if within time domain
        if (spotX >= -0.5 && spotX <= maxX + 0.5) {
          final val = _selectedMetric.extractPointValue(r, tankCapacity: tankCapacity, tankHeight: tankHeight);
          if (val != null && !val.isNaN && !val.isInfinite) {
            segSpots.add(FlSpot(spotX, val));
            allPlottedValues.add(val);
            spotLookup[spotX.round()] = (time: DateTime.fromMillisecondsSinceEpoch(rSec * 1000).toLocal(), value: val);
          }
        }
      }

      if (segSpots.isNotEmpty) {
        // Section 10 & 11: High-Performance LTTB downsampling to physical display resolution
        final finalSpots = segSpots.length > 120
            ? TankAnalyticsGraph.lttbDownsample(segSpots, 100)
            : segSpots;

        // Section 12 & 38: Single primary data line + subtle fill, no min/max lines
        lineBars.add(
          LineChartBarData(
            spots: finalSpots,
            isCurved: finalSpots.length > 2 && finalSpots.length <= 60,
            curveSmoothness: 0.2,
            color: AppTheme.primaryBlue,
            barWidth: 2.8,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: finalSpots.length <= 35,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3.2,
                  color: AppTheme.primaryBlue,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.20),
                  AppTheme.primaryBlue.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        );
      }
    }

    if (lineBars.isEmpty || allPlottedValues.isEmpty) {
      return Center(child: Text('No historical data available', style: TextStyle(color: labelColor)));
    }

    // Section 16-19: Calculate Y-axis bounds based on metric rules
    final bounds = _selectedMetric.calculateYBounds(
      values: allPlottedValues,
      tankCapacity: tankCapacity,
      tankHeight: tankHeight,
    );
    final double minY = bounds.minY;
    final double maxY = bounds.maxY;

    final double tickInterval = maxX / 4.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval: _backendRange == '24h'
              ? 3600.0
              : (_backendRange == '1h' ? 300.0 : (_backendRange == '6h' ? 1800.0 : tickInterval)),
          getDrawingVerticalLine: (val) => FlLine(
            color: gridColor.withOpacity(0.14),
            strokeWidth: 0.8,
            dashArray: [3, 3],
          ),
          getDrawingHorizontalLine: (val) => FlLine(
            color: gridColor.withOpacity(0.4),
            strokeWidth: 1.0,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          // Y-Axis Titles
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: _selectedMetric.type == GraphMetricType.waterLevel
                  ? 25.0
                  : (_selectedMetric.type == GraphMetricType.waterDepth
                      ? (maxY > 0 ? (maxY / 4.0) : 0.5)
                      : null),
              getTitlesWidget: (value, meta) {
                if (value < minY || value > maxY) return const SizedBox.shrink();
                // Prevent duplicate or boundary text collision at the top
                if (value == meta.max && meta.max > maxY) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta, enabled: true),
                  child: Text(
                    _selectedMetric.formatAxisLabel(value),
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 8.5,
                    ),
                  ),
                );
              },
            ),
          ),
          // X-Axis Titles (Section 20 & 21)
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: tickInterval > 0 ? tickInterval : 21600,
              getTitlesWidget: (value, meta) {
                if (value < -0.1 || value > maxX + 0.1) return const SizedBox.shrink();

                final tickSec = domainStart + value.toInt();
                final dt = DateTime.fromMillisecondsSinceEpoch(tickSec * 1000).toLocal();

                // Section 21: "Now" may be displayed as a label if it represents chartEnd
                final isNearEnd = (maxX - value).abs() < (tickInterval * 0.15);
                final labelText = isNearEnd && (_rangeDef.key == '1h' || _rangeDef.key == '6h' || _rangeDef.key == '24h')
                    ? 'Now'
                    : _rangeDef.formatAxisTimestamp(dt);

                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta, enabled: true),
                  child: Text(
                    labelText,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color(0xFF0F172A).withOpacity(0.92),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final roundedX = spot.x.round();
                DateTime spotTime;
                if (spotLookup.containsKey(roundedX)) {
                  spotTime = spotLookup[roundedX]!.time;
                } else {
                  spotTime = DateTime.fromMillisecondsSinceEpoch((domainStart + roundedX) * 1000).toLocal();
                }

                // Section 36: Tooltip shows timestamp + metric value with clean precision
                final timeStr = DateFormat("hh:mm a, dd MMM").format(spotTime);
                final valStr = _selectedMetric.formatValue(spot.y);

                return LineTooltipItem(
                  '${_selectedMetric.displayName}\n$valStr\n$timeStr',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }

  Widget _buildWaterUsedSummaryStrip(
    List<TankHistory> readings,
    double capacity,
    bool isDark,
    Color textColor,
    Color textMutedColor,
  ) {
    final buckets = GraphMetricDefinition.calculateUsageBuckets(
      readings: readings,
      tankCapacity: capacity,
      rangeKey: _backendRange,
    );
    if (buckets.isEmpty) return const SizedBox.shrink();

    final total = buckets.map((b) => b.litersUsed).fold(0.0, (a, b) => a + b);
    final avg = total / (buckets.isNotEmpty ? buckets.length : 1);
    final peak = buckets.map((b) => b.litersUsed).fold(0.0, math.max);
    final activeCount = buckets.where((b) => b.litersUsed > 0).length;
    final unitLabel = _selectedFrequency == 'Daily' ? 'L/Day' : 'L/Hr';

    final chipBg = isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9);
    final chipBorder = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildSummaryChip('Total', '${NumberFormat('#,###').format(total.round())} L', textColor, chipBg, chipBorder, textMutedColor),
        _buildSummaryChip('Average', '${NumberFormat('#,###').format(avg.round())} $unitLabel', textColor, chipBg, chipBorder, textMutedColor),
        if (peak > 0)
          _buildSummaryChip('Peak Hour', '${NumberFormat('#,###').format(peak.round())} $unitLabel', AppTheme.primaryBlue, chipBg, chipBorder, textMutedColor),
        _buildSummaryChip('Active', '$activeCount/${buckets.length} hrs', const Color(0xFF0D9488), chipBg, chipBorder, textMutedColor),
      ],
    );
  }

  Widget _buildSummaryChip(String label, String value, Color valueColor, Color bg, Color border, Color labelColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 11.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart({
    required List<TankHistory> readings,
    required double tankCapacity,
    required bool isDark,
    required Color labelColor,
    required Color gridColor,
  }) {
    final buckets = GraphMetricDefinition.calculateUsageBuckets(
      readings: readings,
      tankCapacity: tankCapacity,
      rangeKey: _backendRange,
    );

    if (buckets.isEmpty) {
      return Center(child: Text('No water consumption data available', style: TextStyle(color: labelColor)));
    }

    final double maxVal = buckets.map((b) => b.litersUsed).fold(0.0, math.max);
    final bounds = _selectedMetric.calculateYBounds(
      values: [maxVal],
      tankCapacity: tankCapacity,
    );
    final double minY = bounds.minY;
    final double maxY = bounds.maxY;

    final barGroups = <BarChartGroupData>[];
    final int bucketCount = buckets.length;
    // Senior UX bar sizing: bold 14.0 width on 24 buckets for substantial presence
    final double barWidth = bucketCount <= 7
        ? 28.0
        : (bucketCount <= 14 ? 18.0 : (bucketCount <= 24 ? 14.0 : 6.0));

    for (int i = 0; i < bucketCount; i++) {
      final b = buckets[i];
      final bool hasUsage = b.litersUsed > 0;
      // For zero-usage hours, render a subtle baseline indicator so every measured hour is clearly accounted for
      final double rodHeight = hasUsage ? b.litersUsed : (maxY * 0.015);

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rodHeight,
              gradient: hasUsage
                  ? LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: isDark
                          ? const [Color(0xFF1D4ED8), Color(0xFF38BDF8)]
                          : const [Color(0xFF2563EB), Color(0xFF60A5FA)],
                    )
                  : null,
              color: hasUsage
                  ? null
                  : (isDark ? Colors.white.withOpacity(0.15) : const Color(0xFFCBD5E1)),
              width: barWidth,
              borderRadius: BorderRadius.vertical(top: Radius.circular(hasUsage ? 4 : 2)),
            ),
          ],
        ),
      );
    }

    double yInterval = 5000.0;
    if (maxY <= 2000) {
      yInterval = 500.0;
    } else if (maxY <= 5000) {
      yInterval = 1000.0;
    } else if (maxY <= 12000) {
      yInterval = 2500.0;
    } else if (maxY <= 25000) {
      yInterval = 5000.0;
    } else {
      yInterval = (maxY / 4.0).roundToDouble();
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (val) => FlLine(
            color: gridColor.withOpacity(0.35),
            strokeWidth: 1.0,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value < minY || value > maxY) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta, enabled: true),
                  child: Text(
                    _selectedMetric.formatAxisLabel(value),
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 9.5,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= buckets.length) return const SizedBox.shrink();

                final bool showLabel = (bucketCount <= 7)
                    ? true
                    : (bucketCount <= 14
                        ? (idx % 2 == 0)
                        : (bucketCount <= 24
                            ? (idx % 4 == 0 || idx == bucketCount - 1)
                            : (idx % 6 == 0)));
                if (!showLabel) return const SizedBox.shrink();

                final String labelText = (idx == bucketCount - 1 && bucketCount == 24)
                    ? 'Now'
                    : buckets[idx].label;

                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta, enabled: true),
                  child: Text(
                    labelText,
                    style: TextStyle(
                      color: idx == bucketCount - 1 ? AppTheme.primaryBlue : labelColor,
                      fontSize: 9.5,
                      fontWeight: idx == bucketCount - 1 ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final b = buckets[group.x.toInt()];
              final unitLabel = _selectedFrequency == 'Daily' ? 'L/Day' : 'L/Hr';
              final timeFmt = DateFormat('h a').format(b.startTime);
              final endFmt = DateFormat('h a').format(b.endTime);
              final bool hasUsage = b.litersUsed > 0;
              final valFormatted = hasUsage
                  ? '${NumberFormat('#,###').format(b.litersUsed.round())} $unitLabel'
                  : '0 $unitLabel (No Usage)';
              return BarTooltipItem(
                '$timeFmt - $endFmt\n',
                TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: valFormatted,
                    style: TextStyle(
                      color: hasUsage ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildWorkInProgressState(bool isDark, Color textColor, Color textMutedColor, String frequency) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.25)),
              ),
              child: Icon(
                Icons.timeline_rounded,
                color: AppTheme.primaryBlue,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$frequency Analytics',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Historical telemetry aggregation for $frequency view will be available soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMutedColor,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
