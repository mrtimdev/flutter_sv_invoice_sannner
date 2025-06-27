// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'providers/scan_provider.dart';
import 'services/scan_service.dart';
import 'providers/theme_notifier.dart'; // Make sure this exists
import 'screens/home_screen.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/in_app_scanner.dart';
import 'screens/scan/list.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import './core/api/api_endpoints.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('rootUrl', ApiEndpoints.rootUrl);
  await prefs.setString('baseUrl', ApiEndpoints.baseUrl);
  // Ensure cameras are initialized if your ScanScreen directly depends on it
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: ${e.code}\n${e.description}');
    // Handle camera initialization error gracefully, e.g., show a message
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ScanService>(
          create: (_) => ScanService(),
        ),
        ChangeNotifierProvider<ScanProvider>(
          create: (context) => ScanProvider(
            Provider.of<ScanService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider<ThemeNotifier>( // Make sure ThemeNotifier is provided
          create: (_) => ThemeNotifier(),
        ),

        // New Auth providers
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            Provider.of<AuthService>(context, listen: false),
          ),
        ),
      ],
      child: Consumer<ThemeNotifier>( // Consumer to react to theme changes
        builder: (context, themeNotifier, child) {
          return MaterialApp(
            title: 'Scan Pro',
            debugShowCheckedModeBanner: false, // Hide debug banner
            theme: ThemeData(
              // Define your primary blue
              primarySwatch: Colors.blue, // Creates various shades of blue
              primaryColor: const Color(0xFF2196F3), // Deep Blue (Material Blue 500)
              brightness: Brightness.light,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2196F3), // Primary blue
                brightness: Brightness.light,
                primary: const Color(0xFF2196F3), // Your main blue
                onPrimary: Colors.white,
                secondary: const Color(0xFFF44336), // Your accent red (Material Red 500)
                onSecondary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
                error: Colors.red,
                onError: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: const Color(0xFFF44336), // Red FAB
                foregroundColor: Colors.white,
              ),
              cardTheme: CardThemeData( // Changed from CardTheme to CardThemeData
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              // Add other theme properties as desired
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: const Color(0xFF1976D2), // Darker blue for dark mode
              visualDensity: VisualDensity.adaptivePlatformDensity,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1976D2), // Darker blue
                brightness: Brightness.dark,
                primary: const Color(0xFF1976D2),
                onPrimary: Colors.white,
                secondary: const Color(0xFFD32F2F), // Darker red for dark mode
                onSecondary: Colors.white,
                surface: const Color(0xFF121212), // Dark background
                onSurface: Colors.white70,
                error: const Color(0xFFCF6679),
                onError: Colors.black,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: const Color(0xFFD32F2F), // Darker Red FAB
                foregroundColor: Colors.white,
              ),
              cardTheme: CardThemeData( // Changed from CardTheme to CardThemeData
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            themeMode: themeNotifier.themeMode, 
            home: const SplashScreen(),
            routes: {
              '/scan': (context) => const ScanScreen(), 
              '/home': (context) => const HomeScreen(), 
              '/view-scan': (context) => const ScansListScreen(), 
              '/login': (context) => const LoginScreen(),
            },
            // onGenerateRoute: (settings) {
            //   if (settings.name == '/') {
            //     return MaterialPageRoute(builder: (context) => const SplashScreen());
            //   }
            //   return null; // Let the normal routing handle other routes
            // },
          );
        },
      ),
    );
  }
}