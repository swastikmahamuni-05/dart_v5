enum UserRole {
  admin,
  operator,
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final List<String> assignedBuildings;
  final List<String> assignedTanks;
  final bool isActive;
  final String lastLogin;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.assignedBuildings = const ['IT Building'],
    this.assignedTanks = const ['tank_001'],
    this.isActive = true,
    required this.lastLogin,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isOperator => role == UserRole.operator;

  String get roleName {
    switch (role) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.operator:
        return 'OPERATOR';
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] ?? 'OPERATOR').toString().toUpperCase();
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: roleStr == 'ADMIN' ? UserRole.admin : UserRole.operator,
      assignedBuildings: json['assignedBuildings'] != null
          ? List<String>.from(json['assignedBuildings'])
          : ['IT Building'],
      assignedTanks: json['assignedTanks'] != null
          ? List<String>.from(json['assignedTanks'])
          : ['tank_001'],
      isActive: json['isActive'] as bool? ?? true,
      lastLogin: json['lastLogin']?.toString() ?? 'Just now',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': roleName,
      'assignedBuildings': assignedBuildings,
      'assignedTanks': assignedTanks,
      'isActive': isActive,
      'lastLogin': lastLogin,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    List<String>? assignedBuildings,
    List<String>? assignedTanks,
    bool? isActive,
    String? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      assignedBuildings: assignedBuildings ?? this.assignedBuildings,
      assignedTanks: assignedTanks ?? this.assignedTanks,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
