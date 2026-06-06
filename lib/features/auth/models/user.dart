import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String email;
  @JsonKey(name: 'full_name')
  final String fullName;
  final String? phone;
  final String role;
  @JsonKey(name: 'profile_image')
  final String? profileImage;
  @JsonKey(name: 'is_active')
  final bool? isActive;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.profileImage,
    this.isActive,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Returns initials for avatar display (e.g. "John Doe" → "JD")
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}
