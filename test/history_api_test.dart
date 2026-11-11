import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_tank_monitor/models/tank_history.dart';

void main() {
  group('Structured History API Parsing Tests', () {
    test('should correctly parse the new structured backend response', () {
      final backendJson = {
        "deviceId": "tank_001",
        "range": "24h",
        "start": 1788678059,
        "end": 1788764459,
        "tankCapacity": 280000.0,
        "bucketSeconds": 300,
        "rawRecordCount": 1588,
        "graphPointCount": 2,
        "summary": {
          "averageWaterAvailableLiters": 125000.0,
          "minimumWaterAvailableLiters": 100000.0,
          "maximumWaterAvailableLiters": 140000.0,
          "averageWaterPercent": 44.6,
          "minimumWaterPercent": 35.7,
          "maximumWaterPercent": 50.0
        },
        "data": [
          {
            "timestamp": 1788756300,
            "timestampISO": "2026-09-07T04:45:00+00:00",
            "waterPercent": 43.405,
            "waterAvailableLiters": 121533.12,
            "minimumWaterPercent": 0.0,
            "maximumWaterPercent": 49.16,
            "minimumWaterAvailableLiters": 0.0,
            "maximumWaterAvailableLiters": 137648.0,
            "samples": 32,
            "rawADC": 1231.194,
            "depth": 2170.214,
            "dataCurrent": 10.798,
            "dataVoltage": 1295.775
          },
          {
            "timestamp": 1788759900,
            "timestampISO": "2026-09-07T05:45:00+00:00",
            "waterPercent": 45.120,
            "waterAvailableLiters": 126336.0,
            "minimumWaterPercent": 42.0,
            "maximumWaterPercent": 48.0,
            "minimumWaterAvailableLiters": 117600.0,
            "maximumWaterAvailableLiters": 134400.0,
            "samples": 40,
            "rawADC": 1250.0,
            "depth": 2250.0,
            "dataCurrent": 11.0,
            "dataVoltage": 1310.0
          }
        ]
      };

      final dataList = (backendJson['data'] as List)
          .map((item) => TankHistory.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final summary = HistorySummary.fromJson(backendJson['summary'] as Map<String, dynamic>);

      final result = HistoryDataResult(
        deviceId: backendJson['deviceId'] as String,
        range: backendJson['range'] as String,
        start: backendJson['start'] as int,
        end: backendJson['end'] as int,
        tankCapacity: (backendJson['tankCapacity'] as num).toDouble(),
        bucketSeconds: backendJson['bucketSeconds'] as int,
        rawRecordCount: backendJson['rawRecordCount'] as int,
        graphPointCount: backendJson['graphPointCount'] as int,
        summary: summary,
        data: dataList,
      );

      expect(result.deviceId, 'tank_001');
      expect(result.range, '24h');
      expect(result.data.length, 2);
      expect(result.summary?.averageWaterAvailableLiters, 125000.0);

      // Check first point preserved fields
      final p1 = result.data.first;
      expect(p1.timestamp, 1788756300);
      expect(p1.waterPercent, 43.405);
      expect(p1.waterAvailableLiters, 121533.12);
      expect(p1.minimumWaterPercent, 0.0);
      expect(p1.maximumWaterPercent, 49.16);
      expect(p1.minimumWaterAvailableLiters, 0.0);
      expect(p1.maximumWaterAvailableLiters, 137648.0);
      expect(p1.samples, 32);
      expect(p1.rawADC, 1231.194);
      expect(p1.depth, 2.170214); // mm to meters normalized
      expect(p1.dataCurrent, 10.798);
      expect(p1.dataVoltage, 1295.775);
      expect(p1.timestampISO, '2026-09-07T04:45:00+00:00');

      // Check chronological ordering
      expect(result.data[0].timestamp < result.data[1].timestamp, isTrue);
    });
  });
}
