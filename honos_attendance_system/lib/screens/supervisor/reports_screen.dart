import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../models/attendance.dart';
import '../../models/guard.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/base64_image_widget.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedFilter = 'Today';
  final List<String> _filters = ['Today', 'This Week', 'This Month', 'All'];

  List<Attendance> _getFiltered(List<Attendance> all) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    switch (_selectedFilter) {
      case 'Today':
        return all.where((a) => a.date == today).toList();
      case 'This Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return all.where((a) {
          final d = DateTime.tryParse(a.date);
          return d != null && d.isAfter(weekAgo);
        }).toList();
      case 'This Month':
        return all
            .where((a) => a.date.startsWith(DateFormat('yyyy-MM').format(now)))
            .toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isAdmin = user?.role == 'admin';
    final guardsAsync = ref.watch(guardsStreamProvider);
    final attendanceAsync = ref.watch(attendanceStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports'),
        actions: isAdmin
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: AppTheme.red),
                  tooltip: 'Clear All Records',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear All Records?'),
                        content: const Text('This will permanently delete ALL attendance records from the database. This action cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                            onPressed: () {
                              ref.read(dbProvider).clearAttendance();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All records deleted.'), backgroundColor: AppTheme.red));
                            },
                            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: guardsAsync.when(
        data: (guards) => attendanceAsync.when(
          data: (allRecords) {
            final filtered = _getFiltered(allRecords);
            final totalGuards = guards.length;
            final presentToday = _getFiltered(allRecords).length;

            return Column(
              children: [
                // Summary Cards
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      _buildSummaryCard('Total Guards', '$totalGuards', Icons.people, AppTheme.primary),
                      const SizedBox(width: 12),
                      _buildSummaryCard('Records', '${allRecords.length}', Icons.history, AppTheme.purple),
                      const SizedBox(width: 12),
                      _buildSummaryCard('Today\'s', '$presentToday', Icons.today, AppTheme.green),
                    ],
                  ),
                ),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters
                          .map((f) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(f),
                                  selected: _selectedFilter == f,
                                  onSelected: (_) => setState(() => _selectedFilter = f),
                                  selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                                  checkmarkColor: AppTheme.primary,
                                  backgroundColor: AppTheme.bgElevated,
                                  labelStyle: TextStyle(
                                    color: _selectedFilter == f ? AppTheme.primary : AppTheme.txtSec,
                                    fontWeight: _selectedFilter == f ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(color: _selectedFilter == f ? AppTheme.primary : AppTheme.bord),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),

                // List header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${filtered.length} records', style: const TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                      const Text('Tap to expand', style: TextStyle(color: AppTheme.txtMuted, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Records List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 72, color: AppTheme.txtMuted),
                              const SizedBox(height: 12),
                              Text('No records for "$_selectedFilter"', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.txtSec)),
                              const SizedBox(height: 8),
                              const Text('Mark attendance to see reports here.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.txtMuted, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final record = filtered[i];
                            final guard = guards.firstWhere(
                              (g) => g.id == record.guardId,
                              orElse: () => const Guard(id: '', name: 'Unknown', empId: '', siteId: '', supervisorId: '', phone: '', joinDate: '', salary: 0),
                            );
                            return _AttendanceCard(
                              record: record, 
                              guard: guard,
                              isAdmin: isAdmin,
                              onDelete: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Record?'),
                                    content: const Text('Are you sure you want to delete this attendance record?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                                        onPressed: () {
                                          ref.read(dbProvider).deleteAttendance(record.id);
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record deleted.'), backgroundColor: AppTheme.red));
                                        },
                                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(child: Text('Rec Error: $e', style: const TextStyle(color: Colors.white))),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Guard Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 20)),
            Text(title,
                style: const TextStyle(color: AppTheme.txtSec, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final Attendance record;
  final Guard guard;
  final bool isAdmin;
  final VoidCallback onDelete;

  const _AttendanceCard({required this.record, required this.guard, this.isAdmin = false, required this.onDelete});

  String _calcWorkingHours() {
    if (record.time.isEmpty || record.checkOutTime.isEmpty) return '';
    try {
      final inParts = record.time.split(':');
      final outParts = record.checkOutTime.split(':');
      if (inParts.length < 2 || outParts.length < 2) return '';
      final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final diff = outMin - inMin;
      if (diff <= 0) return '';
      final h = diff ~/ 60;
      final m = diff % 60;
      return '${h}h ${m}m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(record.date);
    final formattedDate = date != null
        ? DateFormat('EEE, dd MMM yyyy').format(date)
        : record.date;
    final workingHours = _calcWorkingHours();
    final hasCheckOut = record.checkOutTime.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar, name, status badge, delete
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: guard.photo.length > 200
                        ? Base64ImageWidget(base64String: guard.photo)
                        : Container(
                            color: AppTheme.green.withValues(alpha: 0.15),
                            child: const Icon(Icons.person, color: AppTheme.green),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guard.name.isEmpty ? 'Guard #${record.guardId}' : guard.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (guard.empId.isNotEmpty)
                        Text('ID: ${guard.empId}', style: const TextStyle(fontSize: 11, color: AppTheme.txtMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.green.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    record.status.toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Delete Record',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Date row
            Row(children: [
              const Icon(Icons.calendar_today, size: 12, color: AppTheme.txtMuted),
              const SizedBox(width: 5),
              Text(formattedDate, style: const TextStyle(fontSize: 12, color: AppTheme.txtSec)),
            ]),
            const SizedBox(height: 6),
            // Check-in / Check-out / Working hours row
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Check-In
                  Expanded(
                    child: Column(
                      children: [
                        const Icon(Icons.login, size: 16, color: AppTheme.green),
                        const SizedBox(height: 4),
                        const Text('Check-In', style: TextStyle(fontSize: 10, color: AppTheme.txtMuted)),
                        Text(record.time.isNotEmpty ? record.time : '--:--',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.green)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppTheme.bord),
                  // Check-Out
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.logout, size: 16, color: hasCheckOut ? AppTheme.yellow : AppTheme.txtMuted),
                        const SizedBox(height: 4),
                        const Text('Check-Out', style: TextStyle(fontSize: 10, color: AppTheme.txtMuted)),
                        Text(hasCheckOut ? record.checkOutTime : '--:--',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: hasCheckOut ? AppTheme.yellow : AppTheme.txtMuted)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppTheme.bord),
                  // Working Hours
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.timer_outlined, size: 16, color: workingHours.isNotEmpty ? AppTheme.primary : AppTheme.txtMuted),
                        const SizedBox(height: 4),
                        const Text('Working Hrs', style: TextStyle(fontSize: 10, color: AppTheme.txtMuted)),
                        Text(workingHours.isNotEmpty ? workingHours : '--',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: workingHours.isNotEmpty ? AppTheme.primary : AppTheme.txtMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
