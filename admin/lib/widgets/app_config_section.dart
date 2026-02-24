// Widget per la sezione "Configurazione App" nel pannello admin.
// Legge e scrive i parametri configurabili dell'app (Gemini, notifiche, limiti upload)
// tramite GET/POST /admin/config/app.
// _save: invia tutti i campi compilati all'endpoint.
import 'package:flutter/material.dart';
import '../admin_repository.dart';
import 'design_system.dart';

class AppConfigSection extends StatefulWidget {
  final AdminRepository repo;

  const AppConfigSection({super.key, required this.repo});

  @override
  State<AppConfigSection> createState() => _AppConfigSectionState();
}

class _AppConfigSectionState extends State<AppConfigSection> {
  bool _loading = true;
  bool _saving = false;

  final _geminiModelCtrl = TextEditingController();
  final _promptPrefixCtrl = TextEditingController();
  final _notifTitleCtrl = TextEditingController();
  final _notifBodyCtrl = TextEditingController();
  final _maxFileMbCtrl = TextEditingController();
  final _maxPagesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _geminiModelCtrl.dispose();
    _promptPrefixCtrl.dispose();
    _notifTitleCtrl.dispose();
    _notifBodyCtrl.dispose();
    _maxFileMbCtrl.dispose();
    _maxPagesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cfg = await widget.repo.getAppConfig();
      if (!mounted) return;
      setState(() {
        _geminiModelCtrl.text = cfg['gemini_model'] ?? 'gemini-2.5-flash';
        _promptPrefixCtrl.text = cfg['gemini_global_prompt_prefix'] ?? '';
        _notifTitleCtrl.text = cfg['notification_diet_title'] ?? '';
        _notifBodyCtrl.text = cfg['notification_diet_body'] ?? '';
        _maxFileMbCtrl.text = (cfg['max_file_size_mb'] ?? 10).toString();
        _maxPagesCtrl.text = (cfg['max_pdf_pages'] ?? 50).toString();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'gemini_model': _geminiModelCtrl.text.trim(),
        'gemini_global_prompt_prefix': _promptPrefixCtrl.text.trim(),
        'notification_diet_title': _notifTitleCtrl.text.trim(),
        'notification_diet_body': _notifBodyCtrl.text.trim(),
        'max_file_size_mb': int.tryParse(_maxFileMbCtrl.text.trim()) ?? 10,
        'max_pdf_pages': int.tryParse(_maxPagesCtrl.text.trim()) ?? 50,
      };
      await widget.repo.setAppConfig(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurazione salvata')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configurazione App',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: KyboColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          PillCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('AI — Gemini'),
                const SizedBox(height: 12),
                PillTextField(
                  labelText: 'Modello Gemini',
                  controller: _geminiModelCtrl,
                  hintText: 'gemini-2.5-flash',
                ),
                const SizedBox(height: 12),
                _multilineField(
                  label: 'Prompt prefisso globale (opzionale)',
                  controller: _promptPrefixCtrl,
                  hint: 'Testo aggiunto prima di ogni prompt AI...',
                  lines: 3,
                ),
                const SizedBox(height: 24),
                _label('Notifiche Push'),
                const SizedBox(height: 12),
                PillTextField(
                  labelText: 'Titolo notifica dieta pronta',
                  controller: _notifTitleCtrl,
                  hintText: 'Dieta Pronta! 🥗',
                ),
                const SizedBox(height: 12),
                _multilineField(
                  label: 'Corpo notifica dieta pronta',
                  controller: _notifBodyCtrl,
                  hint: 'Il tuo piano nutrizionale è stato elaborato.',
                  lines: 2,
                ),
                const SizedBox(height: 24),
                _label('Limiti Upload'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PillTextField(
                        labelText: 'Max dimensione file (MB)',
                        controller: _maxFileMbCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PillTextField(
                        labelText: 'Max pagine PDF',
                        controller: _maxPagesCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: PillButton(
                    label: 'Salva Configurazione',
                    icon: Icons.save_rounded,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: KyboColors.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _multilineField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required int lines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: KyboColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: KyboColors.surface,
            borderRadius: KyboBorderRadius.medium,
            border: Border.all(color: KyboColors.border),
            boxShadow: KyboColors.softShadow,
          ),
          child: TextField(
            controller: controller,
            maxLines: lines,
            style: TextStyle(color: KyboColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: KyboColors.textMuted, fontSize: 13),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
