
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../services/db_service.dart';
import '../../widgets/base64_image_widget.dart';
import '../../models/guard.dart';
import '../../models/site.dart';
import 'guard_profile_screen.dart';
import '../supervisor/take_attendance_screen.dart';

class AdminGuardsManagementScreen extends ConsumerStatefulWidget {
  const AdminGuardsManagementScreen({super.key});

  @override
  ConsumerState<AdminGuardsManagementScreen> createState() =>
      _AdminGuardsManagementScreenState();
}

class _AdminGuardsManagementScreenState
    extends ConsumerState<AdminGuardsManagementScreen> {
  String _searchQuery = '';
  String? _selectedSiteFilter;
  String? _selectedSupervisorFilter;

  void _openGuardForm(BuildContext context, DbService db, List<Site> sites, {Guard? existing}) {
    if (sites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a Site first!')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AdminGuardFormSheet(
        db: db,
        allSites: sites,
        existing: existing,
        onSaved: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guardsAsync = ref.watch(guardsStreamProvider);
    final sitesAsync = ref.watch(sitesStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);
    final db = ref.read(dbProvider);

    return Scaffold(
      floatingActionButton: sitesAsync.whenOrNull(
        data: (sites) => FloatingActionButton.extended(
          onPressed: () => _openGuardForm(context, db, sites),
          icon: const Icon(Icons.person_add),
          label: const Text('Add Guard'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Guard Management',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppTheme.primaryDark.withValues(alpha: 0.5)),
                  const Icon(Icons.security, size: 100, color: Colors.white10),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or Employee ID...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppTheme.bgSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: sitesAsync.when(
                          data: (sites) {
                            final siteIds = sites.map((s) => s.id).toSet();
                            final safeSiteFilter = (siteIds.contains(_selectedSiteFilter)) ? _selectedSiteFilter : null;
                            return DropdownButtonFormField<String>(
                              initialValue: safeSiteFilter,
                              hint: const Text('Filter by Site', style: TextStyle(color: AppTheme.txtMuted, fontSize: 13)),
                            dropdownColor: AppTheme.bgSurface,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              fillColor: AppTheme.bgSurface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('All Sites')),
                              ...sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                            ],
                            onChanged: (val) => setState(() => _selectedSiteFilter = val),
                          );
                          },
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: usersAsync.when(
                          data: (users) {
                            final supervisors = users.where((u) => u.role == 'supervisor').toList();
                            final supIds = supervisors.map((s) => s.id).toSet();
                            final safeSupFilter = (supIds.contains(_selectedSupervisorFilter)) ? _selectedSupervisorFilter : null;
                            return DropdownButtonFormField<String>(
                              initialValue: safeSupFilter,
                              hint: const Text('Filter by Supervisor', style: TextStyle(color: AppTheme.txtMuted, fontSize: 13)),
                              dropdownColor: AppTheme.bgSurface,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                fillColor: AppTheme.bgSurface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                              items: [
                                const DropdownMenuItem<String>(value: null, child: Text('All Supervisors')),
                                ...supervisors.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                              ],
                              onChanged: (val) => setState(() => _selectedSupervisorFilter = val),
                            );
                          },
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          guardsAsync.when(
            data: (guards) {
              final sites = sitesAsync.value ?? [];
              final filtered = guards.where((g) {
                final matchQuery = g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    g.empId.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchSite = _selectedSiteFilter == null || g.siteId == _selectedSiteFilter;
                final matchSupervisor = _selectedSupervisorFilter == null || g.supervisorId == _selectedSupervisorFilter;
                return matchQuery && matchSite && matchSupervisor;
              }).toList();

              if (filtered.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('No guards found.', style: TextStyle(color: AppTheme.txtMuted)),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final g = filtered[index];
                      final siteName = sites.firstWhere((s) => s.id == g.siteId, orElse: () => const Site(id: '', name: 'Unknown Site', address: '', lat: 0, lng: 0, radius: 0)).name;

                      return attendanceAsync.when(
                        data: (attendance) {
                          final existingRecord = attendance.where((a) => a.guardId == g.id && a.status.toLowerCase() == 'present').lastOrNull;
                          final isCheckedIn = existingRecord != null && existingRecord.checkOutTime.isEmpty;
                          final isShiftCompleted = existingRecord != null && existingRecord.checkOutTime.isNotEmpty;
                          final isAbsent = existingRecord == null;

                          Color statusColor = AppTheme.red;
                          String statusText = 'Absent';
                          IconData statusIcon = Icons.cancel;

                          if (isShiftCompleted) {
                            statusColor = AppTheme.green;
                            statusText = 'Completed';
                            statusIcon = Icons.check_circle;
                          } else if (isCheckedIn) {
                            statusColor = AppTheme.yellow;
                            statusText = 'Active Shift';
                            statusIcon = Icons.timelapse;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GuardProfileScreen(guard: g))),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Hero(
                                          tag: 'avatar_${g.id}',
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(28),
                                            child: SizedBox(
                                              width: 56, height: 56,
                                              child: g.photo.length > 200
                                                  ? Base64ImageWidget(base64String: g.photo, fit: BoxFit.cover)
                                                  : Container(
                                                      color: AppTheme.primary.withValues(alpha: 0.2),
                                                      alignment: Alignment.center,
                                                      child: Text(g.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 22)),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                              const SizedBox(height: 4),
                                              Text('Site: $siteName', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                const Icon(Icons.badge, size: 14, color: AppTheme.txtMuted),
                                                const SizedBox(width: 4),
                                                Text(g.empId, style: const TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                                              ]),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: AppTheme.primary),
                                          tooltip: 'Edit Guard',
                                          onPressed: () => _openGuardForm(context, db, sites, existing: g),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24, color: AppTheme.bord),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.phone, size: 14, color: AppTheme.txtMuted),
                                          const SizedBox(width: 4),
                                          Text(g.phone.isEmpty ? 'N/A' : g.phone, style: const TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                                        ]),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                Icon(statusIcon, size: 14, color: statusColor),
                                                const SizedBox(width: 4),
                                                Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                                              ]),
                                            ),
                                            if (isAbsent) ...[
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () {
                                                  final site = sites.firstWhere((s) => s.id == g.siteId, orElse: () => const Site(id: '', name: '', address: '', lat: 0, lng: 0, radius: 0, supervisorId: ''));
                                                  if (site.id.isEmpty) return;
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TakeAttendanceScreen(site: site, isCheckOutFlow: false, preselectedGuard: g)));
                                                },
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32)),
                                                child: const Text('Check-In', style: TextStyle(fontSize: 11)),
                                              ),
                                            ] else if (isCheckedIn) ...[
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () {
                                                  final site = sites.firstWhere((s) => s.id == g.siteId, orElse: () => const Site(id: '', name: '', address: '', lat: 0, lng: 0, radius: 0, supervisorId: ''));
                                                  if (site.id.isEmpty) return;
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TakeAttendanceScreen(site: site, isCheckOutFlow: true, preselectedGuard: g, existingRecord: existingRecord)));
                                                },
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.yellow, padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32)),
                                                child: const Text('Check-Out', style: TextStyle(fontSize: 11, color: Colors.black)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, __) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
          ),
        ],
      ),
    );
  }
}

// ── Admin Guard Form Sheet ───────────────────────────────────────────────────
class _AdminGuardFormSheet extends StatefulWidget {
  final DbService db;
  final List<Site> allSites;
  final Guard? existing;
  final VoidCallback onSaved;

  const _AdminGuardFormSheet({
    required this.db,
    required this.allSites,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_AdminGuardFormSheet> createState() => _AdminGuardFormSheetState();
}

class _AdminGuardFormSheetState extends State<_AdminGuardFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name, _empId, _phone, _dob,
      _address, _aadhaar, _uan, _bank, _ifsc, _account, _branch, _salary, _details;

  Uint8List? _photoBytes;
  String _existingPhotoPath = '';
  String _selectedSiteId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _name     = TextEditingController(text: g?.name ?? '');
    _empId    = TextEditingController(text: g?.empId ?? '');
    _phone    = TextEditingController(text: g?.phone ?? '');
    _dob      = TextEditingController(text: g?.dob ?? '');
    _address  = TextEditingController(text: g?.address ?? '');
    _aadhaar  = TextEditingController(text: g?.aadharNo ?? '');
    _uan      = TextEditingController(text: g?.uanNo ?? '');
    _bank     = TextEditingController(text: g?.bankName ?? '');
    _ifsc     = TextEditingController(text: g?.ifsc ?? '');
    _account  = TextEditingController(text: g?.accountNo ?? '');
    _branch   = TextEditingController(text: g?.branch ?? '');
    _salary   = TextEditingController(text: g == null || g.salary == 0 ? '' : g.salary.toStringAsFixed(0));
    _details  = TextEditingController(text: g?.passbookPhoto ?? '');
    _existingPhotoPath = g?.photo ?? '';
    _selectedSiteId = g?.siteId ?? (widget.allSites.isNotEmpty ? widget.allSites.first.id : '');
    
    // Safety check in case the site was deleted
    if (!widget.allSites.any((s) => s.id == _selectedSiteId) && widget.allSites.isNotEmpty) {
      _selectedSiteId = widget.allSites.first.id;
    }
  }

  // Validation
  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length < 3) return 'At least 3 characters';
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) return 'Letters only';
    return null;
  }
  String? _validateEmpId(String? v) {
    if (v == null || v.trim().isEmpty) return 'Employee ID is required';
    if (v.contains(' ')) return 'No spaces allowed';
    return null;
  }
  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Exactly 10 digits';
    return null;
  }
  String? _validateAadhaar(String? v) {
    if (v == null || v.trim().isEmpty) return 'Aadhaar is required';
    if (!RegExp(r'^\d{12}$').hasMatch(v.trim())) return 'Exactly 12 digits';
    return null;
  }
  String? _validateIFSC(String? v) {
    if (v == null || v.trim().isEmpty) return 'IFSC is required';
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.trim().toUpperCase())) return 'Invalid — e.g. SBIN0001234';
    return null;
  }
  String? _validateAccountNo(String? v) {
    if (v == null || v.trim().isEmpty) return 'Account number is required';
    if (!RegExp(r'^\d{9,18}$').hasMatch(v.trim())) return '9–18 digits only';
    return null;
  }
  String? _validateSalary(String? v) {
    if (v == null || v.trim().isEmpty) return 'Salary is required';
    final d = double.tryParse(v.trim());
    if (d == null || d <= 0) return 'Enter a positive amount';
    return null;
  }

  // Photo
  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 500, maxHeight: 500, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _existingPhotoPath = base64Encode(bytes);
      _photoBytes = bytes;
    });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSurface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
            title: const Text('Take Photo with Camera'),
            onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppTheme.primary),
            title: const Text('Choose from Gallery'),
            onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.gallery); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // Save
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fix the errors above'), backgroundColor: AppTheme.red));
      return;
    }
    setState(() => _saving = true);
    
    final selectedSite = widget.allSites.firstWhere((s) => s.id == _selectedSiteId);

    final guard = Guard(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      empId: _empId.text.trim(),
      phone: _phone.text.trim(),
      dob: _dob.text.trim(),
      address: _address.text.trim(),
      aadharNo: _aadhaar.text.trim(),
      uanNo: _uan.text.trim(),
      bankName: _bank.text.trim(),
      ifsc: _ifsc.text.trim().toUpperCase(),
      accountNo: _account.text.trim(),
      branch: _branch.text.trim(),
      salary: double.tryParse(_salary.text.trim()) ?? 0,
      photo: _existingPhotoPath,
      siteId: selectedSite.id,
      supervisorId: selectedSite.supervisorId, // Auto-derive supervisor
      joinDate: widget.existing?.joinDate ?? DateTime.now().toIso8601String().split('T').first,
      status: widget.existing?.status ?? 'active',
      aadharPhoto: widget.existing?.aadharPhoto ?? '',
      passbookPhoto: _details.text.trim(),
    );

    await widget.db.saveGuard(guard);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  // UI Helpers
  InputDecoration _field(String label, {String? hint, Widget? prefix}) => InputDecoration(
    labelText: label, hintText: hint,
    prefixIcon: prefix,
    labelStyle: const TextStyle(color: AppTheme.txtSec, fontSize: 13),
    hintStyle: const TextStyle(color: AppTheme.txtMuted, fontSize: 12),
    filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.bord)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.red)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _sectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: AppTheme.primary)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoBytes != null || _existingPhotoPath.length > 200;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(widget.existing == null ? 'Add New Guard' : 'Edit Guard',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
              const SizedBox(height: 20),

              // Photo Picker
              Center(
                child: GestureDetector(
                  onTap: _showPhotoOptions,
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: AppTheme.bgElevated,
                      backgroundImage: _photoBytes != null
                          ? MemoryImage(_photoBytes!) as ImageProvider
                          : (_existingPhotoPath.length > 200 ? MemoryImage(base64Decode(_existingPhotoPath)) : null),
                      child: (!hasPhoto)
                          ? const Icon(Icons.add_a_photo, size: 36, color: AppTheme.txtMuted)
                          : null,
                    ),
                    const Positioned(
                      bottom: 0, right: 0,
                      child: CircleAvatar(radius: 16, backgroundColor: AppTheme.primary, child: Icon(Icons.camera_alt, size: 16, color: Colors.white)),
                    ),
                  ]),
                ),
              ),
              if (!hasPhoto)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('⚠ Photo required for face verification', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.yellow, fontSize: 12)),
                ),

              // Personal
              _sectionHeader('Personal Information', Icons.person),
              TextFormField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _field('Full Name *', prefix: const Icon(Icons.person, size: 18)), validator: _validateName),
              const SizedBox(height: 10),
              TextFormField(controller: _empId, style: const TextStyle(color: Colors.white), decoration: _field('Employee ID *', hint: 'e.g. EMP001', prefix: const Icon(Icons.badge, size: 18)), validator: _validateEmpId),
              const SizedBox(height: 10),
              TextFormField(controller: _phone, style: const TextStyle(color: Colors.white), decoration: _field('Phone Number *', hint: '10-digit mobile', prefix: const Icon(Icons.phone, size: 18)), keyboardType: TextInputType.phone, maxLength: 10, validator: _validatePhone),
              const SizedBox(height: 10),
              TextFormField(
                controller: _dob, style: const TextStyle(color: Colors.white),
                decoration: _field('Date of Birth', hint: 'Tap to select', prefix: const Icon(Icons.cake, size: 18)).copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16, color: AppTheme.txtMuted)),
                readOnly: true,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now().subtract(const Duration(days: 6570)));
                  if (d != null) setState(() => _dob.text = d.toIso8601String().split('T').first);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _address, style: const TextStyle(color: Colors.white),
                decoration: _field('Address *', hint: 'Full residential address', prefix: const Icon(Icons.home, size: 18)),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().length < 10) ? 'Enter full address (min 10 chars)' : null,
              ),

              // Identity
              _sectionHeader('Identity Document', Icons.credit_card),
              TextFormField(controller: _aadhaar, style: const TextStyle(color: Colors.white), decoration: _field('Aadhaar Card Number *', hint: '12-digit number', prefix: const Icon(Icons.credit_card, size: 18)), keyboardType: TextInputType.number, maxLength: 12, validator: _validateAadhaar),
              const SizedBox(height: 10),
              TextFormField(controller: _uan, style: const TextStyle(color: Colors.white), decoration: _field('UAN Number', hint: 'Optional 12-digit UAN', prefix: const Icon(Icons.badge, size: 18)), keyboardType: TextInputType.number, maxLength: 12),

              // Bank Details
              _sectionHeader('Bank Details', Icons.account_balance),
              TextFormField(controller: _bank, style: const TextStyle(color: Colors.white), decoration: _field('Bank Name *', hint: 'e.g. State Bank of India', prefix: const Icon(Icons.account_balance, size: 18)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Bank name is required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _ifsc, style: const TextStyle(color: Colors.white), decoration: _field('IFSC Code *', hint: 'e.g. SBIN0001234', prefix: const Icon(Icons.code, size: 18)), textCapitalization: TextCapitalization.characters, maxLength: 11, validator: _validateIFSC),
              const SizedBox(height: 10),
              TextFormField(controller: _account, style: const TextStyle(color: Colors.white), decoration: _field('Account Number *', hint: '9 to 18 digits', prefix: const Icon(Icons.numbers, size: 18)), keyboardType: TextInputType.number, validator: _validateAccountNo),
              const SizedBox(height: 10),
              TextFormField(controller: _branch, style: const TextStyle(color: Colors.white), decoration: _field('Branch Name (optional)', prefix: const Icon(Icons.location_city, size: 18))),

              // Employment
              _sectionHeader('Employment Details', Icons.work),
              TextFormField(controller: _salary, style: const TextStyle(color: Colors.white), decoration: _field('Monthly Salary ₹ *', hint: 'e.g. 15000', prefix: const Icon(Icons.currency_rupee, size: 18)), keyboardType: TextInputType.number, validator: _validateSalary),
              const SizedBox(height: 10),
              const Text('Assign to Site *', style: TextStyle(color: AppTheme.txtSec, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedSiteId,
                dropdownColor: AppTheme.bgSurface,
                style: const TextStyle(color: Colors.white),
                items: widget.allSites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) => setState(() => _selectedSiteId = val!),
                decoration: _field('Site *', prefix: const Icon(Icons.location_on, size: 18)),
              ),
              if (widget.existing != null)
                const Padding(
                  padding: EdgeInsets.only(top: 6, bottom: 4),
                  child: Text('Changing the site transfers the guard to a new supervisor.', style: TextStyle(color: AppTheme.txtMuted, fontSize: 11), textAlign: TextAlign.center),
                ),

              // Notes
              _sectionHeader('Additional Notes', Icons.notes),
              TextFormField(
                controller: _details, style: const TextStyle(color: Colors.white),
                decoration: _field('Guard Details / Notes (optional)', hint: 'Medical conditions, skills, remarks...', prefix: const Icon(Icons.notes, size: 18)),
                maxLines: 3, maxLength: 500,
              ),

              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(widget.existing == null ? 'Add Guard' : 'Save Changes'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
