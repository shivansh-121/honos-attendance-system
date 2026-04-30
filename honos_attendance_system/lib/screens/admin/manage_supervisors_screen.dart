import 'dart:ui';
import '../../models/site.dart';
import '../../app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../services/db_service.dart';
import '../../models/app_user.dart';
import 'map_picker_screen.dart';

class ManageSupervisorsScreen extends ConsumerStatefulWidget {
  const ManageSupervisorsScreen({super.key});

  @override
  ConsumerState<ManageSupervisorsScreen> createState() =>
      _ManageSupervisorsScreenState();
}

class _ManageSupervisorsScreenState
    extends ConsumerState<ManageSupervisorsScreen> {
  void _showAddDialog(List<Site> allSites) {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    Map<String, dynamic>? selectedLoc;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title:
            const Text('Add Supervisor', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setSt) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 12),
                TextField(
                    controller: userCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 12),
                TextField(
                    controller: passCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 20),
                const Text('New Site Location:',
                    style: TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.pin_drop, color: AppTheme.red),
                  label: Text(selectedLoc == null
                      ? '📍 Pick Site on Map'
                      : 'Location Selected!'),
                  onPressed: () async {
                    final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MapPickerScreen()));
                    if (result != null) {
                      setSt(() => selectedLoc = result as Map<String, dynamic>);
                    }
                  },
                ),
                if (selectedLoc != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(selectedLoc!['address'],
                        style: const TextStyle(
                            color: AppTheme.green, fontSize: 11),
                        textAlign: TextAlign.center),
                  )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty ||
                  userCtrl.text.isEmpty ||
                  passCtrl.text.isEmpty ||
                  selectedLoc == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fill all fields!')));
                return;
              }
              final siteId = const Uuid().v4();
              final newSite = Site(
                  id: siteId,
                  name: "${nameCtrl.text.trim()}'s Site",
                  address: selectedLoc!['address'],
                  lat: selectedLoc!['lat'],
                  lng: selectedLoc!['lng'],
                  radius: 250);
              final newUser = AppUser(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  username: userCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  role: 'supervisor',
                  siteId: siteId);
              ref.read(dbProvider).saveSite(newSite);
              ref.read(dbProvider).saveUser(newUser);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(AppUser sup, List<Site> allSites) {
    final nameCtrl = TextEditingController(text: sup.name);
    final userCtrl = TextEditingController(text: sup.username);
    final passCtrl = TextEditingController(text: sup.password);
    String selectedSiteId = sup.siteId;
    Map<String, dynamic>? updatedLoc;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('Edit Supervisor',
            style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setSt) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 12),
                TextField(
                    controller: userCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 12),
                TextField(
                    controller: passCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 20),
                const Text('Assign Site:',
                    style: TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: allSites.any((s) => s.id == selectedSiteId)
                      ? selectedSiteId
                      : null,
                  dropdownColor: AppTheme.bgSurface,
                  style: const TextStyle(color: Colors.white),
                  items: allSites
                      .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) => setSt(() => selectedSiteId = val!),
                  decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                const SizedBox(height: 20),
                const Text('Update Site Location:',
                    style: TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.map, color: AppTheme.primary),
                  label: Text(updatedLoc == null
                      ? '📍 Move Selected Site'
                      : 'New Location Set'),
                  onPressed: () async {
                    final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MapPickerScreen()));
                    if (result != null) {
                      setSt(() => updatedLoc = result as Map<String, dynamic>);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              // 1. Update Site if location changed
              if (updatedLoc != null) {
                final oldSite =
                    allSites.firstWhere((s) => s.id == selectedSiteId);
                final newSite = Site(
                  id: oldSite.id,
                  name: oldSite.name,
                  address: updatedLoc!['address'],
                  lat: updatedLoc!['lat'],
                  lng: updatedLoc!['lng'],
                  radius: oldSite.radius,
                  supervisorId: sup.id,
                );
                await ref.read(dbProvider).saveSite(newSite);
              }

              // 2. Update User
              final updatedUser = AppUser(
                id: sup.id,
                name: nameCtrl.text.trim(),
                username: userCtrl.text.trim(),
                password: passCtrl.text.trim(),
                role: 'supervisor',
                siteId: selectedSiteId,
              );
              await ref.read(dbProvider).saveUser(updatedUser);

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Supervisor Updated!'),
                  backgroundColor: AppTheme.green));
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(AppUser sup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('Delete Supervisor?',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to remove ${sup.name}? This action cannot be undone.',
            style: const TextStyle(color: AppTheme.txtSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () {
              ref.read(dbProvider).deleteUser(sup.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Supervisor deleted'),
                  backgroundColor: AppTheme.red));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersStreamProvider);
    final sitesAsync = ref.watch(sitesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Supervisors',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                    color: const Color(0xFF1B3B60).withOpacity(0.5)))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(sitesAsync.value ?? []),
        icon: const Icon(Icons.add),
        label: const Text('New Supervisor'),
        backgroundColor: AppTheme.red,
      ).animate().scale(delay: 400.ms),
      body: usersAsync.when(
        data: (users) {
          final supervisors =
              users.where((u) => u.role == 'supervisor').toList();
          final sites = sitesAsync.value ?? [];
          return supervisors.isEmpty
              ? const Center(
                  child: Text('No supervisors found.',
                      style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: supervisors.length,
                  itemBuilder: (ctx, i) {
                    final sup = supervisors[i];
                    final siteName = sites
                        .firstWhere((s) => s.id == sup.siteId,
                            orElse: () => const Site(
                                id: '',
                                name: 'No Site',
                                address: '',
                                lat: 0,
                                lng: 0,
                                radius: 0))
                        .name;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: Color(0xFF1B3B60),
                            child: Icon(Icons.person, color: Colors.white)),
                        title: Text(sup.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        subtitle: Text(
                            'Site: $siteName\nUser: ${sup.username} | Pass: ${sup.password}',
                            style: const TextStyle(
                                color: AppTheme.txtSec, fontSize: 12)),
                        isThreeLine: false,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: AppTheme.primary, size: 20),
                                    onPressed: () =>
                                        _showEditDialog(sup, sites),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                      color: AppTheme.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppTheme.red, size: 20),
                                    onPressed: () =>
                                        _showDeleteConfirmation(sup),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (100 * i).ms)
                        .slideX(begin: 0.1, end: 0);
                  },
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
