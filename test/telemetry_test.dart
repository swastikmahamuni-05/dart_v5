import 'package:flutter_test/flutter_test.dart';
import 'package:water_tank_monitor/services/tank_service.dart';
import 'package:water_tank_monitor/providers/tank_provider.dart';
import 'package:water_tank_monitor/services/api_service.dart';
import 'package:water_tank_monitor/models/tank_model.dart';
import 'package:water_tank_monitor/models/tank_telemetry.dart';

class FakeApiService extends ApiService {
  @override
  Future<List<TankModel>> getAllTanks() async {
    return [
      TankModel(
        deviceId: 'tank_001',
        tankCapacity: 25000.0,
        tankHeight: 2500.0,
        tankShape: 'cylindrical',
        vref: 3300.0,
        correctionFactor: 1.41,
        offset: 0.0,
      ),
    ];
  }

  @override
  Future<TankTelemetry> getLatestTankData(String deviceId) async {
    return TankTelemetry(
      deviceId: deviceId,
      waterPercent: 72.0,
      depth: 1.8,
      rawADC: 2950,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      dataVoltage: 3300,
      dataCurrent: 4.0,
    );
  }
}

void main() {
  group('Cloud Telemetry JSON Parsing Tests', () {
    late TankService tankService;
    late TankProvider tankProvider;

    setUp(() {
      tankService = TankService();
      tankProvider = TankProvider(tankService, FakeApiService());
    });

    test('should update tank properties correctly from cloud JSON payload', () {
      const deviceId = 'tank_001';

      final jsonPayload = {
        "Device_id": deviceId,
        "timestamp": 1718200000,
        "rawADC": 2950.0,
        "currentLevelPercent": 0.85,
        "depth": 2.12,
        "temperature": 24.5,
        "battery": 3.3,
        "rssi": -58,
        "status": "NORMAL"
      };

      tankProvider.updateTankFromTelemetryJson(jsonPayload);

      final updatedTank = tankProvider.tanks.firstWhere((t) => t.deviceId == deviceId);
      
      expect(updatedTank.rawADC, 2950);
      expect(updatedTank.currentLevelPercent, 0.85);
      expect(updatedTank.depth, 2.12);
      expect(updatedTank.temperature, 24.5);
      expect(updatedTank.battery, 3.3);
      expect(updatedTank.rssi, -58);
      expect(updatedTank.status, 'NORMAL');
    });

    test('should fallback to default status calculation if status is missing in JSON', () {
      const deviceId = 'tank_001';

      final jsonPayload = {
        "Device_id": deviceId,
        "timestamp": 1718200000,
        "rawADC": 500.0,
        "currentLevelPercent": 0.10, // Below 0.15 critical threshold
        "temperature": 21.0,
      };

      tankProvider.updateTankFromTelemetryJson(jsonPayload);

      final updatedTank = tankProvider.tanks.firstWhere((t) => t.deviceId == deviceId);
      
      expect(updatedTank.rawADC, 500);
      expect(updatedTank.currentLevelPercent, 0.10);
      expect(updatedTank.status, 'CRITICAL');
    });
  });
}
