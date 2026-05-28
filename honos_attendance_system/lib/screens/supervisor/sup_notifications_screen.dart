import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../nl_theme.dart';
import '../../models/app_notification.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import 'guards_list_screen.dart';

class SupNotificationsScreen extends ConsumerWidget {
  const SupNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        title: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.txtPrimary)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.txtPrimary),
        elevation: 0,
        centerTitle: false,
      ),
      body: notificationsAsync.when(
        data: (allNotifs) {
          final notifications = allNotifs.where((n) => n.supervisorId == user?.id && (n.type == 'edit_approved' || n.type == 'edit_rejected')).toList();

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.colors.bgSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_none, size: 64, color: context.colors.txtSec),
                  ),
                  const SizedBox(height: 24),
                  Text('All caught up!', style: TextStyle(color: context.colors.txtPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('You have no new notifications right now.', style: TextStyle(color: context.colors.txtSec, fontSize: 14)),
                ],
              ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
            itemCount: notifications.length,
            itemBuilder: (ctx, i) {
              final notif = notifications[i];
              return _SupNotificationCard(notification: notif).animate().fadeIn(delay: (i * 40).ms).slideX(begin: 0.05, end: 0);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: NLTheme.accentPink))),
      ),
    );
  }
}

class _SupNotificationCard extends ConsumerWidget {
  final AppNotification notification;

  const _SupNotificationCard({required this.notification});

  String _timeAgo(String timestamp) {
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return DateFormat('MMM dd').format(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isApproved = notification.type == 'edit_approved';
    
    final iconData = isApproved ? Icons.check_circle : Icons.cancel;
    final iconColor = isApproved ? NLTheme.accentGreen : NLTheme.accentPink;
    final bgColor = isApproved ? NLTheme.accentGreen.withValues(alpha: 0.1) : NLTheme.accentPink.withValues(alpha: 0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isRead ? context.colors.txtSec.withValues(alpha: 0.05) : context.colors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          if (!notification.isRead)
            BoxShadow(
              color: context.colors.primary.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: context.colors.bord,
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              if (!notification.isRead) {
                await ref.read(dbProvider).markNotificationAsRead(notification.id);
              }
              if (isApproved && context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GuardsListScreen()));
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin Avatar Tag
                  Column(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        backgroundImage: AssetImage('assets/images/logo.png'),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Admin', style: TextStyle(color: context.colors.bgBase, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.colors.txtPrimary),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _timeAgo(notification.timestamp),
                                  style: TextStyle(color: context.colors.txtSec, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => ref.read(dbProvider).deleteNotification(notification.id),
                                  child: Icon(Icons.close, color: context.colors.txtSec, size: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: TextStyle(color: context.colors.txtSec, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  // Unread Indicator
                  if (!notification.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
