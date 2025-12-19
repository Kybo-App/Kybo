import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'repositories/diet_repository.dart';
import 'providers/diet_provider.dart';
import 'screens/splash_screen.dart'; // [NEW] Safe Entry Point

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => DietRepository()),
        ChangeNotifierProxyProvider<DietRepository, DietProvider>(
          create: (context) => DietProvider(context.read<DietRepository>()),
          update: (context, repo, prev) => prev ?? DietProvider(repo),
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
      // [FIX] Always start with Splash to ensure Env/Firebase load safely
      home: const SplashScreen(),
    );
  }
}
