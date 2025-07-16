import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // For cool animations, add to pubspec.yaml
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'auth/login_screen.dart'; // Adjust path if necessary

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    final prefs = await SharedPreferences.getInstance();
    bool? isAuthenticated;
    if (prefs.getBool("isAuthenticated") == true) {
      isAuthenticated = true;
    } else {
      isAuthenticated = false;
    }
    // Simulate some loading time or initialization
    await Future.delayed(const Duration(seconds: 3), () {}); // 3 seconds delay

    if (!mounted) return; 
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (prefs.getBool("isAuthenticated") == true) { 
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using current theme colors for a consistent look
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background, // Use background color from theme
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // A cool animation using Lottie.
            // You'll need to add 'lottie' to your pubspec.yaml:
            // dependencies:
            //   lottie: ^latest_version
            // And then download a .json animation file and place it in your assets folder.
            // Example: assets/lottie_scanner_animation.json
            Lottie.asset(
              'assets/animations/scanner_animation.json',
              width: 200,
              height: 200,
              fit: BoxFit.fill,
            ),
            const SizedBox(height: 24),
            Text(
              'SV-Invoice Scanner',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary, // Use primary color from theme
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Ultimate Scanning Solution',
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary), // Use accent color
            ),
          ],
        ),
      ),
    );
  }
}
