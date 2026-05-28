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
import '../../nl_theme.dart';
import '../../app_theme.dart';
import '../../widgets/theme_toggle_button.dart';
import 'supervisor_tracker_screen.dart';
import 'manage_supervisors_screen.dart';
import 'admin_sites_screen.dart';
import '../supervisor/reports_screen.dart';
import 'admin_leaves_screen.dart';
import 'admin_guards_management_screen.dart';
import 'admin_advances_screen.dart';
import 'notifications_screen.dart';
import 'admin_manual_attendance_screen.dart';
import 'export_hub_screen.dart';
import '../user_profile_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dbProvider).cleanupOldAttendancePhotos());
  }



  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);
    final leavesAsync = ref.watch(leavesStreamProvider);

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
              final unreadCount = notificationsAsync.value?.where((n) => !n.isRead).length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none, color: context.colors.txtPrimary),
                    onPressed: () => AppNav.push(context, const NotificationsScreen()),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 1.seconds),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildNLDrawer(user),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text('Hello ${user.name.split(' ').first}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)).animate().fadeIn().slideX(),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('ADMIN DASHBOARD', style: TextStyle(fontSize: 13, color: context.colors.txtSec).copyWith(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ).animate().fadeIn(delay: 100.ms),
            
            const SizedBox(height: 24),


            
            // Stats Row
            Row(
              children: [
                Expanded(child: _buildStatSquare('Total\nGuards', guardsAsync.value?.length.toString() ?? '-', '+Active', context.colors.bgSurface).animate().fadeIn(delay: 300.ms)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatSquare('Pending\nLeaves', leavesAsync.value?.where((l) => l.status == 'pending').length.toString() ?? '-', 'Review', context.colors.red.withValues(alpha: 0.1)).animate().fadeIn(delay: 400.ms)),
              ],
            ),
            const SizedBox(height: 24),
            Text('Manage Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.txtPrimary)).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 16),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildActionButton(title: 'Guards', icon: Icons.security, color: context.colors.bgElevated, textColor: Colors.white, onTap: () => AppNav.push(context, const AdminGuardsManagementScreen())),
                _buildActionButton(title: 'Supervisors', icon: Icons.badge, color: context.colors.bgSurface, textColor: context.colors.txtPrimary, onTap: () => AppNav.push(context, const ManageSupervisorsScreen(role: 'supervisor'))),
                _buildActionButton(title: 'Executives', icon: Icons.work, color: context.colors.bgSurface, textColor: context.colors.txtPrimary, onTap: () => AppNav.push(context, const ManageSupervisorsScreen(role: 'executive'))),
                _buildActionButton(title: 'Employees', icon: Icons.computer, color: context.colors.bgSurface, textColor: context.colors.txtPrimary, onTap: () => AppNav.push(context, const ManageSupervisorsScreen(role: 'employee'))),
              ],
            ).animate().fadeIn(delay: 600.ms).slideY(),

            const SizedBox(height: 24),
            Text('Operations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.txtPrimary)).animate().fadeIn(delay: 700.ms),
            const SizedBox(height: 16),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildActionButton(title: 'Reports', icon: Icons.bar_chart, color: context.colors.green, textColor: context.colors.bgSurface, onTap: () => AppNav.push(context, const ReportsScreen())),
                _buildActionButton(title: 'Leave Approvals', icon: Icons.event_available, color: context.colors.txtPrimary, textColor: context.colors.bgSurface, onTap: () => AppNav.push(context, const AdminLeavesScreen())),
                _buildActionButton(title: 'Advances', icon: Icons.account_balance_wallet, color: context.colors.bgSurface, textColor: context.colors.txtPrimary, onTap: () => AppNav.push(context, const AdminAdvancesScreen())),
                _buildActionButton(title: 'Manage Sites', icon: Icons.business, color: context.colors.bgSurface, textColor: context.colors.txtPrimary, onTap: () => AppNav.push(context, const AdminSitesScreen())),
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
                    colors: [context.colors.green, context.colors.green.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: context.colors.bord, blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.file_download, color: context.colors.bgSurface, size: 32),
                    const SizedBox(height: 16),
                    Text('CENTRAL EXPORT HUB', style: TextStyle(color: context.colors.bgSurface, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('Download PDF & Excel ledgers for all staff', style: TextStyle(color: context.colors.bgSurface.withValues(alpha: 0.8), fontSize: 12)),
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
                  boxShadow: [BoxShadow(color: context.colors.bord, blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit_calendar, color: context.colors.primary, size: 32),
                    const SizedBox(height: 16),
                    Text('MANUAL ATTENDANCE', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('Manually check in/out staff without face recognition', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 900.ms).slideY(),
            
          ],
        ),
      ),
    );
  }



  Widget _buildStatSquare(String title, String value, String subText, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: context.colors.bord, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.colors.txtSec, height: 1.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.txtSec.withValues(alpha: 0.1)),
            ),
            child: Text(subText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String title, required IconData icon, required Color color, required Color textColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: context.colors.bord, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showRoleSelectionPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Role', style: TextStyle(color: ctx.colors.txtPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Who do you want to mark attendance for?', style: TextStyle(color: ctx.colors.txtSec)),
              const SizedBox(height: 24),
              _buildRoleTile(ctx, 'Executive', 'executive', Icons.work),
              _buildRoleTile(ctx, 'Office Employee', 'employee', Icons.computer),
              _buildRoleTile(ctx, 'Supervisor', 'supervisor', Icons.badge),
              _buildRoleTile(ctx, 'Guard', 'guard', Icons.security),
            ],
          ),
        );
      }
    );
  }

  Widget _buildRoleTile(BuildContext ctx, String title, String role, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: ctx.colors.primary),
      title: Text(title, style: TextStyle(color: ctx.colors.txtPrimary, fontWeight: FontWeight.bold)),
      trailing: Icon(Icons.chevron_right, color: ctx.colors.txtMuted),
      onTap: () {
        Navigator.pop(ctx);
        AppNav.push(context, AdminManualAttendanceScreen(role: role));
      },
    );
  }

  Widget _buildNLDrawer(AppUser user) {
    return Drawer(
      backgroundColor: context.colors.bgElevated,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text('HONOS.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Text('Admin Panel', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, letterSpacing: 1)),
            ),

            // Scrollable menu
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', true, () => Navigator.pop(context)),

                  _buildSectionLabel('MANAGE STAFF'),
                  _buildDrawerItem(Icons.security, 'Guards', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const AdminGuardsManagementScreen());
                  }),
                  _buildDrawerItem(Icons.badge, 'Supervisors', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const ManageSupervisorsScreen(role: 'supervisor'));
                  }),
                  _buildDrawerItem(Icons.work, 'Executives', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const ManageSupervisorsScreen(role: 'executive'));
                  }),
                  _buildDrawerItem(Icons.computer, 'Employees', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const ManageSupervisorsScreen(role: 'employee'));
                  }),

                  _buildSectionLabel('OPERATIONS'),
                  _buildDrawerItem(Icons.bar_chart, 'Reports', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const ReportsScreen());
                  }),
                  _buildDrawerItem(Icons.event_available, 'Leave Approvals', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const AdminLeavesScreen());
                  }),
                  _buildDrawerItem(Icons.account_balance_wallet, 'Advances', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const AdminAdvancesScreen());
                  }),
                  _buildDrawerItem(Icons.business, 'Manage Sites', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const AdminSitesScreen());
                  }),
                  _buildDrawerItem(Icons.location_on, 'Tracker', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const SupervisorTrackerScreen());
                  }),
                  _buildDrawerItem(Icons.file_download, 'Export Hub', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const ExportHubScreen());
                  }),
                  _buildDrawerItem(Icons.edit_calendar, 'Manual Attendance', false, () {
                    Navigator.pop(context);
                    _showRoleSelectionPopup(context);
                  }),

                  _buildSectionLabel('ACCOUNT'),
                  _buildDrawerItem(Icons.notifications_none, 'Notifications', false, () {
                    Navigator.pop(context);
                    AppNav.push(context, const NotificationsScreen());
                  }),
                  _buildDrawerItem(Icons.logout, 'Logout', false, () {
                    ref.read(authProvider.notifier).logout();
                  }),
                ],
              ),
            ),

            // Profile footer
            InkWell(
              onTap: () {
                Navigator.pop(context);
                AppNav.push(context, const UserProfileScreen());
              },
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                          Text('ADMIN  •  View Profile', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
      child: Text(label, style: TextStyle(color: context.colors.txtPrimary.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: context.colors.green.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? context.colors.green : Colors.white.withValues(alpha: 0.55), size: 20),
            const SizedBox(width: 14),
            Text(title, style: TextStyle(
              color: isSelected ? context.colors.green : Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
              letterSpacing: 0.3,
            )),
          ],
        ),
      ),
    );
  }
}
