import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../app_theme.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/guard.dart';
import '../../services/db_service.dart';
import 'guard_profile_screen.dart';
import 'admin_leaves_screen.dart';
import 'supervisor_profile_screen.dart';
import '../user_profile_screen.dart';
import '../employee/apply_leave_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final user = ref.watch(authProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: responsiveBody(
        notificationsAsync.when(
          data: (allNotifs) {
            final notifications = allNotifs.where((n) {
              if (user?.role == 'admin') return true;
              if (n.type == 'edit_request') return false;
              return n.supervisorId == user?.id || n.guardId == user?.id;
            }).toList();

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
                      child: Icon(Icons.notifications_none,
                          size: 64, color: context.colors.txtMuted),
                    ),
                    const SizedBox(height: 24),
                    Text('All caught up!',
                        style: TextStyle(
                            color: context.colors.txtPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('You have no new notifications right now.',
                        style: TextStyle(
                            color: context.colors.txtSec, fontSize: 14)),
                  ],
                ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 8, bottom: 32),
              itemCount: notifications.length,
              itemBuilder: (ctx, i) {
                final notif = notifications[i];
                return _NotificationCard(
                  notification: notif,
                  guardsAsync: guardsAsync,
                  usersAsync: usersAsync,
                )
                    .animate()
                    .fadeIn(delay: (i * 40).ms)
                    .slideX(begin: 0.05, end: 0);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: TextStyle(color: context.colors.red))),
        ),
        maxWidth: 800,
      ),
    );
  }
}

class _NotificationCard extends ConsumerStatefulWidget {
  final AppNotification notification;
  final AsyncValue<List<Guard>> guardsAsync;
  final AsyncValue<List<AppUser>> usersAsync;

  const _NotificationCard(
      {required this.notification,
      required this.guardsAsync,
      required this.usersAsync});

  @override
  ConsumerState<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends ConsumerState<_NotificationCard> {
  bool _isProcessing = false;

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
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final notification = widget.notification;
    final isEditRequest = notification.type == 'edit_request';
    final isApprovedOrRejected = notification.type == 'edit_approved' ||
        notification.type == 'edit_rejected';
    final isPending = notification.status == 'pending';

    Widget avatarWidget;

    if (isApprovedOrRejected) {
      avatarWidget = Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Admin',
                style: TextStyle(
                    color: context.colors.bgBase,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      );
    } else {
      String? photoStr;
      if (notification.supervisorId.isNotEmpty &&
          widget.usersAsync.value != null) {
        final sender = widget.usersAsync.value!
            .where((u) => u.id == notification.supervisorId)
            .firstOrNull;
        if (sender != null) {
          photoStr = sender.photo;
        }
      }

      if (photoStr != null && photoStr.length > 200) {
        avatarWidget = CircleAvatar(
          radius: 22,
          backgroundColor: context.colors.bgElevated,
          backgroundImage: MemoryImage(base64Decode(photoStr)),
        );
      } else {
        final iconData =
            isEditRequest ? Icons.edit_document : Icons.notifications;
        final iconColor =
            isEditRequest ? context.colors.yellow : context.colors.primary;
        final bgColor = isEditRequest
            ? context.colors.yellow.withValues(alpha: 0.1)
            : context.colors.primary.withValues(alpha: 0.1);

        avatarWidget = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconData, color: iconColor, size: 22),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead
            ? context.colors.bgSurface
            : context.colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isRead
              ? context.colors.txtPrimary.withValues(alpha: 0.03)
              : context.colors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          if (!notification.isRead)
            BoxShadow(
              color: context.colors.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 1,
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
                await ref
                    .read(dbProvider)
                    .markNotificationAsRead(notification.id);
              }

              if (!context.mounted) return;

              if (notification.type == 'edit_approved' ||
                  notification.type == 'edit_rejected') {
                if (user?.role == 'supervisor' &&
                    notification.guardId.isNotEmpty &&
                    notification.guardId != user?.id) {
                  final guard = widget.guardsAsync.value
                      ?.where((g) => g.id == notification.guardId)
                      .firstOrNull;
                  if (guard != null) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GuardProfileScreen(guard: guard)));
                    return;
                  }
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UserProfileScreen()));
                return;
              }

              if (notification.type == 'leave_approved' ||
                  notification.type == 'leave_declined') {
                if (user?.role != 'admin') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ApplyLeaveScreen()));
                  return;
                }
              }

              if (notification.type == 'edit_request' ||
                  notification.type == 'leave_request') {
                if (user?.role == 'admin') {
                  if (notification.supervisorId.isNotEmpty &&
                      widget.usersAsync.value != null) {
                    final sender = widget.usersAsync.value!
                        .where((u) => u.id == notification.supervisorId)
                        .firstOrNull;
                    if (sender != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  SupervisorProfileScreen(supervisor: sender)));
                      return;
                    }
                  }
                  if (notification.guardId.isNotEmpty &&
                      widget.guardsAsync.value != null) {
                    final guard = widget.guardsAsync.value!
                        .where((g) => g.id == notification.guardId)
                        .firstOrNull;
                    if (guard != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  GuardProfileScreen(guard: guard)));
                      return;
                    }
                  }

                  if (notification.type == 'leave_request') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminLeavesScreen()));
                  }
                }
                return;
              }

              if (user?.role == 'admin' &&
                  widget.guardsAsync.value != null &&
                  notification.guardId.isNotEmpty) {
                final guard = widget.guardsAsync.value!
                    .where((g) => g.id == notification.guardId)
                    .firstOrNull;
                if (guard != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GuardProfileScreen(guard: guard)));
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender Avatar or Icon
                      avatarWidget,
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
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: context.colors.txtPrimary),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _timeAgo(notification.timestamp),
                                      style: TextStyle(
                                          color: context.colors.txtMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => ref
                                          .read(dbProvider)
                                          .deleteNotification(notification.id),
                                      child: Icon(Icons.close,
                                          color: context.colors.txtMuted,
                                          size: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notification.message,
                              style: TextStyle(
                                  color: context.colors.txtSec,
                                  fontSize: 14,
                                  height: 1.4),
                            ),

                            // Status Badge (if not pending)
                            if (!isPending && isEditRequest)
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: notification.status == 'approved'
                                      ? context.colors.green
                                          .withValues(alpha: 0.1)
                                      : context.colors.red
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: notification.status == 'approved'
                                          ? context.colors.green
                                              .withValues(alpha: 0.3)
                                          : context.colors.red
                                              .withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  notification.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: notification.status == 'approved'
                                        ? context.colors.green
                                        : context.colors.red,
                                  ),
                                ),
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
                          decoration: BoxDecoration(
                              color: context.colors.primary,
                              shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),

                  // Action Buttons for Pending Request
                  if (isEditRequest && isPending) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: context.colors.txtPrimary
                                      .withValues(alpha: 0.1)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    setState(() => _isProcessing = true);
                                    try {
                                      await ref
                                          .read(dbProvider)
                                          .updateNotificationStatus(
                                              notification.id, 'rejected');
                                      await ref
                                          .read(dbProvider)
                                          .markNotificationAsRead(
                                              notification.id);

                                      final reply = AppNotification(
                                        id: const Uuid().v4(),
                                        type: 'edit_rejected',
                                        title: 'Edit Request Rejected',
                                        message:
                                            'Admin rejected your request to edit details.',
                                        guardId: notification.guardId,
                                        supervisorId: notification.supervisorId,
                                        timestamp:
                                            DateTime.now().toIso8601String(),
                                      );
                                      await ref
                                          .read(dbProvider)
                                          .saveNotification(reply);
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isProcessing = false);
                                      }
                                    }
                                  },
                            child: const Text('Reject',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.colors.primary,
                              foregroundColor: context.colors.bgBase,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    setState(() => _isProcessing = true);
                                    try {
                                      final usersList = await ref
                                          .read(dbProvider)
                                          .usersStream()
                                          .first;
                                      final userTarget = usersList
                                          .where((u) =>
                                              u.id == notification.guardId)
                                          .firstOrNull;

                                      if (userTarget != null) {
                                        // It's an AppUser (Executive, Supervisor, Employee)
                                        await ref
                                            .read(dbProvider)
                                            .updateUserField(
                                                notification.guardId, {
                                          'isEditableBySupervisor': true
                                        });
                                        await ref
                                            .read(dbProvider)
                                            .updateNotificationStatus(
                                                notification.id, 'approved');
                                        await ref
                                            .read(dbProvider)
                                            .markNotificationAsRead(
                                                notification.id);

                                        final reply = AppNotification(
                                          id: const Uuid().v4(),
                                          type: 'edit_approved',
                                          title: 'Edit Request Approved',
                                          message:
                                              'Admin approved your request to edit your profile details.',
                                          guardId: notification.guardId,
                                          supervisorId:
                                              notification.supervisorId,
                                          timestamp:
                                              DateTime.now().toIso8601String(),
                                        );
                                        await ref
                                            .read(dbProvider)
                                            .saveNotification(reply);
                                      } else {
                                        // It's a Guard
                                        await ref
                                            .read(dbProvider)
                                            .updateGuardField(
                                                notification.guardId, {
                                          'isEditableBySupervisor': true
                                        });
                                        await ref
                                            .read(dbProvider)
                                            .updateNotificationStatus(
                                                notification.id, 'approved');
                                        await ref
                                            .read(dbProvider)
                                            .markNotificationAsRead(
                                                notification.id);

                                        final reply = AppNotification(
                                          id: const Uuid().v4(),
                                          type: 'edit_approved',
                                          title: 'Edit Request Approved',
                                          message:
                                              'Admin approved your request to edit guard details. Tap here to edit.',
                                          guardId: notification.guardId,
                                          supervisorId:
                                              notification.supervisorId,
                                          timestamp:
                                              DateTime.now().toIso8601String(),
                                        );
                                        await ref
                                            .read(dbProvider)
                                            .saveNotification(reply);
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isProcessing = false);
                                      }
                                    }
                                  },
                            child: const Text('Approve',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                      ],
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
