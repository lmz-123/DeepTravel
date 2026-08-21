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
  static const enableDemoTriggers = bool.fromEnvironment(
    'ENABLE_DEMO_TRIGGERS',
    defaultValue: true,
  );

  static AppMode get mode => modeValue == 'api' ? AppMode.api : AppMode.demo;
}
