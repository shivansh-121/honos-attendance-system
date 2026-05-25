import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../models/attendance.dart';
import '../../models/guard.dart';
import '../../models/app_user.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../services/app_nav.dart';
import '../admin/guard_profile_screen.dart';

// Since we have stream providers for generic things, let's define a family provider for scoped attendance
final dateRangeAttendanceProvider = StreamProvider.family<List<Attendance>, Map<String, String>>((ref, range) {
  return ref.read(dbProvider).attendanceStreamForDateRange(range['start']!, range['end']!);
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedFilter = 'Today';
  final List<String> _filters = ['Today', 'This Week', 'This Month', 'Custom'];
  
  String _userRoleFilter = 'All'; // 'All', 'Guards', 'Supervisors', 'Office'
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    setState(() {
      if (_selectedFilter == 'Today') {
        _startDate = now;
        _endDate = now;
      } else if (_selectedFilter == 'This Week') {
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
      } else if (_selectedFilter == 'This Month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0); // last day of month
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.colors.primary,
              surface: context.colors.bgSurface,
              onPrimary: Colors.white,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = 'Custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isAdmin = user?.role == 'admin';
    final guardsAsync = ref.watch(guardsStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);

    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    
    final attendanceAsync = ref.watch(dateRangeAttendanceProvider({'start': startStr, 'end': endStr}));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports'),
        actions: isAdmin
            ? [
                IconButton(
                  icon: Icon(Icons.delete_sweep, color: context.colors.red),
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
                            style: ElevatedButton.styleFrom(backgroundColor: context.colors.red),
                            onPressed: () {
                              ref.read(dbProvider).clearAttendance();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('All records deleted.'), backgroundColor: context.colors.red));
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
        data: (guards) => usersAsync.when(
          data: (allUsers) => attendanceAsync.when(
            data: (allRecords) {
              return _buildReportContent(user, isAdmin, guards, allUsers, allRecords);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(child: Text('Rec Error: $e', style: const TextStyle(color: Colors.white))),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(child: Text('User Error: $e', style: const TextStyle(color: Colors.white))),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Guard Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildReportContent(AppUser? currentUser, bool isAdmin, List<Guard> guards, List<AppUser> allUsers, List<Attendance> records) {
    // 1. Get visibility permissions
    final isExecutive = currentUser?.role == 'executive';
    final isSupervisor = currentUser?.role == 'supervisor';

    // List of people the current user is allowed to see
    List<dynamic> visiblePeople = [];

    // Filter by role requested by user
    if (_userRoleFilter == 'All' || _userRoleFilter == 'Guards') {
      visiblePeople.addAll(guards);
    }
    if ((isAdmin || isExecutive) && (_userRoleFilter == 'All' || _userRoleFilter == 'Supervisors')) {
      visiblePeople.addAll(allUsers.where((u) => u.role == 'supervisor'));
    }
    if (isAdmin && (_userRoleFilter == 'All' || _userRoleFilter == 'Office')) {
      visiblePeople.addAll(allUsers.where((u) => u.role == 'office_employee'));
    }

    final totalVisible = visiblePeople.length;
    final isSingleDay = _startDate.year == _endDate.year && _startDate.month == _endDate.month && _startDate.day == _endDate.day;

    // Filter records for visible people
    final visibleRecords = records.where((r) => visiblePeople.any((p) => p.id == r.guardId)).toList();
    final presentCount = visibleRecords.where((r) => r.date == DateFormat('yyyy-MM-dd').format(_startDate)).length; // If single day

    return Column(
      children: [
        // Top Filter Chips (Time)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: _selectedFilter == f,
                  onSelected: (_) {
                    if (f == 'Custom') {
                      _pickCustomRange();
                    } else {
                      setState(() {
                        _selectedFilter = f;
                        _updateDateRange();
                      });
                    }
                  },
                  selectedColor: context.colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: context.colors.primary,
                  backgroundColor: context.colors.bgElevated,
                  labelStyle: TextStyle(
                    color: _selectedFilter == f ? context.colors.primary : context.colors.txtSec,
                    fontWeight: _selectedFilter == f ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: _selectedFilter == f ? context.colors.primary : context.colors.bord),
                  ),
                ),
              )).toList(),
            ),
          ),
        ),

        // Second Filter Chips (Role)
        if (isAdmin || isExecutive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Guards', 'Supervisors', if (isAdmin) 'Office'].map((role) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(role, style: TextStyle(fontSize: 12)),
                    selected: _userRoleFilter == role,
                    onSelected: (val) {
                      if (val) setState(() => _userRoleFilter = role);
                    },
                    selectedColor: context.colors.yellow.withValues(alpha: 0.2),
                    backgroundColor: context.colors.bgElevated,
                    labelStyle: TextStyle(color: _userRoleFilter == role ? context.colors.yellow : context.colors.txtMuted),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _userRoleFilter == role ? context.colors.yellow : Colors.transparent),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),

        // Summary Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildSummaryCard('Personnel', '$totalVisible', Icons.people, context.colors.primary),
              const SizedBox(width: 12),
              _buildSummaryCard('Records', '${visibleRecords.length}', Icons.history, context.colors.purple),
              const SizedBox(width: 12),
              _buildSummaryCard(isSingleDay ? 'Present' : 'Avg/Day', 
                                isSingleDay ? '$presentCount' : '${(visibleRecords.length / max(1, _endDate.difference(_startDate).inDays)).toStringAsFixed(1)}', 
                                Icons.check_circle, context.colors.green),
            ],
          ),
        ),
        
        // Date indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.calendar_month, color: context.colors.txtMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                isSingleDay 
                  ? DateFormat('EEEE, MMM dd, yyyy').format(_startDate)
                  : '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                style: TextStyle(color: context.colors.txtSec, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Records View
        Expanded(
          child: isSingleDay 
            ? _buildDailyView(visiblePeople, visibleRecords)
            : _buildRangeView(visiblePeople, visibleRecords),
        ),
      ],
    );
  }

  // --- Grouped Daily View ---
  Widget _buildDailyView(List<dynamic> people, List<Attendance> records) {
    if (people.isEmpty) return Center(child: Text('No personnel found.', style: TextStyle(color: context.colors.txtMuted)));

    // Sort: Present first, then Absent
    people.sort((a, b) {
      final aPresent = records.any((r) => r.guardId == a.id);
      final bPresent = records.any((r) => r.guardId == b.id);
      if (aPresent && !bPresent) return -1;
      if (!aPresent && bPresent) return 1;
      return a.name.compareTo(b.name);
    });

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: people.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final person = people[i];
        final record = records.where((r) => r.guardId == person.id).firstOrNull;
        
        final isPresent = record != null && record.status.toLowerCase() == 'present';
        final hasCheckOut = record != null && record.checkOutTime.isNotEmpty;
        final color = isPresent ? context.colors.green : context.colors.red;

        return Card(
          color: context.colors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color.withValues(alpha: 0.2),
                      backgroundImage: (person.photo != null && person.photo.toString().length > 200) ? MemoryImage(base64Decode(person.photo)) : null,
                      child: (person.photo == null || person.photo.toString().length <= 200) ? Icon(Icons.person, color: color) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                          Text(person is Guard ? 'Guard • ID: ${person.empId}' : '${(person as AppUser).role.replaceAll('_', ' ').toUpperCase()}', 
                               style: TextStyle(color: context.colors.txtMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        isPresent ? 'PRESENT' : 'ABSENT',
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (isPresent) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.colors.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text('Check-In', style: TextStyle(fontSize: 10, color: context.colors.txtMuted)),
                              Text(record.time.isNotEmpty ? record.time : '--:--', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.colors.green)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 24, color: context.colors.bord),
                        Expanded(
                          child: Column(
                            children: [
                              Text('Check-Out', style: TextStyle(fontSize: 10, color: context.colors.txtMuted)),
                              Text(hasCheckOut ? record.checkOutTime : '--:--', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: hasCheckOut ? context.colors.yellow : context.colors.txtMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Grouped Range/Monthly View ---
  Widget _buildRangeView(List<dynamic> people, List<Attendance> records) {
    if (people.isEmpty) return Center(child: Text('No personnel found.', style: TextStyle(color: context.colors.txtMuted)));

    final int totalDays = _endDate.difference(_startDate).inDays + 1;

    // Sort by presence
    people.sort((a, b) {
      final aCount = records.where((r) => r.guardId == a.id).length;
      final bCount = records.where((r) => r.guardId == b.id).length;
      return bCount.compareTo(aCount);
    });

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: people.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final person = people[i];
        final pRecords = records.where((r) => r.guardId == person.id).toList();
        final presentCount = pRecords.length;
        final absentCount = totalDays - presentCount;
        final double score = (presentCount / max(1, totalDays)) * 100;
        
        Color scoreColor = context.colors.red;
        if (score >= 80) scoreColor = context.colors.green;
        else if (score >= 50) scoreColor = context.colors.yellow;

        return Card(
          color: context.colors.bgSurface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scoreColor.withValues(alpha: 0.2),
                  backgroundImage: (person.photo != null && person.photo.toString().length > 200) ? MemoryImage(base64Decode(person.photo)) : null,
                  child: (person.photo == null || person.photo.toString().length <= 200) ? Icon(Icons.person, color: scoreColor) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('$presentCount Present', style: TextStyle(color: context.colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('$absentCount Absent', style: TextStyle(color: context.colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${score.toStringAsFixed(0)}%', style: TextStyle(color: scoreColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Credibility', style: TextStyle(color: context.colors.txtMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
            Text(title, style: TextStyle(color: context.colors.txtSec, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

int max(int a, int b) => a > b ? a : b;
