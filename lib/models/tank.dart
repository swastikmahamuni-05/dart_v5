import 'package:intl/intl.dart';
import 'tank_model.dart';
import 'tank_config.dart';
import 'tank_telemetry.dart';

enum DeviceFreshness {
  online,
  stale,
  offline,
  unknown,
  error,
}

class Tank {
  final String tankId;
  final String deviceId;
  final String tankName;
  final String university;
  final String location;
  final String building;
  final String tankType;
  final double tankCapacity;
  final double tankHeight;
  final double vref;
  final double correctionFactor;
  final double offset;
  final double range;
  final double fullThreshold;
  final double lowThreshold;
  final double criticalThreshold;
  final bool isActive;
  final bool isDeleted;
  final String createdAt;
  final String updatedAt;

  // Telemetry/Runtime Fields
  final double currentLevelPercent; // Value between 0.0 and 1.0
  final double temperature; // In Celsius
  final String waterType; // e.g., 'Potable', 'Greywater', 'Rainwater'
  final String status; // 'NORMAL', 'LOW', 'CRITICAL', 'FULL', 'OFFLINE', 'STALE'
  final String lastUpdated;
  final double depth; // Liquid height in meters
  final int rssi; // Signal strength in dBm
  final double battery; // Voltage in Volts
  final int rawADC; // Raw analog-to-digital converter signal (0-4095)
  final double dataVoltage; // Measured battery voltage in mV
  final double dataCurrent; // Measured sensor draw in mA
  final int lastTelemetryTimestamp; // Unix epoch seconds of last telemetry packet

  Tank({
    required this.tankId,
    required this.deviceId,
    required this.tankName,
    this.university = 'MIT ADT University',
    this.location = 'IT Building',
    this.building = 'IT Building',
    this.tankType = 'Underground',
    this.tankCapacity = 25000,
    this.tankHeight = 2500,
    this.vref = 3300,
    this.correctionFactor = 1.41,
    this.offset = 0.0,
    this.range = 2500.0,
    this.fullThreshold = 90.0,
    double? lowThreshold,
    double? warningThreshold,
    this.criticalThreshold = 15.0,
    this.isActive = true,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.currentLevelPercent = 0.41,
    this.temperature = 24.5,
    this.waterType = 'Potable',
    this.status = 'NORMAL',
    this.lastUpdated = '20:12:31',
    this.depth = 1.8,
    this.rssi = -60,
    this.battery = 3.3,
    this.rawADC = 2950,
    this.dataVoltage = 3300.0,
    this.dataCurrent = 4.0,
    this.lastTelemetryTimestamp = 0,
  }) : lowThreshold = lowThreshold ?? warningThreshold ?? 30.0;

  // Backward compatibility getters
  String get id => tankId;
  String get name => tankName;
  String get hwId => deviceId;
  String get buildingName => building;
  double get capacityLitres => tankCapacity;
  double get warningThreshold => lowThreshold;
  double get waterLevel => currentLevelPercent * 100.0;

  // Multi-tier Data Freshness State Model
  DeviceFreshness freshnessState({int onlineTimeout = 90, int staleTimeout = 900}) {
    if (lastTelemetryTimestamp <= 0) return DeviceFreshness.unknown;
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final age = nowSec - lastTelemetryTimestamp;
    if (age < 0) return DeviceFreshness.online; // Tolerates minor clock skew
    if (age <= onlineTimeout) return DeviceFreshness.online;
    if (age <= staleTimeout) return DeviceFreshness.stale;
    return DeviceFreshness.offline;
  }

  // Single source of truth for device online state based on lastSeen telemetry
  bool isOnline([int timeoutSeconds = 90]) {
    if (lastTelemetryTimestamp <= 0) return false;
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return (nowSec - lastTelemetryTimestamp) <= timeoutSeconds;
  }

  bool isStale([int timeoutSeconds = 90, int staleSeconds = 900]) {
    if (lastTelemetryTimestamp <= 0) return false;
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final age = nowSec - lastTelemetryTimestamp;
    return age > timeoutSeconds && age <= staleSeconds;
  }

  bool isOffline([int staleSeconds = 900]) {
    if (lastTelemetryTimestamp <= 0) return true;
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return (nowSec - lastTelemetryTimestamp) > staleSeconds;
  }

  bool isTelemetryStale([int timeoutSeconds = 90]) => !isOnline(timeoutSeconds);

  String get freshnessLabel {
    switch (freshnessState()) {
      case DeviceFreshness.online:
        return 'ONLINE';
      case DeviceFreshness.stale:
        return 'STALE';
      case DeviceFreshness.offline:
        return 'OFFLINE';
      case DeviceFreshness.unknown:
        return 'UNKNOWN';
      case DeviceFreshness.error:
        return 'ERROR';
    }
  }

  String dataAgeFormatted([int? currentTimestampSec]) {
    if (lastTelemetryTimestamp <= 0) return 'Never connected';
    final nowSec = currentTimestampSec ?? (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    final ageSec = (nowSec - lastTelemetryTimestamp).clamp(0, 99999999);
    if (ageSec < 5) return 'Just now';
    if (ageSec < 60) return '$ageSec sec ago';
    if (ageSec < 3600) return '${ageSec ~/ 60} min ago';
    if (ageSec < 86400) return '${ageSec ~/ 3600} hr ago';
    return '${ageSec ~/ 86400} d ago';
  }

  String get formattedFreshnessSummary {
    final label = freshnessLabel;
    final age = dataAgeFormatted();
    if (label == 'ONLINE') return 'ONLINE • $age';
    if (label == 'STALE') return 'STALE • Last data $age';
    if (label == 'OFFLINE') return 'OFFLINE • Last seen $age';
    return label;
  }

  String get lastSeenFormatted {
    if (lastTelemetryTimestamp <= 0) return 'Never Connected';
    final dt = DateTime.fromMillisecondsSinceEpoch(lastTelemetryTimestamp * 1000).toLocal();
    final now = DateTime.now();
    final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    if (isToday) {
      return DateFormat('hh:mm:ss a').format(dt);
    } else {
      return DateFormat('MMM dd, hh:mm a').format(dt);
    }
  }

  // Calculate volume in litres
  double get currentVolumeLitres => tankCapacity * currentLevelPercent;

  // Factory to create a Tank from TankModel
  factory Tank.fromModel(TankModel model) {
    final nameVal = model.deviceId == 'tank_001' || model.deviceId == 'ESP32_001'
        ? 'IT Building Underground Tank'
        : 'TANK ${model.deviceId.replaceAll(RegExp(r'[^0-9]'), '')}';

    return Tank(
      tankId: model.deviceId,
      deviceId: model.deviceId,
      tankName: nameVal,
      university: 'MIT ADT University',
      location: 'IT Building',
      building: 'IT Building',
      tankType: 'Underground',
      tankCapacity: model.tankCapacity > 0 ? model.tankCapacity : 25000.0,
      tankHeight: model.tankHeight > 0 ? model.tankHeight : 2500.0,
      vref: model.vref,
      correctionFactor: model.correctionFactor,
      offset: model.offset,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      waterType: 'Potable',
      status: 'NORMAL',
      lastUpdated: DateFormat('hh:mm:ss a').format(DateTime.now()),
    );
  }

  // Copy with dynamic telemetry update
  Tank copyWithTelemetry(TankTelemetry telemetry, {int timeoutSeconds = 90, int staleTimeoutSeconds = 900}) {
    // Validate and clamp input payload to prevent corrupted telemetry rendering
    final double sanitizedWaterPercent = telemetry.waterPercent.clamp(0.0, 100.0);
    final double levelPct = sanitizedWaterPercent / 100.0;
    final int ts = telemetry.timestamp;

    // Single source of truth online evaluation
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final bool online = ts > 0 && ((nowSec - ts) <= timeoutSeconds);
    final bool stale = ts > 0 && ((nowSec - ts) > timeoutSeconds) && ((nowSec - ts) <= staleTimeoutSeconds);

    // Determine status from telemetry percentage, thresholds, and online validity
    String statusVal = 'OFFLINE';
    if (online) {
      if (levelPct * 100 >= fullThreshold) {
        statusVal = 'FULL';
      } else if (levelPct * 100 < criticalThreshold) {
        statusVal = 'CRITICAL';
      } else if (levelPct * 100 < lowThreshold) {
        statusVal = 'LOW';
      } else {
        statusVal = 'NORMAL';
      }
    } else if (stale) {
      statusVal = 'STALE';
    }

    final packetTime = ts > 0 
        ? DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal()
        : DateTime.now();

    final now = DateTime.now();
    final isToday = now.year == packetTime.year && now.month == packetTime.month && now.day == packetTime.day;

    final String timeStr = ts > 0
        ? (isToday ? DateFormat('hh:mm:ss a').format(packetTime) : DateFormat('MMM dd, hh:mm a').format(packetTime))
        : DateFormat('hh:mm:ss a').format(now);

    final double awsDepth = telemetry.depth > 20.0 ? telemetry.depth / 1000.0 : telemetry.depth;
    final int sanitizedAdc = telemetry.rawADC.round().clamp(0, 4095);

    return copyWith(
      currentLevelPercent: levelPct,
      depth: double.parse(awsDepth.toStringAsFixed(2)),
      rawADC: sanitizedAdc,
      dataVoltage: telemetry.dataVoltage,
      dataCurrent: telemetry.dataCurrent,
      battery: telemetry.dataVoltage > 0 ? telemetry.dataVoltage / 1000.0 : 3.3,
      status: statusVal,
      lastUpdated: timeStr,
      lastTelemetryTimestamp: ts,
      updatedAt: now.toIso8601String(),
    );
  }

  // Periodic offline/stale status check against configured timeout
  Tank checkOfflineStatus({int timeoutSeconds = 90, int staleTimeoutSeconds = 900}) {
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final isDeviceOnline = lastTelemetryTimestamp > 0 && (nowSec - lastTelemetryTimestamp) <= timeoutSeconds;
    final isDeviceStale = lastTelemetryTimestamp > 0 && (nowSec - lastTelemetryTimestamp) > timeoutSeconds && (nowSec - lastTelemetryTimestamp) <= staleTimeoutSeconds;
    final isDeviceOffline = lastTelemetryTimestamp <= 0 || (nowSec - lastTelemetryTimestamp) > staleTimeoutSeconds;

    if (isDeviceOffline && status != 'OFFLINE') {
      return copyWith(status: 'OFFLINE');
    } else if (isDeviceStale && status != 'STALE' && status != 'OFFLINE') {
      return copyWith(status: 'STALE');
    }
    return this;
  }

  // Copy with configuration update
  Tank copyWithConfig(TankConfig config) {
    return copyWith(
      tankCapacity: config.tankCapacity,
      tankHeight: config.tankHeight,
      vref: config.vref,
      correctionFactor: config.correctionFactor,
      offset: config.offset,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  // Copy with helper to easily clone and update single attributes
  Tank copyWith({
    String? tankId,
    String? deviceId,
    String? tankName,
    String? university,
    String? location,
    String? building,
    String? tankType,
    double? tankCapacity,
    double? tankHeight,
    double? vref,
    double? correctionFactor,
    double? offset,
    double? range,
    double? fullThreshold,
    double? lowThreshold,
    double? warningThreshold,
    double? criticalThreshold,
    bool? isActive,
    bool? isDeleted,
    String? createdAt,
    String? updatedAt,
    double? currentLevelPercent,
    double? temperature,
    String? waterType,
    String? status,
    String? lastUpdated,
    double? depth,
    int? rssi,
    double? battery,
    int? rawADC,
    double? dataVoltage,
    double? dataCurrent,
    int? lastTelemetryTimestamp,
  }) {
    return Tank(
      tankId: tankId ?? this.tankId,
      deviceId: deviceId ?? this.deviceId,
      tankName: tankName ?? this.tankName,
      university: university ?? this.university,
      location: location ?? this.location,
      building: building ?? this.building,
      tankType: tankType ?? this.tankType,
      tankCapacity: tankCapacity ?? this.tankCapacity,
      tankHeight: tankHeight ?? this.tankHeight,
      vref: vref ?? this.vref,
      correctionFactor: correctionFactor ?? this.correctionFactor,
      offset: offset ?? this.offset,
      range: range ?? this.range,
      fullThreshold: fullThreshold ?? this.fullThreshold,
      lowThreshold: lowThreshold ?? warningThreshold ?? this.lowThreshold,
      criticalThreshold: criticalThreshold ?? this.criticalThreshold,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentLevelPercent: currentLevelPercent ?? this.currentLevelPercent,
      temperature: temperature ?? this.temperature,
      waterType: waterType ?? this.waterType,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      depth: depth ?? this.depth,
      rssi: rssi ?? this.rssi,
      battery: battery ?? this.battery,
      rawADC: rawADC ?? this.rawADC,
      dataVoltage: dataVoltage ?? this.dataVoltage,
      dataCurrent: dataCurrent ?? this.dataCurrent,
      lastTelemetryTimestamp: lastTelemetryTimestamp ?? this.lastTelemetryTimestamp,
    );
  }

  // Factory constructor for parsing JSON
  factory Tank.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString().toUpperCase() ?? 'NORMAL';
    final ts = (json['lastTelemetryTimestamp'] as num?)?.toInt() ?? 0;
    return Tank(
      tankId: json['tankId']?.toString() ?? json['id']?.toString() ?? json['Device_id']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? json['hwId']?.toString() ?? json['Device_id']?.toString() ?? '',
      tankName: json['tankName']?.toString() ?? json['name']?.toString() ?? 'IT Building Underground Tank',
      university: json['university']?.toString() ?? 'MIT ADT University',
      location: json['location']?.toString() ?? json['building']?.toString() ?? 'IT Building',
      building: json['building']?.toString() ?? json['location']?.toString() ?? 'IT Building',
      tankType: json['tankType']?.toString() ?? 'Underground',
      tankCapacity: (json['tankCapacity'] ?? json['capacityLitres'] as num? ?? 25000.0).toDouble(),
      tankHeight: (json['tankHeight'] as num? ?? 2500.0).toDouble(),
      vref: (json['vref'] ?? json['VREF'] as num? ?? 3300.0).toDouble(),
      correctionFactor: (json['correctionFactor'] ?? json['CORRECTION_FACTOR'] as num? ?? 1.41).toDouble(),
      offset: (json['offset'] ?? json['OFFSET'] as num? ?? 0.0).toDouble(),
      range: (json['range'] as num? ?? 2500.0).toDouble(),
      fullThreshold: (json['fullThreshold'] as num? ?? 90.0).toDouble(),
      lowThreshold: (json['lowThreshold'] ?? json['warningThreshold'] as num? ?? 30.0).toDouble(),
      criticalThreshold: (json['criticalThreshold'] as num? ?? 15.0).toDouble(),
      isActive: json['isActive'] as bool? ?? true,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      currentLevelPercent: double.tryParse(json['currentLevelPercent']?.toString() ?? '') ?? 0.41,
      temperature: double.tryParse(json['temperature']?.toString() ?? '') ?? 24.5,
      waterType: json['waterType']?.toString() ?? 'Potable',
      status: statusStr,
      lastUpdated: json['lastUpdated']?.toString() ?? '20:12:31',
      depth: double.tryParse(json['depth']?.toString() ?? '') ?? 1.8,
      rssi: int.tryParse(json['rssi']?.toString() ?? '') ?? -60,
      battery: double.tryParse(json['battery']?.toString() ?? '') ?? 3.3,
      rawADC: int.tryParse(json['rawADC']?.toString() ?? '') ?? 2950,
      dataVoltage: double.tryParse(json['dataVoltage']?.toString() ?? '') ?? 3300.0,
      dataCurrent: double.tryParse(json['dataCurrent']?.toString() ?? '') ?? 4.0,
      lastTelemetryTimestamp: ts,
    );
  }

  // Convert model to JSON
  Map<String, dynamic> toJson() {
    return {
      'tankId': tankId,
      'deviceId': deviceId,
      'tankName': tankName,
      'university': university,
      'location': location,
      'building': building,
      'tankType': tankType,
      'tankCapacity': tankCapacity,
      'tankHeight': tankHeight,
      'vref': vref,
      'correctionFactor': correctionFactor,
      'offset': offset,
      'range': range,
      'fullThreshold': fullThreshold,
      'lowThreshold': lowThreshold,
      'criticalThreshold': criticalThreshold,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'currentLevelPercent': currentLevelPercent,
      'temperature': temperature,
      'waterType': waterType,
      'status': status,
      'lastUpdated': lastUpdated,
      'depth': depth,
      'rssi': rssi,
      'battery': battery,
      'rawADC': rawADC,
      'dataVoltage': dataVoltage,
      'dataCurrent': dataCurrent,
      'lastTelemetryTimestamp': lastTelemetryTimestamp,
    };
  }

  // Validation Helpers
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Tank name is required';
    }
    return null;
  }

  static String? validateDeviceId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Device ID is required';
    }
    return null;
  }

  static String? validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Building/Location is required';
    }
    return null;
  }

  static String? validatePositiveDouble(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return '$fieldName must be a positive number';
    }
    return null;
  }

  static String? validateNonNegativeDouble(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0) {
      return '$fieldName must be a non-negative number';
    }
    return null;
  }
}
