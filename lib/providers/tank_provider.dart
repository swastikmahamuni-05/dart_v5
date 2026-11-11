import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tank_event.dart';
import '../models/tank.dart';
import '../models/alert.dart';
import '../models/notification.dart';
import '../models/tank_history.dart';
import '../models/historical_graph_config.dart';
import '../models/tank_config.dart';
import '../models/user_model.dart';
import '../services/tank_service.dart';
import '../services/api_service.dart';
import '../utils/connectivity.dart';

class BuildingSummary {
  final String buildingName;
  final int totalTanks;
  final int onlineDevices;
  final int activeAlerts;
  final String statusSummary;

  BuildingSummary({
    required this.buildingName,
    required this.totalTanks,
    required this.onlineDevices,
    required this.activeAlerts,
    required this.statusSummary,
  });
}

class TankProvider extends ChangeNotifier {
  final TankService _tankService;
  final ApiService _apiService;
  List<Tank> _tanks = [];
  List<Alert> _alerts = [];
  List<AppNotification> _notifications = [];
  List<TankEvent> _events = [];
  List<String> _telemetryLogs = [];
  List<UserModel> _users = [];
  final Map<String, List<TankHistory>> _historyStore = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Selected filters
  String _selectedBuilding = 'ALL';
  String _selectedTankType = 'ALL';
  String _selectedStatusFilter = 'ALL';
  String _searchQuery = '';

  String get selectedBuilding => _selectedBuilding;
  String get selectedTankType => _selectedTankType;
  String get selectedStatusFilter => _selectedStatusFilter;
  String get searchQuery => _searchQuery;

  void setSelectedBuilding(String building) {
    _selectedBuilding = building;
    notifyListeners();
  }

  void setSelectedTankType(String type) {
    _selectedTankType = type;
    notifyListeners();
  }

  void setSelectedStatusFilter(String status) {
    _selectedStatusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Multi-Criteria Filtered Tanks Getter
  List<Tank> get filteredTanks {
    return tanks.where((tank) {
      if (_selectedBuilding != 'ALL' && tank.building.toLowerCase() != _selectedBuilding.toLowerCase()) {
        return false;
      }
      if (_selectedTankType != 'ALL' && tank.tankType.toLowerCase() != _selectedTankType.toLowerCase()) {
        return false;
      }
      if (_selectedStatusFilter != 'ALL' && tank.status.toUpperCase() != _selectedStatusFilter.toUpperCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = tank.tankName.toLowerCase().contains(query);
        final matchesId = tank.deviceId.toLowerCase().contains(query);
        final matchesBuilding = tank.building.toLowerCase().contains(query);
        if (!matchesName && !matchesId && !matchesBuilding) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Caching historical data
  List<TankHistory> _history = [];
  List<TankHistory> get history => _history;
  HistorySummary? _historySummary;
  HistorySummary? get historySummary => _historySummary;
  HistoryDataResult? _historyResult;
  HistoryDataResult? get historyResult => _historyResult;
  bool _isHistoryLoading = false;
  bool get isHistoryLoading => _isHistoryLoading;
  String? _historyError;
  String? get historyError => _historyError;
  String _activeHistoryRange = '24h';
  String get activeHistoryRange => _activeHistoryRange;
  final Map<String, HistorySummary> _historySummaryStore = {};
  final Map<String, HistoryDataResult> _historyResultStore = {};

  // Config state tracking
  bool _isConfigLoading = false;
  bool get isConfigLoading => _isConfigLoading;
  String? _configError;
  String? get configError => _configError;

  // Telemetry details state tracking
  bool _isTelemetryLoading = false;
  bool get isTelemetryLoading => _isTelemetryLoading;
  String? _telemetryError;
  String? get telemetryError => _telemetryError;

  // Auto Refresh Polling
  Timer? _refreshTimer;

  // Global threshold defaults
  double _lowThreshold = 30.0; // 30%
  double _criticalThreshold = 15.0; // 15%
  double _fullThreshold = 90.0; // 90% per Section 23
  String _apiEndpoint = 'https://cudwq7s6w0.execute-api.ap-south-1.amazonaws.com/prod';

  // Configurable offline timeout (default 90 seconds, tolerates 2-3 telemetry intervals)
  int _offlineTimeoutSeconds = 90;
  int _staleTimeoutSeconds = 900; // 15 minutes
  int get offlineTimeoutSeconds => _offlineTimeoutSeconds;
  int get staleTimeoutSeconds => _staleTimeoutSeconds;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get lastSyncFormatted => _lastSyncTime != null 
      ? DateFormat('hh:mm:ss a').format(_lastSyncTime!) 
      : 'Never';

  void setOfflineTimeoutSeconds(int seconds) {
    _offlineTimeoutSeconds = seconds;
    checkAllTanksOfflineStatus();
    notifyListeners();
  }

  void setStaleTimeoutSeconds(int seconds) {
    _staleTimeoutSeconds = seconds;
    checkAllTanksOfflineStatus();
    notifyListeners();
  }

  List<Tank> get allTanks => _tanks;
  
  // Filter out soft deleted tanks for dashboard and monitoring screens
  List<Tank> get tanks => _tanks.where((t) => !t.isDeleted).toList();
  
  // Get tanks assigned to specific building
  List<Tank> getTanksByBuilding(String buildingName) {
    return tanks.where((t) => t.building.toLowerCase() == buildingName.toLowerCase()).toList();
  }

  List<Alert> get alerts => _alerts;
  List<AppNotification> get notifications => _notifications;
  List<TankEvent> get events => _events;
  List<String> get telemetryLogs => _telemetryLogs;
  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Dynamic Building Summaries (Section 14 & 15)
  List<BuildingSummary> get buildingSummaries {
    final Map<String, List<Tank>> byBuilding = {};
    for (var tank in tanks) {
      byBuilding.putIfAbsent(tank.building, () => []).add(tank);
    }

    return byBuilding.entries.map((entry) {
      final bTanks = entry.value;
      final onlineCount = bTanks.where((t) => t.status != 'OFFLINE').length;
      final tankIds = bTanks.map((t) => t.tankId).toSet();
      final activeAlertsCount = _alerts.where((a) => !a.isResolved && tankIds.contains(a.tankId)).length;

      String status = 'NORMAL';
      if (bTanks.any((t) => t.status == 'CRITICAL')) {
        status = 'CRITICAL';
      } else if (bTanks.any((t) => t.status == 'FULL')) {
        status = 'FULL';
      } else if (bTanks.any((t) => t.status == 'OFFLINE')) {
        status = 'OFFLINE';
      } else if (bTanks.any((t) => t.status == 'LOW')) {
        status = 'LOW';
      }

      return BuildingSummary(
        buildingName: entry.key,
        totalTanks: bTanks.length,
        onlineDevices: onlineCount,
        activeAlerts: activeAlertsCount,
        statusSummary: status,
      );
    }).toList();
  }

  int get totalMonitoredBuildings => buildingSummaries.length;
  
  double get lowThreshold => _lowThreshold;
  double get criticalThreshold => _criticalThreshold;
  double get fullThreshold => _fullThreshold;
  String get apiEndpoint => _apiEndpoint;

  TankProvider(this._tankService, this._apiService) {
    _loadTanks();
    _initializeMockData();
    fetchTanks();
  }

  void _loadTanks() {
    _tanks = List.from(_tankService.getTanks());
    notifyListeners();
  }


  void _initializeMockData() {
    _users = [
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

    // Section 20: NORMAL & LOW generate NO alert. Only CRITICAL, FULL, OFFLINE generate alerts.
    _alerts = [];

    _notifications = [
      AppNotification(
        id: 'NTF-001',
        title: 'Campus Telemetry Pipeline Online',
        body: 'ESP32 sensor nodes connected to AWS IoT Core.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
    ];

    _events = [
      TankEvent(
        id: 'EVT-1001',
        tankId: 'tank_001',
        tankName: 'IT Building Underground Tank',
        building: 'IT Building',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        eventType: TankEventType.connectivity,
        previousState: 'OFFLINE',
        newState: 'ONLINE',
        details: 'ESP32 IoT sensor established telemetry connection.',
      ),
      TankEvent(
        id: 'EVT-1002',
        tankId: 'tank_001',
        tankName: 'IT Building Underground Tank',
        building: 'IT Building',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        eventType: TankEventType.stateTransition,
        previousState: 'LOW',
        newState: 'NORMAL',
        details: 'Water replenishment completed. Operating level (41%).',
      ),
    ];
  }

  void addTankForTesting(Tank tank) {
    _tanks.removeWhere((t) => t.deviceId == tank.deviceId || t.tankId == tank.tankId);
    _tanks.add(tank);
    notifyListeners();
  }

  // Load / Refresh Tanks from AWS Backend API
  Future<void> fetchTanks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    print('Refreshing tanks from backend...');
    try {
      final models = await _apiService.getAllTanks();
      print('GET /tanks response: SUCCESS, items: ${models.length}');
      
      // Update centralized tankService with details
      for (var model in models) {
        final existingTanks = _tankService.getTanks();
        final idx = existingTanks.indexWhere((t) => t.deviceId == model.deviceId);
        if (idx != -1) {
          final existing = existingTanks[idx];
          final updated = existing.copyWith(
            tankCapacity: model.tankCapacity > 0 ? model.tankCapacity : existing.tankCapacity,
            tankHeight: model.tankHeight > 0 ? model.tankHeight : existing.tankHeight,
            vref: model.vref,
            correctionFactor: model.correctionFactor,
            offset: model.offset,
            range: model.tankHeight > 0 ? model.tankHeight : existing.range,
          );
          _tankService.updateTank(updated);
        } else {
          _tankService.addTank(Tank.fromModel(model));
        }
      }

      _tanks = List.from(_tankService.getTanks());
      _errorMessage = null;

      // Fetch latest telemetry for each tank
      await fetchAllLatestTelemetry();
      
      // Start auto-refresh polling timer
      startAutoRefresh();
    } catch (e, stackTrace) {
      print('API Warning: Failed to fetch tanks: $e');
      print('Stack Trace: $stackTrace');
      
      final hasInternet = await checkInternet();
      if (!hasInternet) {
        _errorMessage = 'No Internet Connection';
      } else {
        _errorMessage = null; // Silently fallback to offline/cached models
        try {
          _tanks = List.from(_tankService.getTanks());
        } catch (fallbackError) {
          print('Fallback error loading offline tanks: $fallbackError');
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static const int _maxHistoryCacheEntries = 5;

  void _putInHistoryCache(String key, List<TankHistory> items, HistoryDataResult result, HistorySummary? summary) {
    if (_historyStore.containsKey(key)) {
      _historyStore.remove(key);
      _historyResultStore.remove(key);
      _historySummaryStore.remove(key);
    } else if (_historyStore.length >= _maxHistoryCacheEntries) {
      final oldestKey = _historyStore.keys.first;
      _historyStore.remove(oldestKey);
      _historyResultStore.remove(oldestKey);
      _historySummaryStore.remove(oldestKey);
    }
    _historyStore[key] = items;
    _historyResultStore[key] = result;
    if (summary != null) {
      _historySummaryStore[key] = summary;
    }
  }

  int get historyCacheCount => _historyStore.length;

  void clearHistoryCache() {
    _historyStore.clear();
    _historyResultStore.clear();
    _historySummaryStore.clear();
    _history = [];
    _historySummary = null;
    _historyResult = null;
  }

  final Map<String, int> _offlineFailureCount = {};

  bool _isTelemetryInFlight = false;

  // Fetch telemetry for all active devices concurrently
  Future<void> fetchAllLatestTelemetry() async {
    if (_isTelemetryInFlight) return;
    _isTelemetryInFlight = true;
    try {
      final futures = <Future<void>>[];
      for (int i = 0; i < _tanks.length; i++) {
        final index = i;
        final tank = _tanks[index];
        futures.add(() async {
          final oldStatus = tank.status;
          try {
            final telemetry = await _apiService.getLatestTankData(tank.deviceId);
            _offlineFailureCount[tank.deviceId] = 0;

            _tanks[index] = tank.copyWithTelemetry(
              telemetry,
              timeoutSeconds: _offlineTimeoutSeconds,
              staleTimeoutSeconds: _staleTimeoutSeconds,
            );
            
            final now = DateTime.now();
            final clockSecsStr = DateFormat('hh:mm:ss a').format(now);
            final logLine = '[$clockSecsStr] AWS IoT -> App - { '
                '"Device_id": "${_tanks[index].deviceId}", '
                '"timestamp": ${telemetry.timestamp}, '
                '"rawADC": ${_tanks[index].rawADC} }';
            _telemetryLogs.insert(0, logLine);
            if (_telemetryLogs.length > 30) {
              _telemetryLogs.removeLast();
            }

            _evaluateAlertForTank(_tanks[index], _tanks[index].currentLevelPercent, _tanks[index].status, oldStatus: oldStatus);
          } catch (e) {
            print('API Error: Failed to fetch telemetry for ${tank.deviceId}: $e');
            final fails = (_offlineFailureCount[tank.deviceId] ?? 0) + 1;
            _offlineFailureCount[tank.deviceId] = fails;

            // When ESP32 stops or telemetry fails for >= 2 polling cycles
            if (fails >= 2 && tank.status != 'OFFLINE') {
              _tanks[index] = tank.copyWith(status: 'OFFLINE');
              _evaluateAlertForTank(_tanks[index], _tanks[index].currentLevelPercent, 'OFFLINE', oldStatus: oldStatus);
            }
          }
        }());
      }
      await Future.wait(futures);
      _lastSyncTime = DateTime.now();
    } finally {
      _isTelemetryInFlight = false;
    }
  }

  // Check and update offline/stale status across all monitored tanks based on cloud lastSeen
  void checkAllTanksOfflineStatus() {
    bool changed = false;
    for (int i = 0; i < _tanks.length; i++) {
      final oldStatus = _tanks[i].status;
      final updated = _tanks[i].checkOfflineStatus(
        timeoutSeconds: _offlineTimeoutSeconds,
        staleTimeoutSeconds: _staleTimeoutSeconds,
      );
      if (updated.status != oldStatus) {
        _tanks[i] = updated;
        _evaluateAlertForTank(_tanks[i], _tanks[i].currentLevelPercent, updated.status, oldStatus: oldStatus);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  // Start periodic polling aligned with hardware cadence (default 20 seconds)
  void startAutoRefresh({Duration interval = const Duration(seconds: 20)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (timer) async {
      try {
        await fetchAllLatestTelemetry();
        checkAllTanksOfflineStatus();
        _errorMessage = null;
        notifyListeners();
      } catch (e) {
        print('API Error: Auto-refresh failed: $e');
        checkAllTanksOfflineStatus();
      }
    });
  }

  // Stop periodic polling
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  int _historyRequestId = 0;
  String? _activeHistoryDeviceId;
  String? get activeHistoryDeviceId => _activeHistoryDeviceId;

  // Fetch History for Reports Screen and Analytics Graph with bounded LRU caching
  Future<void> fetchHistory(
    String deviceOrTankId, {
    String range = '24h',
    int? start,
    int? end,
    String? interval,
    bool forceRefresh = false,
  }) async {
    final tankIdx = _tanks.indexWhere((t) => t.deviceId == deviceOrTankId || t.tankId == deviceOrTankId);
    final actualDeviceId = tankIdx != -1 ? _tanks[tankIdx].deviceId : deviceOrTankId;
    final cacheKey = range == 'custom'
        ? '$actualDeviceId:custom:$start:$end:$interval'
        : '$actualDeviceId:$range';
    final bool deviceChanged = _activeHistoryDeviceId != actualDeviceId;
    _activeHistoryDeviceId = actualDeviceId;
    _activeHistoryRange = range;
    final int requestId = ++_historyRequestId;

    if (!forceRefresh && _historyStore.containsKey(cacheKey)) {
      final items = _historyStore.remove(cacheKey)!;
      final summary = _historySummaryStore.remove(cacheKey);
      final result = _historyResultStore.remove(cacheKey);
      _historyStore[cacheKey] = items;
      if (result != null) _historyResultStore[cacheKey] = result;
      if (summary != null) _historySummaryStore[cacheKey] = summary;

      _history = items;
      _historySummary = summary;
      _historyResult = result;
      _historyError = null;
      _isHistoryLoading = false;
      notifyListeners();
      return;
    }

    _isHistoryLoading = true;
    _historyError = null;
    if (deviceChanged) {
      _history = [];
      _historySummary = null;
      _historyResult = null;
    }
    notifyListeners();
    try {
      final result = await _apiService.getTankHistory(
        actualDeviceId,
        range: range,
        start: start,
        end: end,
        interval: interval,
      );

      // Section 23: Stale request protection
      if (requestId != _historyRequestId || _activeHistoryDeviceId != actualDeviceId) {
        print('Discarding stale history response for $actualDeviceId ($range) - newer request active');
        return;
      }

      final items = result.data;
      items.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _putInHistoryCache(cacheKey, items, result, result.summary);

      _history = items;
      _historyResult = result;
      _historySummary = result.summary;
      _historyError = null;
    } catch (e) {
      if (requestId != _historyRequestId) return;
      print('API Error: Failed to fetch history for $actualDeviceId (range: $range): $e');
      _historyError = e.toString();
      _history = [];
      _historySummary = null;
      _historyResult = null;
    } finally {
      if (requestId == _historyRequestId) {
        _isHistoryLoading = false;
        notifyListeners();
      }
    }
  }

  List<TankHistory> getHistoricalReadingsForRange(
    String deviceOrTankId,
    String range, {
    int? start,
    int? end,
    String? interval,
  }) {
    final tankIdx = _tanks.indexWhere((t) => t.deviceId == deviceOrTankId || t.tankId == deviceOrTankId);
    final actualDeviceId = tankIdx != -1 ? _tanks[tankIdx].deviceId : deviceOrTankId;
    final cacheKey = range == 'custom'
        ? '$actualDeviceId:custom:$start:$end:$interval'
        : '$actualDeviceId:$range';
    if (_historyStore.containsKey(cacheKey)) {
      return _historyStore[cacheKey]!;
    }
    if (_activeHistoryRange == range && _activeHistoryDeviceId == actualDeviceId) {
      return _history;
    }
    return const [];
  }

  /// Dedicated fetch helper for export modal to query authoritative history for any range
  Future<List<TankHistory>> fetchHistoryForExport(
    String deviceOrTankId, {
    required String range,
    int? start,
    int? end,
    String? interval,
  }) async {
    final tankIdx = _tanks.indexWhere((t) => t.deviceId == deviceOrTankId || t.tankId == deviceOrTankId);
    final actualDeviceId = tankIdx != -1 ? _tanks[tankIdx].deviceId : deviceOrTankId;
    final cacheKey = range == 'custom'
        ? '$actualDeviceId:custom:$start:$end:$interval'
        : '$actualDeviceId:$range';

    if (_historyStore.containsKey(cacheKey)) {
      return _historyStore[cacheKey]!;
    }

    try {
      final result = await _apiService.getTankHistory(
        actualDeviceId,
        range: range,
        start: start,
        end: end,
        interval: interval,
      );
      final items = result.data;
      items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _historyStore[cacheKey] = items;
      return items;
    } catch (e) {
      print('API Error in fetchHistoryForExport: $e');
      return const [];
    }
  }

  HistorySummary? getHistorySummaryForRange(String deviceOrTankId, String range) {
    final tankIdx = _tanks.indexWhere((t) => t.deviceId == deviceOrTankId || t.tankId == deviceOrTankId);
    final actualDeviceId = tankIdx != -1 ? _tanks[tankIdx].deviceId : deviceOrTankId;
    final cacheKey = '$actualDeviceId:$range';
    if (_historySummaryStore.containsKey(cacheKey)) {
      return _historySummaryStore[cacheKey];
    }
    if (_activeHistoryRange == range) {
      return _historySummary;
    }
    return null;
  }

  HistoryDataResult? getHistoryResultForRange(String deviceOrTankId, String range) {
    final tankIdx = _tanks.indexWhere((t) => t.deviceId == deviceOrTankId || t.tankId == deviceOrTankId);
    final actualDeviceId = tankIdx != -1 ? _tanks[tankIdx].deviceId : deviceOrTankId;
    final cacheKey = '$actualDeviceId:$range';
    if (_historyResultStore.containsKey(cacheKey)) {
      return _historyResultStore[cacheKey];
    }
    if (_activeHistoryRange == range) {
      return _historyResult;
    }
    return null;
  }

  // Fetch Config for Calibration
  Future<void> fetchConfig(String deviceId) async {
    _isConfigLoading = true;
    _configError = null;
    notifyListeners();
    try {
      final config = await _apiService.getTankConfig(deviceId);
      final idx = _tanks.indexWhere((t) => t.deviceId == deviceId);
      if (idx != -1) {
        _tanks[idx] = _tanks[idx].copyWithConfig(config);
      }
      _configError = null;
    } catch (e) {
      print('API Error: Failed to fetch config for $deviceId: $e');
    } finally {
      _isConfigLoading = false;
      notifyListeners();
    }
  }

  // Fetch Latest Telemetry for a single tank
  Future<void> fetchLatestTelemetry(String deviceId) async {
    _isTelemetryLoading = true;
    _telemetryError = null;
    notifyListeners();
    try {
      final telemetry = await _apiService.getLatestTankData(deviceId);
      final idx = _tanks.indexWhere((t) => t.deviceId == deviceId || t.tankId == deviceId);
      if (idx != -1) {
        _tanks[idx] = _tanks[idx].copyWithTelemetry(telemetry, timeoutSeconds: _offlineTimeoutSeconds);

        _evaluateAlertForTank(_tanks[idx], _tanks[idx].currentLevelPercent, _tanks[idx].status);
      }
      _telemetryError = null;
    } catch (e) {
      print('API Error: Failed to fetch telemetry for $deviceId: $e');
    } finally {
      _isTelemetryLoading = false;
      notifyListeners();
    }
  }

  // Add Tank configuration
  Future<void> addTank(Tank tank) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final config = TankConfig(
        deviceId: tank.deviceId,
        tankCapacity: tank.tankCapacity,
        tankHeight: tank.tankHeight,
        tankShape: 'rectangular',
        vref: tank.vref,
        correctionFactor: tank.correctionFactor,
        offset: tank.offset,
      );
      await _apiService.createTank(config);
      _tankService.addTank(tank);
      _loadTanks();
    } catch (e) {
      print('API Error: Failed to create tank: $e');
      _tankService.addTank(tank);
      _loadTanks();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update Tank Calibration Configuration via PUT API
  Future<void> updateTank(Tank updatedTank) async {
    _isLoading = true;
    notifyListeners();
    try {
      final config = TankConfig(
        deviceId: updatedTank.deviceId,
        tankCapacity: updatedTank.tankCapacity,
        tankHeight: updatedTank.tankHeight,
        tankShape: 'cylindrical',
        vref: updatedTank.vref,
        correctionFactor: updatedTank.correctionFactor,
        offset: updatedTank.offset,
      );
      await _apiService.updateTankConfig(updatedTank.deviceId, config);
      _tankService.updateTank(updatedTank);

      final idx = _tanks.indexWhere((t) => t.deviceId == updatedTank.deviceId);
      if (idx != -1) {
        _tanks[idx] = updatedTank;
      }
      _errorMessage = null;
    } catch (e) {
      print('API Error: Failed to update tank configuration: $e');
      _tankService.updateTank(updatedTank);
      final idx = _tanks.indexWhere((t) => t.deviceId == updatedTank.deviceId);
      if (idx != -1) {
        _tanks[idx] = updatedTank;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete Tank configuration
  Future<void> deleteTank(String deviceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _apiService.deleteTank(deviceId);
    } catch (e) {
      print('API Warning: DELETE endpoint failed: $e');
    } finally {
      _tankService.deleteTank(deviceId);
      _loadTanks();
      _isLoading = false;
      notifyListeners();
    }
  }

  // User Management Methods
  void addUser(UserModel user) {
    _users.add(user);
    notifyListeners();
  }

  void updateUser(UserModel updatedUser) {
    final idx = _users.indexWhere((u) => u.id == updatedUser.id);
    if (idx != -1) {
      _users[idx] = updatedUser;
      notifyListeners();
    }
  }

  void toggleUserStatus(String userId) {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      _users[idx] = _users[idx].copyWith(isActive: !_users[idx].isActive);
      notifyListeners();
    }
  }

  // Calculate status based on rules
  String calculateStatus(double levelPercent, bool isOffline) {
    if (isOffline) return 'OFFLINE';
    final pct = levelPercent * 100.0;
    if (pct >= _fullThreshold) return 'FULL';
    if (pct < _criticalThreshold) return 'CRITICAL';
    if (pct < _lowThreshold) return 'LOW';
    return 'NORMAL';
  }

  // Telemetry updates simulation
  void updateTankLevelMock(String tankId, double percent, double temperature) {
    final index = _tanks.indexWhere((t) => t.tankId == tankId || t.deviceId == tankId);
    if (index != -1) {
      final tank = _tanks[index];
      
      final oldStatus = tank.status;
      final isOffline = percent <= 0.0 || tank.status == 'OFFLINE';
      final status = calculateStatus(percent, isOffline);

      final now = DateTime.now();
      final timeStr = DateFormat('hh:mm:ss a').format(now);

      final batteryVal = percent <= 0.0 ? 0.00 : double.parse((3.2 + Random().nextDouble() * 0.2).toStringAsFixed(2));
      final rssiVal = percent <= 0.0 ? -99 : (-55 - Random().nextInt(10));
      final depthVal = percent <= 0.0 ? 0.0 : double.parse((percent * (tank.tankHeight / 1000.0)).toStringAsFixed(2));
      final rawAdcVal = percent <= 0.0 ? 0 : (percent * 4095).round();

      final updatedTank = tank.copyWith(
        currentLevelPercent: percent,
        temperature: percent <= 0.0 ? 0.0 : temperature,
        status: status,
        lastUpdated: timeStr,
        depth: depthVal,
        battery: batteryVal,
        rssi: rssiVal,
        rawADC: rawAdcVal,
        updatedAt: now.toIso8601String(),
      );

      _tanks[index] = updatedTank;
      _tankService.updateTank(updatedTank);

      _evaluateAlertForTank(updatedTank, percent, status, oldStatus: oldStatus);
      notifyListeners();
    }
  }

  // Update tank details using processed telemetry from cloud
  void updateTankFromTelemetryJson(Map<String, dynamic> json) {
    final deviceId = json['Device_id']?.toString() ?? json['deviceId']?.toString() ?? '';
    if (deviceId.isEmpty) return;

    final index = _tanks.indexWhere((t) => t.deviceId == deviceId || t.tankId == deviceId);
    if (index != -1) {
      final tank = _tanks[index];
      final oldStatus = tank.status;

      final double rawAdcVal = (json['rawADC'] as num? ?? tank.rawADC).toDouble();
      final double levelPercent = (json['currentLevelPercent'] ?? json['levelPercent'] ?? tank.currentLevelPercent as num? ?? 0.41).toDouble();
      final double tempVal = (json['temperature'] as num? ?? tank.temperature).toDouble();
      final double depthVal = (json['depth'] as num? ?? tank.depth).toDouble();
      final double batteryVal = (json['battery'] as num? ?? tank.battery).toDouble();
      final int rssiVal = json['rssi'] as int? ?? tank.rssi;
      final String statusVal = json['status']?.toString().toUpperCase() ?? calculateStatus(levelPercent, false);

      final now = DateTime.now();
      final timeStr = DateFormat('hh:mm:ss a').format(now);

      final updatedTank = tank.copyWith(
        rawADC: rawAdcVal.round(),
        currentLevelPercent: levelPercent,
        temperature: tempVal,
        depth: depthVal,
        battery: batteryVal,
        rssi: rssiVal,
        status: statusVal,
        lastUpdated: timeStr,
        updatedAt: now.toIso8601String(),
      );

      _tanks[index] = updatedTank;
      _tankService.updateTank(updatedTank);

      _evaluateAlertForTank(updatedTank, levelPercent, statusVal, oldStatus: oldStatus);
      notifyListeners();
    }
  }

  void clearTelemetryLogs() {
    _telemetryLogs.clear();
    notifyListeners();
  }

  // Strict Alert Rules (Section 20-24, 46, 91, 92, 93)
  void _evaluateAlertForTank(Tank tank, double percent, String status, {String? oldStatus}) {
    final normStatus = status.toUpperCase();
    final pct100 = percent * 100.0;

    if (normStatus == 'CRITICAL') {
      final alertExists = _alerts.any((a) => a.tankId == tank.tankId && !a.isResolved && a.severity == 'critical');
      if (!alertExists) {
        final alertId = 'ALT-${Random().nextInt(1000) + 200}';
        final newAlert = Alert(
          id: alertId,
          tankId: tank.tankId,
          tankName: tank.tankName,
          title: 'CRITICAL WATER LEVEL',
          message: '${tank.tankName} (${tank.building}) fell to ${pct100.toStringAsFixed(1)}%. Immediate operator action required.',
          severity: 'critical',
          timestamp: DateTime.now(),
        );
        _alerts.insert(0, newAlert);

        _notifications.insert(0, AppNotification(
          id: 'NTF-${Random().nextInt(1000) + 200}',
          title: newAlert.title,
          body: newAlert.message,
          timestamp: DateTime.now(),
        ));

        _recordEvent(TankEvent(
          id: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
          tankId: tank.tankId,
          tankName: tank.tankName,
          building: tank.building,
          timestamp: DateTime.now(),
          eventType: TankEventType.alertTrigger,
          previousState: oldStatus ?? 'NORMAL',
          newState: 'CRITICAL',
          details: 'Water level fell below critical threshold to ${pct100.toStringAsFixed(1)}%.',
        ));
      }
    } else if (normStatus == 'FULL') {
      final alertExists = _alerts.any((a) => a.tankId == tank.tankId && !a.isResolved && a.severity == 'full');
      if (!alertExists) {
        final alertId = 'ALT-${Random().nextInt(1000) + 200}';
        final newAlert = Alert(
          id: alertId,
          tankId: tank.tankId,
          tankName: tank.tankName,
          title: 'FULL WATER LEVEL — OVERFLOW RISK',
          message: '${tank.tankName} (${tank.building}) reached ${pct100.toStringAsFixed(1)}% capacity. Risk of overflow.',
          severity: 'full',
          timestamp: DateTime.now(),
        );
        _alerts.insert(0, newAlert);

        _notifications.insert(0, AppNotification(
          id: 'NTF-${Random().nextInt(1000) + 200}',
          title: newAlert.title,
          body: newAlert.message,
          timestamp: DateTime.now(),
        ));

        _recordEvent(TankEvent(
          id: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
          tankId: tank.tankId,
          tankName: tank.tankName,
          building: tank.building,
          timestamp: DateTime.now(),
          eventType: TankEventType.alertTrigger,
          previousState: oldStatus ?? 'NORMAL',
          newState: 'FULL',
          details: 'Water level reached ${pct100.toStringAsFixed(1)}% (>= 90%). Overflow risk alert activated.',
        ));
      }
    } else if (normStatus == 'OFFLINE') {
      final alertExists = _alerts.any((a) => a.tankId == tank.tankId && !a.isResolved && a.severity == 'offline');
      if (!alertExists) {
        final alertId = 'ALT-${Random().nextInt(1000) + 200}';
        final newAlert = Alert(
          id: alertId,
          tankId: tank.tankId,
          tankName: tank.tankName,
          title: 'DEVICE OFFLINE',
          message: 'ESP32 sensor node ${tank.deviceId} in ${tank.building} lost connection.',
          severity: 'offline',
          timestamp: DateTime.now(),
        );
        _alerts.insert(0, newAlert);

        _notifications.insert(0, AppNotification(
          id: 'NTF-${Random().nextInt(1000) + 200}',
          title: newAlert.title,
          body: newAlert.message,
          timestamp: DateTime.now(),
        ));

        _recordEvent(TankEvent(
          id: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
          tankId: tank.tankId,
          tankName: tank.tankName,
          building: tank.building,
          timestamp: DateTime.now(),
          eventType: TankEventType.connectivity,
          previousState: oldStatus ?? 'ONLINE',
          newState: 'OFFLINE',
          details: 'Telemetry timeout exceeded. Node marked offline.',
        ));
      }
    } else {
      // NORMAL or LOW state: LOW does NOT generate an alert (Section 21).
      // Recovery handling (Sections 49 & 93):
      final unresolved = _alerts.where((a) => a.tankId == tank.tankId && !a.isResolved).toList();
      if (unresolved.isNotEmpty) {
        for (var a in unresolved) {
          final idx = _alerts.indexOf(a);
          if (idx != -1) {
            _alerts[idx] = a.copyWith(isResolved: true, resolvedAt: DateTime.now());
          }
        }
        _recordEvent(TankEvent(
          id: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
          tankId: tank.tankId,
          tankName: tank.tankName,
          building: tank.building,
          timestamp: DateTime.now(),
          eventType: TankEventType.alertRecovery,
          previousState: oldStatus ?? 'ALERT',
          newState: normStatus,
          details: 'Tank recovered from active alert condition to $normStatus operational state.',
        ));
      } else if (oldStatus != null && oldStatus != normStatus) {
        // Normal transition without alert (e.g. NORMAL -> LOW or LOW -> NORMAL)
        _recordEvent(TankEvent(
          id: 'EVT-${DateTime.now().millisecondsSinceEpoch}',
          tankId: tank.tankId,
          tankName: tank.tankName,
          building: tank.building,
          timestamp: DateTime.now(),
          eventType: TankEventType.stateTransition,
          previousState: oldStatus,
          newState: normStatus,
          details: 'Water level changed to ${pct100.toStringAsFixed(1)}% ($normStatus).',
        ));
      }
    }
  }

  void _recordEvent(TankEvent event) {
    _events.insert(0, event);
    if (_events.length > 200) {
      _events.removeLast();
    }
  }

  // Resolve / Acknowledge specific Alert
  Future<void> resolveAlert(String alertId) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(
        isResolved: true,
        resolvedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // Clear resolved alerts
  Future<void> clearAllAlerts() async {
    _alerts.removeWhere((a) => a.isResolved);
    notifyListeners();
  }

  // Mark specific notification read
  void markNotificationAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  // Mark all notifications read
  void markAllNotificationsAsRead() {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  // Update settings / thresholds configurations
  void updateSettings(double low, double high, String endpoint) {
    _lowThreshold = low;
    _fullThreshold = high;
    _apiEndpoint = endpoint;

    for (var tank in _tanks) {
      updateTankLevelMock(tank.tankId, tank.currentLevelPercent, tank.temperature);
    }
    notifyListeners();
  }

  // Readings returned strictly from recorded historical data
  List<TankHistory> getReadingsForTimeframe(String tankId, String timeframe) {
    final tankIdx = _tanks.indexWhere((t) => t.tankId == tankId || t.deviceId == tankId);
    final actualDeviceId = tankIdx != -1 ? _tanks[tankIdx].deviceId : tankId;
    return _historyStore['$actualDeviceId:$timeframe'] ?? _historyStore[actualDeviceId] ?? _history;
  }

  // Real Historical Data for Charts (Section 36 & 41: Real data only, no fake lines)
  List<double> getHistoricalLevelData(String tankId, [dynamic timeframeOrCount = '24 Hours']) {
    String tf = '24 Hours';
    if (timeframeOrCount is String) {
      tf = timeframeOrCount;
    } else if (timeframeOrCount is int) {
      if (timeframeOrCount <= 6) {
        tf = '1 Hour';
      } else if (timeframeOrCount <= 8) {
        tf = '6 Hours';
      } else if (timeframeOrCount <= 12) {
        tf = '24 Hours';
      } else {
        tf = '7 Days';
      }
    }
    final readings = getReadingsForTimeframe(tankId, tf);
    return readings.map((r) => r.waterPercent / 100.0).toList().reversed.toList();
  }

  // Real Stored Readings for a tank
  List<TankHistory> getTankReadings(String tankId) {
    return getReadingsForTimeframe(tankId, '24 Hours');
  }

  // Real Stored Readings with timeframe cutoff in hours
  List<TankHistory> getHistoricalReadings(String tankId, int hours) {
    String tf = '24 Hours';
    if (hours <= 1) {
      tf = '1 Hour';
    } else if (hours <= 6) {
      tf = '6 Hours';
    } else if (hours <= 24) {
      tf = '24 Hours';
    } else {
      tf = '7 Days';
    }
    return getReadingsForTimeframe(tankId, tf);
  }

  // Set historical readings in memory for testing
  void setMockHistoryForTest(String key, List<TankHistory> readings) {
    _historyStore[key] = readings;
  }

  // Authoritative water used calculated from chronological historical volume decreases
  double calculateAuthoritativeWaterUsed(String deviceOrTankId, {String range = '24h', double deadbandThresholdPercent = 0.2}) {
    final readings = getHistoricalReadingsForRange(deviceOrTankId, range);
    if (readings.length < 2) return 0.0;
    
    final tankIdx = _tanks.indexWhere((t) => t.deviceId == deviceOrTankId || t.tankId == deviceOrTankId);
    final capacity = tankIdx != -1 && _tanks[tankIdx].tankCapacity > 0 ? _tanks[tankIdx].tankCapacity : 280000.0;

    // Use unified GraphMetricDefinition bucket calculation for exact graph parity
    final buckets = GraphMetricDefinition.calculateUsageBuckets(
      readings: readings,
      tankCapacity: capacity,
      rangeKey: range,
    );
    if (buckets.isNotEmpty) {
      return buckets.fold<double>(0.0, (sum, b) => sum + b.litersUsed);
    }

    final thresholdLitres = capacity * (deadbandThresholdPercent / 100.0);
    final sorted = List<TankHistory>.from(readings)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalUsed = 0.0;
    for (int i = 1; i < sorted.length; i++) {
      final prevVol = sorted[i - 1].waterAvailableLiters ?? (capacity * (sorted[i - 1].waterPercent / 100.0));
      final currVol = sorted[i].waterAvailableLiters ?? (capacity * (sorted[i].waterPercent / 100.0));
      final delta = prevVol - currVol; // Volume reduction
      if (delta > thresholdLitres && delta < capacity * 0.90) {
        totalUsed += delta;
      }
    }
    return totalUsed;
  }

  // Authoritative water received calculated from chronological historical volume increases
  double calculateAuthoritativeWaterReceived(String deviceOrTankId, {String range = '24h', double deadbandThresholdPercent = 0.5}) {
    final readings = getHistoricalReadingsForRange(deviceOrTankId, range);
    if (readings.length < 2) return 0.0;

    final tankIdx = _tanks.indexWhere((t) => t.deviceId == deviceOrTankId || t.tankId == deviceOrTankId);
    final capacity = tankIdx != -1 && _tanks[tankIdx].tankCapacity > 0 ? _tanks[tankIdx].tankCapacity : 280000.0;
    final thresholdLitres = capacity * (deadbandThresholdPercent / 100.0);

    double totalReceived = 0.0;
    for (int i = 1; i < readings.length; i++) {
      final prevVol = readings[i - 1].waterAvailableLiters ?? (capacity * (readings[i - 1].waterPercent / 100.0));
      final currVol = readings[i].waterAvailableLiters ?? (capacity * (readings[i].waterPercent / 100.0));
      final delta = currVol - prevVol; // Volume replenishment
      if (delta > thresholdLitres && delta < capacity * 0.90) {
        totalReceived += delta;
      }
    }
    return totalReceived;
  }

  // Status mapping colors helper
  static Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'NORMAL':
      case 'HEALTHY':
      case 'OK':
        return const Color(0xFF16A34A); // Green
      case 'FULL':
        return const Color(0xFF2563EB); // Blue
      case 'LOW':
      case 'AVERAGE':
      case 'WARNING':
        return const Color(0xFFF97316); // Amber/Orange
      case 'CRITICAL':
        return const Color(0xFFDC2626); // Red
      case 'OFFLINE':
      default:
        return const Color(0xFF9CA3AF); // Grey
    }
  }

  static Color getStatusLightColor(String status) {
    switch (status.toUpperCase()) {
      case 'NORMAL':
      case 'HEALTHY':
      case 'OK':
        return const Color(0xFFDCFCE7);
      case 'FULL':
        return const Color(0xFFDBEAFE);
      case 'LOW':
      case 'AVERAGE':
      case 'WARNING':
        return const Color(0xFFFFEDD5);
      case 'CRITICAL':
        return const Color(0xFFFEE2E2);
      case 'OFFLINE':
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
