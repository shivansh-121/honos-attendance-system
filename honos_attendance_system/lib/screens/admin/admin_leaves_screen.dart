import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app_theme.dart';
import '../../models/app_notification.dart';
import '../../services/db_service.dart';
import 'package:uuid/uuid.dart';

class AdminLeavesScreen extends ConsumerWidget {
  const AdminLeavesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(leavesStreamProvider);

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor: context.colors.bgBase,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground
              ],
              titlePadding:
                  const EdgeInsets.only(left: 24, bottom: 20, right: 24),
              title: const Text('Leave Requests',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.5)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1B3B60),
                          context.colors.primary
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -60,
                    right: -40,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1)),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.15, 1.15),
                        duration: 4.seconds,
                        curve: Curves.easeInOut),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08)),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                        begin: const Offset(1.15, 1.15),
                        end: const Offset(1, 1),
                        duration: 3.seconds,
                        curve: Curves.easeInOut),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 40,
                    child: Transform.rotate(
                      angle: 0.2,
                      child: Icon(Icons.event_note,
                          size: 140,
                          color: Colors.white.withValues(alpha: 0.15)),
                    ).animate().fadeIn(duration: 800.ms).slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 800.ms,
                        curve: Curves.easeOutBack),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          leavesAsync.when(
            data: (leaves) {
              if (leaves.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded,
                                size: 80,
                                color: context.colors.txtMuted
                                    .withValues(alpha: 0.3))
                            .animate()
                            .scale(
                                delay: 200.ms,
                                duration: 400.ms,
                                curve: Curves.easeOutBack),
                        const SizedBox(height: 20),
                        Text('No leave requests.',
                            style: TextStyle(
                                color: context.colors.txtSec,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }

              // Show pending first, then approved/declined
              leaves.sort((a, b) {
                if (a.status == 'pending' && b.status != 'pending') return -1;
                if (a.status != 'pending' && b.status == 'pending') return 1;
                return b.createdAt.compareTo(a.createdAt);
              });

              return ResponsiveSliverPadding(
                extraPadding: const EdgeInsets.fromLTRB(0, 24, 0, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final leave = leaves[index];
                      final isPending = leave.status == 'pending';

                      Color statusColor = context.colors.yellow;
                      if (leave.status == 'approved') {
                        statusColor = context.colors.green;
                      }
                      if (leave.status == 'declined') {
                        statusColor = context.colors.red;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.colors.bgSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color:
                                  context.colors.bord.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                                color: statusColor.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                            color: context.colors.primary
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle),
                                        child: Icon(Icons.person,
                                            color: context.colors.primary,
                                            size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Text(leave.employeeName,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color:
                                                      context.colors.txtPrimary,
                                                  fontSize: 18,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: statusColor.withValues(
                                                alpha: 0.3)),
                                      ),
                                      child: Text(leave.status.toUpperCase(),
                                          style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5)),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.delete,
                                          color: context.colors.red
                                              .withValues(alpha: 0.7),
                                          size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor:
                                                context.colors.bgSurface,
                                            title: Text('Delete Leave',
                                                style: TextStyle(
                                                    color: context
                                                        .colors.txtPrimary)),
                                            content: Text(
                                                'Are you sure you want to delete this leave request?',
                                                style: TextStyle(
                                                    color:
                                                        context.colors.txtSec)),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text('Cancel')),
                                              TextButton(
                                                onPressed: () {
                                                  ref
                                                      .read(dbProvider)
                                                      .deleteLeave(leave.id);
                                                  Navigator.pop(ctx);
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: const Text(
                                                              'Leave deleted'),
                                                          backgroundColor:
                                                              context.colors
                                                                  .green));
                                                },
                                                child: Text('Delete',
                                                    style: TextStyle(
                                                        color: context
                                                            .colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.colors.bgBase,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: context.colors.bord
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.date_range,
                                      color: context.colors.primary, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Leave Duration',
                                            style: TextStyle(
                                                color: context.colors.txtMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '${leave.fromDate} to ${leave.toDate}',
                                            style: TextStyle(
                                                color: context.colors.primary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Reason:',
                                style: TextStyle(
                                    color: context.colors.txtMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(leave.reason,
                                style: TextStyle(
                                    color: context.colors.txtSec,
                                    fontSize: 14)),
                            if (isPending) ...[
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        foregroundColor: context.colors.red,
                                        side: BorderSide(
                                            color: context.colors.red
                                                .withValues(alpha: 0.5)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () async {
                                        await ref
                                            .read(dbProvider)
                                            .updateLeaveStatus(
                                                leave.id, 'declined');

                                        // Send notification to employee
                                        final notif = AppNotification(
                                          id: const Uuid().v4(),
                                          type: 'leave_declined',
                                          title: 'Leave Request Declined',
                                          message:
                                              'Your leave request for ${leave.fromDate} to ${leave.toDate} was declined.',
                                          guardId: '',
                                          supervisorId: leave.employeeId,
                                          timestamp:
                                              DateTime.now().toIso8601String(),
                                        );
                                        ref
                                            .read(dbProvider)
                                            .saveNotification(notif)
                                            .catchError((e) =>
                                                debugPrint(e.toString()));

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: const Text(
                                                      'Leave Declined'),
                                                  backgroundColor:
                                                      context.colors.red));
                                        }
                                      },
                                      label: const Text('Decline',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        backgroundColor: context.colors.green,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.check, size: 18),
                                      onPressed: () async {
                                        await ref
                                            .read(dbProvider)
                                            .updateLeaveStatus(
                                                leave.id, 'approved');

                                        // Send notification to employee
                                        final notif = AppNotification(
                                          id: const Uuid().v4(),
                                          type: 'leave_approved',
                                          title: 'Leave Request Approved',
                                          message:
                                              'Your leave request for ${leave.fromDate} to ${leave.toDate} was approved.',
                                          guardId: '',
                                          supervisorId: leave.employeeId,
                                          timestamp:
                                              DateTime.now().toIso8601String(),
                                        );
                                        ref
                                            .read(dbProvider)
                                            .saveNotification(notif)
                                            .catchError((e) =>
                                                debugPrint(e.toString()));

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: const Text(
                                                      'Leave Approved'),
                                                  backgroundColor:
                                                      context.colors.green));
                                        }
                                      },
                                      label: const Text('Approve',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: (50 * index).ms).slideX(
                          begin: 0.1,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOut);
                    },
                    childCount: leaves.length,
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
        ],
      ),
    );
  }
}
