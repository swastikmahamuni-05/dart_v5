import 'dart:convert';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../models/tank.dart';
import '../models/tank_history.dart';
import '../models/tank_event.dart';
import '../models/historical_graph_config.dart';
import '../utils/file_download.dart';
import '../utils/file_share.dart';

class ExportResult {
  final String fileName;
  final String content;
  final String mimeType;
  final int recordCount;
  final List<Map<String, String>> previewRows;
  final Map<String, dynamic> summaryStats;

  ExportResult({
    required this.fileName,
    required this.content,
    required this.mimeType,
    required this.recordCount,
    this.previewRows = const [],
    this.summaryStats = const {},
  });

  bool get isEmpty => recordCount == 0;
  bool get isNotEmpty => recordCount > 0;

  int get byteLength => utf8.encode(content).length;
  String get formattedSize => ExportService.formatByteSize(byteLength);

  /// Dispatches download using platform appropriate mechanism (IO file write or Web anchor)
  void download() => ExportService.downloadExport(this);

  /// Dispatches native share dialog or staged file export
  Future<FileShareResult> share({String? title, String? text}) =>
      ExportService.shareExport(this, title: title, text: text);
}

class ExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd hh:mm:ss a');
  static final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');
  static final DateFormat _shortDateFormat = DateFormat('yyyy-MM-dd');

  /// Human-friendly byte size formatting without spurious decimals
  static String formatByteSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).round();
      return '$kb KB';
    }
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB';
  }

  /// Sanitizes string against CSV formula injection (=, +, -, @, \t, \r)
  static String sanitizeCsvField(String field) {
    if (field.isEmpty) return '""';
    var sanitized = field.replaceAll('"', '""');
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(sanitized)) {
      sanitized = "'$sanitized";
    }
    return '"$sanitized"';
  }

  /// Sanitizes filenames against path traversal (../, ..\) and forbidden filesystem characters
  static String sanitizeFileName(String name) {
    var clean = name.replaceAll(RegExp(r'\.\.[/\\]'), '');
    clean = clean.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    clean = clean.replaceAll(RegExp(r'\s+'), '_').trim();
    clean = clean.replaceAll(RegExp(r'_+'), '_');
    return clean.isEmpty ? 'report' : clean;
  }

  /// Normalizes telemetry timestamps: converts ms to seconds if needed
  static int normalizeTimestamp(int ts) {
    return ts > 100000000000 ? (ts ~/ 1000) : ts;
  }

  /// Fallback generator for explicit demo/test callers.
  /// Production exports DO NOT synthesize fake readings when real data is empty.
  static List<TankHistory> getEffectiveReadings(
    Tank tank,
    List<TankHistory> rawReadings, {
    bool allowSyntheticFallback = true,
  }) {
    if (rawReadings.isNotEmpty) return rawReadings;
    if (!allowSyntheticFallback) return const [];

    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final list = <TankHistory>[];
    final basePct = tank.waterLevel > 0 ? tank.waterLevel : 75.0;
    final baseDepth = tank.depth > 0 ? tank.depth : 2.0;

    for (int i = 23; i >= 0; i--) {
      final ts = nowSec - (i * 3600);
      final delta = math.sin(i * 0.45) * 2.5;
      final pct = (basePct + delta).clamp(5.0, 100.0);
      final depth = (baseDepth * (pct / basePct)).clamp(0.1, 10.0);
      list.add(TankHistory(
        timestamp: ts,
        waterPercent: pct,
        depth: depth,
        waterAvailableLiters: tank.tankCapacity * (pct / 100.0),
      ));
    }
    return list;
  }

  // =========================================================================
  // 1. WATER LEVEL REPORTS (CSV, EXCEL TSV, 72-CHAR ASCII TEXT)
  // =========================================================================

  /// Dedicated Water Level Report (CSV) with formula injection protection
  static ExportResult generateWaterLevelReportCsv({
    required Tank tank,
    required List<TankHistory> readings,
    required String timeframe,
  }) {
    final now = DateTime.now();
    final cleanTankName = sanitizeFileName(tank.tankName);
    final fileDateStr = _shortDateFormat.format(now);
    final fileName = 'LEVELS_${cleanTankName}_Water_Level_$fileDateStr.csv';

    if (readings.isEmpty) {
      return ExportResult(
        fileName: fileName,
        content: '# LEVELS - Water Level Report\n# Tank: ${tank.tankName}\n# Status: No historical telemetry readings found for $timeframe.\n',
        mimeType: 'text/csv',
        recordCount: 0,
        previewRows: const [],
        summaryStats: {
          'status': 'No historical readings found',
          'recordCount': 0,
        },
      );
    }

    final sorted = List<TankHistory>.from(readings)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final totalVolume = tank.tankCapacity > 0 ? tank.tankCapacity : 280000.0;
    final levels = sorted.map((r) => r.waterPercent).toList();
    final avgLevel = levels.reduce((a, b) => a + b) / levels.length;
    final minLevel = levels.reduce(math.min);
    final maxLevel = levels.reduce(math.max);
    final currentLevel = sorted.last.waterPercent;
    final currentVolume = totalVolume * (currentLevel / 100.0);

    final buffer = StringBuffer();

    // Line 1: Standard RFC 4180 column headers with CRLF so Excel immediately splits columns
    buffer.write('Timestamp,DateTime,Tank Name,Building,Water Level (%),Water Height (m),Stored Volume (L),Status\r\n');

    final preview = <Map<String, String>>[];

    for (int i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      final ts = normalizeTimestamp(r.timestamp);
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      final levelPct = r.waterPercent.toStringAsFixed(2);
      final depthM = r.depth.toStringAsFixed(3);
      final volumeL = (totalVolume * (r.waterPercent / 100.0)).toStringAsFixed(0);

      final safeTankName = sanitizeCsvField(tank.tankName);
      final safeBuilding = sanitizeCsvField(tank.building);
      final safeStatus = sanitizeCsvField(tank.status);

      buffer.write('$ts,"${_dateFormat.format(dt)}",$safeTankName,$safeBuilding,$levelPct,$depthM,$volumeL,$safeStatus\r\n');

      if (preview.length < 5) {
        preview.add({
          'DateTime': _dateFormat.format(dt),
          'Level': '${r.waterPercent.toStringAsFixed(1)}%',
          'Height': '${r.depth.toStringAsFixed(2)} m',
          'Volume': '$volumeL L',
          'Status': tank.status,
        });
      }
    }

    // Trailing Audit & Metadata log (never interferes with column parsing)
    buffer.write('\r\n');
    buffer.write('# LEVELS - University Water Monitoring Platform\r\n');
    buffer.write('# Report: Water Level & Storage Depth Analysis\r\n');
    buffer.write('# Tank: ${tank.tankName} (${tank.tankId})\r\n');
    buffer.write('# Building: ${tank.building}\r\n');
    buffer.write('# Timeframe: $timeframe\r\n');
    buffer.write('# Exported At: ${_dateFormat.format(now)}\r\n');
    buffer.write('# Tank Capacity: ${totalVolume.toStringAsFixed(0)} L\r\n');
    buffer.write('# Current Level: ${currentLevel.toStringAsFixed(1)}% (${currentVolume.toStringAsFixed(0)} L)\r\n');
    buffer.write('# Period Average: ${avgLevel.toStringAsFixed(1)}% | Min: ${minLevel.toStringAsFixed(1)}% | Max: ${maxLevel.toStringAsFixed(1)}%\r\n');

    return ExportResult(
      fileName: fileName,
      content: buffer.toString(),
      mimeType: 'text/csv',
      recordCount: sorted.length,
      previewRows: preview,
      summaryStats: {
        'currentLevel': currentLevel,
        'avgLevel': avgLevel,
        'minLevel': minLevel,
        'maxLevel': maxLevel,
        'storedVolume': currentVolume,
        'recordCount': sorted.length,
      },
    );
  }

  /// Dedicated Water Level Report (Excel-compatible TSV)
  static ExportResult generateWaterLevelReportExcel({
    required Tank tank,
    required List<TankHistory> readings,
    required String timeframe,
  }) {
    final now = DateTime.now();
    final cleanTankName = sanitizeFileName(tank.tankName);
    final fileDateStr = _shortDateFormat.format(now);
    final fileName = 'LEVELS_${cleanTankName}_Water_Level_$fileDateStr.xls';

    if (readings.isEmpty) {
      return ExportResult(
        fileName: fileName,
        content: 'Date & Time\tWater Level (%)\tWater Height (m)\tStored Volume (L)\tStatus\r\nNo historical readings found for $timeframe.\r\n',
        mimeType: 'application/vnd.ms-excel',
        recordCount: 0,
        previewRows: const [],
        summaryStats: {'recordCount': 0},
      );
    }

    final sorted = List<TankHistory>.from(readings)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final totalVolume = tank.tankCapacity > 0 ? tank.tankCapacity : 280000.0;
    final levels = sorted.map((r) => r.waterPercent).toList();
    final avgLevel = levels.reduce((a, b) => a + b) / levels.length;
    final currentLevel = sorted.last.waterPercent;
    final currentVolume = totalVolume * (currentLevel / 100.0);

    final buffer = StringBuffer();
    // Tab-separated column headers on line 1 for immediate Excel recognition
    buffer.write('Date & Time\tWater Level (%)\tWater Height (m)\tStored Volume (L)\tStatus\r\n');

    final preview = <Map<String, String>>[];

    for (final r in sorted) {
      final ts = normalizeTimestamp(r.timestamp);
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      final levelPct = r.waterPercent.toStringAsFixed(2);
      final depthM = r.depth.toStringAsFixed(3);
      final volumeL = (totalVolume * (r.waterPercent / 100.0)).toStringAsFixed(0);

      buffer.write('${_dateFormat.format(dt)}\t$levelPct%\t$depthM m\t$volumeL L\t${tank.status}\r\n');

      if (preview.length < 5) {
        preview.add({
          'DateTime': _dateFormat.format(dt),
          'Level': '$levelPct%',
          'Height': '$depthM m',
          'Volume': '$volumeL L',
          'Status': tank.status,
        });
      }
    }

    buffer.write('\r\n');
    buffer.write('LEVELS University Water Monitoring Platform - Water Level Report\r\n');
    buffer.write('Tank:\t${tank.tankName}\tBuilding:\t${tank.building}\tPeriod:\t$timeframe\r\n');
    buffer.write('Generated:\t${_dateFormat.format(now)}\tCapacity:\t${totalVolume.toStringAsFixed(0)} L\r\n');
    buffer.write('Current Level:\t${currentLevel.toStringAsFixed(1)}%\tPeriod Avg:\t${avgLevel.toStringAsFixed(1)}%\r\n');

    return ExportResult(
      fileName: fileName,
      content: buffer.toString(),
      mimeType: 'application/vnd.ms-excel',
      recordCount: sorted.length,
      previewRows: preview,
      summaryStats: {
        'currentLevel': currentLevel,
        'avgLevel': avgLevel,
        'storedVolume': currentVolume,
        'recordCount': sorted.length,
      },
    );
  }

  /// 72-Character Padded Printable ASCII Report for Water Level
  static ExportResult generateWaterLevelReportText({
    required Tank tank,
    required List<TankHistory> readings,
    required String timeframe,
  }) {
    final now = DateTime.now();
    final cleanTankName = sanitizeFileName(tank.tankName);
    final fileDateStr = _shortDateFormat.format(now);
    final fileName = 'LEVELS_${cleanTankName}_Water_Level_$fileDateStr.txt';

    final buffer = StringBuffer();
    buffer.writeln('========================================================================');
    buffer.writeln('                       LEVELS MONITORING SYSTEM                         ');
    buffer.writeln('            UNIVERSITY WATER TANK WATER LEVEL REPORT                    ');
    buffer.writeln('========================================================================');
    buffer.writeln('Generated At: ${_dateFormat.format(now)}');
    buffer.writeln('Campus:       ${tank.university}');
    buffer.writeln('Building:     ${tank.building}');
    buffer.writeln('Tank:         ${tank.tankName} (${tank.tankId})');
    buffer.writeln('Capacity:     ${tank.tankCapacity.toStringAsFixed(0)} Litres');
    buffer.writeln('Status:       ${tank.status}');
    buffer.writeln('Time Period:  $timeframe');
    buffer.writeln('------------------------------------------------------------------------');

    if (readings.isEmpty) {
      buffer.writeln('No historical telemetry readings recorded for selected period.');
      buffer.writeln('========================================================================');
      return ExportResult(
        fileName: fileName,
        content: buffer.toString(),
        mimeType: 'text/plain',
        recordCount: 0,
        previewRows: const [],
        summaryStats: {'recordCount': 0},
      );
    }

    final sorted = List<TankHistory>.from(readings)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final totalVolume = tank.tankCapacity > 0 ? tank.tankCapacity : 280000.0;
    final levels = sorted.map((r) => r.waterPercent).toList();
    final avgLevel = levels.reduce((a, b) => a + b) / levels.length;
    final minLevel = levels.reduce(math.min);
    final maxLevel = levels.reduce(math.max);
    final currentLevel = sorted.last.waterPercent;
    final currentVol = totalVolume * (currentLevel / 100.0);

    buffer.writeln('STATISTICAL SUMMARY');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('Average Water Level:      ${avgLevel.toStringAsFixed(1).padLeft(6)} %');
    buffer.writeln('Minimum Water Level:      ${minLevel.toStringAsFixed(1).padLeft(6)} %');
    buffer.writeln('Maximum Water Level:      ${maxLevel.toStringAsFixed(1).padLeft(6)} %');
    buffer.writeln('Current Water Level:      ${currentLevel.toStringAsFixed(1).padLeft(6)} %');
    buffer.writeln('Current Stored Volume:    ${NumberFormat('#,###').format(currentVol.round()).padLeft(10)} Litres');
    buffer.writeln('Total Telemetry Points:   ${sorted.length.toString().padLeft(10)} Records');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('TELEMETRY SAMPLES (First 5 and Recent Records)');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('Timestamp                 Level %      Volume (L)     Depth (m)');

    final preview = <Map<String, String>>[];

    for (final r in sorted.take(30)) {
      final dt = DateTime.fromMillisecondsSinceEpoch(normalizeTimestamp(r.timestamp) * 1000);
      final dtStr = _dateFormat.format(dt).padRight(26);
      final pctStr = "${r.waterPercent.toStringAsFixed(1)}%".padRight(13);
      final volStr = "${(totalVolume * (r.waterPercent / 100.0)).toStringAsFixed(0)} L".padRight(15);
      final depthStr = "${r.depth.toStringAsFixed(2)} m";
      buffer.writeln('$dtStr$pctStr$volStr$depthStr');

      if (preview.length < 5) {
        preview.add({
          'DateTime': _dateFormat.format(dt),
          'Level': '${r.waterPercent.toStringAsFixed(1)}%',
          'Height': '${r.depth.toStringAsFixed(2)} m',
          'Volume': '${(totalVolume * (r.waterPercent / 100.0)).toStringAsFixed(0)} L',
          'Status': tank.status,
        });
      }
    }

    buffer.writeln('========================================================================');
    buffer.writeln('End of Report — Authoritative LEVELS University Telemetry Backend');
    buffer.writeln('========================================================================');

    return ExportResult(
      fileName: fileName,
      content: buffer.toString(),
      mimeType: 'text/plain',
      recordCount: sorted.length,
      previewRows: preview,
      summaryStats: {
        'currentLevel': currentLevel,
        'avgLevel': avgLevel,
        'minLevel': minLevel,
        'maxLevel': maxLevel,
        'storedVolume': currentVol,
        'recordCount': sorted.length,
      },
    );
  }

  // =========================================================================
  // 2. WATER USAGE REPORTS (CSV, EXCEL TSV, 72-CHAR ASCII TEXT)
  // =========================================================================

  /// Dedicated Water Usage Report (CSV) with formula injection protection
  static ExportResult generateWaterUsageReportCsv({
    required Tank tank,
    required List<TankHistory> readings,
    required String timeframe,
    String rangeKey = '24h',
    DateTime? startTime,
    DateTime? endTime,
  }) {
    final now = DateTime.now();
    final cleanTankName = sanitizeFileName(tank.tankName);
    final fileDateStr = _shortDateFormat.format(now);
    final fileName = 'LEVELS_${cleanTankName}_Water_Usage_$fileDateStr.csv';

    if (readings.isEmpty) {
      return ExportResult(
        fileName: fileName,
        content: '# LEVELS - Water Usage Report\n# Tank: ${tank.tankName}\n# Status: No historical telemetry readings found for $timeframe.\n',
        mimeType: 'text/csv',
        recordCount: 0,
        previewRows: const [],
        summaryStats: {'recordCount': 0},
      );
    }

    final capacity = tank.tankCapacity > 0 ? tank.tankCapacity : 280000.0;
    final buckets = GraphMetricDefinition.calculateUsageBuckets(
      readings: readings,
      tankCapacity: capacity,
      rangeKey: rangeKey,
      startTime: startTime,
      endTime: endTime,
    );

    final totalUsed = buckets.map((b) => b.litersUsed).fold(0.0, (a, b) => a + b);
    final peakUsage = buckets.map((b) => b.litersUsed).fold(0.0, math.max);
    final avgHourly = buckets.isNotEmpty ? (totalUsed / buckets.length) : 0.0;
    final activeBuckets = buckets.where((b) => b.litersUsed > 0).length;

    final buffer = StringBuffer();

    // Line 1: Standard RFC 4180 headers with CRLF so Excel immediately splits columns
    buffer.write('Hour Window,Start Time,End Time,Tank Name,Building,Water Used (L/Hr),Usage Share (%),Unit\r\n');

    final preview = <Map<String, String>>[];

    for (final b in buckets) {
      final share = totalUsed > 0 ? ((b.litersUsed / totalUsed) * 100.0).toStringAsFixed(1) : '0.0';
      final safeWindow = sanitizeCsvField(b.label);
      final safeTankName = sanitizeCsvField(tank.tankName);
      final safeBuilding = sanitizeCsvField(tank.building);

      buffer.write('$safeWindow,"${_dateFormat.format(b.startTime)}","${_dateFormat.format(b.endTime)}",$safeTankName,$safeBuilding,${b.litersUsed.round()},$share,"L/Hr"\r\n');

      if (preview.length < 5) {
        preview.add({
          'Window': b.label,
          'StartTime': _dateFormat.format(b.startTime),
          'WaterUsed': '${b.litersUsed.round()} L/Hr',
          'Share': '$share%',
        });
      }
    }

    // Trailing metadata and consumption audit log
    buffer.write('\r\n');
    buffer.write('# LEVELS - University Water Monitoring Platform\r\n');
    buffer.write('# Report: Water Consumption & Usage Analytics\r\n');
    buffer.write('# Tank: ${tank.tankName} (${tank.tankId})\r\n');
    buffer.write('# Building: ${tank.building}\r\n');
    buffer.write('# Timeframe: $timeframe\r\n');
    buffer.write('# Exported At: ${_dateFormat.format(now)}\r\n');
    buffer.write('# Total Water Used: ${NumberFormat('#,###').format(totalUsed.round())} L\r\n');
    buffer.write('# Hourly Average: ${NumberFormat('#,###').format(avgHourly.round())} L/Hr\r\n');
    buffer.write('# Peak Hour Usage: ${NumberFormat('#,###').format(peakUsage.round())} L/Hr\r\n');
    buffer.write('# Active Windows: $activeBuckets/${buckets.length}\r\n');

    return ExportResult(
      fileName: fileName,
      content: buffer.toString(),
      mimeType: 'text/csv',
      recordCount: buckets.length,
      previewRows: preview,
      summaryStats: {
        'totalUsed': totalUsed,
        'avgHourly': avgHourly,
        'peakUsage': peakUsage,
        'activeWindows': activeBuckets,
        'recordCount': buckets.length,
      },
    );
  }

  /// Dedicated Water Usage Report (Excel TSV)
  static ExportResult generateWaterUsageReportExcel({
    required Tank tank,
    required List<TankHistory> readings,
    required String timeframe,
    String rangeKey = '24h',
    DateTime? startTime,
    DateTime? endTime,
  }) {
    final now = DateTime.now();
    final cleanTankName = sanitizeFileName(tank.tankName);
    final fileDateStr = _shortDateFormat.format(now);
    final fileName = 'LEVELS_${cleanTankName}_Water_Usage_$fileDateStr.xls';

    if (readings.isEmpty) {
      return ExportResult(
        fileName: fileName,
        content: 'Hour Window\tStart Time\tEnd Time\tWater Used (L/Hr)\tUsage Share (%)\tUnit\r\nNo historical readings found for $timeframe.\r\n',
        mimeType: 'application/vnd.ms-excel',
        recordCount: 0,
        previewRows: const [],
        summaryStats: {'recordCount': 0},
      );
    }

    final capacity = tank.tankCapacity > 0 ? tank.tankCapacity : 280000.0;
    final buckets = GraphMetricDefinition.calculateUsageBuckets(
      readings: readings,
      tankCapacity: capacity,
      rangeKey: rangeKey,
      startTime: startTime,
      endTime: endTime,
    );

    final totalUsed = buckets.map((b) => b.litersUsed).fold(0.0, (a, b) => a + b);
    final avgHourly = buckets.isNotEmpty ? (totalUsed / buckets.length) : 0.0;
    final peakUsage = buckets.map((b) => b.litersUsed).fold(0.0, math.max);

    final buffer = StringBuffer();
    // Tab-delimited headers on line 1 for instant Excel recognition
    buffer.write('Hour Window\tStart Time\tEnd Time\tWater Used (L/Hr)\tUsage Share (%)\tUnit\r\n');

    final preview = <Map<String, String>>[];

    for (final b in buckets) {
      final share = totalUsed > 0 ? ((b.litersUsed / totalUsed) * 100.0).toStringAsFixed(1) : '0.0';
      buffer.write('${b.label}\t${_dateFormat.format(b.startTime)}\t${_dateFormat.format(b.endTime)}\t${b.litersUsed.round()}\t$share%\tL/Hr\r\n');

      if (preview.length < 5) {
        preview.add({
          'Window': b.label,
          'StartTime': _dateFormat.format(b.startTime),
          'WaterUsed': '${b.litersUsed.round()} L/Hr',
          'Share': '$share%',
        });
      }
    }

    buffer.write('\r\n');
    buffer.write('LEVELS University Water Monitoring Platform - Water Usage Report\r\n');
    buffer.write('Tank:\t${tank.tankName}\tBuilding:\t${tank.building}\tPeriod:\t$timeframe\r\n');
    buffer.write('Total Consumption:\t${NumberFormat('#,###').format(totalUsed.round())} L\tHourly Avg:\t${NumberFormat('#,###').format(avgHourly.round())} L/Hr\tPeak:\t${NumberFormat('#,###').format(peakUsage.round())} L/Hr\r\n');

    return ExportResult(
      fileName: fileName,
      content: buffer.toString(),
      mimeType: 'application/vnd.ms-excel',
      recordCount: buckets.length,
      previewRows: preview,
      summaryStats: {
        'totalUsed': totalUsed,
        'avgHourly': avgHourly,
        'peakUsage': peakUsage,
        'recordCount': buckets.length,
      },
    );
  }

  /// 72-Character Padded Printable ASCII Report for Water Usage
  static ExportResult generateWaterUsageReportText({
    required Tank tank,
    required List<TankHistory> readings,
    required String timeframe,
    String rangeKey = '24h',
    DateTime? startTime,
    DateTime? endTime,
  }) {
    final now = DateTime.now();
    final cleanTankName = sanitizeFileName(tank.tankName);
    final fileDateStr = _shortDateFormat.format(now);
    final fileName = 'LEVELS_${cleanTankName}_Water_Usage_$fileDateStr.txt';

    final buffer = StringBuffer();
    buffer.writeln('========================================================================');
    buffer.writeln('                       LEVELS MONITORING SYSTEM                         ');
    buffer.writeln('            UNIVERSITY WATER TANK WATER USAGE REPORT                    ');
    buffer.writeln('========================================================================');
    buffer.writeln('Generated At: ${_dateFormat.format(now)}');
    buffer.writeln('Campus:       ${tank.university}');
    buffer.writeln('Building:     ${tank.building}');
    buffer.writeln('Tank:         ${tank.tankName} (${tank.tankId})');
    buffer.writeln('Capacity:     ${tank.tankCapacity.toStringAsFixed(0)} Litres');
    buffer.writeln('Time Period:  $timeframe');
    buffer.writeln('------------------------------------------------------------------------');

    if (readings.isEmpty) {
      buffer.writeln('No historical telemetry readings recorded for selected period.');
      buffer.writeln('========================================================================');
      return ExportResult(
        fileName: fileName,
        content: buffer.toString(),
        mimeType: 'text/plain',
        recordCount: 0,
        previewRows: const [],
        summaryStats: {'recordCount': 0},
      );
    }

    final capacity = tank.tankCapacity > 0 ? tank.tankCapacity : 280000.0;
    final buckets = GraphMetricDefinition.calculateUsageBuckets(
      readings: readings,
      tankCapacity: capacity,
      rangeKey: rangeKey,
      startTime: startTime,
      endTime: endTime,
    );

    final totalUsed = buckets.map((b) => b.litersUsed).fold(0.0, (a, b) => a + b);
    final peakUsage = buckets.map((b) => b.litersUsed).fold(0.0, math.max);
    final avgHourly = buckets.isNotEmpty ? (totalUsed / buckets.length) : 0.0;
    final activeBuckets = buckets.where((b) => b.litersUsed > 0).length;

    buffer.writeln('CONSUMPTION SUMMARY');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('Total Water Consumed:     ${NumberFormat('#,###').format(totalUsed.round()).padLeft(10)} Litres');
    buffer.writeln('Hourly Average Usage:     ${NumberFormat('#,###').format(avgHourly.round()).padLeft(10)} Litres/Hour');
    buffer.writeln('Peak Hour Consumption:    ${NumberFormat('#,###').format(peakUsage.round()).padLeft(10)} Litres/Hour');
    buffer.writeln('Active Usage Windows:     ${activeBuckets.toString().padLeft(6)} of ${buckets.length} Windows');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('HOURLY USAGE BREAKDOWN');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('Hour Window               Usage (L/Hr)    Share %        Cumulative (L)');

    final preview = <Map<String, String>>[];
    double runningTotal = 0.0;

    for (final b in buckets) {
      runningTotal += b.litersUsed;
      final share = totalUsed > 0 ? ((b.litersUsed / totalUsed) * 100.0).toStringAsFixed(1) : '0.0';
      final winStr = b.label.padRight(26);
      final useStr = "${b.litersUsed.round()} L/Hr".padRight(16);
      final shareStr = "$share%".padRight(15);
      final cumStr = "${runningTotal.round()} L";
      buffer.writeln('$winStr$useStr$shareStr$cumStr');

      if (preview.length < 5) {
        preview.add({
          'Window': b.label,
          'StartTime': _dateFormat.format(b.startTime),
          'WaterUsed': '${b.litersUsed.round()} L/Hr',
          'Share': '$share%',
        });
      }
    }

    buffer.writeln('========================================================================');
    buffer.writeln('End of Report — Authoritative LEVELS University Telemetry Backend');
    buffer.writeln('========================================================================');

    return ExportResult(
      fileName: fileName,
      content: buffer.toString(),
      mimeType: 'text/plain',
      recordCount: buckets.length,
      previewRows: preview,
      summaryStats: {
        'totalUsed': totalUsed,
        'avgHourly': avgHourly,
        'peakUsage': peakUsage,
        'activeWindows': activeBuckets,
        'recordCount': buckets.length,
      },
    );
  }

  // =========================================================================
  // 3. BACKWARD COMPATIBLE & UTILITY METHODS
  // =========================================================================

  /// Backward compatible generic reading CSV
  static ExportResult generateReadingsCsv({
    required Tank tank,
    required List<TankHistory> readings,
    required String timeframe,
  }) => generateWaterLevelReportCsv(tank: tank, readings: readings, timeframe: timeframe);

  /// Backward compatible generic Excel export
  static ExportResult generateExcelTsv({
    required Tank tank,
    required List<TankHistory> readings,
    required String timeframe,
  }) => generateWaterLevelReportExcel(tank: tank, readings: readings, timeframe: timeframe);

  /// Backward compatible printable report
  static ExportResult generatePrintableReport({
    required Tank tank,
    required List<TankHistory> readings,
    required List<TankEvent> events,
    required String timeframe,
    required double avgLevel,
    required double minLevel,
    required double maxLevel,
    required double currentLevel,
    required double estimatedUsage,
  }) {
    final buffer = StringBuffer();
    final nowStr = _dateFormat.format(DateTime.now());

    buffer.writeln('========================================================================');
    buffer.writeln('                       LEVELS MONITORING SYSTEM                         ');
    buffer.writeln('            UNIVERSITY WATER TANK COMPREHENSIVE REPORT                  ');
    buffer.writeln('========================================================================');
    buffer.writeln('Generated At: $nowStr');
    buffer.writeln('Campus:       ${tank.university}');
    buffer.writeln('Building:     ${tank.building}');
    buffer.writeln('Tank:         ${tank.tankName}');
    buffer.writeln('Type:         ${tank.tankType}');
    buffer.writeln('Capacity:     ${tank.tankCapacity.toStringAsFixed(0)} Litres');
    buffer.writeln('Status:       ${tank.status} (${readings.isNotEmpty ? "Online Telemetry" : "Cached/Offline"})');
    buffer.writeln('Time Period:  $timeframe');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('STATISTICAL SUMMARY');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('Average Water Level:      ${avgLevel.toStringAsFixed(1)} %');
    buffer.writeln('Minimum Water Level:      ${minLevel.toStringAsFixed(1)} %');
    buffer.writeln('Maximum Water Level:      ${maxLevel.toStringAsFixed(1)} %');
    buffer.writeln('Current Water Level:      ${currentLevel.toStringAsFixed(1)} %');
    buffer.writeln('Current Available Volume: ${(tank.tankCapacity * (currentLevel / 100.0)).toStringAsFixed(0)} Litres');
    buffer.writeln('Estimated Water Used:     ${estimatedUsage.toStringAsFixed(0)} Litres  (Inferred from delta)');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('RECENT TELEMETRY SAMPLES (Latest ${readings.length > 20 ? 20 : readings.length})');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('Timestamp                 Level %      Volume (L)     Depth (m)');
    
    final sampleList = readings.reversed.take(20).toList();
    if (sampleList.isEmpty) {
      buffer.writeln('No historical telemetry recorded for selected timeframe.');
    } else {
      for (final r in sampleList) {
        final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp * 1000);
        final dtStr = _dateFormat.format(dt).padRight(26);
        final pctStr = "${r.waterPercent.toStringAsFixed(1)}%".padRight(13);
        final volStr = "${(tank.tankCapacity * (r.waterPercent / 100.0)).toStringAsFixed(0)} L".padRight(15);
        final depthStr = "${r.depth.toStringAsFixed(2)} m";
        buffer.writeln('$dtStr$pctStr$volStr$depthStr');
      }
    }

    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('LOGGED STATE TRANSITIONS & ALERTS (${events.length} events)');
    buffer.writeln('------------------------------------------------------------------------');
    if (events.isEmpty) {
      buffer.writeln('No system incidents or transition events recorded for this period.');
    } else {
      for (final e in events.take(15)) {
        buffer.writeln('[${_dateFormat.format(e.timestamp)}] ${e.eventTypeDisplay}: ${e.previousState} -> ${e.newState} - ${e.details}');
      }
    }

    buffer.writeln('========================================================================');
    buffer.writeln('End of Report — Authoritative LEVELS University Telemetry Backend');
    buffer.writeln('========================================================================');

    final fileTimestamp = _fileDateFormat.format(DateTime.now());
    return ExportResult(
      fileName: 'LEVELS_report_${tank.tankId}_$fileTimestamp.txt',
      content: buffer.toString(),
      mimeType: 'text/plain',
      recordCount: readings.length + events.length,
    );
  }

  /// Generate CSV for Events Report
  static ExportResult generateEventsCsv({
    required List<TankEvent> events,
    required String timeframe,
  }) {
    if (events.isEmpty) {
      return ExportResult(
        fileName: 'LEVELS_events_empty.csv',
        content: 'No events for selected period.',
        mimeType: 'text/csv',
        recordCount: 0,
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('# LEVELS - University Water Level Monitoring System');
    buffer.writeln('# Report: State Transitions & Events Export');
    buffer.writeln('# Period: $timeframe');
    buffer.writeln('# Exported At: ${_dateFormat.format(DateTime.now())}');
    buffer.writeln('');

    buffer.writeln('Event ID,Timestamp,DateTime,Tank Name,Building,Event Type,Previous State,New State,Details');

    for (final e in events) {
      final safeTank = sanitizeCsvField(e.tankName);
      final safeBldg = sanitizeCsvField(e.building);
      final safeEvent = sanitizeCsvField(e.eventTypeDisplay);
      final safePrev = sanitizeCsvField(e.previousState);
      final safeNew = sanitizeCsvField(e.newState);
      final safeDetails = sanitizeCsvField(e.details);
      buffer.writeln('"${e.id}",${e.timestamp.millisecondsSinceEpoch ~/ 1000},"${_dateFormat.format(e.timestamp)}",$safeTank,$safeBldg,$safeEvent,$safePrev,$safeNew,$safeDetails');
    }

    final fileTimestamp = _fileDateFormat.format(DateTime.now());
    return ExportResult(
      fileName: 'LEVELS_events_$fileTimestamp.csv',
      content: buffer.toString(),
      mimeType: 'text/csv',
      recordCount: events.length,
    );
  }

  /// Triggers client-side browser download
  static void downloadExport(ExportResult result) {
    downloadFile(
      content: result.content,
      fileName: result.fileName,
      mimeType: result.mimeType,
    );
  }

  /// Triggers cross-platform file sharing (Web Share API / Native Share Sheet)
  static Future<FileShareResult> shareExport(
    ExportResult result, {
    String? title,
    String? text,
  }) async {
    return shareFile(
      content: result.content,
      fileName: result.fileName,
      mimeType: result.mimeType,
      title: title ?? result.fileName,
      text: text,
    );
  }

  /// Filter historical readings by strict start and end dates
  static List<TankHistory> filterReadingsByDateRange(
    List<TankHistory> readings,
    DateTime start,
    DateTime end,
  ) {
    final startSec = start.toUtc().millisecondsSinceEpoch ~/ 1000;
    final endSec = end.toUtc().millisecondsSinceEpoch ~/ 1000;

    return readings.where((r) {
      final ts = normalizeTimestamp(r.timestamp);
      return ts >= startSec && ts <= endSec;
    }).toList();
  }

  /// Generate sample CSV template for offline datalogger / telemetry imports
  static String generateCsvTemplate() {
    final now = DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,DateTime,Water Level (%),Depth (m),Volume (L)');
    buffer.writeln('${now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch ~/ 1000},"${_dateFormat.format(now.subtract(const Duration(hours: 3)))}",78.5,1.96,219800');
    buffer.writeln('${now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000},"${_dateFormat.format(now.subtract(const Duration(hours: 2)))}",76.0,1.90,212800');
    buffer.writeln('${now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000},"${_dateFormat.format(now.subtract(const Duration(hours: 1)))}",74.2,1.85,207760');
    return buffer.toString();
  }

  /// Parse & Validate Telemetry CSV file with comprehensive audit metrics
  static ImportAuditResult validateAndParseCsv(
    String csvContent, {
    double tankCapacity = 280000.0,
    double tankHeight = 2.5,
  }) {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();

    if (lines.isEmpty) {
      return const ImportAuditResult(
        isValid: false,
        totalRows: 0,
        validRows: 0,
        invalidRows: 0,
        skippedRows: 0,
        errors: ['The selected CSV file is empty.'],
        previewRows: [],
        parsedReadings: [],
      );
    }

    final headerLine = lines.first;
    final headers = headerLine.split(',').map((h) => h.replaceAll('"', '').trim().toLowerCase()).toList();

    int timeCol = headers.indexWhere((h) => h.contains('time') || h.contains('stamp') || h.contains('date'));
    int levelCol = headers.indexWhere((h) => h.contains('level') || h.contains('percent') || h == 'pct');
    int depthCol = headers.indexWhere((h) => h.contains('depth') || h.contains('height'));
    int volumeCol = headers.indexWhere((h) => h.contains('volume') || h.contains('liter') || h.contains('available'));

    if (levelCol == -1 && timeCol == -1) {
      return const ImportAuditResult(
        isValid: false,
        totalRows: 0,
        validRows: 0,
        invalidRows: 0,
        skippedRows: 0,
        errors: ['CSV schema error: Required columns (Timestamp and Water Level %) were not detected.'],
        previewRows: [],
        parsedReadings: [],
      );
    }

    final dataLines = lines.skip(1).toList();
    final List<TankHistory> parsedList = [];
    final List<Map<String, dynamic>> previewRows = [];
    final List<String> errors = [];
    final Set<int> seenTimestamps = {};
    int validCount = 0;
    int invalidCount = 0;
    int skippedCount = 0;

    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    for (int i = 0; i < dataLines.length; i++) {
      final line = dataLines[i];
      final tokens = <String>[];
      final regex = RegExp(r'(?:^|,)(?:"([^"]*)"|([^,]*))');
      for (final match in regex.allMatches(line)) {
        final val = match.group(1) ?? match.group(2) ?? '';
        tokens.add(val.trim());
      }

      if (tokens.isEmpty || tokens.every((t) => t.isEmpty)) {
        skippedCount++;
        continue;
      }

      try {
        int timestamp = nowSec - (dataLines.length - i) * 3600;
        if (timeCol != -1 && timeCol < tokens.length && tokens[timeCol].isNotEmpty) {
          final timeStr = tokens[timeCol];
          final parsedInt = int.tryParse(timeStr);
          if (parsedInt != null) {
            timestamp = normalizeTimestamp(parsedInt);
          } else {
            final parsedDate = DateTime.tryParse(timeStr);
            if (parsedDate != null) {
              timestamp = parsedDate.toUtc().millisecondsSinceEpoch ~/ 1000;
            } else {
              invalidCount++;
              if (errors.length < 5) {
                errors.add('Row ${i + 2}: Invalid timestamp "$timeStr".');
              }
              continue;
            }
          }
        }

        if (seenTimestamps.contains(timestamp)) {
          skippedCount++;
          continue;
        }
        seenTimestamps.add(timestamp);

        double waterPercent = 50.0;
        if (levelCol != -1 && levelCol < tokens.length) {
          final cleanLevel = tokens[levelCol].replaceAll('%', '').trim();
          final parsedLevel = double.tryParse(cleanLevel);
          if (parsedLevel == null || parsedLevel < 0.0 || parsedLevel > 100.0) {
            invalidCount++;
            if (errors.length < 5) {
              errors.add('Row ${i + 2}: Invalid water level "$cleanLevel" (must be 0-100%).');
            }
            continue;
          }
          waterPercent = parsedLevel;
        }

        double depth = (tankHeight > 0 ? tankHeight : 2.5) * (waterPercent / 100.0);
        if (depthCol != -1 && depthCol < tokens.length && tokens[depthCol].isNotEmpty) {
          final parsedDepth = double.tryParse(tokens[depthCol].replaceAll('m', '').trim());
          if (parsedDepth != null && parsedDepth >= 0) {
            depth = parsedDepth;
          }
        }

        double volume = tankCapacity * (waterPercent / 100.0);
        if (volumeCol != -1 && volumeCol < tokens.length && tokens[volumeCol].isNotEmpty) {
          final parsedVol = double.tryParse(tokens[volumeCol].replaceAll('L', '').trim());
          if (parsedVol != null && parsedVol >= 0) {
            volume = parsedVol;
          }
        }

        final record = TankHistory(
          timestamp: timestamp,
          waterPercent: waterPercent,
          depth: depth,
          waterAvailableLiters: volume,
        );

        parsedList.add(record);
        validCount++;

        if (previewRows.length < 5) {
          final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          previewRows.add({
            'Time': _dateFormat.format(dt),
            'Level': '${waterPercent.toStringAsFixed(1)}%',
            'Depth': '${depth.toStringAsFixed(2)} m',
            'Volume': '${volume.toStringAsFixed(0)} L',
          });
        }
      } catch (e) {
        invalidCount++;
        if (errors.length < 5) {
          errors.add('Row ${i + 2}: Error parsing line: $e');
        }
      }
    }

    final bool isValid = validCount > 0 && invalidCount == 0;

    return ImportAuditResult(
      isValid: isValid,
      totalRows: dataLines.length,
      validRows: validCount,
      invalidRows: invalidCount,
      skippedRows: skippedCount,
      errors: errors,
      previewRows: previewRows,
      parsedReadings: parsedList,
    );
  }
}

/// Comprehensive audit result for CSV telemetry ingestion
class ImportAuditResult {
  final bool isValid;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int skippedRows;
  final List<String> errors;
  final List<Map<String, dynamic>> previewRows;
  final List<TankHistory> parsedReadings;

  const ImportAuditResult({
    required this.isValid,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.skippedRows,
    required this.errors,
    required this.previewRows,
    required this.parsedReadings,
  });
}
