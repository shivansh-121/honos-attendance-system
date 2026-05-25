import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app_theme.dart';
import '../../models/site.dart';
import '../../models/app_user.dart';
import '../../services/db_service.dart';
import '../../services/excel_service.dart';
import 'admin_supervisor_form_sheet.dart';
import 'supervisor_profile_screen.dart';

class ManageSupervisorsScreen extends ConsumerStatefulWidget {
  final String role;
  
  const ManageSupervisorsScreen({super.key, this.role = 'supervisor'});

  @override
  ConsumerState<ManageSupervisorsScreen> createState() => _ManageSupervisorsScreenState();
}

class _ManageSupervisorsScreenState extends ConsumerState<ManageSupervisorsScreen> {
  String _searchQuery = '';

  String get _roleLabel {
    if (widget.role == 'executive') return 'Executive';
    if (widget.role == 'employee') return 'Office Employee';
    return 'Supervisor';
  }

  void _openSupervisorForm(BuildContext context, DbService db, List<Site> sites, {AppUser? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => AdminSupervisorFormSheet(
        db: db,
        allSites: sites,
        existing: existing,
        role: widget.role,
        onSaved: () {},
      ),
    );
  }

  void _showDeleteConfirmation(AppUser sup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgSurface,
        title: Text('Delete $_roleLabel?', style: const TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to remove ${sup.name}? This action cannot be undone.', style: TextStyle(color: context.colors.txtSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.red),
            onPressed: () {
              ref.read(dbProvider).deleteUser(sup.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_roleLabel deleted'), backgroundColor: context.colors.red));
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
    final db = ref.read(dbProvider);

    return Scaffold(
      floatingActionButton: sitesAsync.whenOrNull(
        data: (sites) => FloatingActionButton.extended(
          onPressed: () => _openSupervisorForm(context, db, sites),
          icon: const Icon(Icons.person_add),
          label: Text('Add $_roleLabel'),
          backgroundColor: context.colors.red,
          foregroundColor: Colors.white,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('$_roleLabel Management', style: const TextStyle(fontWeight: FontWeight.bold)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: context.colors.primaryDark.withValues(alpha: 0.5)),
                  const Icon(Icons.admin_panel_settings, size: 100, color: Colors.white10),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.file_download, color: context.colors.green),
                tooltip: 'Export ${_roleLabel}s Excel',
                onPressed: () async {
                  if (usersAsync.value == null || sitesAsync.value == null) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generating ${_roleLabel}s Excel...')));
                  try {
                    final staff = usersAsync.value!.where((u) => u.role == widget.role).toList();
                    await ExcelService.exportAllSupervisors(staff, sitesAsync.value!);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.red));
                    }
                  }
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or username...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: context.colors.bgSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          usersAsync.when(
            data: (users) {
              final sites = sitesAsync.value ?? [];
              final staffList = users.where((u) {
                if (u.role != widget.role) return false;
                final matchQuery = u.name.toLowerCase().contains(_searchQuery.toLowerCase()) || u.username.toLowerCase().contains(_searchQuery.toLowerCase());
                return matchQuery;
              }).toList();

              if (staffList.isEmpty) {
                return SliverFillRemaining(
                  child: Center(child: Text('No ${widget.role}s found.', style: TextStyle(color: context.colors.txtMuted))),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final u = staffList[index];
                      final siteName = sites.firstWhere((s) => s.id == u.siteId, orElse: () => const Site(id: '', name: 'Unknown Site', address: '', lat: 0, lng: 0, radius: 0)).name;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorProfileScreen(supervisor: u)));
                        },
                        child: Card(
                          color: context.colors.bgSurface,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'sup_${u.id}',
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: context.colors.bgElevated,
                                    backgroundImage: u.photo.length > 200 ? MemoryImage(base64Decode(u.photo)) : null,
                                    child: u.photo.length < 200 ? Text(u.name[0], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.txtMuted)) : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                      if (u.empId.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text('Emp ID: ${u.empId}', style: TextStyle(fontSize: 12, color: context.colors.primary, fontWeight: FontWeight.bold)),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, color: context.colors.primary, size: 14),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(siteName, style: TextStyle(fontSize: 12, color: context.colors.txtSec))),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.phone, color: context.colors.txtMuted, size: 14),
                                          const SizedBox(width: 4),
                                          Text(u.phone.isNotEmpty ? u.phone : '--', style: TextStyle(fontSize: 12, color: context.colors.txtMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, color: context.colors.primary, size: 20),
                                      onPressed: () => _openSupervisorForm(context, db, sites, existing: u),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: context.colors.red, size: 20),
                                      onPressed: () => _showDeleteConfirmation(u),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, end: 0),
                      );
                    },
                    childCount: staffList.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, __) => SliverFillRemaining(child: Center(child: Text('Error: $e', style: TextStyle(color: context.colors.red)))),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}
