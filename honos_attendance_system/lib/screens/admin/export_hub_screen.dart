import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app_theme.dart';
import '../../services/excel_service.dart';
import '../../services/pdf_service.dart';
import '../../services/db_service.dart';
import '../../models/app_user.dart';
import '../../models/guard.dart';
import '../../models/attendance.dart';
import '../../models/advance.dart';
import '../../models/site.dart';

class ExportHubScreen extends ConsumerStatefulWidget {
  const ExportHubScreen({super.key});

  @override
  ConsumerState<ExportHubScreen> createState() => _ExportHubScreenState();
}

class _ExportHubScreenState extends ConsumerState<ExportHubScreen> {
  // ── Shared date range (defaults: 1st of current month → today) ──────────
  late DateTime _fromDate;
  late DateTime _toDate;

  // Excel Export State
  bool _includeGuards = true;
  bool _includeSupervisors = true;
  bool _includeExecutives = true;
  bool _includeEmployees = true;
  bool _isExportingExcel = false;
  String? _selectedExcelSiteId; // null = All Sites

  // PDF Export State
  dynamic _selectedPdfUser; // Can be Guard or AppUser
  bool _isExportingPdf = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _dateRangeLabel =>
      '${DateFormat('dd MMM yyyy').format(_fromDate)}  →  ${DateFormat('dd MMM yyyy').format(_toDate)}';

  int get _totalDays => _toDate.difference(_fromDate).inDays + 1;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(sitesStreamProvider);
    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        title: const Text('Central Export Hub',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: context.colors.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colors.txtPrimary),
        titleTextStyle: TextStyle(
            color: context.colors.txtPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold),
      ),
      body: DefaultTabController(
        length: 2,
        child: responsiveBody(
            Column(
              children: [
                // ── Date range picker (shared across both tabs) ──────────
                _buildDateRangeCard(),
                const SizedBox(height: 4),

                // ── Tab bar ───────────────────────────────────────────────
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.bord),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: context.colors.primary,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: context.colors.txtSec,
                    tabs: const [
                      Tab(text: 'Export Excel'),
                      Tab(text: 'Export PDF'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildExcelTab(),
                      _buildPdfTab(),
                    ],
                  ),
                ),
              ],
            ),
            maxWidth: 1100),
      ),
    );
  }

  // ── Date Range Card ───────────────────────────────────────────────────────

  Widget _buildDateRangeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: context.colors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Report Period',
                style: TextStyle(
                    color: context.colors.txtPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_totalDays day${_totalDays == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: context.colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildDatePickerTile(
                  label: 'From',
                  date: _fromDate,
                  icon: Icons.calendar_today,
                  onPicked: (picked) {
                    if (picked.isAfter(_toDate)) {
                      _showSnack('From date cannot be after To date.');
                      return;
                    }
                    setState(() {
                      _fromDate = picked;
                      _selectedPdfUser = null; // reset selection on range change
                    });
                  },
                  lastDate: _toDate,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward,
                    color: context.colors.txtMuted, size: 18),
              ),
              Expanded(
                child: _buildDatePickerTile(
                  label: 'To',
                  date: _toDate,
                  icon: Icons.event,
                  onPicked: (picked) {
                    if (picked.isBefore(_fromDate)) {
                      _showSnack('To date cannot be before From date.');
                      return;
                    }
                    setState(() {
                      _toDate = picked;
                      _selectedPdfUser = null;
                    });
                  },
                  firstDate: _fromDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Summary chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.bgBase,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.bord),
            ),
            child: Text(
              _dateRangeLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerTile({
    required String label,
    required DateTime date,
    required IconData icon,
    required void Function(DateTime) onPicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.bgBase,
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
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, color: context.colors.primary, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: TextStyle(
                        color: context.colors.txtPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Excel Tab ─────────────────────────────────────────────────────────────

  Widget _buildExcelTab() {
    final sitesAsync = ref.watch(sitesStreamProvider);
    final sites = sitesAsync.value ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Filter by Site', Icons.business),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.bord),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedExcelSiteId,
                isExpanded: true,
                dropdownColor: context.colors.bgSurface,
                style: TextStyle(color: context.colors.txtPrimary, fontSize: 15),
                icon: Icon(Icons.arrow_drop_down, color: context.colors.txtSec),
                onChanged: (val) => setState(() => _selectedExcelSiteId = val),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.public, color: context.colors.primary, size: 18),
                        const SizedBox(width: 10),
                        Text('All Sites',
                            style: TextStyle(
                                color: context.colors.txtPrimary,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  ...sites.map((Site s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: context.colors.txtSec, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(s.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: context.colors.txtPrimary)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Select Roles', Icons.people_alt),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.bord),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 620;
                final itemWidth = twoColumns
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    SizedBox(
                        width: itemWidth,
                        child: _buildRoleCheckbox('Guards', _includeGuards,
                            (v) => setState(() => _includeGuards = v!))),
                    SizedBox(
                        width: itemWidth,
                        child: _buildRoleCheckbox(
                            'Supervisors',
                            _includeSupervisors,
                            (v) => setState(() => _includeSupervisors = v!))),
                    SizedBox(
                        width: itemWidth,
                        child: _buildRoleCheckbox(
                            'Executives',
                            _includeExecutives,
                            (v) => setState(() => _includeExecutives = v!))),
                    SizedBox(
                        width: itemWidth,
                        child: _buildRoleCheckbox(
                            'Office Employees',
                            _includeEmployees,
                            (v) => setState(() => _includeEmployees = v!))),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isExportingExcel
                        ? null
                        : () => _exportExcel(false,
                            siteId: _selectedExcelSiteId),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: context.colors.bgBase,
                      backgroundColor: context.colors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isExportingExcel
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: Text(
                        _isExportingExcel ? 'Generating...' : 'Export Excel',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              if (Platform.isAndroid || Platform.isIOS) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isExportingExcel
                          ? null
                          : () => _exportExcel(true,
                              siteId: _selectedExcelSiteId),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: context.colors.primary,
                        backgroundColor: context.colors.bgSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: context.colors.primary, width: 2)),
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('Share',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── PDF Tab ───────────────────────────────────────────────────────────────

  Widget _buildPdfTab() {
    final guardsAsync = ref.watch(guardsStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);

    List<dynamic> allStaff = [];
    if (guardsAsync.value != null) allStaff.addAll(guardsAsync.value!);
    if (usersAsync.value != null) {
      allStaff.addAll(usersAsync.value!.where((u) => u.role != 'admin'));
    }

    final filteredStaff = allStaff.where((s) {
      final name = s is Guard ? s.name : (s as AppUser).name;
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: _buildSectionHeader('Select Staff Member', Icons.person_search),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: context.colors.txtPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name...',
              hintStyle: TextStyle(color: context.colors.txtMuted),
              prefixIcon: Icon(Icons.search, color: context.colors.txtSec),
              filled: true,
              fillColor: context.colors.bgSurface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: guardsAsync.isLoading || usersAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filteredStaff.length,
                  itemBuilder: (context, index) {
                    final staff = filteredStaff[index];
                    final isGuard = staff is Guard;
                    final id = isGuard ? staff.id : (staff as AppUser).id;
                    final name =
                        isGuard ? staff.name : (staff as AppUser).name;
                    String role = 'Guard';
                    if (!isGuard) {
                      final r = (staff as AppUser).role;
                      role = r[0].toUpperCase() + r.substring(1);
                    }

                    final isSelected = _selectedPdfUser != null &&
                        ((_selectedPdfUser is Guard &&
                                isGuard &&
                                _selectedPdfUser.id == id) ||
                            (_selectedPdfUser is AppUser &&
                                !isGuard &&
                                _selectedPdfUser.id == id));

                    return Card(
                      color: isSelected
                          ? context.colors.primary.withValues(alpha: 0.1)
                          : context.colors.bgSurface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: isSelected
                                ? context.colors.primary
                                : context.colors.bord),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () =>
                            setState(() => _selectedPdfUser = staff),
                        leading: CircleAvatar(
                          backgroundColor:
                              context.colors.primary.withValues(alpha: 0.2),
                          child: Icon(
                              isGuard ? Icons.security : Icons.person,
                              color: context.colors.primary,
                              size: 20),
                        ),
                        title: Text(name,
                            style: TextStyle(
                                color: context.colors.txtPrimary,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(role,
                            style: TextStyle(
                                color: context.colors.txtSec, fontSize: 12)),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: context.colors.primary)
                            : null,
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: context.colors.bgSurface,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10)
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: (_isExportingPdf || _selectedPdfUser == null)
                          ? null
                          : () => _exportPdf(false),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: context.colors.bgBase,
                        backgroundColor: context.colors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isExportingPdf
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(
                          _isExportingPdf ? 'Generating...' : 'Export PDF',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                if (Platform.isAndroid || Platform.isIOS) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isExportingPdf || _selectedPdfUser == null)
                                ? null
                                : () => _exportPdf(true),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: context.colors.primary,
                          backgroundColor: context.colors.bgSurface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: context.colors.primary, width: 2)),
                        ),
                        icon: const Icon(Icons.share),
                        label: const Text('Share',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Reusable Widgets ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: context.colors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: context.colors.txtPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRoleCheckbox(
      String title, bool value, Function(bool?) onChanged) {
    return Theme(
      data: Theme.of(context).copyWith(
        unselectedWidgetColor: context.colors.txtSec,
      ),
      child: CheckboxListTile(
        title: Text(title, style: TextStyle(color: context.colors.txtPrimary)),
        value: value,
        activeColor: context.colors.primary,
        checkColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: onChanged,
      ),
    );
  }

  // ── Export Logic ──────────────────────────────────────────────────────────

  Future<void> _exportExcel(bool share, {String? siteId}) async {
    if (!_includeGuards &&
        !_includeSupervisors &&
        !_includeExecutives &&
        !_includeEmployees) {
      _showSnack('Please select at least one role.', isError: true);
      return;
    }

    setState(() => _isExportingExcel = true);
    try {
      final guards = ref.read(guardsStreamProvider).value ?? [];
      final users = ref.read(usersStreamProvider).value ?? [];

      await ExcelService.exportCentralLedger(
        fromDate: _fromDate,
        toDate: _toDate,
        allGuards: guards,
        allUsers: users,
        includeGuards: _includeGuards,
        includeSupervisors: _includeSupervisors,
        includeExecutives: _includeExecutives,
        includeEmployees: _includeEmployees,
        siteId: siteId,
        share: share,
      );

      if (mounted) {
        _showSnack(share
            ? 'Ledger shared successfully'
            : 'Ledger exported successfully ($_dateRangeLabel)');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to export: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  Future<void> _exportPdf(bool share) async {
    if (_selectedPdfUser == null) return;

    setState(() => _isExportingPdf = true);
    try {
      final db = FirebaseFirestore.instance;
      final isGuard = _selectedPdfUser is Guard;
      final userId = isGuard
          ? (_selectedPdfUser as Guard).id
          : (_selectedPdfUser as AppUser).id;

      // Normalise range to midnight / end-of-day
      final rangeStart = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
      final rangeEnd   = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

      // Fetch attendance — guards are stored with guardId, supervisors/AppUsers with supervisorId
      final QuerySnapshot<Map<String, dynamic>> attSnap;
      if (isGuard) {
        attSnap = await db
            .collection('attendance')
            .where('guardId', isEqualTo: userId)
            .get();
      } else {
        attSnap = await db
            .collection('attendance')
            .where('supervisorId', isEqualTo: userId)
            .get();
      }
      final records = attSnap.docs
          .map<Attendance>((d) => Attendance.fromJson(d.data()))
          .where((r) {
        final date = DateTime.tryParse(r.markedAt.isNotEmpty ? r.markedAt : r.date);
        return date != null &&
            !date.isBefore(rangeStart) &&
            !date.isAfter(rangeEnd);
      }).toList();

      // Fetch advances
      final advSnap = await db
          .collection('advances')
          .where('userId', isEqualTo: userId)
          .get();
      final advances = advSnap.docs.map<Advance>((d) {
        final data = d.data();
        data['id'] = d.id;
        return Advance.fromJson(data);
      }).where((a) {
        final date = DateTime.tryParse(a.date);
        return date != null &&
            !date.isBefore(rangeStart) &&
            !date.isAfter(rangeEnd);
      }).toList();

      // Fetch dicts
      final sites = ref.read(sitesStreamProvider).value ?? [];
      final siteNames = {for (var s in sites) s.id: s.name};
      final users = ref.read(usersStreamProvider).value ?? [];
      final userNames = {for (var u in users) u.id: u.name};

      String? savePath;
      if (isGuard) {
        savePath = await PdfService.generateAndPrintGuardReport(
          guard: _selectedPdfUser as Guard,
          fromDate: _fromDate,
          toDate: _toDate,
          attendanceRecords: records,
          siteNames: siteNames,
          supervisorNames: userNames,
          monthAdvances: advances,
          share: share,
        );
      } else {
        savePath = await PdfService.generateAndPrintSupervisorReport(
          supervisor: _selectedPdfUser as AppUser,
          fromDate: _fromDate,
          toDate: _toDate,
          attendanceRecords: records,
          siteNames: siteNames,
          supervisorNames: userNames,
          monthAdvances: advances,
          share: share,
        );
      }

      if (!share && savePath != null && mounted) {
        _showSnack('Report saved to: $savePath');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to export: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? context.colors.red : context.colors.primary));
  }
}
