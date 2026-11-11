import 'package:flutter_test/flutter_test.dart';
import 'package:water_tank_monitor/models/historical_graph_config.dart';
import 'package:water_tank_monitor/models/tank_history.dart';

void main() {
  group('LEVELS Historical Graph Standard Tests', () {
    test('Rule 1-6: Range Definitions conform to standard specifications', () {
      final r1h = RangeDefinition.get('1h');
      expect(r1h.key, '1h');
      expect(r1h.durationSeconds, 3600);
      expect(r1h.expectedIntervalSeconds, 5); // 5-second raw live readings

      final r24h = RangeDefinition.get('24h');
      expect(r24h.key, '24h');
      expect(r24h.durationSeconds, 86400);
      expect(r24h.expectedIntervalSeconds, 300); // 5-minute buckets

      final r7d = RangeDefinition.get('7d');
      expect(r7d.key, '7d');
      expect(r7d.durationSeconds, 604800);
      expect(r7d.expectedIntervalSeconds, 3600); // 1-hour buckets

      final r30d = RangeDefinition.get('30d');
      expect(r30d.key, '30d');
      expect(r30d.durationSeconds, 2592000);
      expect(r30d.expectedIntervalSeconds, 14400); // 4-hour buckets
    });

    test('Rule 10-12 & 41: Water Level (%) scale is fixed 0% to 100%', () {
      final metric = GraphMetricDefinition.waterLevel;
      expect(metric.unit, '%');
      expect(metric.displayName, 'Water Level');
      final bounds = metric.calculateYBounds(values: [45.0, 80.0]);
      expect(bounds.minY, 0.0);
      expect(bounds.maxY, 100.0);
    });

    test('Rule 8-9: GraphDataSegmenter breaks lines when delta > 2.5 * expectedInterval', () {
      const baseSec = 1700000000;
      // Expected interval 5 seconds (1h range) -> threshold is 2.5 * 5 = 12.5s -> min 60s
      final p1 = TankHistory(waterPercent: 50.0, depth: 1.5, timestamp: baseSec);
      final p2 = TankHistory(waterPercent: 51.0, depth: 1.52, timestamp: baseSec + 5);
      final p3 = TankHistory(waterPercent: 52.0, depth: 1.55, timestamp: baseSec + 10);

      // Large gap of 120 seconds (> 60s threshold)
      final p4 = TankHistory(waterPercent: 53.0, depth: 1.58, timestamp: baseSec + 130);
      final p5 = TankHistory(waterPercent: 54.0, depth: 1.60, timestamp: baseSec + 135);

      final segments = GraphDataSegmenter.segmentReadings([p1, p2, p3, p4, p5], 5);

      expect(segments.length, 2, reason: 'Must split into 2 separate segments across the 120s gap');
      expect(segments[0].length, 3);
      expect(segments[1].length, 2);
    });

    test('Rule 8-9: Continuous data with small jitter stays in single segment', () {
      const baseSec = 1700000000;
      // 24h range expected interval is 300 seconds (5 min) -> threshold is 2.5 * 300 = 750 seconds (12.5 min)
      final p1 = TankHistory(waterPercent: 40.0, depth: 1.0, timestamp: baseSec);
      final p2 = TankHistory(waterPercent: 42.0, depth: 1.1, timestamp: baseSec + 300);
      final p3 = TankHistory(waterPercent: 44.0, depth: 1.2, timestamp: baseSec + 650);

      final segments = GraphDataSegmenter.segmentReadings([p1, p2, p3], 300);

      expect(segments.length, 1, reason: '350s delta is within 750s threshold, should stay unified');
      expect(segments[0].length, 3);
    });

    test('Rule 18: Water Available calculates clean rounded ceiling', () {
      final metric = GraphMetricDefinition.waterAvailable;
      expect(metric.unit, 'L');
      final bounds = metric.calculateYBounds(values: [120000.0, 240000.0], tankCapacity: 280000.0);
      expect(bounds.minY, 0.0);
      expect(bounds.maxY >= 280000.0, isTrue);
      // Clean ceil of 280000 is 500000.0
      expect(bounds.maxY, 500000.0);
    });
  });
}
