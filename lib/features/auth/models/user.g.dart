// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      profileImage: json['profile_image'] as String?,
      isActive: json['is_active'] as bool?,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'full_name': instance.fullName,
      'phone': instance.phone,
      'role': instance.role,
      'profile_image': instance.profileImage,
      'is_active': instance.isActive,
      'created_at': instance.createdAt,
    };
