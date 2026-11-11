import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:water_tank_monitor/models/tank.dart';
import 'package:water_tank_monitor/models/tank_history.dart';
import 'package:water_tank_monitor/providers/tank_provider.dart';
import 'package:water_tank_monitor/services/api_service.dart';
import 'package:water_tank_monitor/services/tank_service.dart';
import 'package:water_tank_monitor/widgets/modals/data_exchange_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Tank testTank;
  late List<TankHistory> testReadings;

  setUp(() {
    testTank = Tank(
      tankId: 'tank_001',
      deviceId: 'tank_001',
      tankName: 'Main Campus Tank',
      building: 'Engineering Block',
      university: 'Apex University',
      tankCapacity: 50000.0,
      createdAt: '2026-01-01',
      updatedAt: '2026-01-01',
      currentLevelPercent: 0.85,
      depth: 2.55,
      status: 'NORMAL',
      lastTelemetryTimestamp: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    );

    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    testReadings = List.generate(
      10,
      (i) => TankHistory(
        timestamp: nowSec - (10 - i) * 1800,
        waterPercent: 85.0 - (i * 0.5),
        depth: 2.55 - (i * 0.015),
        waterAvailableLiters: 50000.0 * ((85.0 - (i * 0.5)) / 100.0),
      ),
    );
  });

  Widget createModalWrapper({
    required Tank tank,
    required List<TankHistory> readings,
    String initialReportType = 'water_level',
  }) {
    final provider = TankProvider(TankService(), ApiService());
    provider.addTankForTesting(tank);

    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<TankProvider>.value(value: provider),
        ],
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 800,
              height: 800,
              child: DataExchangeModal(
                tank: tank,
                readings: readings,
                initialReportType: initialReportType,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('DataExchangeModal Production UX & Architecture Tests', () {
    testWidgets('renders header, segmented controls, format cards, and live audit', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createModalWrapper(tank: testTank, readings: testReadings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header verification
      expect(find.text('EXPORT WATER LEVEL REPORT'), findsOneWidget);
      expect(find.text('Main Campus Tank (Engineering Block)'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);

      // Report type segmented selector
      expect(find.text('Water Level Report'), findsOneWidget);
      expect(find.text('Water Used Report'), findsOneWidget);

      // Timeframe chips
      expect(find.text('Last 24 Hours'), findsOneWidget);
      expect(find.text('Last 7 Days'), findsOneWidget);
      expect(find.text('Last 30 Days'), findsOneWidget);
      expect(find.text('Custom Range'), findsOneWidget);

      // Format cards
      expect(find.text('CSV Spreadsheet'), findsOneWidget);
      expect(find.text('Excel Spreadsheet'), findsOneWidget);
      expect(find.text('Printable Text Report'), findsOneWidget);

      // Live Water Level Data Audit
      expect(find.text('WATER LEVEL DATA AUDIT'), findsOneWidget);
      expect(find.textContaining('Records'), findsWidgets);

      // Both primary actions exist
      expect(find.text('Download Report'), findsOneWidget);
      expect(find.text('Share Report'), findsOneWidget);
    });

    testWidgets('renders 5-row preview table for Water Level Report', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createModalWrapper(tank: testTank, readings: testReadings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Preview Table Headers
      expect(find.text('LIVE REPORT PREVIEW (First 5 Rows)'), findsOneWidget);
      expect(find.text('DATE & TIME'), findsOneWidget);
      expect(find.text('WATER LEVEL'), findsOneWidget);
      expect(find.text('DEPTH'), findsOneWidget);
      expect(find.text('VOLUME'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
    });

    testWidgets('switching to Water Used Report updates preview table columns and metrics', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createModalWrapper(tank: testTank, readings: testReadings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on Water Used Report segmented button
      await tester.tap(find.text('Water Used Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header and Audit switch to Water Usage
      expect(find.text('EXPORT WATER USAGE REPORT'), findsOneWidget);
      expect(find.text('WATER USAGE DATA AUDIT'), findsOneWidget);
      expect(find.text('Total Consumed'), findsOneWidget);
      expect(find.text('Hourly Average'), findsOneWidget);
      expect(find.text('Peak Usage'), findsOneWidget);

      // Preview Table Columns for Usage
      expect(find.text('WINDOW'), findsOneWidget);
      expect(find.text('START TIME'), findsOneWidget);
      expect(find.text('WATER USED'), findsOneWidget);
      expect(find.text('USAGE SHARE'), findsOneWidget);
    });

    testWidgets('empty readings display truthful "No historical readings found" state and disable actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createModalWrapper(tank: testTank, readings: const []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Truthful empty state is shown
      expect(find.text('No historical readings found'), findsOneWidget);
      expect(
        find.text('There are no authoritative telemetry records for this tank during the selected period.'),
        findsOneWidget,
      );

      // Buttons are disabled
      final downloadFinder = find.widgetWithText(ElevatedButton, 'Download Report');
      expect(downloadFinder, findsOneWidget);
      final downloadBtn = tester.widget<ElevatedButton>(downloadFinder);
      expect(downloadBtn.onPressed, isNull);

      final shareFinder = find.widgetWithText(ElevatedButton, 'Share Report');
      expect(shareFinder, findsOneWidget);
      final shareBtn = tester.widget<ElevatedButton>(shareFinder);
      expect(shareBtn.onPressed, isNull);
    });

    testWidgets('tapping Download Report triggers download and displays success feedback', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createModalWrapper(tank: testTank, readings: testReadings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Download Report
      final downloadFinder = find.widgetWithText(ElevatedButton, 'Download Report');
      expect(downloadFinder, findsOneWidget);
      await tester.ensureVisible(downloadFinder);
      await tester.tap(downloadFinder);
      await tester.pump();

      // Verify download success message appears
      expect(find.textContaining('Downloaded "LEVELS_Main_Campus_Tank_Water_Level_'), findsOneWidget);
    });

    testWidgets('tapping Share Report triggers share and displays feedback banner', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createModalWrapper(tank: testTank, readings: testReadings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Share Report
      final shareFinder = find.widgetWithText(ElevatedButton, 'Share Report');
      expect(shareFinder, findsOneWidget);
      await tester.ensureVisible(shareFinder);
      await tester.tap(shareFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // File share driver stages report and displays success feedback
      expect(find.textContaining('Report shared successfully'), findsAtLeast(1));
    });
  });
}
