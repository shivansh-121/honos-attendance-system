import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../app_theme.dart';
import '../../models/guard.dart';
import '../../models/site.dart';
import '../../models/app_notification.dart';
import '../../services/db_service.dart';
import '../../services/id_generator.dart';
import '../../services/auth_service.dart';
import '../../widgets/base64_image_widget.dart';
import '../admin/guard_profile_screen.dart';
import '../../services/app_nav.dart';

class GuardsListScreen extends ConsumerStatefulWidget {
  const GuardsListScreen({super.key});

  @override
  ConsumerState<GuardsListScreen> createState() => _GuardsListScreenState();
}

class _GuardsListScreenState extends ConsumerState<GuardsListScreen> {
  @override
  Widget build(BuildContext context) {
    final guardsAsync = ref.watch(guardsStreamProvider);
    final authUser = ref.watch(authProvider);
    final db = ref.read(dbProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guards'),
        actions: [
          guardsAsync.when(
            data: (guards) => guards.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.delete_sweep_outlined, color: context.colors.red),
                    tooltip: 'Clear All Attendance',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Clear All Attendance'),
                          content: const Text('Are you sure? This will delete ALL attendance records permanently.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: context.colors.red),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await db.clearAttendance();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All attendance records cleared.')));
                        }
                      }
                    },
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGuardForm(context, db),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Guard'),
        backgroundColor: context.colors.primary,
      ),
      body: guardsAsync.when(
        data: (allGuards) {
          final myGuards = allGuards.where((g) => g.siteId == authUser?.siteId).toList();
          return myGuards.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: context.colors.txtMuted),
                        const SizedBox(height: 24),
                        Text('No guards registered yet.', textAlign: TextAlign.center, style: TextStyle(color: context.colors.txtSec, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text('Use the "Add Guard" button below to register a new guard.', textAlign: TextAlign.center, style: TextStyle(color: context.colors.txtMuted, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: myGuards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _GuardCard(
                    guard: myGuards[i],
                    onEdit: () => _openGuardForm(context, db, existing: myGuards[i]),
                  ),
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  void _openGuardForm(BuildContext context, DbService db, {Guard? existing}) {
    final authUser = ref.read(authProvider);
    final sitesAsync = ref.read(sitesStreamProvider);
    final allSites = sitesAsync.value ?? [];
    final siteId = authUser?.siteId ?? '';
    final supervisorId = authUser?.id ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _GuardFormSheet(
        db: db,
        siteId: siteId,
        supervisorId: supervisorId,
        allSites: allSites,
        existing: existing,
        onSaved: () {},
      ),
    );
  }
}

// ── Guard Form Sheet ──────────────────────────────────────────────────────────
class _GuardFormSheet extends StatefulWidget {
  final DbService db;
  final String siteId;
  final String supervisorId;
  final List<Site> allSites;
  final Guard? existing;
  final VoidCallback onSaved;

  const _GuardFormSheet({
    required this.db,
    required this.siteId,
    required this.supervisorId,
    required this.allSites,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_GuardFormSheet> createState() => _GuardFormSheetState();
}

class _GuardFormSheetState extends State<_GuardFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _name, _empId, _phone, _dob,
      _address, _aadhaar, _uan, _bank, _ifsc, _account, _branch, _salary, _details;

  Uint8List? _photoBytes;
  String _existingPhotoPath = '';
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
    _details  = TextEditingController(text: g?.passbookPhoto ?? ''); // notes stored here
    _existingPhotoPath = g?.photo ?? '';
  }

  // ── Validation ──────────────────────────────────────────────────────────────
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
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.trim().toUpperCase())) {
      return 'Invalid — e.g. SBIN0001234';
    }
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
    if (d == null || d <= 0) return 'Enter a valid positive amount';
    return null;
  }

  // ── Photo ───────────────────────────────────────────────────────────────────
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

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Please fix the errors above'), backgroundColor: context.colors.red));
      return;
    }
    setState(() => _saving = true);

    final isNew = widget.existing == null;
    final guardId = widget.existing?.id ?? const Uuid().v4();

    String finalEmpId = _empId.text.trim();
    if (finalEmpId.isEmpty) {
      final allGuards = await widget.db.guardsStream().first;
      finalEmpId = IdGenerator.generateGuardId(allGuards);
    }

    final guard = Guard(
      id: guardId,
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
      siteId: widget.siteId,
      supervisorId: widget.supervisorId,
      joinDate: widget.existing?.joinDate ?? DateTime.now().toIso8601String().split('T').first,
      status: widget.existing?.status ?? 'active',
      aadharPhoto: widget.existing?.aadharPhoto ?? '',
      passbookPhoto: _details.text.trim(), // notes
      isEditableBySupervisor: false, // Always lock after save
    );

    await widget.db.saveGuard(guard);

    if (isNew) {
      final notif = AppNotification(
        id: const Uuid().v4(),
        type: 'guard_added',
        title: 'New Guard Registered',
        message: 'Supervisor registered a new guard: ${guard.name}',
        guardId: guardId,
        supervisorId: widget.supervisorId,
        timestamp: DateTime.now().toIso8601String(),
      );
      await widget.db.saveNotification(notif);
    }

    widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Guard saved and profile locked.'), backgroundColor: context.colors.green));
      Navigator.pop(context);
    }
  }

  // ── Shared UI helpers ───────────────────────────────────────────────────────
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
    if (widget.existing != null && !widget.existing!.isEditableBySupervisor) {
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 40, bottom: MediaQuery.of(context).viewInsets.bottom + 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 64, color: context.colors.txtMuted),
            const SizedBox(height: 16),
            const Text('Edit Locked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Guard profiles are locked for editing after creation to prevent unauthorized changes. You must request permission from an admin to update these details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.txtSec, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: const Text('Request Edit Access'),
                style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : () async {
                  setState(() => _saving = true);
                  final notif = AppNotification(
                    id: const Uuid().v4(),
                    type: 'edit_request',
                    title: 'Edit Access Requested',
                    message: 'Supervisor is requesting permission to edit guard: ${widget.existing!.name}',
                    guardId: widget.existing!.id,
                    supervisorId: widget.supervisorId,
                    timestamp: DateTime.now().toIso8601String(),
                  );
                  await widget.db.saveNotification(notif);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Edit request sent to Admin!'), backgroundColor: context.colors.green));
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

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
              // Header
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

              // ── Personal Info ───────────────────────────────────────────────
              _sectionHeader('Personal Information', Icons.person),
              TextFormField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _field('Full Name *', prefix: const Icon(Icons.person, size: 18)), validator: _validateName),
              const SizedBox(height: 10),
              if (widget.existing != null) ...[
                TextFormField(controller: _empId, style: const TextStyle(color: Colors.white), decoration: _field('Employee ID *', prefix: const Icon(Icons.badge, size: 18)), readOnly: true, validator: _validateEmpId),
                const SizedBox(height: 10),
              ],
              TextFormField(controller: _phone, style: const TextStyle(color: Colors.white), decoration: _field('Phone Number *', hint: '10-digit mobile', prefix: const Icon(Icons.phone, size: 18)), keyboardType: TextInputType.phone, maxLength: 10, validator: _validatePhone),
              const SizedBox(height: 10),
              TextFormField(
                controller: _dob, style: const TextStyle(color: Colors.white),
                decoration: _field('Date of Birth', hint: 'Tap to select', prefix: const Icon(Icons.cake, size: 18)).copyWith(suffixIcon: Icon(Icons.calendar_today, size: 16, color: context.colors.txtMuted)),
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

              // ── Identity ────────────────────────────────────────────────────
              _sectionHeader('Identity Document', Icons.credit_card),
              TextFormField(controller: _aadhaar, style: const TextStyle(color: Colors.white), decoration: _field('Aadhaar Card Number *', hint: '12-digit number', prefix: const Icon(Icons.credit_card, size: 18)), keyboardType: TextInputType.number, maxLength: 12, validator: _validateAadhaar),
              const SizedBox(height: 10),
              TextFormField(controller: _uan, style: const TextStyle(color: Colors.white), decoration: _field('UAN Number', hint: 'Optional 12-digit UAN', prefix: const Icon(Icons.badge, size: 18)), keyboardType: TextInputType.number, maxLength: 12),

              // ── Bank Details ────────────────────────────────────────────────
              _sectionHeader('Bank Details', Icons.account_balance),
              TextFormField(controller: _bank, style: const TextStyle(color: Colors.white), decoration: _field('Bank Name *', hint: 'e.g. State Bank of India', prefix: const Icon(Icons.account_balance, size: 18)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Bank name is required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _ifsc, style: const TextStyle(color: Colors.white), decoration: _field('IFSC Code *', hint: 'e.g. SBIN0001234', prefix: const Icon(Icons.code, size: 18)), textCapitalization: TextCapitalization.characters, maxLength: 11, validator: _validateIFSC),
              const SizedBox(height: 10),
              TextFormField(controller: _account, style: const TextStyle(color: Colors.white), decoration: _field('Account Number *', hint: '9 to 18 digits', prefix: const Icon(Icons.numbers, size: 18)), keyboardType: TextInputType.number, validator: _validateAccountNo),
              const SizedBox(height: 10),
              TextFormField(controller: _branch, style: const TextStyle(color: Colors.white), decoration: _field('Branch Name (optional)', prefix: const Icon(Icons.location_city, size: 18))),

              // ── Employment ──────────────────────────────────────────────────
              _sectionHeader('Employment Details', Icons.work),
              TextFormField(controller: _salary, style: const TextStyle(color: Colors.white), decoration: _field('Monthly Salary ₹ *', hint: 'e.g. 15000', prefix: const Icon(Icons.currency_rupee, size: 18)), keyboardType: TextInputType.number, validator: _validateSalary),

              // ── Notes ───────────────────────────────────────────────────────
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
                style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
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

// ── Guard Card ────────────────────────────────────────────────────────────────
class _GuardCard extends StatelessWidget {
  final Guard guard;
  final VoidCallback onEdit;

  const _GuardCard({required this.guard, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = guard.photo.length > 200;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppNav.push(context, GuardProfileScreen(guard: guard)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: SizedBox(
                width: 60, height: 60,
                child: hasPhoto
                    ? Base64ImageWidget(base64String: guard.photo, fit: BoxFit.cover,
                        placeholder: Text(guard.name[0].toUpperCase(), style: TextStyle(color: context.colors.primary, fontSize: 22, fontWeight: FontWeight.bold)))
                    : Container(
                        color: context.colors.primary.withValues(alpha: 0.15),
                        alignment: Alignment.center,
                        child: Text(guard.name[0].toUpperCase(), style: TextStyle(color: context.colors.primary, fontSize: 22, fontWeight: FontWeight.bold))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(guard.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasPhoto ? context.colors.green.withValues(alpha: 0.15) : context.colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(hasPhoto ? '✓ Photo' : '✗ No Photo',
                        style: TextStyle(fontSize: 10, color: hasPhoto ? context.colors.green : context.colors.red, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                _info(context, Icons.badge_outlined, guard.empId),
                _info(context, Icons.phone_outlined, guard.phone.isEmpty ? '—' : guard.phone),
                _info(context, Icons.currency_rupee, '₹${guard.salary.toStringAsFixed(0)}/month'),
                if (guard.bankName.isNotEmpty) _info(context, Icons.account_balance_outlined, guard.bankName),
              ]),
            ),
            Column(children: [
              IconButton(icon: Icon(Icons.edit_outlined, color: context.colors.primary, size: 20), onPressed: onEdit),
              const SizedBox(height: 12),
              Icon(Icons.chevron_right, color: context.colors.txtMuted),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(children: [
      Icon(icon, size: 12, color: context.colors.txtMuted),
      const SizedBox(width: 5),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: context.colors.txtSec), overflow: TextOverflow.ellipsis)),
    ]),
  );
}
