enum TankEventType {
  stateTransition,
  connectivity,
  alertTrigger,
  alertRecovery,
}

class TankEvent {
  final String id;
  final String tankId;
  final String tankName;
  final String building;
  final DateTime timestamp;
  final TankEventType eventType;
  final String previousState;
  final String newState;
  final String details;

  TankEvent({
    required this.id,
    required this.tankId,
    required this.tankName,
    required this.building,
    required this.timestamp,
    required this.eventType,
    required this.previousState,
    required this.newState,
    required this.details,
  });

  String get eventTypeDisplay {
    switch (eventType) {
      case TankEventType.stateTransition:
        return 'State Transition';
      case TankEventType.connectivity:
        return 'Connectivity Change';
      case TankEventType.alertTrigger:
        return 'Alert Triggered';
      case TankEventType.alertRecovery:
        return 'Alert Recovered';
    }
  }

  factory TankEvent.fromJson(Map<String, dynamic> json) {
    TankEventType parseType(String? val) {
      switch (val?.toUpperCase()) {
        case 'CONNECTIVITY':
          return TankEventType.connectivity;
        case 'ALERT_TRIGGER':
          return TankEventType.alertTrigger;
        case 'ALERT_RECOVERY':
          return TankEventType.alertRecovery;
        default:
          return TankEventType.stateTransition;
      }
    }

    return TankEvent(
      id: json['id'] as String? ?? 'EVT-${DateTime.now().millisecondsSinceEpoch}',
      tankId: json['tankId'] as String? ?? '',
      tankName: json['tankName'] as String? ?? 'Tank',
      building: json['building'] as String? ?? 'Campus Building',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      eventType: parseType(json['eventType'] as String?),
      previousState: json['previousState'] as String? ?? 'NORMAL',
      newState: json['newState'] as String? ?? 'NORMAL',
      details: json['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tankId': tankId,
      'tankName': tankName,
      'building': building,
      'timestamp': timestamp.toIso8601String(),
      'eventType': eventType.name,
      'previousState': previousState,
      'newState': newState,
      'details': details,
    };
  }
}
