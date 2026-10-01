enum AppEnv { dev, staging, prod }

/// Configuración inyectada en build time con `--dart-define`.
///
/// `ENV` elige el entorno (dev por defecto). `API_BASE_URL` y `OTP_BASE_URL`
/// permiten sobreescribir las URLs; por ejemplo, el emulador de Android no ve
/// el localhost del Mac y necesita `API_BASE_URL=http://10.0.2.2:8080/v1`.
class AppConfig {
  static const _envName = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _otpBaseUrlOverride = String.fromEnvironment('OTP_BASE_URL');

  static const _realOtpBaseUrl = 'https://www.quanticasoft.com/otp';

  static AppEnv get env => AppEnv.values.byName(_envName);

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return switch (env) {
      AppEnv.dev => 'http://localhost:8080/v1',
      AppEnv.staging =>
        'https://www.quanticasoft.com/hobbystore/api-staging/v1',
      AppEnv.prod => 'https://www.quanticasoft.com/hobbystore/api/v1',
    };
  }

  /// "mock" usa [MockOtpService] (código 123456) en lugar de enviar SMS.
  static String get otpBaseUrl {
    if (_otpBaseUrlOverride.isNotEmpty) return _otpBaseUrlOverride;
    return env == AppEnv.dev ? 'mock' : _realOtpBaseUrl;
  }

  static bool get useMockOtp => otpBaseUrl == 'mock';
}
