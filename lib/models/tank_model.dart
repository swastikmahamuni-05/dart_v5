class TankModel {
  final String deviceId;
  final double tankCapacity;
  final double tankHeight;
  final String tankShape;
  final double vref;
  final double correctionFactor;
  final double offset;

  TankModel({
    required this.deviceId,
    required this.tankCapacity,
    required this.tankHeight,
    required this.tankShape,
    required this.vref,
    required this.correctionFactor,
    required this.offset,
  });

  factory TankModel.fromJson(Map<String, dynamic> json) {
    return TankModel(
      deviceId: json['Device_id']?.toString() ?? json['deviceId']?.toString() ?? '',
      tankCapacity: (json['tankCapacity'] as num? ?? 0.0).toDouble(),
      tankHeight: (json['tankHeight'] as num? ?? 0.0).toDouble(),
      tankShape: json['tankShape']?.toString() ?? 'cylindrical',
      vref: (json['VREF'] as num? ?? 3300.0).toDouble(),
      correctionFactor: (json['CORRECTION_FACTOR'] as num? ?? 1.0).toDouble(),
      offset: (json['OFFSET'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Device_id': deviceId,
      'tankCapacity': tankCapacity,
      'tankHeight': tankHeight,
      'tankShape': tankShape,
      'VREF': vref,
      'CORRECTION_FACTOR': correctionFactor,
      'OFFSET': offset,
    };
  }
}
