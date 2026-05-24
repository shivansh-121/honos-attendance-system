import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app_theme.dart';
import '../../models/site.dart';
import '../../models/app_user.dart';
import '../../services/db_service.dart';
import '../../services/excel_service.dart';
import '../../widgets/base64_image_widget.dart';
import 'admin_supervisor_form_sheet.dart';
import 'supervisor_profile_screen.dart';

class ManageSupervisorsScreen extends ConsumerStatefulWidget {
  const ManageSupervisorsScreen({super.key});

  @override
  ConsumerState<ManageSupervisorsScreen> createState() => _ManageSupervisorsScreenState();
}

class _ManageSupervisorsScreenState extends ConsumerState<ManageSupervisorsScreen> {
  String _searchQuery = '';

  void _openSupervisorForm(BuildContext context, DbService db, List<Site> sites, {AppUser? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => AdminSupervisorFormSheet(
        db: db,
        allSites: sites,
        existing: existing,
        onSaved: () {},
      ),
    );
  }

  void _showDeleteConfirmation(AppUser sup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('Delete Supervisor?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to remove ${sup.name}? This action cannot be undone.', style: const TextStyle(color: AppTheme.txtSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () {
              ref.read(dbProvider).deleteUser(sup.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supervisor deleted'), backgroundColor: AppTheme.red));
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
          label: const Text('Add Supervisor'),
          backgroundColor: AppTheme.red,
          foregroundColor: Colors.white,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Supervisor Management', style: TextStyle(fontWeight: FontWeight.bold)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppTheme.primaryDark.withValues(alpha: 0.5)),
                  const Icon(Icons.admin_panel_settings, size: 100, color: Colors.white10),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download, color: AppTheme.green),
                tooltip: 'Export Supervisors Excel',
                onPressed: () async {
                  if (usersAsync.value == null || sitesAsync.value == null) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Supervisors Excel...')));
                  try {
                    final supervisors = usersAsync.value!.where((u) => u.role == 'supervisor').toList();
                    await ExcelService.exportAllSupervisors(supervisors, sitesAsync.value!);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red));
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
                  fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          usersAsync.when(
            data: (users) {
              final sites = sitesAsync.value ?? [];
              final filtered = users.where((u) {
                if (u.role != 'supervisor') return false;
                final matchQuery = u.name.toLowerCase().contains(_searchQuery.toLowerCase()) || u.username.toLowerCase().contains(_searchQuery.toLowerCase());
                return matchQuery;
              }).toList();

              if (filtered.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No supervisors found.', style: TextStyle(color: AppTheme.txtMuted))),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final sup = filtered[index];
                      final siteName = sites.firstWhere((s) => s.id == sup.siteId, orElse: () => const Site(id: '', name: 'Unknown Site', address: '', lat: 0, lng: 0, radius: 0)).name;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorProfileScreen(supervisor: sup)));
                        },
                        child: Card(
                          color: AppTheme.bgSurface,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Photo
                                Hero(
                                  tag: 'sup_${sup.id}',
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: AppTheme.bgElevated,
                                    backgroundImage: sup.photo.length > 200 ? MemoryImage(base64Decode(sup.photo)) : null,
                                    child: sup.photo.length < 200 ? Text(sup.name[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.txtMuted)) : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sup.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, color: AppTheme.primary, size: 14),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(siteName, style: const TextStyle(fontSize: 12, color: AppTheme.txtSec))),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone, color: AppTheme.txtMuted, size: 14),
                                          const SizedBox(width: 4),
                                          Text(sup.phone.isNotEmpty ? sup.phone : '--', style: const TextStyle(fontSize: 12, color: AppTheme.txtMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Actions
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
                                      onPressed: () => _openSupervisorForm(context, db, sites, existing: sup),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.red, size: 20),
                                      onPressed: () => _showDeleteConfirmation(sup),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, end: 0),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, __) => SliverFillRemaining(child: Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.red)))),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}
