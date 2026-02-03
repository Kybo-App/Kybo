import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../core/error_handler.dart';
import '../widgets/diet_logo.dart';
import '../widgets/design_system.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? inviteCode;
  final bool isIndependent;

  const LoginScreen({
    super.key,
    this.inviteCode,
    this.isIndependent = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null || widget.isIndependent) {
      _isLogin = false; // Switch to register automatically
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.toUserMessage(e)),
            backgroundColor: KyboColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    try {
      if (email.isEmpty || pass.isEmpty) {
        throw const FormatException("Inserisci email e password.");
      }

      if (_isLogin) {
        await _auth.signIn(email, pass);
      } else {
        await _auth.signUp(
          email, 
          pass,
          role: widget.inviteCode != null ? 'client' : 'independent',
          additionalData: widget.inviteCode != null ? {'invite_code': widget.inviteCode} : null,
        );
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.toUserMessage(e)),
            backgroundColor: KyboColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPrivacyDialog() {
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
            "Informativa sulla Privacy\n\n"
            "I tuoi dati vengono utilizzati per fornire il servizio. "
            "Continuando accetti il trattamento dei dati personali secondo le normative vigenti.",
            style: TextStyle(
              fontSize: 14,
              color: KyboColors.textSecondary(context),
            ),
          ),
        ),
        actions: [
          PillButton(
            label: "Ok",
            onPressed: () => Navigator.pop(ctx),
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  const DietLogo(size: 100),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    _isLogin ? "Bentornato!" : "Crea Account",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: KyboColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin 
                        ? "Accedi al tuo account Kybo"
                        : "Inizia il tuo percorso nutrizionale",
                    style: TextStyle(
                      fontSize: 15,
                      color: KyboColors.textSecondary(context),
                    ),
                  ),
                  if (widget.inviteCode != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: KyboColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: KyboColors.success),
                      ),
                      child: Text(
                        "Codice Invito applicato: ${widget.inviteCode}",
                        style: const TextStyle(
                          color: KyboColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),

                  // Email Field
                  PillTextField(
                    controller: _emailCtrl,
                    labelText: "Email",
                    hintText: "nome@esempio.com",
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  PillTextField(
                    controller: _passCtrl,
                    labelText: "Password",
                    hintText: "Inserisci la tua password",
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    showPasswordToggle: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 32),

                  // Login/Register Button
                  PillButton(
                    label: _isLogin ? "ACCEDI" : "REGISTRATI",
                    onPressed: _submit,
                    isLoading: _isLoading,
                    backgroundColor: KyboColors.primary,
                    textColor: Colors.white,
                    height: 56,
                    expanded: true,
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: KyboColors.border(context),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "oppure",
                          style: TextStyle(
                            color: KyboColors.textMuted(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: KyboColors.border(context),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Login Button
                  PillButton(
                    label: "Accedi con Google",
                    icon: Icons.g_mobiledata,
                    onPressed: _isLoading ? null : _googleLogin,
                    backgroundColor: KyboColors.surface(context),
                    textColor: KyboColors.textPrimary(context),
                    height: 56,
                    expanded: true,
                  ),
                  const SizedBox(height: 24),

                  // Toggle Login/Register
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Non hai un account? Registrati"
                          : "Hai già un account? Accedi",
                      style: TextStyle(
                        color: KyboColors.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Privacy Disclaimer
                  GestureDetector(
                    onTap: _showPrivacyDialog,
                    child: Text(
                      "Continuando, accetti la Privacy Policy e i Termini di Servizio",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KyboColors.textMuted(context),
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
