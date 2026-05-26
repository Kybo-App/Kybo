// Schermata principale del dashboard admin: top bar con navigazione pill, ricerca globale e scorciatoie da tastiera.
// _handleKeyEvent — gestisce Ctrl+K/N/1-8 e Shift+7; _openGlobalSearch — dialog ricerca utenti Firestore.
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
import 'my_day_view.dart';
import 'diet_templates_view.dart';

import 'analytics_view.dart';
import 'gdpr_privacy_view.dart';
import 'reports_view.dart';
import 'server_metrics_view.dart';
import 'rewards_catalog_view.dart';
// [DISABLED workout feature 2026-05-25] import 'workout_management_view.dart';
import 'matchmaking_board_view.dart';

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

class _DashboardContentState extends State<_DashboardContent>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String _userName = "";
  String _userRole = "Utente";
  bool _isAdmin = false;
  bool _isNutritionist = false;
  bool _isPT = false;
  bool _isLoading = true;

  // Stato hover per espandere la sidebar collassata.
  // collapsed = solo icone (72px), expanded = icone + label + badge (240px).
  bool _isSidebarHovered = false;
  static const double _sidebarCollapsedWidth = 72;
  static const double _sidebarExpandedWidth = 240;

  // [FASE 1 — CASCADE EXPAND] AnimationController che piloti l'animazione
  // della sidebar. Ogni item calcolerà un proprio `t locale` in base alla
  // distanza dalla tab selezionata, creando un effetto "onda" che parte
  // dalla selezionata e si propaga simmetricamente sopra/sotto.
  //
  // Param tuning:
  // - itemStaggerMs: ritardo tra item adiacenti (60ms = onda chiaramente
  //   percepibile ma non troppo lenta)
  // - itemAnimMs: durata dell'espansione del singolo item (300ms = morbido)
  // - controllerDurationMs: tempo totale = itemAnimMs + max_distance*stagger.
  //   Con 13 item e selected al centro, max_distance ~ 7, totale ~ 720ms.
  late final AnimationController _sidebarAnim;
  static const int _itemStaggerMs = 60;
  static const int _itemAnimMs = 300;
  static const int _sidebarTotalMs = 800;

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _sidebarAnim = AnimationController(
      duration: const Duration(milliseconds: _sidebarTotalMs),
      vsync: this,
    );
    _fetchCurrentUser();
  }

  @override
  void dispose() {
    _sidebarAnim.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  /// Calcola il `t locale` di un singolo nav item della sidebar in base al
  /// progresso globale del controller e alla distanza dalla tab selezionata.
  ///
  /// L'item selezionato ha delay=0 → inizia subito.
  /// Gli item adiacenti hanno delay=stagger → partono dopo `stagger`ms.
  /// E così via simmetricamente.
  double _itemCascadeT(int index) {
    final globalT = _sidebarAnim.value; // 0..1
    final distance = (index - _selectedIndex).abs();
    final delayMs = distance * _itemStaggerMs;

    final elapsedMs = globalT * _sidebarTotalMs;
    final localProgress =
        ((elapsedMs - delayMs) / _itemAnimMs).clamp(0.0, 1.0);

    // Curva easeInOut applicata localmente per dolcezza
    return Curves.easeInOut.transform(localProgress);
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
          _isNutritionist = _userRole == 'nutritionist' || _isAdmin;
          _isPT = _userRole == 'personal_trainer' || _isAdmin;
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, List<_NavItem> navItems) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrl) {
      if (event.logicalKey == LogicalKeyboardKey.keyK) {
        _openGlobalSearch(navItems);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        // Ctrl+N → tab Utenti (creazione nuovo utente). MyDayView è in 0.
        _onNavSelected(1);
        return KeyEventResult.handled;
      }

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

    // Calcolo lazy degli indici delle tab "chat" e "users" per permettere
    // a MyDayView di saltare a quelle tab tramite onNavigateTo.
    void onMyDayNav(String label) {
      // navItems viene costruito sotto, quindi calcoliamo qui post-build:
      // tab fisse → 'myday'=0, 'users'=1, 'chat'=2 (vedi ordine sotto).
      switch (label) {
        case 'users':
          _onNavSelected(1);
          break;
        case 'chat':
          _onNavSelected(2);
          break;
      }
    }

    final List<_NavItem> navItems = [
      _NavItem(
        icon: Icons.today_rounded,
        label: l10n.myDayTab,
        view: MyDayView(
          key: ValueKey('myday_$themeKey'),
          onNavigateTo: onMyDayNav,
        ),
      ),
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

      if (_isAdmin || _isNutritionist)
        _NavItem(
          icon: Icons.analytics_rounded,
          label: l10n.navAnalytics,
          view: AnalyticsView(key: ValueKey('analytics_$themeKey')),
        ),
      if (_isAdmin || _isNutritionist)
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
      if (_isAdmin)
        _NavItem(
          icon: Icons.monitor_heart_rounded,
          label: l10n.navServer,
          view: ServerMetricsView(key: ValueKey('server_$themeKey')),
        ),
      if (_isAdmin)
        _NavItem(
          icon: Icons.card_giftcard_rounded,
          label: l10n.navRewards,
          view: RewardsCatalogView(key: ValueKey('rewards_$themeKey')),
        ),
      // [DISABLED workout feature 2026-05-25] Per ora la sezione "Allenamento"
      // è nascosta dalla nav admin. Per riattivarla, decommentare il blocco.
      // if (_isPT || _isAdmin)
      //   _NavItem(
      //     icon: Icons.fitness_center_rounded,
      //     label: l10n.navWorkout,
      //     view: WorkoutManagementView(key: ValueKey('workout_$themeKey')),
      //   ),
      if (_isNutritionist || _isAdmin)
        _NavItem(
          icon: Icons.bookmark_rounded,
          label: l10n.dietTemplatesTab,
          view: DietTemplatesView(key: ValueKey('diettpl_$themeKey')),
        ),
      if (_isAdmin || _isPT || _isNutritionist)
        _NavItem(
          icon: Icons.handshake_rounded,
          label: l10n.matchmakingTitle,
          view: MatchmakingBoardView(key: ValueKey('matchmaking_$themeKey')),
        ),
    ];

    if (_selectedIndex >= navItems.length) _selectedIndex = 0;

    // Content area condiviso dai due layout: PillCard con la vista corrente.
    // [PERF] RepaintBoundary isola il content così che durante l'animazione
    // della sidebar (parent) il browser non debba ridisegnare l'intera vista
    // (utenti, analytics, ecc.) ad ogni frame — solo la sidebar si ridipinge.
    final contentArea = Expanded(
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PillCard(
            key: ValueKey('content_card_$themeKey'),
            padding: const EdgeInsets.all(24),
            child: navItems[_selectedIndex].view,
          ),
        ),
      ),
    );

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(node, event, navItems),
      child: Scaffold(
        backgroundColor: KyboColors.background,
        body: Row(
          children: [
            _buildSidebar(navItems, l10n),
            Expanded(
              child: Column(
                children: [
                  _buildTopBarMinimal(navItems, l10n),
                  contentArea,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // [REMOVED 2026-05-25] Layout B (top bar orizzontale legacy) eliminato dopo
  // conferma utente del nuovo Layout A (sidebar). Cronologia git tiene il
  // codice precedente accessibile via blame/log se mai servisse riferimento.
  // Rimossi: _buildTopBar, _buildLogo, _buildNavigation.

  /// Sidebar verticale con cascade expand dalla tab selezionata.
  /// Architettura:
  /// - `_sidebarAnim` (AnimationController) → progresso globale 0..1.
  /// - Larghezza sidebar = lerp(72, 240, globalT).
  /// - Ogni nav item riceve un `t locale` calcolato in `_itemCascadeT(index)`,
  ///   con delay proporzionale a `|index - _selectedIndex|`.
  /// - Effetto: la selezionata si espande per prima, le altre seguono come
  ///   un'onda che si propaga simmetricamente sopra/sotto.
  Widget _buildSidebar(List<_NavItem> navItems, AppLocalizations l10n) {
    return MouseRegion(
      onEnter: (_) {
        if (!_isSidebarHovered) {
          setState(() => _isSidebarHovered = true);
          _sidebarAnim.forward();
        }
      },
      onExit: (_) {
        if (_isSidebarHovered) {
          setState(() => _isSidebarHovered = false);
          _sidebarAnim.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _sidebarAnim,
        builder: (context, _) {
          final globalT = _sidebarAnim.value; // 0..1
          final width = _sidebarCollapsedWidth +
              (_sidebarExpandedWidth - _sidebarCollapsedWidth) * globalT;
          return SizedBox(
            width: width,
            child: ClipRect(
              child: OverflowBox(
                minWidth: _sidebarExpandedWidth,
                maxWidth: _sidebarExpandedWidth,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: _sidebarExpandedWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: KyboColors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                          // Logo: usa globalT (no cascade). È l'header
                          // della sidebar, animarlo in cascade lo farebbe
                          // arrivare con ritardo rispetto al primo item.
                          child: _buildSidebarLogo(l10n, globalT),
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: KyboColors.border,
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            itemCount: navItems.length,
                            itemBuilder: (context, index) {
                              final item = navItems[index];
                              // Ogni item ha il suo t locale, con delay
                              // simmetrico rispetto alla selezionata.
                              final itemT = _itemCascadeT(index);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _SidebarNavItem(
                                  label: item.label,
                                  icon: item.icon,
                                  isSelected: _selectedIndex == index,
                                  badgeCount: item.badgeCount,
                                  onTap: () => _onNavSelected(index),
                                  t: itemT,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Logo per la sidebar. Riceve `t` (0=compatto, 1=esteso) dal parent.
  /// Niente LayoutBuilder: fade tra logo solo e logo+testo via opacity.
  Widget _buildSidebarLogo(AppLocalizations l10n, double t) {
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          // Icona logo sempre presente nella stessa posizione (left-aligned)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KyboColors.primary.withValues(alpha: 0.1),
                  borderRadius: KyboBorderRadius.medium,
                ),
                child: const Center(
                  child: DietLogo(size: 26, isDarkBackground: false),
                ),
              ),
            ),
          ),
          // Testo "Kybo" + sottotitolo: fade-in via opacity, sempre nella
          // stessa posizione layout (no shift).
          Positioned(
            left: 52,
            top: 0,
            bottom: 0,
            right: 0,
            child: Opacity(
              opacity: t,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
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
            ),
          ),
        ],
      ),
    );
  }

  /// Top bar minimale: solo controlli a destra (search, lingua, tema, user,
  /// shortcuts, logout). La nav è nella sidebar a sinistra.
  Widget _buildTopBarMinimal(List<_NavItem> navItems, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: KyboColors.surface,
        boxShadow: KyboColors.softShadow,
      ),
      child: Row(
        children: [
          // Spacer prende lo spazio a sinistra (logo è già nella sidebar)
          const Spacer(),
          _buildUserSection(navItems, l10n),
        ],
      ),
    );
  }

  Widget _buildUserSection(List<_NavItem> navItems, AppLocalizations l10n) {
    final langProvider = LanguageProvider();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SearchPillHint(
          label: l10n.globalSearch,
          onTap: () => _openGlobalSearch(navItems),
        ),

        const SizedBox(width: 4),

        _LanguageToggle(provider: langProvider, l10n: l10n),

        const SizedBox(width: 4),

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

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: KyboColors.background,
            borderRadius: KyboBorderRadius.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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

        PillIconButton(
          icon: Icons.keyboard_rounded,
          color: KyboColors.textSecondary,
          tooltip: l10n.keyboardShortcuts,
          onPressed: _showShortcutsDialog,
        ),

        const SizedBox(width: 4),

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

/// Voce di navigazione della sidebar verticale.
/// Riceve `t` (0..1) dal parent e lo usa per interpolare opacity della
/// label/badge numerico. NIENTE LayoutBuilder, NIENTE AnimatedSwitcher:
/// l'unico animation source è il TweenAnimationBuilder del parent.
class _SidebarNavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;
  final double t;

  const _SidebarNavItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.t,
    this.badgeCount,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    final hover = _isHovered && !selected;
    final hasBadge = widget.badgeCount != null && widget.badgeCount! > 0;
    final t = widget.t;

    final Color bgColor = selected
        ? KyboColors.primary
        : (hover ? KyboColors.primary.withValues(alpha: 0.12) : Colors.transparent);

    final Color fgColor = selected
        ? Colors.white
        : (hover ? KyboColors.primary : KyboColors.textSecondary);

    // Larghezza del background "pill" sotto l'item, interpolata con t.
    // Quando t=0 (compatto): pill di 52px (icona centrata in essa, simmetrica
    // rispetto al padding 14 dell'item → 14 a sx, 24 icona, 14 a dx = 52).
    // Quando t=1 (esteso): pill copre tutto l'item visibile (220px = 240 - 10*2 padding ListView).
    const compactPillWidth = 52.0;
    const expandedPillWidth = 220.0;
    final pillWidth = compactPillWidth + (expandedPillWidth - compactPillWidth) * t;

    // Stack: background pill (Positioned, larghezza dinamica) + Row contenuto.
    // Cosa risolve: prima il bgColor era sul Container outer (sempre 220px
    // wide), e il ClipRect parent lo tagliava al bordo della sidebar
    // collassata, creando l'effetto "selezione tagliata a destra". Ora il
    // pill è dimensionato esplicitamente e cresce smooth con l'animazione.
    Widget content = Stack(
      children: [
        // Background pill animato
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: pillWidth,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: KyboBorderRadius.medium,
              boxShadow: selected ? KyboColors.softShadow : null,
            ),
          ),
        ),
        // Contenuto sopra (icona + label + badge numerico)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icona + eventuale dot badge (visibile solo quando label nascosta)
              SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(child: Icon(widget.icon, size: 20, color: fgColor)),
                    if (hasBadge)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Opacity(
                          opacity: 1 - t,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: KyboColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? KyboColors.primary : KyboColors.surface,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Label sempre presente in layout, solo opacity varia con t.
              Expanded(
                child: Opacity(
                  opacity: t,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    maxLines: 1,
                  ),
                ),
              ),
              // Badge numerico: sempre presente in layout, opacity con t.
              if (hasBadge) ...[
                const SizedBox(width: 6),
                Opacity(
                  opacity: t,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : KyboColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        widget.badgeCount! > 99 ? '99+' : '${widget.badgeCount}',
                        style: TextStyle(
                          color: selected ? KyboColors.primary : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    // Tooltip solo quando la sidebar è collassata abbastanza da nascondere
    // la label.
    if (t < 0.3) {
      content = Tooltip(
        message: hasBadge ? '${widget.label} (${widget.badgeCount})' : widget.label,
        waitDuration: const Duration(milliseconds: 400),
        child: content,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}

/// Pill "Cerca..." con badge della scorciatoia Ctrl+K, per rendere
/// la ricerca globale scopribile senza dover aprire il dialog shortcut.
class _SearchPillHint extends StatelessWidget {
  const _SearchPillHint({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final modifier = isMac ? '⌘' : 'Ctrl';
    return InkWell(
      onTap: onTap,
      borderRadius: KyboBorderRadius.pill,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: KyboColors.background,
          borderRadius: KyboBorderRadius.pill,
          border: Border.all(color: KyboColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                size: 16, color: KyboColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: KyboColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: KyboColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: KyboColors.border),
              ),
              child: Text(
                '$modifier K',
                style: TextStyle(
                  color: KyboColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            tabIndex: 0,
          ));
        }
      }

      if (mounted) setState(() => _results = results);
    } catch (_) {
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

            Flexible(
              child: _query.isEmpty
                  ? _buildEmptyState(l10n)
                  : _results.isEmpty && !_isSearching
                      ? _buildNoResults(l10n)
                      : _buildResults(l10n),
            ),

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
