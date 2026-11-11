import 'dart:math';
import 'package:intl/intl.dart';
import 'tank_history.dart';

/// Centralized Metric Enumeration for Historical Analytics
enum GraphMetricType {
  waterLevel,
  waterAvailable,
  waterDepth,
  voltage,
  current,
  rawADC,
  waterUsed,
  waterReceived,
}

/// Centralized definition for every metric supported by LEVELS historical graphs.
/// Adheres to Section 16-19, 36, 37 of the LEVELS Historical Graph Standard.
class GraphMetricDefinition {
  final GraphMetricType type;
  final String id;
  final String displayName;
  final String unit;
  final int decimalPrecision;
  final bool isBarChart;

  const GraphMetricDefinition({
    required this.type,
    required this.id,
    required this.displayName,
    required this.unit,
    required this.decimalPrecision,
    this.isBarChart = false,
  });

  /// Extracts the scalar metric value from a [TankHistory] point.
  double? extractPointValue(TankHistory reading, {double tankCapacity = 280000.0, double tankHeight = 2.5}) {
    switch (type) {
      case GraphMetricType.waterLevel:
        return reading.waterPercent;
      case GraphMetricType.waterAvailable:
        if (reading.waterAvailableLiters != null && reading.waterAvailableLiters! > 0) {
          return reading.waterAvailableLiters;
        }
        return (tankCapacity * (reading.waterPercent / 100.0)).roundToDouble();
      case GraphMetricType.waterDepth:
        if (reading.depth > 0) return reading.depth;
        return (tankHeight > 0 ? tankHeight : 2.5) * (reading.waterPercent / 100.0);
      case GraphMetricType.voltage:
        return reading.dataVoltage;
      case GraphMetricType.current:
        return reading.dataCurrent;
      case GraphMetricType.rawADC:
        return reading.rawADC;
      case GraphMetricType.waterUsed:
        if (reading.waterAvailableLiters != null && reading.waterAvailableLiters! > 0) {
          return reading.waterAvailableLiters;
        }
        return (tankCapacity * (reading.waterPercent / 100.0)).roundToDouble();
      case GraphMetricType.waterReceived:
        return 0.0;
    }
  }

  /// Extracts the range-wide average value from the API's [HistorySummary].
  double? extractAverage(HistorySummary? summary) {
    if (summary == null) return null;
    switch (type) {
      case GraphMetricType.waterLevel:
        return summary.averageWaterPercent;
      case GraphMetricType.waterAvailable:
        return summary.averageWaterAvailableLiters;
      default:
        return null;
    }
  }

  /// Calculates the truthful, non-exaggerating Y-axis bounds.
  /// Section 17: Water Level is strictly 0% to 100%. Never cropped.
  /// Section 18: Water Available is strictly 0 L to clean rounded maximum.
  ({double minY, double maxY}) calculateYBounds({
    required List<double> values,
    double tankCapacity = 280000.0,
    double tankHeight = 2.5,
  }) {
    switch (type) {
      case GraphMetricType.waterLevel:
        return (minY: 0.0, maxY: 100.0);

      case GraphMetricType.waterAvailable:
        final dataMax = values.isNotEmpty ? values.reduce(max) : tankCapacity;
        final targetMax = max(dataMax, tankCapacity > 0 ? tankCapacity : 280000.0);
        // Calculate clean rounded ceiling
        final cleanMax = _calculateCleanCeiling(targetMax);
        return (minY: 0.0, maxY: cleanMax);

      case GraphMetricType.waterDepth:
        final dataMax = values.isNotEmpty ? values.reduce(max) : tankHeight;
        final cleanMax = max(dataMax * 1.15, (tankHeight > 0 ? tankHeight : 2.5));
        return (minY: 0.0, maxY: cleanMax);

      case GraphMetricType.voltage:
        final dataMax = values.isNotEmpty ? values.reduce(max) : 3300.0;
        return (minY: 0.0, maxY: _calculateCleanCeiling(dataMax * 1.1));

      case GraphMetricType.current:
        final dataMax = values.isNotEmpty ? values.reduce(max) : 20.0;
        return (minY: 0.0, maxY: max(dataMax * 1.2, 20.0));

      case GraphMetricType.rawADC:
        return (minY: 0.0, maxY: 4095.0);

      case GraphMetricType.waterUsed:
      case GraphMetricType.waterReceived:
        final dataMax = values.isNotEmpty ? values.reduce(max) : 1000.0;
        final cleanMax = _calculateCleanCeiling(max(dataMax * 1.2, 500.0));
        return (minY: 0.0, maxY: cleanMax);
    }
  }

  static double _calculateCleanCeiling(double value) {
    if (value <= 0) return 1000.0;
    final exponent = (log(value) / ln10).floor();
    final magnitude = pow(10, exponent).toDouble();
    final normalized = value / magnitude;
    double factor;
    if (normalized <= 1.0) {
      factor = 1.0;
    } else if (normalized <= 1.25) {
      factor = 1.25;
    } else if (normalized <= 1.5) {
      factor = 1.5;
    } else if (normalized <= 2.0) {
      factor = 2.0;
    } else if (normalized <= 2.5) {
      factor = 2.5;
    } else if (normalized <= 5.0) {
      factor = 5.0;
    } else {
      factor = 10.0;
    }
    return factor * magnitude;
  }

  /// Formats a value for display according to Section 36 & 37.
  String formatValue(double value) {
    switch (type) {
      case GraphMetricType.waterLevel:
        return '${value.toStringAsFixed(1)}%';
      case GraphMetricType.waterAvailable:
        if (value >= 100000) {
          return '${(value / 100000).toStringAsFixed(2)} Lakh L';
        } else if (value >= 1000) {
          return '${(value / 1000).toStringAsFixed(1)}k L';
        } else {
          return '${value.toStringAsFixed(0)} L';
        }
      case GraphMetricType.waterDepth:
        return '${value.toStringAsFixed(2)} m';
      case GraphMetricType.voltage:
        return '${value.toStringAsFixed(1)} mV';
      case GraphMetricType.current:
        return '${value.toStringAsFixed(2)} mA';
      case GraphMetricType.rawADC:
        return value.toStringAsFixed(0);
      case GraphMetricType.waterUsed:
        return '${value.toStringAsFixed(0)} L/Hr';
      case GraphMetricType.waterReceived:
        return '${value.toStringAsFixed(0)} L';
    }
  }

  /// Compact axis label formatter
  String formatAxisLabel(double value) {
    switch (type) {
      case GraphMetricType.waterLevel:
        return '${value.toStringAsFixed(0)}%';
      case GraphMetricType.waterDepth:
        return '${value.toStringAsFixed(1)}m';
      case GraphMetricType.waterUsed:
        if (value >= 1000) {
          final k = value / 1000.0;
          return (k == k.roundToDouble()) ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
        }
        return value.toStringAsFixed(0);
      case GraphMetricType.waterAvailable:
        if (value >= 100000) {
          return '${(value / 100000).toStringAsFixed(1)}L';
        } else if (value >= 1000) {
          return '${(value / 1000).toStringAsFixed(0)}k';
        }
        return value.toStringAsFixed(0);
      default:
        if (value >= 1000) {
          return '${(value / 1000).toStringAsFixed(1)}k';
        }
        return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
    }
  }

  // Registry of standard supported metrics
  static const GraphMetricDefinition waterLevel = GraphMetricDefinition(
    type: GraphMetricType.waterLevel,
    id: 'water_level',
    displayName: 'Water Level',
    unit: '%',
    decimalPrecision: 1,
  );

  static const GraphMetricDefinition waterDepth = GraphMetricDefinition(
    type: GraphMetricType.waterDepth,
    id: 'water_depth',
    displayName: 'Water Height',
    unit: 'm',
    decimalPrecision: 2,
  );

  static const GraphMetricDefinition waterAvailable = GraphMetricDefinition(
    type: GraphMetricType.waterAvailable,
    id: 'water_available',
    displayName: 'Water Available',
    unit: 'L',
    decimalPrecision: 0,
  );

  static const GraphMetricDefinition waterUsed = GraphMetricDefinition(
    type: GraphMetricType.waterUsed,
    id: 'water_used',
    displayName: 'Water Used',
    unit: 'L/Hr',
    decimalPrecision: 0,
    isBarChart: true,
  );

  static const GraphMetricDefinition waterReceived = GraphMetricDefinition(
    type: GraphMetricType.waterReceived,
    id: 'water_received',
    displayName: 'Water Received',
    unit: 'L',
    decimalPrecision: 0,
    isBarChart: true,
  );

  // Strictly report types: Water Level (%), Water Height (m), and Water Used (L/Hr)
  static const List<GraphMetricDefinition> allMetrics = [
    waterLevel,
    waterDepth,
    waterUsed,
  ];

  static GraphMetricDefinition fromId(String id) {
    if (id == 'water_height' || id == 'water_depth') return waterDepth;
    return allMetrics.firstWhere(
      (m) => m.id == id,
      orElse: () => waterLevel,
    );
  }

  /// Calculates accurate bucketed water consumption in Liters over a given timeframe
  static List<UsageBucket> calculateUsageBuckets({
    required List<TankHistory> readings,
    required double tankCapacity,
    required String rangeKey,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    if (readings.isEmpty) return const [];

    final sorted = List<TankHistory>.from(readings)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    int normalizeSec(int ts) => ts > 100000000000 ? (ts ~/ 1000) : ts;

    final firstTs = normalizeSec(sorted.first.timestamp);
    final lastTs = normalizeSec(sorted.last.timestamp);

    final rDef = RangeDefinition.get(rangeKey.toLowerCase());
    final int spanSeconds = rDef.durationSeconds;

    final int endSec = endTime != null
        ? (endTime.millisecondsSinceEpoch ~/ 1000)
        : max(lastTs, DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    final int startSec = startTime != null
        ? (startTime.millisecondsSinceEpoch ~/ 1000)
        : (endSec - spanSeconds);

    // Determine bucket duration and count based on timeframe
    int bucketSizeSec = 3600; // default 1 hour
    int numBuckets = 24;
    final rk = rangeKey.toLowerCase();
    if (rk == '1h') {
      bucketSizeSec = 300; // 5-minute intervals
      numBuckets = 12;
    } else if (rk == '6h') {
      bucketSizeSec = 1800; // 30-minute intervals
      numBuckets = 12;
    } else if (rk == '24h') {
      bucketSizeSec = 3600; // 1-hour intervals
      numBuckets = 24;
    } else if (rk == '7d') {
      bucketSizeSec = 86400; // 1-day intervals
      numBuckets = 7;
    } else if (rk == '30d') {
      bucketSizeSec = 86400; // 1-day intervals
      numBuckets = 30;
    } else if (rk == '90d' || rk == '365d') {
      bucketSizeSec = 86400 * 7; // weekly intervals
      numBuckets = max(1, (spanSeconds / bucketSizeSec).ceil());
    }

    final double deadbandLitres = tankCapacity * 0.002; // 0.2% noise deadband
    final List<double> bucketValues = List.filled(numBuckets, 0.0);

    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      final prevSec = normalizeSec(prev.timestamp);
      final currSec = normalizeSec(curr.timestamp);

      if (currSec <= startSec || prevSec >= endSec) continue;

      final prevVol = prev.waterAvailableLiters ?? (tankCapacity * (prev.waterPercent / 100.0));
      final currVol = curr.waterAvailableLiters ?? (tankCapacity * (curr.waterPercent / 100.0));

      final drop = prevVol - currVol; // Positive delta = volume consumed
      if (drop > deadbandLitres && drop < tankCapacity * 0.85) {
        final midSec = (prevSec + currSec) ~/ 2;
        final relSec = midSec - startSec;
        int bIdx = relSec ~/ bucketSizeSec;
        if (bIdx < 0) bIdx = 0;
        if (bIdx >= numBuckets) bIdx = numBuckets - 1;
        bucketValues[bIdx] += drop;
      }
    }

    final List<UsageBucket> result = [];
    for (int b = 0; b < numBuckets; b++) {
      final bStart = DateTime.fromMillisecondsSinceEpoch((startSec + b * bucketSizeSec) * 1000).toLocal();
      final bEnd = DateTime.fromMillisecondsSinceEpoch((startSec + (b + 1) * bucketSizeSec) * 1000).toLocal();
      String label;
      if (bucketSizeSec < 3600) {
        label = DateFormat('hh:mm a').format(bStart);
      } else if (bucketSizeSec <= 3600) {
        label = DateFormat('h a').format(bStart);
      } else {
        label = DateFormat('MMM dd').format(bStart);
      }

      result.add(UsageBucket(
        startTime: bStart,
        endTime: bEnd,
        litersUsed: bucketValues[b],
        label: label,
      ));
    }

    return result;
  }
}

/// Structured consumption bucket for water used analytics
class UsageBucket {
  final DateTime startTime;
  final DateTime endTime;
  final double litersUsed;
  final String label;

  const UsageBucket({
    required this.startTime,
    required this.endTime,
    required this.litersUsed,
    required this.label,
  });
}

/// Centralized Time Range taxonomy adhering to Section 3 of the standard.
class RangeDefinition {
  final String key;
  final String displayLabel;
  final int durationSeconds;
  final String apiRange;
  final int expectedIntervalSeconds;

  const RangeDefinition({
    required this.key,
    required this.displayLabel,
    required this.durationSeconds,
    required this.apiRange,
    required this.expectedIntervalSeconds,
  });

  static const RangeDefinition r1h = RangeDefinition(
    key: '1h',
    displayLabel: '1h',
    durationSeconds: 3600,
    apiRange: '1h',
    expectedIntervalSeconds: 5, // 5-second raw live readings
  );

  static const RangeDefinition r6h = RangeDefinition(
    key: '6h',
    displayLabel: '6h',
    durationSeconds: 21600,
    apiRange: '6h',
    expectedIntervalSeconds: 60, // 1-minute buckets
  );

  static const RangeDefinition r24h = RangeDefinition(
    key: '24h',
    displayLabel: '24h',
    durationSeconds: 86400,
    apiRange: '24h',
    expectedIntervalSeconds: 300, // 5-minute buckets
  );

  static const RangeDefinition r2d = RangeDefinition(
    key: '2d',
    displayLabel: '2d',
    durationSeconds: 172800,
    apiRange: '2d',
    expectedIntervalSeconds: 600, // 10-minute buckets
  );

  static const RangeDefinition r7d = RangeDefinition(
    key: '7d',
    displayLabel: '7d',
    durationSeconds: 604800,
    apiRange: '7d',
    expectedIntervalSeconds: 3600, // 1-hour buckets
  );

  static const RangeDefinition r15d = RangeDefinition(
    key: '15d',
    displayLabel: '15d',
    durationSeconds: 1296000,
    apiRange: '15d',
    expectedIntervalSeconds: 7200,
  );

  static const RangeDefinition r30d = RangeDefinition(
    key: '30d',
    displayLabel: '30d',
    durationSeconds: 2592000,
    apiRange: '30d',
    expectedIntervalSeconds: 14400,
  );

  static const RangeDefinition r90d = RangeDefinition(
    key: '90d',
    displayLabel: '90d',
    durationSeconds: 7776000,
    apiRange: '90d',
    expectedIntervalSeconds: 28800,
  );

  static const RangeDefinition r6m = RangeDefinition(
    key: '6m',
    displayLabel: '6m',
    durationSeconds: 15552000,
    apiRange: '6m',
    expectedIntervalSeconds: 86400,
  );

  static const RangeDefinition r12m = RangeDefinition(
    key: '12m',
    displayLabel: '12m',
    durationSeconds: 31536000,
    apiRange: '12m',
    expectedIntervalSeconds: 86400,
  );

  static const RangeDefinition r24m = RangeDefinition(
    key: '24m',
    displayLabel: '24m',
    durationSeconds: 63072000,
    apiRange: '24m',
    expectedIntervalSeconds: 86400,
  );

  static const RangeDefinition r1y = RangeDefinition(
    key: '1y',
    displayLabel: '1y',
    durationSeconds: 31536000,
    apiRange: '1y',
    expectedIntervalSeconds: 86400,
  );

  static const RangeDefinition r3y = RangeDefinition(
    key: '3y',
    displayLabel: '3y',
    durationSeconds: 94608000,
    apiRange: '3y',
    expectedIntervalSeconds: 604800,
  );

  static const RangeDefinition r5y = RangeDefinition(
    key: '5y',
    displayLabel: '5y',
    durationSeconds: 157680000,
    apiRange: '5y',
    expectedIntervalSeconds: 604800,
  );

  static const Map<String, RangeDefinition> all = {
    '1h': r1h,
    '6h': r6h,
    '24h': r24h,
    '2d': r2d,
    '7d': r7d,
    '15d': r15d,
    '30d': r30d,
    '90d': r90d,
    '6m': r6m,
    '12m': r12m,
    '24m': r24m,
    '1y': r1y,
    '3y': r3y,
    '5y': r5y,
  };

  static const List<String> hourlyRanges = ['1h', '6h', '24h', '2d', '7d'];
  static const List<String> dailyRanges = ['7d', '15d', '30d', '90d'];
  static const List<String> monthlyRanges = ['6m', '12m', '24m'];
  static const List<String> yearlyRanges = ['1y', '3y', '5y'];

  static RangeDefinition get(String key) {
    return all[key.toLowerCase()] ?? r24h;
  }

  /// Formats X-axis timestamp based on range duration (Section 20).
  String formatAxisTimestamp(DateTime dt) {
    final r = key.toLowerCase();
    if (r == '1h' || r == '6h' || r == '24h') {
      return DateFormat('HH:mm').format(dt);
    } else if (r == '2d') {
      return DateFormat('E HH:mm').format(dt);
    } else if (r == '7d' || r == '15d' || r == '30d' || r == '90d') {
      return DateFormat('dd MMM').format(dt);
    } else if (r == '6m' || r == '12m' || r == '24m') {
      return DateFormat('MMM yy').format(dt);
    } else {
      return DateFormat('yyyy').format(dt);
    }
  }
}

/// Helper for truthful data gap preservation (Section 8 & 9).
/// Breaks contiguous readings into discrete sub-lists whenever Δt > expectedInterval * 2.5.
class GraphDataSegmenter {
  static List<List<TankHistory>> segmentReadings(
    List<TankHistory> readings,
    int expectedIntervalSeconds,
  ) {
    if (readings.isEmpty) return [];
    if (readings.length == 1) return [readings];

    // Gap threshold: 2.5x expected bucket/sampling interval (min 60s)
    final gapThreshold = max(expectedIntervalSeconds * 2.5, 60.0).round();

    final List<List<TankHistory>> segments = [];
    List<TankHistory> currentSegment = [readings.first];

    for (int i = 1; i < readings.length; i++) {
      final prev = readings[i - 1];
      final curr = readings[i];
      final deltaSec = curr.timestamp - prev.timestamp;

      if (deltaSec > gapThreshold) {
        // Gap encountered: end current segment and start fresh segment
        segments.add(currentSegment);
        currentSegment = [curr];
      } else {
        currentSegment.add(curr);
      }
    }

    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    return segments;
  }
}
