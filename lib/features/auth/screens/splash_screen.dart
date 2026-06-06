import 'package:flutter/material.dart';
import '../../../core/storage/token_storage.dart';
import 'login_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final loggedIn = await TokenStorage.instance.isLoggedIn();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => loggedIn ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_bus,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            const Text(
              'Bus Tracker',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Driver App',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
