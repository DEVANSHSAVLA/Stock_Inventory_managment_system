import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/local_server_discovery.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/constants/api_urls.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final Map<String, dynamic>? tenant;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.tenant,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    Map<String, dynamic>? tenant,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      tenant: tenant ?? this.tenant,
      error: error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    debugPrint('--- [AuthNotifier] _init start ---');
    state = state.copyWith(isLoading: true);
    
    // 1. Load the last saved server URL or keep default
    try {
      debugPrint('--- [AuthNotifier] reading server URL from SecureStorage ---');
      var savedUrl = await SecureStorage().getServerUrl();
      debugPrint('--- [AuthNotifier] read server URL: $savedUrl ---');
      
      // Auto-heal local host entries to force cloud space URL
      if (savedUrl == null || savedUrl.isEmpty || savedUrl.contains('localhost') || savedUrl.contains('127.0.0.1')) {
        savedUrl = 'https://devanshsavla17-inventory-backend.hf.space';
        await SecureStorage().saveServerUrl(savedUrl);
      }
      
      ApiUrls.setBaseUrl(savedUrl);
      DioClient().updateBaseUrl(savedUrl);
    } catch (e) {
      debugPrint('--- [AuthNotifier] error reading server URL: $e ---');
    }
 
    // 2. Now try to fetch the current user profile (using the resolved/default API URL)
    debugPrint('--- [AuthNotifier] fetching current user from repository ---');
    try {
      final data = await _repo.getMe().timeout(const Duration(seconds: 10));
      debugPrint('--- [AuthNotifier] fetch current user completed, data: $data ---');
      if (data != null && data['user'] != null) {
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        state = AuthState(status: AuthStatus.authenticated, user: user, tenant: data['tenant'] as Map<String, dynamic>?);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('--- [AuthNotifier] fetch current user failed/timed out: $e ---');
      // Timeout, network error, or any other failure → go to login
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
    debugPrint('--- [AuthNotifier] _init finished. State status: ${state.status} ---');
  }

  Future<bool> login(String email, String password, {String? subdomain}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final data = await _repo.login(email, password, subdomain: subdomain);
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user, tenant: data['tenant'] as Map<String, dynamic>?);
      return true;
    } catch (e) {
      String msg = 'Login failed.';
      if (e.toString().contains('Invalid credentials')) msg = 'Invalid email or password.';
      else if (e.toString().contains('Company not found')) msg = 'Invalid workspace.';
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return false;
    }
  }

  Future<bool> signup({
    required String companyName,
    required String subdomain,
    required String email,
    required String password,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final data = await _repo.signup(
        companyName: companyName,
        subdomain: subdomain,
        email: email,
        password: password,
      );
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user, tenant: data['tenant'] as Map<String, dynamic>?);
      return true;
    } catch (e) {
      String msg = 'Signup failed.';
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void forceLogout() {
    if (state.status == AuthStatus.unauthenticated) return;
    _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref.read(authRepositoryProvider));
  DioClient().onAuthFailure = () {
    notifier.forceLogout();
  };
  return notifier;
});
