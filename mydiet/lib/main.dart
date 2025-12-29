import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'constants.dart';
import 'repositories/diet_repository.dart';
import 'providers/diet_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => DietRepository()),
        ChangeNotifierProvider<DietProvider>(
          create: (context) => DietProvider(context.read<DietRepository>()),
        ),
      ],
      child: const DietApp(),
    ),
  );
}

class DietApp extends StatelessWidget {
  const DietApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyDiet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: AppColors.surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      // [CORRETTO] Il builder avvolge ogni singola rotta dell'app col Guard
      builder: (context, child) {
        return MaintenanceGuard(child: child!);
      },
      // [CORRETTO] Rimosso il Guard da qui, ci pensa il builder sopra
      home: const SplashScreen(),
    );
  }
}

// -------------------------------------------------------
// 🛡️ MAINTENANCE GUARD WIDGET
// -------------------------------------------------------
class MaintenanceGuard extends StatelessWidget {
  final Widget child;

  const MaintenanceGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('global')
          .snapshots(),
      builder: (context, snapshot) {
        // Gestione stati di caricamento/errore silenziosi
        if (snapshot.hasError) {
          print("🔴 Maintenance Error: ${snapshot.error}");
          return child;
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Se il documento non esiste, assumiamo che non ci sia manutenzione
          return child;
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        bool isMaintenance = data?['maintenance_mode'] ?? false;

        if (isMaintenance) {
          // [CORRETTO] Restituiamo Scaffold, NON un'altra MaterialApp
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 80,
                      color: Colors.orange,
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Under Maintenance",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "We are updating the system. Please wait.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
