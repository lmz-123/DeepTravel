enum AppMode { demo, api }

abstract final class AppConfig {
  static const modeValue = String.fromEnvironment(
    'APP_MODE',
    defaultValue: 'api',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5001/api/v1',
  );
  static const defaultCitySlug = String.fromEnvironment(
    'DEFAULT_CITY_SLUG',
    defaultValue: 'shenzhen',
  );
  static const runtimeLogEndpoint = String.fromEnvironment(
    'RUNTIME_LOG_ENDPOINT',
    defaultValue: 'http://115.29.221.190:5100/api/runtime/client-logs',
  );
  static const runtimeLogToken = String.fromEnvironment(
    'RUNTIME_LOG_TOKEN',
    defaultValue: 'DeepTravelClientLogs2026',
  );
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0+1',
  );

  static AppMode get mode => modeValue == 'api' ? AppMode.api : AppMode.demo;
}
