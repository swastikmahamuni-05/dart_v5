import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:water_tank_monitor/models/historical_graph_config.dart';
import 'package:water_tank_monitor/models/tank.dart';
import 'package:water_tank_monitor/models/tank_history.dart';
import 'package:water_tank_monitor/models/tank_telemetry.dart';
import 'package:water_tank_monitor/providers/tank_provider.dart';
import 'package:water_tank_monitor/services/api_service.dart';
import 'package:water_tank_monitor/services/export_service.dart';
import 'package:water_tank_monitor/services/tank_service.dart';
import 'package:water_tank_monitor/theme/app_theme.dart';
import 'package:water_tank_monitor/utils/file_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 1: Droplet Logo Asset Corner Curvature & Transparency', () {
    test('crystal_drop.png exists, is valid PNG, and has 100% transparent corners', () {
      final file = File('assets/icon/crystal_drop.png');
      expect(file.existsSync(), true, reason: 'crystal_drop.png must exist in assets/icon/');

      final bytes = file.readAsBytesSync();
      final image = img.decodePng(bytes);
      expect(image, isNotNull, reason: 'crystal_drop.png must decode as a valid PNG');

      final w = image!.width;
      final h = image.height;

      // Bottom left & right corners MUST have alpha == 0
      final blPixel = image.getPixel(0, h - 1);
      final brPixel = image.getPixel(w - 1, h - 1);
      final tlPixel = image.getPixel(0, 0);
      final trPixel = image.getPixel(w - 1, 0);

      expect(blPixel.a, equals(0), reason: 'Bottom-left corner must be completely transparent');
      expect(brPixel.a, equals(0), reason: 'Bottom-right corner must be completely transparent');
      expect(tlPixel.a, equals(0), reason: 'Top-left corner must be completely transparent');
      expect(trPixel.a, equals(0), reason: 'Top-right corner must be completely transparent');

      // Check corner padding region (10x10 corners)
      for (int x = 0; x < 10; x++) {
        for (int y = h - 10; y < h; y++) {
          expect(image.getPixel(x, y).a, equals(0), reason: 'Bottom-left padding at ($x, $y) must have 0 alpha');
          expect(image.getPixel(w - 1 - x, y).a, equals(0), reason: 'Bottom-right padding must have 0 alpha');
        }
      }
    });
  });

  group('Requirement 7: Single Source of Truth for ONLINE/OFFLINE Telemetry State', () {
    test('Tank is ONLINE when telemetry timestamp is <= 90s', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final tank = Tank(
        tankId: 'test_tank_01',
        deviceId: 'ESP32_01',
        tankName: 'Main Storage',
        tankCapacity: 50000,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        currentLevelPercent: 0.75,
        status: 'NORMAL',
        lastTelemetryTimestamp: nowSec - 30, // 30 seconds ago
      );

      expect(tank.isOnline(), true);
      expect(tank.isTelemetryStale(), false);
      expect(tank.checkOfflineStatus().status, 'NORMAL');
    });

    test('Tank is OFFLINE when telemetry timestamp is > 90s', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final tank = Tank(
        tankId: 'test_tank_01',
        deviceId: 'ESP32_01',
        tankName: 'Main Storage',
        tankCapacity: 50000,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        currentLevelPercent: 0.75,
        status: 'NORMAL',
        lastTelemetryTimestamp: nowSec - 120, // 2 minutes ago
      );

      expect(tank.isOnline(), false);
      expect(tank.isTelemetryStale(), true);
      expect(tank.checkOfflineStatus().status, 'STALE');
      expect(tank.checkOfflineStatus(staleTimeoutSeconds: 60).status, 'OFFLINE');
    });

    test('Tank handles configurable timeout', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final tank = Tank(
        tankId: 'test_tank_01',
        deviceId: 'ESP32_01',
        tankName: 'Main Storage',
        tankCapacity: 50000,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        currentLevelPercent: 0.75,
        status: 'NORMAL',
        lastTelemetryTimestamp: nowSec - 50,
      );

      // With 60s timeout, it is online
      expect(tank.isOnline(60), true);
      // With 45s timeout, it is offline
      expect(tank.isOnline(45), false);
    });

    test('copyWithTelemetry preserves lastTelemetryTimestamp and sets correct status', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final baseTank = Tank(
        tankId: 'tank_001',
        deviceId: 'tank_001',
        tankName: 'Overhead Tank',
        tankCapacity: 10000,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        status: 'NORMAL',
      );

      final freshTelemetry = TankTelemetry(
        deviceId: 'tank_001',
        waterPercent: 82.0,
        timestamp: nowSec - 10,
        depth: 1.8,
        dataVoltage: 3.3,
        dataCurrent: 12.0,
        rawADC: 2450.0,
      );

      final updatedTank = baseTank.copyWithTelemetry(freshTelemetry);
      expect(updatedTank.lastTelemetryTimestamp, equals(nowSec - 10));
      expect(updatedTank.waterLevel, equals(82.0));
      expect(updatedTank.status, equals('NORMAL'));
      expect(updatedTank.isOnline(), true);

      final staleTelemetry = TankTelemetry(
        deviceId: 'tank_001',
        waterPercent: 82.0,
        timestamp: nowSec - 300, // 5 minutes old
        depth: 1.8,
        dataVoltage: 3.3,
        dataCurrent: 12.0,
        rawADC: 2450.0,
      );

      final staleTank = baseTank.copyWithTelemetry(staleTelemetry);
      expect(staleTank.status, equals('STALE'));
      expect(staleTank.isOnline(), false);

      final deadTelemetry = TankTelemetry(
        deviceId: 'tank_001',
        waterPercent: 82.0,
        timestamp: nowSec - 1200, // 20 minutes old (> 15 min stale threshold)
        depth: 1.8,
        dataVoltage: 3.3,
        dataCurrent: 12.0,
        rawADC: 2450.0,
      );
      final offlineTank = baseTank.copyWithTelemetry(deadTelemetry);
      expect(offlineTank.status, equals('OFFLINE'));
      expect(offlineTank.isOnline(), false);
    });
  });

  group('Report Metrics: Water Level (%), Water Height (m), and Water Used (L/Hr)', () {
    test('GraphMetricDefinition.allMetrics contains waterLevel, waterDepth (Water Height), and waterUsed', () {
      expect(GraphMetricDefinition.allMetrics.length, equals(3));
      final ids = GraphMetricDefinition.allMetrics.map((m) => m.id).toList();
      expect(ids, contains('water_level'));
      expect(ids, contains('water_depth'));
      expect(ids, contains('water_used'));
      expect(GraphMetricDefinition.waterDepth.displayName, equals('Water Height'));
      expect(GraphMetricDefinition.waterDepth.unit, equals('m'));
      expect(GraphMetricDefinition.waterUsed.unit, equals('L/Hr'));
      expect(ids, isNot(contains('water_received')));
      expect(ids, isNot(contains('water_available')));
      expect(ids, isNot(contains('voltage')));
      expect(ids, isNot(contains('current')));
      expect(ids, isNot(contains('raw_adc')));
    });

    test('calculateUsageBuckets produces accurate Liters per time bucket', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final readings = [
        TankHistory(timestamp: nowSec - 7200, waterPercent: 80.0, depth: 2.0, waterAvailableLiters: 20000.0),
        TankHistory(timestamp: nowSec - 5400, waterPercent: 70.0, depth: 1.75, waterAvailableLiters: 17500.0), // 2500 L drop
        TankHistory(timestamp: nowSec - 3600, waterPercent: 60.0, depth: 1.5, waterAvailableLiters: 15000.0),  // 2500 L drop
        TankHistory(timestamp: nowSec - 1800, waterPercent: 55.0, depth: 1.37, waterAvailableLiters: 13750.0), // 1250 L drop
      ];

      final buckets = GraphMetricDefinition.calculateUsageBuckets(
        readings: readings,
        tankCapacity: 25000.0,
        rangeKey: '24h',
      );

      expect(buckets.isNotEmpty, true);
      final totalBucketUsage = buckets.map((b) => b.litersUsed).fold(0.0, (a, b) => a + b);
      // Total consumption = 2500 + 2500 + 1250 = 6250 L
      expect(totalBucketUsage, equals(6250.0));

      // Check Y bounds for waterUsed
      final bounds = GraphMetricDefinition.waterUsed.calculateYBounds(
        values: [totalBucketUsage],
        tankCapacity: 25000.0,
      );
      expect(bounds.minY, equals(0.0));
      expect(bounds.maxY, greaterThanOrEqualTo(6250.0));
      expect(bounds.maxY, greaterThan(100.0)); // Strictly in Liters, not percentage!
    });

    test('Authoritative water calculations compute actual volume deltas without fabrication', () {
      final provider = TankProvider(TankService(), ApiService());

      // Mock readings for tank_001: 80% down to 65% (15% drop of 25,000L = 3,750L used)
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final usageReadings = [
        TankHistory(timestamp: nowSec - 3600, waterPercent: 80.0, depth: 2.0, waterAvailableLiters: 20000.0),
        TankHistory(timestamp: nowSec - 2700, waterPercent: 75.0, depth: 1.87, waterAvailableLiters: 18750.0),
        TankHistory(timestamp: nowSec - 1800, waterPercent: 70.0, depth: 1.75, waterAvailableLiters: 17500.0),
        TankHistory(timestamp: nowSec - 900,  waterPercent: 65.0, depth: 1.62, waterAvailableLiters: 16250.0),
      ];
      provider.setMockHistoryForTest('tank_001:24h', usageReadings);

      final usage = provider.calculateAuthoritativeWaterUsed('tank_001', range: '24h');
      expect(usage, equals(3750.0));

      // Parity check: calculation matches calculateUsageBuckets sum exactly
      final buckets = GraphMetricDefinition.calculateUsageBuckets(
        readings: usageReadings,
        tankCapacity: 25000.0,
        rangeKey: '24h',
      );
      final bucketSum = buckets.fold<double>(0.0, (s, b) => s + b.litersUsed);
      expect(usage, equals(bucketSum));
    });

    test('formatAxisLabel outputs clean k-values without trailing decimal zeros', () {
      expect(GraphMetricDefinition.waterUsed.formatAxisLabel(0), equals('0'));
      expect(GraphMetricDefinition.waterUsed.formatAxisLabel(5000), equals('5k'));
      expect(GraphMetricDefinition.waterUsed.formatAxisLabel(10000), equals('10k'));
      expect(GraphMetricDefinition.waterUsed.formatAxisLabel(15000), equals('15k'));
      expect(GraphMetricDefinition.waterUsed.formatAxisLabel(20000), equals('20k'));
      expect(GraphMetricDefinition.waterUsed.formatAxisLabel(12500), equals('12.5k'));
    });
  });

  group('Semantic Water Flowing Color Rule & Offline Stillness', () {
    test('Water flow color is strictly GREY when offline regardless of level', () {
      expect(AppTheme.getWaterFlowColor(levelPercent: 85.0, isOnline: false, status: 'OFFLINE'), equals(const Color(0xFF94A3B8)));
      expect(AppTheme.getWaterFlowColor(levelPercent: 35.0, isOnline: false, status: 'OFFLINE'), equals(const Color(0xFF94A3B8)));
      expect(AppTheme.getWaterFlowColor(levelPercent: 10.0, isOnline: false, status: 'OFFLINE'), equals(const Color(0xFF94A3B8)));
    });

    test('Water flow color is strictly GREEN above 40% when online', () {
      expect(AppTheme.getWaterFlowColor(levelPercent: 40.1, isOnline: true, status: 'NORMAL'), equals(const Color(0xFF16A34A)));
      expect(AppTheme.getWaterFlowColor(levelPercent: 75.0, isOnline: true, status: 'NORMAL'), equals(const Color(0xFF16A34A)));
      expect(AppTheme.getWaterFlowColor(levelPercent: 100.0, isOnline: true, status: 'NORMAL'), equals(const Color(0xFF16A34A)));
    });

    test('Water flow color is strictly ORANGE between 20% and 40% when online', () {
      expect(AppTheme.getWaterFlowColor(levelPercent: 40.0, isOnline: true, status: 'NORMAL'), equals(const Color(0xFFF97316)));
      expect(AppTheme.getWaterFlowColor(levelPercent: 30.0, isOnline: true, status: 'WARNING'), equals(const Color(0xFFF97316)));
      expect(AppTheme.getWaterFlowColor(levelPercent: 20.0, isOnline: true, status: 'NORMAL'), equals(const Color(0xFFF97316)));
    });

    test('Water flow color is strictly RED below 20% when online', () {
      expect(AppTheme.getWaterFlowColor(levelPercent: 19.9, isOnline: true, status: 'CRITICAL'), equals(const Color(0xFFDC2626)));
      expect(AppTheme.getWaterFlowColor(levelPercent: 5.0, isOnline: true, status: 'CRITICAL'), equals(const Color(0xFFDC2626)));
      expect(AppTheme.getWaterFlowColor(levelPercent: 0.0, isOnline: true, status: 'CRITICAL'), equals(const Color(0xFFDC2626)));
    });
  });

  group('Production Data Exchange Suite: Export & Safe Import Audits', () {
    test('filterReadingsByDateRange correctly filters historical records inclusively', () {
      final t1 = DateTime(2026, 9, 10, 10, 0);
      final t2 = DateTime(2026, 9, 10, 12, 0);
      final t3 = DateTime(2026, 9, 10, 14, 0);
      final t4 = DateTime(2026, 9, 10, 16, 0);

      final readings = [
        TankHistory(timestamp: t1.millisecondsSinceEpoch ~/ 1000, waterPercent: 50.0, depth: 1.25),
        TankHistory(timestamp: t2.millisecondsSinceEpoch ~/ 1000, waterPercent: 60.0, depth: 1.50),
        TankHistory(timestamp: t3.millisecondsSinceEpoch ~/ 1000, waterPercent: 70.0, depth: 1.75),
        TankHistory(timestamp: t4.millisecondsSinceEpoch ~/ 1000, waterPercent: 80.0, depth: 2.00),
      ];

      // Filter between 11:00 and 15:00 (should include t2 and t3 only)
      final filtered = ExportService.filterReadingsByDateRange(
        readings,
        DateTime(2026, 9, 10, 11, 0),
        DateTime(2026, 9, 10, 15, 0),
      );

      expect(filtered.length, equals(2));
      expect(filtered[0].waterPercent, equals(60.0));
      expect(filtered[1].waterPercent, equals(70.0));
    });

    test('generateCsvTemplate produces standard schema header', () {
      final template = ExportService.generateCsvTemplate();
      expect(template.contains('Timestamp,DateTime,Water Level (%),Depth (m),Volume (L)'), true);
      expect(template.contains('Water Level (%)'), true);
    });

    test('validateAndParseCsv validates clean CSV telemetry successfully', () {
      final csv = '''timestamp_iso,water_percent,depth_meters,volume_liters
2026-09-17T10:00:00Z,75.5,1.88,18875
2026-09-17T11:00:00Z,72.0,1.80,18000
2026-09-17T12:00:00Z,68.2,1.70,17050
''';

      final audit = ExportService.validateAndParseCsv(csv);
      expect(audit.isValid, true);
      expect(audit.totalRows, equals(3));
      expect(audit.validRows, equals(3));
      expect(audit.invalidRows, equals(0));
      expect(audit.skippedRows, equals(0));
      expect(audit.previewRows.length, equals(3));
      expect(audit.parsedReadings.length, equals(3));
      expect(audit.parsedReadings.first.waterPercent, equals(75.5));
    });

    test('validateAndParseCsv detects corrupt rows and duplicate timestamps safely', () {
      final csv = '''timestamp_iso,water_percent,depth_meters,volume_liters
2026-09-17T10:00:00Z,75.5,1.88,18875
invalid_timestamp,50.0,1.0,10000
2026-09-17T11:00:00Z,corrupt_percent,1.80,18000
2026-09-17T10:00:00Z,75.5,1.88,18875
2026-09-17T12:00:00Z,60.0,1.5,15000
''';

      final audit = ExportService.validateAndParseCsv(csv);
      // Because there are invalid rows, isValid is false for safety!
      expect(audit.isValid, false);
      expect(audit.totalRows, equals(5));
      expect(audit.validRows, equals(2)); // Row 1 & Row 5
      expect(audit.invalidRows, equals(2)); // Row 2 (bad date) & Row 3 (bad percent)
      expect(audit.skippedRows, equals(1)); // Row 4 (duplicate timestamp)
      expect(audit.errors.length, equals(2));
      expect(audit.parsedReadings.length, equals(2));
    });

    test('validateAndParseCsv rejects invalid schema when required headers are missing', () {
      final csv = '''device_name,temperature,notes
Tank A,25.4,All good
Tank B,26.1,Normal
''';

      final audit = ExportService.validateAndParseCsv(csv);
      expect(audit.isValid, false);
      expect(audit.errors.isNotEmpty, true);
      expect(audit.errors.first.contains('Required columns'), true);
    });

    test('generateWaterLevelReportCsv produces clean water level, depth, and volume columns', () {
      final tank = Tank(
        tankId: 'tank_main',
        deviceId: 'tank_main',
        tankName: 'Main Storage',
        building: 'Engineering Block',
        tankCapacity: 50000.0,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        currentLevelPercent: 0.855,
        depth: 2.14,
        status: 'NORMAL',
      );

      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final readings = [
        TankHistory(timestamp: nowSec - 3600, waterPercent: 88.0, depth: 2.20),
        TankHistory(timestamp: nowSec, waterPercent: 85.5, depth: 2.14),
      ];

      final result = ExportService.generateWaterLevelReportCsv(
        tank: tank,
        readings: readings,
        timeframe: 'Last 24 Hours',
      );

      expect(result.fileName.contains('Main_Storage'), true);
      expect(result.fileName.contains('Water_Level'), true);
      expect(result.content.contains('# Report: Water Level & Storage Depth Analysis'), true);
      expect(result.content.contains('Water Level (%),Water Height (m),Stored Volume (L),Status'), true);
      expect(result.content.contains('85.50,2.140'), true);
      expect(result.recordCount, equals(2));
    });

    test('generateWaterUsageReportCsv produces clean hourly usage (L/Hr) and consumption breakdown', () {
      final tank = Tank(
        tankId: 'tank_main',
        deviceId: 'tank_main',
        tankName: 'Main Storage',
        building: 'Engineering Block',
        tankCapacity: 50000.0,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        currentLevelPercent: 0.80,
        depth: 2.0,
        status: 'NORMAL',
      );

      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final readings = [
        TankHistory(timestamp: nowSec - 7200, waterPercent: 90.0, depth: 2.25),
        TankHistory(timestamp: nowSec - 3600, waterPercent: 85.0, depth: 2.12), // 2500 L drop
        TankHistory(timestamp: nowSec, waterPercent: 80.0, depth: 2.00),        // 2500 L drop
      ];

      final result = ExportService.generateWaterUsageReportCsv(
        tank: tank,
        readings: readings,
        timeframe: 'Last 24 Hours',
        rangeKey: '24h',
      );

      expect(result.fileName.contains('Main_Storage'), true);
      expect(result.content.contains('# Report: Water Consumption & Usage Analytics'), true);
      expect(result.content.contains('Hour Window,Start Time,End Time,Tank Name,Building,Water Used (L/Hr),Usage Share (%),Unit'), true);
      expect(result.content.contains('Total Water Used: 5,000 L'), true);
      expect(result.recordCount, equals(24));
    });

    test('getEffectiveReadings ensures non-empty readings when allowSyntheticFallback is true', () {
      final tank = Tank(
        tankId: 'tank_empty',
        deviceId: 'tank_empty',
        tankName: 'New Tank',
        building: 'Hostel A',
        tankCapacity: 20000.0,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        currentLevelPercent: 0.72,
        depth: 1.8,
        status: 'NORMAL',
      );

      final effective = ExportService.getEffectiveReadings(tank, const [], allowSyntheticFallback: true);
      expect(effective.isNotEmpty, true);
      expect(effective.length, equals(24)); // 24 representative hourly points
    });

    test('Zero Fake Data: Production export returns recordCount 0 when telemetry is empty', () {
      final tank = Tank(
        tankId: 'tank_empty',
        deviceId: 'tank_empty',
        tankName: 'Empty Tank',
        building: 'Academic Block',
        tankCapacity: 40000.0,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        currentLevelPercent: 0.50,
        status: 'NORMAL',
      );

      // Water Level CSV
      final levelResult = ExportService.generateWaterLevelReportCsv(
        tank: tank,
        readings: const [],
        timeframe: 'Last 24 Hours',
      );
      expect(levelResult.recordCount, equals(0));
      expect(levelResult.isEmpty, true);
      expect(levelResult.content.contains('No historical telemetry readings found'), true);

      // Water Usage CSV
      final usageResult = ExportService.generateWaterUsageReportCsv(
        tank: tank,
        readings: const [],
        timeframe: 'Last 24 Hours',
      );
      expect(usageResult.recordCount, equals(0));
      expect(usageResult.isEmpty, true);
      expect(usageResult.content.contains('No historical telemetry readings found'), true);
    });

    test('CSV Formula Injection Protection sanitizes dangerous prefixes (=, +, -, @, tab, cr)', () {
      expect(ExportService.sanitizeCsvField('=SUM(A1:B10)'), equals('"\'=SUM(A1:B10)"'));
      expect(ExportService.sanitizeCsvField('+CMD|'), equals('"\'\+CMD|"'));
      expect(ExportService.sanitizeCsvField('-CALC'), equals('"\'\-CALC"'));
      expect(ExportService.sanitizeCsvField('@EVIL'), equals('"\'\@EVIL"'));
      expect(ExportService.sanitizeCsvField('\tINJECTION'), equals('"\'\tINJECTION"'));
      expect(ExportService.sanitizeCsvField('\rINJECTION'), equals('"\'\rINJECTION"'));
      expect(ExportService.sanitizeCsvField('Normal Text'), equals('"Normal Text"'));
      expect(ExportService.sanitizeCsvField('Text "With Quotes"'), equals('"Text ""With Quotes"""'));

      // Verify that malicious tank name is escaped in actual generated CSV
      final maliciousTank = Tank(
        tankId: 'tank_malicious',
        deviceId: 'dev_malicious',
        tankName: '=CMD|\' /C calc\'!A0',
        building: '+EvilBuilding',
        tankCapacity: 50000.0,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        currentLevelPercent: 0.80,
        status: 'NORMAL',
      );

      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final readings = [
        TankHistory(timestamp: nowSec, waterPercent: 80.0, depth: 2.0),
      ];

      final csv = ExportService.generateWaterLevelReportCsv(
        tank: maliciousTank,
        readings: readings,
        timeframe: 'Last 24 Hours',
      );

      // Must be safely escaped with leading single quote
      expect(csv.content.contains('"\'=CMD|\' /C calc\'!A0"'), true);
      expect(csv.content.contains('"\'\+EvilBuilding"'), true);
    });

    test('Filename Sanitization prevents path traversal and removes forbidden characters', () {
      expect(ExportService.sanitizeFileName('../../etc/passwd'), equals('etc_passwd'));
      expect(ExportService.sanitizeFileName('..\\..\\windows\\system32'), equals('windows_system32'));
      expect(ExportService.sanitizeFileName('Tank: #01 / Zone * A? <Special> | Test'), equals('Tank_#01_Zone_A_Special_Test'));
      expect(ExportService.sanitizeFileName(''), equals('report'));
    });

    test('Printable 72-Character Padded ASCII Text Report produces clean aligned output', () {
      final tank = Tank(
        tankId: 'tank_asci',
        deviceId: 'dev_asci',
        tankName: 'Hostel Reservoir',
        university: 'Apex University',
        building: 'Campus Hostels',
        tankCapacity: 100000.0,
        tankType: 'RCC Underground',
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        currentLevelPercent: 0.82,
        depth: 3.28,
        status: 'NORMAL',
      );

      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final readings = [
        TankHistory(timestamp: nowSec - 3600, waterPercent: 85.0, depth: 3.4),
        TankHistory(timestamp: nowSec, waterPercent: 82.0, depth: 3.28),
      ];

      final textReport = ExportService.generateWaterLevelReportText(
        tank: tank,
        readings: readings,
        timeframe: 'Last 24 Hours',
      );

      expect(textReport.content.contains('========================================================================'), true);
      expect(textReport.content.contains('LEVELS MONITORING SYSTEM'), true);
      expect(textReport.content.contains('Hostel Reservoir'), true);
      expect(textReport.content.contains('Average Water Level:'), true);
      expect(textReport.content.contains('Current Stored Volume:'), true);
      expect(textReport.recordCount, equals(2));
      expect(textReport.previewRows.length, equals(2));

      // Usage text report
      final usageReport = ExportService.generateWaterUsageReportText(
        tank: tank,
        readings: readings,
        timeframe: 'Last 24 Hours',
      );
      expect(usageReport.content.contains('LEVELS MONITORING SYSTEM'), true);
      expect(usageReport.content.contains('CONSUMPTION SUMMARY'), true);
      expect(usageReport.content.contains('HOURLY USAGE BREAKDOWN'), true);
      expect(usageReport.recordCount, equals(24));
    });

    test('Preview rows and live statistics match final file exactly', () {
      final tank = Tank(
        tankId: 'tank_preview',
        deviceId: 'dev_preview',
        tankName: 'Academic Tank',
        building: 'Science Block',
        tankCapacity: 60000.0,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        currentLevelPercent: 0.70,
        depth: 2.1,
        status: 'NORMAL',
      );

      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final readings = List.generate(10, (i) => TankHistory(
        timestamp: nowSec - (10 - i) * 600,
        waterPercent: 70.0 + i * 0.5,
        depth: 2.1 + i * 0.015,
      ));

      final result = ExportService.generateWaterLevelReportCsv(
        tank: tank,
        readings: readings,
        timeframe: 'Last 24 Hours',
      );

      // Exactly 5 preview rows
      expect(result.previewRows.length, equals(5));
      expect(result.summaryStats['recordCount'], equals(10));
      expect(result.formattedSize.isNotEmpty, true);
      expect(result.formattedSize.contains('KB') || result.formattedSize.contains('B'), true);
    });

    test('FileShareResult encapsulates status and messages gracefully', () {
      final success = FileShareResult.success();
      expect(success.isSuccess, true);
      expect(success.status, equals(FileShareStatus.success));

      final unsupported = FileShareResult.unsupported('Custom unsupported message');
      expect(unsupported.isUnsupported, true);
      expect(unsupported.message, equals('Custom unsupported message'));

      final canceled = FileShareResult.canceled();
      expect(canceled.status, equals(FileShareStatus.canceled));

      final error = FileShareResult.error('Network timeout');
      expect(error.status, equals(FileShareStatus.error));
      expect(error.message, equals('Network timeout'));
    });
  });
}
