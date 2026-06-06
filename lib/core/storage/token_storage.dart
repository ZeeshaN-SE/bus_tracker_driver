import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/models/user.dart';

class TokenStorage {
  TokenStorage._internal();
  static final TokenStorage instance = TokenStorage._internal();
  factory TokenStorage() => instance;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUser = 'user_data';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> saveUser(User user) async {
    final json = jsonEncode(user.toJson());
    await _storage.write(key: _keyUser, value: json);
  }

  Future<User?> getUser() async {
    final json = await _storage.read(key: _keyUser);
    if (json == null) return null;
    try {
      return User.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
