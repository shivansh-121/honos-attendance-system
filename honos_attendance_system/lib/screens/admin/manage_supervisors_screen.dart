import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app_theme.dart';
import '../../models/site.dart';
import '../../models/app_user.dart';
import '../../services/db_service.dart';
import 'admin_supervisor_form_sheet.dart';
import 'supervisor_profile_screen.dart';

class ManageSupervisorsScreen extends ConsumerStatefulWidget {
  final String role;

  const ManageSupervisorsScreen({super.key, this.role = 'supervisor'});

  @override
  ConsumerState<ManageSupervisorsScreen> createState() =>
      _ManageSupervisorsScreenState();
}

class _ManageSupervisorsScreenState
    extends ConsumerState<ManageSupervisorsScreen> {
  String _searchQuery = '';

  String get _roleLabel {
    if (widget.role == 'executive') return 'Executive';
    if (widget.role == 'employee') return 'Office Employee';
    return 'Supervisor';
  }

  void _openSupervisorForm(BuildContext context, DbService db, List<Site> sites,
      {AppUser? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bgSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
        title: Text('Delete $_roleLabel?',
            style: TextStyle(color: context.colors.txtPrimary)),
        content: Text(
            'Are you sure you want to remove ${sup.name}? This action cannot be undone.',
            style: TextStyle(color: context.colors.txtSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: context.colors.red),
            onPressed: () {
              ref.read(dbProvider).deleteUser(sup.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$_roleLabel deleted'),
                  backgroundColor: context.colors.red));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _changeLocation(AppUser u, List<Site> sites) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final filteredSites = sites
              .where((s) =>
                  s.name.toLowerCase().contains(query.toLowerCase()) ||
                  s.address.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: BoxDecoration(
              color: context.colors.bgBase,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Assign Site to ${u.name}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.colors.txtPrimary)),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: (v) => setSheetState(() => query = v),
                    style: TextStyle(color: context.colors.txtPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search site...',
                      prefixIcon:
                          Icon(Icons.search, color: context.colors.txtSec),
                      filled: true,
                      fillColor: context.colors.bgSurface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filteredSites.length,
                    itemBuilder: (context, index) {
                      final site = filteredSites[index];
                      final isCurrent = u.siteId == site.id;
                      return Card(
                        color: isCurrent
                            ? context.colors.primary.withValues(alpha: 0.1)
                            : context.colors.bgSurface,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: isCurrent
                                  ? context.colors.primary
                                  : context.colors.bord),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.location_on,
                              color: isCurrent
                                  ? context.colors.primary
                                  : context.colors.txtMuted),
                          title: Text(site.name,
                              style: TextStyle(
                                  color: context.colors.txtPrimary,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(site.address,
                              style: TextStyle(color: context.colors.txtSec),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          trailing: isCurrent
                              ? Icon(Icons.check_circle,
                                  color: context.colors.primary)
                              : null,
                          onTap: () async {
                            Navigator.pop(ctx);
                            final updatedUser = u.copyWith(siteId: site.id);
                            final messenger = ScaffoldMessenger.of(context);
                            final green = context.colors.green;
                            await ref.read(dbProvider).saveUser(updatedUser);
                            if (mounted) {
                              messenger.showSnackBar(SnackBar(
                                content:
                                    Text('${u.name} assigned to ${site.name}'),
                                backgroundColor: green,
                              ));
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
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
          icon: Icon(Icons.person_add, color: context.colors.bgBase),
          label: Text('Add $_roleLabel',
              style: TextStyle(color: context.colors.bgBase)),
          backgroundColor: context.colors.red,
          foregroundColor: Colors.white,
        ),
      ),
      body: responsiveBody(CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('$_roleLabel Management',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                      color: context.colors.primaryDark.withValues(alpha: 0.5)),
                  Icon(Icons.admin_panel_settings,
                      size: 100,
                      color: context.colors.txtPrimary.withValues(alpha: 0.1)),
                ],
              ),
            ),
            actions: const [],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: context.colors.txtPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name or username...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: context.colors.bgSurface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          usersAsync.when(
            data: (users) {
              final sites = sitesAsync.value ?? [];
              final staffList = users.where((u) {
                if (u.role != widget.role) return false;
                final matchQuery =
                    u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        u.username
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                return matchQuery;
              }).toList();

              if (staffList.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                      child: Text('No ${widget.role}s found.',
                          style: TextStyle(color: context.colors.txtMuted))),
                );
              }

              return ResponsiveSliverPadding(
                extraPadding: const EdgeInsets.symmetric(vertical: 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final u = staffList[index];
                      final siteName = sites
                          .firstWhere((s) => s.id == u.siteId,
                              orElse: () => const Site(
                                  id: '',
                                  name: 'Unknown Site',
                                  address: '',
                                  lat: 0,
                                  lng: 0,
                                  radius: 0))
                          .name;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      SupervisorProfileScreen(supervisor: u)));
                        },
                        child: Card(
                          color: context.colors.bgSurface,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'sup_${u.id}',
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: context.colors.bgElevated,
                                    backgroundImage: u.photo.length > 200
                                        ? MemoryImage(base64Decode(u.photo))
                                        : null,
                                    child: u.photo.length < 200
                                        ? Text(u.name[0],
                                            style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: context.colors.txtMuted))
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(u.name,
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  context.colors.txtPrimary)),
                                      if (u.empId.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text('Emp ID: ${u.empId}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: context.colors.primary,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      if (widget.role == 'supervisor' ||
                                          widget.role == 'employee') ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on,
                                                color: context.colors.primary,
                                                size: 14),
                                            const SizedBox(width: 4),
                                            Expanded(
                                                child: Text(siteName,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: context
                                                            .colors.txtSec))),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.phone,
                                              color: context.colors.txtMuted,
                                              size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                              u.phone.isNotEmpty
                                                  ? u.phone
                                                  : '--',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      context.colors.txtMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.role == 'supervisor' ||
                                        widget.role == 'employee')
                                      IconButton(
                                        icon: Icon(Icons.pin_drop_outlined,
                                            color: context.colors.primary,
                                            size: 20),
                                        tooltip: 'Change Location',
                                        onPressed: () =>
                                            _changeLocation(u, sites),
                                      ),
                                    IconButton(
                                      icon: Icon(Icons.edit,
                                          color: context.colors.primary,
                                          size: 20),
                                      tooltip: 'Edit Profile',
                                      onPressed: () => _openSupervisorForm(
                                          context, db, sites,
                                          existing: u),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: context.colors.red, size: 20),
                                      tooltip: 'Delete',
                                      onPressed: () =>
                                          _showDeleteConfirmation(u),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: (50 * index).ms)
                            .slideX(begin: 0.1, end: 0),
                      );
                    },
                    childCount: staffList.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, __) => SliverFillRemaining(
                child: Center(
                    child: Text('Error: $e',
                        style: TextStyle(color: context.colors.red)))),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      )),
    );
  }
}
