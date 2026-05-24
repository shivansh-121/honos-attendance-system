import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../models/app_user.dart';
import '../../models/advance.dart';
import '../../models/attendance.dart';
import '../../services/db_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/base64_image_widget.dart';

class SupervisorProfileScreen extends ConsumerStatefulWidget {
  final AppUser supervisor;

  const SupervisorProfileScreen({super.key, required this.supervisor});

  @override
  ConsumerState<SupervisorProfileScreen> createState() => _SupervisorProfileScreenState();
}

class _SupervisorProfileScreenState extends ConsumerState<SupervisorProfileScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final s = widget.supervisor;
    final advancesAsync = ref.watch(advancesStreamProvider);
    final attendanceAsync = ref.watch(attendanceStreamProvider); // Assumes we have a generic or supervisor attendance stream

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Supervisor Profile', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  _buildHeader(s),
                  const SizedBox(height: 20),
                  
                  // Export Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export Monthly Report', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _exportPdf(s, attendanceAsync.value ?? []),
                  ),
                  const SizedBox(height: 24),

                  // Profile Details
                  _buildDetailsCard(s),
                  const SizedBox(height: 24),

                  // Advances
                  advancesAsync.when(
                    data: (advances) => _buildAdvancesCard(s, advances),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, __) => Text('Error loading advances: $e'),
                  ),
                  const SizedBox(height: 24),

                  // Attendance
                  attendanceAsync.when(
                    data: (att) => _buildAttendanceCalendar(att),
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

  void _exportPdf(AppUser sup, List<Attendance> allAttendance) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF Report...')));
    try {
      final monthAttendance = allAttendance.where((a) {
        // Supervisor marks their own attendance, so guardId == sup.id or supervisorId == sup.id?
        // Wait! Supervisors use TakeAttendanceScreen with themselves? No, we will make them use TakeAttendanceScreen, which sets guardId. 
        // For self-attendance, guardId = sup.id. 
        if (a.guardId != sup.id) return false;
        final d = DateTime.tryParse(a.date);
        if (d == null) return false;
        return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
      }).toList();

      final sites = ref.read(sitesStreamProvider).value ?? [];
      final users = ref.read(usersStreamProvider).value ?? [];
      
      final siteMap = {for (var s in sites) s.id: s.name};
      final supMap = {for (var u in users) u.id: u.name};

      await PdfService.generateAndPrintSupervisorReport(
        supervisor: sup,
        month: _selectedMonth,
        attendanceRecords: monthAttendance,
        siteNames: siteMap,
        supervisorNames: supMap,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red));
    }
  }

  Widget _buildHeader(AppUser s) {
    return Card(
      color: AppTheme.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.bgElevated,
              backgroundImage: s.photo.length > 200 ? MemoryImage(base64Decode(s.photo)) : null,
              child: s.photo.length < 200 ? const Icon(Icons.person, size: 50, color: AppTheme.txtMuted) : null,
            ),
            const SizedBox(height: 16),
            Text(s.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(s.role.toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone, size: 16, color: AppTheme.txtSec),
                const SizedBox(width: 4),
                Text(s.phone.isNotEmpty ? s.phone : 'No Phone', style: const TextStyle(color: AppTheme.txtSec)),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today, size: 16, color: AppTheme.txtSec),
                const SizedBox(width: 4),
                Text('Joined: ${s.joinDate.split('T').first}', style: const TextStyle(color: AppTheme.txtSec)),
              ],
            )
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildDetailsCard(AppUser s) {
    return Card(
      color: AppTheme.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Identity', Icons.credit_card),
            _row(Icons.credit_card, 'Aadhaar No.', _mask(s.aadharNo)),
            const Divider(color: Colors.white10, height: 24),
            _row(Icons.badge, 'UAN No.', s.uanNo.isNotEmpty ? s.uanNo : 'Not Provided'),
            
            const SizedBox(height: 24),
            _sectionTitle('Bank Details', Icons.account_balance),
            _row(Icons.account_balance, 'Bank Name', s.bankName),
            const Divider(color: Colors.white10, height: 24),
            _row(Icons.numbers, 'Account No.', s.accountNo),
            const Divider(color: Colors.white10, height: 24),
            _row(Icons.code, 'IFSC Code', s.ifsc),
            
            const SizedBox(height: 24),
            _sectionTitle('Employment', Icons.work),
            _row(Icons.currency_rupee, 'Fixed Salary', '₹${s.salary.toStringAsFixed(0)}'),
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
          Icon(icon, color: AppTheme.primary, size: 18),
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
        Expanded(flex: 2, child: Text(label, style: const TextStyle(color: AppTheme.txtSec))),
        Expanded(flex: 3, child: Text(value.isEmpty ? '--' : value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
      ],
    );
  }

  String _mask(String val) {
    if (val.length < 4) return val;
    return 'XXXX XXXX ${val.substring(val.length - 4)}';
  }

  Widget _buildAdvancesCard(AppUser s, List<Advance> allAdvances) {
    final supAdvances = allAdvances.where((a) => a.userId == s.id && a.userType == 'supervisor').toList();
    final monthAdvances = supAdvances.where((a) {
      final d = DateTime.tryParse(a.date);
      if (d == null) return false;
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }).toList();
    
    final totalAdv = monthAdvances.fold<double>(0, (sum, a) => sum + a.amount);
    final netPay = s.salary - totalAdv;

    return Card(
      color: AppTheme.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Advances & Payroll', Icons.money),
                Text(DateFormat('MMM yyyy').format(_selectedMonth), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Total Advances', style: TextStyle(color: AppTheme.txtSec, fontSize: 12)),
                    Text('₹${totalAdv.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.red, fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Est. Net Pay', style: TextStyle(color: AppTheme.txtSec, fontSize: 12)),
                    Text('₹${netPay.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.green, fontSize: 16, fontWeight: FontWeight.bold)),
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
                    Text(DateFormat('dd MMM').format(DateTime.parse(a.date)), style: const TextStyle(color: AppTheme.txtSec)),
                    Text(a.reason.isNotEmpty ? a.reason : 'Advance', style: const TextStyle(color: AppTheme.txtSec, fontSize: 12)),
                    Text('₹${a.amount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              )).toList()
            ]
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAttendanceCalendar(List<Attendance> allAttendance) {
    // Filter to this supervisor's attendance
    final supAttendance = allAttendance.where((a) => a.guardId == widget.supervisor.id).toList();

    return Card(
      color: AppTheme.bgSurface,
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
            // Placeholder for real calendar (just showing summary)
            Text('Attendance marked: ${supAttendance.where((a) => DateTime.parse(a.date).month == _selectedMonth.month && DateTime.parse(a.date).year == _selectedMonth.year).length} days', style: const TextStyle(color: AppTheme.txtSec)),
            // You can embed the same calendar grid logic as GuardProfileScreen here
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }
}
