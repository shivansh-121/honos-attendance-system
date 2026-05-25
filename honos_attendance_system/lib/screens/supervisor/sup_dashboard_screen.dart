import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
import '../../app_theme.dart';
import 'take_attendance_screen.dart';
import 'executive_take_attendance_screen.dart';
import 'guards_list_screen.dart';
import 'reports_screen.dart';
import 'sup_notifications_screen.dart';
import '../user_profile_screen.dart';
import '../../widgets/theme_toggle_button.dart';
class SupervisorDashboardScreen extends ConsumerStatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  ConsumerState<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState
    extends ConsumerState<SupervisorDashboardScreen> {
  bool _isOnDuty = false;
  bool _notifiedPhoto = false;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPhotoStatus();
    });
  }

  void _checkPhotoStatus() {
    final user = ref.read(authProvider);
    if (user != null && (user.role == 'executive' || user.role == 'supervisor')) {
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

  Future<void> _checkServiceStatus() async {
    final isRunning = await isServiceRunning();
    if (mounted) {
      setState(() => _isOnDuty = isRunning);
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
                  if (user.role == 'executive') {
                    AppNav.push(context, ExecutiveTakeAttendanceScreen(isCheckOutFlow: isCheckOut));
                  } else {
                    setState(() => _isOnDuty = !isCheckOut);
                    _handleDutyToggle(!isCheckOut, user);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isCheckOut ? 'Duty Ended' : 'Duty Started'), backgroundColor: context.colors.green));
                  }
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
                          Text(user.role == 'executive' ? 'Record your own site visit' : 'Toggle your Duty Status', style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
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
                  final sites = ref.read(sitesStreamProvider).value ?? [];
                  final pulseHospital = sites.firstWhere(
                      (s) => s.id == user.siteId,
                      orElse: () => const Site(id: 'err', name: 'No Site Found', address: '', lat: 0, lng: 0, radius: 0, supervisorId: ''));
                  AppNav.push(context, TakeAttendanceScreen(site: pulseHospital, isCheckOutFlow: isCheckOut));
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
    final sitesAsync = ref.watch(sitesStreamProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);

    final bool missingPhoto = user != null && (user.photo.isEmpty || user.photo.length < 200);

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
          const ThemeToggleButton(),
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
                    icon: Icon(Icons.notifications_outlined, color: context.colors.primary),
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
                          color: context.colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: context.colors.red.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)
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
            icon: Icon(Icons.logout, color: context.colors.primary),
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
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.05),
                    border: Border(
                        bottom: BorderSide(
                            color: context.colors.primary.withValues(alpha: 0.1))),
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
              leading: Icon(Icons.dashboard, color: context.colors.primary),
              title: Text('Dashboard',
                  style: TextStyle(
                      color: context.colors.primary, fontWeight: FontWeight.bold)),
              selected: true,
              selectedTileColor: context.colors.primary.withValues(alpha: 0.1),
              onTap: () => Navigator.pop(context),
            )
                .animate()
                .fadeIn(delay: 200.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
            ListTile(
              leading: Icon(Icons.security, color: context.colors.txtSec),
              title: Text('My Guards',
                  style: TextStyle(color: context.colors.txtSec)),
              onTap: () {
                Navigator.pop(context);
                AppNav.push(context, const GuardsListScreen());
              },
            )
                .animate()
                .fadeIn(delay: 350.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
            ListTile(
              leading: Icon(Icons.history, color: context.colors.txtSec),
              title: Text('Reports',
                  style: TextStyle(color: context.colors.txtSec)),
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
                      child: Text(user?.role.toUpperCase() ?? 'SUPERVISOR', style: TextStyle(color: context.colors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
                        style: TextStyle(
                            color: context.colors.txtSec, fontSize: 14));
                  },
                  loading: () => Text('Site: Loading...',
                      style: TextStyle(color: context.colors.txtSec, fontSize: 14)),
                  error: (_, __) => Text('Site: Error loading',
                      style: TextStyle(color: context.colors.txtSec, fontSize: 14)),
                )
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 24),
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
                    onPressed: missingPhoto ? () => _showPhotoPrompt(context, user!) : () {
                      _showAttendanceActionSheet(context, user!, false);
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Check-In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: missingPhoto ? Colors.grey.shade800 : context.colors.green,
                      foregroundColor: missingPhoto ? Colors.grey.shade500 : Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .shimmer(duration: 2000.ms, color: Colors.white.withValues(alpha: 0.2))
                   .scaleXY(begin: 1.0, end: 1.02, duration: 1000.ms),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: missingPhoto ? () => _showPhotoPrompt(context, user!) : () {
                      _showAttendanceActionSheet(context, user!, true);
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Check-Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: missingPhoto ? Colors.grey.shade800 : context.colors.red,
                      foregroundColor: missingPhoto ? Colors.grey.shade500 : Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms).scale(),
            const SizedBox(height: 24),
            Card(
              color: _isOnDuty ? context.colors.green.withValues(alpha: 0.08) : null,
              shape: _isOnDuty
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: context.colors.green, width: 1.5),
                    )
                  : null,
              child: SwitchListTile(
                value: _isOnDuty,
                activeThumbColor: context.colors.green,
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
                    color: _isOnDuty ? context.colors.green : null,
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
                                    context.colors.primary,
                                    delay: 800.ms)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildStatCard(
                                    context,
                                    'Present',
                                    presentCount.toString(),
                                    Icons.check_circle_outline,
                                    context.colors.green,
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
                                    context.colors.red,
                                    delay: 1000.ms)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildStatCard(
                                    context,
                                    'Duty Status',
                                    _isOnDuty ? 'ACTIVE' : 'INACTIVE',
                                    Icons.radar_rounded,
                                    _isOnDuty
                                        ? context.colors.green
                                        : context.colors.txtMuted,
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
          SnackBar(
              content: const Text('Permissions required for tracking.'),
              backgroundColor: context.colors.red),
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
          backgroundColor: val ? context.colors.green : null,
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
                    context, 'Total', '...', Icons.people, context.colors.primary)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard(
                    context, 'Present', '...', Icons.check, context.colors.green)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    context, 'Absent', '...', Icons.cancel, context.colors.red)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard(context, 'Duty Status', '...',
                    Icons.radar_rounded, context.colors.txtMuted)),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorStats(BuildContext context) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading stats',
                style: TextStyle(color: context.colors.red))));
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
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.colors.txtSec)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.1, end: 0);
  }
}
