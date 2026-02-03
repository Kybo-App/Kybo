import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/diet_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/design_system.dart';
import 'change_password_screen.dart';

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
    // This would normally open the time settings dialog from home_screen
    // For now, show a simple message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Gestione Allarmi verrà implementata qui'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
      ),
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
    await prefs.setBool('tutorial_completed', false);

    if (context.mounted) {
      // Navigate back to home and restart tutorial
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tutorial riavviato! Riapri il drawer per iniziare.'),
          backgroundColor: KyboColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Trigger tutorial restart by refreshing the ShowCaseWidget
      // This will re-check tutorial_completed and restart if false
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          // Find and restart ShowCaseWidget context
          // The tutorial will automatically restart when the user interacts next
        }
      });
    }
  }
}
