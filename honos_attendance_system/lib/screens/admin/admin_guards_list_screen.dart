import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../models/attendance.dart';
import '../../app_theme.dart';

class AdminGuardsListScreen extends ConsumerStatefulWidget {
  const AdminGuardsListScreen({super.key});

  @override
  ConsumerState<AdminGuardsListScreen> createState() => _AdminGuardsListScreenState();
}

class _AdminGuardsListScreenState extends ConsumerState<AdminGuardsListScreen> {
  final Set<String> _editingGuards = {};
  void _markAttendance(String guardId, String status, String siteId) {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final todayAtt = ref.read(todayAttendanceProvider).value ?? [];
    final today = DateTime.now().toIso8601String().split('T').first;
    final existing = todayAtt.where((a) => a.guardId == guardId && a.date == today).lastOrNull;

    final now = DateTime.now();
    final record = Attendance(
      id: existing?.id ?? const Uuid().v4(),
      guardId: guardId,
      siteId: siteId,
      date: today,
      time: existing?.time.isNotEmpty == true ? existing!.time : '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      status: status,
      supervisorId: auth.id,
      markedAt: 'Manual Override (Admin)',
      checkOutTime: existing?.checkOutTime ?? '',
    );

    ref.read(dbProvider).saveAttendance(record);
    
    setState(() {
      _editingGuards.remove(guardId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guard manually marked as $status')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guardsAsync = ref.watch(guardsStreamProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Override', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: context.colors.bgElevated.withValues(alpha: 0.8)),
          ),
        ),
      ),
      body: guardsAsync.when(
        data: (guards) => attendanceAsync.when(
          data: (attendance) => guards.isEmpty
            ? Center(child: Text('No guards assigned to sites yet.', style: TextStyle(color: context.colors.txtMuted)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: guards.length,
                itemBuilder: (ctx, i) {
                  final g = guards[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: context.colors.bgElevated.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: context.colors.primary,
                                backgroundImage: g.photo.length > 200 ? MemoryImage(base64Decode(g.photo)) : null,
                                child: g.photo.length <= 200 ? Icon(Icons.person, color: context.colors.txtPrimary) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(g.name, style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.txtPrimary, fontSize: 16)),
                                    Text('ID: ${g.empId}', style: TextStyle(color: context.colors.txtSec, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildActionRow(g.id, g.siteId, attendance),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (100 * i).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
                },
              ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(child: Text('Error: $e', style: TextStyle(color: context.colors.txtPrimary))),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e', style: TextStyle(color: context.colors.txtPrimary))),
      ),
    );
  }

  Widget _buildActionRow(String guardId, String siteId, List<Attendance> attendance) {
    // Check if attendance is already marked today
    final today = DateTime.now().toIso8601String().split('T').first;
    final allAtt = attendance.where((a) => a.guardId == guardId && a.date == today).toList();
    
    // Process the latest status if it exists and we're not explicitly editing
    if (allAtt.isNotEmpty && !_editingGuards.contains(guardId)) {
      final latest = allAtt.last;
      final isPresent = latest.status == 'Present';
      final hasCheckIn = latest.time.isNotEmpty;
      final hasCheckOut = latest.checkOutTime.isNotEmpty;

      // Calculate working hours
      String workingHours = '';
      if (hasCheckIn && hasCheckOut) {
        try {
          final inParts = latest.time.split(':');
          final outParts = latest.checkOutTime.split(':');
          if (inParts.length >= 2 && outParts.length >= 2) {
            final inMin = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
            final outMin = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
            final diff = outMin - inMin;
            if (diff > 0) {
              workingHours = '${diff ~/ 60}h ${diff % 60}m';
            }
          }
        } catch (_) {}
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isPresent ? Icons.check_circle : Icons.cancel, color: isPresent ? context.colors.green : context.colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text('Marked ${latest.status}', style: TextStyle(color: context.colors.txtPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _editingGuards.add(guardId);
                  });
                },
                icon: Icon(Icons.edit, size: 16, color: context.colors.blue),
                label: Text('Edit', style: TextStyle(color: context.colors.blue)),
              )
            ],
          ),
          if (hasCheckIn || hasCheckOut) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.bgElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.login, size: 14, color: context.colors.green),
                        const SizedBox(height: 2),
                        Text('Check-In', style: TextStyle(fontSize: 9, color: context.colors.txtMuted)),
                        Text(hasCheckIn ? latest.time : '--:--',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasCheckIn ? context.colors.green : context.colors.txtMuted)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: context.colors.bord),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.logout, size: 14, color: hasCheckOut ? context.colors.yellow : context.colors.txtMuted),
                        const SizedBox(height: 2),
                        Text('Check-Out', style: TextStyle(fontSize: 9, color: context.colors.txtMuted)),
                        Text(hasCheckOut ? latest.checkOutTime : '--:--',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasCheckOut ? context.colors.yellow : context.colors.txtMuted)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: context.colors.bord),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: workingHours.isNotEmpty ? context.colors.primary : context.colors.txtMuted),
                        const SizedBox(height: 2),
                        Text('Working Hrs', style: TextStyle(fontSize: 9, color: context.colors.txtMuted)),
                        Text(workingHours.isNotEmpty ? workingHours : '--',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: workingHours.isNotEmpty ? context.colors.primary : context.colors.txtMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Default: Show action buttons (Present / Absent)
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.green, foregroundColor: Colors.white),
            onPressed: () => _markAttendance(guardId, 'Present', siteId),
            icon: const Icon(Icons.check),
            label: const Text('Present'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.red, foregroundColor: Colors.white),
            onPressed: () => _markAttendance(guardId, 'Absent', siteId),
            icon: const Icon(Icons.close),
            label: const Text('Absent'),
          ),
        ),
      ],
    );
  }
}
