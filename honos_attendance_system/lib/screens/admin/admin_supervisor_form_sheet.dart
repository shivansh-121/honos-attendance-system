import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

import '../../app_theme.dart';
import '../../models/app_user.dart';
import '../../models/site.dart';
import '../../services/db_service.dart';
import '../../services/id_generator.dart';
import 'map_picker_screen.dart';

class AdminSupervisorFormSheet extends StatefulWidget {
  final DbService db;
  final List<Site> allSites;
  final AppUser? existing;
  final String role;
  final VoidCallback onSaved;

  const AdminSupervisorFormSheet({
    super.key,
    required this.db,
    required this.allSites,
    this.existing,
    this.role = 'supervisor',
    required this.onSaved,
  });

  @override
  State<AdminSupervisorFormSheet> createState() => _AdminSupervisorFormSheetState();
}

class _AdminSupervisorFormSheetState extends State<AdminSupervisorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _name, _username, _password, _phone, _dob,
      _address, _aadhaar, _uan, _bank, _ifsc, _account, _branch, _salary;

  String? _selectedSiteId;
  Map<String, dynamic>? _customSiteLoc;

  String _photoBytes = '';
  String _aadhaarBytes = '';
  String _passbookBytes = '';

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _name = TextEditingController(text: u?.name ?? '');
    _username = TextEditingController(text: u?.username ?? '');
    _password = TextEditingController(); // Don't show existing hash
    _phone = TextEditingController(text: u?.phone ?? '');
    _dob = TextEditingController(text: u?.dob ?? '');
    _address = TextEditingController(text: u?.address ?? '');
    _aadhaar = TextEditingController(text: u?.aadharNo ?? '');
    _uan = TextEditingController(text: u?.uanNo ?? '');
    _bank = TextEditingController(text: u?.bankName ?? '');
    _ifsc = TextEditingController(text: u?.ifsc ?? '');
    _account = TextEditingController(text: u?.accountNo ?? '');
    _branch = TextEditingController(text: u?.branch ?? '');
    _salary = TextEditingController(text: u != null ? u.salary.toStringAsFixed(0) : '');

    if (u != null && widget.allSites.any((s) => s.id == u.siteId)) {
      _selectedSiteId = u.siteId;
    } else if (widget.allSites.isNotEmpty) {
      _selectedSiteId = widget.allSites.first.id;
    }

    _photoBytes = u?.photo ?? '';
    _aadhaarBytes = u?.aadharPhoto ?? '';
    _passbookBytes = u?.passbookPhoto ?? '';
  }

  Future<void> _pickImage(String type) async {
    final src = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgSurface,
        title: const Text('Select Source', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: src, imageQuality: 50, maxWidth: 800);
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    final b64 = base64Encode(bytes);
    setState(() {
      if (type == 'photo') {
        _photoBytes = b64;
      } else if (type == 'aadhaar') _aadhaarBytes = b64;
      else if (type == 'passbook') _passbookBytes = b64;
    });
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgSurface,
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(msg, style: TextStyle(color: context.colors.txtSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      )
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill all required fields correctly. Scroll up to see the errors in red.');
      return;
    }
    if (widget.existing == null && _password.text.isEmpty) {
      _showError('Password is required for new ${widget.role == 'executive' ? 'executives' : 'supervisors'}!');
      return;
    }

    setState(() => _saving = true);
    try {
      String finalSiteId = _selectedSiteId ?? '';
      
      // If custom location picked, update/create site
      if (_customSiteLoc != null) {
        if (widget.existing == null) {
          // New supervisor + new site
          finalSiteId = const Uuid().v4();
          final newSite = Site(
              id: finalSiteId,
              name: "${_name.text.trim()}'s Site",
              address: _customSiteLoc!['address'],
              lat: _customSiteLoc!['lat'],
              lng: _customSiteLoc!['lng'],
              radius: 250);
          await widget.db.saveSite(newSite);
        } else {
          // Update existing assigned site
          final oldSite = widget.allSites.firstWhere((s) => s.id == finalSiteId);
          final newSite = Site(
            id: oldSite.id,
            name: oldSite.name,
            address: _customSiteLoc!['address'],
            lat: _customSiteLoc!['lat'],
            lng: _customSiteLoc!['lng'],
            radius: oldSite.radius,
            supervisorId: widget.existing!.id,
          );
          await widget.db.saveSite(newSite);
        }
      }

      String? finalPassword = widget.existing?.password;
      if (_password.text.isNotEmpty) {
        finalPassword = sha256.convert(utf8.encode(_password.text.trim())).toString();
      }

      String finalEmpId = widget.existing?.empId ?? '';
      if (finalEmpId.isEmpty) {
        final allUsers = await widget.db.usersStream().first;
        finalEmpId = widget.role == 'executive' 
            ? IdGenerator.generateExecutiveId(allUsers)
            : IdGenerator.generateSupervisorId(allUsers);
      }

      final u = AppUser(
        id: widget.existing?.id ?? const Uuid().v4(),
        empId: finalEmpId,
        name: _name.text.trim(),
        username: _username.text.trim(),
        password: finalPassword,
        role: widget.existing?.role ?? widget.role,
        siteId: finalSiteId,
        salary: double.tryParse(_salary.text.trim()) ?? 0,
        phone: _phone.text.trim(),
        dob: _dob.text.trim(),
        address: _address.text.trim(),
        aadharNo: _aadhaar.text.trim(),
        uanNo: _uan.text.trim(),
        bankName: _bank.text.trim(),
        ifsc: _ifsc.text.trim(),
        accountNo: _account.text.trim(),
        branch: _branch.text.trim(),
        photo: _photoBytes,
        aadharPhoto: _aadhaarBytes,
        passbookPhoto: _passbookBytes,
        joinDate: widget.existing?.joinDate ?? DateTime.now().toIso8601String(),
        status: widget.existing?.status ?? 'active',
      );

      await widget.db.saveUser(u);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _field(String label, {String? hint, Widget? prefix}) {
    return InputDecoration(
      labelText: label, hintText: hint, prefixIcon: prefix,
      filled: true, fillColor: context.colors.bgBase,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      labelStyle: TextStyle(color: context.colors.txtSec, fontSize: 13),
      hintStyle: TextStyle(color: context.colors.txtMuted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(children: [
        Icon(icon, color: context.colors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(widget.existing == null ? 'Add New ${widget.role == 'executive' ? 'Executive' : 'Supervisor'}' : 'Edit ${widget.role == 'executive' ? 'Executive' : 'Supervisor'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(icon: Icon(Icons.close, color: context.colors.txtSec), onPressed: () => Navigator.pop(context)),
              ]),
              if (widget.existing?.empId.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text('Employee ID: ${widget.existing!.empId}', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
              const SizedBox(height: 20),

              // Photo
              Center(
                child: GestureDetector(
                  onTap: () => _pickImage('photo'),
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: context.colors.bgElevated,
                      backgroundImage: _photoBytes.length > 200 ? MemoryImage(base64Decode(_photoBytes)) : null,
                      child: _photoBytes.length < 200 ? Icon(Icons.add_a_photo, size: 36, color: context.colors.txtMuted) : null,
                    ),
                    Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 16, backgroundColor: context.colors.primary, child: const Icon(Icons.camera_alt, size: 16, color: Colors.white))),
                  ]),
                ),
              ),

              // Login Info
              _sectionHeader('Login Credentials', Icons.login),
              TextFormField(controller: _username, style: const TextStyle(color: Colors.white), decoration: _field('Username *', prefix: const Icon(Icons.alternate_email, size: 18)), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _password, style: const TextStyle(color: Colors.white), decoration: _field('Password ${widget.existing == null ? '*' : '(Leave empty to keep)'}', prefix: const Icon(Icons.password, size: 18))),
              
              // Personal Info
              _sectionHeader('Personal Information', Icons.person),
              TextFormField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _field('Full Name *', prefix: const Icon(Icons.person, size: 18)), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _phone, style: const TextStyle(color: Colors.white), decoration: _field('Phone Number *', prefix: const Icon(Icons.phone, size: 18)), keyboardType: TextInputType.phone, maxLength: 10, validator: (v) => v!.length < 10 ? 'Invalid' : null),
              const SizedBox(height: 10),
              TextFormField(
                controller: _dob, style: const TextStyle(color: Colors.white),
                decoration: _field('Date of Birth', hint: 'Tap to select', prefix: const Icon(Icons.cake, size: 18)).copyWith(suffixIcon: Icon(Icons.calendar_today, size: 16, color: context.colors.txtMuted)),
                readOnly: true,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now());
                  if (d != null) setState(() => _dob.text = d.toIso8601String().split('T').first);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _address, style: const TextStyle(color: Colors.white), decoration: _field('Address *', prefix: const Icon(Icons.home, size: 18)), maxLines: 2, validator: (v) => v!.isEmpty ? 'Required' : null),

              // Identity
              _sectionHeader('Identity Document', Icons.credit_card),
              TextFormField(controller: _aadhaar, style: const TextStyle(color: Colors.white), decoration: _field('Aadhaar Card Number *', prefix: const Icon(Icons.credit_card, size: 18)), keyboardType: TextInputType.number, maxLength: 12, validator: (v) => v!.length < 12 ? 'Invalid' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _uan, style: const TextStyle(color: Colors.white), decoration: _field('UAN Number', prefix: const Icon(Icons.badge, size: 18)), keyboardType: TextInputType.number, maxLength: 12),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file), label: Text(_aadhaarBytes.isEmpty ? 'Upload Aadhaar Photo' : 'Aadhaar Photo Attached'),
                style: OutlinedButton.styleFrom(foregroundColor: _aadhaarBytes.isEmpty ? context.colors.txtSec : context.colors.green),
                onPressed: () => _pickImage('aadhaar'),
              ),

              // Bank Details
              _sectionHeader('Bank Details', Icons.account_balance),
              TextFormField(controller: _bank, style: const TextStyle(color: Colors.white), decoration: _field('Bank Name *', prefix: const Icon(Icons.account_balance, size: 18)), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _ifsc, style: const TextStyle(color: Colors.white), decoration: _field('IFSC Code *', prefix: const Icon(Icons.code, size: 18)), textCapitalization: TextCapitalization.characters, maxLength: 11, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _account, style: const TextStyle(color: Colors.white), decoration: _field('Account Number *', prefix: const Icon(Icons.numbers, size: 18)), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _branch, style: const TextStyle(color: Colors.white), decoration: _field('Branch Name', prefix: const Icon(Icons.location_city, size: 18))),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file), label: Text(_passbookBytes.isEmpty ? 'Upload Passbook Photo' : 'Passbook Photo Attached'),
                style: OutlinedButton.styleFrom(foregroundColor: _passbookBytes.isEmpty ? context.colors.txtSec : context.colors.green),
                onPressed: () => _pickImage('passbook'),
              ),

              // Employment
              _sectionHeader('Employment Details', Icons.work),
              TextFormField(controller: _salary, style: const TextStyle(color: Colors.white), decoration: _field('Monthly Salary ₹ *', prefix: const Icon(Icons.currency_rupee, size: 18)), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              if (widget.allSites.isNotEmpty) ...[
                Text('Assign to Site *', style: TextStyle(color: context.colors.txtSec, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSiteId,
                  dropdownColor: context.colors.bgSurface,
                  style: const TextStyle(color: Colors.white),
                  items: widget.allSites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (val) => setState(() => _selectedSiteId = val!),
                  decoration: _field('Site *', prefix: const Icon(Icons.location_on, size: 18)),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: Icon(Icons.pin_drop, color: context.colors.red),
                label: Text(_customSiteLoc == null ? '📍 Override Site Location on Map' : 'Custom Location Selected!'),
                onPressed: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPickerScreen()));
                  if (result != null) setState(() => _customSiteLoc = result as Map<String, dynamic>);
                },
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                label: Text(widget.existing == null ? 'Add ${widget.role == 'executive' ? 'Executive' : 'Supervisor'}' : 'Save Changes'),
                style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
