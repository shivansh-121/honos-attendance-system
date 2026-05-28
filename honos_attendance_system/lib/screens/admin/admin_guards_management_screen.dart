
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../services/db_service.dart';
import '../../services/id_generator.dart';
import '../../widgets/base64_image_widget.dart';
import '../../models/guard.dart';
import '../../models/site.dart';
import 'guard_profile_screen.dart';

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
      backgroundColor: context.colors.bgSurface,
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
    final db = ref.read(dbProvider);

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      floatingActionButton: sitesAsync.whenOrNull(
        data: (sites) => FloatingActionButton.extended(
          onPressed: () => _openGuardForm(context, db, sites),
          icon: Icon(Icons.person_add, color: context.colors.bgBase),
          label: Text('Add Guard', style: TextStyle(color: context.colors.bgBase, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          backgroundColor: context.colors.primary,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds, color: Colors.white24),
      ),
      body: CustomScrollView(
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

            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              titlePadding: const EdgeInsets.only(left: 24, bottom: 20, right: 24),
              title: Text('Guard Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.colors.primaryDark, context.colors.primary],
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
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 4.seconds, curve: Curves.easeInOut),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1.15, 1.15), end: const Offset(1, 1), duration: 3.seconds, curve: Curves.easeInOut),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 40,
                    child: Transform.rotate(
                      angle: -0.15,
                      child: Icon(Icons.security_rounded, size: 140, color: Colors.white.withValues(alpha: 0.15)),
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3, end: 0, duration: 800.ms, curve: Curves.easeOutBack),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
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
            child: Container(
              color: context.colors.bgBase,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: context.colors.txtPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by name or Employee ID...',
                      hintStyle: TextStyle(color: context.colors.txtMuted),
                      prefixIcon: Icon(Icons.search, color: context.colors.primary),
                      filled: true,
                      fillColor: context.colors.bgSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: context.colors.bord.withValues(alpha: 0.5))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: context.colors.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: Icon(Icons.clear, color: context.colors.txtMuted),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: sitesAsync.when(
                          data: (sites) {
                            final siteIds = sites.map((s) => s.id).toSet();
                            final safeSiteFilter = (siteIds.contains(_selectedSiteFilter)) ? _selectedSiteFilter : null;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.colors.bgSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.colors.bord.withValues(alpha: 0.5)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: safeSiteFilter,
                                  isExpanded: true,
                                  hint: Text('Filter by Site', style: TextStyle(color: context.colors.txtMuted, fontSize: 13)),
                                  dropdownColor: context.colors.bgSurface,
                                  style: TextStyle(color: context.colors.txtPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.primary),
                                  items: [
                                    const DropdownMenuItem<String>(value: null, child: Text('All Sites')),
                                    ...sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                                  ],
                                  onChanged: (val) => setState(() => _selectedSiteFilter = val),
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: usersAsync.when(
                          data: (users) {
                            final supervisors = users.where((u) => u.role == 'supervisor').toList();
                            final supIds = supervisors.map((s) => s.id).toSet();
                            final safeSupFilter = (supIds.contains(_selectedSupervisorFilter)) ? _selectedSupervisorFilter : null;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.colors.bgSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.colors.bord.withValues(alpha: 0.5)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: safeSupFilter,
                                  isExpanded: true,
                                  hint: Text('Filter by Sup', style: TextStyle(color: context.colors.txtMuted, fontSize: 13)),
                                  dropdownColor: context.colors.bgSurface,
                                  style: TextStyle(color: context.colors.txtPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.primary),
                                  items: [
                                    const DropdownMenuItem<String>(value: null, child: Text('All Sups')),
                                    ...supervisors.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                                  ],
                                  onChanged: (val) => setState(() => _selectedSupervisorFilter = val),
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut),
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
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.security_rounded, size: 80, color: context.colors.txtMuted.withValues(alpha: 0.3)).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 20),
                        Text('No guards found', style: TextStyle(color: context.colors.txtSec, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Try adjusting your search or filters.', style: TextStyle(color: context.colors.txtMuted, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final g = filtered[index];
                      final siteName = sites.firstWhere((s) => s.id == g.siteId, orElse: () => const Site(id: '', name: 'Unassigned', address: '', lat: 0, lng: 0, radius: 0)).name;

                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GuardProfileScreen(guard: g))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: context.colors.bgSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: context.colors.bord.withValues(alpha: 0.5)),
                            boxShadow: [
                              BoxShadow(color: context.colors.primary.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Hero(
                                    tag: 'avatar_${g.id}',
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: context.colors.primary.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
                                      ),
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: context.colors.primary,
                                        backgroundImage: g.photo.length > 200 ? MemoryImage(base64Decode(g.photo)) : null,
                                        child: g.photo.length < 200 ? Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)) : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(g.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.colors.txtPrimary, letterSpacing: -0.3)),
                                        Container(
                                          margin: const EdgeInsets.only(top: 6, bottom: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                          child: Text('ID: ${g.empId}', style: TextStyle(fontSize: 10, color: context.colors.primaryDark, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                        ),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on_rounded, color: context.colors.primary, size: 14),
                                            const SizedBox(width: 6),
                                            Expanded(child: Text(siteName, style: TextStyle(fontSize: 13, color: context.colors.txtSec, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit_rounded, color: context.colors.txtSec, size: 22),
                                    onPressed: () => _openGuardForm(context, db, sites, existing: g),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(height: 1, color: context.colors.bord.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.phone_rounded, size: 14, color: context.colors.txtMuted),
                                      const SizedBox(width: 6),
                                      Text(g.phone.isEmpty ? 'No phone' : g.phone, style: TextStyle(color: context.colors.txtSec, fontSize: 13)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.currency_rupee, size: 14, color: context.colors.txtMuted),
                                      const SizedBox(width: 4),
                                      Text('₹${g.salary.toStringAsFixed(0)}/mo', style: TextStyle(color: context.colors.txtSec, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: (40 * index).ms).slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, __) => SliverFillRemaining(child: Center(child: Text('Error: $e', style: TextStyle(color: context.colors.red)))),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
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
    if (widget.existing == null && (v == null || v.trim().isEmpty)) return null;
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
      backgroundColor: context.colors.bgSurface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.camera_alt, color: context.colors.primary),
            title: const Text('Take Photo with Camera'),
            onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.camera); },
          ),
          ListTile(
            leading: Icon(Icons.photo_library, color: context.colors.primary),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Please fix the errors above'), backgroundColor: context.colors.red));
      return;
    }
    setState(() => _saving = true);
    
    final selectedSite = widget.allSites.firstWhere((s) => s.id == _selectedSiteId);

    String finalEmpId = _empId.text.trim();
    if (finalEmpId.isEmpty) {
      final allGuards = await widget.db.guardsStream().first;
      finalEmpId = IdGenerator.generateGuardId(allGuards);
    }

    final guard = Guard(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      empId: finalEmpId,
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
    labelStyle: TextStyle(color: context.colors.txtSec, fontSize: 13),
    hintStyle: TextStyle(color: context.colors.txtMuted, fontSize: 12),
    filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.bord)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.primary)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.red)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _sectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: context.colors.primary)),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
              ]),
              const SizedBox(height: 20),

              // Photo Picker
              Center(
                child: GestureDetector(
                  onTap: _showPhotoOptions,
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: context.colors.bgElevated,
                      backgroundImage: _photoBytes != null
                          ? MemoryImage(_photoBytes!) as ImageProvider
                          : (_existingPhotoPath.length > 200 ? MemoryImage(base64Decode(_existingPhotoPath)) : null),
                      child: (!hasPhoto)
                          ? Icon(Icons.add_a_photo, size: 36, color: context.colors.txtMuted)
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: CircleAvatar(radius: 16, backgroundColor: context.colors.primary, child: const Icon(Icons.camera_alt, size: 16, color: Colors.white)),
                    ),
                  ]),
                ),
              ),
              if (!hasPhoto)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('⚠ Photo required for face verification', textAlign: TextAlign.center, style: TextStyle(color: context.colors.yellow, fontSize: 12)),
                ),

              // Personal
              _sectionHeader('Personal Information', Icons.person),
              TextFormField(controller: _name, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('Full Name *', prefix: const Icon(Icons.person, size: 18)), validator: _validateName),
              const SizedBox(height: 10),
              if (widget.existing != null) ...[
                TextFormField(controller: _empId, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('Employee ID *', prefix: const Icon(Icons.badge, size: 18)), readOnly: true, validator: _validateEmpId),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              TextFormField(controller: _phone, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('Phone Number *', hint: '10-digit mobile', prefix: const Icon(Icons.phone, size: 18)), keyboardType: TextInputType.phone, maxLength: 10, validator: _validatePhone),
              const SizedBox(height: 10),
              TextFormField(
                controller: _dob, style: TextStyle(color: context.colors.txtPrimary),
                decoration: _field('Date of Birth', hint: 'Tap to select', prefix: const Icon(Icons.cake, size: 18)).copyWith(suffixIcon: Icon(Icons.calendar_today, size: 16, color: context.colors.txtMuted)),
                readOnly: true,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now().subtract(const Duration(days: 6570)));
                  if (d != null) setState(() => _dob.text = d.toIso8601String().split('T').first);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _address, style: TextStyle(color: context.colors.txtPrimary),
                decoration: _field('Address *', hint: 'Full residential address', prefix: const Icon(Icons.home, size: 18)),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().length < 10) ? 'Enter full address (min 10 chars)' : null,
              ),

              // Identity
              _sectionHeader('Identity Document', Icons.credit_card),
              TextFormField(controller: _aadhaar, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('Aadhaar Card Number *', hint: '12-digit number', prefix: const Icon(Icons.credit_card, size: 18)), keyboardType: TextInputType.number, maxLength: 12, validator: _validateAadhaar),
              const SizedBox(height: 10),
              TextFormField(controller: _uan, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('UAN Number', hint: 'Optional 12-digit UAN', prefix: const Icon(Icons.badge, size: 18)), keyboardType: TextInputType.number, maxLength: 12),

              // Bank Details
              _sectionHeader('Bank Details', Icons.account_balance),
              TextFormField(controller: _bank, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('Bank Name *', hint: 'e.g. State Bank of India', prefix: const Icon(Icons.account_balance, size: 18)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Bank name is required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _ifsc, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('IFSC Code *', hint: 'e.g. SBIN0001234', prefix: const Icon(Icons.code, size: 18)), textCapitalization: TextCapitalization.characters, maxLength: 11, validator: _validateIFSC),
              const SizedBox(height: 10),
              TextFormField(controller: _account, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('Account Number *', hint: '9 to 18 digits', prefix: const Icon(Icons.numbers, size: 18)), keyboardType: TextInputType.number, validator: _validateAccountNo),
              const SizedBox(height: 10),
              TextFormField(controller: _branch, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('Branch Name (optional)', prefix: const Icon(Icons.location_city, size: 18))),

              // Employment
              _sectionHeader('Employment Details', Icons.work),
              TextFormField(controller: _salary, style: TextStyle(color: context.colors.txtPrimary), decoration: _field('Monthly Salary ₹ *', hint: 'e.g. 15000', prefix: const Icon(Icons.currency_rupee, size: 18)), keyboardType: TextInputType.number, validator: _validateSalary),
              const SizedBox(height: 10),
              Text('Assign to Site *', style: TextStyle(color: context.colors.txtSec, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedSiteId,
                dropdownColor: context.colors.bgSurface,
                style: TextStyle(color: context.colors.txtPrimary),
                items: widget.allSites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) => setState(() => _selectedSiteId = val!),
                decoration: _field('Site *', prefix: const Icon(Icons.location_on, size: 18)),
              ),
              if (widget.existing != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text('Changing the site transfers the guard to a new supervisor.', style: TextStyle(color: context.colors.txtMuted, fontSize: 11), textAlign: TextAlign.center),
                ),

              // Notes
              _sectionHeader('Additional Notes', Icons.notes),
              TextFormField(
                controller: _details, style: TextStyle(color: context.colors.txtPrimary),
                decoration: _field('Guard Details / Notes (optional)', hint: 'Medical conditions, skills, remarks...', prefix: const Icon(Icons.notes, size: 18)),
                maxLines: 3, maxLength: 500,
              ),

              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(widget.existing == null ? 'Add Guard' : 'Save Changes'),
                style: ElevatedButton.styleFrom(foregroundColor: context.colors.bgBase, backgroundColor: context.colors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
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
