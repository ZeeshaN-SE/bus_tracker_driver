import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'auth_response.g.dart';

@JsonSerializable()
class AuthResponse {
  final bool success;
  final String? message;
  final AuthData? data;

  AuthResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable()
class AuthData {
  final User user;
  final String token;
  @JsonKey(name: 'refreshToken')
  final String refreshToken;

  AuthData({
    required this.user,
    required this.token,
    required this.refreshToken,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) =>
      _$AuthDataFromJson(json);
  Map<String, dynamic> toJson() => _$AuthDataToJson(this);
}
