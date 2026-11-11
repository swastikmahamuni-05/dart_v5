@Timeout(Duration(seconds: 90))
import 'package:flutter_test/flutter_test.dart';
import 'package:water_tank_monitor/services/api_service.dart';
import 'package:water_tank_monitor/services/tank_service.dart';
import 'package:water_tank_monitor/providers/tank_provider.dart';

void main() {
  test('Diagnose complete Flutter history request for tank_001 with range=24h and range=1h', () async {
    final apiService = ApiService();
    final tankService = TankService();
    final provider = TankProvider(tankService, apiService);

    print('\n==================================================');
    print('TEST 1: Flutter Request with range=24h');
    print('==================================================');
    try {
      final res24 = await apiService.getTankHistory('tank_001', range: '24h');
      print('24h Result points: ${res24.data.length}');
    } catch (e) {
      print('24h Failed with: $e');
    }

    print('\n==================================================');
    print('TEST 2: Flutter Request with range=1h');
    print('==================================================');
    try {
      final res1 = await apiService.getTankHistory('tank_001', range: '1h');
      print('1h Result:');
      print('  deviceId: ${res1.deviceId}');
      print('  range: ${res1.range}');
      print('  points count: ${res1.data.length}');
      print('  first point: ${res1.data.first.waterPercent}% at ${res1.data.first.timestamp}');
      print('  last point: ${res1.data.last.waterPercent}% at ${res1.data.last.timestamp}');
    } catch (e) {
      print('1h Failed with: $e');
    }
  });
}
