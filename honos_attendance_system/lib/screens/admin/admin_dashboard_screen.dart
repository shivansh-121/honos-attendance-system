import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../app_theme.dart';
import 'supervisor_tracker_screen.dart';
import 'manage_supervisors_screen.dart';
import 'admin_sites_screen.dart';
import '../supervisor/reports_screen.dart';
import 'admin_guards_list_screen.dart';
import 'admin_guards_management_screen.dart';
import 'admin_advances_screen.dart';
import '../../services/db_service.dart';
import '../../services/app_nav.dart';
import 'notifications_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Run background cleanup for old photos to save database storage
    Future.microtask(() {
      ref.read(dbProvider).cleanupOldAttendancePhotos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final notificationsAsync = ref.watch(notificationsStreamProvider);
              final unreadCount = notificationsAsync.value?.where((n) => !n.isRead).length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () => AppNav.push(context, const NotificationsScreen()),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 1.seconds),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Full-width Logo Header
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1B3B60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Hero(
                tag: 'admin_logo',
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 800.ms),
            ListTile(
                    leading: const Icon(Icons.dashboard, color: Colors.white),
                    title: const Text('Dashboard',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    selected: true,
                    selectedTileColor: Colors.white.withValues(alpha: 0.1),
                    onTap: () {})
                .animate()
                .fadeIn(delay: 200.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading:
                        const Icon(Icons.location_on, color: Color(0xFFCAD4E0)),
                    title: const Text('Supervisor Tracker',
                        style: TextStyle(color: Color(0xFFCAD4E0))),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const SupervisorTrackerScreen());
                    })
                .animate()
                .fadeIn(delay: 350.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: const Icon(Icons.manage_accounts,
                        color: Color(0xFFCAD4E0)),
                    title: const Text('Manage Supervisors',
                        style: TextStyle(color: Color(0xFFCAD4E0))),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const ManageSupervisorsScreen());
                    })
                .animate()
                .fadeIn(delay: 450.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: const Icon(Icons.fact_check, color: Color(0xFFCAD4E0)),
                    title: const Text('Manual Attendance',
                        style: TextStyle(color: Color(0xFFCAD4E0))),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const AdminGuardsListScreen());
                    })
                .animate()
                .fadeIn(delay: 550.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: const Icon(Icons.people, color: Color(0xFFCAD4E0)),
                    title: const Text('Guards & Staff',
                        style: TextStyle(color: Color(0xFFCAD4E0))),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const AdminGuardsManagementScreen());
                    })
                .animate()
                .fadeIn(delay: 650.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Color(0xFFCAD4E0)),
                    title: const Text('Manage Advances',
                        style: TextStyle(color: Color(0xFFCAD4E0))),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const AdminAdvancesScreen());
                    })
                .animate()
                .fadeIn(delay: 500.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: const Icon(Icons.business, color: Color(0xFFCAD4E0)),
                    title: const Text('Sites & Geofencing',
                        style: TextStyle(color: Color(0xFFCAD4E0))),
                    onTap: () {
                      AppNav.push(context, const AdminSitesScreen());
                    })
                .animate()
                .fadeIn(delay: 650.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: const Icon(Icons.account_balance_wallet,
                        color: Color(0xFFCAD4E0)),
                    title: const Text('Attendance Report',
                        style: TextStyle(color: Color(0xFFCAD4E0))),
                    onTap: () {
                      AppNav.push(context, const ReportsScreen());
                    })
                .animate()
                .fadeIn(delay: 800.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${user?.name ?? 'Admin'}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold))
                .animate()
                .fadeIn()
                .slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),

            // Summary Stats
            Row(
              children: [
                Expanded(
                  child: guardsAsync.when(
                    data: (guards) => _buildStatCard(
                        context,
                        'Total Guards',
                        guards.length.toString(),
                        Icons.security,
                        AppTheme.primary,
                        delay: 400.ms),
                    loading: () => _buildStatCard(context, 'Total Guards',
                        '...', Icons.security, AppTheme.primary),
                    error: (_, __) => _buildStatCard(context, 'Total Guards',
                        '!', Icons.security, AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: usersAsync.when(
                    data: (users) => _buildStatCard(
                        context,
                        'Supervisors',
                        users
                            .where((u) => u.role == 'supervisor')
                            .length
                            .toString(),
                        Icons.people,
                        AppTheme.purple,
                        delay: 500.ms),
                    loading: () => _buildStatCard(context, 'Supervisors', '...',
                        Icons.people, AppTheme.purple),
                    error: (_, __) => _buildStatCard(context, 'Supervisors',
                        '!', Icons.people, AppTheme.purple),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: attendanceAsync.when(
                    data: (att) {
                      final today =
                          DateTime.now().toIso8601String().split('T').first;
                      final presentToday = att
                          .where(
                              (a) => a.date == today && a.status.toLowerCase() == 'present')
                          .length;
                      return _buildStatCard(
                          context,
                          'Total Present',
                          presentToday.toString(),
                          Icons.check_circle,
                          AppTheme.green,
                          delay: 600.ms);
                    },
                    loading: () => _buildStatCard(context, 'Total Present',
                        '...', Icons.check_circle, AppTheme.green),
                    error: (_, __) => _buildStatCard(context, 'Total Present',
                        '!', Icons.check_circle, AppTheme.green),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ref.watch(sitesStreamProvider).when(
                    data: (sites) => _buildStatCard(
                        context, 'Sites Online', sites.length.toString(),
                        Icons.business, AppTheme.yellow,
                        delay: 700.ms),
                    loading: () => _buildStatCard(context, 'Sites Online', '...',
                        Icons.business, AppTheme.yellow),
                    error: (_, __) => _buildStatCard(context, 'Sites Online', '!',
                        Icons.business, AppTheme.yellow),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text('Command Center',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold))
                .animate()
                .fadeIn(delay: 800.ms),
            const SizedBox(height: 16),

            _buildActionCard(context, 'Live Supervisor Map',
                'Track all supervisors in real-time', Icons.map, () {
              AppNav.push(context, const SupervisorTrackerScreen());
            }, delay: 900.ms),
            const SizedBox(height: 12),
            _buildActionCard(context, 'Guards & Staff',
                'View, search and manage all guards', Icons.people, () {
              AppNav.push(context, const AdminGuardsManagementScreen());
            }, delay: 1000.ms),
            const SizedBox(height: 12),
            _buildActionCard(
                context,
                'Sites & Geofencing',
                'Manage site locations and geofence radius',
                Icons.business, () {
              AppNav.push(context, const AdminSitesScreen());
            }, delay: 1100.ms),
            const SizedBox(height: 12),
            _buildActionCard(
                context,
                'Attendance Report',
                'View full attendance history and reports',
                Icons.bar_chart, () {
              AppNav.push(context, const ReportsScreen());
            }, delay: 1200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color,
      {Duration delay = Duration.zero}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCAD4E0))),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).scale();
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle,
      IconData icon, VoidCallback onTap,
      {Duration delay = Duration.zero}) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFFCAD4E0))),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    ).animate().fadeIn(delay: delay).slideX(begin: 0.1, end: 0);
  }
}
