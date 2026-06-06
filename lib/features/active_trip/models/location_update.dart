class LocationUpdate {
  final String tripId;
  final double latitude;
  final double longitude;
  final double? speed;
  final double? accuracy;

  LocationUpdate({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.accuracy,
  });

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'latitude': latitude,
        'longitude': longitude,
        if (speed != null) 'speed': speed,
        if (accuracy != null) 'accuracy': accuracy,
      };
}
