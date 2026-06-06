import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/api_response.dart';
import '../network/dio_client.dart';
import '../../features/auth/models/user.dart';
import '../../features/auth/models/auth_response.dart';
import '../../features/dashboard/models/trip.dart';
import '../../features/active_trip/models/location_update.dart';
import '../../features/scan/models/validation_result.dart';

class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;

  final Dio _dio = DioClient().dio;

  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<ApiResponse<AuthData>> login({
    required String email,
    required String password,
  }) async {
    return _request(
      () => _dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      }),
      fromJson: (json) => AuthData.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<ApiResponse<User>> getMe() async {
    return _request(
      () => _dio.get(ApiConstants.me),
      fromJson: (json) => User.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<ApiResponse<void>> logout() async {
    return _request<void>(
      () => _dio.post(ApiConstants.logout),
    );
  }

  Future<ApiResponse<AuthData>> refreshToken(String refreshToken) async {
    return _request(
      () => _dio.post(ApiConstants.refresh,
          data: {'refreshToken': refreshToken}),
      fromJson: (json) => AuthData.fromJson(json as Map<String, dynamic>),
    );
  }

  // ─── Trips ───────────────────────────────────────────────────────────────

  Future<ApiResponse<List<Trip>>> getMyTrips() async {
    return _request(
      () => _dio.get(ApiConstants.myTrips),
      fromJson: (json) => (json as List<dynamic>)
          .map((e) => Trip.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ApiResponse<Trip>> startTrip(String tripId) async {
    return _request(
      () => _dio.post(ApiConstants.startTrip(tripId)),
      fromJson: (json) => Trip.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<ApiResponse<Trip>> endTrip(String tripId) async {
    return _request(
      () => _dio.post(ApiConstants.endTrip(tripId)),
      fromJson: (json) => Trip.fromJson(json as Map<String, dynamic>),
    );
  }

  /// WhatsApp-style one-tap live tracking start.
  /// Creates a trip in `in_progress` state in a single round-trip.
  Future<ApiResponse<Trip>> quickStartTrip({
    required String busId,
    required String routeId,
  }) async {
    return _request(
      () => _dio.post(ApiConstants.quickStartTrip, data: {
        'bus_id': busId,
        'route_id': routeId,
      }),
      fromJson: (json) => Trip.fromJson(json as Map<String, dynamic>),
    );
  }

  // ─── Buses & Routes (for live-tracking picker) ───────────────────────────

  /// Get all active buses (used by the quick-start dropdown).
  Future<ApiResponse<List<Map<String, dynamic>>>> getBuses() async {
    return _request(
      () => _dio.get(ApiConstants.buses),
      fromJson: (json) => (json as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  /// Get all active routes (used by the quick-start dropdown).
  Future<ApiResponse<List<Map<String, dynamic>>>> getRoutes() async {
    return _request(
      () => _dio.get(ApiConstants.routes),
      fromJson: (json) => (json as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  // ─── GPS ─────────────────────────────────────────────────────────────────

  Future<ApiResponse<void>> updateLocation(LocationUpdate update) async {
    return _request<void>(
      () => _dio.post(ApiConstants.gpsLocation, data: update.toJson()),
    );
  }

  // ─── Pass Validation (Phase 8) ───────────────────────────────────────────

  /// Validate a scanned QR code against an in-progress trip.
  /// Returns a [ValidationResult] in `data` regardless of valid/invalid;
  /// only network/server errors are surfaced as `success = false`.
  Future<ApiResponse<ValidationResult>> validatePass({
    required String qrCode,
    required String tripId,
    double? latitude,
    double? longitude,
  }) async {
    return _request(
      () => _dio.post(ApiConstants.validatePass, data: {
        'qr_code': qrCode,
        'trip_id': tripId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      }),
      fromJson: (json) =>
          ValidationResult.fromJson(json as Map<String, dynamic>),
    );
  }

  // ─── Generic request helper ──────────────────────────────────────────────

  Future<ApiResponse<T>> _request<T>(
    Future<Response> Function() call, {
    T Function(Object? json)? fromJson,
  }) async {
    try {
      final response = await call();
      final body = response.data as Map<String, dynamic>;
      return ApiResponse<T>(
        success: body['success'] as bool? ?? true,
        message: body['message'] as String?,
        data: body['data'] != null && fromJson != null
            ? fromJson(body['data'])
            : null,
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      String message = _mapStatusToMessage(e);
      String? code;

      if (body is Map<String, dynamic>) {
        final err = body['error'];
        if (err is Map<String, dynamic>) {
          message = err['message'] as String? ?? message;
          code = err['code'] as String?;
        }
      }

      return ApiResponse<T>(
        success: false,
        error: ApiError(code: code, message: message),
      );
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        error: ApiError(message: 'An unexpected error occurred: $e'),
      );
    }
  }

  String _mapStatusToMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timed out. Please check your internet.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Is the backend running?';
      default:
        switch (e.response?.statusCode) {
          case 400:
            return 'Invalid request. Please check your input.';
          case 401:
            return 'Invalid credentials. Please try again.';
          case 403:
            return 'You do not have permission to perform this action.';
          case 404:
            return 'Resource not found.';
          case 409:
            return 'Conflict error.';
          case 500:
            return 'Server error. Please try again later.';
          default:
            return 'Something went wrong. Please try again.';
        }
    }
  }
}
