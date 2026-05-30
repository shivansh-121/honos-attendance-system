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

class ExportHubScreen extends ConsumerStatefulWidget {
  const ExportHubScreen({super.key});

  @override
  ConsumerState<ExportHubScreen> createState() => _ExportHubScreenState();
}

class _ExportHubScreenState extends ConsumerState<ExportHubScreen> {
  // Excel Export State
  DateTime _excelMonth = DateTime.now();
  bool _includeGuards = true;
  bool _includeSupervisors = true;
  bool _includeExecutives = true;
  bool _includeEmployees = true;
  bool _isExportingExcel = false;

  // PDF Export State
  DateTime _pdfMonth = DateTime.now();
  dynamic _selectedPdfUser; // Can be Guard or AppUser
  bool _isExportingPdf = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
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

  Widget _buildExcelTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Select Month', Icons.calendar_month),
          const SizedBox(height: 12),
          _buildMonthSelector(
            currentMonth: _excelMonth,
            onMonthChanged: (m) => setState(() => _excelMonth = m),
          ),
          const SizedBox(height: 32),
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
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isExportingExcel ? null : _exportExcel,
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
                  _isExportingExcel
                      ? 'Generating Ledger...'
                      : 'Download Excel Ledger',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

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
          child: _buildSectionHeader('Select Month', Icons.calendar_month),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildMonthSelector(
            currentMonth: _pdfMonth,
            onMonthChanged: (m) => setState(() {
              _pdfMonth = m;
              _selectedPdfUser = null; // reset user on month change
            }),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              _buildSectionHeader('Select Staff Member', Icons.person_search),
        ),
        const SizedBox(height: 12),
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
                    final name = isGuard ? staff.name : (staff as AppUser).name;
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
                        onTap: () => setState(() => _selectedPdfUser = staff),
                        leading: CircleAvatar(
                          backgroundColor:
                              context.colors.primary.withValues(alpha: 0.2),
                          child: Icon(isGuard ? Icons.security : Icons.person,
                              color: context.colors.primary, size: 20),
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
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.bgSurface,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10)
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: (_isExportingPdf || _selectedPdfUser == null)
                  ? null
                  : _exportPdf,
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
                  _isExportingPdf ? 'Generating PDF...' : 'Download PDF',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _buildMonthSelector(
      {required DateTime currentMonth,
      required Function(DateTime) onMonthChanged}) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: currentMonth,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDatePickerMode: DatePickerMode.year,
        );
        if (date != null) {
          onMonthChanged(date);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.bord),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(currentMonth),
              style: TextStyle(
                  color: context.colors.txtPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            Icon(Icons.arrow_drop_down, color: context.colors.txtSec),
          ],
        ),
      ),
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

  Future<void> _exportExcel() async {
    if (!_includeGuards &&
        !_includeSupervisors &&
        !_includeExecutives &&
        !_includeEmployees) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Please select at least one role.'),
          backgroundColor: context.colors.red));
      return;
    }

    setState(() => _isExportingExcel = true);
    try {
      final guards = ref.read(guardsStreamProvider).value ?? [];
      final users = ref.read(usersStreamProvider).value ?? [];

      await ExcelService.exportCentralLedger(
        month: _excelMonth,
        allGuards: guards,
        allUsers: users,
        includeGuards: _includeGuards,
        includeSupervisors: _includeSupervisors,
        includeExecutives: _includeExecutives,
        includeEmployees: _includeEmployees,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: context.colors.red));
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_selectedPdfUser == null) return;

    setState(() => _isExportingPdf = true);
    try {
      final db = FirebaseFirestore.instance;
      final isGuard = _selectedPdfUser is Guard;
      final userId = isGuard
          ? (_selectedPdfUser as Guard).id
          : (_selectedPdfUser as AppUser).id;

      // Fetch attendance
      final attSnap = await db
          .collection('attendance')
          .where('guardId', isEqualTo: userId)
          .get();
      final records = attSnap.docs
          .map<Attendance>((d) => Attendance.fromJson(d.data()))
          .where((r) {
        final date = DateTime.tryParse(r.markedAt) ?? DateTime.tryParse(r.date);
        return date != null &&
            date.year == _pdfMonth.year &&
            date.month == _pdfMonth.month;
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
            date.year == _pdfMonth.year &&
            date.month == _pdfMonth.month;
      }).toList();

      // Fetch dicts
      final sites = ref.read(sitesStreamProvider).value ?? [];
      final siteNames = {for (var s in sites) s.id: s.name};
      final users = ref.read(usersStreamProvider).value ?? [];
      final userNames = {for (var u in users) u.id: u.name};

      if (isGuard) {
        await PdfService.generateAndPrintGuardReport(
          guard: _selectedPdfUser as Guard,
          month: _pdfMonth,
          attendanceRecords: records,
          siteNames: siteNames,
          supervisorNames: userNames,
          monthAdvances: advances,
        );
      } else {
        await PdfService.generateAndPrintSupervisorReport(
          supervisor: _selectedPdfUser as AppUser,
          month: _pdfMonth,
          attendanceRecords: records,
          siteNames: siteNames,
          supervisorNames: userNames,
          monthAdvances: advances,
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: context.colors.red));
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }
}
