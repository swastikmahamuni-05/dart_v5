import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  UserModel? _currentUser;
  bool _isLoading = false;

  bool get isAuthenticated => _isAuthenticated;
  UserModel? get currentUser => _currentUser;
  String? get userName => _currentUser?.name;
  String? get userEmail => _currentUser?.email;
  UserRole get currentRole => _currentUser?.role ?? UserRole.operator;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isOperator => _currentUser?.isOperator ?? false;
  bool get isLoading => _isLoading;

  // Pre-configured default users
  final List<UserModel> _systemUsers = [
    UserModel(
      id: 'USR-001',
      name: 'Dr. Marcus Vance',
      email: 'admin@mit.edu',
      role: UserRole.admin,
      assignedBuildings: ['IT Building'],
      assignedTanks: ['tank_001'],
      isActive: true,
      lastLogin: 'Today, 10:15 AM',
    ),
    UserModel(
      id: 'USR-002',
      name: 'Ramesh Sharma',
      email: 'operator@mit.edu',
      role: UserRole.operator,
      assignedBuildings: ['IT Building'],
      assignedTanks: ['tank_001'],
      isActive: true,
      lastLogin: 'Today, 08:30 AM',
    ),
  ];

  List<UserModel> get systemUsers => List.unmodifiable(_systemUsers);

  // Authenticate user with role resolution
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isNotEmpty && normalizedEmail.contains('@') && password.length >= 6) {
      if (normalizedEmail.contains('admin')) {
        _currentUser = _systemUsers.firstWhere(
          (u) => u.role == UserRole.admin,
          orElse: () => UserModel(
            id: 'USR-001',
            name: 'Dr. Marcus Vance',
            email: email,
            role: UserRole.admin,
            lastLogin: 'Just now',
          ),
        );
      } else {
        _currentUser = _systemUsers.firstWhere(
          (u) => u.email.toLowerCase() == normalizedEmail,
          orElse: () => UserModel(
            id: 'USR-${DateTime.now().millisecondsSinceEpoch % 1000}',
            name: normalizedEmail.split('@')[0].toUpperCase(),
            email: email,
            role: UserRole.operator,
            lastLogin: 'Just now',
          ),
        );
      }

      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout function
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    _isAuthenticated = false;
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }
}
