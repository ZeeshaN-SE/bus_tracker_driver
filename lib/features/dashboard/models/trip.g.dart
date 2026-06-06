// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Trip _$TripFromJson(Map<String, dynamic> json) => Trip(
      id: json['id'] as String,
      status: json['status'] as String,
      scheduledStartTime: json['scheduled_start_time'] as String?,
      scheduledEndTime: json['scheduled_end_time'] as String?,
      actualStartTime: json['actual_start_time'] as String?,
      actualEndTime: json['actual_end_time'] as String?,
      bus: json['bus'] == null
          ? null
          : BusSummary.fromJson(json['bus'] as Map<String, dynamic>),
      route: json['route'] == null
          ? null
          : RouteSummary.fromJson(json['route'] as Map<String, dynamic>),
      driver: json['driver'] == null
          ? null
          : DriverSummary.fromJson(json['driver'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TripToJson(Trip instance) => <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'scheduled_start_time': instance.scheduledStartTime,
      'scheduled_end_time': instance.scheduledEndTime,
      'actual_start_time': instance.actualStartTime,
      'actual_end_time': instance.actualEndTime,
      'bus': instance.bus,
      'route': instance.route,
      'driver': instance.driver,
    };

BusSummary _$BusSummaryFromJson(Map<String, dynamic> json) => BusSummary(
      id: json['id'] as String,
      busNumber: json['bus_number'] as String,
      registrationNumber: json['registration_number'] as String?,
      capacity: (json['capacity'] as num?)?.toInt(),
      model: json['model'] as String?,
    );

Map<String, dynamic> _$BusSummaryToJson(BusSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bus_number': instance.busNumber,
      'registration_number': instance.registrationNumber,
      'capacity': instance.capacity,
      'model': instance.model,
    };

RouteSummary _$RouteSummaryFromJson(Map<String, dynamic> json) => RouteSummary(
      id: json['id'] as String,
      routeName: json['route_name'] as String?,
      routeCode: json['route_code'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$RouteSummaryToJson(RouteSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'route_name': instance.routeName,
      'route_code': instance.routeCode,
      'description': instance.description,
    };

DriverSummary _$DriverSummaryFromJson(Map<String, dynamic> json) =>
    DriverSummary(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$DriverSummaryToJson(DriverSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'full_name': instance.fullName,
      'email': instance.email,
    };
