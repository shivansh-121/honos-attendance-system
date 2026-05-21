import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../models/guard.dart';
import '../../services/db_service.dart';
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
    final db = ref.read(dbProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guards'),
        actions: [
          guardsAsync.when(
            data: (guards) => guards.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined,
                        color: AppTheme.red),
                    tooltip: 'Clear All Attendance',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Clear All Attendance'),
                          content: const Text(
                              'Are you sure? This will delete ALL attendance records permanently.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.red),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await db.clearAttendance();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('All attendance records cleared.')));
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
        backgroundColor: AppTheme.primary,
      ),
      body: guardsAsync.when(
        data: (allGuards) {
          return allGuards.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 80, color: AppTheme.txtMuted),
                      const SizedBox(height: 24),
                      const Text('No guards registered yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.txtSec, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('Use the "Add Guard" button below to register a new guard.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.txtMuted, fontSize: 14)),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: allGuards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _GuardCard(
                  guard: allGuards[i],
                  onEdit: () =>
                      _openGuardForm(context, db, existing: allGuards[i]),
                ),
              );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(
            child:
                Text('Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  void _openGuardForm(BuildContext context, DbService db, {Guard? existing}) {
    final authUser = ref.read(authProvider);
    final siteId = authUser?.siteId ?? 'site1';
    final supervisorId = authUser?.id ?? 'sup1';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _GuardFormSheet(
          db: db,
          siteId: siteId,
          supervisorId: supervisorId,
          existing: existing,
          onSaved: () {}),
    );
  }
}

// ── Guard Form Sheet ──────────────────────────────────────────────────────────
class _GuardFormSheet extends StatefulWidget {
  final DbService db;
  final String siteId;
  final String supervisorId;
  final Guard? existing;
  final VoidCallback onSaved;

  const _GuardFormSheet(
      {required this.db,
      required this.siteId,
      required this.supervisorId,
      this.existing,
      required this.onSaved});

  @override
  State<_GuardFormSheet> createState() => _GuardFormSheetState();
}

class _GuardFormSheetState extends State<_GuardFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _empId, _phone, _salary;
  File? _photoFile;
  Uint8List? _photoBytes;
  String _existingPhotoPath = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _name = TextEditingController(text: g?.name ?? '');
    _empId = TextEditingController(text: g?.empId ?? '');
    _phone = TextEditingController(text: g?.phone ?? '');
    _salary = TextEditingController(
        text: g == null || g.salary == 0 ? '' : g.salary.toStringAsFixed(0));
    _existingPhotoPath = g?.photo ?? '';
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 70); // Compressed for Base64 limits
    if (picked == null) return;

    // Convert directly to Base64 for instant syncing across devices
    final bytes = await picked.readAsBytes();
    final base64String = base64Encode(bytes);

    setState(() {
      _existingPhotoPath = base64String;
      _photoBytes = bytes;
      if (!kIsWeb) _photoFile = File(picked.path);
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
            onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppTheme.primary),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Always use _existingPhotoPath — it holds the Base64 string after photo is picked.
    // _photoFile is only used for local preview in the UI; never saved to Firestore.
    final photoToSave = _existingPhotoPath;

    final guard = Guard(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      empId: _empId.text.trim(),
      siteId: widget.siteId,
      supervisorId: widget.supervisorId,
      phone: _phone.text.trim(),
      joinDate: widget.existing?.joinDate ??
          DateTime.now().toIso8601String().split('T').first,
      salary: double.tryParse(_salary.text) ?? 0,
      photo: photoToSave,
    );

    await widget.db.saveGuard(guard);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoFile != null || _existingPhotoPath.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existing == null ? 'Add New Guard' : 'Edit Guard',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Photo Picker
                Center(
                  child: GestureDetector(
                    onTap: _showPhotoOptions,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: AppTheme.bgElevated,
                          backgroundImage: _photoBytes != null
                              ? MemoryImage(_photoBytes!) as ImageProvider
                              : (_existingPhotoPath.length > 200
                                  ? MemoryImage(
                                      base64Decode(_existingPhotoPath))
                                  : null),
                          child: (!hasPhoto && _photoBytes == null)
                              ? const Icon(Icons.add_a_photo,
                                  size: 36, color: AppTheme.txtMuted)
                              : null,
                        ),
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primary,
                            child: Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!hasPhoto)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('⚠ Photo required for face verification',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.yellow, fontSize: 12)),
                  ),
                const SizedBox(height: 20),

                TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                    validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _empId,
                    decoration: const InputDecoration(
                        labelText: 'Employee ID (e.g. HSS003)',
                        prefixIcon: Icon(Icons.badge)),
                    validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _salary,
                    decoration: const InputDecoration(
                        labelText: 'Monthly Salary (₹)',
                        prefixIcon: Icon(Icons.currency_rupee)),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(
                      widget.existing == null ? 'Add Guard' : 'Save Changes'),
                  onPressed: _saving ? null : _save,
                ),
              ]),
        ),
      ),
    );
  }
}

// ── Guard Card ────────────────────────────────────────────────────────────────
class _GuardCard extends StatelessWidget {
  final Guard guard;
  final VoidCallback onEdit;

  const _GuardCard(
      {required this.guard, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    // Debug print to help identify image issues
    if (guard.photo.isNotEmpty && guard.photo.length <= 200) {
      debugPrint(
          'Guard ${guard.name} has legacy/invalid photo path: ${guard.photo}');
    }
    final hasPhoto = guard.photo.length > 200;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppNav.push(context, GuardProfileScreen(guard: guard)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
          // Avatar with photo or initial
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: SizedBox(
              width: 60,
              height: 60,
              child: hasPhoto
                  ? Base64ImageWidget(
                      base64String: guard.photo,
                      fit: BoxFit.cover,
                      placeholder: Text(guard.name[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    )
                  : Container(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      alignment: Alignment.center,
                      child: Text(guard.name[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(guard.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasPhoto
                        ? AppTheme.green.withOpacity(0.15)
                        : AppTheme.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasPhoto ? '✓ Photo' : '✗ No Photo',
                    style: TextStyle(
                        fontSize: 10,
                        color: hasPhoto ? AppTheme.green : AppTheme.red,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              _info(Icons.badge_outlined, guard.empId),
              _info(Icons.phone_outlined,
                  guard.phone.isEmpty ? '—' : guard.phone),
              _info(Icons.currency_rupee,
                  '₹${guard.salary.toStringAsFixed(0)}/month'),
            ]),
          ),
          Column(children: [
            IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.primary, size: 20),
                onPressed: onEdit),
            const SizedBox(height: 12),
            const Icon(Icons.chevron_right, color: AppTheme.txtMuted),
          ]),
        ]),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Icon(icon, size: 12, color: AppTheme.txtMuted),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(fontSize: 12, color: AppTheme.txtSec)),
        ]),
      );
}
