import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_urls.dart';
import '../storage/secure_storage.dart';

final dioProvider = Provider<Dio>((ref) => DioClient().dio);


class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  DioClient._internal() {
    _init();
  }

  late final Dio _dio;
  late final Dio _publicDio;
  String? tenantSchema;
  void Function()? onAuthFailure;

  Dio get dio => _dio;
  Dio get publicDio => _publicDio;

  void setTenantSchema(String? schema) {
    tenantSchema = schema;
  }

  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
    _publicDio.options.baseUrl = newUrl;
  }

  void _init() {
    final baseOptions = BaseOptions(
      baseUrl: ApiUrls.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    );

    _dio = Dio(baseOptions);
    _publicDio = Dio(baseOptions);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage().getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (tenantSchema != null) {
            options.headers['X-Tenant-ID'] = tenantSchema;
            options.queryParameters['tenant'] = tenantSchema; // Fallback for WebSocket / API
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              final token = await SecureStorage().getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              } catch (_) {}
            } else {
              await SecureStorage().clearAll();
              onAuthFailure?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    try {
      final refresh = await SecureStorage().getRefreshToken();
      if (refresh == null) return false;
      final response = await _publicDio.post(
        ApiUrls.refresh,
        data: {'refresh': refresh},
      );
      final access = response.data['access'];
      final newRefresh = response.data['refresh'] ?? refresh;
      if (access != null) {
        await SecureStorage().saveTokens(access, newRefresh);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
