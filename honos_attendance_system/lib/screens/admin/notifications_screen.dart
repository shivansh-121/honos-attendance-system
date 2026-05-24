import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../app_theme.dart';
import '../../models/app_notification.dart';
import '../../models/guard.dart';
import '../../services/db_service.dart';
import 'guard_profile_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: AppTheme.txtMuted),
                  SizedBox(height: 16),
                  Text('No notifications yet', style: TextStyle(color: AppTheme.txtSec, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final notif = notifications[i];
              return _NotificationCard(
                notification: notif,
                guardsAsync: guardsAsync,
              ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1, end: 0);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.red))),
      ),
    );
  }
}

class _NotificationCard extends ConsumerStatefulWidget {
  final AppNotification notification;
  final AsyncValue<List<Guard>> guardsAsync;

  const _NotificationCard({required this.notification, required this.guardsAsync});

  @override
  ConsumerState<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends ConsumerState<_NotificationCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final isEditRequest = notification.type == 'edit_request';
    final isPending = notification.status == 'pending';

    return Card(
      color: notification.isRead ? AppTheme.bgSurface : AppTheme.primaryDark.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: notification.isRead ? AppTheme.bord : AppTheme.primary, width: notification.isRead ? 1 : 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Mark as read (does not hide buttons since that relies on status == pending)
          if (!notification.isRead) {
            await ref.read(dbProvider).markNotificationAsRead(notification.id);
          }

          // Navigate to Guard Profile
          if (widget.guardsAsync.value != null) {
            final guard = widget.guardsAsync.value!.where((g) => g.id == notification.guardId).firstOrNull;
            if (guard != null && context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => GuardProfileScreen(guard: guard)));
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guard not found (may have been deleted)')));
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isEditRequest ? AppTheme.yellow.withValues(alpha: 0.2) : AppTheme.green.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEditRequest ? Icons.edit_note : Icons.person_add,
                      color: isEditRequest ? AppTheme.yellow : AppTheme.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
                            // Delete Button
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.txtMuted, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await ref.read(dbProvider).deleteNotification(notification.id);
                              },
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(notification.message, style: const TextStyle(color: AppTheme.txtSec, fontSize: 13)),
                        if (!isPending && isEditRequest)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Status: ${notification.status.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: notification.status == 'approved' ? AppTheme.green : AppTheme.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!notification.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
              if (isEditRequest && isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.red,
                          side: const BorderSide(color: AppTheme.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isProcessing ? null : () async {
                          setState(() => _isProcessing = true);
                          try {
                            await ref.read(dbProvider).updateNotificationStatus(notification.id, 'rejected');
                            await ref.read(dbProvider).markNotificationAsRead(notification.id);
                            
                            final reply = AppNotification(
                              id: const Uuid().v4(),
                              type: 'edit_rejected',
                              title: 'Edit Request Rejected',
                              message: 'Admin rejected your request to edit guard details.',
                              guardId: notification.guardId,
                              supervisorId: notification.supervisorId,
                              timestamp: DateTime.now().toIso8601String(),
                            );
                            await ref.read(dbProvider).saveNotification(reply);
                            
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request rejected')));
                          } finally {
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isProcessing ? null : () async {
                          setState(() => _isProcessing = true);
                          try {
                            if (widget.guardsAsync.value != null) {
                              final guard = widget.guardsAsync.value!.where((g) => g.id == notification.guardId).firstOrNull;
                              if (guard != null) {
                                final updatedGuard = Guard(
                                  id: guard.id, name: guard.name, empId: guard.empId, photo: guard.photo, siteId: guard.siteId, supervisorId: guard.supervisorId,
                                  phone: guard.phone, dob: guard.dob, address: guard.address, aadharNo: guard.aadharNo, aadharPhoto: guard.aadharPhoto,
                                  bankName: guard.bankName, accountNo: guard.accountNo, ifsc: guard.ifsc, branch: guard.branch, passbookPhoto: guard.passbookPhoto,
                                  salary: guard.salary, joinDate: guard.joinDate, status: guard.status,
                                  isEditableBySupervisor: true,
                                );
                                await ref.read(dbProvider).saveGuard(updatedGuard);
                                await ref.read(dbProvider).updateNotificationStatus(notification.id, 'approved');
                                await ref.read(dbProvider).markNotificationAsRead(notification.id);
                                
                                final reply = AppNotification(
                                  id: const Uuid().v4(),
                                  type: 'edit_approved',
                                  title: 'Edit Request Approved',
                                  message: 'Admin approved your request to edit guard details. Tap here to edit.',
                                  guardId: notification.guardId,
                                  supervisorId: notification.supervisorId,
                                  timestamp: DateTime.now().toIso8601String(),
                                );
                                await ref.read(dbProvider).saveNotification(reply);

                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit permission granted!'), backgroundColor: AppTheme.green));
                              }
                            }
                          } finally {
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
