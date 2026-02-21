import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/diet_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/design_system.dart';
import 'change_password_screen.dart';
import '../widgets/meal_reminder_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          // Change Password
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


          // Manage Alarms
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

          // Budget Spesa Settimanale
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

          // Dark Mode Toggle
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
                activeColor: Colors.amber,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Privacy Policy
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

          // Reset Tutorial
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

          // App Info
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

      if (context.mounted) {
        await provider.uploadDiet(filePath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dieta caricata con successo!'),
            backgroundColor: KyboColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento: $e'),
            backgroundColor: KyboColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          ),
        );
      }
    }
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
    await prefs.setBool('seen_tutorial_v10', false);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
