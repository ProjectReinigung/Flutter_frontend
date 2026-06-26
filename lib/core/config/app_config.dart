class AppConfig {
  static const developmentBackendUrl = 'http://localhost:8081';
  static const developmentKeycloakUrl = 'http://localhost:8082';
  static const developmentRedirectUrl = 'http://localhost:8080/';

  static const productionBackendUrl = 'https://api.karakheti.de';
  static const productionKeycloakUrl = 'https://auth.karakheti.de';
  static const productionRedirectUrl =
      'https://projectreinigung.github.io/Flutter_frontend/';

  static const defaultRealm = 'cleaning-system';
  static const developmentClientId = 'cleaning-system-local';
  static const productionClientId = 'cleaning-system-frontend';

  static const _environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const _backendUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _keycloakUrlOverride = String.fromEnvironment('KEYCLOAK_URL');
  static const _realmOverride = String.fromEnvironment('KEYCLOAK_REALM');
  static const _clientIdOverride = String.fromEnvironment('KEYCLOAK_CLIENT_ID');
  static const _redirectUrlOverride = String.fromEnvironment('REDIRECT_URL');

  static bool get isProduction => _environment == 'production';

  static String get defaultBackendUrl => _url(
    _backendUrlOverride.isNotEmpty
        ? _backendUrlOverride
        : isProduction
        ? productionBackendUrl
        : developmentBackendUrl,
  );

  static String get defaultKeycloakUrl => _url(
    _keycloakUrlOverride.isNotEmpty
        ? _keycloakUrlOverride
        : isProduction
        ? productionKeycloakUrl
        : developmentKeycloakUrl,
  );

  static String get keycloakRealm =>
      _realmOverride.isNotEmpty ? _realmOverride : defaultRealm;

  static String get keycloakClientId => _clientIdOverride.isNotEmpty
      ? _clientIdOverride
      : isProduction
      ? productionClientId
      : developmentClientId;

  static String get redirectUrl => _redirectUrlOverride.isNotEmpty
      ? _redirectUrlOverride
      : isProduction
      ? productionRedirectUrl
      : developmentRedirectUrl;

  static String _url(String value) => value.replaceAll(RegExp(r'/$'), '');
}
