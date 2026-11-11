import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_tank_monitor/models/tank.dart';
import 'package:water_tank_monitor/models/tank_telemetry.dart';
import 'package:water_tank_monitor/services/api_service.dart';
import 'package:water_tank_monitor/services/tank_service.dart';
import 'package:water_tank_monitor/providers/tank_provider.dart';
import 'package:water_tank_monitor/utils/file_download_io.dart';
import 'package:water_tank_monitor/utils/file_share_io.dart';
import 'package:water_tank_monitor/utils/file_share_types.dart';
import 'package:water_tank_monitor/services/export_service.dart';

void main() {
  group('LEVELS Production Hardening - Data Freshness & Reliability', () {
    test('DeviceFreshness transitions correctly based on telemetry age', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      // Online: 30 seconds ago (<= 90s)
      final onlineTank = Tank(
        tankId: 'tank_001',
        deviceId: 'tank_001',
        tankName: 'Main Campus Sump',
        building: 'Engineering Block',
        status: 'NORMAL',
        currentLevelPercent: 0.75,
        tankCapacity: 280000,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        lastTelemetryTimestamp: nowSec - 30,
      );

      expect(onlineTank.freshnessState(), equals(DeviceFreshness.online));
      expect(onlineTank.isOnline(), isTrue);
      expect(onlineTank.isStale(), isFalse);
      expect(onlineTank.isOffline(), isFalse);
      expect(onlineTank.freshnessLabel, equals('ONLINE'));
      expect(onlineTank.dataAgeFormatted(), contains('sec ago'));
      expect(onlineTank.formattedFreshnessSummary, contains('ONLINE •'));

      // Stale: 300 seconds (5 mins) ago (between 90s and 900s)
      final staleTank = Tank(
        tankId: 'tank_002',
        deviceId: 'tank_002',
        tankName: 'Overhead Tank',
        building: 'Science Block',
        status: 'NORMAL',
        currentLevelPercent: 0.50,
        tankCapacity: 50000,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        lastTelemetryTimestamp: nowSec - 300,
      );

      expect(staleTank.freshnessState(), equals(DeviceFreshness.stale));
      expect(staleTank.isOnline(), isFalse);
      expect(staleTank.isStale(), isTrue);
      expect(staleTank.isOffline(), isFalse);
      expect(staleTank.freshnessLabel, equals('STALE'));
      expect(staleTank.dataAgeFormatted(), contains('min ago'));
      expect(staleTank.formattedFreshnessSummary, contains('STALE • Last data'));

      // Offline: 1200 seconds (20 mins) ago (> 900s)
      final offlineTank = Tank(
        tankId: 'tank_003',
        deviceId: 'tank_003',
        tankName: 'Hostel Reservoir',
        building: 'Hostel A',
        status: 'OFFLINE',
        currentLevelPercent: 0.40,
        tankCapacity: 100000,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        lastTelemetryTimestamp: nowSec - 1200,
      );

      expect(offlineTank.freshnessState(), equals(DeviceFreshness.offline));
      expect(offlineTank.isOnline(), isFalse);
      expect(offlineTank.isStale(), isFalse);
      expect(offlineTank.isOffline(), isTrue);
      expect(offlineTank.freshnessLabel, equals('OFFLINE'));
      expect(offlineTank.dataAgeFormatted(), contains('min ago'));
      expect(offlineTank.formattedFreshnessSummary, contains('OFFLINE • Last seen'));
    });

    test('Telemetry clamping prevents sensor anomalies and overflows', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final tank = Tank(
        tankId: 'tank_clamp_test',
        deviceId: 'tank_clamp_test',
        tankName: 'Clamp Test',
        building: 'Lab',
        status: 'NORMAL',
        currentLevelPercent: 0.50,
        tankCapacity: 10000,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
      );

      // Over 100% level clamped to 1.0 (100%), ADC clamped to 4095
      final overflowTelemetry = TankTelemetry(
        deviceId: 'tank_clamp_test',
        waterPercent: 145.0,
        depth: 2.5,
        rawADC: 5000,
        dataVoltage: 1200.0,
        dataCurrent: 10.0,
        timestamp: nowSec,
      );
      final overflowTank = tank.copyWithTelemetry(overflowTelemetry);
      expect(overflowTank.currentLevelPercent, equals(1.0));
      expect(overflowTank.rawADC, equals(4095));

      // Negative level clamped to 0.0, ADC clamped to 0
      final underflowTelemetry = TankTelemetry(
        deviceId: 'tank_clamp_test',
        waterPercent: -15.0,
        depth: 0.0,
        rawADC: -20,
        dataVoltage: 0.0,
        dataCurrent: 0.0,
        timestamp: nowSec,
      );
      final underflowTank = tank.copyWithTelemetry(underflowTelemetry);
      expect(underflowTank.currentLevelPercent, equals(0.0));
      expect(underflowTank.rawADC, equals(0));
    });

    test('Live telemetry mutations NEVER inject synthetic records into history', () async {
      final tankService = TankService();
      final apiService = ApiService();
      final provider = TankProvider(tankService, apiService);

      // Verify baseline history for tank_001 is empty before any API call
      final initialHistory = provider.getHistoricalReadingsForRange('tank_001', '24h');
      expect(initialHistory, isEmpty);

      // Mutate live tank level using mock/live telemetry updater (0.825 = 82.5%)
      provider.updateTankLevelMock('tank_001', 0.825, 25.0);

      final updatedTank = provider.tanks.firstWhere((t) => t.tankId == 'tank_001');
      expect(updatedTank.currentLevelPercent, equals(0.825));

      // Historical records must remain strictly empty (no synthetic injection!)
      final afterMutationHistory = provider.getHistoricalReadingsForRange('tank_001', '24h');
      expect(afterMutationHistory, isEmpty);
    });

    test('ApiException generates structured error codes and human-readable messages', () {
      final networkEx = ApiException(
        message: 'No internet connection',
        code: ApiErrorCodes.networkError,
      );
      expect(networkEx.code, equals(ApiErrorCodes.networkError));
      expect(networkEx.toString(), contains('NETWORK_ERROR'));

      final timeoutEx = ApiException(
        message: 'Request timed out after 15s',
        code: ApiErrorCodes.timeoutError,
      );
      expect(timeoutEx.code, equals(ApiErrorCodes.timeoutError));

      final notFoundEx = ApiException(
        message: 'Device not found',
        code: ApiErrorCodes.deviceNotFound,
        statusCode: 404,
      );
      expect(notFoundEx.statusCode, equals(404));
      expect(notFoundEx.code, equals(ApiErrorCodes.deviceNotFound));
    });

    test('IO file download driver creates file with UTF-8 BOM', () {
      final testFileName = 'levels_test_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      const testContent = 'Timestamp,Level\r\n1000,75.0\r\n';

      saveFileToDisk(
        content: testContent,
        fileName: testFileName,
        mimeType: 'text/csv',
      );

      Directory targetDir = Directory.systemTemp;
      if (Platform.isWindows && Platform.environment['USERPROFILE'] != null) {
        final winDownloads = Directory('${Platform.environment['USERPROFILE']}\\Downloads');
        if (winDownloads.existsSync()) targetDir = winDownloads;
      }
      final targetFile = File('${targetDir.path}${Platform.pathSeparator}$testFileName');
      expect(targetFile.existsSync(), isTrue);

      final bytes = targetFile.readAsBytesSync();
      // First 3 bytes should be UTF-8 BOM: 0xEF, 0xBB, 0xBF
      expect(bytes[0], equals(0xEF));
      expect(bytes[1], equals(0xBB));
      expect(bytes[2], equals(0xBF));

      // Cleanup
      try {
        targetFile.deleteSync();
      } catch (_) {}
    });

    test('IO file share driver stages file and returns success with filePath', () async {
      final testFileName = 'levels_test_share_${DateTime.now().millisecondsSinceEpoch}.csv';
      const testContent = 'Timestamp,Level\r\n2000,80.0\r\n';

      final result = await platformShareFile(
        content: testContent,
        fileName: testFileName,
        mimeType: 'text/csv',
        title: 'Test Share',
      );

      expect(result.status, equals(FileShareStatus.success));
      expect(result.filePath, isNotNull);
      final stagedFile = File(result.filePath!);
      expect(stagedFile.existsSync(), isTrue);

      // Cleanup
      try {
        stagedFile.deleteSync();
      } catch (_) {}
    });

    test('ExportResult download and share dispatchers execute cleanly', () async {
      final tank = Tank(
        tankId: 'tank_001',
        deviceId: 'tank_001',
        tankName: 'Main Campus Sump',
        building: 'Engineering Block',
        status: 'NORMAL',
        currentLevelPercent: 0.75,
        tankCapacity: 280000,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
      );

      final result = ExportService.generateWaterLevelReportCsv(
        tank: tank,
        readings: [],
        timeframe: '24h',
      );

      expect(result.fileName, contains('LEVELS_Main_Campus_Sump'));
      expect(result.isEmpty, isTrue);

      // Method invocations should not throw
      result.download();
      final shareRes = await result.share();
      expect(shareRes.status, equals(FileShareStatus.success));
      expect(shareRes.filePath, isNotNull);
    });
  });
}
