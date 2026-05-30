import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app_theme.dart';
import '../../models/guard.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';

class AdminManualAttendanceScreen extends ConsumerStatefulWidget {
  final String role; // 'executive', 'office_employee', 'guard', 'supervisor'
  const AdminManualAttendanceScreen({super.key, required this.role});

  @override
  ConsumerState<AdminManualAttendanceScreen> createState() =>
      _AdminManualAttendanceScreenState();
}

class _AdminManualAttendanceScreenState
    extends ConsumerState<AdminManualAttendanceScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final guardsAsync = ref.watch(guardsStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        title: const Text('Manual Attendance'),
        backgroundColor: context.colors.bgBase,
      ),
      body: responsiveBody(
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
                style: TextStyle(color: context.colors.txtPrimary),
                decoration: InputDecoration(
                  hintText: 'Search staff by name...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: context.colors.bgSurface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: Builder(
                builder: (ctx) {
                  if (guardsAsync.isLoading || usersAsync.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<dynamic> allStaff = [];

                  if (widget.role == 'guard') {
                    allStaff.addAll(guardsAsync.value ?? []);
                  } else {
                    allStaff.addAll((usersAsync.value ?? []).where((u) =>
                        u.role.toLowerCase() == widget.role.toLowerCase()));
                  }

                  final filtered = allStaff.where((p) {
                    return p.name.toLowerCase().contains(_searchQuery);
                  }).toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

                  if (filtered.isEmpty) {
                    return Center(
                        child: Text(
                            'No ${widget.role.replaceAll('_', ' ')}s found.',
                            style: TextStyle(color: context.colors.txtMuted)));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final person = filtered[i];
                      final isGuard = person is Guard;

                      return Card(
                        color: context.colors.bgSurface,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                context.colors.primary.withValues(alpha: 0.2),
                            backgroundImage: person.photo.isNotEmpty
                                ? NetworkImage(person.photo)
                                : null,
                            child: person.photo.isEmpty
                                ? Icon(isGuard ? Icons.security : Icons.person,
                                    color: context.colors.primary)
                                : null,
                          ),
                          title: Text(person.name,
                              style: TextStyle(
                                  color: context.colors.txtPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                                isGuard
                                    ? 'Guard'
                                    : (person as AppUser)
                                        .role
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                style: TextStyle(
                                    color: context.colors.txtSec, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          trailing: Icon(Icons.edit_calendar,
                              color: context.colors.primary),
                          onTap: () => _showManualAttendanceDialog(person),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        maxWidth: 700,
      ),
    );
  }

  void _showManualAttendanceDialog(dynamic person) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bgSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) =>
          responsiveBody(_ManualAttendanceForm(person: person), maxWidth: 560),
    );
  }
}

class _ManualAttendanceForm extends ConsumerStatefulWidget {
  final dynamic person;
  const _ManualAttendanceForm({required this.person});

  @override
  ConsumerState<_ManualAttendanceForm> createState() =>
      _ManualAttendanceFormState();
}

class _ManualAttendanceFormState extends ConsumerState<_ManualAttendanceForm> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final personName = widget.person.name;
    final personId = widget.person.id;

    // Watch today's attendance to see if they are checked in
    final todayAttAsync = ref.watch(todayAttendanceProvider);

    return todayAttAsync.when(
      data: (attendanceList) {
        final myRecordsForToday =
            attendanceList.where((r) => r.guardId == personId).toList();
        final openRecord =
            myRecordsForToday.where((r) => r.checkOutTime.isEmpty).firstOrNull;

        bool isCheckOut = openRecord != null;

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mark Attendance',
                  style: TextStyle(
                      color: context.colors.txtPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('For $personName',
                  style: TextStyle(color: context.colors.txtSec)),
              const SizedBox(height: 24),

              // Info Box showing current status
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: isCheckOut
                          ? context.colors.red.withValues(alpha: 0.1)
                          : context.colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(isCheckOut ? Icons.output : Icons.login,
                        color: isCheckOut
                            ? context.colors.red
                            : context.colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            isCheckOut
                                ? 'Status: Currently Checked-In since ${openRecord.time}'
                                : 'Status: Not Checked-In yet today (or shift completed)',
                            style: TextStyle(
                                color: isCheckOut
                                    ? context.colors.red
                                    : context.colors.green,
                                fontWeight: FontWeight.bold))),
                  ])),

              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: context.colors.bgBase,
                  backgroundColor:
                      isCheckOut ? context.colors.red : context.colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => _submit(isCheckOut, openRecord),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isCheckOut ? 'Mark Check-Out' : 'Mark Check-In',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(48.0),
        child: Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _submit(bool isCheckOut, Attendance? myRecord) async {
    setState(() => _isSubmitting = true);
    try {
      final db = ref.read(dbProvider);
      final admin = ref.read(authProvider);
      if (admin == null) throw Exception('Admin not logged in');

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);
      final personId = widget.person.id;

      if (isCheckOut) {
        if (myRecord == null)
          throw Exception('No Check-In found for this date. Cannot Check-Out.');

        final updated = Attendance(
          id: myRecord.id,
          guardId: myRecord.guardId,
          siteId: myRecord.siteId,
          supervisorId: myRecord.supervisorId, // Keep original supervisor
          date: myRecord.date,
          time: myRecord.time,
          status: myRecord.status,
          photoPath: myRecord.photoPath,
          markedAt: myRecord.markedAt,
          lat: myRecord.lat,
          lng: myRecord.lng,
          checkOutTime: timeStr,
          checkOutPhotoPath: '',
          checkOutSiteId: myRecord.checkOutSiteId,
        );
        await db.saveAttendance(updated);
      } else {
        // Find actual supervisor for this person's site
        String actualSupervisorId = admin.id;
        String pSiteId = '';
        if (widget.person is Guard) {
          pSiteId = (widget.person as Guard).siteId;
        } else if (widget.person is AppUser) {
          pSiteId = (widget.person as AppUser).siteId;
        }

        // We can safely read sites from the stream
        final sites = ref.read(sitesStreamProvider).value ?? [];
        try {
          final s = sites.firstWhere((x) => x.id == pSiteId);
          if (s.supervisorId.isNotEmpty) {
            actualSupervisorId = s.supervisorId;
          }
        } catch (_) {}

        final att = Attendance(
          id: const Uuid().v4(),
          guardId: personId,
          siteId: pSiteId.isEmpty ? 'admin_manual' : pSiteId,
          supervisorId: actualSupervisorId,
          date: dateStr,
          time: timeStr,
          status: 'Present',
          photoPath: '',
          markedAt: DateTime.now().toIso8601String(),
        );
        await db.saveAttendance(att);
      }

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Attendance marked manually!'),
            backgroundColor: context.colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: context.colors.red));
        setState(() => _isSubmitting = false);
      }
    }
  }
}
