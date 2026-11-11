import 'package:flutter_test/flutter_test.dart';
import 'package:water_tank_monitor/models/alert.dart';
import 'package:water_tank_monitor/models/tank.dart';
import 'package:water_tank_monitor/models/tank_event.dart';
import 'package:water_tank_monitor/models/tank_history.dart';
import 'package:water_tank_monitor/providers/tank_provider.dart';
import 'package:water_tank_monitor/services/api_service.dart';
import 'package:water_tank_monitor/services/export_service.dart';
import 'package:water_tank_monitor/services/tank_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TankProvider provider;
  late TankService tankService;
  late ApiService apiService;

  setUp(() {
    tankService = TankService();
    apiService = ApiService();
    provider = TankProvider(tankService, apiService);
  });

  group('LEVELS Master Spec - Strict Alert Rules (Section 20-24, 46, 91-93)', () {
    test('NORMAL state produces NO active alert', () {
      final tank = provider.tanks.first;
      provider.updateTankLevelMock(tank.tankId, 0.65, 24.0); // 65%

      final activeAlerts = provider.alerts.where((a) => !a.isResolved && a.tankId == tank.tankId).toList();
      expect(activeAlerts.isEmpty, true);
    });

    test('LOW state (<= 35% and >= 15%) is a visible status but produces NO alert', () {
      final tank = provider.tanks.first;
      // 25% is LOW (above critical 15%, below low 30%)
      provider.updateTankLevelMock(tank.tankId, 0.25, 24.0);

      final updatedTank = provider.tanks.firstWhere((t) => t.tankId == tank.tankId);
      expect(updatedTank.status, 'LOW');

      // Crucial requirement: LOW must not trigger alerts
      final activeAlerts = provider.alerts.where((a) => !a.isResolved && a.tankId == tank.tankId).toList();
      expect(activeAlerts.isEmpty, true);
    });

    test('CRITICAL state (< 15%) triggers critical alert', () {
      final tank = provider.tanks.first;
      provider.updateTankLevelMock(tank.tankId, 0.10, 24.0); // 10%

      final updatedTank = provider.tanks.firstWhere((t) => t.tankId == tank.tankId);
      expect(updatedTank.status, 'CRITICAL');

      final activeAlerts = provider.alerts.where((a) => !a.isResolved && a.tankId == tank.tankId).toList();
      expect(activeAlerts.isNotEmpty, true);
      expect(activeAlerts.first.severity, 'critical');
      expect(activeAlerts.first.isCritical, true);
    });

    test('FULL state (>= 90%) triggers full (overflow risk) alert', () {
      final tank = provider.tanks.first;
      provider.updateTankLevelMock(tank.tankId, 0.95, 24.0); // 95%

      final updatedTank = provider.tanks.firstWhere((t) => t.tankId == tank.tankId);
      expect(updatedTank.status, 'FULL');

      final activeAlerts = provider.alerts.where((a) => !a.isResolved && a.tankId == tank.tankId).toList();
      expect(activeAlerts.isNotEmpty, true);
      expect(activeAlerts.first.severity, 'full');
      expect(activeAlerts.first.isFull, true);
      expect(activeAlerts.first.categoryDisplay.contains('FULL'), true);
    });

    test('Recovery to NORMAL resolves existing alerts and logs recovery event', () {
      final tank = provider.tanks.first;
      // Trigger critical alert
      provider.updateTankLevelMock(tank.tankId, 0.10, 24.0);
      expect(provider.alerts.any((a) => !a.isResolved && a.tankId == tank.tankId), true);

      // Replenish to normal
      provider.updateTankLevelMock(tank.tankId, 0.75, 24.0);

      // Alerts should now be resolved
      final activeAlerts = provider.alerts.where((a) => !a.isResolved && a.tankId == tank.tankId).toList();
      expect(activeAlerts.isEmpty, true);

      // Event should be recorded
      final recoveryEvents = provider.events.where((e) => e.eventType == TankEventType.alertRecovery).toList();
      expect(recoveryEvents.isNotEmpty, true);
    });
  });

  group('LEVELS Master Spec - Operational Summaries & Multi-Criteria Filtering', () {
    test('Dynamic building summaries calculate correctly', () {
      final summaries = provider.buildingSummaries;
      expect(summaries.isNotEmpty, true);
      expect(provider.totalMonitoredBuildings, summaries.length);
      expect(summaries.first.totalTanks, greaterThanOrEqualTo(1));
    });

    test('Displayed Tanks filter correctly by status and building', () {
      provider.setSelectedBuilding('ALL');
      provider.setSelectedStatusFilter('ALL');
      final allCount = provider.filteredTanks.length;

      // Filter by non-existent building should return 0
      provider.setSelectedBuilding('NonExistentBuilding');
      expect(provider.filteredTanks.isEmpty, true);

      // Reset
      provider.setSelectedBuilding('ALL');
      expect(provider.filteredTanks.length, allCount);
    });
  });

  group('LEVELS Master Spec - Export Service (RFC 4180 CSV, Excel TSV, Text)', () {
    late Tank sampleTank;
    late List<TankHistory> sampleReadings;

    setUp(() {
      sampleTank = Tank(
        tankId: 'test_tank_01',
        deviceId: 'ESP32_01',
        tankName: 'Science Block Tank',
        building: 'Science Building',
        tankCapacity: 20000,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      sampleReadings = [
        TankHistory(waterPercent: 75.5, depth: 1.51, timestamp: 1700000000),
        TankHistory(waterPercent: 72.0, depth: 1.44, timestamp: 1700003600),
        TankHistory(waterPercent: 68.2, depth: 1.36, timestamp: 1700007200),
      ];
    });

    test('generateReadingsCsv creates valid RFC 4180 CSV with headers and records', () {
      final result = ExportService.generateReadingsCsv(
        tank: sampleTank,
        readings: sampleReadings,
        timeframe: '24H',
      );

      expect(result.recordCount, 3);
      expect(result.mimeType, 'text/csv');
      expect(result.content.contains('Water Level (%)'), true);
      expect(result.content.contains('Science Block Tank'), true);
      expect(result.content.contains('75.50'), true);
    });

    test('generateExcelTsv creates tab-separated table compatible with Excel', () {
      final result = ExportService.generateExcelTsv(
        tank: sampleTank,
        readings: sampleReadings,
        timeframe: '7D',
      );

      expect(result.recordCount, 3);
      expect(result.content.contains('\t'), true);
      expect(result.content.contains('Water Level (%)'), true);
    });

    test('generatePrintableReport includes statistics and inferred usage disclaimer', () {
      final result = ExportService.generatePrintableReport(
        tank: sampleTank,
        readings: sampleReadings,
        events: [],
        timeframe: '24H',
        avgLevel: 71.9,
        minLevel: 68.2,
        maxLevel: 75.5,
        currentLevel: 68.2,
        estimatedUsage: 1460.0,
      );

      expect(result.recordCount, 3);
      expect(result.content.contains('STATISTICAL SUMMARY'), true);
      expect(result.content.contains('Estimated Water Used:     1460 Litres  (Inferred from delta)'), true);
      expect(result.content.contains('Average Water Level:      71.9 %'), true);
    });
  });
}
