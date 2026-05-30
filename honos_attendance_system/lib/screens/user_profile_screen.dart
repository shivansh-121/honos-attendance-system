import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

import '../../app_theme.dart';
import '../../models/app_user.dart';
import '../../models/advance.dart';
import '../../models/attendance.dart';
import '../../models/app_notification.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import 'admin/admin_supervisor_form_sheet.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  DateTime _selectedMonth = DateTime.now();

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile picture updated!'),
          backgroundColor: context.colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: context.colors.red));
    }
  }

  void _requestEditAccess(AppUser user) async {
    if (user.role == 'admin' || user.isEditableBySupervisor == true) {
      // Admins and approved users can edit themselves directly
      final sites = ref.read(sitesStreamProvider).value ?? [];
      final result = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.bgSurface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => AdminSupervisorFormSheet(
          db: ref.read(dbProvider),
          allSites: sites,
          existing: user,
          role: user.role,
          onSaved: () {},
        ),
      );

      // Revoke edit access once the sheet is closed (whether saved or cancelled)
      if (user.role != 'admin' && user.isEditableBySupervisor) {
        if (user.role == 'guard') {
          await ref
              .read(dbProvider)
              .updateGuardField(user.id, {'isEditableBySupervisor': false});
        } else {
          await ref
              .read(dbProvider)
              .updateUserField(user.id, {'isEditableBySupervisor': false});
        }

        if (result != null && result.isNotEmpty) {
          final notif = AppNotification(
            id: const Uuid().v4(),
            type: 'profile_updated',
            title: '${user.name} Profile Updated',
            message:
                '${user.name} (${user.role}) updated their profile:\n\n${result.join('\n')}',
            supervisorId: 'admin',
            guardId: user.id,
            timestamp: DateTime.now().toIso8601String(),
          );
          await ref.read(dbProvider).saveNotification(notif);
        }
      }
      return;
    }

    try {
      final notif = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Edit Access Requested',
        message:
            '${user.name} (${user.role}) is requesting permission to edit their profile details.',
        type: 'edit_request',
        timestamp: DateTime.now().toIso8601String(),
        supervisorId: 'admin',
        guardId: user.id,
      );
      await ref.read(dbProvider).saveNotification(notif);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Edit request sent to Admin!'),
            backgroundColor: context.colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: context.colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localUser = ref.watch(authProvider);
    if (localUser == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final usersAsync = ref.watch(usersStreamProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);

    AppUser user = localUser;

    final foundGuard =
        guardsAsync.value?.where((g) => g.id == localUser.id).firstOrNull;
    if (foundGuard != null) {
      user = AppUser(
        id: foundGuard.id,
        name: foundGuard.name,
        username: foundGuard.phone,
        password: null,
        role: 'guard',
        siteId: foundGuard.siteId,
        salary: foundGuard.salary,
        empId: foundGuard.empId,
        phone: foundGuard.phone,
        dob: foundGuard.dob,
        address: foundGuard.address,
        aadharNo: foundGuard.aadharNo,
        aadharPhoto: foundGuard.aadharPhoto,
        uanNo: foundGuard.uanNo,
        bankName: foundGuard.bankName,
        accountNo: foundGuard.accountNo,
        ifsc: foundGuard.ifsc,
        branch: foundGuard.branch,
        passbookPhoto: foundGuard.passbookPhoto,
        photo: foundGuard.photo,
        joinDate: foundGuard.joinDate,
        status: foundGuard.status,
        isEditableBySupervisor: foundGuard.isEditableBySupervisor,
      );
    } else {
      user = usersAsync.value?.where((u) => u.id == localUser.id).firstOrNull ??
          localUser;
    }

    final advancesAsync = ref.watch(userAdvancesProvider(user.id));
    final attendanceAsync = ref.watch(guardAttendanceProvider(user.id));

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_note, color: context.colors.primary),
            tooltip: 'Edit Details',
            onPressed: () => _requestEditAccess(user),
          ),
        ],
      ),
      body: responsiveBody(
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    _buildHeader(user),
                    const SizedBox(height: 20),

                    // Profile Details
                    if (user.role != 'admin') ...[
                      _buildDetailsCard(user),
                      const SizedBox(height: 24),
                    ],

                    // Advances & Payroll
                    if (user.role != 'admin' &&
                        user.role != 'office_employee') ...[
                      advancesAsync.when(
                        data: (adv) => _buildAdvancesCard(user, adv),
                        loading: () => const Center(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator())),
                        error: (e, __) => Text('Error loading advances: $e'),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Attendance
                    if (user.role != 'admin') ...[
                      attendanceAsync.when(
                        data: (att) => _buildAttendanceCalendar(user, att),
                        loading: () => const Center(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator())),
                        error: (e, __) => Text('Error loading attendance: $e'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppUser user) {
    return Card(
      color: context.colors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (user.role == 'admin')
              Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              )
            else
              GestureDetector(
                onTap: () => _uploadPhoto(user),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: context.colors.bgElevated,
                      backgroundImage: user.photo.length > 200
                          ? MemoryImage(base64Decode(user.photo))
                          : null,
                      child: user.photo.length < 200
                          ? Icon(Icons.person,
                              size: 50, color: context.colors.txtMuted)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_alt,
                          size: 16, color: context.colors.bgBase),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(user.name,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.colors.txtPrimary)),
            if (user.empId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Emp ID: ${user.empId}',
                  style: TextStyle(
                      fontSize: 14,
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(user.role.toUpperCase(),
                  style: TextStyle(
                      color: context.colors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 16, color: context.colors.txtSec),
                const SizedBox(width: 4),
                Text(user.phone.isNotEmpty ? user.phone : 'No Phone',
                    style: TextStyle(color: context.colors.txtSec)),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today,
                    size: 16, color: context.colors.txtSec),
                const SizedBox(width: 4),
                Text('Joined: ${user.joinDate.split('T').first}',
                    style: TextStyle(color: context.colors.txtSec)),
              ],
            )
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildDetailsCard(AppUser user) {
    return Card(
      color: context.colors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Identity', Icons.credit_card),
            _row(Icons.credit_card, 'Aadhaar No.', _mask(user.aadharNo)),
            Divider(
                color: context.colors.txtPrimary.withValues(alpha: 0.1),
                height: 24),
            _row(Icons.badge, 'UAN No.',
                user.uanNo.isNotEmpty ? user.uanNo : 'Not Provided'),
            const SizedBox(height: 24),
            _sectionTitle('Bank Details', Icons.account_balance),
            _row(Icons.account_balance, 'Bank Name', user.bankName),
            Divider(
                color: context.colors.txtPrimary.withValues(alpha: 0.1),
                height: 24),
            _row(Icons.numbers, 'Account No.', user.accountNo),
            Divider(
                color: context.colors.txtPrimary.withValues(alpha: 0.1),
                height: 24),
            _row(Icons.code, 'IFSC Code', user.ifsc),
            if (user.role != 'admin') ...[
              const SizedBox(height: 24),
              _sectionTitle('Employment', Icons.work),
              _row(Icons.currency_rupee, 'Fixed Salary',
                  '₹${user.salary.toStringAsFixed(0)}'),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: context.colors.txtPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 26),
        Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: context.colors.txtSec))),
        Expanded(
            flex: 3,
            child: Text(value.isEmpty ? '--' : value,
                style: TextStyle(
                    color: context.colors.txtPrimary,
                    fontWeight: FontWeight.w500))),
      ],
    );
  }

  String _mask(String val) {
    if (val.length < 4) return val;
    return 'XXXX XXXX ${val.substring(val.length - 4)}';
  }

  Widget _buildAdvancesCard(AppUser user, List<Advance> allAdvances) {
    final supAdvances = allAdvances
        .where((a) => a.userId == user.id && a.userType == user.role)
        .toList();
    final monthAdvances = supAdvances.where((a) {
      final d = DateTime.tryParse(a.date);
      if (d == null) return false;
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }).toList();

    final totalAdv = monthAdvances.fold<double>(0, (sum, a) => sum + a.amount);
    final netPay = user.salary - totalAdv;

    return Card(
      color: context.colors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Advances & Payroll', Icons.money),
                Text(DateFormat('MMM yyyy').format(_selectedMonth),
                    style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: context.colors.bgElevated,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Advances',
                            style: TextStyle(
                                color: context.colors.txtSec, fontSize: 12)),
                        Text('₹${totalAdv.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: context.colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Est. Net Pay',
                        style: TextStyle(
                            color: context.colors.txtSec, fontSize: 12)),
                    Text('₹${netPay.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: context.colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ]),
                ],
              ),
            ),
            if (monthAdvances.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...monthAdvances.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            DateFormat('dd MMM').format(DateTime.parse(a.date)),
                            style: TextStyle(color: context.colors.txtSec)),
                        Text(a.reason.isNotEmpty ? a.reason : 'Advance',
                            style: TextStyle(
                                color: context.colors.txtSec, fontSize: 12)),
                        Text('₹${a.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: context.colors.red,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ))
            ]
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAttendanceCalendar(
      AppUser user, List<Attendance> allAttendance) {
    final supAttendance =
        allAttendance.where((a) => a.guardId == user.id).toList();

    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final now = DateTime.now();

    return Column(
      children: [
        Card(
          color: context.colors.bgSurface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle('Attendance', Icons.calendar_month),
                    Row(
                      children: [
                        IconButton(
                            icon: Icon(Icons.chevron_left,
                                color: context.colors.txtPrimary),
                            onPressed: () => setState(() => _selectedMonth =
                                DateTime(_selectedMonth.year,
                                    _selectedMonth.month - 1))),
                        Text(DateFormat('MMM yyyy').format(_selectedMonth),
                            style: TextStyle(
                                color: context.colors.txtPrimary,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: Icon(Icons.chevron_right,
                                color: context.colors.txtPrimary),
                            onPressed: () => setState(() => _selectedMonth =
                                DateTime(_selectedMonth.year,
                                    _selectedMonth.month + 1))),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 36,
                  ),
                  itemCount: daysInMonth,
                  itemBuilder: (ctx, index) {
                    final day = index + 1;
                    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime(
                        _selectedMonth.year, _selectedMonth.month, day));

                    final attRecord =
                        supAttendance.where((a) => a.date == dateStr).toList();
                    Color blockColor = context.colors.bgElevated;

                    if (attRecord.isNotEmpty) {
                      final isPresent = attRecord
                          .any((a) => a.status.toLowerCase() == 'present');
                      blockColor =
                          isPresent ? context.colors.green : context.colors.red;
                    } else {
                      final checkDate = DateTime(
                          _selectedMonth.year, _selectedMonth.month, day);
                      if (checkDate
                          .isBefore(DateTime(now.year, now.month, now.day))) {
                        blockColor = context.colors.red;
                      }
                    }

                    return Tooltip(
                      message:
                          'Day $day: ${attRecord.isNotEmpty ? attRecord.last.time : 'No Record'}',
                      child: Container(
                        decoration: BoxDecoration(
                          color: blockColor,
                          borderRadius: BorderRadius.circular(6),
                          border: _selectedMonth.year == now.year &&
                                  _selectedMonth.month == now.month &&
                                  day == now.day
                              ? Border.all(
                                  color: context.colors.txtPrimary, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: blockColor == context.colors.bgElevated
                                  ? context.colors.txtMuted
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(context.colors.green, 'Present'),
                    const SizedBox(width: 16),
                    _buildLegendItem(context.colors.red, 'Absent'),
                    const SizedBox(width: 16),
                    _buildLegendItem(context.colors.bgElevated, 'Future'),
                  ],
                )
              ],
            ),
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 16),
        _buildWorkingHoursSection(supAttendance),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 11, color: context.colors.txtSec)),
      ],
    );
  }

  Widget _buildWorkingHoursSection(List<Attendance> attendance) {
    final completedShifts = attendance
        .where((a) => a.time.isNotEmpty && a.checkOutTime.isNotEmpty)
        .toList();
    completedShifts.sort((a, b) => b.date.compareTo(a.date));
    final recentShifts = completedShifts.take(14).toList();

    if (recentShifts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('Recent Working Hours',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.colors.txtPrimary)),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentShifts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final shift = recentShifts[i];

            int durationMinutes = 0;
            try {
              final inParts = shift.time.split(':');
              final outParts = shift.checkOutTime.split(':');

              final inTime = DateTime(
                  2000, 1, 1, int.parse(inParts[0]), int.parse(inParts[1]));
              var outTime = DateTime(
                  2000, 1, 1, int.parse(outParts[0]), int.parse(outParts[1]));

              if (outTime.isBefore(inTime)) {
                outTime = outTime.add(const Duration(days: 1));
              }

              durationMinutes = outTime.difference(inTime).inMinutes;
            } catch (e) {
              // Ignore parse errors
            }

            final hours = durationMinutes ~/ 60;
            final mins = durationMinutes % 60;
            final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

            final date = DateTime.tryParse(shift.date);
            final dateStr = date != null
                ? DateFormat('MMM dd, yyyy').format(date)
                : shift.date;

            return Card(
              color: context.colors.bgSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: context.colors.bord.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.access_time,
                          color: context.colors.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateStr,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.txtPrimary,
                                  fontSize: 14)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.login,
                                  size: 12, color: context.colors.txtMuted),
                              const SizedBox(width: 4),
                              Text(shift.time,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.txtSec)),
                              const SizedBox(width: 12),
                              Icon(Icons.logout,
                                  size: 12, color: context.colors.txtMuted),
                              const SizedBox(width: 4),
                              Text(shift.checkOutTime,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.txtSec)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        durationStr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }
}
