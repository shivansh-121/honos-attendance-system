import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/local_push_service.dart';
import '../../app_theme.dart';
import '../admin/supervisor_tracker_screen.dart';
import '../admin/manage_supervisors_screen.dart';
import '../admin/admin_sites_screen.dart';
import '../supervisor/reports_screen.dart';
import '../admin/admin_guards_list_screen.dart';
import '../admin/admin_guards_management_screen.dart';
import '../admin/admin_advances_screen.dart';
import '../../services/db_service.dart';
import '../../services/app_nav.dart';
import '../admin/notifications_screen.dart';
import '../supervisor/executive_take_attendance_screen.dart';
import '../supervisor/take_attendance_screen.dart';
import '../../models/site.dart';
import '../user_profile_screen.dart';
import '../../widgets/theme_toggle_button.dart';
class ExecutiveDashboardScreen extends ConsumerStatefulWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  ConsumerState<ExecutiveDashboardScreen> createState() =>
      _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends ConsumerState<ExecutiveDashboardScreen> {
  bool _notifiedPhoto = false;

  @override
  void initState() {
    super.initState();
    // Run background cleanup for old photos to save database storage
    Future.microtask(() {
      ref.read(dbProvider).cleanupOldAttendancePhotos();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPhotoStatus();
    });
  }

  void _checkPhotoStatus() {
    final user = ref.read(authProvider);
    if (user != null && user.role == 'executive') {
      if (user.photo.isEmpty || user.photo.length < 200) {
        if (!_notifiedPhoto) {
          LocalPushService.showNotification(
            title: 'Action Required',
            body: 'Please add a profile picture to check-in/out.',
          );
          LocalPushService.showPeriodicNotification(
            title: 'Action Required',
            body: 'Please add a profile picture to check-in/out.',
          );
          _notifiedPhoto = true;
        }
      } else {
        LocalPushService.cancelPeriodicNotification();
      }
    }
  }

  Future<void> _uploadPhoto(AppUser user) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (xFile == null) return;

    try {
      final bytes = await xFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return;
      final resized = img.copyResize(image, width: 400);
      final compressed = img.encodeJpg(resized, quality: 70);
      final base64Photo = base64Encode(compressed);

      final updatedUser = AppUser(
        id: user.id,
        empId: user.empId,
        name: user.name,
        username: user.username,
        password: user.password,
        role: user.role,
        siteId: user.siteId,
        salary: user.salary,
        phone: user.phone,
        dob: user.dob,
        address: user.address,
        aadharNo: user.aadharNo,
        uanNo: user.uanNo,
        bankName: user.bankName,
        ifsc: user.ifsc,
        accountNo: user.accountNo,
        branch: user.branch,
        photo: base64Photo,
        aadharPhoto: user.aadharPhoto,
        passbookPhoto: user.passbookPhoto,
        joinDate: user.joinDate,
        status: user.status,
      );

      await ref.read(dbProvider).saveUser(updatedUser);
      ref.read(authProvider.notifier).updateUser(updatedUser);
      _checkPhotoStatus();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profile picture updated!'), backgroundColor: context.colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.red));
    }
  }

  void _showPhotoPrompt(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: context.colors.yellow),
            const SizedBox(width: 8),
            const Text('Profile Picture Required', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'You must add a profile picture before you can check-in or check-out.',
          style: TextStyle(color: context.colors.txtSec),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _uploadPhoto(user);
            },
            child: const Text('Upload Now'),
          ),
        ],
      ),
    );
  }

  void _showAttendanceActionSheet(BuildContext context, AppUser user, bool isCheckOut) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colors.bgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(isCheckOut ? 'Who is checking out?' : 'Who is checking in?', 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  AppNav.push(context, ExecutiveTakeAttendanceScreen(isCheckOutFlow: isCheckOut));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(16),
                    color: context.colors.primary.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: context.colors.primary, child: const Icon(Icons.person, color: Colors.white)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Myself', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Record your own site visit', style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
                        ],
                      )),
                      Icon(Icons.chevron_right, color: context.colors.txtMuted),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  final dummySite = Site(id: 'executive_scan', name: 'Executive Scan', address: '', lat: 0, lng: 0, radius: 0, supervisorId: user.id);
                  AppNav.push(context, TakeAttendanceScreen(site: dummySite, isCheckOutFlow: isCheckOut));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.security, color: Colors.white)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('A Guard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Scan a guard\'s face to mark their attendance', style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
                        ],
                      )),
                      Icon(Icons.chevron_right, color: context.colors.txtMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive Dashboard'),
        actions: [
          const ThemeToggleButton(),
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
                          color: context.colors.blue,
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
        child: Column(
          children: [
            Expanded(
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
                    leading: Icon(Icons.dashboard, color: context.colors.primary),
                    title: Text('Dashboard',
                        style: TextStyle(
                            color: context.colors.primary, fontWeight: FontWeight.bold)),
                    selected: true,
                    selectedTileColor: context.colors.primary.withValues(alpha: 0.1),
                    onTap: () {})
                .animate()
                .fadeIn(delay: 200.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading:
                        Icon(Icons.location_on, color: context.colors.txtSec),
                    title: Text('Supervisor Tracker',
                        style: TextStyle(color: context.colors.txtSec)),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const SupervisorTrackerScreen());
                    })
                .animate()
                .fadeIn(delay: 350.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: Icon(Icons.manage_accounts,
                        color: context.colors.txtSec),
                    title: Text('Manage Supervisors',
                        style: TextStyle(color: context.colors.txtSec)),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const ManageSupervisorsScreen(role: 'supervisor'));
                    })
                .animate()
                .fadeIn(delay: 450.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),



            ListTile(
                    leading: Icon(Icons.fact_check, color: context.colors.txtSec),
                    title: Text('Manual Attendance',
                        style: TextStyle(color: context.colors.txtSec)),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const AdminGuardsListScreen());
                    })
                .animate()
                .fadeIn(delay: 550.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: Icon(Icons.people, color: context.colors.txtSec),
                    title: Text('Guards & Staff',
                        style: TextStyle(color: context.colors.txtSec)),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const AdminGuardsManagementScreen());
                    })
                .animate()
                .fadeIn(delay: 650.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: Icon(Icons.account_balance_wallet, color: context.colors.txtSec),
                    title: Text('Manage Advances',
                        style: TextStyle(color: context.colors.txtSec)),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const AdminAdvancesScreen());
                    })
                .animate()
                .fadeIn(delay: 500.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: Icon(Icons.business, color: context.colors.txtSec),
                    title: Text('Sites & Geofencing',
                        style: TextStyle(color: context.colors.txtSec)),
                    onTap: () {
                      AppNav.push(context, const AdminSitesScreen());
                    })
                .animate()
                .fadeIn(delay: 650.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

            ListTile(
                    leading: Icon(Icons.account_balance_wallet,
                        color: context.colors.txtSec),
                    title: Text('Attendance Report',
                        style: TextStyle(color: context.colors.txtSec)),
                    onTap: () {
                      AppNav.push(context, const ReportsScreen());
                    })
                .animate()
                .fadeIn(delay: 800.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),

                ],
              ),
            ),
            Divider(color: context.colors.primary.withValues(alpha: 0.1), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: context.colors.bgElevated,
                  backgroundImage: user != null && user.photo.length > 200 ? MemoryImage(base64Decode(user.photo)) : null,
                  child: user == null || user.photo.length < 200 ? Icon(Icons.person, size: 28, color: context.colors.txtMuted) : null,
                ),
                title: Text(user?.name ?? 'Profile',
                    style: TextStyle(color: context.colors.txtSec, fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(user?.role.toUpperCase() ?? 'EXECUTIVE', style: TextStyle(color: context.colors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  AppNav.push(context, const UserProfileScreen());
                },
              ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
            ),
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
            
            if (user?.role == 'executive') ...[
              Builder(
                builder: (context) {
                  final missingPhoto = user!.photo.isEmpty || user.photo.length < 200;
                  return Column(
                    children: [
                      if (missingPhoto)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: context.colors.red.withValues(alpha: 0.1),
                            border: Border.all(color: context.colors.red),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: context.colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Profile Picture Required', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('You must upload a profile picture before you can check-in or check-out.', style: TextStyle(color: context.colors.txtSec)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _uploadPhoto(user),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Upload Photo Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn().slideY(begin: -0.1, end: 0),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: missingPhoto ? Colors.grey.shade800 : context.colors.green,
                                foregroundColor: missingPhoto ? Colors.grey.shade500 : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: missingPhoto ? () => _showPhotoPrompt(context, user) : () {
                                _showAttendanceActionSheet(context, user, false);
                              },
                              icon: const Icon(Icons.login),
                              label: const Text('Check-In', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: missingPhoto ? Colors.grey.shade800 : context.colors.red,
                                foregroundColor: missingPhoto ? Colors.grey.shade500 : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: missingPhoto ? () => _showPhotoPrompt(context, user) : () {
                                _showAttendanceActionSheet(context, user, true);
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Check-Out', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

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
                        context.colors.primary,
                        delay: 400.ms),
                    loading: () => _buildStatCard(context, 'Total Guards',
                        '...', Icons.security, context.colors.primary),
                    error: (_, __) => _buildStatCard(context, 'Total Guards',
                        '!', Icons.security, context.colors.primary),
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
                        context.colors.purple,
                        delay: 500.ms),
                    loading: () => _buildStatCard(context, 'Supervisors', '...',
                        Icons.people, context.colors.purple),
                    error: (_, __) => _buildStatCard(context, 'Supervisors',
                        '!', Icons.people, context.colors.purple),
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
                          context.colors.green,
                          delay: 600.ms);
                    },
                    loading: () => _buildStatCard(context, 'Total Present',
                        '...', Icons.check_circle, context.colors.green),
                    error: (_, __) => _buildStatCard(context, 'Total Present',
                        '!', Icons.check_circle, context.colors.green),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ref.watch(sitesStreamProvider).when(
                    data: (sites) => _buildStatCard(
                        context, 'Sites Online', sites.length.toString(),
                        Icons.business, context.colors.yellow,
                        delay: 700.ms),
                    loading: () => _buildStatCard(context, 'Sites Online', '...',
                        Icons.business, context.colors.yellow),
                    error: (_, __) => _buildStatCard(context, 'Sites Online', '!',
                        Icons.business, context.colors.yellow),
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
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.colors.txtSec)),
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
              color: context.colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: context.colors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: context.colors.txtSec)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    ).animate().fadeIn(delay: delay).slideX(begin: 0.1, end: 0);
  }
}
