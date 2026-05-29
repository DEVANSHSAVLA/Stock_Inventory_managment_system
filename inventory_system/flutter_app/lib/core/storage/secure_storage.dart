import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'hive_service.dart';

class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  final _storage = const FlutterSecureStorage();

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyTenantSchema = 'tenant_schema';
  static const _keyCompanyName = 'company_name';
  static const _keyUserRole = 'user_role';
  static const _keyServerUrl = 'server_url';

  // 1. Tokens (Sensitive): Try using secure storage, fallback to Hive if it fails.
  Future<void> saveTokens(String access, String refresh) async {
    try {
      await _storage.write(key: _keyAccess, value: access);
      await _storage.write(key: _keyRefresh, value: refresh);
      // Clean up fallback tokens if secure storage succeeded
      await HiveService.userData.delete(_keyAccess);
      await HiveService.userData.delete(_keyRefresh);
    } catch (e) {
      debugPrint('[SecureStorage] Error writing tokens securely, using Hive fallback: $e');
      await HiveService.userData.put(_keyAccess, access);
      await HiveService.userData.put(_keyRefresh, refresh);
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _keyAccess);
      if (token != null) return token;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading access token, checking Hive fallback: $e');
    }
    return HiveService.userData.get(_keyAccess) as String?;
  }

  Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _keyRefresh);
      if (token != null) return token;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading refresh token, checking Hive fallback: $e');
    }
    return HiveService.userData.get(_keyRefresh) as String?;
  }

  // 2. Non-Sensitive configurations: Store and retrieve directly from Hive.
  // This is synchronous internally, which makes it fast, reliable, and completely eliminates startup hangs.
  Future<void> saveTenantSchema(String schema) async {
    await HiveService.userData.put(_keyTenantSchema, schema);
  }

  Future<String?> getTenantSchema() async {
    return HiveService.userData.get(_keyTenantSchema) as String?;
  }

  Future<void> saveCompanyName(String name) async {
    await HiveService.userData.put(_keyCompanyName, name);
  }

  Future<String?> getCompanyName() async {
    return HiveService.userData.get(_keyCompanyName) as String?;
  }

  Future<void> saveUserRole(String role) async {
    await HiveService.userData.put(_keyUserRole, role);
  }

  Future<String?> getUserRole() async {
    return HiveService.userData.get(_keyUserRole) as String?;
  }

  Future<void> saveServerUrl(String url) async {
    await HiveService.userData.put(_keyServerUrl, url);
  }

  Future<String?> getServerUrl() async {
    return HiveService.userData.get(_keyServerUrl) as String?;
  }

  Future<void> clearTokens() async {
    try {
      await _storage.delete(key: _keyAccess);
      await _storage.delete(key: _keyRefresh);
    } catch (_) {}
    await HiveService.userData.delete(_keyAccess);
    await HiveService.userData.delete(_keyRefresh);
  }

  Future<void> clearAll() async {
    // Preserve server URL across logout so user doesn't have to re-enter it
    final serverUrl = HiveService.userData.get(_keyServerUrl);
    
    try {
      await _storage.deleteAll();
    } catch (_) {}
    
    await HiveService.userData.clear();
    
    if (serverUrl != null) {
      await HiveService.userData.put(_keyServerUrl, serverUrl);
    }
  }
}
