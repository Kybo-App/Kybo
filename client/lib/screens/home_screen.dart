import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../providers/diet_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/badge_service.dart';
import '../widgets/design_system.dart';
import '../core/error_handler.dart';
import 'diet_view.dart';
import 'pantry_view.dart';
import 'shopping_list_view.dart';
import 'login_screen.dart';
import 'history_screen.dart';
import 'change_password_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'badges_screen.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/env.dart';
import '../services/jailbreak_service.dart';

// --- 1. WRAPPER PRINCIPALE ---
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      autoPlay: false,
      blurValue: 1,
      builder: (context) => const MainScreenContent(),
    );
  }
}

// --- 2. CONTENUTO DELLA SCHERMATA ---
class MainScreenContent extends StatefulWidget {
  const MainScreenContent({super.key});

  @override
  State<MainScreenContent> createState() => _MainScreenContentState();
}

class _MainScreenContentState extends State<MainScreenContent>
    with TickerProviderStateMixin {
  int _currentIndex = 1;
  TabController? _tabController;
  int _lastDaysCount = 0;
  final AuthService _auth = AuthService();

  // CHIAVI TUTORIAL
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _tranquilKey = GlobalKey();
  final GlobalKey _pantryTabKey = GlobalKey();
  final GlobalKey _shoppingTabKey = GlobalKey();

  String _menuTutorialDescription = 'Qui trovi le impostazioni e lo storico.';

  @override
  void initState() {
    super.initState();
    _initialPermissionCheck();
    // TabController viene creato/aggiornato in _ensureTabController()
    // dopo che getDays() ha i dati reali

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkJailbreak();
      _initAppData();
      _checkTutorial();
    });
  }

  /// Crea o ricrea il TabController quando il numero di giorni cambia.
  /// Calcola l'initialIndex trovando il nome del giorno corrente nella lista.
  void _ensureTabController(List<String> days) {
    if (days.isEmpty) return;
    if (_tabController != null && days.length == _lastDaysCount) return;

    // Mappa weekday di Dart (1=Mon..7=Sun) ai nomi italiani standard
    const italianWeekdays = [
      'lunedì', 'martedì', 'mercoledì', 'giovedì',
      'venerdì', 'sabato', 'domenica',
    ];

    final todayWeekday = DateTime.now().weekday; // 1=Mon..7=Sun
    final todayName = italianWeekdays[todayWeekday - 1];

    // Trova l'indice del giorno corrente nella lista della dieta
    int initialIndex = 0;
    for (int i = 0; i < days.length; i++) {
      if (days[i].toLowerCase() == todayName) {
        initialIndex = i;
        break;
      }
    }

    _tabController?.dispose();
    _tabController = TabController(
      length: days.length,
      initialIndex: initialIndex,
      vsync: this,
    );
    _lastDaysCount = days.length;
  }

  Future<void> _initialPermissionCheck() async {
    var status = await Permission.notification.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      await Permission.notification.request();
    }
  }

  // Dialog "Hard": Spiega e manda alle impostazioni
  void _showForcePermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(
          'Notifiche Pasti 🍽️',
          style: TextStyle(color: KyboColors.textPrimary(context)),
        ),
        content: Text(
          'Per ricordarti i pasti e controllare la dispensa, Kybo ha bisogno delle notifiche.\n\n'
          'Per favore, attivale nelle impostazioni del telefono.',
          style: TextStyle(color: KyboColors.textSecondary(context)),
        ),
        actions: [
          PillButton(
            label: 'Annulla',
            onPressed: () => Navigator.pop(context),
            backgroundColor: KyboColors.surface(context),
            textColor: KyboColors.textPrimary(context),
            height: 44,
          ),
          PillButton(
            label: 'Impostazioni',
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );
  }

  Future<void> _initAppData() async {
    if (!mounted) return;
    final provider = context.read<DietProvider>();
    await provider.loadFromCache();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      provider.syncFromFirebase(user.uid);
    }

    final storage = StorageService();
    try {
      // FIX: Rimosso check ridondante 'data is List'
      var data = await storage.loadAlarms();
      if (data.isNotEmpty) {
        // NUOVO
        if (mounted) {
          // Chiediamo al provider di rischedulare usando i dati che possiede
          await context.read<DietProvider>().scheduleMealNotifications();
        }
      }
    } catch (_) {}

    // Check Badges (First Login, Streak)
    if (mounted) {
      context.read<BadgeService>().checkLoginStreak();
    }
  }

// Fix #2: Usa direttamente JailbreakService invece di cercare Provider<bool>
  Future<void> _checkJailbreak() async {
    try {
      final jailbreakService = JailbreakService();
      final isJailbroken = await jailbreakService.checkDevice();
      if (isJailbroken && mounted) {
        _showJailbreakWarning();
      }
    } catch (e) {
      // Ignora errore se jailbreak detection non disponibile (es. emulatore)
      debugPrint('Jailbreak check error: $e');
    }
  }

  // --- LOGICA TUTORIAL ---
  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('seen_tutorial_v10') ?? false;

    if (!seen) {
      _startShowcase();
    }
  }

  Future<void> _startShowcase() async {
    final user = FirebaseAuth.instance.currentUser;
    String role = 'client';

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) role = doc.data()?['role'] ?? 'client';
      } catch (_) {}
    }

    if (role == 'independent' || role == 'admin') {
      _menuTutorialDescription =
          "Qui puoi:\n• Caricare la tua Dieta\n• Gestire Notifiche\n• Vedere lo Storico";
    } else {
      _menuTutorialDescription =
          "Qui puoi:\n• Gestire le Notifiche\n• Vedere lo Storico delle diete passate";
    }

    if (mounted) {
      ShowCaseWidget.of(
        context,
      ).startShowCase([_menuKey, _tranquilKey, _pantryTabKey, _shoppingTabKey]);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_tutorial_v10', true);
    }
  }

  Future<void> _resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_tutorial_v10', false);
    _startShowcase();
  }

  // Helper per mostrare la Privacy Policy (Modale)
  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(
          "Privacy Policy",
          style: TextStyle(color: KyboColors.textPrimary(context)),
        ),
        content: SingleChildScrollView(
          child: Text(
            "Informativa sulla Privacy\n\n"
            "I tuoi dati (email, nome, piano alimentare) sono utilizzati esclusivamente per fornirti il servizio Kybo.\n"
            "I dati sensibili sono protetti e accessibili solo al personale autorizzato per scopi di assistenza tecnica o legale.\n\n"
            "Per richiedere la cancellazione dei dati, contatta l'amministratore.",
            style: TextStyle(
              fontSize: 14,
              color: KyboColors.textSecondary(context),
            ),
          ),
        ),
        actions: [
          PillButton(
            label: "Chiudi",
            onPressed: () => Navigator.pop(ctx),
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );
  }

  void _showJailbreakWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Row(
          children: [
            Icon(Icons.security, color: KyboColors.warning, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Dispositivo Non Sicuro",
                style: TextStyle(
                  fontSize: 18,
                  color: KyboColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Il tuo dispositivo risulta modificato (jailbreak/root).",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: KyboColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Questo comporta rischi per la sicurezza dei tuoi dati medici:",
                style: TextStyle(color: KyboColors.textSecondary(context)),
              ),
              const SizedBox(height: 8),
              Text("• Malware può accedere ai tuoi dati", style: TextStyle(color: KyboColors.textSecondary(context))),
              Text("• Le chiavi di cifratura potrebbero essere compromesse", style: TextStyle(color: KyboColors.textSecondary(context))),
              Text("• App di terze parti possono intercettare informazioni", style: TextStyle(color: KyboColors.textSecondary(context))),
              const SizedBox(height: 16),
              Text(
                "Ti consigliamo vivamente di:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: KyboColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text("• Usare un dispositivo non modificato", style: TextStyle(color: KyboColors.textSecondary(context))),
              Text("• Ripristinare il dispositivo alle impostazioni originali", style: TextStyle(color: KyboColors.textSecondary(context))),
              Text("• Contattare il supporto per assistenza", style: TextStyle(color: KyboColors.textSecondary(context))),
              const SizedBox(height: 16),
              Text(
                "Continuando, accetti che i tuoi dati potrebbero non essere completamente protetti.",
                style: TextStyle(
                  color: KyboColors.error,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          PillButton(
            label: "Ho capito, continua comunque",
            onPressed: () {
              FirebaseAnalytics.instance.logEvent(
                name: 'jailbreak_warning_accepted',
                parameters: {
                  'timestamp': DateTime.now().toIso8601String(),
                },
              );
              Navigator.pop(ctx);
            },
            backgroundColor: KyboColors.warning,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DietProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    final days = provider.getDays();
    _ensureTabController(days);
    final isTablet = KyboBreakpoints.isTablet(context);

    if (provider.needsNotificationPermissions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.resetPermissionFlag();
        _showForcePermissionDialog();
      });
    }

    if (isTablet) {
      return _buildTabletLayout(context, provider, user);
    }
    return _buildMobileLayout(context, provider, user);
  }

  // ─── LAYOUT MOBILE (invariato) ───────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, DietProvider provider, user) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: _currentIndex == 1 && _tabController != null
          ? AppBar(
              backgroundColor: KyboColors.surface(context),
              elevation: 0,
              title: Text(
                "Kybo",
                style: TextStyle(
                  color: KyboColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              iconTheme: IconThemeData(color: KyboColors.textPrimary(context)),
              leading: Builder(
                builder: (context) {
                  return Showcase(
                    key: _menuKey,
                    title: 'Menu Principale',
                    description: _menuTutorialDescription,
                    targetShapeBorder: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  );
                },
              ),
              actions: [
                Showcase(
                  key: _tranquilKey,
                  title: 'Modalità Relax',
                  description:
                      'Tocca la foglia per nascondere le calorie\ne ridurre lo stress.',
                  targetShapeBorder: const CircleBorder(),
                  child: Semantics(
                    label: "Modalità Relax",
                    selected: provider.isTranquilMode,
                    hint: "Nasconde le calorie per ridurre lo stress",
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        provider.isTranquilMode ? Icons.spa : Icons.spa_outlined,
                        color: provider.isTranquilMode
                            ? KyboColors.primary
                            : Colors.grey,
                      ),
                      onPressed: provider.toggleTranquilMode,
                    ),
                  ),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: KyboColors.primary,
                unselectedLabelColor: KyboColors.textMuted(context),
                indicatorColor: KyboColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: provider.getDays()
                    .map((d) => Tab(text: d.length >= 3 ? d.substring(0, 3).toUpperCase() : d.toUpperCase()))
                    .toList(),
              ),
            )
          : null,
      drawer: _buildDrawer(context, user),
      body: _buildBody(provider),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: KyboColors.surface(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.kitchen,
                  label: 'Dispensa',
                  index: 0,
                  showcaseKey: _pantryTabKey,
                  showcaseTitle: 'Dispensa',
                  showcaseDesc: 'Tieni traccia di ciò che hai in casa.\nScorri per eliminare, + per aggiungere.',
                ),
                _buildNavItem(
                  icon: Icons.calendar_today,
                  label: 'Piano',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.shopping_cart,
                  label: 'Lista',
                  index: 2,
                  showcaseKey: _shoppingTabKey,
                  showcaseTitle: 'Lista della Spesa',
                  showcaseDesc: 'Generata in automatico dalla tua dieta.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── LAYOUT TABLET ───────────────────────────────────────────────────────
  Widget _buildTabletLayout(BuildContext context, DietProvider provider, user) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      body: Row(
        children: [
          // ── Sidebar sinistra: NavigationRail + drawer content ────────────
          _buildTabletSidebar(context, provider, user),
          // Separatore verticale
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: KyboColors.border(context),
          ),
          // ── Area contenuto principale ────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // AppBar solo per la tab Piano (giorni della settimana)
                if (_currentIndex == 1 && _tabController != null)
                  _buildTabletAppBar(context, provider),
                Expanded(child: _buildBody(provider)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sidebar tablet: logo + NavigationRail + menu items del drawer
  Widget _buildTabletSidebar(BuildContext context, DietProvider provider, user) {
    final String initial = (user?.email != null && user!.email!.isNotEmpty)
        ? user.email![0].toUpperCase()
        : "U";

    return Container(
      width: 220,
      color: KyboColors.surface(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header profilo ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [KyboColors.primary, KyboColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: KyboColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Kybo",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          user?.email ?? "Ospite",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── NavigationRail items (Dispensa, Piano, Lista) ──────────
            _buildSidebarNavItem(
              context: context,
              icon: Icons.kitchen,
              label: 'Dispensa',
              index: 0,
            ),
            _buildSidebarNavItem(
              context: context,
              icon: Icons.calendar_today,
              label: 'Piano',
              index: 1,
            ),
            _buildSidebarNavItem(
              context: context,
              icon: Icons.shopping_cart,
              label: 'Lista Spesa',
              index: 2,
            ),

            Divider(color: KyboColors.border(context), indent: 12, endIndent: 12),

            // ── Menu items del drawer ──────────────────────────────────
            Expanded(
              child: _buildTabletDrawerItems(context, provider, user),
            ),
          ],
        ),
      ),
    );
  }

  /// Singolo item di navigazione nella sidebar tablet
  Widget _buildSidebarNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: KyboBorderRadius.large,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? KyboColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: KyboBorderRadius.large,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? KyboColors.primary : KyboColors.textMuted(context),
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? KyboColors.primary : KyboColors.textSecondary(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: KyboColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Menu items secondari nella sidebar tablet (stesso contenuto del drawer mobile)
  Widget _buildTabletDrawerItems(BuildContext context, DietProvider provider, user) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        bool hasNutritionist = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          hasNutritionist = ((data?['parent_id'] != null &&
                  (data?['parent_id'].toString().isNotEmpty ?? false)) ||
              (data?['created_by'] != null &&
                  (data?['created_by'].toString().isNotEmpty ?? false)));
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            // Chat o Upload
            if (hasNutritionist)
              Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  final unreadCount = chatProvider.unreadCount;
                  return _buildSidebarMenuItem(
                    context: context,
                    icon: Icons.chat_bubble,
                    label: 'Chat',
                    subtitle: unreadCount > 0
                        ? '$unreadCount non letti'
                        : null,
                    badge: unreadCount > 0 ? '$unreadCount' : null,
                    iconColor: KyboColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    ),
                  );
                },
              )
            else
              _buildSidebarMenuItem(
                context: context,
                icon: Icons.upload_file,
                label: 'Carica Dieta',
                iconColor: KyboColors.warning,
                onTap: () => _uploadDiet(context),
              ),

            _buildSidebarMenuItem(
              context: context,
              icon: Icons.history,
              label: 'Cronologia',
              iconColor: KyboColors.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
            _buildSidebarMenuItem(
              context: context,
              icon: Icons.emoji_events_rounded,
              label: 'Traguardi',
              iconColor: KyboColors.warning,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BadgesScreen()),
              ),
            ),
            _buildSidebarMenuItem(
              context: context,
              icon: Icons.picture_as_pdf_rounded,
              label: 'Esporta PDF',
              iconColor: KyboColors.primary,
              onTap: () => _exportDietPdf(context),
            ),
            _buildSidebarMenuItem(
              context: context,
              icon: Icons.bar_chart_rounded,
              label: 'Statistiche',
              iconColor: KyboColors.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              ),
            ),
            _buildSidebarMenuItem(
              context: context,
              icon: Icons.settings_rounded,
              label: 'Impostazioni',
              iconColor: KyboColors.textMuted(context),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Singolo item di menu nella sidebar tablet
  Widget _buildSidebarMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    String? subtitle,
    String? badge,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: KyboBorderRadius.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: KyboColors.textPrimary(context),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: KyboColors.textMuted(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: KyboColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// AppBar per tablet: senza hamburger menu, con TabBar giorni
  PreferredSizeWidget _buildTabletAppBar(BuildContext context, DietProvider provider) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: KyboColors.surface(context),
      elevation: 0,
      title: Text(
        "Piano Alimentare",
        style: TextStyle(
          color: KyboColors.textPrimary(context),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        Showcase(
          key: _tranquilKey,
          title: 'Modalità Relax',
          description: 'Tocca la foglia per nascondere le calorie\ne ridurre lo stress.',
          targetShapeBorder: const CircleBorder(),
          child: Semantics(
            label: "Modalità Relax",
            selected: provider.isTranquilMode,
            button: true,
            child: IconButton(
              icon: Icon(
                provider.isTranquilMode ? Icons.spa : Icons.spa_outlined,
                color: provider.isTranquilMode ? KyboColors.primary : Colors.grey,
              ),
              onPressed: provider.toggleTranquilMode,
            ),
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: KyboColors.primary,
        unselectedLabelColor: KyboColors.textMuted(context),
        indicatorColor: KyboColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: provider.getDays()
            .map((d) => Tab(
                text: d.length >= 3
                    ? d.substring(0, 3).toUpperCase()
                    : d.toUpperCase()))
            .toList(),
      ),
    );
  }

  /// Returns (mealName, dayName) of the next upcoming meal, or null if none found.
  (String, String)? _findNextMeal(DietProvider provider) {
    final plan = provider.dietPlan;
    if (plan == null) return null;

    final days = provider.getDays();
    if (days.isEmpty) return null;

    // Ordered meal times for determining "next" meal by name
    const mealOrder = [
      'Colazione', 'Seconda Colazione', 'Pranzo', 'Merenda', 'Cena',
      'Spuntino', 'Spuntino Serale',
    ];

    // Map Italian weekday index (1=Mon) to day name
    const italianWeekdays = [
      'lunedì', 'martedì', 'mercoledì', 'giovedì',
      'venerdì', 'sabato', 'domenica',
    ];

    final now = DateTime.now();
    final todayName = italianWeekdays[now.weekday - 1];

    // Find today in the plan
    String? todayKey;
    for (final day in days) {
      if (day.toLowerCase() == todayName) {
        todayKey = day;
        break;
      }
    }
    if (todayKey == null) return null;

    final dayPlan = plan.plan[todayKey];
    if (dayPlan == null || dayPlan.isEmpty) return null;

    // Hour-based: estimate next meal based on current hour
    final hour = now.hour;
    final String nextMealName;
    if (hour < 9) {
      nextMealName = 'Colazione';
    } else if (hour < 11) {
      nextMealName = 'Seconda Colazione';
    } else if (hour < 14) {
      nextMealName = 'Pranzo';
    } else if (hour < 17) {
      nextMealName = 'Merenda';
    } else if (hour < 21) {
      nextMealName = 'Cena';
    } else {
      nextMealName = 'Spuntino Serale';
    }

    // Find in plan (case-insensitive partial match)
    for (final mealKey in dayPlan.keys) {
      if (mealKey.toLowerCase().contains(nextMealName.toLowerCase()) ||
          nextMealName.toLowerCase().contains(mealKey.toLowerCase())) {
        final dishes = dayPlan[mealKey];
        if (dishes != null && dishes.isNotEmpty) {
          return (mealKey, todayKey);
        }
      }
    }

    // Fall back to first non-consumed meal in order
    for (final orderedMeal in mealOrder) {
      for (final mealKey in dayPlan.keys) {
        if (mealKey.toLowerCase().contains(orderedMeal.toLowerCase())) {
          final dishes = dayPlan[mealKey];
          if (dishes != null && dishes.any((d) => !d.isConsumed)) {
            return (mealKey, todayKey);
          }
        }
      }
    }

    return null;
  }

  Widget _buildNextMealBanner(DietProvider provider) {
    final next = _findNextMeal(provider);
    if (next == null) return const SizedBox.shrink();

    final (mealName, _) = next;
    final plan = provider.dietPlan?.plan;
    final dishes = plan?[_findNextMeal(provider)!.$2]?[mealName] ?? [];
    if (dishes.isEmpty) return const SizedBox.shrink();

    // Show first 2 dishes as preview
    final preview = dishes.take(2).map((d) => d.name).join(', ');
    final more = dishes.length > 2 ? ' +${dishes.length - 2}' : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: KyboColors.primary.withValues(alpha: 0.08),
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(color: KyboColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant_rounded, color: KyboColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prossimo pasto: $mealName',
                  style: TextStyle(
                    fontSize: 12,
                    color: KyboColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$preview$more',
                  style: TextStyle(
                    fontSize: 12,
                    color: KyboColors.textSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DietProvider provider) {
    switch (_currentIndex) {
      case 0:
        return PantryView(
          pantryItems: provider.pantryItems,
          onAddManual: provider.addPantryItem,
          onRemove: provider.removePantryItem,
          onScanTap: () => _scanReceipt(provider),
        );
      case 1:
        // [FIX] TabController null = giorni non ancora caricati
        if (_tabController == null || provider.getDays().isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: KyboColors.primary),
          );
        }
        return Column(
          children: [
            _buildNextMealBanner(provider),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: provider.getDays().map((day) {
                  return DietView(
                    day: day,
                    dietPlan: provider.dietPlan,
                    isLoading: provider.isLoading,
                    activeSwaps: provider.activeSwaps,
                    pantryItems: provider.pantryItems,
                    isTranquilMode: provider.isTranquilMode,
                  );
                }).toList(),
              ),
            ),
          ],
        );
      case 2:
        return ShoppingListView(
          shoppingList: provider.shoppingList,
          dietPlan:
              provider.dietPlan, // <--- PASSA L'OGGETTO (prima era dietData)
          activeSwaps: provider.activeSwaps,
          pantryItems: provider.pantryItems,
          onUpdateList: provider.updateShoppingList,
          onAddToPantry: provider.addPantryItem,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    GlobalKey? showcaseKey,
    String? showcaseTitle,
    String? showcaseDesc,
  }) {
    final isSelected = _currentIndex == index;
    
    Widget navItem = InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: KyboBorderRadius.large,
      child: Semantics(
        label: label,
        selected: isSelected,
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? KyboColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: KyboBorderRadius.large,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? KyboColors.primary : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? KyboColors.primary : Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (showcaseKey != null && showcaseTitle != null && showcaseDesc != null) {
      return Showcase(
        key: showcaseKey,
        title: showcaseTitle,
        description: showcaseDesc,
        child: navItem,
      );
    }

    return navItem;
  }

  Widget _buildDrawer(BuildContext drawerCtx, User? user) {
    final String initial = (user?.email != null && user!.email!.isNotEmpty)
        ? user.email![0].toUpperCase()
        : "U";

    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots()
          : const Stream.empty(),
      builder: (streamCtx, snapshot) {
        String role = 'user';
        if (snapshot.hasData && snapshot.data!.exists) {
          role =
              (snapshot.data!.data() as Map<String, dynamic>)['role'] ?? 'user';
        }
        final bool canUpload = (role == 'independent' || role == 'admin');

        return Drawer(
          backgroundColor: KyboColors.background(drawerCtx),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      KyboColors.primary,
                      KyboColors.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: KyboColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Kybo",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? "Ospite",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (user != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                    builder: (context, snapshot) {
                      // Determine if user has a nutritionist by checking parent_id or created_by
                      // If user has parent_id/created_by, they are a client with nutritionist → Show Chat
                      // If user doesn't have parent_id, they are independent → Show Upload
                      bool hasNutritionist = false;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        hasNutritionist = ((data?['parent_id'] != null && (data?['parent_id'].toString().isNotEmpty ?? false)) ||
                                         (data?['created_by'] != null && (data?['created_by'].toString().isNotEmpty ?? false)));
                      }
                      
                      return Column(
                        children: [
                          // 💬 Chat OR 📤 Upload (mutually exclusive)
                          if (hasNutritionist) ...[
                            // User has nutritionist → Show Chat
                            Consumer<ChatProvider>(
                              builder: (context, chatProvider, _) {
                                final unreadCount = chatProvider.unreadCount;
                                return PillListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: KyboColors.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Stack(
                                      children: [
                                        const Icon(Icons.chat_bubble, color: KyboColors.primary, size: 20),
                                        if (unreadCount > 0)
                                          Positioned(
                                            top: -2,
                                            right: -2,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: KyboColors.error,
                                                shape: BoxShape.circle,
                                              ),
                                              constraints: const BoxConstraints(
                                                minWidth: 16,
                                                minHeight: 16,
                                              ),
                                              child: Text(
                                                unreadCount > 9 ? '9+' : '$unreadCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  title: "Chat",
                                  subtitle: unreadCount > 0 
                                      ? "$unreadCount ${unreadCount == 1 ? 'messaggio' : 'messaggi'} non letto" 
                                      : "Parla con il tuo nutrizionista",
                                  onTap: () {
                                    Navigator.pop(drawerCtx);
                                    Navigator.push(
                                      drawerCtx,
                                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                                    );
                                  },
                                );
                              },
                            ),
                          ] else ...[
                            // User is independent → Show Upload Diet
                            PillListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: KyboColors.warning.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.upload_file, color: KyboColors.warning, size: 20),
                              ),
                              title: "Carica Dieta PDF",
                              subtitle: "Importa una nuova dieta",
                              onTap: () {
                                Navigator.pop(drawerCtx);
                                _uploadDiet(drawerCtx);
                              },
                            ),
                          ],

                          // 📜 Cronologia
                          PillListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: KyboColors.accent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history, color: KyboColors.accent, size: 20),
                            ),
                            title: "Cronologia",
                            onTap: () {
                              Navigator.pop(drawerCtx);
                              Navigator.push(
                                drawerCtx,
                                MaterialPageRoute(builder: (_) => const HistoryScreen()),
                              );
                            },
                          ),

                          // 🏆 Traguardi / Badges
                          PillListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: KyboColors.warning.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.emoji_events_rounded, color: KyboColors.warning, size: 20),
                            ),
                            title: "Traguardi",
                            onTap: () {
                              Navigator.pop(drawerCtx);
                              Navigator.push(
                                drawerCtx,
                                MaterialPageRoute(builder: (_) => const BadgesScreen()),
                              );
                            },
                          ),

                          // 📄 Esporta Dieta PDF
                          PillListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: KyboColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.picture_as_pdf_rounded, color: KyboColors.primary, size: 20),
                            ),
                            title: "Esporta Dieta PDF",
                            subtitle: "Scarica la tua dieta in PDF",
                            onTap: () {
                              Navigator.pop(drawerCtx);
                              _exportDietPdf(drawerCtx);
                            },
                          ),

                          // ⚙️ Impostazioni
                          PillListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: KyboColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.settings, color: KyboColors.success, size: 20),
                            ),
                            title: "Impostazioni",
                            onTap: () {
                              Navigator.pop(drawerCtx);
                              Navigator.push(
                                drawerCtx,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            },
                          ),

                          // 📊 Statistiche
                          PillListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.analytics, color: Colors.purple, size: 20),
                            ),
                            title: "Statistiche",
                            subtitle: "Progressi e tracking peso",
                            onTap: () {
                              Navigator.pop(drawerCtx);
                              Navigator.push(
                                drawerCtx,
                                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                              );
                            },
                          ),

                          // 🚪 Esci
                          PillListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: KyboColors.error.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.logout, color: KyboColors.error, size: 20),
                            ),
                            title: "Esci",
                            onTap: () async {
                              Navigator.pop(drawerCtx);
                              await context.read<DietProvider>().clearData();
                              await _auth.signOut();
                              if (mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadDiet(BuildContext context) async {
    final provider = Provider.of<DietProvider>(context, listen: false);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return; // Utente ha annullato
      }

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;

      // ✅ Mostra dialog con progresso
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: KyboColors.surface(context),
              shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
              title: Text(
                "Caricamento Dieta",
                style: TextStyle(color: KyboColors.textPrimary(context)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Progress bar reale con Consumer
                  Consumer<DietProvider>(
                    builder: (_, prov, __) {
                      final progress = prov.uploadProgress;
                      final percentage = (progress * 100).toInt();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: KyboColors.border(context),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                KyboColors.primary,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "$percentage%",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: KyboColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 12,
                              color: KyboColors.textMuted(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          // ✅ Messaggio dinamico basato su progresso
                          Text(
                            percentage < 95
                                ? "Upload in corso..."
                                : "Elaborazione AI...",
                            style: TextStyle(
                              fontSize: 14,
                              color: KyboColors.textSecondary(context),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // ✅ Esegui upload (progress viene tracciato automaticamente)
      await provider.uploadDiet(filePath);

      // Chiudi dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Dieta caricata con successo!"),
            backgroundColor: KyboColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Chiudi dialog se aperto
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.toUserMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _exportDietPdf(BuildContext ctx) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await user.getIdToken();
      final uri = Uri.parse('${Env.apiUrl}/export-diet-pdf');

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Generazione PDF in corso...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Launch the API URL with auth token as query param for direct browser download
        final downloadUri = Uri.parse(
          '${Env.apiUrl}/export-diet-pdf?token=${Uri.encodeComponent(token!)}',
        );
        if (await canLaunchUrl(downloadUri)) {
          await launchUrl(downloadUri, mode: LaunchMode.externalApplication);
        }
      } else {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('Errore esportazione: ${response.statusCode}'),
              backgroundColor: KyboColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  Future<void> _scanReceipt(DietProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        int count = await provider.scanReceipt(result.files.single.path!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Aggiunti $count prodotti!"),
              backgroundColor: KyboColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.toUserMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openTimeSettings() async {
    // Orari default per ogni tipo di pasto
    final Map<String, String> defaultTimes = {
      'Colazione': '08:00',
      'Seconda Colazione': '10:30',
      'Pranzo': '13:00',
      'Merenda': '16:00',
      'Cena': '20:00',
      'Spuntino': '11:00',
      'Spuntino Serale': '22:00',
    };

    // Carica impostazioni salvate
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('meal_alarms');
    Map<String, String> currentAlarms = {};

    if (savedJson != null) {
      try {
        final decoded = jsonDecode(savedJson) as Map<String, dynamic>;
        decoded.forEach((k, v) => currentAlarms[k] = v.toString());
      } catch (_) {}
    }

    // Stato per il dialog
    Map<String, bool> enabled = {};
    Map<String, TimeOfDay> times = {};

    for (var mealType in defaultTimes.keys) {
      enabled[mealType] = currentAlarms.containsKey(mealType);
      if (currentAlarms.containsKey(mealType)) {
        final parts = currentAlarms[mealType]!.split(':');
        times[mealType] = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } else {
        final parts = defaultTimes[mealType]!.split(':');
        times[mealType] = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    if (!mounted) return;

    // Verifica permessi
    final notificationService = NotificationService();
    await notificationService.requestPermissions();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (innerCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: KyboColors.surface(context),
              shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
              title: Row(
                children: [
                  Icon(Icons.notifications_active, color: KyboColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Promemoria Pasti",
                    style: TextStyle(color: KyboColors.textPrimary(context)),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          "Attiva i promemoria per ricevere notifiche all'orario dei pasti.",
                          style: TextStyle(
                            color: KyboColors.textSecondary(innerCtx),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      ...defaultTimes.keys.map((mealType) {
                        final time = times[mealType]!;
                        final isEnabled = enabled[mealType] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? KyboColors.primary.withValues(alpha: 0.1)
                                : KyboColors.surface(innerCtx),
                            borderRadius: KyboBorderRadius.medium,
                            border: Border.all(
                              color: isEnabled
                                  ? KyboColors.primary.withValues(alpha: 0.3)
                                  : KyboColors.border(innerCtx),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Switch(
                              value: isEnabled,
                              activeTrackColor: KyboColors.primary.withValues(alpha: 0.5),
                              thumbColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) return KyboColors.primary;
                                return Colors.grey;
                              }),
                              onChanged: (val) {
                                setDialogState(() => enabled[mealType] = val);
                              },
                            ),
                            title: Text(
                              mealType,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isEnabled
                                    ? KyboColors.primary
                                    : KyboColors.textSecondary(innerCtx),
                              ),
                            ),
                            trailing: isEnabled
                                ? InkWell(
                                    onTap: () async {
                                      final p = await showTimePicker(
                                        context: innerCtx,
                                        initialTime: time,
                                      );
                                      if (p != null) {
                                        setDialogState(() => times[mealType] = p);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: KyboColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                    ),
                                  ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                PillButton(
                  label: "Annulla",
                  onPressed: () => Navigator.pop(ctx),
                  backgroundColor: KyboColors.surface(context),
                  textColor: KyboColors.textPrimary(context),
                  height: 44,
                ),
                PillButton(
                  icon: Icons.save,
                  label: "Salva",
                  onPressed: () async {
                    Navigator.pop(ctx);

                    // Salva solo i pasti attivati
                    Map<String, String> toSave = {};
                    for (var mealType in defaultTimes.keys) {
                      if (enabled[mealType] == true) {
                        final t = times[mealType]!;
                        toSave[mealType] =
                            "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
                      }
                    }

                    await prefs.setString('meal_alarms', jsonEncode(toSave));

                    // Rischedula notifiche
                    if (mounted) {
                      await context
                          .read<DietProvider>()
                          .scheduleMealNotifications();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              toSave.isEmpty
                                  ? "Promemoria disattivati"
                                  : "Attivati ${toSave.length} promemoria",
                            ),
                            backgroundColor: KyboColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  backgroundColor: KyboColors.primary,
                  textColor: Colors.white,
                  height: 44,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
