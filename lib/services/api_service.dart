import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../models/tank_model.dart';
import '../models/tank_telemetry.dart';
import '../models/tank_history.dart';
import '../models/tank_config.dart';

class ApiErrorCodes {
  static const String networkError = 'NETWORK_ERROR';
  static const String timeoutError = 'TIMEOUT_ERROR';
  static const String deviceNotFound = 'DEVICE_NOT_FOUND';
  static const String historyUnavailable = 'HISTORY_UNAVAILABLE';
  static const String serverError = 'SERVER_ERROR';
  static const String authRequired = 'AUTH_REQUIRED';
  static const String forbidden = 'FORBIDDEN';
  static const String invalidSensorData = 'INVALID_SENSOR_DATA';
}

class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final String? endpoint;

  ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.endpoint,
  });

  @override
  String toString() => 'ApiException [$code]: $message (status: ${statusCode ?? "N/A"})';
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Robust HTTP request executor with timeout, cancellation, and exponential backoff retry.
  Future<http.Response> _executeRequest(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = ApiConfig.requestTimeout,
    int maxRetries = ApiConfig.maxRetries,
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        http.Response response;
        switch (method.toUpperCase()) {
          case 'GET':
            response = await _client.get(url, headers: headers).timeout(timeout);
            break;
          case 'POST':
            response = await _client.post(url, headers: headers, body: body).timeout(timeout);
            break;
          case 'PUT':
            response = await _client.put(url, headers: headers, body: body).timeout(timeout);
            break;
          case 'DELETE':
            response = await _client.delete(url, headers: headers).timeout(timeout);
            break;
          default:
            throw ArgumentError('Unsupported HTTP method: $method');
        }

        // 5xx Server Errors are eligible for retry up to maxRetries
        if (response.statusCode >= 500 && attempt < maxRetries) {
          final delay = ApiConfig.initialRetryDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        return response;
      } on TimeoutException {
        if (attempt < maxRetries) {
          final delay = ApiConfig.initialRetryDelay * attempt;
          await Future.delayed(delay);
          continue;
        }
        throw ApiException(
          code: ApiErrorCodes.timeoutError,
          message: 'Backend request timed out after ${timeout.inSeconds} seconds.',
          endpoint: url.path,
        );
      } catch (e) {
        if (e is ApiException) rethrow;
        if (attempt < maxRetries) {
          final delay = ApiConfig.initialRetryDelay * attempt;
          await Future.delayed(delay);
          continue;
        }
        throw ApiException(
          code: ApiErrorCodes.networkError,
          message: 'Network communication failure: $e',
          endpoint: url.path,
        );
      }
    }
  }

  Future<List<TankModel>> getAllTanks() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/tanks');
    try {
      final response = await _executeRequest('GET', url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TankModel.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw ApiException(
          code: ApiErrorCodes.authRequired,
          message: 'Authentication required to access tank list.',
          statusCode: 401,
          endpoint: url.path,
        );
      } else {
        throw ApiException(
          code: ApiErrorCodes.serverError,
          message: 'Failed to load tanks: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          endpoint: url.path,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        code: ApiErrorCodes.networkError,
        message: 'Could not connect to tanks API: $e',
        endpoint: url.path,
      );
    }
  }

  Future<TankTelemetry> getLatestTankData(String deviceId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/tank/$deviceId/latest');
    try {
      final response = await _executeRequest('GET', url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return TankTelemetry.fromJson(data);
      } else if (response.statusCode == 404) {
        throw ApiException(
          code: ApiErrorCodes.deviceNotFound,
          message: 'Device $deviceId has no recorded telemetry.',
          statusCode: 404,
          endpoint: url.path,
        );
      } else {
        throw ApiException(
          code: ApiErrorCodes.serverError,
          message: 'Failed to fetch latest telemetry: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          endpoint: url.path,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        code: ApiErrorCodes.networkError,
        message: 'Failed to reach telemetry endpoint: $e',
        endpoint: url.path,
      );
    }
  }

  Future<HistoryDataResult> getTankHistory(
    String deviceId, {
    String? range,
    int? start,
    int? end,
    String? interval,
    int? limit,
  }) async {
    final baseUri = Uri.parse('${ApiConfig.baseUrl}/tank/$deviceId/history');
    final queryParams = <String, String>{};
    if (range != null && range.isNotEmpty) queryParams['range'] = range;
    if (start != null) queryParams['start'] = start.toString();
    if (end != null) queryParams['end'] = end.toString();
    if (interval != null) queryParams['interval'] = interval;
    if (limit != null) queryParams['limit'] = limit.toString();

    final url = queryParams.isNotEmpty ? baseUri.replace(queryParameters: queryParams) : baseUri;

    try {
      final response = await _executeRequest('GET', url);

      if (response.statusCode != 200) {
        throw ApiException(
          code: ApiErrorCodes.historyUnavailable,
          message: 'Failed to load history for $deviceId: HTTP ${response.statusCode} - ${response.body}',
          statusCode: response.statusCode,
          endpoint: url.path,
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      List<TankHistory> parsedPoints = [];
      HistorySummary? parsedSummary;
      String? respDeviceId = deviceId;
      String? respRange = range;
      int? respStart = start;
      int? respEnd = end;
      double? respCapacity;
      int? respBucketSec;
      int? respRawCount;
      int? respGraphCount;

      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        respDeviceId = map['deviceId']?.toString() ?? deviceId;
        respRange = map['range']?.toString() ?? range;
        respStart = (map['start'] as num?)?.toInt() ?? start;
        respEnd = (map['end'] as num?)?.toInt() ?? end;
        respCapacity = (map['tankCapacity'] as num?)?.toDouble();
        respBucketSec = (map['bucketSeconds'] as num?)?.toInt();
        respRawCount = (map['rawRecordCount'] as num?)?.toInt();
        respGraphCount = (map['graphPointCount'] as num?)?.toInt();

        if (map['summary'] is Map) {
          try {
            parsedSummary = HistorySummary.fromJson(Map<String, dynamic>.from(map['summary']));
          } catch (_) {}
        }

        final dynamic rawList = map['data'] ?? map['value'] ?? map['Items'] ?? map['items'] ?? map['history'] ?? map['readings'];

        if (rawList is List) {
          for (var item in rawList) {
            if (item is Map) {
              try {
                parsedPoints.add(TankHistory.fromJson(Map<String, dynamic>.from(item)));
              } catch (_) {}
            }
          }
        } else if (map.containsKey('waterPercent') || map.containsKey('waterLevelPercent') || map.containsKey('depth')) {
          parsedPoints = [TankHistory.fromJson(map)];
        }
      } else if (decoded is List) {
        for (var item in decoded) {
          if (item is Map) {
            try {
              parsedPoints.add(TankHistory.fromJson(Map<String, dynamic>.from(item)));
            } catch (_) {}
          }
        }
      }

      // Ensure chronological ordering ascending (OLDEST -> NEWEST)
      parsedPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return HistoryDataResult(
        deviceId: respDeviceId,
        range: respRange,
        start: respStart,
        end: respEnd,
        tankCapacity: respCapacity,
        bucketSeconds: respBucketSec,
        rawRecordCount: respRawCount,
        graphPointCount: respGraphCount ?? parsedPoints.length,
        summary: parsedSummary,
        data: parsedPoints,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        code: ApiErrorCodes.historyUnavailable,
        message: 'History query failed for $deviceId: $e',
        endpoint: url.path,
      );
    }
  }

  Future<TankConfig> getTankConfig(String deviceId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/tank/$deviceId/config');
    try {
      final response = await _executeRequest('GET', url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return TankConfig.fromJson(data);
      } else {
        throw ApiException(
          code: ApiErrorCodes.deviceNotFound,
          message: 'Failed to load configuration for $deviceId: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          endpoint: url.path,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        code: ApiErrorCodes.networkError,
        message: 'Could not fetch config: $e',
        endpoint: url.path,
      );
    }
  }

  Future<void> createTank(TankConfig config) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/tank');
    try {
      final response = await _executeRequest(
        'POST',
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        throw ApiException(
          code: ApiErrorCodes.serverError,
          message: 'Failed to create tank: HTTP ${response.statusCode} - ${response.body}',
          statusCode: response.statusCode,
          endpoint: url.path,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        code: ApiErrorCodes.networkError,
        message: 'Create tank failed: $e',
        endpoint: url.path,
      );
    }
  }

  Future<void> updateTankConfig(String deviceId, TankConfig config) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/tank/$deviceId/config');
    try {
      final response = await _executeRequest(
        'PUT',
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config.toJson()),
      );
      if (response.statusCode == 200) {
        return;
      } else {
        throw ApiException(
          code: ApiErrorCodes.serverError,
          message: 'Failed to update config for $deviceId: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          endpoint: url.path,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        code: ApiErrorCodes.networkError,
        message: 'Update tank config failed: $e',
        endpoint: url.path,
      );
    }
  }

  Future<void> deleteTank(String deviceId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/tank/$deviceId');
    try {
      final response = await _executeRequest(
        'DELETE',
        url,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else {
        throw ApiException(
          code: ApiErrorCodes.serverError,
          message: 'Failed to delete tank $deviceId: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          endpoint: url.path,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        code: ApiErrorCodes.networkError,
        message: 'Delete tank failed: $e',
        endpoint: url.path,
      );
    }
  }
}
