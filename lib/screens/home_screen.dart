import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:sv_service_checker/screens/service_checkers/add.dart';
import 'package:sv_service_checker/screens/service_checkers/form.dart';
import 'package:sv_service_checker/screens/settings.screen.dart';
import '../providers/theme_notifier.dart';
import '../providers/auth_provider.dart'; // Import AuthProvider
import 'auth/login_screen.dart';
import 'drivers/index.dart';
import 'in_app_scanner.dart';
import 'scan/list.dart';
import 'service_checkers/index.dart';
// import 'scans_list_screen.dart'; // Future: Create a screen to list user's scans

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure that auth status is checked when HomeScreen is initialized
    // This is especially important if HomeScreen is reached directly after SplashScreen
    // or if the app was killed and restarted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).initialAuthCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context); // Access ThemeNotifier

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Display a loading indicator while auth status is being checked
        if (authProvider.status == AuthStatus.initial || authProvider.status == AuthStatus.loading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  Text('Loading user session...', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, themeNotifier, authProvider), // Pass authProvider
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildActionCard(
                        context,
                        icon: Icons.checklist_sharp,
                        title: 'Check List',
                        subtitle: 'Service checker.',
                        onTap: () {
                          if (authProvider.isAuthenticated) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ServiceCheckersIndex()),
                            );
                          } else {
                            _showAuthRequiredDialog(context);
                          }
                        },
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        iconColor: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      _buildActionCard(
                        context,
                        icon: Icons.supervised_user_circle_outlined,
                        title: 'Your Drivers',
                        subtitle: 'Create or update driver`s info.',
                        onTap: () {
                          if (authProvider.isAuthenticated) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => DriverIndexScreen()));
                          } else {
                            _showAuthRequiredDialog(context);
                          }
                        },
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                        iconColor: Theme.of(context).colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              if (authProvider.isAuthenticated) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ServiceCheckerForm()),
                );
              } else {
                _showAuthRequiredDialog(context);
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Start New Check List'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ThemeNotifier themeNotifier, AuthProvider authProvider) {
    // Get username for display, default to 'Guest' if not authenticated
    final String displayName = authProvider.isAuthenticated ? authProvider.username ?? 'User' : 'Guest';

    return SliverAppBar(
      expandedHeight: 250,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min, // Use min size for column
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $displayName!', // Personalized welcome
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 18, // Slightly smaller for a welcome message
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            Text(
              'SV Service Checker', // Main app title remains visible when collapsed
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
              ),
            ),
            Lottie.asset(
              'assets/animations/animation01.json', // Replace with your Lottie asset path
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              repeat: true,
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.settings,
            color: Theme.of(context).colorScheme.onPrimary,
          ), 
          onPressed: () { Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ); },
        ),
        IconButton(
          icon: Icon(
            themeNotifier.themeMode == ThemeMode.light
                ? Icons.light_mode
                : Icons.dark_mode,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () {
            themeNotifier.toggleTheme(); // Toggle theme
          },
        ),
        // New: Login/Logout button
        if (authProvider.isAuthenticated)
          IconButton(
            icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.onPrimary),
            tooltip: 'Logout',
            onPressed: () {
              authProvider.logout();
              // Optionally navigate back to LoginScreen after logout
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        else
          IconButton(
            icon: Icon(Icons.login, color: Theme.of(context).colorScheme.onPrimary),
            tooltip: 'Login',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
    Color? iconColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.1),
        highlightColor: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color ?? Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: iconColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  

  // Helper method to show dialog when authentication is required
  void _showAuthRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Authentication Required'),
          content: const Text('Please log in to use this feature.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Login'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
