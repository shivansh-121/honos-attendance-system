import 'dart:io';
import 'package:flutter/foundation.dart';
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

  // Bulletproof error widget — no custom theme, no extensions, cannot crash.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF1a1a1a),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rendering Error',
                style: TextStyle(
                  color: Color(0xFFFF5C5C),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // ── Step 1: Hive ─────────────────────────────────────────────────
  String? fatalError;

  try {
    await Hive.initFlutter();
    await Hive.openBox('session');
  } catch (e) {
    debugPrint('Hive open error, attempting recovery: $e');
    try {
      await Hive.deleteBoxFromDisk('session');
      await Hive.openBox('session');
    } catch (e2) {
      debugPrint('Hive recovery failed: $e2');
      fatalError = 'Storage Error: $e2';
    }
  }

  // ── Step 2: Firebase Core ────────────────────────────────────────
  // On Windows the C++ Firebase SDK initializes natively — we pass web
  // credentials so the Dart plugin can talk to the same project, but
  // we must NOT treat a channel-error as fatal; the native SDK is fine.
  if (fatalError == null) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully.');
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        // Already initialized by the native layer — perfectly fine.
        debugPrint('Firebase already initialized (duplicate-app is OK).');
      } else {
        debugPrint('Firebase Core init failed: $e');
        fatalError = 'Firebase Error [${e.code}]: ${e.message}';
      }
    } catch (e, stack) {
      final msg = e.toString();
      debugPrint('FIREBASE INIT ERROR: $msg');
      debugPrint('STACKTRACE: $stack');
      if (msg.contains('channel-error') || msg.contains('Unable to establish connection')) {
        // We cannot safely continue if the Dart channel handshake timed out,
        // because the Dart Firebase App is not registered and accessing
        // Dart Firebase plugins (like Firestore) will throw a core/no-app error.
        debugPrint('Firebase channel-error on Windows — failing. ($msg)');
        fatalError = 'Firebase Error: Dart failed to connect to native SDK ($msg)';
      } else {
        debugPrint('Firebase Core init failed (unknown): $e');
        fatalError = 'Firebase Error: $e';
      }
    }
  }

  // ── Step 3: Firestore settings ────────────────────────────────────
  if (fatalError == null) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore settings failed (non-fatal): $e');
    }
  }

  // ── Step 4: Mobile-only background services ───────────────────────
  if (fatalError == null && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await initBackgroundService();
    } catch (e) {
      debugPrint('Background service init skipped: $e');
    }
    try {
      await LocalPushService.initialize();
    } catch (e) {
      debugPrint('Local Push init skipped: $e');
    }
  }

  // ── Launch ────────────────────────────────────────────────────────
  runApp(
    ProviderScope(
      child: fatalError != null
          ? _FatalErrorApp(error: fatalError!)
          : const HonosApp(),
    ),
  );
}

/// Shown only when Hive fails completely.
/// Uses ZERO custom theme extensions — cannot crash.
class _FatalErrorApp extends StatelessWidget {
  final String error;
  const _FatalErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Honos Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF111111),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFFF5C5C), size: 72),
                const SizedBox(height: 24),
                const Text(
                  'Initialization Failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x30FFFFFF)),
                  ),
                  child: SelectableText(
                    error,
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
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

    // Keep push notification manager alive while app is running
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
