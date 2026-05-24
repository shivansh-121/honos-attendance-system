import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/background_location_service.dart';
import '../../services/app_nav.dart';
import '../../services/permission_service.dart';
import '../../models/site.dart';
import '../../models/app_user.dart';
import '../../app_theme.dart';
import 'take_attendance_screen.dart';
import 'guards_list_screen.dart';
import 'reports_screen.dart';
import 'sup_notifications_screen.dart';

class SupervisorDashboardScreen extends ConsumerStatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  ConsumerState<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState
    extends ConsumerState<SupervisorDashboardScreen> {
  bool _isOnDuty = false;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await isServiceRunning();
    if (mounted) {
      setState(() => _isOnDuty = isRunning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final sitesAsync = ref.watch(sitesStreamProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: const Color(0xFF1B3B60).withValues(alpha: 0.5),
            ),
          ),
        ),
        actions: [
          // Notification Bell
          Consumer(
            builder: (context, ref, child) {
              final notificationsAsync = ref.watch(notificationsStreamProvider);
              final user = ref.watch(authProvider);

              int unreadCount = 0;
              if (notificationsAsync.value != null) {
                unreadCount = notificationsAsync.value!
                    .where((n) => !n.isRead && n.supervisorId == user?.id && (n.type == 'edit_approved' || n.type == 'edit_rejected'))
                    .length;
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SupNotificationsScreen()));
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: AppTheme.red.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border(
                        bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  child: Center(
                    child: Hero(
                      tag: 'sup_logo',
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 90,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(
                    begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.white),
              title: const Text('Dashboard',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              selected: true,
              selectedTileColor: Colors.white.withValues(alpha: 0.1),
              onTap: () => Navigator.pop(context),
            )
                .animate()
                .fadeIn(delay: 200.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
            ListTile(
              leading: const Icon(Icons.security, color: Color(0xFFCAD4E0)),
              title: const Text('My Guards',
                  style: TextStyle(color: Color(0xFFCAD4E0))),
              onTap: () {
                Navigator.pop(context);
                AppNav.push(context, const GuardsListScreen());
              },
            )
                .animate()
                .fadeIn(delay: 350.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFFCAD4E0)),
              title: const Text('Reports',
                  style: TextStyle(color: Color(0xFFCAD4E0))),
              onTap: () {
                Navigator.pop(context);
                AppNav.push(context, const ReportsScreen());
              },
            )
                .animate()
                .fadeIn(delay: 500.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${user?.name ?? 'Supervisor'}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold))
                .animate()
                .fadeIn()
                .slideY(begin: 0.1, end: 0),
            const SizedBox(height: 8),
            sitesAsync
                .when(
                  data: (sites) {
                    final mySite = sites.firstWhere((s) => s.id == user?.siteId,
                        orElse: () => const Site(
                            id: '',
                            name: 'No site assigned',
                            address: '',
                            lat: 0,
                            lng: 0,
                            radius: 0,
                            supervisorId: ''));
                    return Text('Site: ${mySite.name}',
                        style: const TextStyle(
                            color: Color(0xFFCAD4E0), fontSize: 14));
                  },
                  loading: () => const Text('Site: Loading...',
                      style: TextStyle(color: Color(0xFFCAD4E0), fontSize: 14)),
                  error: (_, __) => const Text('Site: Error loading',
                      style: TextStyle(color: Color(0xFFCAD4E0), fontSize: 14)),
                )
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final sites = ref.read(sitesStreamProvider).value ?? [];
                      final pulseHospital = sites.firstWhere(
                          (s) => s.id == user?.siteId,
                          orElse: () => const Site(id: 'err', name: 'No Site Found', address: '', lat: 0, lng: 0, radius: 0, supervisorId: ''));
                      AppNav.push(context, TakeAttendanceScreen(site: pulseHospital, isCheckOutFlow: false));
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Check-In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final sites = ref.read(sitesStreamProvider).value ?? [];
                      final pulseHospital = sites.firstWhere(
                          (s) => s.id == user?.siteId,
                          orElse: () => const Site(id: 'err', name: 'No Site Found', address: '', lat: 0, lng: 0, radius: 0, supervisorId: ''));
                      AppNav.push(context, TakeAttendanceScreen(site: pulseHospital, isCheckOutFlow: true));
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Check-Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms).scale(),
            const SizedBox(height: 24),
            Card(
              color: _isOnDuty ? AppTheme.green.withValues(alpha: 0.08) : null,
              shape: _isOnDuty
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.green, width: 1.5),
                    )
                  : null,
              child: SwitchListTile(
                value: _isOnDuty,
                activeThumbColor: AppTheme.green,
                onChanged: (val) {
                  setState(() => _isOnDuty = val);
                  _handleDutyToggle(val, user);
                },
                title: Text(
                  _isOnDuty
                      ? '🟢 On Duty – Tracking Active'
                      : 'Start Duty & Share Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isOnDuty ? AppTheme.green : null,
                  ),
                ),
                subtitle: Text(
                  _isOnDuty
                      ? 'Your live path is visible to admin. Runs in background.'
                      : 'Turn on to share your live GPS location with admin. Required during shift.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 16),
            guardsAsync.when(
              data: (allGuards) {
                final myGuards =
                    allGuards.where((g) => g.siteId == user?.siteId).toList();
                final totalCount = myGuards.length;

                return attendanceAsync.when(
                  data: (todayAttendance) {
                    final siteAttendance = todayAttendance
                        .where((a) =>
                            a.siteId == user?.siteId &&
                            a.status.toLowerCase() == 'present')
                        .toList();

                    final uniquePresentIds =
                        siteAttendance.map((a) => a.guardId).toSet();
                    final presentCount = uniquePresentIds.length;
                    final absentCount =
                        (totalCount - presentCount).clamp(0, totalCount);

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _buildStatCard(
                                    context,
                                    'Total Guards',
                                    totalCount.toString(),
                                    Icons.people_outline,
                                    AppTheme.primary,
                                    delay: 800.ms)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildStatCard(
                                    context,
                                    'Present',
                                    presentCount.toString(),
                                    Icons.check_circle_outline,
                                    AppTheme.green,
                                    delay: 900.ms)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _buildStatCard(
                                    context,
                                    'Absent',
                                    absentCount.toString(),
                                    Icons.cancel_outlined,
                                    AppTheme.red,
                                    delay: 1000.ms)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildStatCard(
                                    context,
                                    'Duty Status',
                                    _isOnDuty ? 'ACTIVE' : 'INACTIVE',
                                    Icons.radar_rounded,
                                    _isOnDuty
                                        ? AppTheme.green
                                        : AppTheme.txtMuted,
                                    delay: 1100.ms)),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => _buildLoadingStats(context),
                  error: (_, __) => _buildErrorStats(context),
                );
              },
              loading: () => _buildLoadingStats(context),
              error: (_, __) => _buildErrorStats(context),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDutyToggle(bool val, AppUser? user) async {
    if (kIsWeb || user == null) return;
    if (val) {
      final gpsEnabled = await PermissionService.isGpsEnabled();
      if (!gpsEnabled && mounted) {
        setState(() => _isOnDuty = false);
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('GPS Disabled'),
            content: const Text(
                'Please enable Location Services (GPS) to start your duty tracking.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c), child: const Text('OK'))
            ],
          ),
        );
        return;
      }
      final hasPerms = await PermissionService.requestSupervisorPermissions();
      if (!hasPerms && mounted) {
        setState(() => _isOnDuty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Permissions required for tracking.'),
              backgroundColor: AppTheme.red),
        );
        return;
      }
    }
    toggleTracking(val, user.id);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val
              ? '✅ Live tracking started'
              : '⏹ Duty ended. Tracking stopped.'),
          backgroundColor: val ? AppTheme.green : null,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildLoadingStats(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    context, 'Total', '...', Icons.people, AppTheme.primary)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard(
                    context, 'Present', '...', Icons.check, AppTheme.green)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    context, 'Absent', '...', Icons.cancel, AppTheme.red)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard(context, 'Duty Status', '...',
                    Icons.radar_rounded, AppTheme.txtMuted)),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorStats(BuildContext context) {
    return const Center(
        child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Error loading stats',
                style: TextStyle(color: AppTheme.red))));
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
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCAD4E0))),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.1, end: 0);
  }
}
