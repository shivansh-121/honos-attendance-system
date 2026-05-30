import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../models/app_user.dart';
import '../../models/advance.dart';
import '../../models/attendance.dart';
import '../../models/leave.dart';
import '../../services/db_service.dart';

class SupervisorProfileScreen extends ConsumerStatefulWidget {
  final AppUser supervisor;

  const SupervisorProfileScreen({super.key, required this.supervisor});

  @override
  ConsumerState<SupervisorProfileScreen> createState() =>
      _SupervisorProfileScreenState();
}

class _SupervisorProfileScreenState
    extends ConsumerState<SupervisorProfileScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final s = widget.supervisor;
    final advancesAsync = ref.watch(advancesStreamProvider);
    final attendanceAsync = ref.watch(guardAttendanceProvider(s.id));
    final leavesAsync = ref.watch(leavesStreamProvider);
    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${s.role[0].toUpperCase()}${s.role.substring(1)} Profile',
            style: const TextStyle(fontWeight: FontWeight.bold)),
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

                  // Profile Details
                  _buildDetailsCard(s),
                  const SizedBox(height: 24),

                  // Advances & Net Pay
                  advancesAsync.when(
                    data: (advances) => leavesAsync.when(
                      data: (leaves) => _buildAdvancesCard(s, advances, leaves),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, __) => Text('Error loading leaves: $e'),
                    ),
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

  Widget _buildHeader(AppUser s) {
    return Card(
      color: context.colors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: context.colors.bgElevated,
              backgroundImage: s.photo.length > 200
                  ? MemoryImage(base64Decode(s.photo))
                  : null,
              child: s.photo.length < 200
                  ? Icon(Icons.person, size: 50, color: context.colors.txtMuted)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(s.name,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.colors.txtPrimary)),
            if (s.empId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Emp ID: ${s.empId}',
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
              child: Text(s.role.toUpperCase(),
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
                Text(s.phone.isNotEmpty ? s.phone : 'No Phone',
                    style: TextStyle(color: context.colors.txtSec)),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today,
                    size: 16, color: context.colors.txtSec),
                const SizedBox(width: 4),
                Text('Joined: ${s.joinDate.split('T').first}',
                    style: TextStyle(color: context.colors.txtSec)),
              ],
            )
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildDetailsCard(AppUser s) {
    return Card(
      color: context.colors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Identity', Icons.credit_card),
            _row(Icons.credit_card, 'Aadhaar No.', _mask(s.aadharNo)),
            Divider(
                color: context.colors.txtPrimary.withValues(alpha: 0.1),
                height: 24),
            _row(Icons.badge, 'UAN No.',
                s.uanNo.isNotEmpty ? s.uanNo : 'Not Provided'),
            const SizedBox(height: 24),
            _sectionTitle('Bank Details', Icons.account_balance),
            _row(Icons.account_balance, 'Bank Name', s.bankName),
            Divider(
                color: context.colors.txtPrimary.withValues(alpha: 0.1),
                height: 24),
            _row(Icons.numbers, 'Account No.', s.accountNo),
            Divider(
                color: context.colors.txtPrimary.withValues(alpha: 0.1),
                height: 24),
            _row(Icons.code, 'IFSC Code', s.ifsc),
            const SizedBox(height: 24),
            _sectionTitle('Employment', Icons.work),
            _row(Icons.currency_rupee, 'Fixed Salary',
                '₹${s.salary.toStringAsFixed(0)}'),
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

  Widget _buildAdvancesCard(
      AppUser s, List<Advance> allAdvances, List<Leave> allLeaves) {
    final supAdvances = allAdvances
        .where((a) =>
            a.userId == s.id &&
            (a.userType == 'supervisor' ||
                a.userType == 'executive' ||
                a.userType == 'employee'))
        .toList();
    final monthAdvances = supAdvances.where((a) {
      final d = DateTime.tryParse(a.date);
      if (d == null) return false;
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }).toList();

    final totalAdv = monthAdvances.fold<double>(0, (sum, a) => sum + a.amount);

    // Deduct leaves
    final myLeaves = allLeaves
        .where((l) => l.employeeId == s.id && l.status == 'approved')
        .toList();
    final monthLeavesCount = myLeaves.where((l) {
      final d = DateTime.tryParse(l.fromDate);
      if (d == null) return false;
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }).length;

    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final dailyWage = s.salary / daysInMonth;
    final leaveDeduction = dailyWage * monthLeavesCount;

    final netPay = s.salary - totalAdv - leaveDeduction;

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
                  color: Colors.black12,
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
                    if (monthLeavesCount > 0)
                      Text('-$monthLeavesCount Leave(s)',
                          style: TextStyle(
                              color: context.colors.red, fontSize: 10)),
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

  Widget _buildAttendanceCalendar(List<Attendance> allAttendance) {
    final supAttendance =
        allAttendance.where((a) => a.guardId == widget.supervisor.id).toList();

    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final now = DateTime.now();

    return Column(children: [
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
                      Text(monthName,
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
                  final dateStr = DateFormat('yyyy-MM-dd').format(
                      DateTime(_selectedMonth.year, _selectedMonth.month, day));

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
    ]);
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
