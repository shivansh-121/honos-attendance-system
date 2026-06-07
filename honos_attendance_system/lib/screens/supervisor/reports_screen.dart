import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../models/attendance.dart';
import '../../models/guard.dart';
import '../../models/app_user.dart';
import '../../models/site.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../services/app_nav.dart';
import '../admin/guard_profile_screen.dart';
import '../admin/supervisor_profile_screen.dart';

final dateRangeAttendanceProvider =
    StreamProvider.family<List<Attendance>, String>((ref, rangeStr) {
  final parts = rangeStr.split('|');
  return ref.read(dbProvider).attendanceStreamForDateRange(parts[0], parts[1]);
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
    final sitesAsync = ref.watch(sitesStreamProvider);

    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final monthStart = DateTime(_startDate.year, _startDate.month, 1);
    final monthEnd = DateTime(_startDate.year, _startDate.month + 1, 0);
    final fetchStart = monthStart;
    final fetchEnd = _endDate.isAfter(monthEnd) ? _endDate : monthEnd;

    final fetchStartStr = DateFormat('yyyy-MM-dd').format(fetchStart);
    final fetchEndStr = DateFormat('yyyy-MM-dd').format(fetchEnd);

    final attendanceAsync =
        ref.watch(dateRangeAttendanceProvider('$fetchStartStr|$fetchEndStr'));

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      body: guardsAsync.when(
        data: (guards) => usersAsync.when(
          data: (allUsers) => attendanceAsync.when(
            data: (allRecords) {
              final sites = sitesAsync.value ?? [];
              return _buildReportContent(user, isAdmin, guards, allUsers,
                  allRecords, sites, startStr, endStr);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(
                child: Text('Rec Error: $e',
                    style: TextStyle(color: context.colors.red))),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(
              child: Text('User Error: $e',
                  style: TextStyle(color: context.colors.red))),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(
            child: Text('Guard Error: $e',
                style: TextStyle(color: context.colors.red))),
      ),
    );
  }

  Widget _buildReportContent(
      AppUser? currentUser,
      bool isAdmin,
      List<Guard> guards,
      List<AppUser> allUsers,
      List<Attendance> fetchedRecords,
      List<Site> sites,
      String startStr,
      String endStr) {
    // 1. Get visibility permissions
    final isExecutive = currentUser?.role == 'executive';
    final isSupervisor = currentUser?.role == 'supervisor';
    final isOffice = currentUser?.role == 'office_employee';

    // Supervisor can only see records marked under them
    List<Attendance> filteredRecords = fetchedRecords;
    if (isSupervisor && currentUser != null) {
      filteredRecords = fetchedRecords
          .where((r) => r.supervisorId == currentUser.id)
          .toList();
    }

    // List of people the current user is allowed to see
    List<dynamic> visiblePeople = [];

    if (isOffice) {
      if (currentUser != null) visiblePeople.add(currentUser);
    } else {
      // Filter by role requested by user
      if (_userRoleFilter == 'All' || _userRoleFilter == 'Guards') {
        if (isSupervisor) {
          final rangeRecords = filteredRecords
              .where((r) =>
                  r.date.compareTo(startStr) >= 0 &&
                  r.date.compareTo(endStr) <= 0)
              .toList();
          final guardIds = rangeRecords.map((r) => r.guardId).toSet();
          visiblePeople.addAll(guards.where((g) => guardIds.contains(g.id)));
        } else {
          visiblePeople.addAll(guards);
        }
      }
      if ((isAdmin || isExecutive) &&
          (_userRoleFilter == 'All' || _userRoleFilter == 'Supervisors')) {
        visiblePeople.addAll(allUsers.where((u) => u.role == 'supervisor'));
      }
      if ((isAdmin || isExecutive) &&
          (_userRoleFilter == 'All' || _userRoleFilter == 'Office')) {
        visiblePeople
            .addAll(allUsers.where((u) => u.role == 'office_employee'));
      }
      if (isAdmin &&
          (_userRoleFilter == 'All' || _userRoleFilter == 'Executives')) {
        visiblePeople.addAll(allUsers.where((u) => u.role == 'executive'));
      }
    }

    final totalVisible = visiblePeople.length;
    final isSingleDay = _startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day;

    // Filter records for visible people (within the specifically selected date range for overall stats)
    final visibleRecords = filteredRecords
        .where((r) =>
            visiblePeople.any((p) => p.id == r.guardId) &&
            r.date.compareTo(startStr) >= 0 &&
            r.date.compareTo(endStr) <= 0)
        .toList();
    final presentCount = visibleRecords
        .where((r) => r.date == DateFormat('yyyy-MM-dd').format(_startDate))
        .length; // If single day

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          stretch: true,
          backgroundColor: context.colors.bgBase,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: isAdmin
              ? [
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.white),
                    tooltip: 'Clear All Records',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: context.colors.bgSurface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: Text('Clear All Records?',
                              style: TextStyle(
                                  color: context.colors.txtPrimary,
                                  fontWeight: FontWeight.bold)),
                          content: Text(
                              'This will permanently delete ALL attendance records from the database. This action cannot be undone.',
                              style: TextStyle(color: context.colors.txtSec)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Cancel',
                                    style: TextStyle(
                                        color: context.colors.txtSec))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: context.colors.red),
                              onPressed: () {
                                ref.read(dbProvider).clearAttendance();
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            const Text('All records deleted.'),
                                        backgroundColor: context.colors.red));
                              },
                              child: Text('Delete All',
                                  style: TextStyle(
                                      color: context.colors.txtPrimary,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ]
              : null,
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [
              StretchMode.zoomBackground,
              StretchMode.blurBackground
            ],
            titlePadding:
                const EdgeInsets.only(left: 24, bottom: 20, right: 24),
            title: const Text('Reports',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5)),
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1B3B60), context.colors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 40,
                  child: Transform.rotate(
                    angle: 0.2,
                    child: Icon(Icons.bar_chart_rounded,
                        size: 140, color: Colors.white.withValues(alpha: 0.15)),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: responsiveBody(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildSummaryCard('Personnel', '$totalVisible',
                          Icons.people, context.colors.primary),
                      const SizedBox(width: 12),
                      _buildSummaryCard('Records', '${visibleRecords.length}',
                          Icons.history, context.colors.purple),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        isSingleDay ? 'Present' : 'Avg/Day',
                        isSingleDay
                            ? '$presentCount'
                            : (visibleRecords.length /
                                    max(1,
                                        _endDate.difference(_startDate).inDays))
                                .toStringAsFixed(1),
                        Icons.check_circle,
                        context.colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFilterDropdown(
                      isAdmin: isAdmin, isExecutive: isExecutive),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.calendar_month,
                          color: context.colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSingleDay
                              ? DateFormat('EEEE, MMM dd, yyyy')
                                  .format(_startDate)
                              : '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                          style: TextStyle(
                              color: context.colors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            maxWidth: 1100,
          ),
        ),

        // Records View
        isSingleDay
            ? _buildDailyView(visiblePeople, visibleRecords, allUsers, sites)
            : _buildRangeView(visiblePeople, visibleRecords),
      ],
    );
  }

  // --- Grouped Daily View ---
  Widget _buildDailyView(List<dynamic> people, List<Attendance> records,
      List<AppUser> allUsers, List<Site> sites) {
    if (people.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
            child: Text('No personnel found.',
                style: TextStyle(
                    color: context.colors.txtMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.bold))),
      );
    }

    // Sort: Present first, then Absent
    people.sort((a, b) {
      final aPresent = records.any((r) => r.guardId == a.id);
      final bPresent = records.any((r) => r.guardId == b.id);
      if (aPresent && !bPresent) return -1;
      if (!aPresent && bPresent) return 1;
      return a.name.compareTo(b.name);
    });

    return ResponsiveSliverPadding(
      extraPadding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final person = people[i];
            final personRecords =
                records.where((r) => r.guardId == person.id).toList();
            personRecords.sort((a, b) => a.time.compareTo(b.time));

            final isPresent = personRecords.isNotEmpty &&
                personRecords.any((r) => r.status.toLowerCase() == 'present');
            final color = isPresent ? context.colors.green : context.colors.red;

            return GestureDetector(
              onTap: () {
                if (person is Guard) {
                  AppNav.push(context, GuardProfileScreen(guard: person));
                } else if (person is AppUser &&
                    (person.role == 'supervisor' ||
                        person.role == 'office_employee' ||
                        person.role == 'executive')) {
                  AppNav.push(
                      context, SupervisorProfileScreen(supervisor: person));
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.colors.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: context.colors.bord.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: color.withValues(alpha: 0.5),
                                    width: 2)),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: color.withValues(alpha: 0.1),
                              backgroundImage: (person.photo != null &&
                                      person.photo.toString().length > 200)
                                  ? MemoryImage(base64Decode(person.photo))
                                  : null,
                              child: (person.photo == null ||
                                      person.photo.toString().length <= 200)
                                  ? Icon(Icons.person, color: color)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(person.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: context.colors.txtPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                    person is Guard
                                        ? 'Guard • ID: ${person.empId}'
                                        : (person as AppUser).role.replaceAll('_', ' ').toUpperCase(),
                                    style: TextStyle(
                                        color: context.colors.txtMuted,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              isPresent ? 'PRESENT' : 'ABSENT',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                      if (isPresent) ...[
                        const SizedBox(height: 12),
                        ...personRecords.map((record) {
                          final hasCheckOut = record.checkOutTime.isNotEmpty;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: context.colors.bgElevated,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text('Check-In',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      context.colors.txtMuted,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(
                                              record.time.isNotEmpty
                                                  ? record.time
                                                  : '--:--',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: context.colors.green)),
                                          const SizedBox(height: 4),
                                          Text(
                                              sites
                                                      .where((s) =>
                                                          s.id == record.siteId)
                                                      .firstOrNull
                                                      ?.name ??
                                                  'Unknown',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      context.colors.txtMuted),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          if (record.photoPath == 'manual' ||
                                              record.photoPath.isEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                  (record.supervisorId ==
                                                              'admin' ||
                                                          record.supervisorId
                                                              .isNotEmpty)
                                                      ? 'BY ${record.supervisorId == 'admin' ? 'ADMIN' : (allUsers.where((u) => u.id == record.supervisorId).firstOrNull?.name.split(' ').first.toUpperCase() ?? 'ADMIN')}'
                                                      : 'MANUAL',
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color:
                                                          context.colors.yellow,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            )
                                        ],
                                      ),
                                    ),
                                    Container(
                                        width: 1,
                                        height: 50,
                                        color: context.colors.bord),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text('Check-Out',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      context.colors.txtMuted,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(
                                              hasCheckOut
                                                  ? record.checkOutTime
                                                  : '--:--',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: hasCheckOut
                                                      ? context.colors.yellow
                                                      : context
                                                          .colors.txtMuted)),
                                          if (hasCheckOut) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                                record.checkOutSiteId.isNotEmpty
                                                    ? (sites
                                                            .where((s) =>
                                                                s.id ==
                                                                record
                                                                    .checkOutSiteId)
                                                            .firstOrNull
                                                            ?.name ??
                                                        'Unknown')
                                                    : (sites
                                                            .where((s) =>
                                                                s.id ==
                                                                record.siteId)
                                                            .firstOrNull
                                                            ?.name ??
                                                        'Unknown'),
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: context
                                                        .colors.txtMuted),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            if (record.checkOutPhotoPath ==
                                                    'manual' ||
                                                record
                                                    .checkOutPhotoPath.isEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text('MANUAL',
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        color: context
                                                            .colors.yellow,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              )
                                          ]
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: people.length,
        ),
      ),
    );
  }

  // --- Grouped Range/Monthly View ---
  Widget _buildRangeView(List<dynamic> people, List<Attendance> records) {
    if (people.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
            child: Text('No personnel found.',
                style: TextStyle(
                    color: context.colors.txtMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.bold))),
      );
    }

    final String startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final String endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    final fetchedRecords = records;

    final selectedTotalDays = _endDate.difference(_startDate).inDays + 1;
    final monthStartStr = DateFormat('yyyy-MM-dd')
        .format(DateTime(_startDate.year, _startDate.month, 1));
    final monthEndStr = DateFormat('yyyy-MM-dd')
        .format(DateTime(_startDate.year, _startDate.month + 1, 0));
    final daysInMonth = DateTime(_startDate.year, _startDate.month + 1, 0).day;

    // Sort people by the number of present days in the selected range
    people.sort((a, b) {
      final aCount = fetchedRecords
          .where((r) =>
              r.guardId == a.id &&
              r.date.compareTo(startStr) >= 0 &&
              r.date.compareTo(endStr) <= 0)
          .length;
      final bCount = fetchedRecords
          .where((r) =>
              r.guardId == b.id &&
              r.date.compareTo(startStr) >= 0 &&
              r.date.compareTo(endStr) <= 0)
          .length;
      return bCount.compareTo(aCount);
    });

    return ResponsiveSliverPadding(
      extraPadding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final person = people[i];

            // Monthly records for score
            final pMonthRecords = fetchedRecords
                .where((r) =>
                    r.guardId == person.id &&
                    r.date.compareTo(monthStartStr) >= 0 &&
                    r.date.compareTo(monthEndStr) <= 0)
                .toList();

            // Selected range records for chips
            final pSelectedRecords = fetchedRecords
                .where((r) =>
                    r.guardId == person.id &&
                    r.date.compareTo(startStr) >= 0 &&
                    r.date.compareTo(endStr) <= 0)
                .toList();

            final presentCount =
                pSelectedRecords.map((r) => r.date).toSet().length;
            final absentCount = selectedTotalDays - presentCount;

            final monthPresentCount =
                pMonthRecords.map((r) => r.date).toSet().length;
            final double score = (monthPresentCount / daysInMonth) * 100;

            Color scoreColor = context.colors.red;
            if (score >= 80) {
              scoreColor = context.colors.green;
            } else if (score >= 50) {
              scoreColor = context.colors.yellow;
            }

            return GestureDetector(
              onTap: () {
                if (person is Guard) {
                  AppNav.push(context, GuardProfileScreen(guard: person));
                } else if (person is AppUser &&
                    (person.role == 'supervisor' ||
                        person.role == 'office_employee' ||
                        person.role == 'executive')) {
                  AppNav.push(
                      context, SupervisorProfileScreen(supervisor: person));
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.colors.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: context.colors.bord.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                        color: scoreColor.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: scoreColor.withValues(alpha: 0.5),
                                width: 2)),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: scoreColor.withValues(alpha: 0.1),
                          backgroundImage: (person.photo != null &&
                                  person.photo.toString().length > 200)
                              ? MemoryImage(base64Decode(person.photo))
                              : null,
                          child: (person.photo == null ||
                                  person.photo.toString().length <= 200)
                              ? Icon(Icons.person, color: scoreColor)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(person.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: context.colors.txtPrimary)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: context.colors.green
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text('$presentCount Present',
                                      style: TextStyle(
                                          color: context.colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: context.colors.red
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text('$absentCount Absent',
                                      style: TextStyle(
                                          color: context.colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${score.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: scoreColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900)),
                          Text('Attendance',
                              style: TextStyle(
                                  color: context.colors.txtMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: people.length,
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
      {required bool isAdmin, required bool isExecutive}) {
    final roleOptions = [
      'All',
      'Guards',
      'Supervisors',
      'Office',
      if (isAdmin) 'Executives'
    ];
    final roleAllowed = isAdmin || isExecutive;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.bord),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.tune, color: context.colors.primary),
          title: Text(
            'Filters',
            style: TextStyle(
                color: context.colors.txtPrimary, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            roleAllowed
                ? '$_selectedFilter • $_userRoleFilter'
                : _selectedFilter,
            style: TextStyle(color: context.colors.txtMuted, fontSize: 12),
          ),
          iconColor: context.colors.primary,
          collapsedIconColor: context.colors.txtSec,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 640;
                final fieldWidth = twoColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _buildFilterField(
                        label: 'Date Range',
                        icon: Icons.calendar_month,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedFilter,
                          dropdownColor: context.colors.bgSurface,
                          iconEnabledColor: context.colors.txtSec,
                          decoration:
                              const InputDecoration(border: InputBorder.none),
                          style: TextStyle(
                              color: context.colors.txtPrimary,
                              fontWeight: FontWeight.w600),
                          items: _filters
                              .map((f) =>
                                  DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            if (value == 'Custom') {
                              await _pickCustomRange();
                            } else {
                              _selectedFilter = value;
                              _updateDateRange();
                            }
                          },
                        ),
                      ),
                    ),
                    if (roleAllowed)
                      SizedBox(
                        width: fieldWidth,
                        child: _buildFilterField(
                          label: 'Personnel',
                          icon: Icons.people_alt,
                          child: DropdownButtonFormField<String>(
                            initialValue: _userRoleFilter,
                            dropdownColor: context.colors.bgSurface,
                            iconEnabledColor: context.colors.txtSec,
                            decoration:
                                const InputDecoration(border: InputBorder.none),
                            style: TextStyle(
                                color: context.colors.txtPrimary,
                                fontWeight: FontWeight.w600),
                            items: roleOptions
                                .map((role) => DropdownMenuItem(
                                    value: role, child: Text(role)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _userRoleFilter = value);
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterField(
      {required String label, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      decoration: BoxDecoration(
        color: context.colors.bgBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.bord.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.colors.txtMuted, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: context.colors.txtMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          child,
        ],
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
                style: TextStyle(color: context.colors.txtSec, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

int max(int a, int b) => a > b ? a : b;
