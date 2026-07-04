// Schermata login/registrazione con supporto codice invito, Google Sign-In e privacy dialog.
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../core/error_handler.dart';
import '../widgets/diet_logo.dart';
import '../widgets/design_system.dart';
import '../widgets/password_checklist.dart';
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

  bool _isValidEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  bool get _emailValid => _isValidEmail(_emailCtrl.text.trim());

  /// Mostra l'errore inline solo se l'utente ha già scritto qualcosa (ep6.2:
  /// validazione inline, ma senza urlare su un campo ancora vuoto).
  bool get _emailError => _emailCtrl.text.trim().isNotEmpty && !_emailValid;

  /// Submit abilitato-finché-valido (ep6.1). In login basta email valida +
  /// password non vuota (gli utenti storici possono avere password vecchie).
  /// In registrazione la password deve rispettare la policy.
  bool get _canSubmit {
    if (!_emailValid) return false;
    return _isLogin
        ? _passCtrl.text.isNotEmpty
        : KyboPasswordChecklist.isValid(_passCtrl.text);
  }

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null || widget.isIndependent) {
      _isLogin = false;
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
          // [SECURITY FIX F1] 'client' non è mai stato ammesso dalla create
          // rule (solo ['independent', 'user']) né dal server: la scrittura
          // veniva negata e ingoiata, lasciando l'account senza profilo.
          // 'user' è la convenzione usata da rules e server per un cliente
          // registrato con invito.
          role: widget.inviteCode != null ? 'user' : 'independent',
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
            // [FIX F4] Testo segnaposto ("secondo le normative vigenti") senza
            // policy reale né link ai documenti — rischio legale per un'app di
            // salute in UE. Allineato al testo corretto usato in
            // settings_screen.dart (stessa correzione ST2: niente più
            // dichiarazioni di cifratura E2E inesistente).
            "Kybo rispetta la tua privacy e protegge i tuoi dati personali secondo il GDPR.\n\n"
            "Raccogliamo email, dati del profilo e, se li inserisci, dati su dieta/peso/obiettivi, per fornirti il servizio e permettere al tuo nutrizionista/personal trainer di seguirti.\n\n"
            "I tuoi dati sono protetti dalle regole di accesso di Firestore e dalla cifratura a riposo di Google Cloud. Solo tu, il professionista che ti segue e gli amministratori autorizzati possono accedervi.\n\n"
            "Puoi richiedere l'esportazione o la cancellazione dei tuoi dati in qualsiasi momento dalle Impostazioni dell'app, dopo l'accesso.",
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

  /// [FIX F3] Nessun flusso di recupero password esisteva nell'app.
  void _showForgotPasswordDialog(BuildContext context) {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool isSending = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canSend = _isValidEmail(resetEmailCtrl.text.trim()) && !isSending;
          return AlertDialog(
            backgroundColor: KyboColors.surface(context),
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
            title: Text(
              "Recupera Password",
              style: TextStyle(color: KyboColors.textPrimary(context)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Inserisci la tua email: ti invieremo un link per reimpostare la password.",
                  style: TextStyle(color: KyboColors.textSecondary(context), fontSize: 13),
                ),
                const SizedBox(height: 16),
                PillTextField(
                  controller: resetEmailCtrl,
                  labelText: "Email",
                  hintText: "nome@esempio.com",
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              PillButton(
                label: "Annulla",
                onPressed: isSending ? null : () => Navigator.pop(ctx),
                backgroundColor: KyboColors.surface(context),
                textColor: KyboColors.textPrimary(context),
                height: 44,
              ),
              PillButton(
                label: "Invia",
                isLoading: isSending,
                onPressed: !canSend
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSending = true);
                        try {
                          await _auth.sendPasswordReset(resetEmailCtrl.text.trim());
                          if (ctx.mounted) Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(content: Text("Email inviata! Controlla la tua casella di posta.")),
                          );
                        } catch (e) {
                          setDialogState(() => isSending = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(ErrorMapper.toUserMessage(e)), backgroundColor: KyboColors.error),
                            );
                          }
                        }
                      },
                backgroundColor: KyboColors.primary,
                textColor: Colors.white,
                height: 44,
              ),
            ],
          );
        },
      ),
    ).then((_) => resetEmailCtrl.dispose());
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
                  const DietLogo(size: 100),
                  const SizedBox(height: 24),

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

                  PillTextField(
                    controller: _emailCtrl,
                    labelText: "Email",
                    hintText: "nome@esempio.com",
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                  // Errore email inline (ep6.2).
                  if (_emailError) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 15, color: KyboColors.error),
                          const SizedBox(width: 6),
                          Text(
                            "Inserisci un'email valida",
                            style: TextStyle(
                                color: KyboColors.error, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  PillTextField(
                    controller: _passCtrl,
                    labelText: "Password",
                    hintText: "Inserisci la tua password",
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    showPasswordToggle: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _canSubmit ? _submit() : null,
                  ),
                  // In registrazione: requisiti password live (ep6.5).
                  if (!_isLogin) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: KyboPasswordChecklist(password: _passCtrl.text),
                    ),
                  ],
                  // [FIX F3] "Password dimenticata?" mancava del tutto.
                  if (_isLogin) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : () => _showForgotPasswordDialog(context),
                        child: Text(
                          "Password dimenticata?",
                          style: TextStyle(color: KyboColors.primary, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  PillButton(
                    label: _isLogin ? "ACCEDI" : "REGISTRATI",
                    onPressed: (_isLoading || !_canSubmit) ? null : _submit,
                    isLoading: _isLoading,
                    backgroundColor:
                        _canSubmit ? KyboColors.primary : KyboColors.border(context),
                    textColor:
                        _canSubmit ? Colors.white : KyboColors.textMuted(context),
                    height: 56,
                    expanded: true,
                  ),
                  const SizedBox(height: 16),

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
