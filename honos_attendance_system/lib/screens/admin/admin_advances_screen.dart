import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app_theme.dart';
import '../../services/db_service.dart';
import '../../models/advance.dart';
import '../../models/guard.dart';
import '../../models/app_user.dart';
import '../../models/site.dart';

class AdminAdvancesScreen extends ConsumerStatefulWidget {
  const AdminAdvancesScreen({super.key});

  @override
  ConsumerState<AdminAdvancesScreen> createState() =>
      _AdminAdvancesScreenState();
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
    final sitesAsync = ref.watch(sitesStreamProvider);

    return Scaffold(
      backgroundColor: context.colors.bgBase,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAdvanceDialog(
            guardsAsync.value ?? [], 
            usersAsync.value ?? [],
            sitesAsync.value ?? []),
        icon: Icon(Icons.add, color: context.colors.bgBase),
        label: Text('Add Deduction/Advance',
            style: TextStyle(
                color: context.colors.bgBase,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        backgroundColor: context.colors.primary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 2.seconds, color: Colors.white24),
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
              title: const Text('Advances & Accommodations',
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
                          context.colors.primaryDark,
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
                      angle: -0.15,
                      child: Icon(Icons.account_balance_wallet_rounded,
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
          SliverToBoxAdapter(
            child: responsiveBody(Container(
              color: context.colors.bgBase,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                children: [
                  // Month Selector
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.colors.bgSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: context.colors.bord.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left_rounded,
                              color: context.colors.txtPrimary),
                          onPressed: () => setState(() => _selectedMonth =
                              DateTime(_selectedMonth.year,
                                  _selectedMonth.month - 1)),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: TextStyle(
                              color: context.colors.txtPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right_rounded,
                              color: context.colors.txtPrimary),
                          onPressed: () => setState(() => _selectedMonth =
                              DateTime(_selectedMonth.year,
                                  _selectedMonth.month + 1)),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),

                  const SizedBox(height: 20),

                  // Role Toggles
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colors.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: context.colors.bord.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        _buildTab('Guards', 'guard'),
                        _buildTab('Supervisors', 'supervisor'),
                        _buildTab('Executives', 'executive'),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),

                  const SizedBox(height: 20),

                  // Search Bar
                  TextField(
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                    style: TextStyle(color: context.colors.txtPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search $_selectedTab...',
                      hintStyle: TextStyle(color: context.colors.txtMuted),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: context.colors.primary),
                      filled: true,
                      fillColor: context.colors.bgSurface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                              color:
                                  context.colors.bord.withValues(alpha: 0.5))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                              color: context.colors.primary, width: 2)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: context.colors.txtMuted),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 16),
                ],
              ),
            )),
          ),
          advancesAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, st) => SliverFillRemaining(
                child: Center(
                    child: Text('Error: $e',
                        style: TextStyle(color: context.colors.red)))),
            data: (advances) {
              final monthAdvances = advances.where((a) {
                final d = DateTime.parse(a.date);
                return d.year == _selectedMonth.year &&
                    d.month == _selectedMonth.month;
              }).toList();

              if (_selectedTab == 'guard') {
                return guardsAsync.when(
                  loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, st) => SliverFillRemaining(
                      child: Center(
                          child: Text('Error loading guards',
                              style: TextStyle(color: context.colors.red)))),
                  data: (guards) => _buildUserList(
                    users: guards
                        .map((g) => _UserModel(g.id, g.name, 'Guard', g.salary))
                        .toList(),
                    advances: monthAdvances,
                    userType: 'guard',
                  ),
                );
              } else {
                return usersAsync.when(
                  loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, st) => SliverFillRemaining(
                      child: Center(
                          child: Text('Error loading $_selectedTab',
                              style: TextStyle(color: context.colors.red)))),
                  data: (users) {
                    final staff =
                        users.where((u) => u.role == _selectedTab).toList();
                    return _buildUserList(
                      users: staff
                          .map((s) => _UserModel(
                              s.id,
                              s.name,
                              _selectedTab == 'executive'
                                  ? 'Executive'
                                  : 'Supervisor',
                              s.salary))
                          .toList(),
                      advances: monthAdvances,
                      userType: _selectedTab,
                    );
                  },
                );
              }
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }

  Widget _buildTab(String title, String tabValue) {
    final isSelected = _selectedTab == tabValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tabValue),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? context.colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: context.colors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : context.colors.txtSec,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList({
    required List<_UserModel> users,
    required List<Advance> advances,
    required String userType,
  }) {
    final filteredUsers = users
        .where((u) => u.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (filteredUsers.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                      size: 80,
                      color: context.colors.txtMuted.withValues(alpha: 0.3))
                  .animate()
                  .scale(
                      delay: 200.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutBack),
              const SizedBox(height: 20),
              Text('No $userType found',
                  style: TextStyle(
                      color: context.colors.txtSec,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return ResponsiveSliverPadding(
      extraPadding: const EdgeInsets.symmetric(vertical: 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final u = filteredUsers[index];
            final userAdvances = advances
                .where((a) => a.userId == u.id && a.userType == userType)
                .toList();
            final totalAdvance =
                userAdvances.fold<double>(0, (sum, a) => sum + a.amount);
            final netPay = u.salary - totalAdvance;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.colors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: context.colors.bord.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: const Border(),
                title: Text(u.name,
                    style: TextStyle(
                        color: context.colors.txtPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: -0.3)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Net Pay: INR ${netPay.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: context.colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: totalAdvance > 0
                        ? context.colors.red.withValues(alpha: 0.1)
                        : context.colors.bgBase,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Ded: ${totalAdvance.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: totalAdvance > 0
                              ? context.colors.red
                              : context.colors.txtMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                iconColor: context.colors.primary,
                collapsedIconColor: context.colors.txtMuted,
                children: [
                  Container(
                    color: context.colors.bgBase.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet_rounded,
                                    size: 16, color: context.colors.txtMuted),
                                const SizedBox(width: 8),
                                Text('Fixed Monthly Salary:',
                                    style: TextStyle(
                                        color: context.colors.txtSec,
                                        fontSize: 13)),
                              ],
                            ),
                            Text('INR ${u.salary.toStringAsFixed(0)}',
                                style: TextStyle(
                                    color: context.colors.txtPrimary,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text('Deductions & Advances',
                            style: TextStyle(
                                color: context.colors.txtPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 12),
                        if (userAdvances.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: context.colors.bgSurface,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('No deductions taken this month.',
                                style: TextStyle(
                                    color: context.colors.txtMuted,
                                    fontStyle: FontStyle.italic)),
                          )
                        else
                          ...userAdvances.map((a) {
                                String typeLabel = 'Advance';
                                Color typeColor = context.colors.primary;
                                if (a.type == 'uniform') { typeLabel = 'Uniform'; typeColor = Colors.orange; }
                                else if (a.type == 'mess') { typeLabel = 'Mess/Canteen'; typeColor = Colors.teal; }
                                else if (a.type == 'other') { typeLabel = a.otherExpenseName.isNotEmpty ? a.otherExpenseName : 'Other'; typeColor = Colors.purple; }

                                return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.colors.bgSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: context.colors.bord
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                  DateFormat('dd MMM yyyy').format(
                                                      DateTime.parse(a.date)),
                                                  style: TextStyle(
                                                      color:
                                                          context.colors.txtPrimary,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600)),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: typeColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                                                ),
                                                child: Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          if (a.reason.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(a.reason,
                                                style: TextStyle(
                                                    color:
                                                        context.colors.txtSec,
                                                    fontSize: 12)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text('INR ${a.amount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            color: context.colors.red,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            }),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (40 * index).ms).slideY(
                begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
          },
          childCount: filteredUsers.length,
        ),
      ),
    );
  }

  void _showAddAdvanceDialog(List<Guard> guards, List<AppUser> allStaff, List<Site> sites) {
    String selectedType = _selectedTab;
    String? selectedUserId;
    String? selectedSiteId;
    String deductionType = 'advance'; // 'advance', 'uniform', 'mess', 'other'
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final otherNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: StatefulBuilder(
          builder: (ctx, setSt) {
            List<DropdownMenuItem<String>> items = [];
            if (selectedType == 'guard') {
              List<Guard> filteredGuards = [];
              if (selectedSiteId != null) {
                filteredGuards = guards.where((g) => g.siteId == selectedSiteId).toList();
              }

              items = filteredGuards
                  .map((g) => DropdownMenuItem(
                      value: g.id,
                      child: Text('${g.name} ${g.empId.isNotEmpty ? "(ID: ${g.empId})" : ""}'.trim(),
                          style: TextStyle(
                              color: context.colors.txtPrimary, fontSize: 14))))
                  .toList();
            } else {
              items = allStaff
                  .where((s) => s.role == selectedType)
                  .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name} ${s.empId.isNotEmpty ? "(ID: ${s.empId})" : ""}'.trim(),
                          style: TextStyle(
                              color: context.colors.txtPrimary, fontSize: 14))))
                  .toList();
            }

            if (selectedUserId != null &&
                !items.any((i) => i.value == selectedUserId)) {
              selectedUserId = null;
            }

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.bgSurface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Deduction/Advance',
                        style: TextStyle(
                            color: context.colors.txtPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 24),
                    
                    Text('Employee Type', style: TextStyle(color: context.colors.txtSec, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.bgBase,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRoleSelector('Guard', 'guard', selectedType, (val) => setSt(() {
                              selectedType = val;
                              selectedSiteId = null;
                              selectedUserId = null;
                            })),
                          ),
                          Expanded(
                            child: _buildRoleSelector('Sup.', 'supervisor', selectedType, (val) => setSt(() {
                              selectedType = val;
                              selectedSiteId = null;
                              selectedUserId = null;
                            })),
                          ),
                          Expanded(
                            child: _buildRoleSelector('Exec.', 'executive', selectedType, (val) => setSt(() {
                              selectedType = val;
                              selectedSiteId = null;
                              selectedUserId = null;
                            })),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (selectedType == 'guard') ...[
                      _buildDropdown(
                        value: selectedSiteId,
                        hint: 'Select Site',
                        items: sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: (val) => setSt(() {
                          selectedSiteId = val;
                          selectedUserId = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildDropdown(
                      value: selectedUserId,
                      hint: selectedType == 'guard' && selectedSiteId == null ? 'Please select a site first' : 'Select Employee',
                      items: items,
                      onChanged: (val) => setSt(() => selectedUserId = val),
                    ),
                    const SizedBox(height: 20),

                    Text('Deduction Category', style: TextStyle(color: context.colors.txtSec, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: deductionType,
                      hint: 'Select Category',
                      items: const [
                        DropdownMenuItem(value: 'advance', child: Text('Advance')),
                        DropdownMenuItem(value: 'uniform', child: Text('Uniform Fee')),
                        DropdownMenuItem(value: 'mess', child: Text('Mess/Canteen Fee')),
                        DropdownMenuItem(value: 'other', child: Text('Other Expense')),
                      ],
                      onChanged: (val) => setSt(() => deductionType = val!),
                    ),
                    const SizedBox(height: 16),

                    if (deductionType == 'other') ...[
                      _buildTextField(otherNameCtrl, 'Expense Name (e.g., Penalty)'),
                      const SizedBox(height: 16),
                    ],

                    _buildTextField(amountCtrl, 'Amount (INR)', isNumber: true),
                    const SizedBox(height: 16),
                    _buildTextField(reasonCtrl, 'Reason / Notes (Optional)'),
                    
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text('Cancel', style: TextStyle(color: context.colors.txtSec, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (selectedUserId == null || amountCtrl.text.isEmpty || (deductionType == 'other' && otherNameCtrl.text.trim().isEmpty)) {
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
                                date: DateTime(_selectedMonth.year, _selectedMonth.month, DateTime.now().day.clamp(1, 28), DateTime.now().hour, DateTime.now().minute).toIso8601String(),
                                reason: reasonCtrl.text.trim(),
                                type: deductionType,
                                otherExpenseName: deductionType == 'other' ? otherNameCtrl.text.trim() : '',
                              );

                              await ref.read(dbProvider).saveAdvance(advance);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.colors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Save Deduction', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleSelector(String label, String value, String selectedValue, Function(String) onTap) {
    final isSelected = value == selectedValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          color: isSelected ? Colors.white : context.colors.txtSec,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 12
        )),
      ),
    );
  }

  Widget _buildDropdown({required String? value, required String hint, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.bgBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.bord.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: context.colors.txtSec, fontSize: 14)),
          isExpanded: true,
          dropdownColor: context.colors.bgSurface,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.txtMuted),
          items: items,
          onChanged: onChanged,
          style: TextStyle(color: context.colors.txtPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: context.colors.txtPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colors.txtSec, fontSize: 14),
        filled: true,
        fillColor: context.colors.bgBase,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.colors.bord.withValues(alpha: 0.5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.colors.primary, width: 1.5)),
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
