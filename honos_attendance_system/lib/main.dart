import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';
import 'services/camera_service.dart';
import 'services/background_location_service.dart';
import 'screens/login_screen.dart';
import 'screens/supervisor/sup_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();
    await Hive.openBox('session');
  } catch (e) {
    debugPrint("Hive error: $e");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ── Enable Firestore offline persistence (huge speed boost) ──
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }

  // Fire-and-forget non-critical inits
  initCameras();
  initBackgroundService();

  runApp(
    const ProviderScope(
      child: HonosApp(),
    ),
  );

  // Background seed after UI is visible
  DbService().seedInitialData().catchError((e) => debugPrint("Seed error: $e"));
}

class HonosApp extends ConsumerWidget {
  const HonosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider);

    return MaterialApp(
      title: 'Honos Attendance',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: authUser == null
          ? const LoginScreen()
          : authUser.role == 'admin'
              ? const AdminDashboardScreen()
              : const SupervisorDashboardScreen(),
    );
  }
}
