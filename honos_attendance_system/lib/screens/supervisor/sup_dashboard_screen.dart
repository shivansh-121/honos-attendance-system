import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/background_location_service.dart';
import '../../services/app_nav.dart';
import '../../services/permission_service.dart';
import '../../services/local_push_service.dart';
import '../../models/site.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../nl_theme.dart';
import '../../app_theme.dart';
import '../../widgets/theme_toggle_button.dart';
import 'take_attendance_screen.dart';
import 'executive_take_attendance_screen.dart';
import 'guards_list_screen.dart';
import 'reports_screen.dart';
import 'sup_notifications_screen.dart';
import '../user_profile_screen.dart';

class SupervisorDashboardScreen extends ConsumerStatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  ConsumerState<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends ConsumerState<SupervisorDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isOnDuty = false;
  bool _notifiedPhoto = false;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    Future.microtask(() => ref.read(dbProvider).cleanupOldAttendancePhotos());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPhotoStatus());
  }

  void _checkPhotoStatus() {
    final user = ref.read(authProvider);
    if (user != null && (user.photo.isEmpty || user.photo.length < 200)) {
      if (!_notifiedPhoto) {
        LocalPushService.showNotification(title: 'Action Required', body: 'Please add a profile picture to check-in/out.');
        _notifiedPhoto = true;
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
        id: user.id, empId: user.empId, name: user.name, username: user.username, password: user.password,
        role: user.role, siteId: user.siteId, salary: user.salary, phone: user.phone, dob: user.dob,
        address: user.address, aadharNo: user.aadharNo, uanNo: user.uanNo, bankName: user.bankName,
        ifsc: user.ifsc, accountNo: user.accountNo, branch: user.branch, photo: base64Photo,
        aadharPhoto: user.aadharPhoto, passbookPhoto: user.passbookPhoto, joinDate: user.joinDate, status: user.status,
      );

      await ref.read(dbProvider).saveUser(updatedUser);
      ref.read(authProvider.notifier).updateUser(updatedUser);
      _checkPhotoStatus();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profile picture updated!'), backgroundColor: context.colors.green));
    } catch (e) {}
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await isServiceRunning();
    if (mounted) setState(() => _isOnDuty = isRunning);
  }

  Future<void> _toggleDuty() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    if (_isOnDuty) {
      toggleTracking(false, user.id);
      setState(() => _isOnDuty = false);
    } else {
      final hasPerms = await PermissionService.requestSupervisorPermissions();
      if (!hasPerms) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissions required for tracking.'), backgroundColor: Colors.red));
        return;
      }
      toggleTracking(true, user.id);
      setState(() => _isOnDuty = true);
    }
  }

  void _showPhotoPrompt(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgSurface,
        title: Text('Profile Picture Required', style: TextStyle(color: context.colors.txtPrimary)),
        content: Text('You must add a profile picture before you can check-in or check-out.', style: TextStyle(color: context.colors.txtSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: context.colors.bgElevated, ),
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
    if (user.photo.isEmpty || user.photo.length < 200) {
      _showPhotoPrompt(context, user);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: context.colors.bgSurface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.txtSec.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(isCheckOut ? 'Who is checking out?' : 'Who is checking in?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
              const SizedBox(height: 24),
              
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  AppNav.push(context, ExecutiveTakeAttendanceScreen(isCheckOutFlow: isCheckOut));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: context.colors.bgElevated.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(16), color: context.colors.bgSurface),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: context.colors.bgElevated, child: const Icon(Icons.person, color: Colors.white)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Myself', style: TextStyle(color: context.colors.txtPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Record your own site visit', style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
                      ])),
                      Icon(Icons.chevron_right, color: context.colors.txtSec),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  if (user.siteId == null || user.siteId!.isEmpty) return;
                  final sites = ref.read(sitesStreamProvider).value ?? [];
                  final site = sites.firstWhere((s) => s.id == user.siteId, orElse: () => Site(id: '', name: 'Unknown', address: '', lat: 0, lng: 0, radius: 0, supervisorId: user.id));
                  if (site.id.isNotEmpty && mounted) {
                    AppNav.push(context, TakeAttendanceScreen(site: site, isCheckOutFlow: isCheckOut));
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: context.colors.bgElevated.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(16), color: context.colors.bgSurface),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: context.colors.primary, child: Icon(Icons.local_police, color: context.colors.bgElevated)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('A Guard', style: TextStyle(color: context.colors.txtPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Scan a guard\'s face to mark their attendance', style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
                      ])),
                      Icon(Icons.chevron_right, color: context.colors.txtSec),
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
    final attendanceAsync = ref.watch(guardAttendanceProvider(user?.id ?? ''));

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
              }).length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none, color: context.colors.txtPrimary),
                    onPressed: () => AppNav.push(context, const SupNotificationsScreen()),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello ${user.name.split(' ').first}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)).animate().fadeIn().slideX(),
              SizedBox(height: 4),
              Row(
                children: [
                  Text('SUPERVISOR DASHBOARD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.colors.txtSec, letterSpacing: 1)),
                ],
              ).animate().fadeIn(delay: 100.ms),
                  ],
                ),
                // Duty Toggle
                InkWell(
                  onTap: _toggleDuty,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isOnDuty ? context.colors.green.withValues(alpha: 0.2) : context.colors.bgSurface,
                      border: Border.all(color: _isOnDuty ? context.colors.green : context.colors.txtSec.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 14, color: _isOnDuty ? context.colors.green : context.colors.txtSec),
                        SizedBox(width: 6),
                        Text(_isOnDuty ? 'ON DUTY' : 'OFF DUTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isOnDuty ? context.colors.green : context.colors.txtSec)),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
            
            SizedBox(height: 24),



            // Attendance Action
            Row(
              children: [
                Expanded(
                   child: _buildAttendanceButton('Check In', Icons.login, context.colors.green, () => _showAttendanceActionSheet(context, user, false)),
                ),
                SizedBox(width: 12),
                Expanded(
                   child: _buildAttendanceButton('Check Out', Icons.logout, context.colors.red, () => _showAttendanceActionSheet(context, user, true)),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms).slideY(),
            
            SizedBox(height: 24),

            // Timeline Card
            attendanceAsync.when(
              data: (attData) {
                final myAtt = attData.where((a) => a.guardId == user.id).toList();
                return _buildCalendarGrid(myAtt).animate().fadeIn(delay: 350.ms).slideY();
              },
              loading: () => const SizedBox(),
              error: (e, __) => const SizedBox(),
            ),

            const SizedBox(height: 24),

            // Stats Row
            Row(
              children: [
                Expanded(child: _buildStatSquare('Total\nGuards', guardsAsync.value?.where((g) => g.siteId == user.siteId).length.toString() ?? '-', 'My Site', context.colors.bgSurface).animate().fadeIn(delay: 400.ms)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatSquare('Total\nGuards', guardsAsync.value?.length.toString() ?? '-', 'All Sites', context.colors.primary.withValues(alpha: 0.1)).animate().fadeIn(delay: 500.ms)),
              ],
            ),

            const SizedBox(height: 24),
            Text('Operations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.txtPrimary)).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildActionButton(title: 'My Guards', icon: Icons.security, color: context.colors.bgElevated, textColor: Colors.white, onTap: () => AppNav.push(context, const GuardsListScreen())),
                _buildActionButton(title: 'Reports', icon: Icons.bar_chart, color: context.colors.green, textColor: context.colors.bgSurface, onTap: () => AppNav.push(context, const ReportsScreen())),
              ],
            ).animate().fadeIn(delay: 700.ms).slideY(),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: context.colors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
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
            decoration: BoxDecoration(color: context.colors.bgSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.colors.txtSec.withValues(alpha: 0.1))),
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

  Widget _buildNLDrawer(AppUser user) {
    return Drawer(
      backgroundColor: context.colors.bgElevated,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('HONOS.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            const SizedBox(height: 20),
            _buildDrawerItem(Icons.dashboard_rounded, 'DASHBOARD', true, () => Navigator.pop(context)),
            _buildDrawerItem(Icons.security, 'MY GUARDS', false, () {
              Navigator.pop(context);
              AppNav.push(context, const GuardsListScreen());
            }),
            _buildDrawerItem(Icons.bar_chart, 'REPORTS', false, () {
              Navigator.pop(context);
              AppNav.push(context, const ReportsScreen());
            }),

            const Spacer(),
            _buildDrawerItem(Icons.logout, 'LOGOUT', false, () => ref.read(authProvider.notifier).logout()),
            const SizedBox(height: 20),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                AppNav.push(context, const UserProfileScreen());
              },
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: user.photo.length > 200 ? Colors.transparent : context.colors.red,
                      backgroundImage: user.photo.length > 200 ? MemoryImage(base64Decode(user.photo)) : null,
                      child: user.photo.length <= 200 ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('SUPERVISOR', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1)),
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

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(border: isSelected ? Border(left: BorderSide(color: context.colors.primary, width: 4)) : null),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? context.colors.primary : Colors.white.withValues(alpha: 0.5), size: 20),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: isSelected ? context.colors.primary : Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(List<Attendance> attendance) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    
    final startingWeekday = firstDayOfMonth.weekday;
    
    final attMap = <String, Attendance>{};
    for (var a in attendance) {
      if (a.date.isNotEmpty) attMap[a.date] = a;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: context.colors.bord, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.txtPrimary)),
              Text(DateFormat('MMMM yyyy').format(now), style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => 
              SizedBox(width: 32, child: Center(child: Text(d, style: TextStyle(color: context.colors.txtSec, fontSize: 12, fontWeight: FontWeight.bold))))
            ).toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lastDayOfMonth.day + startingWeekday - 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index < startingWeekday - 1) return const SizedBox();
              
              final day = index - (startingWeekday - 1) + 1;
              final dateObj = DateTime(now.year, now.month, day);
              final dateStr = DateFormat('yyyy-MM-dd').format(dateObj);
              
              final isWeekend = dateObj.weekday == 6 || dateObj.weekday == 7;
              final att = attMap[dateStr];
              
              Color cellColor = context.colors.bgBase;
              Color txtColor = context.colors.txtPrimary;
              
              if (att != null) {
                if (att.status.toLowerCase() == 'present') {
                  cellColor = context.colors.green.withValues(alpha: 0.2);
                  txtColor = context.colors.green;
                } else if (att.status.toLowerCase() == 'absent') {
                  cellColor = context.colors.red.withValues(alpha: 0.2);
                  txtColor = context.colors.red;
                }
              } else if (isWeekend) {
                cellColor = context.colors.txtMuted.withValues(alpha: 0.1);
                txtColor = context.colors.txtSec;
              }

              if (dateObj.isAfter(now)) {
                cellColor = Colors.transparent;
                txtColor = context.colors.txtMuted.withValues(alpha: 0.3);
              }
              
              return Container(
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dateObj.day == now.day && dateObj.month == now.month ? context.colors.primary : Colors.transparent, width: 2),
                ),
                child: Center(
                  child: Text('$day', style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildChartLegend(context.colors.green, 'PRESENT'),
              _buildChartLegend(context.colors.red, 'ABSENT'),
              _buildChartLegend(context.colors.txtMuted, 'WEEKEND'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChartLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.colors.txtSec)),
      ],
    );
  }
}
