import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../app_theme.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../models/leave.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/app_nav.dart';
import '../admin/notifications_screen.dart';
import '../user_profile_screen.dart';
import 'apply_leave_screen.dart';
import 'employee_take_attendance_screen.dart';
import '../../nl_theme.dart';
import '../../widgets/theme_toggle_button.dart';

final dateRangeAttendanceProvider =
    StreamProvider.family<List<Attendance>, Map<String, String>>((ref, range) {
  return ref
      .read(dbProvider)
      .attendanceStreamForDateRange(range['start']!, range['end']!);
});

class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends ConsumerState<EmployeeDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _uploadPhoto(AppUser user) async {
    final picker = ImagePicker();
    final xfile =
        await picker.pickImage(source: ImageSource.camera, maxWidth: 600);
    if (xfile == null) return;

    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Processing photo...'),
          backgroundColor: NLTheme.accentGreen));

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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: NLTheme.accentGreen));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);
    final leavesAsync = ref.watch(leavesStreamProvider);

    if (user == null) return const Scaffold();

    final missingPhoto = user.photo.isEmpty || user.photo.length < 200;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final myRecs =
        attendanceAsync.value?.where((a) => a.guardId == user.id).toList() ??
            [];
    myRecs.sort((a, b) {
      final da = DateTime.tryParse(a.markedAt) ?? DateTime(2000);
      final db = DateTime.tryParse(b.markedAt) ?? DateTime(2000);
      return db.compareTo(da);
    });

    final todayRecs = myRecs.where((a) => a.date == today).toList();
    final lastRec = todayRecs.firstOrNull;
    final needsCheckOut = lastRec != null && lastRec.checkOutTime.isEmpty;

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
      body: responsiveBody(
        SingleChildScrollView(
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
                  Text('YOUR DASHBOARD',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.colors.txtSec,
                          letterSpacing: 1)),
                  Icon(Icons.chevron_right,
                      size: 14, color: context.colors.txtSec),
                ],
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 16),

              // Mark Attendance & Apply Leave Buttons (Modern style)
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      title: needsCheckOut ? 'Check Out' : 'Check In',
                      icon: needsCheckOut ? Icons.logout : Icons.login,
                      color: needsCheckOut
                          ? context.colors.red
                          : context.colors.green,
                      textColor: Colors.white,
                      onTap: () {
                        if (missingPhoto) {
                          _uploadPhoto(user);
                        } else {
                          AppNav.push(
                              context,
                              EmployeeTakeAttendanceScreen(
                                  isCheckOutFlow: needsCheckOut));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      title: 'Apply Leave',
                      icon: Icons.event_note,
                      color: context.colors.bgSurface,
                      textColor: context.colors.txtPrimary,
                      onTap: () =>
                          AppNav.push(context, const ApplyLeaveScreen()),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms).slideY(),

              const SizedBox(height: 16),

              // Tasks/Leaves List Card
              leavesAsync.when(
                data: (leaves) => _buildLeavesTasksCard(
                        leaves.where((l) => l.employeeId == user.id).toList())
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideY(),
                loading: () => const SizedBox(),
                error: (e, __) => const SizedBox(),
              ),

              const SizedBox(height: 16),

              // Timeline Card
              attendanceAsync.when(
                data: (_) => _buildTimelineCard(lastRec)
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideY(),
                loading: () => const SizedBox(),
                error: (e, __) => const SizedBox(),
              ),

              const SizedBox(height: 16),

              // Stats Row
              Row(
                children: [
                  Expanded(
                      child: _buildStatSquare(
                              'Total\nSalary',
                              '₹${user.salary}',
                              '+0%',
                              context.colors.bgSurface)
                          .animate()
                          .fadeIn(delay: 700.ms)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatSquare(
                              'Current\nMonth',
                              DateFormat('MMM').format(DateTime.now()),
                              'Active',
                              context.colors.red.withValues(alpha: 0.1))
                          .animate()
                          .fadeIn(delay: 800.ms)),
                ],
              ),

              const SizedBox(height: 16),

              // AI / Personal Data Card

              // Personal data card removed
            ],
          ),
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
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('HONOS.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),
            const SizedBox(height: 20),
            _buildDrawerItem(Icons.dashboard_rounded, 'DASHBOARD', true,
                () => Navigator.pop(context)),
            _buildDrawerItem(Icons.event_note, 'APPLY LEAVE', false, () {
              Navigator.pop(context);
              AppNav.push(context, const ApplyLeaveScreen());
            }),

            const Spacer(),
            _buildDrawerItem(Icons.logout, 'LOGOUT', false,
                () => ref.read(authProvider.notifier).logout()),
            const SizedBox(height: 20),
            // Mini profile at bottom of drawer
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
                  borderRadius: BorderRadius.circular(16),
                ),
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
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          Text('OFFICE EMP',
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
              ? Border(left: BorderSide(color: context.colors.green, width: 4))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? context.colors.green
                    : Colors.white.withValues(alpha: 0.5),
                size: 20),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? context.colors.green
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeavesTasksCard(List<Leave> leaves) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Leave Requests',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colors.txtPrimary)),
              Text('${leaves.length} Total',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.colors.txtPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar aesthetic
          LinearProgressIndicator(
            value: leaves.isEmpty
                ? 1.0
                : leaves.where((l) => l.status == 'approved').length /
                    leaves.length,
            backgroundColor: context.colors.green.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(context.colors.green),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 20),
          if (leaves.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                  child: Text('No leave requests.',
                      style: TextStyle(color: context.colors.txtSec))),
            )
          else
            ...leaves.take(4).map((leave) {
              final isApproved = leave.status == 'approved';
              final isPending = leave.status == 'pending';
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.colors.bgBase,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.event,
                          color: isApproved
                              ? context.colors.green
                              : (isPending
                                  ? context.colors.primary
                                  : context.colors.red),
                          size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(leave.reason.toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: context.colors.txtPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('${leave.fromDate} to ${leave.toDate}',
                              style: TextStyle(
                                  fontSize: 10, color: context.colors.txtSec)),
                        ],
                      ),
                    ),
                    Icon(
                      isApproved
                          ? Icons.check_circle
                          : (isPending ? Icons.pending_outlined : Icons.cancel),
                      color: isApproved
                          ? context.colors.green
                          : (isPending
                              ? context.colors.txtSec
                              : context.colors.red),
                      size: 20,
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(Attendance? todayRecord) {
    String checkInTime = todayRecord != null && todayRecord.time.isNotEmpty
        ? todayRecord.time
        : '--:--';
    String checkOutTime =
        todayRecord != null && todayRecord.checkOutTime.isNotEmpty
            ? todayRecord.checkOutTime
            : '--:--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: context.colors.bord,
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Today\'s Timeline',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.colors.txtPrimary)),
              Text(DateFormat('dd MMM yyyy').format(DateTime.now()),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: context.colors.primary)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(checkInTime,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.colors.txtPrimary)),
                    const SizedBox(height: 40),
                    Text(checkOutTime,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.colors.txtPrimary)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      left: 10,
                      top: 0,
                      bottom: 0,
                      child: Container(
                          width: 2,
                          color: context.colors.primary.withValues(alpha: 0.2)),
                    ),
                    if (checkInTime != '--:--')
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            Container(
                                width: 22,
                                height: 2,
                                color: context.colors.primary),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  color: context.colors.primary,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Text('CHECK IN',
                                  style: TextStyle(
                                      color: context.colors.bgBase,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    if (checkOutTime != '--:--')
                      Positioned(
                        top: 56,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            Container(
                                width: 22,
                                height: 2,
                                color: context.colors.primary),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  color: context.colors.bgBase,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: context.colors.primary)),
                              child: Text('CHECK OUT',
                                  style: TextStyle(
                                      color: context.colors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 90),
                  ],
                ),
              )
            ],
          )
        ],
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
                  color: context.colors.txtSec.withValues(alpha: 0.1)),
            ),
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
}
