import 'dart:io';

import 'package:flutter/foundation.dart';

/// Central API configuration for Android, iOS, and web.
///
/// Physical device (same Wi-Fi as laptop):
///   flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000
///
/// Android emulator:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///
/// iOS simulator:
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000
class AppConfig {
  static const String _fromEnv = String.fromEnvironment('API_BASE_URL');

  /// Default LAN IP when no dart-define is passed (physical phone on Wi-Fi).
  static const String _defaultLanHost =
      String.fromEnvironment('API_LAN_HOST', defaultValue: 'moizpirzada1-oral-vision-backend.hf.space');

  static String get apiBaseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isIOS) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://$_defaultLanHost:8000';
    return 'http://localhost:8000';
  }
}
