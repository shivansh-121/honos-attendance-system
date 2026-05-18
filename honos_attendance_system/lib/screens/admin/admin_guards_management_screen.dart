import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../app_theme.dart';
import '../../services/db_service.dart';
import '../../widgets/base64_image_widget.dart';
import '../../models/guard.dart';
import '../../models/site.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
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

  void _showAddGuardDialog(List<Site> allSites) {
    if (allSites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a Site first!')));
      return;
    }
    final nameCtrl = TextEditingController();
    final empIdCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedSiteId = allSites.first.id;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('Add New Guard', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setSt) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 12),
                TextField(controller: empIdCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Employee ID')),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Phone Number')),
                const SizedBox(height: 20),
                const Text('Assign to Site:', style: TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedSiteId,
                  dropdownColor: AppTheme.bgSurface,
                  style: const TextStyle(color: Colors.white),
                  items: allSites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setSt(() => selectedSiteId = val!),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || empIdCtrl.text.trim().isEmpty) return;
              final newGuard = Guard(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim(),
                empId: empIdCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                siteId: selectedSiteId,
                supervisorId: allSites.firstWhere((s) => s.id == selectedSiteId).supervisorId,
                photo: '', // Photo can be captured later by the supervisor
                joinDate: DateTime.now().toIso8601String().split('T').first,
                salary: 0,
              );
              await ref.read(dbProvider).saveGuard(newGuard);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guard added successfully!'), backgroundColor: AppTheme.green));
              }
            },
            child: const Text('Add Guard'),
          ),
        ],
      ),
    );
  }

  void _showEditGuardDialog(Guard guard, List<Site> allSites) {
    final nameCtrl = TextEditingController(text: guard.name);
    final empIdCtrl = TextEditingController(text: guard.empId);
    final phoneCtrl = TextEditingController(text: guard.phone);
    String selectedSiteId = guard.siteId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('Edit Guard / Transfer Site', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setSt) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 12),
                TextField(controller: empIdCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Employee ID')),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Phone Number')),
                const SizedBox(height: 20),
                const Text('Current Work Site:', style: TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: allSites.any((s) => s.id == selectedSiteId) ? selectedSiteId : null,
                  dropdownColor: AppTheme.bgSurface,
                  style: const TextStyle(color: Colors.white),
                  items: allSites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setSt(() => selectedSiteId = val!),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                const SizedBox(height: 12),
                const Text('Tip: Transferring a guard here will instantly move them to the new supervisor\'s attendance list.', 
                  style: TextStyle(color: AppTheme.txtMuted, fontSize: 11), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final updatedGuard = Guard(
                id: guard.id,
                name: nameCtrl.text.trim(),
                empId: empIdCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                siteId: selectedSiteId,
                supervisorId: allSites.firstWhere((s) => s.id == selectedSiteId, orElse: () => const Site(id: '', name: '', address: '', lat: 0, lng: 0, radius: 0)).supervisorId,
                photo: guard.photo,
                joinDate: guard.joinDate,
                salary: guard.salary,
              );
              await ref.read(dbProvider).saveGuard(updatedGuard);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guard updated and transferred!'), backgroundColor: AppTheme.green));
            },
            child: const Text('Update & Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guardsAsync = ref.watch(guardsStreamProvider);
    final sitesAsync = ref.watch(sitesStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);

    return Scaffold(
      floatingActionButton: sitesAsync.whenOrNull(
        data: (sites) => FloatingActionButton.extended(
          onPressed: () => _showAddGuardDialog(sites),
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
                          data: (sites) => DropdownButtonFormField<String>(
                            value: _selectedSiteFilter,
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
                          ),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: usersAsync.when(
                          data: (users) {
                            final supervisors = users.where((u) => u.role == 'supervisor').toList();
                            return DropdownButtonFormField<String>(
                              value: _selectedSupervisorFilter,
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
                    child: Text('No guards found.',
                        style: TextStyle(color: AppTheme.txtMuted)),
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
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          GuardProfileScreen(guard: g))),
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
                                              width: 56,
                                              height: 56,
                                              child: g.photo.length > 200
                                                  ? Base64ImageWidget(
                                                      base64String: g.photo,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Container(
                                                      color: AppTheme.primary
                                                          .withValues(alpha: 0.2),
                                                      alignment: Alignment.center,
                                                      child: Text(g.name[0],
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                              color: AppTheme
                                                                  .primary)),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(g.name,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.white)),
                                              const SizedBox(height: 4),
                                              Text('Current Site: $siteName', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.badge,
                                                      size: 14,
                                                      color: AppTheme.txtMuted),
                                                  const SizedBox(width: 4),
                                                  Text(g.empId,
                                                      style: const TextStyle(
                                                          color: AppTheme.txtSec,
                                                          fontSize: 13)),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_location_alt, color: AppTheme.primary),
                                          tooltip: 'Transfer Site',
                                          onPressed: () => _showEditGuardDialog(g, sites),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24, color: AppTheme.bord),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.phone, size: 14, color: AppTheme.txtMuted),
                                            const SizedBox(width: 4),
                                            Text(g.phone.isEmpty ? 'N/A' : g.phone, style: const TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(statusIcon, size: 14, color: statusColor),
                                                  const SizedBox(width: 4),
                                                  Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                                                ],
                                              ),
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
                          ).animate().fadeIn(delay: (index * 50).ms).slideX(
                              begin: 0.1, end: 0, curve: Curves.easeOutQuad);
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
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, __) =>
                SliverFillRemaining(child: Center(child: Text('Error: $e'))),
          ),
        ],
      ),
    );
  }
}
