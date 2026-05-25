import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app_theme.dart';
import '../../models/leave.dart';
import '../../models/app_notification.dart';
import '../../services/db_service.dart';
import 'package:uuid/uuid.dart';

class AdminLeavesScreen extends ConsumerWidget {
  const AdminLeavesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(leavesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
      ),
      body: leavesAsync.when(
        data: (leaves) {
          if (leaves.isEmpty) {
            return Center(child: Text('No leave requests.', style: TextStyle(color: context.colors.txtMuted)));
          }

          // Show pending first, then approved/declined
          leaves.sort((a, b) {
            if (a.status == 'pending' && b.status != 'pending') return -1;
            if (a.status != 'pending' && b.status == 'pending') return 1;
            return b.createdAt.compareTo(a.createdAt);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaves.length,
            itemBuilder: (context, index) {
              final leave = leaves[index];
              final isPending = leave.status == 'pending';
              
              Color statusColor = context.colors.yellow;
              if (leave.status == 'approved') statusColor = context.colors.green;
              if (leave.status == 'declined') statusColor = context.colors.red;

              return Card(
                color: context.colors.bgSurface,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(leave.employeeName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(leave.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.date_range, color: context.colors.txtMuted, size: 16),
                          const SizedBox(width: 8),
                          Text('${leave.fromDate}  to  ${leave.toDate}', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Reason: ${leave.reason}', style: TextStyle(color: context.colors.txtSec)),
                      
                      if (isPending) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.colors.red,
                                  side: BorderSide(color: context.colors.red),
                                ),
                                onPressed: () async {
                                  await ref.read(dbProvider).updateLeaveStatus(leave.id, 'declined');
                                  
                                  // Send notification to employee
                                  final notif = AppNotification(
                                    id: const Uuid().v4(),
                                    type: 'leave_declined',
                                    title: 'Leave Request Declined',
                                    message: 'Your leave request for ${leave.fromDate} to ${leave.toDate} was declined.',
                                    guardId: '',
                                    supervisorId: leave.employeeId,
                                    timestamp: DateTime.now().toIso8601String(),
                                  );
                                  ref.read(dbProvider).saveNotification(notif).catchError((e) => debugPrint(e.toString()));

                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Leave Declined'), backgroundColor: context.colors.red));
                                },
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  await ref.read(dbProvider).updateLeaveStatus(leave.id, 'approved');

                                  // Send notification to employee
                                  final notif = AppNotification(
                                    id: const Uuid().v4(),
                                    type: 'leave_approved',
                                    title: 'Leave Request Approved',
                                    message: 'Your leave request for ${leave.fromDate} to ${leave.toDate} was approved.',
                                    guardId: '',
                                    supervisorId: leave.employeeId,
                                    timestamp: DateTime.now().toIso8601String(),
                                  );
                                  ref.read(dbProvider).saveNotification(notif).catchError((e) => debugPrint(e.toString()));

                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Leave Approved'), backgroundColor: context.colors.green));
                                },
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        )
                      ],
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, end: 0);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e', style: TextStyle(color: context.colors.red))),
      ),
    );
  }
}
