// Entrypoint dell'app Kybo: inizializza Firebase, providers e MaterialApp con tema chiaro/scuro.
// MaintenanceGuard — legge config/global da Firestore e mostra schermata di manutenzione se attiva.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/env.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import 'repositories/diet_repository.dart';
import 'providers/diet_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/matchmaking_provider.dart';
import 'screens/splash_screen.dart';
import 'guards/password_guard.dart';
import 'services/notification_service.dart';
import 'services/badge_service.dart';
import 'services/xp_service.dart';
import 'services/challenge_service.dart';
import 'services/scale_service.dart';
import 'utils/time_helper.dart';
import 'widgets/design_system.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Inizializza i dati di locale per package:intl. Senza questa chiamata
      // DateFormat('dd MMM', 'it') (e simili) solleva un LocaleDataException
      // e il widget che la usa mostra il banner rosso di errore (es. la
      // sezione "Sfide" dentro Traguardi).
      await initializeDateFormatting('it', null);

      await Env.init();

      try {
        final firebaseOptions = Env.isProd
            ? prod.DefaultFirebaseOptions.currentPlatform
            : dev.DefaultFirebaseOptions.currentPlatform;

        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: firebaseOptions);
        }

        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        debugPrint("Firebase Init Error: $e");
      }

      await TimeHelper().init();

      runApp(
        MultiProvider(
          providers: [
            Provider(create: (_) => DietRepository()),
            ChangeNotifierProvider<XpService>(
              create: (_) => XpService(),
            ),
            ChangeNotifierProvider<BadgeService>(
              create: (_) => BadgeService(),
            ),
            ChangeNotifierProvider<ChallengeService>(
              create: (context) => ChallengeService(
                context.read<XpService>(),
              ),
            ),
            ChangeNotifierProvider<DietProvider>(
              create: (context) => DietProvider(
                context.read<DietRepository>(),
                context.read<BadgeService>(),
                context.read<XpService>(),
                context.read<ChallengeService>(),
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
            ChangeNotifierProvider<WorkoutProvider>(
              create: (_) => WorkoutProvider(),
            ),
            ChangeNotifierProvider<MatchmakingProvider>(
              create: (_) => MatchmakingProvider(),
            ),
          ],
          child: const DietApp(),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (Firebase.apps.isNotEmpty) {
          NotificationService().init();
        }
      });
    },
    (error, stack) {
      debugPrint("Global Error: $error");
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
      builder: (context, child) {
        return MaintenanceGuard(child: PasswordGuard(child: child!));
      },
      home: const SplashScreen(),
    );
  }
}

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
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
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
