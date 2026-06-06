// GENERATED CODE - DO NOT MODIFY BY HAND
// Manually maintained for Phase 8 (matches output of json_serializable).

part of 'validation_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

const _$ValidationOutcomeEnumMap = {
  ValidationOutcome.valid: 'valid',
  ValidationOutcome.expired: 'expired',
  ValidationOutcome.invalid: 'invalid',
  ValidationOutcome.alreadyUsed: 'already_used',
  ValidationOutcome.unknown: 'unknown',
};

ValidationOutcome _$enumDecode(
  Map<ValidationOutcome, dynamic> map,
  Object? source, {
  ValidationOutcome? unknownValue,
}) {
  if (source == null) {
    return unknownValue ?? ValidationOutcome.unknown;
  }
  for (final entry in map.entries) {
    if (entry.value == source) return entry.key;
  }
  return unknownValue ?? ValidationOutcome.unknown;
}

ValidationResult _$ValidationResultFromJson(Map<String, dynamic> json) =>
    ValidationResult(
      valid: json['valid'] as bool? ?? false,
      result: _$enumDecode(
        _$ValidationOutcomeEnumMap,
        json['result'],
        unknownValue: ValidationOutcome.unknown,
      ),
      pass: json['pass'] == null
          ? null
          : ValidatedPass.fromJson(json['pass'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ValidationResultToJson(ValidationResult instance) =>
    <String, dynamic>{
      'valid': instance.valid,
      'result': _$ValidationOutcomeEnumMap[instance.result],
      'pass': instance.pass?.toJson(),
    };

ValidatedPass _$ValidatedPassFromJson(Map<String, dynamic> json) =>
    ValidatedPass(
      id: json['id'] as String,
      studentName: json['student_name'] as String?,
      passType: json['pass_type'] as String?,
      validFrom: json['valid_from'] as String?,
      validUntil: json['valid_until'] as String?,
    );

Map<String, dynamic> _$ValidatedPassToJson(ValidatedPass instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_name': instance.studentName,
      'pass_type': instance.passType,
      'valid_from': instance.validFrom,
      'valid_until': instance.validUntil,
    };
