import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../providers/tank_provider.dart';

class MqttService extends ChangeNotifier {
  final TankProvider _tankProvider;
  MqttServerClient? _client;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _brokerAddress = 'broker.hivemq.com';
  int _brokerPort = 1883;
  String _clientId = 'water_tank_client_';

  // Simulator properties (strictly for optional manual diagnostics, disabled by default)
  Timer? _simulatorTimer;
  bool _isSimulatorRunning = false;
  int _refreshIntervalSeconds = 5;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get brokerAddress => _brokerAddress;
  int get brokerPort => _brokerPort;
  bool get isSimulatorRunning => _isSimulatorRunning;
  int get refreshIntervalSeconds => _refreshIntervalSeconds;

  MqttService(this._tankProvider) {
    _clientId += Random().nextInt(10000).toString();
    // Do not start simulator in production
  }

  // Start background telemetry simulation
  void startSimulator() {
    _isSimulatorRunning = true;
    _simulatorTimer?.cancel();
    _simulatorTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (timer) {
      final Random r = Random();
      for (var tank in _tankProvider.tanks) {
        if (tank.status == 'offline') continue;
        // Random drift up or down
        double change = (r.nextDouble() - 0.5) * 0.03;
        double newLevel = (tank.currentLevelPercent + change).clamp(0.02, 1.0);
        // Drifting temperature slowly
        double tempDrift = (r.nextDouble() - 0.5) * 0.4;
        double newTemp = (tank.temperature + tempDrift).clamp(15.0, 35.0);

        _tankProvider.updateTankLevelMock(tank.tankId, newLevel, newTemp);
      }
    });
    notifyListeners();
  }

  void updateRefreshInterval(int seconds) {
    _refreshIntervalSeconds = seconds;
    if (_isSimulatorRunning) {
      startSimulator();
    }
    notifyListeners();
  }

  // Stop background simulator
  void stopSimulator() {
    _isSimulatorRunning = false;
    _simulatorTimer?.cancel();
    notifyListeners();
  }

  // Connect to the MQTT Broker
  Future<bool> connect(String broker, int port) async {
    _brokerAddress = broker;
    _brokerPort = port;
    _isConnecting = true;
    notifyListeners();

    // If simulator was running, pause it during real broker connection attempts
    bool wasSimulatorRunning = _isSimulatorRunning;
    stopSimulator();

    _client = MqttServerClient.withPort(_brokerAddress, _clientId, _brokerPort);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      if (kDebugMode) {
        print('MQTT Service: Attempting to connect to $_brokerAddress:$_brokerPort');
      }
      await _client!.connect();
      _isConnecting = false;
      _isConnected = true;
      notifyListeners();

      // Subscribe to all tank telemetry topics
      subscribeToTelemetry();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('MQTT Connection failed: $e');
      }
      _isConnecting = false;
      _isConnected = false;
      _client = null;
      notifyListeners();
      
      // Fallback: resume simulator if connection failed
      if (wasSimulatorRunning) {
        startSimulator();
      }
      return false;
    }
  }

  // Disconnect from broker
  void disconnect() {
    _client?.disconnect();
    _onDisconnected();
  }

  void _onConnected() {
    _isConnected = true;
    _isConnecting = false;
    notifyListeners();
  }

  void _onDisconnected() {
    _isConnected = false;
    _isConnecting = false;
    _client = null;
    notifyListeners();
  }

  void _onSubscribed(String topic) {
    if (kDebugMode) {
      print('MQTT Service: Successfully subscribed to topic: $topic');
    }
  }

  // Subscribe to telemetry
  void subscribeToTelemetry() {
    if (_client == null || !_isConnected) return;

    const topic = 'watertanks/+/telemetry';
    _client!.subscribe(topic, MqttQos.atMostOnce);
    
    // Listen for incoming payload messages
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      try {
        // Attempt to parse as JSON first (handles updated cloud format)
        final Map<String, dynamic> jsonObj = jsonDecode(pt);
        _tankProvider.updateTankFromTelemetryJson(jsonObj);
      } catch (e) {
        // Fallback to legacy comma-separated values (CSV) format
        try {
          final parts = pt.split(',');
          if (parts.length >= 3) {
            final tankId = parts[0];
            final level = double.parse(parts[1]);
            final temp = double.parse(parts[2]);
            
            _tankProvider.updateTankFromTelemetryJson({
              'Device_id': tankId,
              'waterPercent': level <= 1.0 ? level * 100.0 : level,
              'temperature': temp,
              'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
            });
          }
        } catch (csvError) {
          if (kDebugMode) {
            print('MQTT Payload Parsing Error (both JSON and CSV failed): $e | CSV error: $csvError');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _simulatorTimer?.cancel();
    disconnect();
    super.dispose();
  }
}
