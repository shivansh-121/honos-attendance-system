import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app_theme.dart';
import '../../services/db_service.dart';
import '../../services/excel_service.dart';
import '../../models/advance.dart';
import '../../models/guard.dart';
import '../../models/app_user.dart';

class AdminAdvancesScreen extends ConsumerStatefulWidget {
  const AdminAdvancesScreen({super.key});

  @override
  ConsumerState<AdminAdvancesScreen> createState() => _AdminAdvancesScreenState();
}

class _AdminAdvancesScreenState extends ConsumerState<AdminAdvancesScreen> {
  bool _showGuards = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final advancesAsync = ref.watch(advancesStreamProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('Manage Advances & Salary', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: AppTheme.green),
            tooltip: 'Export Payroll Excel',
            onPressed: () async {
              if (guardsAsync.value == null || usersAsync.value == null || advancesAsync.value == null) return;
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generating Payroll Excel...')),
              );
              try {
                await ExcelService.exportMonthlyPayroll(
                  _selectedMonth,
                  guardsAsync.value!,
                  usersAsync.value!,
                  advancesAsync.value!,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
                  );
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Give Advance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddAdvanceDialog(guardsAsync.value ?? [], usersAsync.value ?? []),
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.bgSurface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
                ),
              ],
            ),
          ),
          
          // Toggle Guards/Supervisors
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showGuards ? AppTheme.primary : AppTheme.bgSurface,
                      foregroundColor: _showGuards ? Colors.white : AppTheme.txtSec,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _showGuards = true),
                    child: const Text('Guards'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showGuards ? AppTheme.primary : AppTheme.bgSurface,
                      foregroundColor: !_showGuards ? Colors.white : AppTheme.txtSec,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _showGuards = false),
                    child: const Text('Supervisors'),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: advancesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.red))),
              data: (advances) {
                final monthAdvances = advances.where((a) {
                  final d = DateTime.parse(a.date);
                  return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
                }).toList();

                if (_showGuards) {
                  return guardsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => const Center(child: Text('Error loading guards')),
                    data: (guards) => _buildUserList(
                      users: guards.map((g) => _UserModel(g.id, g.name, 'Guard', g.salary)).toList(),
                      advances: monthAdvances,
                      userType: 'guard',
                    ),
                  );
                } else {
                  return usersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => const Center(child: Text('Error loading supervisors')),
                    data: (users) {
                      final sups = users.where((u) => u.role == 'supervisor').toList();
                      return _buildUserList(
                        users: sups.map((s) => _UserModel(s.id, s.name, 'Supervisor', s.salary)).toList(),
                        advances: monthAdvances,
                        userType: 'supervisor',
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList({
    required List<_UserModel> users,
    required List<Advance> advances,
    required String userType,
  }) {
    if (users.isEmpty) {
      return Center(child: Text('No $userType found.', style: const TextStyle(color: AppTheme.txtSec)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final userAdvances = advances.where((a) => a.userId == u.id && a.userType == userType).toList();
        final totalAdvance = userAdvances.fold<double>(0, (sum, a) => sum + a.amount);
        final netPay = u.salary - totalAdvance;

        return Card(
          color: AppTheme.bgSurface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(u.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Net Pay: INR ${netPay.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.green)),
            trailing: Text('Adv: ${totalAdvance.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            children: [
              Container(
                color: Colors.black12,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fixed Monthly Salary:', style: TextStyle(color: AppTheme.txtSec)),
                        Text('INR ${u.salary.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Advances Taken:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (userAdvances.isEmpty)
                      const Text('No advances taken this month.', style: TextStyle(color: AppTheme.txtSec))
                    else
                      ...userAdvances.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('dd MMM yyyy').format(DateTime.parse(a.date)), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                if (a.reason.isNotEmpty)
                                  Text(a.reason, style: const TextStyle(color: AppTheme.txtSec, fontSize: 12)),
                              ],
                            ),
                            Text('INR ${a.amount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddAdvanceDialog(List<Guard> guards, List<AppUser> supervisors) {
    String selectedType = _showGuards ? 'guard' : 'supervisor';
    String? selectedUserId;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('Give Advance', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setSt) {
            List<DropdownMenuItem<String>> items = [];
            if (selectedType == 'guard') {
              items = guards.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList();
            } else {
              items = supervisors.where((s) => s.role == 'supervisor').map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList();
            }

            // Ensure selectedUserId is valid or null
            if (selectedUserId != null && !items.any((i) => i.value == selectedUserId)) {
              selectedUserId = null;
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Radio<String>(
                        value: 'guard',
                        groupValue: selectedType,
                        activeColor: AppTheme.primary,
                        onChanged: (val) => setSt(() => selectedType = val!),
                      ),
                      const Text('Guard', style: TextStyle(color: Colors.white)),
                      Radio<String>(
                        value: 'supervisor',
                        groupValue: selectedType,
                        activeColor: AppTheme.primary,
                        onChanged: (val) => setSt(() => selectedType = val!),
                      ),
                      const Text('Supervisor', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedUserId,
                    hint: const Text('Select Employee', style: TextStyle(color: AppTheme.txtSec)),
                    dropdownColor: AppTheme.bgBase,
                    items: items,
                    onChanged: (val) => setSt(() => selectedUserId = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Amount (INR)'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Reason (Optional)'),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (selectedUserId == null || amountCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
                return;
              }
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount.')));
                return;
              }

              final advance = Advance(
                id: const Uuid().v4(),
                userId: selectedUserId!,
                userType: selectedType,
                amount: amount,
                date: DateTime.now().toIso8601String(),
                reason: reasonCtrl.text.trim(),
              );

              await ref.read(dbProvider).saveAdvance(advance);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _UserModel {
  final String id;
  final String name;
  final String role;
  final double salary;
  _UserModel(this.id, this.name, this.role, this.salary);
}
