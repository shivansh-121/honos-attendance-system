import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app_theme.dart';
import '../../models/leave.dart';
import '../../models/app_notification.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.colors.primary,
              onPrimary: Colors.white,
              surface: context.colors.bgSurface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(picked)) {
            _toDate = picked;
          }
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_fromDate == null || _toDate == null || _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Please fill all fields'), backgroundColor: context.colors.red));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authProvider)!;
      final db = ref.read(dbProvider);

      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate!);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate!);

      final leave = Leave(
        id: const Uuid().v4(),
        employeeId: user.id,
        employeeName: user.name,
        fromDate: fromStr,
        toDate: toStr,
        reason: _reasonController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
      );

      // Run DB operations in background without blocking UI
      db.saveLeave(leave).catchError((e) => debugPrint('Leave error: $e'));

      // Notify Admin (supervisors get this by not matching any specific guard/supervisor ID filter)
      final notification = AppNotification(
        id: const Uuid().v4(),
        type: 'leave_request',
        title: 'New Leave Request',
        message: '${user.name} applied for leave from $fromStr to $toStr.',
        timestamp: DateTime.now().toIso8601String(),
        isRead: false,
        supervisorId: user.id,
        guardId: '',
      );
      db.saveNotification(notification).catchError((e) => debugPrint('Notif error: $e'));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Leave Request Submitted!'), backgroundColor: context.colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.red));
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final leavesAsync = ref.watch(leavesStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave Duration', style: TextStyle(color: context.colors.txtSec, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('From', style: TextStyle(color: context.colors.txtMuted, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text(_fromDate == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_fromDate!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(false),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('To', style: TextStyle(color: context.colors.txtMuted, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text(_toDate == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_toDate!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Reason for Leave', style: TextStyle(color: context.colors.txtSec, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your reason here...',
                hintStyle: TextStyle(color: context.colors.txtMuted),
                filled: true,
                fillColor: context.colors.bgSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            Text('My Leave History', style: TextStyle(color: context.colors.txtSec, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            leavesAsync.when(
              data: (leaves) {
                final myLeaves = leaves.where((l) => l.employeeId == user?.id).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (myLeaves.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('No leaves applied yet.', style: TextStyle(color: context.colors.txtMuted)),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: myLeaves.length,
                  itemBuilder: (ctx, i) {
                    final l = myLeaves[i];
                    Color statusColor = context.colors.yellow;
                    IconData statusIcon = Icons.hourglass_empty;
                    if (l.status == 'approved') {
                      statusColor = context.colors.green;
                      statusIcon = Icons.check_circle;
                    } else if (l.status == 'rejected') {
                      statusColor = context.colors.red;
                      statusIcon = Icons.cancel;
                    }

                    return Card(
                      color: context.colors.bgElevated,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Icon(statusIcon, color: statusColor),
                        title: Text('${l.fromDate} to ${l.toDate}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(l.reason, style: TextStyle(color: context.colors.txtSec), maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Text(l.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
