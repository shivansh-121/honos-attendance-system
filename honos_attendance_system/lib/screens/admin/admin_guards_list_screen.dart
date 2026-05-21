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
  void _markAttendance(String guardId, String status) {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final now = DateTime.now();
    final record = Attendance(
      id: const Uuid().v4(),
      guardId: guardId,
      siteId: 'site1', // Demo scope
      date: now.toIso8601String().split('T').first,
      time: '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      status: status,
      supervisorId: auth.id,
      markedAt: 'Manual Override (Admin)',
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
            child: Container(color: const Color(0xFF1B3B60).withOpacity(0.5)),
          ),
        ),
      ),
      body: guardsAsync.when(
        data: (guards) => attendanceAsync.when(
          data: (attendance) => guards.isEmpty
            ? const Center(child: Text('No guards assigned to sites yet.', style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: guards.length,
                itemBuilder: (ctx, i) {
                  final g = guards[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.white.withOpacity(0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF1B3B60),
                                backgroundImage: g.photo.length > 200 ? MemoryImage(base64Decode(g.photo)) : null,
                                child: g.photo.length <= 200 ? const Icon(Icons.person, color: Colors.white) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                    Text('ID: ${g.empId}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildActionRow(g.id, attendance),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (100 * i).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
                },
              ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildActionRow(String guardId, List<Attendance> attendance) {
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
                  Icon(isPresent ? Icons.check_circle : Icons.cancel, color: isPresent ? AppTheme.green : AppTheme.red, size: 20),
                  const SizedBox(width: 8),
                  Text('Marked ${latest.status}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _editingGuards.add(guardId);
                  });
                },
                icon: const Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                label: const Text('Edit', style: TextStyle(color: Colors.blueAccent)),
              )
            ],
          ),
          if (hasCheckIn || hasCheckOut) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Icon(Icons.login, size: 14, color: AppTheme.green),
                        const SizedBox(height: 2),
                        const Text('Check-In', style: TextStyle(fontSize: 9, color: Colors.white54)),
                        Text(hasCheckIn ? latest.time : '--:--',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasCheckIn ? AppTheme.green : Colors.white38)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.white12),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.logout, size: 14, color: hasCheckOut ? AppTheme.yellow : Colors.white38),
                        const SizedBox(height: 2),
                        const Text('Check-Out', style: TextStyle(fontSize: 9, color: Colors.white54)),
                        Text(hasCheckOut ? latest.checkOutTime : '--:--',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasCheckOut ? AppTheme.yellow : Colors.white38)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.white12),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: workingHours.isNotEmpty ? AppTheme.primary : Colors.white38),
                        const SizedBox(height: 2),
                        const Text('Working Hrs', style: TextStyle(fontSize: 9, color: Colors.white54)),
                        Text(workingHours.isNotEmpty ? workingHours : '--',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: workingHours.isNotEmpty ? AppTheme.primary : Colors.white38)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A9D8F), foregroundColor: Colors.white),
            onPressed: () => _markAttendance(guardId, 'Present'),
            icon: const Icon(Icons.check),
            label: const Text('Present'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63946), foregroundColor: Colors.white),
            onPressed: () => _markAttendance(guardId, 'Absent'),
            icon: const Icon(Icons.close),
            label: const Text('Absent'),
          ),
        ),
      ],
    );
  }
}
