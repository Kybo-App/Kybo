// Schermata principale con navbar (Dispensa/Piano/Lista), drawer laterale e layout tablet adattivo.
// _ensureTabController — ricrea il TabController quando cambiano i giorni o la settimana selezionata.
// _findNextMeal — individua il prossimo pasto non consumato in base all'ora corrente.
// _onShowcaseComplete — gestisce le transizioni tra le fasi del tutorial interattivo.
import 'dart:async';
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
import '../providers/chat_provider.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../services/xp_service.dart';
import '../services/challenge_service.dart';
import '../widgets/design_system.dart';
import '../widgets/streak_badge_widget.dart';
import '../core/error_handler.dart';
import 'diet_view.dart';
import 'pantry_view.dart';
import 'shopping_list_view.dart';
import 'login_screen.dart';
import 'history_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'badges_screen.dart';
import 'meal_suggestions_screen.dart';
import 'rewards_screen.dart';
import 'workout_screen.dart';
import 'matchmaking_screen.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../core/env.dart';
import '../services/jailbreak_service.dart';
import '../services/deep_link_service.dart';
import '../services/shortcuts_service.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  static final GlobalKey<_MainScreenContentState> _contentKey =
      GlobalKey<_MainScreenContentState>();

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      autoPlay: false,
      blurValue: 1,
      enableAutoScroll: true,
      onComplete: (index, key) =>
          _contentKey.currentState?._onShowcaseComplete(key),
      builder: (context) => MainScreenContent(key: _contentKey),
    );
  }
}

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
  int _lastSelectedWeek = 0;
  final AuthService _auth = AuthService();
  StreamSubscription<String>? _deepLinkNavSubscription;

  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _tranquilKey = GlobalKey();
  final GlobalKey _swapDayKey = GlobalKey();
  final GlobalKey _pantryTabKey = GlobalKey();
  final GlobalKey _shoppingTabKey = GlobalKey();

  final GlobalKey _drawerAvatarKey = GlobalKey();
  final GlobalKey _drawerChatKey = GlobalKey();
  final GlobalKey _drawerUploadKey = GlobalKey();
  final GlobalKey _drawerHistoryKey = GlobalKey();
  final GlobalKey _drawerBadgesKey = GlobalKey();
  final GlobalKey _drawerPdfKey = GlobalKey();
  final GlobalKey _drawerSettingsKey = GlobalKey();
  final GlobalKey _drawerStatsKey = GlobalKey();
  final GlobalKey _drawerSuggestionsKey = GlobalKey();
  final GlobalKey _drawerWorkoutKey = GlobalKey();
  final GlobalKey _drawerRewardsKey = GlobalKey();
  final GlobalKey _drawerMatchmakingKey = GlobalKey();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _hasNutritionistForTutorial = false;

  @override
  void initState() {
    super.initState();
    _initialPermissionCheck();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkJailbreak();
      await _initAppData();
      _checkTutorial();
      _handleInitialDeepLink();
    });

    _deepLinkNavSubscription = DeepLinkService().navigationStream.listen(_handleNavTarget);
  }

  @override
  void dispose() {
    _deepLinkNavSubscription?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  /// Gestisce il deep link iniziale (cold start) dopo che i dati sono caricati.
  void _handleInitialDeepLink() {
    final uri = DeepLinkService().lastUri;
    if (uri == null) return;
    final target = DeepLinkService.getNavigationTarget(uri);
    if (target != null) _handleNavTarget(target);
  }

  /// Naviga alla schermata corretta quando arriva un deep link da Siri / Assistant.
  void _handleNavTarget(String target) {
    if (!mounted) return;
    switch (target) {
      case NavTarget.diet:
        setState(() => _currentIndex = 1);
        break;
      case NavTarget.suggestions:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MealSuggestionsScreen()),
        );
        break;
      case NavTarget.shoppingList:
        setState(() => _currentIndex = 2);
        final shareId = DeepLinkService.getSharedListId(DeepLinkService().lastUri);
        if (shareId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndShowSharedList(shareId));
        }
        break;
    }
  }

  Future<void> _loadAndShowSharedList(String shareId) async {
    if (!mounted) return;
    try {
      final response = await http.get(
        Uri.parse('${Env.apiUrl}/shopping-list/share/$shareId'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = List<String>.from(data['items'] ?? []);
        final title = data['title'] as String? ?? 'Lista condivisa';
        _showSharedListDialog(title, items);
      }
    } catch (_) {}
  }

  void _showSharedListDialog(String title, List<String> items) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) => ListTile(
              leading: Icon(Icons.shopping_cart_outlined, color: KyboColors.primary),
              title: Text(items[i]),
              dense: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _mergeSharedItems(items);
            },
            child: const Text('Aggiungi alla lista'),
          ),
        ],
      ),
    );
  }

  // Regex: "200g di pollo" | "2 mele" | "1 kg riso"
  static final _itemRegex = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s*(g|gr|kg|ml|l|cl|dl|pz|pezzi|fett[ae]|cucchiai(?:no)?|tazz[ae]?)?\s*(?:di\s+)?(.+)$',
    caseSensitive: false,
  );

  static (double, String, String)? _parseItem(String raw) {
    final text = raw.startsWith('OK_') ? raw.substring(3) : raw;
    final m = _itemRegex.firstMatch(text.trim());
    if (m == null) return null;
    final qty = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 1.0;
    final unit = (m.group(2) ?? '').toLowerCase();
    final name = m.group(3)!.trim().toLowerCase();
    return (qty, unit, name);
  }

  static String _formatItem(double qty, String unit, String name) {
    final q = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
    return unit.isNotEmpty ? '$q$unit di $name' : '$q $name';
  }

  void _mergeSharedItems(List<String> incomingItems) {
    if (!mounted) return;
    final provider = context.read<DietProvider>();
    final updated = List<String>.from(provider.shoppingList);
    int added = 0;
    int summed = 0;

    for (final incoming in incomingItems) {
      final parsed = _parseItem(incoming);
      if (parsed != null) {
        final (inQty, inUnit, inName) = parsed;
        int matchIdx = -1;
        for (int i = 0; i < updated.length; i++) {
          final ex = _parseItem(updated[i]);
          if (ex != null) {
            final (_, exUnit, exName) = ex;
            if (exName == inName && exUnit == inUnit) { matchIdx = i; break; }
          }
        }
        if (matchIdx >= 0) {
          final (exQty, exUnit, exName) = _parseItem(updated[matchIdx])!;
          updated[matchIdx] = _formatItem(exQty + inQty, exUnit, exName);
          summed++;
        } else {
          updated.add(incoming);
          added++;
        }
      } else {
        final plain = incoming.startsWith('OK_') ? incoming.substring(3) : incoming;
        final alreadyPresent = updated.any((e) {
          final t = e.startsWith('OK_') ? e.substring(3) : e;
          return t.toLowerCase() == plain.toLowerCase();
        });
        if (!alreadyPresent) { updated.add(incoming); added++; }
      }
    }

    provider.updateShoppingList(updated);
    final parts = <String>[];
    if (added > 0) parts.add('$added aggiunt${added == 1 ? 'o' : 'i'}');
    if (summed > 0) parts.add('$summed sommati');
    final msg = parts.isEmpty ? 'Nessuna modifica.' : parts.join(', ');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Crea o ricrea il TabController quando cambia il numero di giorni o la settimana selezionata.
  void _ensureTabController(List<String> days, int selectedWeek) {
    if (days.isEmpty) return;
    if (_tabController != null &&
        days.length == _lastDaysCount &&
        selectedWeek == _lastSelectedWeek) {
      return;
    }

    const italianWeekdays = [
      'lunedì', 'martedì', 'mercoledì', 'giovedì',
      'venerdì', 'sabato', 'domenica',
    ];

    final todayWeekday = DateTime.now().weekday;
    final todayName = italianWeekdays[todayWeekday - 1];

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
    _lastSelectedWeek = selectedWeek;
  }

  Future<void> _initialPermissionCheck() async {
    var status = await Permission.notification.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      await Permission.notification.request();
    }
  }

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
      var data = await storage.loadAlarms();
      if (data.isNotEmpty) {
        if (mounted) {
          await context.read<DietProvider>().scheduleMealNotifications();
        }
      }
    } catch (_) {}

    if (mounted) {
      context.read<BadgeService>().checkLoginStreak();
      context.read<XpService>().loadXp();
      context.read<ChallengeService>().loadOrGenerateDailyChallenges();
    }

    ShortcutsService().donateShortcut(ShortcutsService.dietActivity);
  }

  Future<void> _checkJailbreak() async {
    try {
      final jailbreakService = JailbreakService();
      final isJailbroken = await jailbreakService.checkDevice();
      if (isJailbroken && mounted) {
        _showJailbreakWarning();
      }
    } catch (e) {
      debugPrint('Jailbreak check error: $e');
    }
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    // v12: refresh del tour dopo riorganizzazione menu + nuove funzioni
    // (foto profilo, premi con URL esterno, studio del professionista).
    bool seen = prefs.getBool('seen_tutorial_v13') ?? false;

    if (!seen) {
      _startShowcase();
    }
  }

  Future<void> _startShowcase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          _hasNutritionistForTutorial =
              (data?['parent_id'] != null &&
                  data!['parent_id'].toString().isNotEmpty) ||
              (data?['created_by'] != null &&
                  data!['created_by'].toString().isNotEmpty);
        }
      } catch (_) {}
    }

    for (int i = 0; i < 10 && _tabController == null && mounted; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (mounted) {
      ShowCaseWidget.of(context).startShowCase([_menuKey]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_tutorial_v13', true);
    }
  }

  /// Gestisce le transizioni tra le fasi del tutorial interattivo.
  void _onShowcaseComplete(GlobalKey key) {
    if (!mounted) return;

    if (key == _menuKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _scaffoldKey.currentState?.openDrawer();
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        // Ordine aggiornato: Impostazioni promosse, Cronologia in fondo (v12).
        final drawerKeys = _hasNutritionistForTutorial
            ? [
                _drawerAvatarKey,
                _drawerChatKey,
                _drawerSettingsKey,
                _drawerWorkoutKey,
                _drawerBadgesKey,
                _drawerStatsKey,
                _drawerSuggestionsKey,
                _drawerRewardsKey,
                _drawerPdfKey,
                _drawerHistoryKey,
              ]
            : [
                _drawerAvatarKey,
                _drawerUploadKey,
                _drawerSettingsKey,
                _drawerWorkoutKey,
                _drawerBadgesKey,
                _drawerStatsKey,
                _drawerSuggestionsKey,
                _drawerRewardsKey,
                _drawerPdfKey,
                _drawerHistoryKey,
                _drawerMatchmakingKey,
              ];
        ShowCaseWidget.of(context).startShowCase(drawerKeys);
      });
    } else if (key == _drawerHistoryKey && _hasNutritionistForTutorial) {
      // Utente con nutri: l'ultimo step del drawer è Cronologia.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
        }
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        setState(() => _currentIndex = 1);
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        ShowCaseWidget.of(context).startShowCase([_tranquilKey]);
      });
    } else if (key == _drawerMatchmakingKey && !_hasNutritionistForTutorial) {
      // Utente senza nutri: l'ultimo step del drawer è "Trova Coach".
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
        }
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        setState(() => _currentIndex = 1);
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        ShowCaseWidget.of(context).startShowCase([_tranquilKey]);
      });
    } else if (key == _tranquilKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        ShowCaseWidget.of(context).startShowCase([_swapDayKey]);
      });
    } else if (key == _swapDayKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        setState(() => _currentIndex = 0);
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        ShowCaseWidget.of(context).startShowCase([_pantryTabKey]);
      });
    } else if (key == _pantryTabKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        setState(() => _currentIndex = 2);
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        ShowCaseWidget.of(context).startShowCase([_shoppingTabKey]);
      });
    } else if (key == _shoppingTabKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = 1);
      });
    }
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
    _ensureTabController(days, provider.selectedWeek);
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

  void _showDaySwapSheet(BuildContext context, DietProvider provider) {
    final days = provider.getDays();
    final currentDayIndex = _tabController?.index ?? 0;
    if (currentDayIndex >= days.length) return;
    final currentDay = days[currentDayIndex];
    final otherDays = days.where((d) => d != currentDay).toList();

    if (otherDays.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: KyboColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Scambia $currentDay con...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.textPrimary(context),
                ),
              ),
            ),
            ...otherDays.map((day) => ListTile(
              leading: Icon(Icons.swap_horiz, color: KyboColors.primary),
              title: Text(day, style: TextStyle(color: KyboColors.textPrimary(context))),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: KyboColors.surface(context),
                    shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
                    title: Text(
                      'Scambia giorni',
                      style: TextStyle(color: KyboColors.textPrimary(context)),
                    ),
                    content: Text(
                      'Vuoi scambiare i pasti di $currentDay con quelli di $day?\nLo scambio è permanente ma reversibile.',
                      style: TextStyle(color: KyboColors.textSecondary(context)),
                    ),
                    actions: [
                      PillButton(
                        label: 'Annulla',
                        onPressed: () => Navigator.pop(c),
                        backgroundColor: KyboColors.surface(context),
                        textColor: KyboColors.textPrimary(context),
                        height: 44,
                      ),
                      PillButton(
                        label: 'Scambia',
                        onPressed: () async {
                          Navigator.pop(c);
                          await provider.swapDays(currentDay, day, provider.selectedWeek);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$currentDay e $day scambiati!'),
                                backgroundColor: KyboColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
                              ),
                            );
                          }
                        },
                        backgroundColor: KyboColors.primary,
                        textColor: Colors.white,
                        height: 44,
                      ),
                    ],
                  ),
                );
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, DietProvider provider, user) {
    return Scaffold(
      key: _scaffoldKey,
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
                    title: 'Menu Laterale',
                    description:
                        'Tocca per aprire il menu e scoprire\ntutte le funzioni dell\'app.',
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
                  key: _swapDayKey,
                  title: 'Scambia Giorni',
                  description:
                      'Tocca per scambiare i pasti di questo giorno\ncon un altro. Permanente ma sempre reversibile.',
                  targetShapeBorder: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: 'Scambia giorno',
                    onPressed: () => _showDaySwapSheet(context, provider),
                  ),
                ),
                Showcase(
                  key: _tranquilKey,
                  title: 'Modalità Relax',
                  description:
                      'Tocca la foglia per nascondere le grammature\ndi frutta e verdura. Meno stress, stessa dieta.',
                  targetShapeBorder: const CircleBorder(),
                  child: Semantics(
                    label: "Modalità Relax",
                    selected: provider.isTranquilMode,
                    hint: "Nasconde le grammature di frutta e verdura per ridurre lo stress",
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
                  showcaseDesc: 'Monitora ciò che hai in frigorifero e in cucina.\nScansiona lo scontrino o aggiungi manualmente.',
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
                  showcaseDesc: 'Generata automaticamente dalla tua dieta.\nSpunta gli acquisti già effettuati.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, DietProvider provider, user) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      body: Row(
        children: [
          _buildTabletSidebar(context, provider, user),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: KyboColors.border(context),
          ),
          Expanded(
            child: Column(
              children: [
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

  /// Sidebar tablet: logo + NavigationRail + menu items del drawer.
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

            Expanded(
              child: _buildTabletDrawerItems(context, provider, user),
            ),
          ],
        ),
      ),
    );
  }

  /// Singolo item di navigazione nella sidebar tablet.
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

  /// Menu items secondari nella sidebar tablet (stesso contenuto del drawer mobile).
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
            if (hasNutritionist)
              Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  final unreadCount = chatProvider.unreadCount;
                  return _buildSidebarMenuItem(
                    context: context,
                    icon: Icons.chat_bubble,
                    label: chatProvider.nutritionistName,
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
              icon: Icons.auto_awesome,
              label: 'Suggerimenti AI',
              iconColor: KyboColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MealSuggestionsScreen()),
              ),
            ),
            _buildSidebarMenuItem(
              context: context,
              icon: Icons.card_giftcard_rounded,
              label: 'Shop Premi',
              iconColor: KyboColors.warning,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RewardsScreen()),
              ),
            ),
            _buildSidebarMenuItem(
              context: context,
              icon: Icons.fitness_center_rounded,
              label: 'Allenamento',
              iconColor: KyboColors.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkoutScreen()),
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
              ).then((_) => _checkTutorial()),
            ),
          ],
        );
      },
    );
  }

  /// Singolo item di menu nella sidebar tablet.
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

  /// AppBar per tablet: senza hamburger menu, con TabBar giorni.
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
          key: _swapDayKey,
          title: 'Scambia Giorni',
          description: 'Tocca per scambiare i pasti di questo giorno\ncon un altro. Permanente ma sempre reversibile.',
          targetShapeBorder: const CircleBorder(),
          child: IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Scambia giorno',
            onPressed: () => _showDaySwapSheet(context, provider),
          ),
        ),
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

  /// Restituisce (mealName, dayName) del prossimo pasto in base all'ora corrente, null se non trovato.
  (String, String)? _findNextMeal(DietProvider provider) {
    if (provider.dietPlan == null) return null;
    final weekPlan = provider.currentWeekPlan;
    if (weekPlan.isEmpty) return null;

    final days = provider.getDays();
    if (days.isEmpty) return null;

    const mealOrder = [
      'Colazione', 'Seconda Colazione', 'Pranzo', 'Merenda', 'Cena',
      'Spuntino', 'Spuntino Serale',
    ];

    const italianWeekdays = [
      'lunedì', 'martedì', 'mercoledì', 'giovedì',
      'venerdì', 'sabato', 'domenica',
    ];

    final now = DateTime.now();
    final todayName = italianWeekdays[now.weekday - 1];

    String? todayKey;
    for (final day in days) {
      if (day.toLowerCase() == todayName) {
        todayKey = day;
        break;
      }
    }
    if (todayKey == null) return null;

    final dayPlan = weekPlan[todayKey];
    if (dayPlan == null || dayPlan.isEmpty) return null;

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

    for (final mealKey in dayPlan.keys) {
      if (mealKey.toLowerCase().contains(nextMealName.toLowerCase()) ||
          nextMealName.toLowerCase().contains(mealKey.toLowerCase())) {
        final dishes = dayPlan[mealKey];
        if (dishes != null && dishes.isNotEmpty) {
          return (mealKey, todayKey);
        }
      }
    }

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
    final weekPlan = provider.currentWeekPlan;
    final dishes = weekPlan[_findNextMeal(provider)!.$2]?[mealName] ?? [];
    if (dishes.isEmpty) return const SizedBox.shrink();

    final preview = dishes.take(2).map((d) => d.name).join(', ');
    final more = dishes.length > 2 ? ' +${dishes.length - 2}' : '';

    return Container(
      color: KyboColors.background(context),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
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
      ),
    );
  }

  /// Row di pill-chip "Sett. 1 / Sett. 2 / ..." visibile solo per diete multi-settimana.
  Widget _buildWeekSelector(BuildContext context, DietProvider provider) {
    if (provider.weekCount <= 1) return const SizedBox.shrink();

    return Container(
      color: KyboColors.background(context),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Icon(Icons.calendar_view_week_rounded,
              size: 16, color: KyboColors.textMuted(context)),
          const SizedBox(width: 8),
          ...List.generate(provider.weekCount, (i) {
            final isSelected = provider.selectedWeek == i;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  provider.setWeek(i);
                  setState(() => _lastDaysCount = 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? KyboColors.primary
                        : KyboColors.surface(context),
                    borderRadius: KyboBorderRadius.large,
                    border: Border.all(
                      color: isSelected
                          ? KyboColors.primary
                          : KyboColors.border(context),
                    ),
                  ),
                  child: Text(
                    'Sett. ${i + 1}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : KyboColors.textSecondary(context),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
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
        if (_tabController == null || provider.getDays().isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: KyboColors.primary),
          );
        }
        return Column(
          children: [
            _buildWeekSelector(context, provider),
            _buildNextMealBanner(provider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: const StreakBadgeWidget(),
            ),
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
          dietPlan: provider.dietPlan,
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
        final userData =
            snapshot.data?.data() as Map<String, dynamic>?;
        final photoUrl = userData?['photo_url'] as String?;
        final firstName = userData?['first_name'] as String? ?? '';
        final lastName = userData?['last_name'] as String? ?? '';
        final displayName = '$firstName $lastName'.trim();
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
                    Showcase(
                      key: _drawerAvatarKey,
                      title: 'Foto profilo',
                      description: 'Tocca l\'avatar per caricare\nla tua foto profilo.',
                      child: GestureDetector(
                        onTap: user == null ? null : () => _pickAndUploadProfilePhoto(drawerCtx),
                        child: Stack(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              image: (photoUrl != null && photoUrl.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(photoUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: KyboColors.primary,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: KyboColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName.isNotEmpty ? displayName : "Kybo",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? "Ospite",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      bool hasNutritionist = false;
                      bool hasPT = false;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        hasNutritionist = ((data?['parent_id'] != null && (data?['parent_id'].toString().isNotEmpty ?? false)) ||
                                         (data?['created_by'] != null && (data?['created_by'].toString().isNotEmpty ?? false)) ||
                                         (data?['nutritionist_id'] != null && (data?['nutritionist_id'].toString().isNotEmpty ?? false)));
                        hasPT = (data?['pt_id'] != null && (data?['pt_id'].toString().isNotEmpty ?? false));
                      }

                      return Column(
                        children: [
                          if (hasNutritionist) ...[
                            Showcase(
                              key: _drawerChatKey,
                              title: 'Chat',
                              description: 'Scrivi al tuo nutrizionista\ne ricevi risposte in tempo reale.',
                              child: Consumer<ChatProvider>(
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
                                  title: chatProvider.nutritionistName,
                                  subtitle: unreadCount > 0
                                      ? "$unreadCount ${unreadCount == 1 ? 'messaggio' : 'messaggi'} non letto"
                                      : "Scrivi al tuo nutrizionista",
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
                            ),
                          ] else ...[
                            Showcase(
                              key: _drawerUploadKey,
                              title: 'Carica Dieta',
                              description: 'Importa la tua dieta in PDF.\nL\'AI la legge e la organizza per te.',
                              child: PillListTile(
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
                            ),
                          ],

                          Showcase(
                            key: _drawerSettingsKey,
                            title: 'Impostazioni',
                            description: 'Notifiche, dark mode,\nbudget della spesa e altro.',
                            child: PillListTile(
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
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              ).then((_) => _checkTutorial());
                            },
                          ),
                          ),

                          Showcase(
                            key: _drawerWorkoutKey,
                            title: 'Allenamento',
                            description: 'La tua scheda personalizzata\ncreata dal tuo PT.',
                            child: PillListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: KyboColors.accent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.fitness_center_rounded, color: KyboColors.accent, size: 20),
                            ),
                            title: "Allenamento",
                            subtitle: "La tua scheda e i tuoi esercizi",
                            onTap: () {
                              Navigator.pop(drawerCtx);
                              Navigator.push(
                                drawerCtx,
                                MaterialPageRoute(builder: (_) => const WorkoutScreen()),
                              );
                            },
                          ),
                          ),

                          Showcase(
                            key: _drawerBadgesKey,
                            title: 'Traguardi',
                            description: 'Badge e obiettivi da sbloccare\nseguendo la tua dieta.',
                            child: PillListTile(
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
                          ),

                          Showcase(
                            key: _drawerStatsKey,
                            title: 'Statistiche',
                            description: 'Monitora il tuo peso\ne i progressi nel tempo.',
                            child: PillListTile(
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
                          ),

                          Showcase(
                            key: _drawerSuggestionsKey,
                            title: 'Suggerimenti AI',
                            description: 'Ricevi idee pasto personalizzate\nbasate sulla tua dieta.',
                            child: PillListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: KyboColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_awesome, color: KyboColors.primary, size: 20),
                            ),
                            title: "Suggerimenti AI",
                            subtitle: "Idee pasti personalizzate",
                            onTap: () {
                              Navigator.pop(drawerCtx);
                              Navigator.push(
                                drawerCtx,
                                MaterialPageRoute(builder: (_) => const MealSuggestionsScreen()),
                              );
                            },
                          ),
                          ),

                          Showcase(
                            key: _drawerRewardsKey,
                            title: 'Shop Premi',
                            description: 'Riscatta gli XP per premi reali.\nAlcuni si completano online.',
                            child: PillListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: KyboColors.warning.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.card_giftcard_rounded, color: KyboColors.warning, size: 20),
                            ),
                            title: "Shop Premi",
                            subtitle: "Riscatta i tuoi XP",
                            onTap: () {
                              Navigator.pop(drawerCtx);
                              Navigator.push(
                                drawerCtx,
                                MaterialPageRoute(builder: (_) => const RewardsScreen()),
                              );
                            },
                          ),
                          ),

                          Showcase(
                            key: _drawerPdfKey,
                            title: 'Esporta PDF',
                            description: 'Scarica la dieta in PDF\nda condividere o stampare.',
                            child: PillListTile(
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
                          ),

                          Showcase(
                            key: _drawerHistoryKey,
                            title: 'Cronologia',
                            description: 'Rivedi tutte le diete precedenti\ncaricate nel tempo.',
                            child: PillListTile(
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
                          ),

                          if (!hasNutritionist || !hasPT)
                            Showcase(
                              key: _drawerMatchmakingKey,
                              title: 'Trova il tuo Coach',
                              description: 'Kybo ti aiuta a trovare\nun nutrizionista o PT.',
                              child: PillListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.handshake, color: Colors.indigo, size: 20),
                                ),
                                title: "Trova il tuo Coach",
                                subtitle: "Cerca Nutrizionista o PT",
                                onTap: () {
                                  Navigator.pop(drawerCtx);
                                  Navigator.push(
                                    drawerCtx,
                                    MaterialPageRoute(builder: (_) => const MatchmakingScreen()),
                                  );
                                },
                              ),
                            ),

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
                              if (!context.mounted) return;
                              // [SECURITY] Pulisce stato chat per evitare che
                              // dati del precedente utente restino in memoria.
                              context.read<ChatProvider>().clearChat();
                              await _auth.signOut();
                              if (!context.mounted) return;
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
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

  Future<void> _pickAndUploadProfilePhoto(BuildContext ctx) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();
      if (token == null) return;

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Caricamento foto...'), duration: Duration(seconds: 2)),
        );
      }

      final uri = Uri.parse('${Env.apiUrl}/profile/upload-photo');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';
      if (file.bytes != null) {
        req.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
      } else if (file.path != null) {
        req.files.add(await http.MultipartFile.fromPath('file', file.path!, filename: file.name));
      } else {
        return;
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (!ctx.mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Foto profilo aggiornata')),
        );
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento: ${resp.statusCode}'),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: KyboColors.error),
        );
      }
    }
  }

  Future<void> _uploadDiet(BuildContext context) async {
    final provider = Provider.of<DietProvider>(context, listen: false);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;

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

      await provider.uploadDiet(filePath);

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

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Generazione PDF in corso...'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      final response = await http.get(
        Uri.parse('${Env.apiUrl}/export-diet-pdf'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        await Share.shareXFiles(
          [XFile.fromData(response.bodyBytes, name: 'dieta-kybo.pdf', mimeType: 'application/pdf')],
          subject: 'Dieta Kybo',
        );
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Errore esportazione: ${response.statusCode}'),
            backgroundColor: KyboColors.error,
          ),
        );
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
}
