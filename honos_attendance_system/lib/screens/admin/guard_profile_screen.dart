import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/db_service.dart';
import '../../models/guard.dart';
import '../../models/attendance.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';

class GuardProfileScreen extends ConsumerStatefulWidget {
  final Guard guard;
  const GuardProfileScreen({super.key, required this.guard});

  @override
  ConsumerState<GuardProfileScreen> createState() => _GuardProfileScreenState();
}

class _GuardProfileScreenState extends ConsumerState<GuardProfileScreen> {
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
    final attendanceAsync = ref.watch(guardAttendanceProvider(widget.guard.id));
    final sitesAsync = ref.watch(sitesStreamProvider);
    final authUser = ref.watch(authProvider);
    final isAdmin = authUser?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guard Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: isAdmin 
          ? [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.red),
                tooltip: 'Delete Guard',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete Guard Profile?'),
                      content: Text('Are you sure you want to permanently delete ${widget.guard.name}? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(dbProvider).deleteGuard(widget.guard.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              )
            ]
          : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Profile Card
            _buildProfileHeader(sitesAsync),
            const SizedBox(height: 24),

            // 2. Metrics & Grid loaded from Attendance Data
            attendanceAsync.when(
              data: (allAttendance) {
                // Filter attendance specifically for this guard
                final guardAttendance = allAttendance.where((a) => a.guardId == widget.guard.id).toList();
                
                return Column(
                  children: [
                    _buildMetricsSection(guardAttendance),
                    const SizedBox(height: 24),
                    _buildCalendarGrid(guardAttendance),
                    const SizedBox(height: 24),
                    _buildWorkingHoursSection(guardAttendance),
                  ],
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
              error: (e, __) => Center(child: Text('Error loading attendance: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(AsyncValue sitesAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.guard.id}',
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.primary.withOpacity(0.2),
                backgroundImage: widget.guard.photo.length > 200 ? MemoryImage(base64Decode(widget.guard.photo)) : null,
                child: widget.guard.photo.length <= 200 ? Text(widget.guard.name[0], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary)) : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.guard.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.badge, size: 14, color: AppTheme.txtMuted),
                      const SizedBox(width: 4),
                      Text('ID: ${widget.guard.empId}', style: const TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  sitesAsync.when(
                    data: (sites) {
                      final siteMatches = sites.where((s) => s.id == widget.guard.siteId);
                      final siteName = siteMatches.isNotEmpty ? siteMatches.first.name : 'Unknown Site';
                      return Row(
                        children: [
                          const Icon(Icons.business, size: 14, color: AppTheme.txtMuted),
                          const SizedBox(width: 4),
                          Expanded(child: Text(siteName, style: const TextStyle(color: AppTheme.txtSec, fontSize: 13), overflow: TextOverflow.ellipsis)),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            // Call Button
            if (widget.guard.phone.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.phone, color: AppTheme.green),
                style: IconButton.styleFrom(backgroundColor: AppTheme.green.withOpacity(0.1)),
                onPressed: () async {
                  final uri = Uri.parse('tel:${widget.guard.phone}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not launch dialer')),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildMetricsSection(List<Attendance> attendance) {
    // 1. Overall Credibility (Percentage)
    // Assume 30 days in a month for simplicity if joinDate isn't set perfectly,
    // but a better way is to check the first attendance record date.
    int totalPossibleDays = 30; // Default
    if (attendance.isNotEmpty) {
      attendance.sort((a, b) => a.date.compareTo(b.date));
      final firstDate = DateTime.tryParse(attendance.first.date);
      if (firstDate != null) {
        totalPossibleDays = DateTime.now().difference(firstDate).inDays + 1;
        if (totalPossibleDays < 1) totalPossibleDays = 1;
      }
    }
    
    final totalPresent = attendance.where((a) => a.status.toLowerCase() == 'present').length;
    final double credibilityScore = totalPossibleDays > 0 ? (totalPresent / totalPossibleDays) * 100 : 0;

    // 2. Current Month Salary Estimate
    final currentMonthAtt = attendance.where((a) {
      final d = DateTime.tryParse(a.date);
      return d != null && d.year == DateTime.now().year && d.month == DateTime.now().month;
    }).toList();
    
    final monthPresentDays = currentMonthAtt.where((a) => a.status.toLowerCase() == 'present').length;
    final int daysInCurrentMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
    final double dailyWage = widget.guard.salary / daysInCurrentMonth;
    final double estimatedSalary = monthPresentDays * dailyWage;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Credibility',
            value: '${credibilityScore.clamp(0, 100).toStringAsFixed(1)}%',
            subtitle: 'Overall Attendance',
            icon: Icons.trending_up,
            color: credibilityScore >= 80 ? AppTheme.green : (credibilityScore >= 50 ? AppTheme.yellow : AppTheme.red),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Est. Salary',
            value: '₹${estimatedSalary.toStringAsFixed(0)}',
            subtitle: '$monthPresentDays days this month',
            icon: Icons.account_balance_wallet,
            color: AppTheme.primary,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMetricCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Card(
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.txtSec)),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(List<Attendance> attendance) {
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final now = DateTime.now();
    
    return Card(
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
                    IconButton(icon: const Icon(Icons.chevron_left, color: AppTheme.txtSec), onPressed: () => _changeMonth(-1)),
                    Text(monthName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    IconButton(icon: const Icon(Icons.chevron_right, color: AppTheme.txtSec), onPressed: () => _changeMonth(1)),
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
                
                Color blockColor = AppTheme.bgElevated; // Default/No data
                String statusText = '';
                
                if (attRecord.isNotEmpty) {
                  final isPresent = attRecord.any((a) => a.status.toLowerCase() == 'present');
                  blockColor = isPresent ? AppTheme.green : AppTheme.red;
                  statusText = isPresent ? 'P' : 'A';
                } else {
                  // If it's a past date and no record, mark as absent/red
                  final checkDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                  if (checkDate.isBefore(DateTime(now.year, now.month, now.day))) {
                    blockColor = AppTheme.red.withOpacity(0.3); // Missed attendance
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
                          color: blockColor == AppTheme.bgElevated ? AppTheme.txtMuted : Colors.white,
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
                _buildLegendItem(AppTheme.green, 'Present'),
                const SizedBox(width: 16),
                _buildLegendItem(AppTheme.red, 'Absent'),
                const SizedBox(width: 16),
                _buildLegendItem(AppTheme.red.withOpacity(0.3), 'Missed'),
                const SizedBox(width: 16),
                _buildLegendItem(AppTheme.bgElevated, 'Future'),
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
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.txtSec)),
      ],
    );
  }

  Widget _buildWorkingHoursSection(List<Attendance> attendance) {
    // Filter to attendance that has BOTH check-in and check-out time
    final completedShifts = attendance.where((a) => a.time.isNotEmpty && a.checkOutTime.isNotEmpty).toList();
    
    // Sort descending by date
    completedShifts.sort((a, b) => b.date.compareTo(a.date));

    // Get the top 14 most recent shifts
    final recentShifts = completedShifts.take(14).toList();

    if (recentShifts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('Recent Working Hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentShifts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final shift = recentShifts[i];
            
            // Calculate duration
            int durationMinutes = 0;
            try {
              final inParts = shift.time.split(':');
              final outParts = shift.checkOutTime.split(':');
              
              final inTime = DateTime(2000, 1, 1, int.parse(inParts[0]), int.parse(inParts[1]));
              var outTime = DateTime(2000, 1, 1, int.parse(outParts[0]), int.parse(outParts[1]));
              
              // Handle overnight shifts if checkout is next day
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
            final dateStr = date != null ? DateFormat('MMM dd, yyyy').format(date) : shift.date;

            return Card(
              color: AppTheme.bgElevated,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.access_time, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.login, size: 12, color: AppTheme.txtMuted),
                              const SizedBox(width: 4),
                              Text(shift.time, style: const TextStyle(fontSize: 12, color: AppTheme.txtSec)),
                              const SizedBox(width: 12),
                              const Icon(Icons.logout, size: 12, color: AppTheme.txtMuted),
                              const SizedBox(width: 4),
                              Text(shift.checkOutTime, style: const TextStyle(fontSize: 12, color: AppTheme.txtSec)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                      ),
                      child: Text(
                        durationStr,
                        style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }
}
