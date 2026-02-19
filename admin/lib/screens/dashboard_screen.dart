import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/admin_notification_provider.dart';
import '../providers/language_provider.dart';
import '../core/app_localizations.dart';
import '../widgets/design_system.dart';
import '../widgets/diet_logo.dart';
import 'user_management_view.dart';
import 'config_view.dart';
import 'audit_log_view.dart';
import 'chat_management_view.dart';
import 'nutritional_calculator_view.dart';
import 'analytics_view.dart';
import 'gdpr_privacy_view.dart';
import 'reports_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminNotificationProvider(),
      child: const _DashboardContent(),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent();

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  int _selectedIndex = 0;
  String _userName = "";
  String _userRole = "Utente";
  bool _isAdmin = false;
  bool _isLoading = true;

  // Focus node per catturare le scorciatoie da tastiera
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(l10n.logoutTitle),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          PillButton(
            label: l10n.logout,
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

  // ─────────────────────────────────────────────────────────────────────────
  // RICERCA GLOBALE
  // ─────────────────────────────────────────────────────────────────────────

  void _openGlobalSearch(List<_NavItem> navItems) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _GlobalSearchDialog(
        navItems: navItems,
        onNavigate: (index) {
          Navigator.pop(ctx);
          _onNavSelected(index);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCORCIATOIE DA TASTIERA
  // ─────────────────────────────────────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, List<_NavItem> navItems) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrl) {
      // Ctrl+K → Ricerca globale
      if (event.logicalKey == LogicalKeyboardKey.keyK) {
        _openGlobalSearch(navItems);
        return KeyEventResult.handled;
      }

      // Ctrl+N → Nuovo utente (naviga alla tab Utenti)
      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        _onNavSelected(0);
        return KeyEventResult.handled;
      }

      // Ctrl+1..8 → Navigazione tab
      final digitMap = {
        LogicalKeyboardKey.digit1: 0,
        LogicalKeyboardKey.digit2: 1,
        LogicalKeyboardKey.digit3: 2,
        LogicalKeyboardKey.digit4: 3,
        LogicalKeyboardKey.digit5: 4,
        LogicalKeyboardKey.digit6: 5,
        LogicalKeyboardKey.digit7: 6,
        LogicalKeyboardKey.digit8: 7,
      };
      if (digitMap.containsKey(event.logicalKey)) {
        final idx = digitMap[event.logicalKey]!;
        if (idx < navItems.length) {
          _onNavSelected(idx);
          return KeyEventResult.handled;
        }
      }
    }

    // Shift+7 → mostra dialog scorciatoie
    // Intercetta sia slash+shift (layout US) che digit7+shift (layout IT)
    // e consuma l'evento per evitare che il carattere '?' venga scritto
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    if (isShift &&
        (event.logicalKey == LogicalKeyboardKey.slash ||
         event.logicalKey == LogicalKeyboardKey.question ||
         event.logicalKey == LogicalKeyboardKey.digit7)) {
      _showShortcutsDialog();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _showShortcutsDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        backgroundColor: KyboColors.surface,
        title: Row(
          children: [
            Icon(Icons.keyboard_rounded, color: KyboColors.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              l10n.keyboardShortcuts,
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShortcutRow(keys: 'Ctrl + K', description: l10n.shortcutSearch),
              _ShortcutRow(keys: 'Ctrl + N', description: l10n.shortcutNewUser),
              _ShortcutRow(keys: 'Ctrl + 1–8', description: l10n.shortcutNavigation),
              _ShortcutRow(keys: 'Shift + 7', description: l10n.keyboardShortcuts),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: KyboColors.background,
        body: Center(
          child: CircularProgressIndicator(color: KyboColors.primary),
        ),
      );
    }

    final themeKey = KyboColors.isDark ? 'dark' : 'light';
    final notifProvider = context.watch<AdminNotificationProvider>();

    final List<_NavItem> navItems = [
      _NavItem(
        icon: Icons.people_alt_rounded,
        label: l10n.navUsers,
        view: UserManagementView(key: ValueKey('users_$themeKey')),
        badgeCount: notifProvider.expiringDiets,
      ),
      _NavItem(
        icon: Icons.chat_bubble_rounded,
        label: l10n.navChat,
        view: ChatManagementView(key: ValueKey('chat_$themeKey')),
        badgeCount: notifProvider.unreadChats,
      ),
      _NavItem(
        icon: Icons.calculate_rounded,
        label: l10n.navCalculator,
        view: NutritionalCalculatorView(key: ValueKey('calc_$themeKey')),
      ),
      _NavItem(
        icon: Icons.analytics_rounded,
        label: l10n.navAnalytics,
        view: AnalyticsView(key: ValueKey('analytics_$themeKey')),
      ),
      _NavItem(
        icon: Icons.assessment_rounded,
        label: l10n.navReports,
        view: ReportsView(key: ValueKey('reports_$themeKey')),
      ),
      if (_isAdmin)
        _NavItem(
          icon: Icons.settings_rounded,
          label: l10n.navSettings,
          view: ConfigView(key: ValueKey('config_$themeKey')),
        ),
      if (_isAdmin)
        _NavItem(
          icon: Icons.privacy_tip_rounded,
          label: l10n.navGdpr,
          view: GDPRPrivacyView(key: ValueKey('gdpr_$themeKey')),
        ),
      if (_isAdmin)
        _NavItem(
          icon: Icons.security_rounded,
          label: l10n.navAuditLog,
          view: AuditLogView(key: ValueKey('audit_$themeKey')),
        ),
    ];

    if (_selectedIndex >= navItems.length) _selectedIndex = 0;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(node, event, navItems),
      child: Scaffold(
        backgroundColor: KyboColors.background,
        body: Column(
          children: [
            // ═══════════════════════════════════════════════════════════════
            // TOP BAR
            // ═══════════════════════════════════════════════════════════════
            _buildTopBar(navItems, l10n),

            // ═══════════════════════════════════════════════════════════════
            // CONTENT AREA
            // ═══════════════════════════════════════════════════════════════
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PillCard(
                  key: ValueKey('content_card_$themeKey'),
                  padding: const EdgeInsets.all(24),
                  child: navItems[_selectedIndex].view,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(List<_NavItem> navItems, AppLocalizations l10n) {
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
          _buildLogo(l10n),

          const SizedBox(width: 48),

          // ─────────────────────────────────────────────────────────────────
          // NAVIGATION PILLS
          // ─────────────────────────────────────────────────────────────────
          _buildNavigation(navItems),

          const Spacer(),

          // ─────────────────────────────────────────────────────────────────
          // USER SECTION
          // ─────────────────────────────────────────────────────────────────
          _buildUserSection(navItems, l10n),
        ],
      ),
    );
  }

  Widget _buildLogo(AppLocalizations l10n) {
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
              l10n.adminPanel,
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
              badgeCount: item.badgeCount,
              onTap: () => _onNavSelected(index),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserSection(List<_NavItem> navItems, AppLocalizations l10n) {
    final langProvider = LanguageProvider();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ricerca Globale (Ctrl+K)
        PillIconButton(
          icon: Icons.search_rounded,
          color: KyboColors.textSecondary,
          tooltip: '${l10n.globalSearch} (Ctrl+K)',
          onPressed: () => _openGlobalSearch(navItems),
        ),

        const SizedBox(width: 4),

        // Toggle Lingua
        _LanguageToggle(provider: langProvider, l10n: l10n),

        const SizedBox(width: 4),

        // Dark Mode Toggle
        PillIconButton(
          icon: KyboColors.isDark
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          color: KyboColors.textSecondary,
          tooltip: KyboColors.isDark ? l10n.lightMode : l10n.darkMode,
          onPressed: () {
            KyboThemeProvider().toggleTheme();
            setState(() {});
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

        // Scorciatoie (?)
        PillIconButton(
          icon: Icons.keyboard_rounded,
          color: KyboColors.textSecondary,
          tooltip: l10n.keyboardShortcuts,
          onPressed: _showShortcutsDialog,
        ),

        const SizedBox(width: 4),

        // Logout Button
        PillIconButton(
          icon: Icons.logout_rounded,
          color: KyboColors.error,
          tooltip: l10n.logout,
          onPressed: _logout,
        ),
      ],
    );
  }
}

// =============================================================================
// LANGUAGE TOGGLE WIDGET
// =============================================================================

class _LanguageToggle extends StatelessWidget {
  final LanguageProvider provider;
  final AppLocalizations l10n;

  const _LanguageToggle({required this.provider, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: Consumer<LanguageProvider>(
        builder: (context, lang, _) => Tooltip(
          message: lang.isItalian ? l10n.english : l10n.italian,
          child: InkWell(
            onTap: () {
              lang.toggleLanguage();
            },
            borderRadius: KyboBorderRadius.pill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: KyboColors.background,
                borderRadius: KyboBorderRadius.pill,
                border: Border.all(color: KyboColors.border),
              ),
              child: Text(
                lang.isItalian ? '🇮🇹 IT' : '🇬🇧 EN',
                style: TextStyle(
                  color: KyboColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// RICERCA GLOBALE DIALOG
// =============================================================================

class _GlobalSearchDialog extends StatefulWidget {
  final List<_NavItem> navItems;
  final void Function(int index) onNavigate;

  const _GlobalSearchDialog({
    required this.navItems,
    required this.onNavigate,
  });

  @override
  State<_GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<_GlobalSearchDialog> {
  final TextEditingController _ctrl = TextEditingController();
  String _query = '';
  List<_SearchResult> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      setState(() => _query = _ctrl.text.trim().toLowerCase());
      if (_query.length >= 2) _runSearch();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    if (_query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);

    try {
      // Cerca utenti in Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(20)
          .get();

      final results = <_SearchResult>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name =
            '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final role = (data['role'] ?? '').toString();

        if (name.contains(_query) || email.contains(_query)) {
          results.add(_SearchResult(
            type: _SearchResultType.user,
            title: '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
            subtitle: data['email'] ?? '',
            badge: role,
            tabIndex: 0, // naviga alla tab Utenti
          ));
        }
      }

      if (mounted) setState(() => _results = results);
    } catch (_) {
      // Ignora errori di ricerca
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: KyboColors.surface,
          borderRadius: KyboBorderRadius.large,
          boxShadow: KyboColors.mediumShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Search Bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: KyboColors.background,
                  borderRadius: KyboBorderRadius.pill,
                  border: Border.all(color: KyboColors.primary.withValues(alpha: 0.4)),
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: TextStyle(color: KyboColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    hintStyle: TextStyle(color: KyboColors.textMuted),
                    prefixIcon: _isSearching
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: KyboColors.primary,
                              ),
                            ),
                          )
                        : Icon(Icons.search_rounded, color: KyboColors.textMuted),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: KyboColors.textMuted),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() {
                                _query = '';
                                _results = [];
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // ─── Results ──────────────────────────────────────────────────
            Flexible(
              child: _query.isEmpty
                  ? _buildEmptyState(l10n)
                  : _results.isEmpty && !_isSearching
                      ? _buildNoResults(l10n)
                      : _buildResults(l10n),
            ),

            // ─── Footer hint ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: KyboColors.border)),
              ),
              child: Row(
                children: [
                  _KeyChip(label: 'Esc'),
                  const SizedBox(width: 6),
                  Text(
                    l10n.close,
                    style: TextStyle(color: KyboColors.textMuted, fontSize: 12),
                  ),
                  const Spacer(),
                  _KeyChip(label: '↵'),
                  const SizedBox(width: 6),
                  Text(
                    l10n.navUsers,
                    style: TextStyle(color: KyboColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 40, color: KyboColors.textMuted),
          const SizedBox(height: 12),
          Text(
            l10n.searchTypeToStart,
            style: TextStyle(color: KyboColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          // Mostra tab navigabili come suggerimenti
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: widget.navItems.asMap().entries.map((e) {
              return ActionChip(
                avatar: Icon(e.value.icon, size: 14, color: KyboColors.primary),
                label: Text(
                  e.value.label,
                  style: TextStyle(fontSize: 12, color: KyboColors.textSecondary),
                ),
                backgroundColor: KyboColors.background,
                side: BorderSide(color: KyboColors.border),
                onPressed: () => widget.onNavigate(e.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: KyboColors.textMuted),
          const SizedBox(height: 12),
          Text(
            l10n.searchNoResults,
            style: TextStyle(color: KyboColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(AppLocalizations l10n) {
    final grouped = <_SearchResultType, List<_SearchResult>>{};
    for (final r in _results) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: grouped.entries.expand((entry) {
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              entry.key == _SearchResultType.user ? l10n.searchUsersSection : '',
              style: TextStyle(
                color: KyboColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...entry.value.map(
            (r) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KyboColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    r.title.isNotEmpty ? r.title[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: KyboColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              title: Text(
                r.title,
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                r.subtitle,
                style: TextStyle(color: KyboColors.textMuted, fontSize: 12),
              ),
              trailing: r.badge.isNotEmpty ? PillBadge.role(r.badge) : null,
              onTap: () => widget.onNavigate(r.tabIndex),
              hoverColor: KyboColors.primary.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
            ),
          ),
        ];
      }).toList(),
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

class _ShortcutRow extends StatelessWidget {
  final String keys;
  final String description;

  const _ShortcutRow({required this.keys, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _KeyChip(label: keys),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(color: KyboColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  final String label;
  const _KeyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KyboColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: KyboColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

class _NavItem {
  final IconData icon;
  final String label;
  final Widget view;
  final int badgeCount;

  _NavItem({
    required this.icon,
    required this.label,
    required this.view,
    this.badgeCount = 0,
  });
}

enum _SearchResultType { user }

class _SearchResult {
  final _SearchResultType type;
  final String title;
  final String subtitle;
  final String badge;
  final int tabIndex;

  _SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.tabIndex,
  });
}
