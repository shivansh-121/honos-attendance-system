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
  DateTime _selectedMonth = DateTime.now();
  String _selectedTab = 'guard'; // 'guard', 'supervisor', 'executive'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final advancesAsync = ref.watch(advancesStreamProvider);
    final guardsAsync = ref.watch(guardsStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      appBar: AppBar(
        backgroundColor: context.colors.bgSurface,
        title: const Text('Manage Advances & Salary', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.file_download, color: context.colors.green),
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
                    SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.colors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Give Advance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddAdvanceDialog(guardsAsync.value ?? [], usersAsync.value ?? []),
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: context.colors.bgSurface,
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
          
          // Toggle Guards/Supervisors/Executives
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTab == 'guard' ? context.colors.primary : context.colors.bgSurface,
                      foregroundColor: _selectedTab == 'guard' ? Colors.white : context.colors.txtSec,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => setState(() => _selectedTab = 'guard'),
                    child: const Text('Guards', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTab == 'supervisor' ? context.colors.primary : context.colors.bgSurface,
                      foregroundColor: _selectedTab == 'supervisor' ? Colors.white : context.colors.txtSec,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => setState(() => _selectedTab = 'supervisor'),
                    child: const Text('Supervisors', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTab == 'executive' ? context.colors.primary : context.colors.bgSurface,
                      foregroundColor: _selectedTab == 'executive' ? Colors.white : context.colors.txtSec,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => setState(() => _selectedTab = 'executive'),
                    child: const Text('Executives', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search $_selectedTab...',
                hintStyle: TextStyle(color: context.colors.txtMuted),
                prefixIcon: Icon(Icons.search, color: context.colors.txtMuted),
                filled: true,
                fillColor: context.colors.bgElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: advancesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e', style: TextStyle(color: context.colors.red))),
              data: (advances) {
                final monthAdvances = advances.where((a) {
                  final d = DateTime.parse(a.date);
                  return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
                }).toList();

                if (_selectedTab == 'guard') {
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
                    error: (e, st) => Center(child: Text('Error loading $_selectedTab')),
                    data: (users) {
                      final staff = users.where((u) => u.role == _selectedTab).toList();
                      return _buildUserList(
                        users: staff.map((s) => _UserModel(s.id, s.name, _selectedTab == 'executive' ? 'Executive' : 'Supervisor', s.salary)).toList(),
                        advances: monthAdvances,
                        userType: _selectedTab,
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
    final filteredUsers = users.where((u) => u.name.toLowerCase().contains(_searchQuery)).toList();

    if (filteredUsers.isEmpty) {
      return Center(child: Text('No $userType found.', style: TextStyle(color: context.colors.txtSec)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final u = filteredUsers[index];
        final userAdvances = advances.where((a) => a.userId == u.id && a.userType == userType).toList();
        final totalAdvance = userAdvances.fold<double>(0, (sum, a) => sum + a.amount);
        final netPay = u.salary - totalAdvance;

        return Card(
          color: context.colors.bgSurface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(u.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Net Pay: INR ${netPay.toStringAsFixed(0)}', style: TextStyle(color: context.colors.green)),
            trailing: Text('Adv: ${totalAdvance.toStringAsFixed(0)}', style: TextStyle(color: context.colors.red, fontWeight: FontWeight.bold)),
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
                        Text('Fixed Monthly Salary:', style: TextStyle(color: context.colors.txtSec)),
                        Text('INR ${u.salary.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Advances Taken:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (userAdvances.isEmpty)
                      Text('No advances taken this month.', style: TextStyle(color: context.colors.txtSec))
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
                                  Text(a.reason, style: TextStyle(color: context.colors.txtSec, fontSize: 12)),
                              ],
                            ),
                            Text('INR ${a.amount.toStringAsFixed(0)}', style: TextStyle(color: context.colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddAdvanceDialog(List<Guard> guards, List<AppUser> allStaff) {
    String selectedType = _selectedTab;
    String? selectedUserId;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgSurface,
        title: const Text('Give Advance', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setSt) {
            List<DropdownMenuItem<String>> items = [];
            if (selectedType == 'guard') {
              items = guards.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList();
            } else {
              items = allStaff.where((s) => s.role == selectedType).map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList();
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
                        activeColor: context.colors.primary,
                        onChanged: (val) => setSt(() => selectedType = val!),
                      ),
                      const Text('Guard', style: TextStyle(color: Colors.white)),
                      Radio<String>(
                        value: 'supervisor',
                        groupValue: selectedType,
                        activeColor: context.colors.primary,
                        onChanged: (val) => setSt(() => selectedType = val!),
                      ),
                      const Text('Supervisor', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'executive',
                        groupValue: selectedType,
                        activeColor: context.colors.primary,
                        onChanged: (val) => setSt(() => selectedType = val!),
                      ),
                      const Text('Executive', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUserId,
                    hint: Text('Select Employee', style: TextStyle(color: context.colors.txtSec)),
                    dropdownColor: context.colors.bgBase,
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
