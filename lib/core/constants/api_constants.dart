class ApiConstants {
  // Android emulator: http://10.0.2.2:3000/api/
  // Physical device: http://<your-pc-lan-ip>:3000/api/
  // ngrok: https://xxxx.ngrok.io/api/
  static const String baseUrl = 'https://bus-tracker-backend-upt9.onrender.com/api/';

  // Auth
  static const String login = 'auth/login';
  static const String me = 'auth/me';
  static const String logout = 'auth/logout';
  static const String refresh = 'auth/refresh';

  // Trips
  static const String myTrips = 'trips/my';
  static String startTrip(String tripId) => 'trips/$tripId/start';
  static String endTrip(String tripId) => 'trips/$tripId/end';
  /// WhatsApp-style one-tap live tracking (Phase 11). Body: { bus_id, route_id }.
  static const String quickStartTrip = 'trips/quick-start';

  // Buses & Routes — needed for the quick-start picker
  static const String buses = 'buses';
  static const String routes = 'routes';

  // GPS
  static const String gpsLocation = 'gps/location';

  // Passes (Phase 8)
  static const String validatePass = 'passes/validate';

  /// WebSocket origin (everything before `/api/`). Used by the student app's
  /// Socket.IO client. The driver app does not need it.
  static String get socketBaseUrl =>
      baseUrl.replaceAll(RegExp(r'/api/?$'), '');
}
