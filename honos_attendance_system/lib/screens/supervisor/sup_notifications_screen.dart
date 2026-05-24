import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app_theme.dart';
import '../../models/app_notification.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import 'guards_list_screen.dart'; // We could import GuardProfileScreen instead if we want to deep link to it

// Assuming we have a GuardProfileScreen in supervisor folder? Wait, supervisors use GuardsListScreen and maybe edit sheet directly.
// Let's check where the GuardProfile is for supervisors... Wait, supervisor doesn't have a GuardProfileScreen! Admin does.
// Supervisor just taps a guard in GuardsListScreen and it opens the Edit form `_GuardFormSheet`.
// We can just pop back or push to GuardsListScreen, but ideally we show the edit form.
// For now, let's just push GuardsListScreen, and they can tap the guard.

class SupNotificationsScreen extends ConsumerWidget {
  const SupNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: notificationsAsync.when(
        data: (allNotifs) {
          final notifications = allNotifs.where((n) => n.supervisorId == user?.id && (n.type == 'edit_approved' || n.type == 'edit_rejected')).toList();

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
              return _SupNotificationCard(notification: notif).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1, end: 0);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.red))),
      ),
    );
  }
}

class _SupNotificationCard extends ConsumerWidget {
  final AppNotification notification;

  const _SupNotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isApproved = notification.type == 'edit_approved';

    return Card(
      color: notification.isRead ? AppTheme.bgSurface : AppTheme.primaryDark.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: notification.isRead ? AppTheme.bord : AppTheme.primary, width: notification.isRead ? 1 : 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (!notification.isRead) {
            await ref.read(dbProvider).markNotificationAsRead(notification.id);
          }
          if (isApproved && context.mounted) {
            // Push to guards list screen
            Navigator.push(context, MaterialPageRoute(builder: (_) => const GuardsListScreen()));
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
                      color: isApproved ? AppTheme.green.withValues(alpha: 0.2) : AppTheme.red.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isApproved ? Icons.check_circle : Icons.cancel,
                      color: isApproved ? AppTheme.green : AppTheme.red,
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
            ],
          ),
        ),
      ),
    );
  }
}
