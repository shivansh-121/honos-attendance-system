import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/local_push_service.dart';
import '../../services/db_service.dart';
import '../../services/app_nav.dart';
import '../../services/mobile_attendance_guard.dart';
import '../../nl_theme.dart';
import '../../app_theme.dart';
import '../../widgets/theme_toggle_button.dart';

import '../admin/supervisor_tracker_screen.dart';
import '../admin/manage_supervisors_screen.dart';
import '../admin/admin_sites_screen.dart';
import '../supervisor/reports_screen.dart';
import '../admin/admin_guards_management_screen.dart';
import '../admin/admin_advances_screen.dart';
import '../admin/notifications_screen.dart';
import '../supervisor/executive_take_attendance_screen.dart';
import '../admin/export_hub_screen.dart';
import '../admin/admin_manual_attendance_screen.dart';
import '../user_profile_screen.dart';

class ExecutiveDashboardScreen extends ConsumerStatefulWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  ConsumerState<ExecutiveDashboardScreen> createState() =>
      _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState
    extends ConsumerState<ExecutiveDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _notifiedPhoto = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dbProvider).cleanupOldAttendancePhotos());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPhotoStatus());
  }

  void _checkPhotoStatus() {
    final user = ref.read(authProvider);
    if (user != null && (user.photo.isEmpty || user.photo.length < 200)) {
      if (!_notifiedPhoto) {
        LocalPushService.showNotification(
            title: 'Action Required',
            body: 'Please add a profile picture to check-in/out.');
        _notifiedPhoto = true;
      }
    }
  }

  Future<void> _uploadPhoto(AppUser user) async {
    final picker = ImagePicker();
    final xFile =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: NLTheme.accentGreen));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _showPhotoPrompt(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NLTheme.surface,
        title: const Text('Profile Picture Required',
            style: TextStyle(color: NLTheme.primaryText)),
        content: const Text(
            'You must add a profile picture before you can check-in or check-out.',
            style: TextStyle(color: NLTheme.secondaryText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: NLTheme.sidebar,
            ),
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

  void _handleExecutiveAttendance(
      BuildContext context, AppUser user, bool isCheckOut) {
    if (!isMobileAttendanceDevice) {
      showMobileAttendanceRequiredDialog(context, isCheckOut: isCheckOut);
      return;
    }
    if (user.photo.isEmpty || user.photo.length < 200) {
      _showPhotoPrompt(context, user);
      return;
    }
    AppNav.push(
        context, ExecutiveTakeAttendanceScreen(isCheckOutFlow: isCheckOut));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);
    if (user == null) return const Scaffold();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        backgroundColor: context.colors.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colors.txtPrimary),
        actions: [
          const ThemeToggleButton(),
          Consumer(
            builder: (context, ref, child) {
              final notificationsAsync = ref.watch(notificationsStreamProvider);
              final unreadCount = notificationsAsync.value?.where((n) {
                    if (n.isRead) return false;
                    if (n.type == 'edit_request') return false;
                    return n.supervisorId == user.id || n.guardId == user.id;
                  }).length ??
                  0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none,
                        color: context.colors.txtPrimary),
                    onPressed: () =>
                        AppNav.push(context, const NotificationsScreen()),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            color: context.colors.primary,
                            shape: BoxShape.circle),
                        constraints:
                            const BoxConstraints(minWidth: 8, minHeight: 8),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.2, 1.2),
                          duration: 1.seconds),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildNLDrawer(user),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text('Hello ${user.name.split(' ').first}',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: context.colors.txtPrimary))
                    .animate()
                    .fadeIn()
                    .slideX(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('EXECUTIVE DASHBOARD',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: context.colors.txtSec,
                            letterSpacing: 1)),
                  ],
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 24),

                // Attendance Action
                Row(
                  children: [
                    Expanded(
                      child: _buildAttendanceButton(
                          'Check In',
                          Icons.login,
                          NLTheme.accentGreen,
                          () =>
                              _handleExecutiveAttendance(context, user, false)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAttendanceButton(
                          'Check Out',
                          Icons.logout,
                          NLTheme.accentPink,
                          () =>
                              _handleExecutiveAttendance(context, user, true)),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms).slideY(),

                const SizedBox(height: 24),

                // Stats Row
                Row(
                  children: [
                    Expanded(
                        child: _buildStatSquare(
                                'Total\nGuards',
                                guardsAsync.value?.length.toString() ?? '-',
                                '+Active',
                                context.colors.bgSurface)
                            .animate()
                            .fadeIn(delay: 300.ms)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildStatSquare(
                                'Total\nSites',
                                guardsAsync.value
                                        ?.map((g) => g.siteId)
                                        .toSet()
                                        .length
                                        .toString() ??
                                    '-',
                                'Managed',
                                context.colors.primary.withValues(alpha: 0.1))
                            .animate()
                            .fadeIn(delay: 400.ms)),
                  ],
                ),

                const SizedBox(height: 24),
                Text('Manage Staff',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.colors.txtPrimary))
                    .animate()
                    .fadeIn(delay: 500.ms),
                const SizedBox(height: 16),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 900
                      ? 4
                      : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio:
                      MediaQuery.of(context).size.width > 600 ? 1.5 : 1.1,
                  children: [
                    _buildActionButton(
                        title: 'Guards',
                        icon: Icons.security,
                        color: context.colors.bgElevated,
                        textColor: Colors.white,
                        onTap: () => AppNav.push(
                            context, const AdminGuardsManagementScreen())),
                    _buildActionButton(
                        title: 'Supervisors',
                        icon: Icons.badge,
                        color: context.colors.bgSurface,
                        textColor: context.colors.txtPrimary,
                        onTap: () => AppNav.push(context,
                            const ManageSupervisorsScreen(role: 'supervisor'))),
                    _buildActionButton(
                        title: 'Employees',
                        icon: Icons.computer,
                        color: context.colors.bgSurface,
                        textColor: context.colors.txtPrimary,
                        onTap: () => AppNav.push(context,
                            const ManageSupervisorsScreen(role: 'employee'))),
                  ],
                ).animate().fadeIn(delay: 600.ms).slideY(),

                const SizedBox(height: 24),
                Text('Operations',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.colors.txtPrimary))
                    .animate()
                    .fadeIn(delay: 700.ms),
                const SizedBox(height: 16),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 900
                      ? 4
                      : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio:
                      MediaQuery.of(context).size.width > 600 ? 1.5 : 1.1,
                  children: [
                    _buildActionButton(
                        title: 'Reports',
                        icon: Icons.bar_chart,
                        color: context.colors.green,
                        textColor: context.colors.bgSurface,
                        onTap: () =>
                            AppNav.push(context, const ReportsScreen())),
                    _buildActionButton(
                        title: 'Advances',
                        icon: Icons.account_balance_wallet,
                        color: context.colors.bgSurface,
                        textColor: context.colors.txtPrimary,
                        onTap: () =>
                            AppNav.push(context, const AdminAdvancesScreen())),
                    _buildActionButton(
                        title: 'Tracker',
                        icon: Icons.location_on,
                        color: context.colors.bgSurface,
                        textColor: context.colors.txtPrimary,
                        onTap: () => AppNav.push(
                            context, const SupervisorTrackerScreen())),
                    _buildActionButton(
                        title: 'Manage Sites',
                        icon: Icons.business,
                        color: context.colors.bgSurface,
                        textColor: context.colors.txtPrimary,
                        onTap: () =>
                            AppNav.push(context, const AdminSitesScreen())),
                  ],
                ).animate().fadeIn(delay: 800.ms).slideY(),

                const SizedBox(height: 16),

                // Export Data Banner
                InkWell(
                  onTap: () => AppNav.push(context, const ExportHubScreen()),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.green,
                          context.colors.green.withValues(alpha: 0.7)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: context.colors.bord,
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.file_download,
                            color: context.colors.bgSurface, size: 32),
                        const SizedBox(height: 16),
                        Text('CENTRAL EXPORT HUB',
                            style: TextStyle(
                                color: context.colors.bgSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text('Download PDF & Excel ledgers for all staff',
                            style: TextStyle(
                                color: context.colors.bgSurface
                                    .withValues(alpha: 0.8),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 850.ms).slideY(),

                const SizedBox(height: 16),

                // Mark Staff Attendance Banner
                InkWell(
                  onTap: () => _showRoleSelectionPopup(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: context.colors.bord,
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.edit_calendar,
                            color: context.colors.primary, size: 32),
                        const SizedBox(height: 16),
                        const Text('MANUAL ATTENDANCE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                        const SizedBox(height: 4),
                        const Text(
                            'Manually check in/out staff without face recognition',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms).slideY(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRoleSelectionPopup(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: context.colors.bgSurface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Role',
                    style: TextStyle(
                        color: ctx.colors.txtPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Who do you want to mark attendance for?',
                    style: TextStyle(color: ctx.colors.txtSec)),
                const SizedBox(height: 24),
                // Executives excluded per rule
                _buildRoleTile(
                    ctx, 'Office Employee', 'employee', Icons.computer),
                _buildRoleTile(ctx, 'Supervisor', 'supervisor', Icons.badge),
                _buildRoleTile(ctx, 'Guard', 'guard', Icons.security),
              ],
            ),
          );
        });
  }

  Widget _buildRoleTile(
      BuildContext ctx, String title, String role, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: ctx.colors.primary),
      title: Text(title,
          style: TextStyle(
              color: ctx.colors.txtPrimary, fontWeight: FontWeight.bold)),
      trailing: Icon(Icons.chevron_right, color: ctx.colors.txtMuted),
      onTap: () {
        Navigator.pop(ctx);
        AppNav.push(context, AdminManualAttendanceScreen(role: role));
      },
    );
  }

  Widget _buildAttendanceButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: context.colors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.txtPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSquare(
      String title, String value, String subText, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: context.colors.bord,
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.colors.txtPrimary)),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: context.colors.txtSec,
                  height: 1.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: context.colors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: context.colors.txtSec.withValues(alpha: 0.1))),
            child: Text(subText,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: context.colors.txtPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required String title,
      required IconData icon,
      required Color color,
      required Color textColor,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: context.colors.bord,
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildNLDrawer(AppUser user) {
    return Drawer(
      backgroundColor: context.colors.bgElevated,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('HONOS.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildDrawerItem(Icons.dashboard_rounded, 'DASHBOARD', true,
                        () => Navigator.pop(context)),
                    _buildDrawerItem(Icons.security, 'GUARDS', false, () {
                      Navigator.pop(context);
                      AppNav.push(context, const AdminGuardsManagementScreen());
                    }),
                    _buildDrawerItem(Icons.badge, 'SUPERVISORS', false, () {
                      Navigator.pop(context);
                      AppNav.push(context,
                          const ManageSupervisorsScreen(role: 'supervisor'));
                    }),
                    _buildDrawerItem(Icons.bar_chart, 'REPORTS', false, () {
                      Navigator.pop(context);
                      AppNav.push(context, const ReportsScreen());
                    }),
                    _buildDrawerItem(
                        Icons.account_balance_wallet, 'ADVANCES', false, () {
                      Navigator.pop(context);
                      AppNav.push(context, const AdminAdvancesScreen());
                    }),
                    _buildDrawerItem(Icons.location_on, 'TRACKER', false, () {
                      Navigator.pop(context);
                      AppNav.push(context, const SupervisorTrackerScreen());
                    }),
                    _buildDrawerItem(Icons.business, 'MANAGE SITES', false, () {
                      Navigator.pop(context);
                      AppNav.push(context, const AdminSitesScreen());
                    }),
                    _buildDrawerItem(Icons.file_download, 'EXPORT HUB', false,
                        () {
                      Navigator.pop(context);
                      AppNav.push(context, const ExportHubScreen());
                    }),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            _buildDrawerItem(Icons.logout, 'LOGOUT', false,
                () => ref.read(authProvider.notifier).logout()),
            const SizedBox(height: 20),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                AppNav.push(context, const UserProfileScreen());
              },
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: user.photo.length > 200
                          ? Colors.transparent
                          : context.colors.primary,
                      backgroundImage: user.photo.length > 200
                          ? MemoryImage(base64Decode(user.photo))
                          : null,
                      child: user.photo.length <= 200
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          Text('EXECUTIVE',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  letterSpacing: 1)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      IconData icon, String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
            border: isSelected
                ? Border(
                    left: BorderSide(color: context.colors.primary, width: 4))
                : null),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? context.colors.primary
                    : Colors.white.withValues(alpha: 0.5),
                size: 20),
            const SizedBox(width: 16),
            Text(title,
                style: TextStyle(
                    color: isSelected
                        ? context.colors.primary
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
