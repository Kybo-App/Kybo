import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/design_system.dart';
import '../widgets/diet_logo.dart';
import 'user_management_view.dart';
import 'config_view.dart';
import 'audit_log_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _userName = "Caricamento...";
  String _userRole = "Utente";
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
  }

  Future<void> _fetchCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _userName =
              "${data['first_name'] ?? 'Utente'} ${data['last_name'] ?? ''}"
                  .trim();
          _userRole = data['role'] ?? 'user';
          _isAdmin = _userRole == 'admin';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _onNavSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: const Text("Conferma Logout"),
        content: const Text("Sei sicuro di voler uscire?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annulla"),
          ),
          PillButton(
            label: "Esci",
            icon: Icons.logout,
            backgroundColor: KyboColors.error,
            textColor: Colors.white,
            height: 40,
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: KyboColors.background,
        body: Center(
          child: CircularProgressIndicator(color: KyboColors.primary),
        ),
      );
    }

    // Build navigation items based on role
    final List<_NavItem> navItems = [
      _NavItem(
        icon: Icons.people_alt_rounded,
        label: "Utenti",
        view: const UserManagementView(),
      ),
      if (_isAdmin)
        _NavItem(
          icon: Icons.settings_rounded,
          label: "Impostazioni",
          view: const ConfigView(),
        ),
      if (_isAdmin)
        _NavItem(
          icon: Icons.security_rounded,
          label: "Audit Log",
          view: const AuditLogView(),
        ),
    ];

    // Ensure selected index is valid
    if (_selectedIndex >= navItems.length) _selectedIndex = 0;

    return Scaffold(
      backgroundColor: KyboColors.background,
      body: Column(
        children: [
          // ═══════════════════════════════════════════════════════════════════
          // TOP BAR
          // ═══════════════════════════════════════════════════════════════════
          _buildTopBar(navItems),

          // ═══════════════════════════════════════════════════════════════════
          // CONTENT AREA
          // ═══════════════════════════════════════════════════════════════════
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: PillCard(
                padding: const EdgeInsets.all(24),
                child: navItems[_selectedIndex].view,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(List<_NavItem> navItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: KyboColors.surface,
        boxShadow: KyboColors.softShadow,
      ),
      child: Row(
        children: [
          // ─────────────────────────────────────────────────────────────────
          // LOGO
          // ─────────────────────────────────────────────────────────────────
          _buildLogo(),

          const SizedBox(width: 48),

          // ─────────────────────────────────────────────────────────────────
          // NAVIGATION PILLS
          // ─────────────────────────────────────────────────────────────────
          _buildNavigation(navItems),

          const Spacer(),

          // ─────────────────────────────────────────────────────────────────
          // USER SECTION
          // ─────────────────────────────────────────────────────────────────
          _buildUserSection(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: KyboColors.primary.withValues(alpha: 0.1),
            borderRadius: KyboBorderRadius.medium,
          ),
          child: const Center(
            child: DietLogo(size: 28, isDarkBackground: false),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Kybo",
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              "Admin Panel",
              style: TextStyle(
                color: KyboColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigation(List<_NavItem> navItems) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              right: index < navItems.length - 1 ? 8 : 0,
            ),
            child: PillNavItem(
              label: item.label,
              icon: item.icon,
              isSelected: _selectedIndex == index,
              onTap: () => _onNavSelected(index),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserSection() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dark Mode Toggle
        PillIconButton(
          icon: KyboColors.isDark
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          color: KyboColors.textSecondary,
          tooltip: KyboColors.isDark ? "Modalità Chiara" : "Modalità Scura",
          onPressed: () {
            KyboThemeProvider().toggleTheme();
            setState(() {}); // Rebuild UI
          },
        ),

        const SizedBox(width: 8),

        // User Info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: KyboColors.background,
            borderRadius: KyboBorderRadius.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isAdmin
                      ? KyboColors.roleAdmin
                      : KyboColors.roleNutritionist,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : "?",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Role
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _userName,
                    style: TextStyle(
                      color: KyboColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  PillBadge.role(_userRole),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Logout Button
        PillIconButton(
          icon: Icons.logout_rounded,
          color: KyboColors.error,
          tooltip: "Esci",
          onPressed: _logout,
        ),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget view;

  _NavItem({required this.icon, required this.label, required this.view});
}
