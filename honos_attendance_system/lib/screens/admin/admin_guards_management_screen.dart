import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app_theme.dart';
import '../../services/db_service.dart';
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
    final attendanceAsync = ref.watch(todayAttendanceProvider);

    return Scaffold(
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
              child: TextField(
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
            ),
          ),
          guardsAsync.when(
            data: (guards) {
              final sites = sitesAsync.value ?? [];
              final filtered = guards.where((g) {
                final match = g.name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                    g.empId.toLowerCase().contains(_searchQuery.toLowerCase());
                return match;
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
                          final isPresent = attendance.any((a) =>
                              a.guardId == g.id &&
                              a.status.toLowerCase() == 'present');

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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isPresent ? AppTheme.green.withValues(alpha: 0.15) : AppTheme.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(isPresent ? Icons.check_circle : Icons.cancel, size: 14, color: isPresent ? AppTheme.green : AppTheme.red),
                                              const SizedBox(width: 4),
                                              Text(isPresent ? 'Present' : 'Absent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPresent ? AppTheme.green : AppTheme.red)),
                                            ],
                                          ),
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
