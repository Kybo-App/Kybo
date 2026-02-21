import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/env.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import 'repositories/diet_repository.dart';
import 'providers/diet_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/splash_screen.dart';
import 'guards/password_guard.dart';
import 'services/notification_service.dart';
import 'services/badge_service.dart';
import 'services/scale_service.dart';
import 'widgets/design_system.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Env
      await Env.init();

      // 2. Init Firebase
      try {
        final firebaseOptions = Env.isProd
            ? prod.DefaultFirebaseOptions.currentPlatform
            : dev.DefaultFirebaseOptions.currentPlatform;

        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: firebaseOptions);
        }

        // [IMPORTANTE] Abilita la persistenza offline di Firestore subito
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        debugPrint("⚠️ Firebase Init Error: $e");
      }

      // 3. Avvio UI Immediato
      runApp(
        MultiProvider(
          providers: [
            Provider(create: (_) => DietRepository()),
            ChangeNotifierProvider<BadgeService>(
              create: (_) => BadgeService(),
            ),
            ChangeNotifierProvider<DietProvider>(
              create: (context) => DietProvider(
                context.read<DietRepository>(),
                context.read<BadgeService>(),
              ),
            ),
            ChangeNotifierProvider<ScaleService>(
              create: (_) => ScaleService(),
            ),
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(),
            ),
            ChangeNotifierProvider<ChatProvider>(
              create: (_) => ChatProvider()..initializeChat(),
            ),
          ],
          child: const DietApp(),
        ),
      );

      // 4. Avvio Notifiche "Lazy" (Non blocca l'app)
      // Non aspettiamo il risultato, lo lasciamo andare in background
      Future.delayed(const Duration(seconds: 3), () {
        if (Firebase.apps.isNotEmpty) {
          NotificationService().init();
        }
      });
    },
    (error, stack) {
      debugPrint("🔴 Global Error: $error");
    },
  );
}

class DietApp extends StatelessWidget {
  const DietApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return MaterialApp(
      title: 'Kybo',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      // ═══════════════════════════════════════════════════════════════════════
      // LIGHT THEME - Colori identici a Kybo Admin
      // ═══════════════════════════════════════════════════════════════════════
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: KyboColors.backgroundLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: KyboColors.primary,
          brightness: Brightness.light,
          primary: KyboColors.primary,
          secondary: KyboColors.accent,
          surface: KyboColors.surfaceLight,
          onSurface: KyboColors.textPrimaryLight,
        ),
        cardColor: KyboColors.surfaceLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: KyboColors.surfaceLight,
          foregroundColor: KyboColors.textPrimaryLight,
          elevation: 0,
          surfaceTintColor: KyboColors.surfaceLight,
        ),
        listTileTheme: const ListTileThemeData(
          textColor: KyboColors.textPrimaryLight,
          iconColor: KyboColors.textSecondaryLight,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return KyboColors.primary;
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return KyboColors.primary.withValues(alpha: 0.5);
            }
            return Colors.grey.withValues(alpha: 0.3);
          }),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: KyboColors.textPrimaryLight),
          bodyMedium: TextStyle(color: KyboColors.textPrimaryLight),
          bodySmall: TextStyle(color: KyboColors.textSecondaryLight),
          titleLarge: TextStyle(color: KyboColors.textPrimaryLight),
          titleMedium: TextStyle(color: KyboColors.textPrimaryLight),
          titleSmall: TextStyle(color: KyboColors.textSecondaryLight),
        ),
        iconTheme: const IconThemeData(color: KyboColors.textSecondaryLight),
        dividerColor: KyboColors.textMutedLight,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: KyboColors.surfaceLight,
          labelStyle: const TextStyle(color: KyboColors.textSecondaryLight),
          hintStyle: const TextStyle(color: KyboColors.textMutedLight),
          enabledBorder: OutlineInputBorder(
            borderRadius: KyboBorderRadius.medium,
            borderSide: BorderSide(
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: KyboBorderRadius.medium,
            borderSide: const BorderSide(color: KyboColors.primary, width: 2),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: KyboColors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          titleTextStyle: const TextStyle(
            color: KyboColors.textPrimaryLight,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: const TextStyle(color: KyboColors.textSecondaryLight),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: KyboColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
      ),
      // ═══════════════════════════════════════════════════════════════════════
      // DARK THEME - Colori identici a Kybo Admin
      // ═══════════════════════════════════════════════════════════════════════
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: KyboColors.backgroundDark,
        colorScheme: const ColorScheme.dark(
          primary: KyboColors.primary,
          secondary: KyboColors.accent,
          surface: KyboColors.surfaceDark,
          onSurface: KyboColors.textPrimaryDark,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        cardColor: KyboColors.surfaceElevatedDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: KyboColors.surfaceDark,
          foregroundColor: KyboColors.textPrimaryDark,
          elevation: 0,
          surfaceTintColor: KyboColors.surfaceDark,
        ),
        listTileTheme: const ListTileThemeData(
          textColor: KyboColors.textPrimaryDark,
          iconColor: KyboColors.textSecondaryDark,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return KyboColors.primary;
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return KyboColors.primary.withValues(alpha: 0.5);
            }
            return Colors.grey.withValues(alpha: 0.3);
          }),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: KyboColors.textPrimaryDark),
          bodyMedium: TextStyle(color: KyboColors.textPrimaryDark),
          bodySmall: TextStyle(color: KyboColors.textSecondaryDark),
          titleLarge: TextStyle(color: KyboColors.textPrimaryDark),
          titleMedium: TextStyle(color: KyboColors.textPrimaryDark),
          titleSmall: TextStyle(color: KyboColors.textSecondaryDark),
        ),
        iconTheme: const IconThemeData(color: KyboColors.textSecondaryDark),
        dividerColor: Colors.white.withValues(alpha: 0.1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: KyboColors.surfaceDark,
          labelStyle: const TextStyle(color: KyboColors.textSecondaryDark),
          hintStyle: const TextStyle(color: KyboColors.textMutedDark),
          enabledBorder: OutlineInputBorder(
            borderRadius: KyboBorderRadius.medium,
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: KyboBorderRadius.medium,
            borderSide: const BorderSide(color: KyboColors.primary, width: 2),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: KyboColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          titleTextStyle: const TextStyle(
            color: KyboColors.textPrimaryDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: const TextStyle(color: KyboColors.textSecondaryDark),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: KyboColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
      ),
      // Qui usiamo il MaintenanceGuard basato su Firestore
      builder: (context, child) {
        return MaintenanceGuard(child: PasswordGuard(child: child!));
      },
      home: const SplashScreen(),
    );
  }
}

// -------------------------------------------------------
// 🛡️ MAINTENANCE GUARD (SOLO FIRESTORE)
// -------------------------------------------------------
class MaintenanceGuard extends StatelessWidget {
  final Widget child;
  const MaintenanceGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) return child;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('global')
          .snapshots(),
      builder: (context, snapshot) {
        // Se siamo offline, Firestore proverà a usare la cache.
        // Se non ha cache o c'è errore, snapshot.hasError potrebbe essere true o connectionState waiting.
        // IN OGNI CASO DI DUBBIO -> Lasciamo passare l'utente (Fail Open)

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          // Non blocchiamo l'utente se non riusciamo a leggere la config
          return child;
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        bool isMaintenance = data?['maintenance_mode'] ?? false;

        if (isMaintenance) {
          return Scaffold(
            backgroundColor: KyboColors.background(context),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: KyboColors.warning.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.build_circle,
                      size: 56,
                      color: KyboColors.warning,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Manutenzione",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: KyboColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      data?['maintenance_message'] ??
                          "Sistema in aggiornamento.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KyboColors.textSecondary(context),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
