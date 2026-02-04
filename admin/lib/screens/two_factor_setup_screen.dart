import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../admin_repository.dart';
import '../widgets/design_system.dart';

/// Two-Factor Authentication Setup Screen
/// Allows users to enable/disable 2FA
class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final AdminRepository _repo = AdminRepository();

  bool _isLoading = true;
  bool _is2FAEnabled = false;

  // Setup state
  bool _isSettingUp = false;
  String? _secret;
  String? _qrUri;

  // Verification
  final _codeController = TextEditingController();
  bool _isVerifying = false;

  // Backup codes
  List<String>? _backupCodes;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);

    try {
      final enabled = await _repo.get2FAStatus();
      if (mounted) {
        setState(() {
          _is2FAEnabled = enabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startSetup() async {
    setState(() => _isSettingUp = true);

    try {
      final data = await _repo.setup2FA();
      if (mounted) {
        setState(() {
          _secret = data['secret'] as String?;
          _qrUri = data['qr_uri'] as String?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSettingUp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  Future<void> _verifyAndEnable() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Inserisci un codice a 6 cifre"),
          backgroundColor: KyboColors.error,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final result = await _repo.verify2FA(code: code, secret: _secret!);

      if (result['success'] == true) {
        final backupCodes = result['backup_codes'] as List<dynamic>?;
        if (mounted) {
          setState(() {
            _is2FAEnabled = true;
            _isSettingUp = false;
            _backupCodes = backupCodes?.map((e) => e.toString()).toList();
            _isVerifying = false;
            _codeController.clear();
          });
        }
      } else {
        if (mounted) {
          setState(() => _isVerifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Codice non valido"),
              backgroundColor: KyboColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  Future<void> _disable2FA() async {
    final code = await _showCodeDialog("Disabilita 2FA", "Inserisci il codice 2FA per confermare");
    if (code == null) return;

    setState(() => _isLoading = true);

    try {
      await _repo.disable2FA(code);
      if (mounted) {
        setState(() {
          _is2FAEnabled = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("2FA disabilitato"),
            backgroundColor: KyboColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _showCodeDialog(String title, String message) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: "000000",
                counterText: "",
                border: OutlineInputBorder(
                  borderRadius: KyboBorderRadius.small,
                ),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          PillButton(
            label: "Conferma",
            height: 40,
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            onPressed: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background,
      appBar: AppBar(
        backgroundColor: KyboColors.surface,
        elevation: 0,
        title: Text(
          "Autenticazione a Due Fattori",
          style: TextStyle(color: KyboColors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: KyboColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KyboColors.primary))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    // Show backup codes if just enabled
    if (_backupCodes != null) {
      return _buildBackupCodesView();
    }

    // Show setup wizard
    if (_isSettingUp && _secret != null) {
      return _buildSetupWizard();
    }

    // Show status
    return _buildStatusView();
  }

  Widget _buildStatusView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _is2FAEnabled
                      ? KyboColors.success.withValues(alpha: 0.1)
                      : KyboColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _is2FAEnabled ? Icons.verified_user_rounded : Icons.shield_outlined,
                  size: 50,
                  color: _is2FAEnabled ? KyboColors.success : KyboColors.warning,
                ),
              ),
              const SizedBox(height: 24),

              // Status text
              Text(
                _is2FAEnabled
                    ? "2FA Attivo"
                    : "2FA Non Attivo",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _is2FAEnabled
                    ? "Il tuo account è protetto con autenticazione a due fattori."
                    : "Aggiungi un livello extra di sicurezza al tuo account.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KyboColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Action button
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: _is2FAEnabled ? "Disabilita 2FA" : "Attiva 2FA",
                  icon: _is2FAEnabled ? Icons.lock_open_rounded : Icons.lock_rounded,
                  backgroundColor: _is2FAEnabled ? KyboColors.error : KyboColors.primary,
                  textColor: Colors.white,
                  onPressed: _is2FAEnabled ? _disable2FA : _startSetup,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupWizard() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Icon(
                Icons.qr_code_2_rounded,
                size: 64,
                color: KyboColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                "Configura Authenticator",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Instructions
              PillCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStep("1", "Apri la tua app authenticator", Icons.phone_android_rounded),
                    const SizedBox(height: 12),
                    _buildStep("2", "Scansiona il QR code o inserisci il codice manualmente", Icons.qr_code_scanner_rounded),
                    const SizedBox(height: 12),
                    _buildStep("3", "Inserisci il codice a 6 cifre generato", Icons.pin_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // QR Code placeholder (in real app, generate actual QR)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: KyboBorderRadius.medium,
                  border: Border.all(color: KyboColors.textMuted.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    // In real implementation, use qr_flutter package
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: KyboColors.background,
                        borderRadius: KyboBorderRadius.small,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_rounded,
                              size: 100,
                              color: KyboColors.textMuted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "QR Code",
                              style: TextStyle(color: KyboColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Manual entry secret
                    Text(
                      "Oppure inserisci manualmente:",
                      style: TextStyle(
                        fontSize: 12,
                        color: KyboColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _secret ?? "",
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: KyboColors.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text("Copia"),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _secret ?? ""));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Codice copiato")),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Verification code input
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  letterSpacing: 12,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "000000",
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: KyboBorderRadius.medium,
                  ),
                  filled: true,
                  fillColor: KyboColors.surface,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: "Annulla",
                      onPressed: () {
                        setState(() {
                          _isSettingUp = false;
                          _secret = null;
                          _qrUri = null;
                          _codeController.clear();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PillButton(
                      label: _isVerifying ? "Verifica..." : "Verifica",
                      backgroundColor: KyboColors.primary,
                      textColor: Colors.white,
                      onPressed: _isVerifying ? null : _verifyAndEnable,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: KyboColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: KyboColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: KyboColors.textSecondary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: KyboColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildBackupCodesView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Success icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: KyboColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 40,
                  color: KyboColors.success,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "2FA Attivato!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Salva questi codici di backup in un posto sicuro. Potrai usarli se perdi l'accesso al tuo authenticator.",
                textAlign: TextAlign.center,
                style: TextStyle(color: KyboColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // Backup codes
              PillCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: KyboColors.warning.withValues(alpha: 0.05),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.key_rounded, color: KyboColors.warning),
                        const SizedBox(width: 8),
                        Text(
                          "Codici di Backup",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: KyboColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _backupCodes!.map((code) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: KyboColors.surface,
                          borderRadius: KyboBorderRadius.small,
                          border: Border.all(color: KyboColors.textMuted.withValues(alpha: 0.3)),
                        ),
                        child: SelectableText(
                          code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text("Copia tutti"),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _backupCodes!.join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Codici copiati")),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: "Ho salvato i codici",
                  icon: Icons.check_rounded,
                  backgroundColor: KyboColors.primary,
                  textColor: Colors.white,
                  onPressed: () {
                    setState(() => _backupCodes = null);
                    Navigator.pop(context, true);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
