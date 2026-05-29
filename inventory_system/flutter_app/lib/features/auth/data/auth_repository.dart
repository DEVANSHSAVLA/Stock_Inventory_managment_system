import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/hive_service.dart';
import '../../../shared/models/user_model.dart';

class AuthRepository {
  final _dio = DioClient().dio;
  final _publicDio = DioClient().publicDio;

  Future<Map<String, dynamic>> resolveTenant(String subdomain) async {
    final response = await _publicDio.post(ApiUrls.resolveTenant, data: {
      'subdomain': subdomain,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signup({
    required String companyName,
    required String subdomain,
    required String email,
    required String password,
  }) async {
    final response = await _publicDio.post(ApiUrls.signupPublic, data: {
      'company_name': companyName,
      'subdomain': subdomain,
      'email': email,
      'password': password,
    });
    
    final data = response.data['data'];
    await _saveAuthData(data);
    return data;
  }

  Future<Map<String, dynamic>> login(String email, String password, {String? subdomain}) async {
    final response = await _publicDio.post(ApiUrls.loginPublic, data: {
      'email': email,
      'password': password,
      if (subdomain != null && subdomain.isNotEmpty) 'subdomain': subdomain,
    });
    
    final data = response.data['data'];
    await _saveAuthData(data);
    return data;
  }

  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    await SecureStorage().saveTokens(data['access'], data['refresh']);
    
    final tenant = data['tenant'] as Map<String, dynamic>;
    final schemaName = tenant['schema_name'];
    final companyName = tenant['company_name'];
    
    await SecureStorage().saveTenantSchema(schemaName);
    await SecureStorage().saveCompanyName(companyName);
    DioClient().setTenantSchema(schemaName);
    
    final user = data['user'] as Map<String, dynamic>;
    await SecureStorage().saveUserRole(user['role']);
    await HiveService.cacheUserData(user);
  }

  Future<void> logout() async {
    try {
      final refresh = await SecureStorage().getRefreshToken();
      if (refresh != null) {
        await _dio.post(ApiUrls.logout, data: {'refresh': refresh});
      }
    } catch (_) {}
    await SecureStorage().clearAll();
    await HiveService.clearAll();
    DioClient().setTenantSchema(null);
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final schema = await SecureStorage().getTenantSchema();
      if (schema != null) {
        DioClient().setTenantSchema(schema);
      }
      
      final response = await _dio.get(ApiUrls.me);
      return response.data['data'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
