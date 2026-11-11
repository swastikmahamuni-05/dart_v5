class Alert {
  final String id;
  final String tankId;
  final String tankName;
  final String title;
  final String message;
  // Alert categories: 'critical', 'full', 'offline'
  final String severity;
  final DateTime timestamp;
  final bool isResolved;
  final DateTime? resolvedAt;

  Alert({
    required this.id,
    required this.tankId,
    required this.tankName,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.isResolved = false,
    this.resolvedAt,
  });

  bool get isCritical => severity.toLowerCase() == 'critical';
  bool get isFull => severity.toLowerCase() == 'full';
  bool get isOffline => severity.toLowerCase() == 'offline';

  String get categoryDisplay {
    if (isCritical) return 'CRITICAL';
    if (isFull) return 'FULL (OVERFLOW RISK)';
    if (isOffline) return 'OFFLINE';
    return severity.toUpperCase();
  }

  Alert copyWith({
    String? id,
    String? tankId,
    String? tankName,
    String? title,
    String? message,
    String? severity,
    DateTime? timestamp,
    bool? isResolved,
    DateTime? resolvedAt,
  }) {
    return Alert(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      tankName: tankName ?? this.tankName,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      tankId: json['tankId'] as String,
      tankName: json['tankName'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      severity: json['severity'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isResolved: json['isResolved'] as bool? ?? false,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tankId': tankId,
      'tankName': tankName,
      'title': title,
      'message': message,
      'severity': severity,
      'timestamp': timestamp.toIso8601String(),
      'isResolved': isResolved,
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }
}
