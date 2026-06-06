import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class DioClient {
  DioClient._internal();
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio _dio = _createDio();

  Dio get dio => _dio;

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        // 60s tolerates Render free-tier cold starts (service sleeps after
        // 15 min idle, takes ~30–50s to wake up on first request).
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));

    dio.interceptors.add(_AuthInterceptor(dio));

    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await TokenStorage.instance.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await TokenStorage.instance.getRefreshToken();
        if (refreshToken == null) {
          await _clearAndReject(err, handler);
          return;
        }

        // Attempt to refresh the token
        final response = await _dio.post(
          ApiConstants.refresh,
          data: {'refreshToken': refreshToken},
        );

        final data = response.data as Map<String, dynamic>?;
        final newToken = data?['data']?['token'] as String?;
        final newRefresh = data?['data']?['refreshToken'] as String?;

        if (newToken == null) {
          await _clearAndReject(err, handler);
          return;
        }

        await TokenStorage.instance.saveToken(newToken);
        if (newRefresh != null) {
          await TokenStorage.instance.saveRefreshToken(newRefresh);
        }

        // Retry the original request with the new token
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        final retryResponse = await _dio.fetch(opts);
        handler.resolve(retryResponse);
      } catch (_) {
        await _clearAndReject(err, handler);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }

  Future<void> _clearAndReject(
      DioException err, ErrorInterceptorHandler handler) async {
    await TokenStorage.instance.clearAll();
    handler.next(err);
  }
}
