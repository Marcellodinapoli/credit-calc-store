import 'package:flutter/foundation.dart';

/// Config Connettore Credixa (pratiche in affido per consulenti esterni).
abstract final class GestionaleConnectorConfig {
  /// Override completo: `--dart-define=CREDIXA_CONNECTOR_URL=http://192.168.1.5:8443`
  static const String _urlOverride = String.fromEnvironment(
    'CREDIXA_CONNECTOR_URL',
    defaultValue: '',
  );

  /// IP del PC in LAN (device fisico Android). Emulatore: usa 10.0.2.2 via override.
  static const String _devLanHost = String.fromEnvironment(
    'CREDIXA_DEV_HOST',
    defaultValue: '192.168.1.5',
  );

  static const String defaultTenantSlug = String.fromEnvironment(
    'CREDIXA_TENANT_SLUG',
    defaultValue: 'demo',
  );

  static const String apiKey = String.fromEnvironment(
    'CREDIXA_CONNECTOR_API_KEY',
    defaultValue: '',
  );

  /// Su telefono/tablet Android `127.0.0.1` è il device, non il PC.
  static String get baseUrl {
    if (_urlOverride.isNotEmpty) return _urlOverride;
    if (kIsWeb) return 'http://127.0.0.1:8443';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://$_devLanHost:8443';
      case TargetPlatform.iOS:
        // Simulatore → localhost; device fisico → stesso host LAN del PC.
        return kDebugMode
            ? 'http://$_devLanHost:8443'
            : 'http://127.0.0.1:8443';
      default:
        return 'http://127.0.0.1:8443';
    }
  }

  static String creditCalcPath(String tenantSlug, String suffix) {
    final slug =
        tenantSlug.trim().isEmpty ? defaultTenantSlug : tenantSlug.trim();
    final path = suffix.startsWith('/') ? suffix : '/$suffix';
    return '$baseUrl/api/v1/tenants/$slug/creditcalc$path';
  }
}
