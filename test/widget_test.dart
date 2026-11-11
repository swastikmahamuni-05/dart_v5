// This is a basic Flutter widget test for the Water Tank Monitoring application.
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:water_tank_monitor/main.dart';
import 'package:water_tank_monitor/services/auth_service.dart';
import 'package:water_tank_monitor/services/tank_service.dart';
import 'package:water_tank_monitor/services/api_service.dart';
import 'package:water_tank_monitor/providers/tank_provider.dart';
import 'package:water_tank_monitor/services/mqtt_service.dart';

import 'package:water_tank_monitor/models/tank_model.dart';
import 'package:water_tank_monitor/models/tank_telemetry.dart';

class FakeApiService extends ApiService {
  @override
  Future<List<TankModel>> getAllTanks() async {
    return [
      TankModel(
        deviceId: '1',
        tankCapacity: 25000.0,
        tankHeight: 5000.0,
        tankShape: 'cylindrical',
        vref: 3300.0,
        correctionFactor: 1.41,
        offset: 0.0,
      ),
      TankModel(
        deviceId: '2',
        tankCapacity: 10000.0,
        tankHeight: 4000.0,
        tankShape: 'cylindrical',
        vref: 3300.0,
        correctionFactor: 1.41,
        offset: 0.0,
      ),
      TankModel(
        deviceId: '3',
        tankCapacity: 15000.0,
        tankHeight: 5000.0,
        tankShape: 'cylindrical',
        vref: 3300.0,
        correctionFactor: 1.41,
        offset: 0.0,
      ),
      TankModel(
        deviceId: '4',
        tankCapacity: 8000.0,
        tankHeight: 3000.0,
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
      waterPercent: 50.0,
      depth: 2.5,
      rawADC: 2048,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      dataVoltage: 3300,
      dataCurrent: 4.0,
    );
  }
}

void main() {
  testWidgets('App launch and Login screen render test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthService()),
          Provider(create: (_) => TankService()),
          Provider<ApiService>(create: (_) => FakeApiService()),
          ChangeNotifierProvider(
            create: (context) => TankProvider(
              Provider.of<TankService>(context, listen: false),
              Provider.of<ApiService>(context, listen: false),
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => MqttService(
              Provider.of<TankProvider>(context, listen: false),
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify that our app title is present.
    expect(find.text('LEVELS'), findsWidgets);
  });
}
