// Widget per la sezione "Configurazione App" nel pannello admin.
// Legge e scrive i parametri configurabili dell'app (Gemini, notifiche, limiti upload)
// tramite GET/POST /admin/config/app.
// Comportamento: i campi sono READ-ONLY di default (evita modifiche accidentali ai
// parametri production). Si abilita l'editing solo premendo "Modifica"; "Salva"
// conferma, "Annulla" ripristina i valori caricati dal server.
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
  bool _editMode = false;

  // Snapshot dei valori lato server, usato per il display read-only e per
  // ripristinare i controller quando l'utente preme "Annulla".
  Map<String, String> _serverValues = {
    'gemini_model': '',
    'gemini_global_prompt_prefix': '',
    'notification_diet_title': '',
    'notification_diet_body': '',
    'max_file_size_mb': '',
    'max_pdf_pages': '',
  };

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
        _serverValues = {
          'gemini_model': cfg['gemini_model'] ?? 'gemini-2.5-flash',
          'gemini_global_prompt_prefix': cfg['gemini_global_prompt_prefix'] ?? '',
          'notification_diet_title': cfg['notification_diet_title'] ?? '',
          'notification_diet_body': cfg['notification_diet_body'] ?? '',
          'max_file_size_mb': (cfg['max_file_size_mb'] ?? 10).toString(),
          'max_pdf_pages': (cfg['max_pdf_pages'] ?? 50).toString(),
        };
        _resetControllers();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetControllers() {
    _geminiModelCtrl.text = _serverValues['gemini_model']!;
    _promptPrefixCtrl.text = _serverValues['gemini_global_prompt_prefix']!;
    _notifTitleCtrl.text = _serverValues['notification_diet_title']!;
    _notifBodyCtrl.text = _serverValues['notification_diet_body']!;
    _maxFileMbCtrl.text = _serverValues['max_file_size_mb']!;
    _maxPagesCtrl.text = _serverValues['max_pdf_pages']!;
  }

  void _enterEditMode() {
    setState(() => _editMode = true);
  }

  void _cancelEdit() {
    setState(() {
      _resetControllers();
      _editMode = false;
    });
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
        setState(() {
          _serverValues = updates.map(
            (k, v) => MapEntry(k, v.toString()),
          );
          _editMode = false;
        });
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
        Row(
          children: [
            Text(
              'Configurazione App',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: KyboColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (!_loading && !_editMode)
              PillButton(
                label: 'Modifica',
                icon: Icons.edit_rounded,
                height: 36,
                onPressed: _enterEditMode,
              ),
            if (!_loading && _editMode) ...[
              PillButton(
                label: 'Annulla',
                icon: Icons.close_rounded,
                height: 36,
                backgroundColor: KyboColors.surface,
                textColor: KyboColors.textSecondary,
                onPressed: _saving ? null : _cancelEdit,
              ),
              const SizedBox(width: 12),
              PillButton(
                label: 'Salva',
                icon: Icons.save_rounded,
                height: 36,
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ],
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
                _field(
                  label: 'Modello Gemini',
                  controller: _geminiModelCtrl,
                  displayValue: _serverValues['gemini_model']!,
                  hint: 'gemini-2.5-flash',
                ),
                const SizedBox(height: 12),
                _field(
                  label: 'Prompt prefisso globale (opzionale)',
                  controller: _promptPrefixCtrl,
                  displayValue: _serverValues['gemini_global_prompt_prefix']!,
                  hint: 'Testo aggiunto prima di ogni prompt AI...',
                  lines: 3,
                ),
                const SizedBox(height: 24),
                _label('Notifiche Push'),
                const SizedBox(height: 12),
                _field(
                  label: 'Titolo notifica dieta pronta',
                  controller: _notifTitleCtrl,
                  displayValue: _serverValues['notification_diet_title']!,
                  hint: 'Dieta Pronta! 🥗',
                ),
                const SizedBox(height: 12),
                _field(
                  label: 'Corpo notifica dieta pronta',
                  controller: _notifBodyCtrl,
                  displayValue: _serverValues['notification_diet_body']!,
                  hint: 'Il tuo piano nutrizionale è stato elaborato.',
                  lines: 2,
                ),
                const SizedBox(height: 24),
                _label('Limiti Upload'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        label: 'Max dimensione file (MB)',
                        controller: _maxFileMbCtrl,
                        displayValue: _serverValues['max_file_size_mb']!,
                        hint: '10',
                        numeric: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _field(
                        label: 'Max pagine PDF',
                        controller: _maxPagesCtrl,
                        displayValue: _serverValues['max_pdf_pages']!,
                        hint: '50',
                        numeric: true,
                      ),
                    ),
                  ],
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String displayValue,
    String hint = '',
    int lines = 1,
    bool numeric = false,
  }) {
    if (!_editMode) {
      return _readOnlyRow(label: label, value: displayValue);
    }

    if (lines > 1) {
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

    return PillTextField(
      labelText: label,
      controller: controller,
      hintText: hint,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
    );
  }

  Widget _readOnlyRow({required String label, required String value}) {
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
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: KyboColors.background,
            borderRadius: KyboBorderRadius.medium,
            border: Border.all(color: KyboColors.border),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              color: value.isEmpty
                  ? KyboColors.textMuted
                  : KyboColors.textPrimary,
              fontSize: 14,
              fontStyle: value.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}
