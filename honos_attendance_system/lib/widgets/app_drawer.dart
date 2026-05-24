import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../models/app_user.dart';

/// A navigation item descriptor for [AppDrawer].
class DrawerItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });
}

/// Shared premium drawer used by both Admin and Supervisor dashboards.
class AppDrawer extends StatelessWidget {
  final AppUser? user;
  final List<DrawerItem> items;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.user,
    required this.items,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.bgSurface,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          _DrawerHeader(user: user),

          // ── Nav items ─────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _DrawerNavItem(item: item, index: index);
              },
            ),
          ),

          // ── Logout button ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: Material(
              color: AppTheme.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onLogout,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: AppTheme.red, size: 22),
                      const SizedBox(width: 14),
                      Text(
                        'Sign Out',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ──────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  final AppUser? user;
  const _DrawerHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final isAdmin = user?.role == 'admin';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.darkHeaderGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.contain,
                ),
              ).animate().fadeIn(duration: 600.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 16),
              // Name
              Text(
                user?.name ?? 'User',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.1, end: 0),
              const SizedBox(height: 6),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? AppTheme.secondary.withValues(alpha: 0.20)
                      : AppTheme.primary.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isAdmin
                        ? AppTheme.secondary.withValues(alpha: 0.40)
                        : AppTheme.primary.withValues(alpha: 0.40),
                  ),
                ),
                child: Text(
                  isAdmin ? '⚙  ADMIN' : '🛡  SUPERVISOR',
                  style: GoogleFonts.inter(
                    color: isAdmin ? AppTheme.secondary : AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ).animate().fadeIn(delay: 250.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  final DrawerItem item;
  final int index;
  const _DrawerNavItem({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: item.isSelected
            ? AppTheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
            item.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: item.isSelected ? AppTheme.primary : AppTheme.txtSec,
                ),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: item.isSelected ? AppTheme.primary : AppTheme.txtSec,
                    fontWeight: item.isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (item.isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (100 + index * 60).ms)
        .slideX(begin: -0.15, end: 0, curve: Curves.easeOutCubic);
  }
}
