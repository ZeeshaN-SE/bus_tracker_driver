import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/active_trip/services/gps_tracking_service.dart';

// Entry point for the foreground task isolate
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(GpsTaskHandler());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize foreground task configuration
  GpsTrackingService.initialize();

  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Tracker Driver',
      theme: AppTheme.driver,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
