import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final DateTime _selectedDate = DateTime.now();

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

  // ── Date range mode ───────────────────────────────────────────────────────
  bool _isRangeMode = false;
  DateTime? _rangeFromDate;
  DateTime? _rangeToDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.selectedDate;
    _checkInTime = const TimeOfDay(hour: 9, minute: 0);
  }

  void _initData(List<Attendance> attendanceList) {
    if (_isInitialized) return;
    _isInitialized = true;
    final personId = widget.person.id;
    final myRecords = attendanceList.where((r) => r.guardId == personId).toList();
    _existingRecord = myRecords.firstOrNull;

    if (_existingRecord != null) {
      _status = _existingRecord!.status;
      if (_status.toLowerCase() == 'present') {
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
      _checkInTime = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  int get _rangeDays {
    if (_rangeFromDate == null || _rangeToDate == null) return 0;
    return _rangeToDate!.difference(_rangeFromDate!).inDays + 1;
  }

  // ── Date pickers ──────────────────────────────────────────────────────────

  Future<void> _pickSingleDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: _datePickerTheme,
    );
    if (d != null) {
      setState(() {
        _currentDate = d;
        _isInitialized = false;
      });
    }
  }

  Future<void> _pickRangeFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _rangeFromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _rangeToDate ?? DateTime.now(),
      builder: _datePickerTheme,
    );
    if (d != null) setState(() => _rangeFromDate = d);
  }

  Future<void> _pickRangeTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _rangeToDate ?? DateTime.now(),
      firstDate: _rangeFromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: _datePickerTheme,
    );
    if (d != null) setState(() => _rangeToDate = d);
  }

  Widget Function(BuildContext, Widget?) get _datePickerTheme =>
      (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: context.colors.primary,
                onPrimary: Colors.white,
                surface: context.colors.bgSurface,
                onSurface: context.colors.txtPrimary,
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: context.colors.bgSurface,
              ),
            ),
            child: child!,
          );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final personName = widget.person.name;
    final dateStr = DateFormat('yyyy-MM-dd').format(_currentDate);
    final attAsync = ref.watch(attendanceForDateProvider(dateStr));

    // In range mode we skip the existing-record lookup (batch insert only)
    if (_isRangeMode) {
      return _buildRangeModeForm(personName);
    }

    return attAsync.when(
      data: (attendanceList) {
        _initData(attendanceList);
        return _buildSingleDayForm(personName);
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

  // ── Single-day form (original behaviour) ─────────────────────────────────

  Widget _buildSingleDayForm(String personName) {
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
          _buildHeader(personName),
          const SizedBox(height: 8),

          // ── Single date row ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'For $personName on ${DateFormat('MMM dd, yyyy').format(_currentDate)}',
                  style: TextStyle(color: context.colors.txtSec),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                ),
                onPressed: _pickSingleDate,
                icon: Icon(Icons.edit_calendar, color: context.colors.primary, size: 18),
                label: Text('Change', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          // ── Range mode toggle ─────────────────────────────────────────────
          _buildRangeToggle(),
          const SizedBox(height: 16),

          _buildStatusButtons(),
          const SizedBox(height: 24),

          if (_status == 'Present') ...[
            _buildTimePicker(
              label: 'Check-In Time:',
              time: _checkInTime,
              onPick: (t) => setState(() => _checkInTime = t),
            ),
            const Divider(),
            _buildTimePicker(
              label: 'Check-Out Time:',
              time: _checkOutTime,
              placeholder: 'Not Checked Out',
              onPick: (t) => setState(() => _checkOutTime = t),
            ),
            const SizedBox(height: 24),
          ],

          _buildSubmitButton('Save Attendance', _submit),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Date-range form (batch mode) ─────────────────────────────────────────

  Widget _buildRangeModeForm(String personName) {
    final canSubmit = _rangeFromDate != null && _rangeToDate != null;
    final fmt = DateFormat('MMM dd, yyyy');

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
          _buildHeader(personName),
          const SizedBox(height: 4),
          Text(
            'Select a date range to mark attendance for multiple days at once.',
            style: TextStyle(color: context.colors.txtSec, fontSize: 13),
          ),

          // ── Range mode toggle ─────────────────────────────────────────────
          _buildRangeToggle(),
          const SizedBox(height: 20),

          // ── From / To date pickers ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildDateTile(
                  label: 'FROM',
                  value: _rangeFromDate != null ? fmt.format(_rangeFromDate!) : 'Select date',
                  icon: Icons.calendar_today,
                  onTap: _pickRangeFrom,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward, color: context.colors.txtMuted, size: 18),
              ),
              Expanded(
                child: _buildDateTile(
                  label: 'TO',
                  value: _rangeToDate != null ? fmt.format(_rangeToDate!) : 'Select date',
                  icon: Icons.event,
                  onTap: _pickRangeTo,
                ),
              ),
            ],
          ),

          if (canSubmit) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: context.colors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$_rangeDays day${_rangeDays == 1 ? '' : 's'} selected  •  Existing records will be skipped',
                    style: TextStyle(color: context.colors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          _buildStatusButtons(),
          const SizedBox(height: 24),

          if (_status == 'Present') ...[
            _buildTimePicker(
              label: 'Check-In Time (applied to all days):',
              time: _checkInTime,
              onPick: (t) => setState(() => _checkInTime = t),
            ),
            const Divider(),
            _buildTimePicker(
              label: 'Check-Out Time (applied to all days):',
              time: _checkOutTime,
              placeholder: 'Not Checked Out',
              onPick: (t) => setState(() => _checkOutTime = t),
            ),
            const SizedBox(height: 24),
          ],

          _buildSubmitButton(
            canSubmit ? 'Save for $_rangeDays Day${_rangeDays == 1 ? '' : 's'}' : 'Select Date Range',
            canSubmit ? _submitRange : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildHeader(String personName) {
    return Text('Mark Attendance — $personName',
        style: TextStyle(
            color: context.colors.txtPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold));
  }

  Widget _buildRangeToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => setState(() {
          _isRangeMode = !_isRangeMode;
          if (_isRangeMode) {
            // Pre-fill range with today as default
            _rangeToDate = DateTime.now();
            _rangeFromDate = DateTime.now().subtract(const Duration(days: 1));
          }
        }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isRangeMode
                ? context.colors.primary.withValues(alpha: 0.12)
                : context.colors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isRangeMode ? context.colors.primary : context.colors.bord,
              width: _isRangeMode ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.date_range,
                color: _isRangeMode ? context.colors.primary : context.colors.txtSec,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark for Multiple Days',
                      style: TextStyle(
                        color: _isRangeMode ? context.colors.primary : context.colors.txtPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Select a date range instead of a single date',
                      style: TextStyle(color: context.colors.txtMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isRangeMode,
                onChanged: (v) => setState(() {
                  _isRangeMode = v;
                  if (v) {
                    _rangeToDate = DateTime.now();
                    _rangeFromDate = DateTime.now().subtract(const Duration(days: 1));
                  }
                }),
                activeThumbColor: context.colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.bord),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: context.colors.txtMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, color: context.colors.primary, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(value,
                      style: TextStyle(
                          color: context.colors.txtPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButtons() {
    return Row(
      children: [
        Expanded(child: _buildStatusBtn('Present', context.colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatusBtn('Absent', context.colors.red)),
      ],
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? time,
    required Function(TimeOfDay) onPick,
    String placeholder = 'Select Time',
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: context.colors.txtPrimary, fontWeight: FontWeight.bold))),
        TextButton.icon(
          onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
            if (t != null) onPick(t);
          },
          icon: Icon(Icons.access_time, color: context.colors.primary),
          label: Text(time?.format(context) ?? placeholder, style: TextStyle(color: context.colors.primary)),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(String label, VoidCallback? onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: context.colors.bgBase,
        backgroundColor: context.colors.primary,
        disabledBackgroundColor: context.colors.primary.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isSubmitting ? null : onPressed,
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          color: isSelected ? color.withValues(alpha: 0.15) : context.colors.bgSurface,
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

  // ── Submit: single day ────────────────────────────────────────────────────

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
      final timeStr = _formatTime(_checkInTime);
      final checkOutStr = _formatTime(_checkOutTime);
      final personId = widget.person.id;

      if (_existingRecord != null) {
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
        await _createRecord(db, admin, personId, dateStr, timeStr, checkOutStr);
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

  // ── Submit: date range (batch) ────────────────────────────────────────────

  Future<void> _submitRange() async {
    if (_rangeFromDate == null || _rangeToDate == null) return;
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

      final personId = widget.person.id;
      final timeStr = _formatTime(_checkInTime);
      final checkOutStr = _formatTime(_checkOutTime);

      // Fetch existing attendance for this person to detect duplicates
      final existingSnap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('guardId', isEqualTo: personId)
          .get();
      final existingDates = existingSnap.docs
          .map((d) => d.data()['date'] as String? ?? '')
          .toSet();

      int saved = 0;
      int skipped = 0;

      // Iterate every day in the range
      DateTime cursor = DateTime(_rangeFromDate!.year, _rangeFromDate!.month, _rangeFromDate!.day);
      final end = DateTime(_rangeToDate!.year, _rangeToDate!.month, _rangeToDate!.day);

      while (!cursor.isAfter(end)) {
        final dateStr = DateFormat('yyyy-MM-dd').format(cursor);

        if (existingDates.contains(dateStr)) {
          skipped++;
        } else {
          await _createRecord(db, admin, personId, dateStr, timeStr, checkOutStr);
          saved++;
        }
        cursor = cursor.add(const Duration(days: 1));
      }

      if (mounted) {
        Navigator.pop(context);
        final msg = skipped > 0
            ? 'Saved $saved day${saved == 1 ? '' : 's'}. Skipped $skipped (already had record).'
            : 'Attendance saved for $saved day${saved == 1 ? '' : 's'}!';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: context.colors.green,
            duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: context.colors.red));
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ── Shared record creation helper ─────────────────────────────────────────

  Future<void> _createRecord(
    dynamic db,
    dynamic admin,
    String personId,
    String dateStr,
    String timeStr,
    String checkOutStr,
  ) async {
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
}
