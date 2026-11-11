import 'package:intl/intl.dart';
import '../models/tank.dart';

class TankService {
  final List<Tank> _tanks = [];

  TankService() {
    _loadConfirmedDeploymentTank();
  }

  void _loadConfirmedDeploymentTank() {
    // Only ONE tank location is currently confirmed for MIT ADT University:
    // University: MIT ADT University
    // Building: IT Building
    // Tank Name: IT Building Underground Tank
    // Tank Type: Underground
    // Device ID: tank_001
    _tanks.add(
      Tank(
        tankId: 'tank_001',
        deviceId: 'tank_001',
        tankName: 'IT Building Underground Tank',
        university: 'MIT ADT University',
        location: 'IT Building',
        building: 'IT Building',
        tankType: 'Underground',
        tankCapacity: 25000.0,
        tankHeight: 2500.0,
        vref: 3300.0,
        correctionFactor: 1.41,
        offset: 0.0,
        range: 2500.0,
        fullThreshold: 95.0,
        lowThreshold: 30.0,
        criticalThreshold: 15.0,
        isActive: true,
        isDeleted: false,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        currentLevelPercent: 0.410, // 41.0% (Matches confirmed live AWS telemetry)
        temperature: 24.5,
        waterType: 'Potable',
        status: 'NORMAL',
        lastUpdated: DateFormat('hh:mm:ss a').format(DateTime.now()),
        depth: 2.05,
        rssi: -58,
        battery: 3.3,
        rawADC: 1205,
        dataVoltage: 1268.0,
        dataCurrent: 10.57,
      ),
    );
  }

  List<Tank> getTanks() {
    return List.unmodifiable(_tanks);
  }

  void addTank(Tank tank) {
    _tanks.add(tank);
  }

  void updateTank(Tank tank) {
    final idx = _tanks.indexWhere((t) => t.tankId == tank.tankId || t.deviceId == tank.deviceId);
    if (idx != -1) {
      _tanks[idx] = tank;
    } else {
      _tanks.add(tank);
    }
  }

  void deleteTank(String tankId) {
    final idx = _tanks.indexWhere((t) => t.tankId == tankId || t.deviceId == tankId);
    if (idx != -1) {
      _tanks[idx] = _tanks[idx].copyWith(isDeleted: true, updatedAt: DateTime.now().toIso8601String());
    }
  }
}
