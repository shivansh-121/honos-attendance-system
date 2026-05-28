import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/background_location_service.dart';
import 'services/local_push_service.dart';
import 'screens/login_screen.dart';
import 'screens/supervisor/sup_dashboard_screen.dart';
import 'screens/employee/employee_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/executive/executive_dashboard_screen.dart';
import 'providers/theme_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();
    await Hive.openBox('session');
  } catch (e) {
    debugPrint("Hive error: $e");
  }

  bool firebaseInitialized = false;
  String? firebaseInitError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint("Firebase CORE already initialized natively.");
    } else {
      debugPrint("Firebase CORE init failed: $e");
      firebaseInitError = "Firebase Core Error: $e";
    }
  }

  if (firebaseInitError == null) {
    try {
      // ── Enable Firestore offline persistence (huge speed boost) ──
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      firebaseInitialized = true;
    } catch (e) {
      debugPrint("Firestore init failed: $e");
      firebaseInitError = "Firestore Error: $e";
    }
  }

  // Fire-and-forget non-critical inits
  initBackgroundService();
  LocalPushService.initialize();

  runApp(
    ProviderScope(
      child: firebaseInitialized 
          ? const HonosApp() 
          : InitializationErrorApp(error: firebaseInitError),
    ),
  );
}

class InitializationErrorApp extends StatelessWidget {
  final String? error;
  const InitializationErrorApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Honos Attendance',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to initialize Firebase. If you just added Firebase to the project, please completely stop the app and run it again (Hot Restart is not enough).\n\nDetails: $error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.txtSec),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HonosApp extends ConsumerWidget {
  const HonosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    
    // Watch the push notification manager so it stays alive while the app is running
    if (authUser != null) {
      ref.watch(pushNotificationManagerProvider);
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Honos Attendance',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: authUser == null
          ? const LoginScreen()
          : authUser.role == 'admin'
              ? const AdminDashboardScreen()
              : authUser.role == 'executive'
                  ? const ExecutiveDashboardScreen()
                  : authUser.role == 'employee'
                      ? const EmployeeDashboardScreen()
                      : const SupervisorDashboardScreen(),
    );
  }
}
