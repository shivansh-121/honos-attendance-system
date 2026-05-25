import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../models/attendance.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/excel_service.dart'; // To calculate days in month

class EmployeeProfileScreen extends ConsumerStatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  ConsumerState<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final leavesAsync = ref.watch(leavesStreamProvider);
    final attendanceAsync = ref.watch(guardAttendanceProvider(user?.id ?? ''));

    if (user == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'profile_pic',
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: context.colors.bgElevated,
                      backgroundImage: user.photo.length > 200 ? MemoryImage(base64Decode(user.photo)) : null,
                      child: user.photo.length < 200 ? Text(user.name[0], style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: context.colors.txtMuted)) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(user.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text('OFFICE EMPLOYEE', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
            ),
          ),
          
          leavesAsync.when(
            data: (leaves) {
              final myLeaves = leaves.where((l) => l.employeeId == user.id && l.status == 'approved').length;
              final monthlySalary = user.salary;
              
              // Simple calculation for salary impact:
              final daysInMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
              final dailyWage = monthlySalary / daysInMonth;
              
              // Assume we deduct daily wage for every approved leave.
              // Note: Ideally we'd use exact attendance records, but for demonstration of "salary impact" based on leaves:
              final deduction = dailyWage * myLeaves;
              final netSalary = monthlySalary - deduction;

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          title: 'Approved Leaves',
                          value: myLeaves.toString(),
                          icon: Icons.event_available,
                          color: context.colors.yellow,
                          delay: 200,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatBox(
                          title: 'Net Salary Impact',
                          value: '-₹${deduction.toStringAsFixed(0)}',
                          icon: Icons.trending_down,
                          color: context.colors.red,
                          delay: 300,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(),
            error: (e, __) => const SliverToBoxAdapter(),
          ),

          attendanceAsync.when(
            data: (allAttendance) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: _buildCalendarGrid(allAttendance),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, __) => SliverToBoxAdapter(child: Center(child: Text('Error loading attendance: $e'))),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text('Contact Information', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _InfoCard(
                  delay: 400,
                  children: [
                    _InfoRow(icon: Icons.phone, label: 'Phone', value: user.phone.isNotEmpty ? user.phone : '--'),
                    _InfoRow(icon: Icons.badge, label: 'Employee ID', value: user.empId.isNotEmpty ? user.empId : '--'),
                    _InfoRow(icon: Icons.location_on, label: 'Address', value: user.address.isNotEmpty ? user.address : '--'),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('Financial Information', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _InfoCard(
                  delay: 500,
                  children: [
                    _InfoRow(icon: Icons.currency_rupee, label: 'Fixed Salary', value: '₹${user.salary.toStringAsFixed(0)}'),
                    _InfoRow(icon: Icons.account_balance, label: 'Bank Name', value: user.bankName.isNotEmpty ? user.bankName : '--'),
                    _InfoRow(icon: Icons.numbers, label: 'Account No.', value: user.accountNo.isNotEmpty ? user.accountNo : '--'),
                    _InfoRow(icon: Icons.account_balance_wallet, label: 'IFSC Code', value: user.ifsc.isNotEmpty ? user.ifsc : '--'),
                  ],
                ),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(List<Attendance> attendance) {
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final now = DateTime.now();
    
    return Card(
      color: context.colors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Monthly Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Row(
                  children: [
                    IconButton(icon: Icon(Icons.chevron_left, color: context.colors.txtSec), onPressed: () => _changeMonth(-1)),
                    Text(monthName, style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.primary)),
                    IconButton(icon: Icon(Icons.chevron_right, color: context.colors.txtSec), onPressed: () => _changeMonth(1)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: daysInMonth,
              itemBuilder: (ctx, index) {
                final day = index + 1;
                final dateStr = DateFormat('yyyy-MM-dd').format(DateTime(_selectedMonth.year, _selectedMonth.month, day));
                
                // Find attendance for this day
                final attRecord = attendance.where((a) => a.date == dateStr).toList();
                
                Color blockColor = context.colors.bgElevated; // Default/No data
                
                if (attRecord.isNotEmpty) {
                  final isPresent = attRecord.any((a) => a.status.toLowerCase() == 'present');
                  blockColor = isPresent ? context.colors.green : context.colors.red;
                } else {
                  // If it's a past date and no record, mark as absent/red
                  final checkDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                  if (checkDate.isBefore(DateTime(now.year, now.month, now.day))) {
                    blockColor = context.colors.red.withValues(alpha: 0.3); // Missed attendance
                  }
                }

                return Tooltip(
                  message: 'Day $day: ${attRecord.isNotEmpty ? attRecord.last.time : 'No Record'}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: blockColor,
                      borderRadius: BorderRadius.circular(6),
                      border: _selectedMonth.year == now.year && _selectedMonth.month == now.month && day == now.day 
                          ? Border.all(color: Colors.white, width: 2) // Highlight today
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: blockColor == context.colors.bgElevated ? context.colors.txtMuted : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(context.colors.green, 'Present'),
                const SizedBox(width: 16),
                _buildLegendItem(context.colors.red, 'Absent'),
                const SizedBox(width: 16),
                _buildLegendItem(context.colors.red.withValues(alpha: 0.3), 'Missed'),
                const SizedBox(width: 16),
                _buildLegendItem(context.colors.bgElevated, 'Future'),
              ],
            )
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: context.colors.txtSec)),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final int delay;

  const _StatBox({required this.title, required this.value, required this.icon, required this.color, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: context.colors.txtMuted, fontSize: 12)),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1, end: 0);
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final int delay;

  const _InfoCard({required this.children, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: children.expand((w) => [w, const Divider(color: Colors.white10, height: 24)]).toList()..removeLast(),
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1, end: 0);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: context.colors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.colors.txtMuted, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
