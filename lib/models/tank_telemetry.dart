class TankTelemetry {
  final String deviceId;
  final double waterPercent;
  final double depth;
  final double rawADC;
  final double dataVoltage;
  final double dataCurrent;
  final int timestamp;

  TankTelemetry({
    required this.deviceId,
    required this.waterPercent,
    required this.depth,
    required this.rawADC,
    required this.dataVoltage,
    required this.dataCurrent,
    required this.timestamp,
  });

  factory TankTelemetry.fromJson(Map<String, dynamic> json) {
    int timestampVal = 0;
    final rawTimestamp = json['timestamp'];
    if (rawTimestamp != null) {
      if (rawTimestamp is num) {
        timestampVal = rawTimestamp.round();
      } else {
        final parsedNum = int.tryParse(rawTimestamp.toString());
        if (parsedNum != null) {
          timestampVal = parsedNum;
        } else {
          try {
            timestampVal = DateTime.parse(rawTimestamp.toString()).millisecondsSinceEpoch ~/ 1000;
          } catch (_) {
            timestampVal = 0;
          }
        }
      }
    }

    return TankTelemetry(
      deviceId: json['Device_id']?.toString() ?? json['deviceId']?.toString() ?? '',
      waterPercent: (json['waterLevelPercent'] as num? ?? 
                    json['waterPercent'] as num? ?? 
                    double.tryParse(json['waterLevelPercent']?.toString() ?? '') ?? 
                    double.tryParse(json['waterPercent']?.toString() ?? '') ?? 0.0).toDouble(),
      depth: (json['waterDepth'] as num? ?? 
             json['depth'] as num? ?? 
             double.tryParse(json['waterDepth']?.toString() ?? '') ?? 
             double.tryParse(json['depth']?.toString() ?? '') ?? 0.0).toDouble(),
      rawADC: (json['rawADC'] as num? ?? double.tryParse(json['rawADC']?.toString() ?? '') ?? 0.0).toDouble(),
      dataVoltage: (json['dataVoltage'] as num? ?? double.tryParse(json['dataVoltage']?.toString() ?? '') ?? 0.0).toDouble(),
      dataCurrent: (json['dataCurrent'] as num? ?? double.tryParse(json['dataCurrent']?.toString() ?? '') ?? 0.0).toDouble(),
      timestamp: timestampVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Device_id': deviceId,
      'waterPercent': waterPercent,
      'depth': depth,
      'rawADC': rawADC,
      'dataVoltage': dataVoltage,
      'dataCurrent': dataCurrent,
      'timestamp': timestamp,
    };
  }
}
