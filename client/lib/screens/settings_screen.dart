// Schermata impostazioni: password, allarmi pasti, budget spesa, dark mode, privacy, tutorial,
// preferenze supermercato, timer cottura.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/diet_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/design_system.dart';
import 'change_password_screen.dart';
import 'cooking_timer_screen.dart';
import '../widgets/meal_reminder_dialog.dart';

const _kSupermarketPrefKey = 'preferred_supermarket';
const _supermarkets = [
  'Esselunga',
  'Conad',
  'Carrefour',
  'Lidl',
  'Eurospin',
  'Coop',
  'Pam',
  'MD Discount',
  "IN'S Mercato",
  'Aldi',
  'Penny Market',
  'Tigros',
  'Iper',
  'Ipercoop',
  'Altro',
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _preferredSupermarket;

  @override
  void initState() {
    super.initState();
    _loadSupermarketPref();
  }

  Future<void> _loadSupermarketPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _preferredSupermarket = prefs.getString(_kSupermarketPrefKey);
      });
    }
  }

  Future<void> _saveSupermarketPref(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_kSupermarketPrefKey);
    } else {
      await prefs.setString(_kSupermarketPrefKey, value);
    }
    if (mounted) setState(() => _preferredSupermarket = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        backgroundColor: KyboColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: KyboColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Impostazioni',
          style: TextStyle(
            color: KyboColors.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PillCard(
            child: PillListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KyboColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, color: KyboColors.primary, size: 20),
              ),
              title: "Cambia Password",
              subtitle: "Aggiorna la tua password di accesso",
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                );
              },
            ),
          ),


          PillCard(
            child: PillListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KyboColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active, color: KyboColors.success, size: 20),
              ),
              title: "Gestisci Allarmi",
              subtitle: "Configura promemoria pasti",
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openTimeSettings(context),
            ),
          ),

          const SizedBox(height: 12),

          Consumer<DietProvider>(
            builder: (context, dietProvider, _) {
              final budget = dietProvider.weeklyBudget;
              final estimatedCost = dietProvider.estimatedShoppingCost;
              return PillCard(
                child: PillListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: KyboColors.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.euro_rounded,
                        color: KyboColors.accent, size: 20),
                  ),
                  title: "Budget Spesa Settimanale",
                  subtitle: budget != null
                      ? "€${budget.toStringAsFixed(0)} · spesa stimata: €${estimatedCost.toStringAsFixed(2).replaceAll('.', ',')}"
                      : "Nessun budget impostato",
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showBudgetDialog(context, dietProvider),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // --- Supermercato preferito ---
          PillCard(
            child: PillListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store_rounded, color: Colors.orange, size: 20),
              ),
              title: "Supermercato Preferito",
              subtitle: _preferredSupermarket ?? "Nessuna preferenza impostata",
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSupermarketDialog(context),
            ),
          ),

          const SizedBox(height: 12),

          // --- Timer cottura ---
          PillCard(
            child: PillListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_rounded, color: Colors.deepOrange, size: 20),
              ),
              title: "Timer Cottura",
              subtitle: "Countdown per i tuoi piatti",
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CookingTimerScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => PillCard(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (themeProvider.isDarkMode ? Colors.amber : Colors.blueGrey)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: themeProvider.isDarkMode ? Colors.amber : Colors.blueGrey,
                    size: 20,
                  ),
                ),
                title: Text(
                  "Modalità Scura",
                  style: TextStyle(
                    color: KyboColors.textPrimary(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  themeProvider.isDarkMode ? "Attiva" : "Disattivata",
                  style: TextStyle(
                    color: KyboColors.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
                value: themeProvider.isDarkMode,
                onChanged: (val) => themeProvider.toggleTheme(),
                activeThumbColor: KyboColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          PillCard(
            child: PillListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.privacy_tip, color: Colors.blueGrey, size: 20),
              ),
              title: "Privacy Policy",
              subtitle: "Informativa sulla privacy",
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPrivacyDialog(context),
            ),
          ),

          const SizedBox(height: 12),

          PillCard(
            child: PillListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.replay_circle_filled, color: Colors.green, size: 20),
              ),
              title: "Riavvia Tutorial",
              subtitle: "Mostra nuovamente le guide",
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _resetTutorial(context),
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'Kybo v1.0.0',
              style: TextStyle(
                color: KyboColors.textMuted(context),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupermarketDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_rounded, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Supermercato Preferito',
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleziona il supermercato dove fai la spesa più spesso.',
                style: TextStyle(
                  color: KyboColors.textSecondary(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  // [FIX M-5] Migrato da RadioListTile(groupValue/onChanged)
                  // deprecati in Flutter 3.32 → RadioGroup ancestor pattern.
                  child: RadioGroup<String?>(
                    groupValue: _preferredSupermarket,
                    onChanged: (v) {
                      _saveSupermarketPref(v);
                      Navigator.pop(ctx);
                    },
                    child: Column(
                      children: [
                        // Opzione "Nessuna preferenza"
                        RadioListTile<String?>(
                          value: null,
                          title: Text(
                            'Nessuna preferenza',
                            style: TextStyle(
                              color: KyboColors.textSecondary(context),
                              fontSize: 14,
                            ),
                          ),
                          activeColor: KyboColors.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        ..._supermarkets.map((name) => RadioListTile<String?>(
                          value: name,
                          title: Text(
                            name,
                            style: TextStyle(
                              color: KyboColors.textPrimary(context),
                              fontSize: 14,
                            ),
                          ),
                          activeColor: KyboColors.primary,
                          contentPadding: EdgeInsets.zero,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          PillButton(
            label: 'Chiudi',
            onPressed: () => Navigator.pop(ctx),
            backgroundColor: KyboColors.surface(context),
            textColor: KyboColors.textPrimary(context),
            height: 40,
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, DietProvider provider) {
    final controller = TextEditingController(
      text: provider.weeklyBudget != null
          ? provider.weeklyBudget!.toStringAsFixed(0)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KyboColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.euro_rounded,
                  color: KyboColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Budget Spesa',
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Imposta un budget settimanale per la spesa.\n'
              'Kybo ti avviserà quando la lista stimata si avvicina al limite.',
              style: TextStyle(
                color: KyboColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: KyboColors.textMuted(context)),
                prefixText: '€ ',
                prefixStyle: TextStyle(
                  color: KyboColors.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                border: OutlineInputBorder(
                  borderRadius: KyboBorderRadius.medium,
                  borderSide: BorderSide(color: KyboColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: KyboBorderRadius.medium,
                  borderSide:
                      const BorderSide(color: KyboColors.accent, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (provider.weeklyBudget != null)
            TextButton(
              onPressed: () {
                provider.setWeeklyBudget(null);
                Navigator.pop(ctx);
              },
              child:
                  Text('Rimuovi', style: TextStyle(color: KyboColors.error)),
            ),
          PillButton(
            label: 'Annulla',
            onPressed: () => Navigator.pop(ctx),
            backgroundColor: KyboColors.surface(context),
            textColor: KyboColors.textPrimary(context),
            height: 40,
          ),
          PillButton(
            label: 'Salva',
            onPressed: () {
              final val = double.tryParse(
                  controller.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                provider.setWeeklyBudget(val);
              }
              Navigator.pop(ctx);
            },
            backgroundColor: KyboColors.accent,
            textColor: Colors.white,
            height: 40,
          ),
        ],
      ),
    );
  }

  void _openTimeSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const MealReminderDialog(),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
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
            "Kybo rispetta la tua privacy e protegge i tuoi dati personali.\n\n"
            "I tuoi dati sono crittografati end-to-end e vengono utilizzati esclusivamente per fornire i servizi dell'app.\n\n"
            "Per maggiori informazioni, visita il nostro sito web.",
            style: TextStyle(color: KyboColors.textSecondary(context)),
          ),
        ),
        actions: [
          PillButton(
            label: "OK",
            onPressed: () => Navigator.pop(ctx),
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );
  }

  void _resetTutorial(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_tutorial_v11', false);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
