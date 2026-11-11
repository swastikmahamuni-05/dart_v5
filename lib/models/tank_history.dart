class HistorySummary {
  final double? averageWaterAvailableLiters;
  final double? minimumWaterAvailableLiters;
  final double? maximumWaterAvailableLiters;
  final double? averageWaterPercent;
  final double? minimumWaterPercent;
  final double? maximumWaterPercent;

  const HistorySummary({
    this.averageWaterAvailableLiters,
    this.minimumWaterAvailableLiters,
    this.maximumWaterAvailableLiters,
    this.averageWaterPercent,
    this.minimumWaterPercent,
    this.maximumWaterPercent,
  });

  factory HistorySummary.fromJson(Map<String, dynamic> json) {
    double? parseD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return HistorySummary(
      averageWaterAvailableLiters: parseD(json['averageWaterAvailableLiters']),
      minimumWaterAvailableLiters: parseD(json['minimumWaterAvailableLiters']),
      maximumWaterAvailableLiters: parseD(json['maximumWaterAvailableLiters']),
      averageWaterPercent: parseD(json['averageWaterPercent']),
      minimumWaterPercent: parseD(json['minimumWaterPercent']),
      maximumWaterPercent: parseD(json['maximumWaterPercent']),
    );
  }

  Map<String, dynamic> toJson() => {
    'averageWaterAvailableLiters': averageWaterAvailableLiters,
    'minimumWaterAvailableLiters': minimumWaterAvailableLiters,
    'maximumWaterAvailableLiters': maximumWaterAvailableLiters,
    'averageWaterPercent': averageWaterPercent,
    'minimumWaterPercent': minimumWaterPercent,
    'maximumWaterPercent': maximumWaterPercent,
  };
}

class HistoryDataResult {
  final String? deviceId;
  final String? range;
  final int? start;
  final int? end;
  final double? tankCapacity;
  final int? bucketSeconds;
  final int? rawRecordCount;
  final int? graphPointCount;
  final HistorySummary? summary;
  final List<TankHistory> data;

  const HistoryDataResult({
    this.deviceId,
    this.range,
    this.start,
    this.end,
    this.tankCapacity,
    this.bucketSeconds,
    this.rawRecordCount,
    this.graphPointCount,
    this.summary,
    required this.data,
  });
}

class TankHistory {
  final double waterPercent;
  final double depth;
  final int timestamp;
  final double? waterAvailableLiters;
  final double? minimumWaterPercent;
  final double? maximumWaterPercent;
  final double? minimumWaterAvailableLiters;
  final double? maximumWaterAvailableLiters;
  final int? samples;
  final double? rawADC;
  final double? dataCurrent;
  final double? dataVoltage;
  final String? timestampISO;

  TankHistory({
    required this.waterPercent,
    required this.depth,
    required this.timestamp,
    this.waterAvailableLiters,
    this.minimumWaterPercent,
    this.maximumWaterPercent,
    this.minimumWaterAvailableLiters,
    this.maximumWaterAvailableLiters,
    this.samples,
    this.rawADC,
    this.dataCurrent,
    this.dataVoltage,
    this.timestampISO,
  });

  factory TankHistory.fromJson(Map<String, dynamic> json) {
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
    // Normalize if timestamp is in milliseconds (13 digits)
    if (timestampVal > 100000000000) {
      timestampVal = timestampVal ~/ 1000;
    }

    double rawDepth = (json['waterDepth'] as num? ?? 
           json['depth'] as num? ?? 
           double.tryParse(json['waterDepth']?.toString() ?? '') ?? 
           double.tryParse(json['depth']?.toString() ?? '') ?? 0.0).toDouble();
    if (rawDepth > 20.0) {
      rawDepth = rawDepth / 1000.0;
    }

    double? parseDoubleField(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? parseIntField(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return TankHistory(
      waterPercent: (json['waterLevelPercent'] as num? ?? 
                    json['waterPercent'] as num? ?? 
                    double.tryParse(json['waterLevelPercent']?.toString() ?? '') ?? 
                    double.tryParse(json['waterPercent']?.toString() ?? '') ?? 0.0).toDouble(),
      depth: rawDepth,
      timestamp: timestampVal,
      waterAvailableLiters: parseDoubleField(json['waterAvailableLiters'] ?? json['waterAvailable']),
      minimumWaterPercent: parseDoubleField(json['minimumWaterPercent'] ?? json['minWaterPercent']),
      maximumWaterPercent: parseDoubleField(json['maximumWaterPercent'] ?? json['maxWaterPercent']),
      minimumWaterAvailableLiters: parseDoubleField(json['minimumWaterAvailableLiters'] ?? json['minWaterAvailableLiters']),
      maximumWaterAvailableLiters: parseDoubleField(json['maximumWaterAvailableLiters'] ?? json['maxWaterAvailableLiters']),
      samples: parseIntField(json['samples']),
      rawADC: parseDoubleField(json['rawADC']),
      dataCurrent: parseDoubleField(json['dataCurrent']),
      dataVoltage: parseDoubleField(json['dataVoltage']),
      timestampISO: json['timestampISO']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waterPercent': waterPercent,
      'depth': depth,
      'timestamp': timestamp,
      if (waterAvailableLiters != null) 'waterAvailableLiters': waterAvailableLiters,
      if (minimumWaterPercent != null) 'minimumWaterPercent': minimumWaterPercent,
      if (maximumWaterPercent != null) 'maximumWaterPercent': maximumWaterPercent,
      if (minimumWaterAvailableLiters != null) 'minimumWaterAvailableLiters': minimumWaterAvailableLiters,
      if (maximumWaterAvailableLiters != null) 'maximumWaterAvailableLiters': maximumWaterAvailableLiters,
      if (samples != null) 'samples': samples,
      if (rawADC != null) 'rawADC': rawADC,
      if (dataCurrent != null) 'dataCurrent': dataCurrent,
      if (dataVoltage != null) 'dataVoltage': dataVoltage,
      if (timestampISO != null) 'timestampISO': timestampISO,
    };
  }
}

class RangeConfig {
  static const List<String> hourlyRanges = ['1h', '6h', '24h', '2d', '7d'];
  static const List<String> dailyRanges = ['7d', '15d', '30d', '90d'];
  static const List<String> monthlyRanges = ['6m', '12m', '24m'];
  static const List<String> yearlyRanges = ['1y', '3y', '5y'];

  static const List<String> allRanges = [
    '1h', '6h', '24h', '2d', '7d', '15d', '30d', '90d',
    '6m', '12m', '24m', '1y', '3y', '5y',
  ];

  static int getDurationSeconds(String range) {
    switch (range.toLowerCase()) {
      case '1h':
        return 3600;
      case '6h':
        return 6 * 3600;
      case '24h':
        return 24 * 3600;
      case '2d':
        return 2 * 86400;
      case '7d':
        return 7 * 86400;
      case '15d':
        return 15 * 86400;
      case '30d':
        return 30 * 86400;
      case '90d':
        return 90 * 86400;
      case '6m':
        return 180 * 86400;
      case '12m':
        return 365 * 86400;
      case '24m':
        return 730 * 86400;
      case '1y':
        return 365 * 86400;
      case '3y':
        return 3 * 365 * 86400;
      case '5y':
        return 5 * 365 * 86400;
      default:
        return 24 * 3600;
    }
  }

  static Duration getDuration(String range) {
    return Duration(seconds: getDurationSeconds(range));
  }
}

