import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../app_theme.dart';
import '../../models/app_user.dart';
import '../../models/site.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/app_nav.dart';
import '../../widgets/theme_toggle_button.dart';
import '../admin/notifications_screen.dart';
import '../user_profile_screen.dart';
import 'apply_leave_screen.dart';
import 'employee_take_attendance_screen.dart';

class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends ConsumerState<EmployeeDashboardScreen> {
  Future<void> _uploadPhoto(AppUser user) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera, maxWidth: 600);
    if (xfile == null) return;

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Processing photo...'), backgroundColor: context.colors.primary));

    try {
      final bytes = await xfile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');
      final jpg = img.encodeJpg(image, quality: 70);
      final base64Photo = base64Encode(jpg);

      final updatedUser = AppUser(
        id: user.id,
        name: user.name,
        username: user.username,
        role: user.role,
        siteId: user.siteId,
        password: user.password,
        salary: user.salary,
        empId: user.empId,
        phone: user.phone,
        dob: user.dob,
        address: user.address,
        aadharNo: user.aadharNo,
        uanNo: user.uanNo,
        bankName: user.bankName,
        accountNo: user.accountNo,
        ifsc: user.ifsc,
        branch: user.branch,
        photo: base64Photo,
        aadharPhoto: user.aadharPhoto,
        passbookPhoto: user.passbookPhoto,
        joinDate: user.joinDate,
        status: user.status,
      );

      await ref.read(dbProvider).saveUser(updatedUser);
      ref.read(authProvider.notifier).updateUser(updatedUser);
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
          'You must add a profile picture before you can mark attendance.',
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);
    final leavesAsync = ref.watch(leavesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Portal'),
        actions: [
          const ThemeToggleButton(),
          Consumer(
            builder: (context, ref, child) {
              final notificationsAsync = ref.watch(notificationsStreamProvider);
              final unreadCount = notificationsAsync.value?.where((n) => !n.isRead && n.supervisorId == user?.id).length ?? 0;
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
                        decoration: BoxDecoration(color: context.colors.blue, borderRadius: BorderRadius.circular(10)),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 1.seconds),
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
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1B3B60)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                    ),
                  ).animate().fadeIn(duration: 800.ms),
                  ListTile(
                    leading: Icon(Icons.dashboard, color: context.colors.primary),
                    title: Text('Dashboard', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
                    selected: true,
                    selectedTileColor: context.colors.primary.withValues(alpha: 0.1),
                    onTap: () => Navigator.pop(context),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
                  ListTile(
                    leading: Icon(Icons.date_range, color: context.colors.txtSec),
                    title: Text('Apply for Leave', style: TextStyle(color: context.colors.txtSec)),
                    onTap: () {
                      Navigator.pop(context);
                      AppNav.push(context, const ApplyLeaveScreen());
                    },
                  ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
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
                title: Text(user?.name ?? 'Profile', style: TextStyle(color: context.colors.txtSec, fontSize: 14, fontWeight: FontWeight.bold)),
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
                      child: Text('OFFICE EMPLOYEE', style: TextStyle(color: context.colors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  AppNav.push(context, const UserProfileScreen());
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back,', style: TextStyle(color: context.colors.txtMuted, fontSize: 16)),
            Text(user?.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                .animate().fadeIn().slideY(begin: 0.1, end: 0),
            const SizedBox(height: 32),

            // Attendance Action Card
            Builder(
              builder: (context) {
                final missingPhoto = user!.photo.isEmpty || user.photo.length < 200;
                
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [context.colors.bgSurface, context.colors.bgElevated],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.fingerprint, color: context.colors.primary, size: 28),
                          const SizedBox(width: 12),
                          const Text('Today\'s Attendance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 24),
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
                                AppNav.push(context, const EmployeeTakeAttendanceScreen(isCheckOutFlow: false));
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
                                AppNav.push(context, const EmployeeTakeAttendanceScreen(isCheckOutFlow: true));
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Check-Out', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack);
              }
            ),

            const SizedBox(height: 32),

            // Statistics Row
            leavesAsync.when(
              data: (leaves) {
                final myLeaves = leaves.where((l) => l.employeeId == user?.id).toList();
                final approvedLeaves = myLeaves.where((l) => l.status == 'approved').length;
                final pendingLeaves = myLeaves.where((l) => l.status == 'pending').length;

                return Row(
                  children: [
                    Expanded(child: _buildStatCard(context, 'Approved Leaves', approvedLeaves.toString(), Icons.event_available, context.colors.green, delay: 400.ms)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard(context, 'Pending Leaves', pendingLeaves.toString(), Icons.event_note, context.colors.yellow, delay: 500.ms)),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => const SizedBox(),
            ),

            const SizedBox(height: 32),

            // Visual Graph / Progress
            Text('Monthly Overview', style: TextStyle(color: context.colors.txtSec, fontSize: 18, fontWeight: FontWeight.bold))
                .animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.bgSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.colors.primary.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Attendance Progress', style: TextStyle(color: context.colors.txtMuted)),
                      Text('${DateFormat('MMMM').format(DateTime.now())} 2026', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // A beautiful custom progress bar representing the month's days
                  attendanceAsync.when(
                    data: (attn) {
                      // Note: This is an aesthetic mockup of the progress, in a real scenario you'd calculate exact present days this month
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: const LinearProgressIndicator(
                              value: 0.85, // Mock value for aesthetics
                              minHeight: 12,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Present: 22 Days', style: TextStyle(color: context.colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('Absent/Leave: 4 Days', style: TextStyle(color: context.colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, __) => const SizedBox(),
                  )
                ],
              ),
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color, {required Duration delay}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
        ],
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.1, end: 0);
  }
}
