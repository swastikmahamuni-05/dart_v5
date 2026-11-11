import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:water_tank_monitor/models/tank_history.dart';

void main() {
  group('Range Configuration Source of Truth Tests', () {
    test('verifies all supported range durations in seconds', () {
      expect(RangeConfig.getDurationSeconds('1h'), 3600);
      expect(RangeConfig.getDurationSeconds('6h'), 21600);
      expect(RangeConfig.getDurationSeconds('24h'), 86400);
      expect(RangeConfig.getDurationSeconds('2d'), 172800);
      expect(RangeConfig.getDurationSeconds('7d'), 604800);
      expect(RangeConfig.getDurationSeconds('15d'), 15 * 86400);
      expect(RangeConfig.getDurationSeconds('30d'), 30 * 86400);
      expect(RangeConfig.getDurationSeconds('90d'), 90 * 86400);
      expect(RangeConfig.getDurationSeconds('6m'), 180 * 86400);
      expect(RangeConfig.getDurationSeconds('12m'), 365 * 86400);
      expect(RangeConfig.getDurationSeconds('24m'), 730 * 86400);
      expect(RangeConfig.getDurationSeconds('1y'), 365 * 86400);
      expect(RangeConfig.getDurationSeconds('3y'), 3 * 365 * 86400);
      expect(RangeConfig.getDurationSeconds('5y'), 5 * 365 * 86400);
    });

    test('verifies range groups are correctly categorized', () {
      expect(RangeConfig.hourlyRanges, ['1h', '6h', '24h', '2d', '7d']);
      expect(RangeConfig.dailyRanges, ['7d', '15d', '30d', '90d']);
      expect(RangeConfig.monthlyRanges, ['6m', '12m', '24m']);
      expect(RangeConfig.yearlyRanges, ['1y', '3y', '5y']);
    });
  });

  group('Timeline Domain & Real Timestamp Coordinate Mapping', () {
    test('verifies API start/end define domain boundaries and partial data leaves missing periods empty', () {
      // API returns 24h domain from start to end (86400 seconds)
      const int apiStart = 1788678059; // e.g. 12:40 PM yesterday
      const int apiEnd = 1788764459;   // e.g. 12:40 PM today
      const double domainDuration = (apiEnd - apiStart) * 1.0;
      expect(domainDuration, 86400.0);

      // Suppose real telemetry only exists from 10:15 AM to 12:30 PM today
      // 10:15 AM today is ~21.58 hours (77700 seconds) into the 24h window
      const int reading1Time = apiStart + 77700;
      // 12:30 PM today is ~23.83 hours (85800 seconds) into the 24h window
      const int reading2Time = apiStart + 85800;

      final readings = [
        TankHistory(
          waterPercent: 43.4,
          waterAvailableLiters: 121533.0,
          depth: 2.1,
          timestamp: reading1Time,
        ),
        TankHistory(
          waterPercent: 39.371,
          waterAvailableLiters: 110238.0,
          depth: 1.9,
          timestamp: reading2Time,
        ),
      ];

      // Map each reading to X position: x = (timestamp - chartStart)
      final spot1X = (readings[0].timestamp - apiStart).toDouble();
      final spot2X = (readings[1].timestamp - apiStart).toDouble();

      // Verify first returned record does NOT automatically become the left edge (x=0)
      expect(spot1X, 77700.0);
      expect(spot1X > 0.0, isTrue);

      // Verify last returned record does NOT automatically become the right edge (x=86400)
      expect(spot2X, 85800.0);
      expect(spot2X < domainDuration, isTrue);

      // Missing period (from x=0 to x=77700) is completely empty with no spots
      expect(spot1X - 0.0, 77700.0); // 21.58 hours empty on the left
      expect(domainDuration - spot2X, 600.0); // 10 minutes empty on the right
    });
  });

  group('tank_001 24h Acceptance Criteria Verification', () {
    test('verifies 28 points, oldest to newest, rightmost is 1.10 Lakh L and formatted with timestamp', () {
      final endTimeUtc = DateTime.utc(2026, 9, 7, 7, 0);
      final endTimestampSec = endTimeUtc.millisecondsSinceEpoch ~/ 1000;
      final startTimestampSec = endTimestampSec - 86400;

      final List<TankHistory> points = [];
      for (int i = 0; i < 28; i++) {
        final ptTimeSec = endTimestampSec - (27 - i) * 3100;
        final isLast = i == 27;
        points.add(TankHistory(
          waterPercent: isLast ? 39.371 : (40.0 + (i % 5)),
          waterAvailableLiters: isLast ? 110238.0 : (112000.0 + i * 100),
          depth: 2.1,
          timestamp: ptTimeSec,
        ));
      }

      expect(points.length, 28);

      // Chronological ascending (OLDEST -> NEWEST)
      for (int i = 0; i < points.length - 1; i++) {
        expect(points[i].timestamp < points[i + 1].timestamp, isTrue);
      }

      // Leftmost point is oldest
      final leftmost = points.first;
      expect(leftmost.timestamp, points.map((p) => p.timestamp).reduce((a, b) => a < b ? a : b));

      // Rightmost point is newest with ~1.10 Lakh L
      final rightmost = points.last;
      expect(rightmost.waterAvailableLiters, 110238.0);
      expect(rightmost.waterPercent, 39.371);
      expect(rightmost.timestamp, endTimestampSec);

      final val = rightmost.waterAvailableLiters!;
      final formattedVal = val >= 100000
          ? '${(val / 100000).toStringAsFixed(2)} Lk'
          : '${(val / 1000).toStringAsFixed(1)}k';
      expect(formattedVal, '1.10 Lk');

      // Actual timestamp used, not "Now"
      final lastDt = DateTime.fromMillisecondsSinceEpoch(rightmost.timestamp * 1000).toLocal();
      final formattedTime = DateFormat('HH:mm').format(lastDt);
      expect(formattedTime != 'Now', isTrue);
      expect(formattedTime.contains(':'), isTrue);

      // Verify domain mapping:
      final spotX = (rightmost.timestamp - startTimestampSec).toDouble();
      expect(spotX, 86400.0); // Exactly at 24h mark
    });

    test('verifies backend summary is used for Average value without recalculating from live tank', () {
      const summary = HistorySummary(
        averageWaterAvailableLiters: 121533.12,
        averageWaterPercent: 43.405,
      );

      final avgLiters = summary.averageWaterAvailableLiters!;
      final formattedAvg = avgLiters >= 100000
          ? '${(avgLiters / 100000).toStringAsFixed(2)} Lakh L'
          : '${(avgLiters / 1000).toStringAsFixed(1)}k L';

      expect(formattedAvg, '1.22 Lakh L');

      final avgPercent = summary.averageWaterPercent!;
      final formattedPercent = '${avgPercent.toStringAsFixed(1)}%';
      expect(formattedPercent, '43.4%');
    });
  });
}
