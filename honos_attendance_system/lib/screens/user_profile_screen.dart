import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../app_theme.dart';
import '../../models/app_user.dart';
import '../../models/advance.dart';
import '../../models/attendance.dart';
import '../../models/app_notification.dart';
import '../../services/db_service.dart';
import '../../services/pdf_service.dart';
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profile picture updated!'), backgroundColor: context.colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.red));
    }
  }

  void _requestEditAccess(AppUser user) async {
    if (user.role == 'admin') {
      // Admins can edit themselves directly
      final sites = ref.read(sitesStreamProvider).value ?? [];
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.bgSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => AdminSupervisorFormSheet(
          db: ref.read(dbProvider),
          allSites: sites,
          existing: user,
          role: user.role,
          onSaved: () {},
        ),
      );
      return;
    }

    try {
      final notif = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Edit Access Requested',
        message: '${user.name} (${user.role}) is requesting permission to edit their profile details.',
        type: 'edit_request',
        timestamp: DateTime.now().toIso8601String(),
        supervisorId: user.id,
        guardId: user.id,
      );
      await ref.read(dbProvider).saveNotification(notif);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Edit request sent to Admin!'), backgroundColor: context.colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final advancesAsync = ref.watch(advancesStreamProvider);
    final attendanceAsync = ref.watch(attendanceStreamProvider); 

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_note, color: context.colors.primary),
            tooltip: 'Edit Details',
            onPressed: () => _requestEditAccess(user),
          ),
        ],
      ),
      body: CustomScrollView(
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
                  
                  // Export Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export Monthly Report', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _exportPdf(user, attendanceAsync.value ?? []),
                  ),
                  const SizedBox(height: 24),

                  // Profile Details
                  _buildDetailsCard(user),
                  const SizedBox(height: 24),

                  // Advances
                  advancesAsync.when(
                    data: (advances) => _buildAdvancesCard(user, advances),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, __) => Text('Error loading advances: $e'),
                  ),
                  const SizedBox(height: 24),

                  // Attendance
                  attendanceAsync.when(
                    data: (att) => _buildAttendanceCalendar(user, att),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, __) => Text('Error loading attendance: $e'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exportPdf(AppUser user, List<Attendance> allAttendance) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF Report...')));
    try {
      final monthAttendance = allAttendance.where((a) {
        if (a.guardId != user.id) return false;
        final d = DateTime.tryParse(a.date);
        if (d == null) return false;
        return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
      }).toList();

      final sites = ref.read(sitesStreamProvider).value ?? [];
      final users = ref.read(usersStreamProvider).value ?? [];
      
      final siteMap = {for (var s in sites) s.id: s.name};
      final supMap = {for (var u in users) u.id: u.name};

      await PdfService.generateAndPrintSupervisorReport(
        supervisor: user,
        month: _selectedMonth,
        attendanceRecords: monthAttendance,
        siteNames: siteMap,
        supervisorNames: supMap,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: context.colors.red));
    }
  }

  Widget _buildHeader(AppUser user) {
    return Card(
      color: context.colors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _uploadPhoto(user),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: context.colors.bgElevated,
                    backgroundImage: user.photo.length > 200 ? MemoryImage(base64Decode(user.photo)) : null,
                    child: user.photo.length < 200 ? Icon(Icons.person, size: 50, color: context.colors.txtMuted) : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            if (user.empId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Emp ID: ${user.empId}', style: TextStyle(fontSize: 14, color: context.colors.primary, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(user.role.toUpperCase(), style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 16, color: context.colors.txtSec),
                const SizedBox(width: 4),
                Text(user.phone.isNotEmpty ? user.phone : 'No Phone', style: TextStyle(color: context.colors.txtSec)),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 16, color: context.colors.txtSec),
                const SizedBox(width: 4),
                Text('Joined: ${user.joinDate.split('T').first}', style: TextStyle(color: context.colors.txtSec)),
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
            const Divider(color: Colors.white10, height: 24),
            _row(Icons.badge, 'UAN No.', user.uanNo.isNotEmpty ? user.uanNo : 'Not Provided'),
            
            const SizedBox(height: 24),
            _sectionTitle('Bank Details', Icons.account_balance),
            _row(Icons.account_balance, 'Bank Name', user.bankName),
            const Divider(color: Colors.white10, height: 24),
            _row(Icons.numbers, 'Account No.', user.accountNo),
            const Divider(color: Colors.white10, height: 24),
            _row(Icons.code, 'IFSC Code', user.ifsc),
            
            const SizedBox(height: 24),
            _sectionTitle('Employment', Icons.work),
            _row(Icons.currency_rupee, 'Fixed Salary', '₹${user.salary.toStringAsFixed(0)}'),
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
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 26),
        Expanded(flex: 2, child: Text(label, style: TextStyle(color: context.colors.txtSec))),
        Expanded(flex: 3, child: Text(value.isEmpty ? '--' : value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
      ],
    );
  }

  String _mask(String val) {
    if (val.length < 4) return val;
    return 'XXXX XXXX ${val.substring(val.length - 4)}';
  }

  Widget _buildAdvancesCard(AppUser user, List<Advance> allAdvances) {
    final supAdvances = allAdvances.where((a) => a.userId == user.id && a.userType == user.role).toList();
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
                Text(DateFormat('MMM yyyy').format(_selectedMonth), style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Advances', style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
                    Text('₹${totalAdv.toStringAsFixed(0)}', style: TextStyle(color: context.colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Est. Net Pay', style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
                    Text('₹${netPay.toStringAsFixed(0)}', style: TextStyle(color: context.colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
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
                    Text(DateFormat('dd MMM').format(DateTime.parse(a.date)), style: TextStyle(color: context.colors.txtSec)),
                    Text(a.reason.isNotEmpty ? a.reason : 'Advance', style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
                    Text('₹${a.amount.toStringAsFixed(0)}', style: TextStyle(color: context.colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ))
            ]
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAttendanceCalendar(AppUser user, List<Attendance> allAttendance) {
    final supAttendance = allAttendance.where((a) => a.guardId == user.id).toList();

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
                _sectionTitle('Attendance', Icons.calendar_month),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1))),
                    Text(DateFormat('MMM yyyy').format(_selectedMonth), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1))),
                  ],
                )
              ],
            ),
            const SizedBox(height: 8),
            Text('Attendance marked: ${supAttendance.where((a) => DateTime.parse(a.date).month == _selectedMonth.month && DateTime.parse(a.date).year == _selectedMonth.year).length} days', style: TextStyle(color: context.colors.txtSec)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }
}
