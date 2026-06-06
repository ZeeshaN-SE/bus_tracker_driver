import 'package:json_annotation/json_annotation.dart';

part 'validation_result.g.dart';

/// Outcome categories returned by the backend `/api/passes/validate` endpoint.
/// Mirrors the DB CHECK constraint on `pass_validations.validation_result`.
enum ValidationOutcome {
  @JsonValue('valid')
  valid,
  @JsonValue('expired')
  expired,
  @JsonValue('invalid')
  invalid,
  @JsonValue('already_used')
  alreadyUsed,
  unknown,
}

@JsonSerializable()
class ValidationResult {
  final bool valid;
  @JsonKey(unknownEnumValue: ValidationOutcome.unknown)
  final ValidationOutcome result;
  final ValidatedPass? pass;

  ValidationResult({
    required this.valid,
    required this.result,
    this.pass,
  });

  factory ValidationResult.fromJson(Map<String, dynamic> json) =>
      _$ValidationResultFromJson(json);
  Map<String, dynamic> toJson() => _$ValidationResultToJson(this);
}

@JsonSerializable()
class ValidatedPass {
  final String id;
  @JsonKey(name: 'student_name')
  final String? studentName;
  @JsonKey(name: 'pass_type')
  final String? passType;
  @JsonKey(name: 'valid_from')
  final String? validFrom;
  @JsonKey(name: 'valid_until')
  final String? validUntil;

  ValidatedPass({
    required this.id,
    this.studentName,
    this.passType,
    this.validFrom,
    this.validUntil,
  });

  factory ValidatedPass.fromJson(Map<String, dynamic> json) =>
      _$ValidatedPassFromJson(json);
  Map<String, dynamic> toJson() => _$ValidatedPassToJson(this);
}
