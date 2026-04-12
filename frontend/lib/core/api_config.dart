import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend base URL (no trailing slash). Override with --dart-define=API_BASE=http://...
class ApiConfig {
  ApiConfig._();

  static const String _defineBase = String.fromEnvironment('API_BASE', defaultValue: '');

  static String get baseUrl {
    if (_defineBase.isNotEmpty) return _defineBase.replaceAll(RegExp(r'/$'), '');
    if (kIsWeb) return 'http://localhost:5000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    } catch (_) {
      // Platform not available in some test contexts
    }
    return 'http://localhost:5000';
  }
}
