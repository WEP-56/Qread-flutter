class AppConstants {
  static const String appName = 'Qread';
  static const String appVersion = '3.4.6';

  // API
  static const String apiVersion = '5';
  static String baseUrl = 'http://localhost:8080';
  static String get apiBase => '$baseUrl/api/$apiVersion';

  // 存储
  static const String keyToken = 'access_token';
  static const String keyBaseUrl = 'base_url';
  static const String keyThemeMode = 'theme_mode';

  // 分页
  static const int pageSize = 20;
}
