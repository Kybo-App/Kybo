// Vista templates di dieta: lista + upload + elimina + clone-and-assign.
// Pattern speculare a workout_management_view ma per le diete.
// Il template viene caricato come PDF e parsato dal backend (Gemini),
// poi può essere clonato su qualsiasi utente del professionista.

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../widgets/design_system.dart';

class DietTemplatesView extends StatefulWidget {
  const DietTemplatesView({super.key});

  @override
  State<DietTemplatesView> createState() => _DietTemplatesViewState();
}

class _DietTemplatesViewState extends State<DietTemplatesView> {
  final AdminRepository _repo = AdminRepository();

  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadClients();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getDietTemplates();
      if (mounted) {
        setState(() {
          _templates =
              List<Map<String, dynamic>>.from(data['templates'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).error}: $e'),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadClients() async {
    try {
      final raw = await _repo.getSecureUsersList();
      final clients = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((u) {
            final role = (u['role'] as String?) ?? '';
            return role == 'user' || role == 'client' || role == 'independent';
          })
          .toList();
      if (mounted) setState(() => _clients = clients);
    } catch (_) {}
  }

  Future<void> _uploadTemplate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    if (!mounted) return;

    final nameCtrl = TextEditingController(
        text: file.name.replaceAll('.pdf', '').replaceAll('_', ' '));
    final descCtrl = TextEditingController();
    bool isUploading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: KyboColors.surface,
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          title: Row(
            children: [
              Icon(Icons.bookmark_add_rounded,
                  color: KyboColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(ctx).dietTemplateNew,
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File: ${file.name}',
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                PillTextField(
                  controller: nameCtrl,
                  hintText: AppLocalizations.of(ctx).dietTemplateNameHint,
                  prefixIcon: Icons.label_rounded,
                ),
                const SizedBox(height: 12),
                PillTextField(
                  controller: descCtrl,
                  hintText:
                      '${AppLocalizations.of(ctx).description} (${AppLocalizations.of(ctx).optional.toLowerCase()})',
                  prefixIcon: Icons.description_rounded,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: KyboColors.warning.withValues(alpha: 0.10),
                    borderRadius: KyboBorderRadius.medium,
                    border: Border.all(
                        color: KyboColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: KyboColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(ctx).dietTemplateAiWarning,
                          style: TextStyle(
                            color: KyboColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(ctx).cancel,
                  style: TextStyle(color: KyboColors.textSecondary)),
            ),
            PillButton(
              label: AppLocalizations.of(ctx).create,
              icon: Icons.bookmark_rounded,
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              height: 40,
              isLoading: isUploading,
              onPressed: isUploading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '${AppLocalizations.of(context).name} ${AppLocalizations.of(context).required.toLowerCase()}')),
                        );
                        return;
                      }
                      setDialogState(() => isUploading = true);
                      try {
                        await _repo.createDietTemplate(
                          file: file,
                          name: name,
                          description: descCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  AppLocalizations.of(context).dietTemplateCreated),
                              backgroundColor: KyboColors.success,
                            ),
                          );
                        }
                        _loadTemplates();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${AppLocalizations.of(context).error}: $e'),
                              backgroundColor: KyboColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => isUploading = false);
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _useTemplate(Map<String, dynamic> template) async {
    final l10n = AppLocalizations.of(context);
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noDataAvailable)),
      );
      return;
    }
    String? selectedUid;
    bool isAssigning = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: KyboColors.surface,
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          title: Row(
            children: [
              Icon(Icons.content_copy_rounded,
                  color: KyboColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(ctx).useTemplate,
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(ctx).dietTemplateUseDescription,
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedUid,
                  isExpanded: true,
                  items: _clients
                      .map((c) => DropdownMenuItem<String>(
                            value: c['uid'] as String,
                            child: Text(
                              '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'
                                      .trim()
                                      .isNotEmpty
                                  ? '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'
                                      .trim()
                                  : (c['email'] ?? c['uid']) as String,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedUid = v),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(ctx).roleClient,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(ctx).cancel,
                  style: TextStyle(color: KyboColors.textSecondary)),
            ),
            PillButton(
              label: AppLocalizations.of(ctx).assign,
              icon: Icons.check_rounded,
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              height: 40,
              isLoading: isAssigning,
              onPressed: isAssigning
                  ? null
                  : () async {
                      if (selectedUid == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context).noResults)),
                        );
                        return;
                      }
                      setDialogState(() => isAssigning = true);
                      try {
                        await _repo.cloneAndAssignDietTemplate(
                            template['id'], selectedUid!);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context).dietTemplateAssigned),
                              backgroundColor: KyboColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${AppLocalizations.of(context).error}: $e'),
                              backgroundColor: KyboColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => isAssigning = false);
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTemplate(Map<String, dynamic> template) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface,
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text('${AppLocalizations.of(ctx).delete} template',
            style: TextStyle(color: KyboColors.textPrimary)),
        content: Text(
          AppLocalizations.of(ctx).dietTemplateDeleteConfirm,
          style: TextStyle(color: KyboColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx).cancel,
                style: TextStyle(color: KyboColors.textSecondary)),
          ),
          PillButton(
            label: AppLocalizations.of(ctx).delete,
            icon: Icons.delete_rounded,
            backgroundColor: KyboColors.error,
            textColor: Colors.white,
            height: 40,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.deleteDietTemplate(template['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dietTemplateDeleted),
            backgroundColor: KyboColors.success,
          ),
        );
      }
      _loadTemplates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.bookmark_rounded, color: KyboColors.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              l10n.dietTemplatesTab,
              style: TextStyle(
                fontSize: 22,
                color: KyboColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            PillButton(
              label: l10n.dietTemplateUploadCta,
              icon: Icons.upload_file_rounded,
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              height: 40,
              onPressed: _uploadTemplate,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: KyboColors.primary))
              : _templates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_border_rounded,
                              size: 56, color: KyboColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            l10n.dietTemplateNoneTitle,
                            style: TextStyle(
                              fontSize: 16,
                              color: KyboColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.dietTemplateNoneSubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: KyboColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _templates.length,
                      itemBuilder: (ctx, idx) =>
                          _buildTemplateRow(_templates[idx]),
                    ),
        ),
      ],
    );
  }

  Widget _buildTemplateRow(Map<String, dynamic> template) {
    final name = template['name'] ?? AppLocalizations.of(context).clientUnnamed;
    final desc = (template['description'] ?? '').toString();
    final fileName = (template['file_name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(
          color: KyboColors.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: KyboColors.accent.withValues(alpha: 0.1),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: Icon(Icons.bookmark_rounded,
                color: KyboColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: KyboColors.textPrimary,
                  ),
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      desc,
                      style: TextStyle(
                          fontSize: 13, color: KyboColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (fileName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      fileName,
                      style: TextStyle(
                          fontSize: 11, color: KyboColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PillIconButton(
                icon: Icons.content_copy_rounded,
                color: KyboColors.success,
                tooltip: AppLocalizations.of(context).useTemplateTooltip,
                onPressed: () => _useTemplate(template),
              ),
              const SizedBox(width: 4),
              PillIconButton(
                icon: Icons.delete_rounded,
                color: KyboColors.error,
                tooltip: AppLocalizations.of(context).delete,
                onPressed: () => _deleteTemplate(template),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
