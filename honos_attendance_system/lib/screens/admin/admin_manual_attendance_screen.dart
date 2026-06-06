import 'dart:convert';
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
  DateTime _selectedDate = DateTime.now();

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            backgroundImage: person.photo.startsWith('http')
                                ? NetworkImage(person.photo) as ImageProvider
                                : (person.photo.length > 200 ? MemoryImage(base64Decode(person.photo)) as ImageProvider : null),
                            child: person.photo.length < 200 && !person.photo.startsWith('http')
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
          responsiveBody(_ManualAttendanceForm(person: person, selectedDate: _selectedDate), maxWidth: 560),
    );
  }
}

class _ManualAttendanceForm extends ConsumerStatefulWidget {
  final dynamic person;
  final DateTime selectedDate;
  const _ManualAttendanceForm({required this.person, required this.selectedDate});

  @override
  ConsumerState<_ManualAttendanceForm> createState() =>
      _ManualAttendanceFormState();
}

class _ManualAttendanceFormState extends ConsumerState<_ManualAttendanceForm> {
  bool _isSubmitting = false;
  String _status = 'Present';
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;
  bool _isInitialized = false;
  Attendance? _existingRecord;
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.selectedDate;
  }

  void _initData(List<Attendance> attendanceList) {
    if (_isInitialized) return;
    _isInitialized = true;
    final personId = widget.person.id;
    final myRecords = attendanceList.where((r) => r.guardId == personId).toList();
    _existingRecord = myRecords.firstOrNull;

    if (_existingRecord != null) {
      _status = _existingRecord!.status;
      if (_status == 'Present') {
        if (_existingRecord!.time.isNotEmpty) {
          final parts = _existingRecord!.time.split(':');
          if (parts.length >= 2) {
            _checkInTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
          }
        }
        if (_existingRecord!.checkOutTime.isNotEmpty) {
          final parts = _existingRecord!.checkOutTime.split(':');
          if (parts.length >= 2) {
            _checkOutTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
          }
        }
      }
    } else {
      _status = 'Present';
      // Default to 09:00 AM if no record exists
      _checkInTime = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personName = widget.person.name;
    final dateStr = DateFormat('yyyy-MM-dd').format(_currentDate);
    final attAsync = ref.watch(attendanceForDateProvider(dateStr));

    return attAsync.when(
      data: (attendanceList) {
        _initData(attendanceList);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('For $personName on ${DateFormat('MMM dd, yyyy').format(_currentDate)}',
                        style: TextStyle(color: context.colors.txtSec)),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _currentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: context.colors.primary,
                                onPrimary: Colors.white,
                                surface: context.colors.bgSurface,
                                onSurface: context.colors.txtPrimary,
                              ),
                              dialogBackgroundColor: context.colors.bgSurface,
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (d != null) {
                        setState(() {
                          _currentDate = d;
                          _isInitialized = false; // re-fetch and re-init data
                        });
                      }
                    },
                    icon: Icon(Icons.edit_calendar, color: context.colors.primary, size: 18),
                    label: Text('Change', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Toggle
              Row(
                children: [
                  Expanded(
                    child: _buildStatusBtn('Present', context.colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusBtn('Absent', context.colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_status == 'Present') ...[
                // Check In Time
                Row(
                  children: [
                    Expanded(child: Text('Check-In Time:', style: TextStyle(color: context.colors.txtPrimary, fontWeight: FontWeight.bold))),
                    TextButton.icon(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: _checkInTime ?? TimeOfDay.now());
                        if (t != null) setState(() => _checkInTime = t);
                      },
                      icon: Icon(Icons.access_time, color: context.colors.primary),
                      label: Text(_checkInTime?.format(context) ?? 'Select Time', style: TextStyle(color: context.colors.primary)),
                    ),
                  ],
                ),
                const Divider(),
                // Check Out Time
                Row(
                  children: [
                    Expanded(child: Text('Check-Out Time:', style: TextStyle(color: context.colors.txtPrimary, fontWeight: FontWeight.bold))),
                    TextButton.icon(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: _checkOutTime ?? TimeOfDay.now());
                        if (t != null) setState(() => _checkOutTime = t);
                      },
                      icon: Icon(Icons.access_time, color: context.colors.primary),
                      label: Text(_checkOutTime?.format(context) ?? 'Not Checked Out', style: TextStyle(color: context.colors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: context.colors.bgBase,
                  backgroundColor: context.colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save Attendance',
                        style: TextStyle(
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

  Widget _buildStatusBtn(String label, Color color) {
    final isSelected = _status == label;
    return InkWell(
      onTap: () => setState(() => _status = label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : context.colors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : context.colors.bord,
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle, color: color, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: TextStyle(
                  color: isSelected ? color : context.colors.txtSec,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_status == 'Present' && _checkInTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Please select Check-In Time.'),
          backgroundColor: context.colors.red));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final db = ref.read(dbProvider);
      final admin = ref.read(authProvider);
      if (admin == null) throw Exception('Admin not logged in');

      final dateStr = DateFormat('yyyy-MM-dd').format(_currentDate);
      
      String formatTime(TimeOfDay? t) {
        if (t == null) return '';
        final h = t.hour.toString().padLeft(2, '0');
        final m = t.minute.toString().padLeft(2, '0');
        return '$h:$m:00';
      }

      final timeStr = formatTime(_checkInTime);
      final checkOutStr = formatTime(_checkOutTime);
      final personId = widget.person.id;

      if (_existingRecord != null) {
        // Update existing record
        final updated = Attendance(
          id: _existingRecord!.id,
          guardId: _existingRecord!.guardId,
          siteId: _existingRecord!.siteId,
          supervisorId: _existingRecord!.supervisorId,
          date: _existingRecord!.date,
          time: _status == 'Present' ? timeStr : '',
          status: _status,
          photoPath: _existingRecord!.photoPath,
          markedAt: _existingRecord!.markedAt,
          lat: _existingRecord!.lat,
          lng: _existingRecord!.lng,
          checkOutTime: _status == 'Present' ? checkOutStr : '',
          checkOutPhotoPath: _existingRecord!.checkOutPhotoPath,
          checkOutSiteId: _existingRecord!.checkOutSiteId,
        );
        await db.saveAttendance(updated);
      } else {
        // Create new record
        String actualSupervisorId = admin.id;
        String pSiteId = '';
        if (widget.person is Guard) {
          pSiteId = (widget.person as Guard).siteId;
        } else if (widget.person is AppUser) {
          pSiteId = (widget.person as AppUser).siteId;
        }

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
          time: _status == 'Present' ? timeStr : '',
          status: _status,
          photoPath: '',
          markedAt: DateTime.now().toIso8601String(),
          checkOutTime: _status == 'Present' ? checkOutStr : '',
        );
        await db.saveAttendance(att);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Attendance saved successfully!'),
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
