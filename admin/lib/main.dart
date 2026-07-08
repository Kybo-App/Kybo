// Entry point dell'app admin Kybo. Inizializza Firebase, LanguageProvider e
// gestisce il flusso auth: LoginScreen → AdminPasswordGuard → TwoFactorGuard → RoleCheckScreen.
import 'package:kybo_admin/guards/admin_password_guard.dart';
import 'package:kybo_admin/guards/email_verification_guard.dart';
import 'package:kybo_admin/guards/two_factor_guard.dart';
import 'package:kybo_admin/screens/dashboard_screen.dart';
import 'package:kybo_admin/widgets/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/env.dart';
import 'core/app_localizations.dart';
import 'providers/language_provider.dart';
import 'providers/user_provider.dart';

import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.init();

  // [THEME] Primo avvio: tema del sistema (prefers-color-scheme). Dopo la
  // prima scelta col toggle nella top bar la preferenza persistita vince.
  await KyboThemeProvider().init();

  final firebaseOptions = Env.isProd
      ? prod.DefaultFirebaseOptions.currentPlatform
      : dev.DefaultFirebaseOptions.currentPlatform;

  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const AdminApp());
}

/// ScrollBehavior per web desktop: abilita drag con mouse/trackpad/touch e
/// mostra sempre una Scrollbar visibile e trascinabile.
class _AdminScrollBehavior extends MaterialScrollBehavior {
  const _AdminScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      child: child,
    );
  }
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: LanguageProvider()),
        // [COERENZA] Profilo/ruolo condiviso: una lettura Firestore per login
        // invece di una copia locale per ogni view (vedi user_provider.dart).
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, _) => _buildMaterialApp(langProvider.locale),
      ),
    );
  }

  Widget _buildMaterialApp(Locale locale) {
    // [THEME] ThemeData dinamico agganciato a KyboThemeProvider: i default
    // Material (Card, Dropdown menu, testi senza stile, Dialog, ecc.) seguono
    // il dark mode. Prima il ThemeData era fisso chiaro e ogni widget che
    // ereditava i default restava bianco/scuro sbagliato col tema scuro.
    return ListenableBuilder(
      listenable: KyboThemeProvider(),
      builder: (context, _) {
        final isDark = KyboColors.isDark;
        return MaterialApp(
          title: 'Kybo Admin',
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [Locale('it'), Locale('en')],
          scrollBehavior: const _AdminScrollBehavior(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: KyboColors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D32),
              brightness: isDark ? Brightness.dark : Brightness.light,
              primary: const Color(0xFF2E7D32),
              secondary: const Color(0xFFE65100),
              surface: KyboColors.surface,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: KyboColors.surface,
              surfaceTintColor: KyboColors.surface,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: KyboColors.surface,
              surfaceTintColor: KyboColors.surface,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF2E7D32)),
              titleTextStyle: const TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Look uniforme per TUTTE le snackbar (prima ogni chiamata
            // inline aveva forma/posizione diverse). I colori semantici
            // error/success restano per-chiamata via backgroundColor.
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: KyboColors.surfaceElevated,
              contentTextStyle: TextStyle(color: KyboColors.textPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              // filled: false — il fill del tema è RETTANGOLARE (con
              // InputBorder.none non segue il raggio) e sporgeva con angoli
              // squadrati sopra i campi pill-shaped (es. ricerca utenti).
              // Chi vuole il fill lo dichiara esplicito nel widget.
              filled: false,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: KyboColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: KyboColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
              ),
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        // Ordine: verifica email → cambio password → 2FA → controllo ruolo.
        // La verifica dell'identità email precede tutto il resto.
        return EmailVerificationGuard(
          child: AdminPasswordGuard(
            child: TwoFactorGuard(child: const RoleCheckScreen()),
          ),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _canLogin =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailCtrl.text.trim()) &&
      _passCtrl.text.isNotEmpty;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${t.loginError}$e"),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: KyboColors.background,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: KyboColors.surface,
            borderRadius: KyboBorderRadius.large,
            boxShadow: KyboColors.mediumShadow,
            border: Border.all(color: KyboColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                      Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: KyboColors.primary.withValues(alpha: 0.1),
                  borderRadius: KyboBorderRadius.large,
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 44,
                  color: KyboColors.primary,
                ),
              ),
              const SizedBox(height: 28),

              Text(
                "Kybo Admin",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: KyboColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.loginReserved,
                style: TextStyle(color: KyboColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 36),

              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: KyboColors.background,
                  borderRadius: KyboBorderRadius.pill,
                  border: Border.all(color: KyboColors.border),
                ),
                child: TextField(
                  controller: _emailCtrl,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: KyboColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: t.email,
                    hintStyle: TextStyle(color: KyboColors.textMuted),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: KyboColors.textMuted,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: KyboColors.background,
                  borderRadius: KyboBorderRadius.pill,
                  border: Border.all(color: KyboColors.border),
                ),
                child: TextField(
                  controller: _passCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _canLogin ? _login() : null,
                  style: TextStyle(color: KyboColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: t.password,
                    hintStyle: TextStyle(color: KyboColors.textMuted),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: KyboColors.textMuted,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: KyboColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: t.loginButton,
                  icon: Icons.login_rounded,
                  // Grigio finché email valida + password non vuota.
                  backgroundColor:
                      _canLogin ? KyboColors.primary : KyboColors.border,
                  textColor: _canLogin ? Colors.white : KyboColors.textMuted,
                  height: 52,
                  isLoading: _isLoading,
                  onPressed: (_isLoading || !_canLogin) ? null : _login,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleCheckScreen extends StatefulWidget {
  const RoleCheckScreen({super.key});
  @override
  State<RoleCheckScreen> createState() => _RoleCheckScreenState();
}

class _RoleCheckScreenState extends State<RoleCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // [COERENZA] Ruolo dal UserProvider condiviso (fail-closed: se la
      // lettura fallisce il ruolo resta vuoto → accesso negato).
      final userProv = context.read<UserProvider>();
      await userProv.ensureLoaded();

      if (userProv.isProfessional) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          final t = AppLocalizations.of(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(t.webAccessDeniedTitle),
              content: Text(t.webAccessDeniedBody),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Text(t.goBack),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
