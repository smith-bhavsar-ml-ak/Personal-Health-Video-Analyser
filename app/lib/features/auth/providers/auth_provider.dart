import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/client.dart';
import '../../../core/storage/secure_storage.dart';

class AuthState {
  final bool isAuthenticated;
  final String? email;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.email,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? email,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        email:           email           ?? this.email,
        isLoading:       isLoading       ?? this.isLoading,
        error:           clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final token = await SecureStorage.instance.readToken();
    final email = await SecureStorage.instance.readEmail();
    if (token != null) {
      state = AuthState(isAuthenticated: true, email: email);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await ApiService.instance.login(email, password);
      await SecureStorage.instance.writeToken(resp.accessToken);
      await SecureStorage.instance.writeEmail(resp.email);
      state = AuthState(isAuthenticated: true, email: resp.email);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
    }
  }

  Future<void> register(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await ApiService.instance.register(email, password);
      await SecureStorage.instance.writeToken(resp.accessToken);
      await SecureStorage.instance.writeEmail(resp.email);
      state = AuthState(isAuthenticated: true, email: resp.email);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
    }
  }

  Future<void> logout() async {
    await SecureStorage.instance.clearAll();
    // Re-init the Dio client so it loses the stored token
    await ApiClient.instance.init();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(clearError: true);

  static String _extractMessage(Exception e) {
    final s = e.toString();
    final match = RegExp(r'"detail":\s*"([^"]+)"').firstMatch(s);
    return match?.group(1) ?? s.replaceFirst('Exception: ', '');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
