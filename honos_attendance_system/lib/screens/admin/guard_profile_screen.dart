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
  bool _isGeneratingPdf = false;

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
    final usersAsync = ref.watch(usersStreamProvider);
    final advancesAsync = ref.watch(advancesStreamProvider);
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
                icon: Icon(Icons.delete_outline, color: context.colors.red),
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
                          style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: context.colors.red),
                          onPressed: () => Navigator.pop(c, true),
                          child: Text('Delete', style: TextStyle(color: context.colors.txtPrimary)),
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

            // 2.5. Advances Section
            _buildAdvancesSection(advancesAsync),
            const SizedBox(height: 24),

            // 3. Metrics Sectiond loaded from Attendance Data
            attendanceAsync.when(
              data: (allAttendance) {
                final guardAttendance = allAttendance.where((a) => a.guardId == widget.guard.id).toList();
                return Column(
                  children: [
                    _buildMetricsSection(guardAttendance),
                    const SizedBox(height: 24),
                    _buildPersonalInfoSection(),
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
                backgroundColor: context.colors.primary.withValues(alpha: 0.2),
                backgroundImage: widget.guard.photo.length > 200 ? MemoryImage(base64Decode(widget.guard.photo)) : null,
                child: widget.guard.photo.length <= 200 ? Text(widget.guard.name[0], style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: context.colors.primary)) : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.guard.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge, size: 14, color: context.colors.txtMuted),
                      const SizedBox(width: 4),
                      Text('ID: ${widget.guard.empId}', style: TextStyle(color: context.colors.txtSec, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  sitesAsync.when(
                    data: (sites) {
                      final siteMatches = sites.where((s) => s.id == widget.guard.siteId);
                      final siteName = siteMatches.isNotEmpty ? siteMatches.first.name : 'Unknown Site';
                      return Row(
                        children: [
                          Icon(Icons.business, size: 14, color: context.colors.txtMuted),
                          const SizedBox(width: 4),
                          Expanded(child: Text(siteName, style: TextStyle(color: context.colors.txtSec, fontSize: 13), overflow: TextOverflow.ellipsis)),
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
                icon: Icon(Icons.phone, color: context.colors.green),
                style: IconButton.styleFrom(backgroundColor: context.colors.green.withValues(alpha: 0.1)),
                onPressed: () async {
                  final uri = Uri.parse('tel:${widget.guard.phone}');
                  final messenger = ScaffoldMessenger.of(context);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Could not launch dialer')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildAdvancesSection(AsyncValue<List<dynamic>> advancesAsync) {
    return advancesAsync.when(
      data: (allAdvances) {
        final monthAdvances = allAdvances.where((a) {
          if (a.userId != widget.guard.id || a.userType != 'guard') return false;
          final d = DateTime.tryParse(a.date);
          return d != null && d.year == _selectedMonth.year && d.month == _selectedMonth.month;
        }).toList();

        final totalAdvance = monthAdvances.fold<double>(0, (sum, a) => sum + a.amount);

        return Card(
          color: context.colors.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Advances Taken', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
                    Text('Total: INR ${totalAdvance.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.red)),
                  ],
                ),
                const SizedBox(height: 12),
                if (monthAdvances.isEmpty)
                  Text('No advances taken this month.', style: TextStyle(color: context.colors.txtSec))
                else
                  ...monthAdvances.map((a) {
                    final d = DateTime.parse(a.date);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('dd MMM yyyy').format(d), style: TextStyle(color: context.colors.txtSec, fontSize: 13)),
                              if (a.reason.isNotEmpty)
                                Text(a.reason, style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
                            ],
                          ),
                          Text('INR ${a.amount.toStringAsFixed(0)}', style: TextStyle(color: context.colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMetricsSection(List<Attendance> attendance) {
    // 1. Total possible days — use joinDate if set, else first attendance date
    int totalPossibleDays = 1;
    final joinDate = DateTime.tryParse(widget.guard.joinDate);
    if (joinDate != null) {
      totalPossibleDays = DateTime.now().difference(joinDate).inDays + 1;
      if (totalPossibleDays < 1) totalPossibleDays = 1;
    } else if (attendance.isNotEmpty) {
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
            color: credibilityScore >= 80 ? context.colors.green : (credibilityScore >= 50 ? context.colors.yellow : context.colors.red),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Est. Salary',
            value: '₹${estimatedSalary.toStringAsFixed(0)}',
            subtitle: '$monthPresentDays days this month',
            icon: Icons.account_balance_wallet,
            color: context.colors.primary,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPersonalInfoSection() {
    final g = widget.guard;

    // Masking helpers
    String maskAadhaar(String v) {
      if (v.length < 4) return v.isEmpty ? '—' : v;
      return 'XXXX-XXXX-${v.substring(v.length - 4)}';
    }

    String maskAccount(String v) {
      if (v.length < 4) return v.isEmpty ? '—' : v;
      return '****${v.substring(v.length - 4)}';
    }

    Widget row(IconData icon, String label, String value, {Color? valueColor}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: context.colors.txtMuted),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: context.colors.txtSec, fontSize: 12))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: TextStyle(color: valueColor ?? context.colors.txtPrimary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 2)),
        ],
      ),
    );

    Widget divider() => Divider(color: context.colors.bord, height: 1);

    Widget sectionTitle(String title, IconData icon) => Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 12, color: context.colors.primary)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guard Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
            const SizedBox(height: 16),

            // Personal
            sectionTitle('Personal Information', Icons.person),
            row(Icons.phone, 'Phone', g.phone),
            divider(),
            row(Icons.cake, 'Date of Birth', g.dob),
            divider(),
            row(Icons.home, 'Address', g.address),
            divider(),
            row(Icons.calendar_today, 'Joined On', g.joinDate),
            divider(),
            row(Icons.currency_rupee, 'Monthly Salary', g.salary > 0 ? '₹${g.salary.toStringAsFixed(0)}' : '—', valueColor: context.colors.green),
            const SizedBox(height: 16),

            // Identity
            sectionTitle('Identity', Icons.credit_card),
            row(Icons.credit_card, 'Aadhaar No.', maskAadhaar(g.aadharNo)),
            divider(),
            row(Icons.badge, 'UAN No.', g.uanNo.isNotEmpty ? g.uanNo : '—'),
            const SizedBox(height: 16),

            // Bank
            sectionTitle('Bank Details', Icons.account_balance),
            row(Icons.account_balance, 'Bank Name', g.bankName),
            divider(),
            row(Icons.code, 'IFSC Code', g.ifsc),
            divider(),
            row(Icons.numbers, 'Account No.', maskAccount(g.accountNo)),
            divider(),
            row(Icons.location_city, 'Branch', g.branch),
            const SizedBox(height: 16),

            // Notes
            if (g.passbookPhoto.isNotEmpty) ...[
              sectionTitle('Notes', Icons.notes),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.colors.bgElevated, borderRadius: BorderRadius.circular(10)),
                child: Text(g.passbookPhoto, style: TextStyle(color: context.colors.txtSec, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMetricCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Card(
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withValues(alpha: 0.2))),
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
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: context.colors.txtSec)),
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
                Text('Monthly Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
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
                    blockColor = context.colors.red; // Missed attendance is now also red
                  }
                }

                return Tooltip(
                  message: 'Day $day: ${attRecord.isNotEmpty ? attRecord.last.time : 'No Record'}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: blockColor,
                      borderRadius: BorderRadius.circular(6),
                      border: _selectedMonth.year == now.year && _selectedMonth.month == now.month && day == now.day 
                          ? Border.all(color: context.colors.txtPrimary, width: 2) // Highlight today
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('Recent Working Hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
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
              color: context.colors.bgSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.colors.bord.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.access_time, color: context.colors.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateStr, style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.txtPrimary, fontSize: 14)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.login, size: 12, color: context.colors.txtMuted),
                              const SizedBox(width: 4),
                              Text(shift.time, style: TextStyle(fontSize: 12, color: context.colors.txtSec)),
                              const SizedBox(width: 12),
                              Icon(Icons.logout, size: 12, color: context.colors.txtMuted),
                              const SizedBox(width: 4),
                              Text(shift.checkOutTime, style: TextStyle(fontSize: 12, color: context.colors.txtSec)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        durationStr,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
