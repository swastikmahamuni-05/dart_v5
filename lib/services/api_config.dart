class ApiConfig {
  static const String environment = 'production';
  static const String region = 'ap-south-1';
  static const String baseUrl =
      'https://cudwq7s6w0.execute-api.ap-south-1.amazonaws.com/prod';

  // Network reliability timeouts & retries
  static const Duration requestTimeout = Duration(seconds: 15);
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(milliseconds: 500);

  // Freshness thresholds (seconds)
  static const int defaultOnlineThresholdSeconds = 90;
  static const int defaultStaleThresholdSeconds = 900; // 15 minutes
}

