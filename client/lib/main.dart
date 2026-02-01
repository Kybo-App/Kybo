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
import 'screens/splash_screen.dart';
import 'guards/password_guard.dart';
import 'services/notification_service.dart';
import 'constants.dart';

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
            ChangeNotifierProvider<DietProvider>(
              create: (context) => DietProvider(context.read<DietRepository>()),
            ),
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(),
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkScaffoldBackground,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.darkSurface,
          onSurface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
        ),
        cardColor: AppColors.darkCardColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: Colors.white,
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white70,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary.withValues(alpha: 0.5);
            return Colors.grey.withValues(alpha: 0.3);
          }),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
          titleSmall: TextStyle(color: Colors.white70),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        dividerColor: Colors.white24,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkInputBackground,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.grey[600]),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: AppColors.darkSurface,
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Colors.white70),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkSurface,
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
            backgroundColor: AppColors.getScaffoldBackground(context),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.build_circle,
                    size: 80,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Manutenzione",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      data?['maintenance_message'] ??
                          "Sistema in aggiornamento.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.getSecondaryTextColor(context)),
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
