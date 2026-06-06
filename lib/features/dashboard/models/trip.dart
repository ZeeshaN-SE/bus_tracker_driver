import 'package:json_annotation/json_annotation.dart';

part 'trip.g.dart';

@JsonSerializable()
class Trip {
  final String id;
  final String status; // 'scheduled', 'in_progress', 'completed', 'cancelled'
  @JsonKey(name: 'scheduled_start_time')
  final String? scheduledStartTime;
  @JsonKey(name: 'scheduled_end_time')
  final String? scheduledEndTime;
  @JsonKey(name: 'actual_start_time')
  final String? actualStartTime;
  @JsonKey(name: 'actual_end_time')
  final String? actualEndTime;
  final BusSummary? bus;
  final RouteSummary? route;
  final DriverSummary? driver;

  Trip({
    required this.id,
    required this.status,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.actualStartTime,
    this.actualEndTime,
    this.bus,
    this.route,
    this.driver,
  });

  /// Returns the best time to display: actual start if in progress, scheduled otherwise
  String? get displayTime => actualStartTime ?? scheduledStartTime;

  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);
  Map<String, dynamic> toJson() => _$TripToJson(this);
}

@JsonSerializable()
class BusSummary {
  final String id;
  @JsonKey(name: 'bus_number')
  final String busNumber;
  @JsonKey(name: 'registration_number')
  final String? registrationNumber;
  final int? capacity;
  final String? model;

  BusSummary({
    required this.id,
    required this.busNumber,
    this.registrationNumber,
    this.capacity,
    this.model,
  });

  factory BusSummary.fromJson(Map<String, dynamic> json) =>
      _$BusSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$BusSummaryToJson(this);
}

@JsonSerializable()
class RouteSummary {
  final String id;
  @JsonKey(name: 'route_name')
  final String? routeName;
  @JsonKey(name: 'route_code')
  final String? routeCode;
  final String? description;

  RouteSummary({
    required this.id,
    this.routeName,
    this.routeCode,
    this.description,
  });

  String get name => routeName ?? 'Unknown Route';
  String get code => routeCode ?? '—';

  factory RouteSummary.fromJson(Map<String, dynamic> json) =>
      _$RouteSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$RouteSummaryToJson(this);
}

@JsonSerializable()
class DriverSummary {
  final String id;
  @JsonKey(name: 'full_name')
  final String? fullName;
  final String? email;

  DriverSummary({
    required this.id,
    this.fullName,
    this.email,
  });

  factory DriverSummary.fromJson(Map<String, dynamic> json) =>
      _$DriverSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$DriverSummaryToJson(this);
}
