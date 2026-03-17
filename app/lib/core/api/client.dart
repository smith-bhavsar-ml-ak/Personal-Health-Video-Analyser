import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import '../storage/secure_storage.dart';

const _defaultMobileBase = 'http://localhost';

// Allow overriding the API base URL at build time:
// flutter run -d chrome --dart-define=API_BASE=http://192.168.1.10:8000/api/v1
const _devApiBase = String.fromEnvironment('API_BASE', defaultValue: '');

/// Dio HTTP client singleton.
/// - Web (prod): uses relative URL /api/v1 (served from same Nginx origin)
/// - Web (dev): use --dart-define=API_BASE=http://localhost:8000/api/v1
/// - Mobile: uses server URL from secure storage (user-configurable in Settings)
class ApiClient {
  late final Dio dio;

  ApiClient._();
  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  Future<void> init() async {
    String baseUrl;
    if (_devApiBase.isNotEmpty) {
      baseUrl = _devApiBase;
    } else if (kIsWeb && kDebugMode) {
      // Dev: Flutter server (port 3000) ≠ backend (port 8000) — use absolute URL
      baseUrl = 'http://localhost:8000/api/v1';
    } else if (kIsWeb) {
      // Prod: same origin, nginx proxies /api/v1 → backend
      baseUrl = '/api/v1';
    } else {
      final stored = await SecureStorage.instance.readServerUrl();
      baseUrl = '${stored ?? _defaultMobileBase}/api/v1';
    }

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120), // video analysis can be slow
      headers: {'Content-Type': 'application/json'},
    ));

    // Auth token interceptor
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.instance.readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  /// Call after user changes server URL in Settings.
  Future<void> updateBaseUrl(String serverUrl) async {
    await SecureStorage.instance.writeServerUrl(serverUrl);
    if (!kIsWeb) {
      dio.options.baseUrl = '$serverUrl/api/v1';
    }
  }
}
