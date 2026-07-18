// Vista gestione utenti: lista, creazione, modifica, eliminazione, assegnazione a nutrizionista e upload diete.
// _checkCurrentUser — carica ruolo dai token claims; _buildAdminGroupedLayout — raggruppa utenti per nutrizionista.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../widgets/design_system.dart';
import '../widgets/password_checklist.dart';
import '../widgets/skeleton_loaders.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:universal_html/html.dart' as html;
import '../services/client_report_service.dart';
import '../core/error_mapper.dart';
import '../widgets/state_views.dart';

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final AdminRepository _repo = AdminRepository();
  bool _isLoading = false;

  String _searchQuery = "";
  String _roleFilter = "all";
  final TextEditingController _searchCtrl = TextEditingController();

  // --- BULK SELECTION ---
  // Solo i ruoli "user" e "independent" sono selezionabili (sono gli unici
  // su cui ha senso fare azioni di massa: assegnazione + export CSV).
  final Set<String> _selectedUids = {};
  final Map<String, Map<String, dynamic>> _selectedUserData = {};
  bool _selectionMode = false;

  static const _selectableRoles = {'user', 'independent'};

  // --- VIRTUALIZZAZIONE LISTA UTENTI ---
  // Le GridView annidate dentro PillExpansionTile usano shrinkWrap+
  // NeverScrollableScrollPhysics, che rompe la lazy build di Flutter:
  // tutti i _UserCard di una sezione vengono costruiti subito anche se
  // non visibili. Per dataset grandi (>500) è il bottleneck principale.
  // Soluzione pragmatica: mostriamo i primi N elementi per sezione e
  // riveliamo il resto in step quando l'utente clicca "Mostra altri".
  static const int _sectionInitialVisible = 60;
  static const int _sectionLoadStep = 60;
  final Map<String, int> _sectionVisible = {};

  int _visibleCount(String key) =>
      _sectionVisible[key] ?? _sectionInitialVisible;

  // --- SPLIT VIEW MASTER-DETAIL ---
  // Quando _detailUid != null e il viewport è largo (>1100px), la build
  // mostra la lista a sinistra e un pannello dettaglio a destra.
  String? _detailUid;
  Map<String, dynamic>? _detailUserData;

  void _showUserDetail(Map<String, dynamic> user) {
    setState(() {
      _detailUid = user['uid'] as String?;
      _detailUserData = user;
    });
  }

  void _closeUserDetail() {
    setState(() {
      _detailUid = null;
      _detailUserData = null;
    });
  }

  void _loadMoreSection(String key, int total) {
    setState(() {
      final cur = _visibleCount(key);
      _sectionVisible[key] =
          (cur + _sectionLoadStep).clamp(0, total).toInt();
    });
  }

  bool _isSelectableRole(String role) =>
      _selectableRoles.contains(role.toLowerCase());

  void _toggleSelection(Map<String, dynamic> user) {
    final uid = user['uid'] as String;
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
        _selectedUserData.remove(uid);
        if (_selectedUids.isEmpty) _selectionMode = false;
      } else {
        _selectedUids.add(uid);
        _selectedUserData[uid] = user;
        _selectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedUids.clear();
      _selectedUserData.clear();
      _selectionMode = false;
    });
  }

  String _currentUserId = '';
  String _currentUserRole = '';
  bool _isDataLoaded = false;

  Future<List<dynamic>>? _usersFuture;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final tokenResult = await user.getIdTokenResult(true);
        final role = tokenResult.claims?['role'] ?? 'user';

        if (mounted) {
          setState(() {
            _currentUserId = user.uid;
            _currentUserRole = role;
            _isDataLoaded = true;
          });
          _refreshList();
        }
      } catch (e) {
        if (mounted) setState(() => _isDataLoaded = true);
      }
    }
  }

  void _refreshList() {
    setState(() {
      _usersFuture = _repo.getSecureUsersList();
    });
  }

  Future<void> _syncUsers() async {
    setState(() => _isLoading = true);
    try {
      String msg = await _repo.syncUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.blue),
        );
        _refreshList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${AppLocalizations.of(context).userSyncError}: ${ErrorMapper.toUserMessage(e)}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String uid) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.userDeleteTitle),
            content: Text(l10n.userDeleteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() => _isLoading = true);
      try {
        await _repo.deleteUser(uid);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.userDeleted)));
          _refreshList();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(ErrorMapper.toUserMessage(e))));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadDiet(String targetUid) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.bytes != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _DietUploadProgressDialog(),
      );

      try {
        await _repo.uploadDietForUser(targetUid, result.files.single);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).userDietUploaded),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${AppLocalizations.of(context).userDietUploadError}: ${ErrorMapper.toUserMessage(e)}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Variante drag-and-drop: prende il primo PDF dai file rilasciati sulla
  /// user card, ne legge i byte, lo wrappa in PlatformFile e riusa
  /// AdminRepository.uploadDietForUser. Se nessun PDF tra i file rilasciati
  /// → snackbar di errore.
  Future<void> _uploadDroppedDiet(String targetUid, List<XFile> files) async {
    final pdf = files.firstWhere(
      (f) => f.name.toLowerCase().endsWith('.pdf'),
      orElse: () => XFile(''),
    );
    if (pdf.path.isEmpty && pdf.name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).userDragPdf),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bytes = await pdf.readAsBytes();
    final platformFile = PlatformFile(
      name: pdf.name,
      size: bytes.length,
      bytes: bytes,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DietUploadProgressDialog(),
    );

    try {
      await _repo.uploadDietForUser(targetUid, platformFile);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).userDietUploaded),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "${AppLocalizations.of(context).uploadErrorPrefix}: ${ErrorMapper.toUserMessage(e)}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadParser(String targetUid) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ParserConfigScreen(targetUid: targetUid),
      ),
    );
  }

  Future<void> _showUserHistory(String targetUid, String userName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _UserHistoryScreen(targetUid: targetUid, userName: userName),
      ),
    );
  }

  void _showClientNotes(String clientUid, String clientName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClientNotesScreen(
          clientUid: clientUid,
          clientName: clientName,
        ),
      ),
    );
  }

  Future<void> _editUser(
    String uid,
    String currentEmail,
    String currentFirst,
    String currentLast,
    Map<String, dynamic> userData,
  ) async {
    final emailCtrl = TextEditingController(text: currentEmail);
    final firstCtrl = TextEditingController(text: currentFirst);
    final lastCtrl = TextEditingController(text: currentLast);
    
    final initialRole = (userData['role'] ?? '').toString();
    String selectedRole = initialRole;
    final bioCtrl = TextEditingController(text: userData['bio'] ?? '');
    final specCtrl = TextEditingController(text: userData['specializations'] ?? '');
    final phoneCtrl = TextEditingController(text: userData['phone'] ?? '');
    final studioCtrl = TextEditingController(text: userData['studio_name'] ?? '');
    final limitCtrl = TextEditingController(
      text: (userData['max_clients'] ?? 50).toString(),
    );


    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final t = AppLocalizations.of(ctx);
          final isNutritionistOrCoach = selectedRole == 'nutritionist' ||
              selectedRole == 'coach' ||
              selectedRole == 'personal_trainer';
          return AlertDialog(
        title: Text(t.isItalian ? 'Modifica Account' : 'Edit Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstCtrl,
                decoration: InputDecoration(labelText: t.firstName),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastCtrl,
                decoration: InputDecoration(labelText: t.lastName),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: t.email),
              ),
              if (_currentUserRole == 'admin') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole.isEmpty ? 'user' : selectedRole,
                  decoration: InputDecoration(
                    labelText: t.role,
                    prefixIcon: const Icon(Icons.admin_panel_settings),
                  ),
                  items: [
                    DropdownMenuItem(value: 'user', child: Text(t.roleClient)),
                    DropdownMenuItem(value: 'independent', child: Text(t.roleIndependent)),
                    DropdownMenuItem(value: 'nutritionist', child: Text(t.roleNutritionist)),
                    DropdownMenuItem(value: 'personal_trainer', child: Text(t.rolePersonalTrainer)),
                    DropdownMenuItem(value: 'coach', child: Text(t.roleCoach)),
                    DropdownMenuItem(value: 'admin', child: Text(t.roleAdmin)),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRole = v);
                  },
                ),
              ],
              if (isNutritionistOrCoach) ...[
                const SizedBox(height: 16),
                const Divider(),
                Text(t.professionalProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                 TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(labelText: t.phone, prefixIcon: const Icon(Icons.phone)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bioCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: t.bio),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: specCtrl,
                  decoration: InputDecoration(labelText: t.specializations),
                ),
                if (_currentUserRole == 'admin') ...[
                   const SizedBox(height: 8),
                   TextField(
                    controller: studioCtrl,
                    decoration: InputDecoration(
                      labelText: t.studioName,
                      hintText: t.studioNameHint,
                      prefixIcon: const Icon(Icons.store_mall_directory),
                    ),
                  ),
                   const SizedBox(height: 8),
                   TextField(
                    controller: limitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t.clientLimit),
                  ),
                ]
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                int? maxClients;
                if (isNutritionistOrCoach && _currentUserRole == 'admin') {
                    maxClients = int.tryParse(limitCtrl.text);
                }

                await _repo.updateUser(
                  uid,
                  email: emailCtrl.text,
                  firstName: firstCtrl.text,
                  lastName: lastCtrl.text,
                  bio: isNutritionistOrCoach ? bioCtrl.text : null,
                  specializations: isNutritionistOrCoach ? specCtrl.text : null,
                  phone: isNutritionistOrCoach ? phoneCtrl.text : null,
                  maxClients: maxClients,
                  studioName: isNutritionistOrCoach && _currentUserRole == 'admin'
                      ? studioCtrl.text
                      : null,
                  role: _currentUserRole == 'admin' && selectedRole != initialRole
                      ? selectedRole
                      : null,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.userUpdated)),
                  );
                  _refreshList();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ErrorMapper.toUserMessage(e)),
                      backgroundColor: KyboColors.error,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: Text(t.save),
          ),
        ],
      );
        },
      ),
    );
  }

  // Esporta il report PDF del cliente (cronologia diete + workout + note).
  // Mostra snackbar di stato per feedback immediato durante il fetch dei dati.
  Future<void> _exportClientReport(
      String clientUid, Map<String, dynamic> clientData) async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.reportGenerating),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      await ClientReportService().generateAndDownload(
        clientUid: clientUid,
        clientData: clientData,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.reportDownloaded),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${AppLocalizations.of(context).userReportGenError}: ${ErrorMapper.toUserMessage(e)}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Assegna in bulk gli utenti selezionati a un nutrizionista.
  // Itera serialmente per evitare burst sull'API e fornisce snackbar finale
  // con conteggio successi/errori.
  Future<void> _bulkAssign(Map<String, String> nutritionists) async {
    final l10n = AppLocalizations.of(context);
    if (_selectedUids.isEmpty) return;
    if (nutritionists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.userNoNutritionist),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? selectedNutId = nutritionists.keys.first;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(l10n.userBulkAssignTitle(_selectedUids.length)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.locale.languageCode == 'it'
                    ? "Stai per assegnare ${_selectedUids.length} utenti al nutrizionista selezionato."
                    : "You're about to assign ${_selectedUids.length} users to the selected nutritionist.",
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedNutId,
                isExpanded: true,
                items: nutritionists.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedNutId = v),
                decoration: InputDecoration(
                  labelText: l10n.chatSelectNutritionist,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.assign),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || selectedNutId == null) return;

    setState(() => _isLoading = true);
    int ok = 0;
    final errors = <String>[];
    final uids = List<String>.from(_selectedUids);
    for (final uid in uids) {
      try {
        await _repo.assignUserToNutritionist(uid, selectedNutId!);
        ok++;
      } catch (e) {
        errors.add(uid.substring(0, 6));
      }
    }
    if (mounted) {
      final l10n2 = AppLocalizations.of(context);
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errors.isEmpty
                ? (l10n2.locale.languageCode == 'it'
                    ? "$ok utenti assegnati con successo!"
                    : "$ok users assigned successfully!")
                : (l10n2.locale.languageCode == 'it'
                    ? "$ok ok, ${errors.length} errori (${errors.join(', ')})"
                    : "$ok ok, ${errors.length} errors (${errors.join(', ')})"),
          ),
          backgroundColor: errors.isEmpty ? Colors.green : Colors.orange,
        ),
      );
      _refreshList();
      setState(() => _isLoading = false);
    }
  }

  // Esporta gli utenti selezionati in CSV (download via blob su web).
  // Colonne: UID, Nome, Cognome, Email, Ruolo, Creato il, Ultima attività.
  Future<void> _bulkExportCsv() async {
    if (_selectedUids.isEmpty) return;

    final rows = <List<dynamic>>[];
    rows.add([
      "UID",
      "Nome",
      "Cognome",
      "Email",
      "Ruolo",
      "Creato il",
      "Ultima attività",
    ]);

    for (final uid in _selectedUids) {
      final u = _selectedUserData[uid];
      if (u == null) continue;
      rows.add([
        uid,
        u['first_name'] ?? '',
        u['last_name'] ?? '',
        u['email'] ?? '',
        u['role'] ?? '',
        u['created_at'] ?? '',
        u['last_seen'] ?? u['last_login'] ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute(
        "download",
        "users_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv",
      )
      ..click();

    html.Url.revokeObjectUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).userBulkExported(_selectedUids.length)),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _assignUser(
    String targetUid,
    Map<String, String> nutritionists,
  ) async {
    String? selectedNutId;
    if (nutritionists.isNotEmpty) selectedNutId = nutritionists.keys.first;

    final l10n = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(l10n.userAssignTitle),
          content: DropdownButtonFormField<String>(
            initialValue: selectedNutId,
            isExpanded: true,
            items: nutritionists.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setDialogState(() => selectedNutId = v),
            decoration: InputDecoration(
              labelText: l10n.chatSelectNutritionist,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedNutId == null) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _repo.assignUserToNutritionist(
                    targetUid,
                    selectedNutId!,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.userAssigned)),
                    );
                    _refreshList();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ErrorMapper.toUserMessage(e)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: Text(l10n.assign),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManageAssignmentDialog(
    String targetUid,
    Map<String, String> nutritionists,
  ) async {
    String? selectedNutId;
    if (nutritionists.isNotEmpty) selectedNutId = nutritionists.keys.first;
    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(l10n.userManageAssignment),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.locale.languageCode == 'it'
                    ? "Sposta utente ad un altro nutrizionista:"
                    : "Move user to another nutritionist:",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedNutId,
                isExpanded: true,
                items: nutritionists.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedNutId = v),
                decoration: InputDecoration(
                  labelText: l10n.newNutritionist,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_off, color: Colors.red),
                label: Text(
                  l10n.locale.languageCode == 'it'
                      ? "Rimuovi assegnazione"
                      : "Remove assignment",
                  style: const TextStyle(color: Colors.red),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  try {
                    await _repo.unassignUser(targetUid);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.userAssignmentRemoved)),
                      );
                      _refreshList();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(ErrorMapper.toUserMessage(e))));
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedNutId == null) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _repo.assignUserToNutritionist(
                    targetUid,
                    selectedNutId!,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.userTransferred)),
                    );
                    _refreshList();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(ErrorMapper.toUserMessage(e))));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: Text(l10n.userMove),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateUserDialog() async {
    final l10n = AppLocalizations.of(context);
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    String role = 'user';

    List<DropdownMenuItem<String>> allowedRoles = [
      DropdownMenuItem(value: 'user', child: Text(l10n.roleClient)),
    ];

    if (_currentUserRole == 'admin') {
      allowedRoles.addAll([
        DropdownMenuItem(
          value: 'nutritionist',
          child: Text(l10n.roleNutritionist),
        ),
        DropdownMenuItem(
          value: 'personal_trainer',
          child: Text(l10n.rolePersonalTrainer),
        ),
        DropdownMenuItem(
          value: 'coach',
          child: Text(l10n.roleCoach),
        ),
        DropdownMenuItem(
          value: 'independent',
          child: Text(l10n.roleIndependent),
        ),
        DropdownMenuItem(value: 'admin', child: Text(l10n.roleAdmin)),
      ]);
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(l10n.userNew),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(labelText: l10n.firstName),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: surnameCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.lastName,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: emailCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  TextField(
                    controller: passCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.locale.languageCode == 'it'
                          ? "Password temp"
                          : "Temp password",
                      prefixIcon: const Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // La password temp deve comunque rispettare la policy
                  // (l'utente la cambierà al primo accesso): checklist live.
                  KyboPasswordChecklist(password: passCtrl.text),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: InputDecoration(labelText: l10n.role),
                    items: allowedRoles,
                    onChanged: (v) => setDialogState(() => role = v!),
                  ),
                  if (role == 'nutritionist' || role == 'personal_trainer' || role == 'coach') ...[
                     const SizedBox(height: 8),
                     TextField(
                      controller: limitCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.clientLimit,
                        hintText: 'Default: 50',
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              // Grigio finché email valida (formato) + password conforme alla policy.
              onPressed: (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(emailCtrl.text.trim()) ||
                      !KyboPasswordChecklist.isValid(passCtrl.text))
                  ? null
                  : () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _repo.createUser(
                    email: emailCtrl.text,
                    password: passCtrl.text,
                    role: role,
                    firstName: nameCtrl.text,
                    lastName: surnameCtrl.text,
                    maxClients: int.tryParse(limitCtrl.text),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.userCreated)),
                    );
                    _refreshList();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(ErrorMapper.toUserMessage(e))));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: Text(l10n.create),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'nutritionist':
        return Colors.blue;
      case 'personal_trainer':
        return Colors.teal;
      case 'coach':
        return Colors.indigo;
      case 'independent':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return const SkeletonUserList();
    }

    final width = MediaQuery.of(context).size.width;
    final showDetailPane = width > 1100 && _detailUid != null;

    final mainColumn = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: KyboColors.surface,
            borderRadius: KyboBorderRadius.pill,
            boxShadow: KyboColors.softShadow,
            border: Border.all(color: KyboColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: KyboColors.background,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                    style: TextStyle(color: KyboColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).searchUser,
                      hintStyle: TextStyle(
                        color: KyboColors.textMuted,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: KyboColors.textMuted,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              if (_currentUserRole == 'admin') ...[
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: KyboColors.background,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _roleFilter,
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(AppLocalizations.of(context).filterAllRoles),
                        ),
                        DropdownMenuItem(value: 'user', child: Text(AppLocalizations.of(context).filterClients)),
                        DropdownMenuItem(
                          value: 'nutritionist',
                          child: Text(AppLocalizations.of(context).filterNutritionists),
                        ),
                        DropdownMenuItem(
                          value: 'personal_trainer',
                          child: Text(AppLocalizations.of(context).filterPT),
                        ),
                        DropdownMenuItem(
                          value: 'coach',
                          child: Text(AppLocalizations.of(context).filterCoach),
                        ),
                        DropdownMenuItem(
                          value: 'independent',
                          child: Text(AppLocalizations.of(context).filterIndependents),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text(AppLocalizations.of(context).filterAdmin)),
                      ],
                      onChanged: (val) => setState(() => _roleFilter = val!),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: KyboColors.textSecondary,
                      ),
                      style: TextStyle(
                        color: KyboColors.textPrimary,
                        fontSize: 14,
                      ),
                      dropdownColor: KyboColors.surface,
                      borderRadius: KyboBorderRadius.medium,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              PillIconButton(
                icon: Icons.refresh_rounded,
                color: KyboColors.primary,
                tooltip: AppLocalizations.of(context).reloadListTooltip,
                onPressed: _refreshList,
              ),

              if (_currentUserRole == 'admin') ...[
                const SizedBox(width: 4),
                PillIconButton(
                  icon: Icons.sync_rounded,
                  color: KyboColors.accent,
                  tooltip: AppLocalizations.of(context).syncDbTooltip,
                  onPressed: _isLoading ? null : _syncUsers,
                ),
              ],

              const SizedBox(width: 12),

              if (_currentUserRole == 'admin' ||
                  _currentUserRole == 'nutritionist')
                PillButton(
                  label: AppLocalizations.of(context).newUser.toUpperCase(),
                  icon: Icons.add_rounded,
                  backgroundColor: KyboColors.primary,
                  textColor: Colors.white,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _showCreateUserDialog,
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        if (_isLoading)
          LinearProgressIndicator(
            backgroundColor: KyboColors.background,
            valueColor: AlwaysStoppedAnimation(KyboColors.primary),
          ),

        const SizedBox(height: 16),

        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SkeletonUserList();
              }
              if (snapshot.hasError) {
                // [UX/SECURITY] Prima esponeva snapshot.error grezzo a schermo
                // (dettaglio backend + rischio info-disclosure). Ora messaggio
                // pulito + azione di retry (ep5/ep7).
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: KyboColors.error, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context).usersLoadError,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: KyboColors.textPrimary, fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        PillButton(
                          label: AppLocalizations.of(context).retry,
                          icon: Icons.refresh_rounded,
                          onPressed: _refreshList,
                          backgroundColor: KyboColors.primary,
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context).noUsersFound,
                    style: TextStyle(color: KyboColors.textMuted),
                  ),
                );
              }

              var allUsers = snapshot.data!;
              final expertNameMap = <String, String>{};
              for (var u in allUsers) {
                final r = u['role']?.toString() ?? '';
                if (r == 'nutritionist' || r == 'personal_trainer' || r == 'coach') {
                  expertNameMap[u['uid']] =
                      "${u['first_name'] ?? ''} ${u['last_name'] ?? ''}".trim();
                  if (expertNameMap[u['uid']]!.isEmpty) {
                    expertNameMap[u['uid']] = u['email'] ?? 'Unknown';
                  }
                }
              }

              final filteredUsers = allUsers.where((user) {
                final role = (user['role'] ?? 'user').toString().toLowerCase();
                final name =
                    "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}"
                        .toLowerCase();
                final email = (user['email'] ?? '').toString().toLowerCase();
                if (_currentUserRole == 'admin' &&
                    _roleFilter != 'all' &&
                    role != _roleFilter) {
                  return false;
                }
                if (_searchQuery.isNotEmpty) {
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }
                return true;
              }).toList();

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context).searchNoResults,
                    style: TextStyle(color: KyboColors.textMuted),
                  ),
                );
              }

              final layout = _currentUserRole == 'admin'
                  ? _buildAdminGroupedLayout(filteredUsers, expertNameMap)
                  : _buildUserGrid(filteredUsers);

              if (!_selectionMode || _selectedUids.isEmpty) {
                return layout;
              }

              return Column(
                children: [
                  _buildBulkActionBar(expertNameMap),
                  const SizedBox(height: 12),
                  Expanded(child: layout),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (!showDetailPane) return mainColumn;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: mainColumn),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: _UserDetailPane(
            user: _detailUserData!,
            roleColor: _getRoleColor(
                (_detailUserData!['role'] ?? 'user').toString()),
            onClose: _closeUserDetail,
            onOpenChat: () => _closeUserDetail(),
            onShowHistory: () {
              _showUserHistory(_detailUid!,
                  _detailUserData!['first_name'] ?? AppLocalizations.of(context).user);
            },
          ),
        ),
      ],
    );
  }

  // Pulsante "Mostra altri N" per sezioni con più di _sectionInitialVisible
  // utenti. Click → svela altri _sectionLoadStep elementi.
  Widget _buildLoadMoreButton(String sectionKey, int total) {
    final visible = _visibleCount(sectionKey);
    if (total <= visible) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final remaining = total - visible;
    final next = remaining < _sectionLoadStep ? remaining : _sectionLoadStep;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: PillButton(
          label: l10n.loadMoreUsers(next, visible, total),
          icon: Icons.expand_more_rounded,
          backgroundColor: KyboColors.background,
          textColor: KyboColors.primary,
          height: 36,
          onPressed: () => _loadMoreSection(sectionKey, total),
        ),
      ),
    );
  }

  // Barra azioni di massa: visibile solo quando ci sono utenti selezionati.
  // Mostra contatore + pulsanti Assegna/Esporta CSV/Annulla.
  Widget _buildBulkActionBar(Map<String, String> nutritionists) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: KyboColors.primary.withValues(alpha: 0.10),
        borderRadius: KyboBorderRadius.pill,
        border: Border.all(color: KyboColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.checklist_rounded, color: KyboColors.primary, size: 22),
          const SizedBox(width: 10),
          Text(
            l10n.selectedCount(_selectedUids.length),
            style: TextStyle(
              color: KyboColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (_currentUserRole == 'admin') ...[
            PillButton(
              label: l10n.bulkAssign,
              icon: Icons.person_add_rounded,
              backgroundColor: KyboColors.accent,
              textColor: Colors.white,
              onPressed: _isLoading ? null : () => _bulkAssign(nutritionists),
            ),
            const SizedBox(width: 8),
          ],
          PillButton(
            label: l10n.bulkExportCsv,
            icon: Icons.download_rounded,
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            onPressed: _isLoading ? null : _bulkExportCsv,
          ),
          const SizedBox(width: 8),
          PillIconButton(
            icon: Icons.close_rounded,
            color: KyboColors.textSecondary,
            tooltip: l10n.bulkCancelTooltip,
            onPressed: _clearSelection,
            size: 36,
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrid(List<dynamic> users) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 240,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index] as Map<String, dynamic>;
        final uid = u['uid'] as String;
        final role = (u['role'] ?? 'user').toString();
        final selectable = _isSelectableRole(role);
        return _UserCard(
          user: u,
          onDelete: (uid) => _deleteUser(uid),
          onUploadDiet: _uploadDiet,
                          onDropDiet: _uploadDroppedDiet,
          onUploadParser: _uploadParser,
          onHistory: (uid) =>
              _showUserHistory(uid, u['first_name'] ?? 'User'),
          onEdit: _editUser,
          onAssign: null,
          onNotes: _showClientNotes,
          onExportReport: _exportClientReport,
          onShowDetail: _showUserDetail,
          currentUserRole: _currentUserRole,
          currentUserId: _currentUserId,
          roleColor: _getRoleColor(role),
          selectable: selectable,
          selectionMode: _selectionMode,
          isSelected: _selectedUids.contains(uid),
          onToggleSelect: selectable ? () => _toggleSelection(u) : null,
        );
      },
    );
  }

  Widget _buildAdminGroupedLayout(
    List<dynamic> users,
    Map<String, String> expertNameMap,
  ) {
    final admins = <dynamic>[];
    final independents = <dynamic>[];
    final expertGroups = <String, List<dynamic>>{};
    final expertDocs = <String, dynamic>{};

    for (var user in users) {
      final role = (user['role'] ?? 'user').toString().toLowerCase();
      final parentId = user['parent_id'] as String?;
      final nutId = user['nutritionist_id'] as String?;
      final ptId = user['pt_id'] as String?;
      final createdBy = user['created_by'] as String?;
      
      final supervisorIds = {
         if (parentId != null) parentId,
         if (nutId != null) nutId,
         if (ptId != null) ptId,
         if (createdBy != null) createdBy,
      };
      
      final uid = user['uid'] as String;

      if (role == 'admin') {
        admins.add(user);
      } else if (role == 'independent') {
        independents.add(user);
      } else if (role == 'nutritionist' || role == 'personal_trainer' || role == 'coach') {
        expertDocs[uid] = user;
        if (!expertGroups.containsKey(uid)) expertGroups[uid] = [];
      } else if (role == 'user') {
        bool assigned = false;
        for (var sid in supervisorIds) {
          if (expertNameMap.containsKey(sid) || expertDocs.containsKey(sid)) {
            if (!expertGroups.containsKey(sid)) {
              expertGroups[sid] = [];
            }
            // avoid duplicating the user in the same group
            if (!expertGroups[sid]!.any((u) => u['uid'] == uid)) {
                expertGroups[sid]!.add(user);
            }
            assigned = true;
          }
        }
        if (!assigned) {
          independents.add(user);
        }
      }
    }

    return ListView(
      children: [
        ...expertGroups.entries.map((entry) {
          final expertId = entry.key;
          final clients = entry.value;
          final expertName = expertNameMap[expertId] ?? "Expert ID: $expertId";
          final expertDoc = expertDocs[expertId];
          final eRole = expertDoc?['role'] ?? 'nutritionist';

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PillExpansionTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getRoleColor(eRole).withValues(alpha: 0.15),
                  borderRadius: KyboBorderRadius.medium,
                ),
                child: Icon(
                  eRole == 'personal_trainer' ? Icons.fitness_center : Icons.health_and_safety,
                  color: _getRoleColor(eRole),
                ),
              ),
              title: expertName,
              subtitle: "${clients.length} Clienti",
              children: [
                if (expertDoc != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      height: 240,
                      child: _UserCard(
                        user: expertDoc,
                        onDelete: _deleteUser,
                        onUploadDiet: _uploadDiet,
                          onDropDiet: _uploadDroppedDiet,
                        onUploadParser: _uploadParser,
                        onHistory: (_) {},
                        onEdit: _editUser,
                        onAssign: null,
                        currentUserRole: _currentUserRole,
                        currentUserId: _currentUserId,
                        roleColor: _getRoleColor('nutritionist'),
                        clientCount: clients.length,
                      ),
                    ),
                  ),
                if (clients.isNotEmpty) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth <= 0) {
                        return const SizedBox.shrink();
                      }
                      final sectionKey = 'expert_$expertId';
                      final visibleClients =
                          clients.length > _visibleCount(sectionKey)
                              ? clients.sublist(0, _visibleCount(sectionKey))
                              : clients;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisExtent: 240,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: visibleClients.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (ctx, idx) {
                          final u = visibleClients[idx] as Map<String, dynamic>;
                          final uid = u['uid'] as String;
                          return _UserCard(
                            user: u,
                            onDelete: _deleteUser,
                            onUploadDiet: _uploadDiet,
                            onDropDiet: _uploadDroppedDiet,
                            onUploadParser: _uploadParser,
                            onHistory: (uid) => _showUserHistory(
                              uid,
                              u['first_name'] ?? 'Client',
                            ),
                            onEdit: _editUser,
                            onAssign: (uid) =>
                                _showManageAssignmentDialog(uid, expertNameMap),
                            onNotes: _showClientNotes,
                            onExportReport: _exportClientReport,
                            onShowDetail: _showUserDetail,
                            currentUserRole: _currentUserRole,
                            currentUserId: _currentUserId,
                            roleColor: _getRoleColor('user'),
                            selectable: true,
                            selectionMode: _selectionMode,
                            isSelected: _selectedUids.contains(uid),
                            onToggleSelect: () => _toggleSelection(u),
                          );
                        },
                      );
                    },
                  ),
                  _buildLoadMoreButton('expert_$expertId', clients.length),
                ],
              ],
            ),
          );
        }),

        if (independents.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PillExpansionTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KyboColors.roleIndependent.withValues(alpha: 0.15),
                  borderRadius: KyboBorderRadius.medium,
                ),
                child: Icon(
                  Icons.person_outline,
                  color: KyboColors.roleIndependent,
                ),
              ),
              title: "Utenti Indipendenti",
              subtitle: "${independents.length} Utenti",
              initiallyExpanded: false,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth <= 0) {
                      return const SizedBox.shrink();
                    }
                    final visIndep = independents.length >
                            _visibleCount('independents')
                        ? independents.sublist(0, _visibleCount('independents'))
                        : independents;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisExtent: 240,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: visIndep.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (ctx, idx) {
                        final u = visIndep[idx] as Map<String, dynamic>;
                        final uid = u['uid'] as String;
                        return _UserCard(
                          user: u,
                          onDelete: _deleteUser,
                          onUploadDiet: _uploadDiet,
                          onDropDiet: _uploadDroppedDiet,
                          onUploadParser: _uploadParser,
                          onHistory: (uid) => _showUserHistory(
                            uid,
                            u['first_name'] ?? 'User',
                          ),
                          onEdit: _editUser,
                          onAssign: (uid) => _assignUser(uid, expertNameMap),
                          onNotes: _showClientNotes,
                          onExportReport: _exportClientReport,
                          onShowDetail: _showUserDetail,
                          currentUserRole: _currentUserRole,
                          currentUserId: _currentUserId,
                          roleColor: _getRoleColor('independent'),
                          selectable: true,
                          selectionMode: _selectionMode,
                          isSelected: _selectedUids.contains(uid),
                          onToggleSelect: () => _toggleSelection(u),
                        );
                      },
                    );
                  },
                ),
                _buildLoadMoreButton('independents', independents.length),
              ],
            ),
          ),

        if (admins.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PillExpansionTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KyboColors.roleAdmin.withValues(alpha: 0.15),
                  borderRadius: KyboBorderRadius.medium,
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: KyboColors.roleAdmin,
                ),
              ),
              title: "Amministratori",
              subtitle: "${admins.length} Admin",
              initiallyExpanded: false,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth <= 0) {
                      return const SizedBox.shrink();
                    }
                    final visAdmins = admins.length > _visibleCount('admins')
                        ? admins.sublist(0, _visibleCount('admins'))
                        : admins;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisExtent: 240,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: visAdmins.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (ctx, idx) => _UserCard(
                        user: visAdmins[idx],
                        onDelete: _deleteUser,
                        onUploadDiet: _uploadDiet,
                          onDropDiet: _uploadDroppedDiet,
                        onUploadParser: _uploadParser,
                        onHistory: (_) {},
                        onEdit: _editUser,
                        onAssign: null,
                        currentUserRole: _currentUserRole,
                        currentUserId: _currentUserId,
                        roleColor: _getRoleColor('admin'),
                      ),
                    );
                  },
                ),
                _buildLoadMoreButton('admins', admins.length),
              ],
            ),
          ),
      ],
    );
  }
}

class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(String) onDelete;
  final Function(String) onUploadDiet;
  final Function(String, List<XFile>)? onDropDiet;
  final Function(String) onUploadParser;
  final Function(String) onHistory;
  final Function(String, String, String, String, Map<String, dynamic>) onEdit;
  final Function(String)? onAssign;
  final Function(String, String)? onNotes;
  final Function(String, Map<String, dynamic>)? onExportReport;
  final Function(Map<String, dynamic>)? onShowDetail;
  final String currentUserRole;
  final String currentUserId;
  final Color roleColor;
  // Multi-select: se selectable=true e l'utente clicca/long-press, viene
  // chiamato onToggleSelect. selectionMode rende visibile la checkbox.
  final bool selectable;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;

  const _UserCard({
    required this.user,
    required this.onDelete,
    required this.onUploadDiet,
    this.onDropDiet,
    required this.onUploadParser,
    required this.onHistory,
    required this.onEdit,
    this.onAssign,
    this.onNotes,
    this.onExportReport,
    this.onShowDetail,
    required this.currentUserRole,
    required this.currentUserId,
    required this.roleColor,
    this.clientCount,
    this.selectable = false,
    this.selectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
  });

  final int? clientCount;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _isUnlocked = false;
  bool _isUnlocking = false;
  bool _isDraggingOver = false;
  final AdminRepository _repo = AdminRepository();

  String _maskEmail(String email) => (email.length <= 4)
      ? "****"
      : "${email.split('@')[0][0]}***@***.${email.split('.').last}";
  String _maskName(String name) =>
      name.split(' ').map((p) => p.isNotEmpty ? "${p[0]}***" : "*").join(' ');

  Future<void> _unlockData() async {
    setState(() => _isUnlocking = true);
    try {
      await _repo.logDataAccess(widget.user['uid']);
      if (mounted) {
        setState(() => _isUnlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).userDataUnlocked),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${AppLocalizations.of(context).userUnlockFailed}: ${ErrorMapper.toUserMessage(e)}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.user;
    final uid = data['uid'] as String;
    final role = data['role'] ?? 'user';
    final realName = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}";
    final realEmail = data['email'] ?? '';

    final bool isAdmin = widget.currentUserRole == 'admin';
    final bool isMyClient =
        widget.currentUserRole == 'nutritionist' &&
        data['parent_id'] == widget.currentUserId;

    final bool shouldMask =
        !_isUnlocked &&
        ((isAdmin && (role == 'user' || role == 'independent')) ||
            (widget.currentUserRole == 'nutritionist' && !isMyClient));

    final String displayName = shouldMask ? _maskName(realName) : realName;
    final String displayEmail = shouldMask ? _maskEmail(realEmail) : realEmail;
    final requiresPassChange = data['requires_password_change'] == true;

    bool showParser =
        isAdmin &&
        (role == 'nutritionist' || role == 'independent' || role == 'admin');
    // showDiet abilita la SEZIONE "storico diete" (sola lettura). Visibile a
    // tutti i ruoli che la possono guardare (admin compreso → monitora).
    bool showDiet = (role == 'user' || role == 'independent');
    // canUploadDiet: il caricamento di una nuova dieta per il cliente è
    // operazione da nutrizionista. Admin guarda lo storico, non carica
    // diete personalmente.
    bool canUploadDiet = showDiet && !isAdmin;
    bool canDelete =
        isAdmin ||
        (role == 'user' && data['parent_id'] == widget.currentUserId);
    bool canEdit = isAdmin ||
        (data['created_by'] == widget.currentUserId);
    bool canAssign =
        (role == 'independent' || role == 'user') && widget.onAssign != null;
    // showNotes: le "note interne" sono appunti clinici del nutrizionista
    // sul cliente. Admin non scrive note (è osservatore).
    bool showNotes = (role == 'user' || role == 'independent')
        && widget.onNotes != null
        && !isAdmin;

    String dateStr = '-';
    if (data['created_at'] != null) {
      try {
        final d = DateTime.tryParse(data['created_at'].toString());
        if (d != null) dateStr = DateFormat('dd MMM yyyy').format(d);
      } catch (e) {
        debugPrint("Date parse error: $e");
      }
    }

    // Ultima attività (last_seen aggiornato dal client a ogni avvio).
    // Fallback a last_login se last_seen non presente. Inattivo >30gg → rosso.
    String? lastSeenLabel;
    Color lastSeenColor = KyboColors.textMuted;
    final lastSeenRaw = data['last_seen'] ?? data['last_login'];
    if (lastSeenRaw != null) {
      try {
        final d = DateTime.tryParse(lastSeenRaw.toString());
        if (d != null) {
          lastSeenLabel = timeago.format(d, locale: 'it');
          final days = DateTime.now().difference(d).inDays;
          if (days >= 30) {
            lastSeenColor = KyboColors.error;
          } else if (days >= 7) {
            lastSeenColor = KyboColors.warning;
          } else {
            lastSeenColor = KyboColors.success;
          }
        }
      } catch (_) {
        // Parsing data cosmetico (etichetta "ultimo accesso"): se fallisce
        // resta il fallback, nessun impatto per l'utente.
      }
    }

    // --- EXPIRING DIET CHECK ---
    bool isDietExpired = false;
    String? dietDateStr;
    if (showDiet && data['last_diet_update'] != null) {
      try {
        final lastUpdate = DateTime.tryParse(data['last_diet_update'].toString());
        if (lastUpdate != null) {
          dietDateStr = DateFormat('dd MMM').format(lastUpdate);
          final diff = DateTime.now().difference(lastUpdate).inDays;
          if (diff >= 30) {
            isDietExpired = true;
          }
        }
      } catch (_) {
        // Diet date parsing failed — non-critical, isDietExpired stays false
      }
    }

    final Widget rawCard = PillCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.roleColor.withValues(alpha: 0.12),
                  borderRadius: KyboBorderRadius.medium,
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty && !displayName.startsWith('*')
                        ? displayName[0].toUpperCase()
                        : "?",
                    style: TextStyle(
                      color: widget.roleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty
                          ? displayName
                          : AppLocalizations.of(context).user,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: KyboColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (role == 'nutritionist' && data['specializations'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "${data['specializations']}",
                          style: TextStyle(
                             color: KyboColors.primary,
                             fontSize: 11,
                             fontWeight: FontWeight.w500
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      displayEmail,
                      style: TextStyle(
                        color: KyboColors.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lastSeenLabel != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: lastSeenColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Attivo $lastSeenLabel",
                            style: TextStyle(
                              color: lastSeenColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isAdmin) ...[
                      const SizedBox(height: 2),
                      Text(
                        "${uid.substring(0, 8)}...",
                        style: TextStyle(
                          color: KyboColors.textMuted,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    if (role == 'nutritionist' && widget.clientCount != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "${widget.clientCount} / ${data['max_clients'] ?? 50} Clienti",
                          style: TextStyle(
                            color: KyboColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (shouldMask)
                _isUnlocking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: KyboColors.warning,
                        ),
                      )
                    : PillIconButton(
                        icon: Icons.lock_outline_rounded,
                        color: KyboColors.warning,
                        tooltip: AppLocalizations.of(context).unlockData,
                        onPressed: _unlockData,
                        size: 36,
                      ),

              const SizedBox(width: 8),

              PillBadge.role(role.toString()),
            ],
          ),

          const Spacer(),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (data['two_factor_enabled'] == true)
                PillBadge(
                  label: "2FA Attivo",
                  color: KyboColors.success,
                  icon: Icons.verified_user_rounded,
                  small: true,
                ),
              if (requiresPassChange)
                PillBadge(
                  label: AppLocalizations.of(context).passwordToChange,
                  color: KyboColors.warning,
                  icon: Icons.warning_amber_rounded,
                  small: true,
                ),
              if (isDietExpired)
                PillBadge(
                  label: AppLocalizations.of(context)
                      .dietExpiredWithDate(dietDateStr ?? '-'),
                  color: KyboColors.error,
                  icon: Icons.timer_off_outlined,
                  small: true,
                ),
            ],
          ),
          if (data['two_factor_enabled'] == true || requiresPassChange || isDietExpired)
            const SizedBox(height: 12),

          // Riga "Workout 7gg" — solo per clienti seguiti dal PT/admin.
          // Mostra completamenti recenti con emoji feedback. Errori → silenzioso.
          if (showDiet)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WorkoutActivityRow(uid: uid),
            ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: KyboColors.textMuted.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onShowDetail != null)
                  PillIconButton(
                    icon: Icons.info_outline_rounded,
                    color: KyboColors.primary,
                    tooltip: AppLocalizations.of(context).details,
                    onPressed: () => widget.onShowDetail!(data),
                    size: 36,
                  ),
                if (canAssign)
                  PillIconButton(
                    icon: role == 'user'
                        ? Icons.manage_accounts_rounded
                        : Icons.person_add_rounded,
                    color: KyboColors.accent,
                    tooltip: AppLocalizations.of(context).assign,
                    onPressed: () => widget.onAssign!(uid),
                    size: 36,
                  ),
                if (showNotes)
                  PillIconButton(
                    icon: Icons.note_alt_outlined,
                    color: KyboColors.primary,
                    tooltip: AppLocalizations.of(context).internalNotes,
                    onPressed: () => widget.onNotes!(uid, realName),
                    size: 36,
                  ),
                if (showDiet) ...[
                  PillIconButton(
                    icon: Icons.history_rounded,
                    color: KyboColors.primary,
                    tooltip: AppLocalizations.of(context).dietHistoryTooltip,
                    onPressed: () => widget.onHistory(uid),
                    size: 36,
                  ),
                  // Upload nascosto per admin (operazione da nutrizionista).
                  if (canUploadDiet)
                    PillIconButton(
                      icon: Icons.upload_file_rounded,
                      color: KyboColors.textSecondary,
                      tooltip: AppLocalizations.of(context).uploadDietTooltip,
                      onPressed: () => widget.onUploadDiet(uid),
                      size: 36,
                    ),
                  if (widget.onExportReport != null)
                    PillIconButton(
                      icon: Icons.picture_as_pdf_rounded,
                      color: KyboColors.error,
                      tooltip:
                          AppLocalizations.of(context).exportReportTooltip,
                      onPressed: () =>
                          widget.onExportReport!(uid, data),
                      size: 36,
                    ),
                ],
                if (showParser)
                  PillIconButton(
                    icon: Icons.settings_applications_rounded,
                    color: KyboColors.warning,
                    tooltip: "Parser Config",
                    onPressed: () => widget.onUploadParser(uid),
                    size: 36,
                  ),
                if (canEdit)
                  PillIconButton(
                    icon: Icons.edit_rounded,
                    color: KyboColors.accent,
                    tooltip: AppLocalizations.of(context).edit,
                    onPressed: () => widget.onEdit(
                      uid,
                      realEmail,
                      data['first_name'] ?? '',
                      data['last_name'] ?? '',
                      data,
                    ),
                    size: 36,
                  ),
                if (canDelete)
                  PillIconButton(
                    icon: Icons.delete_outline_rounded,
                    color: KyboColors.error,
                    tooltip: AppLocalizations.of(context).delete,
                    onPressed: () => widget.onDelete(uid),
                    size: 36,
                  ),
              ],
            ),
          ),

          Text(
            "Creato il: $dateStr",
            style: TextStyle(fontSize: 11, color: KyboColors.textMuted),
          ),
        ],
      ),
    );

    // Wrapper selezione: long-press apre la modalità multi-select; in
    // modalità selezione, tap toggla. Overlay con checkbox quando selezionato.
    Widget card = rawCard;
    if (widget.selectable && widget.onToggleSelect != null) {
      card = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: widget.onToggleSelect,
        onTap: widget.selectionMode ? widget.onToggleSelect : null,
        child: Stack(
          children: [
            // Bordo evidenziato quando selezionato.
            if (widget.isSelected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: KyboColors.primary.withValues(alpha: 0.08),
                      borderRadius: KyboBorderRadius.large,
                      border: Border.all(
                        color: KyboColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            rawCard,
            if (widget.selectionMode)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? KyboColors.primary
                        : KyboColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.isSelected
                          ? KyboColors.primary
                          : KyboColors.textMuted,
                      width: 1.5,
                    ),
                  ),
                  child: widget.isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
          ],
        ),
      );
    }

    // Drag & drop PDF dieta: solo per ruoli che possono ricevere diete.
    if (!showDiet || widget.onDropDiet == null) return card;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingOver = true),
      onDragExited: (_) => setState(() => _isDraggingOver = false),
      onDragDone: (detail) {
        setState(() => _isDraggingOver = false);
        if (detail.files.isEmpty) return;
        widget.onDropDiet!(uid, detail.files);
      },
      child: Stack(
        children: [
          card,
          if (_isDraggingOver)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: KyboColors.primary.withValues(alpha: 0.18),
                    borderRadius: KyboBorderRadius.large,
                    border: Border.all(
                      color: KyboColors.primary,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file_rounded,
                          size: 40,
                          color: KyboColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Rilascia il PDF della dieta",
                          style: TextStyle(
                            color: KyboColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserHistoryScreen extends StatefulWidget {
  final String targetUid;
  final String userName;
  const _UserHistoryScreen({required this.targetUid, required this.userName});
  @override
  State<_UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<_UserHistoryScreen> {
  final AdminRepository _repo = AdminRepository();
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _repo.getSecureUserHistory(widget.targetUid);
  }

  void _deleteDiet(BuildContext context, String dietId) async {
    final l10n = AppLocalizations.of(context);
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.dietDeleteTitle),
            content: Text(l10n.dietDeleteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _repo.deleteDiet(dietId);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.dietDeleted)));
          setState(
            () => _historyFuture = _repo.getSecureUserHistory(widget.targetUid),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(ErrorMapper.toUserMessage(e))));
        }
      }
    }
  }

  void _viewDiet(BuildContext context, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _DietDetailScreen(data: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background,
      appBar: AppBar(
        backgroundColor: KyboColors.surface,
        iconTheme: IconThemeData(color: KyboColors.textPrimary),
        title: Text(
          AppLocalizations.of(context).userHistoryTitle(widget.userName),
          style: TextStyle(color: KyboColors.textPrimary),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // [UX/SECURITY] Niente snapshot.error grezzo a schermo: messaggio
            // pulito + retry (ep5/ep7).
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: KyboColors.error, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).historyLoadError,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: KyboColors.textPrimary, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    PillButton(
                      label: AppLocalizations.of(context).retry,
                      icon: Icons.refresh_rounded,
                      onPressed: () => setState(() =>
                          _historyFuture =
                              _repo.getSecureUserHistory(widget.targetUid)),
                      backgroundColor: KyboColors.primary,
                      textColor: Colors.white,
                    ),
                  ],
                ),
              ),
            );
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context).dietNoneInHistory));
          }

          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (ctx, i) {
              final data = list[i] as Map<String, dynamic>;
              DateTime date =
                  DateTime.tryParse(data['uploadedAt'] ?? '') ?? DateTime.now();
              return ListTile(
                leading: const Icon(Icons.lock_clock, color: Colors.indigo),
                title: Text(data['fileName'] ?? "Dieta Protetta"),
                subtitle: Text(
                  AppLocalizations.of(context).uploadedOn(
                      DateFormat('dd MMM yyyy HH:mm').format(date)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.green),
                      onPressed: () => _viewDiet(context, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteDiet(context, data['id']),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DietDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DietDetailScreen({required this.data});

  @override
  Widget build(BuildContext context) {
    final parsedData = data['parsedData'] as Map<String, dynamic>?;
    final plan = parsedData?['plan'] as Map<String, dynamic>?;

    // [NON LOCALIZZARE] Questi non sono testi UI ma le CHIAVI del JSON del
    // piano dieta prodotte dal parser (plan["Lunedì"]...): tradurle
    // romperebbe il lookup indipendentemente dalla lingua dell'interfaccia.
    final orderedDays = [
      "Lunedì",
      "Martedì",
      "Mercoledì",
      "Giovedì",
      "Venerdì",
      "Sabato",
      "Domenica",
    ];

    return Scaffold(
      backgroundColor: KyboColors.background,
      appBar: AppBar(
        backgroundColor: KyboColors.surface,
        iconTheme: IconThemeData(color: KyboColors.textPrimary),
        title: Text(
          data['fileName'] ?? AppLocalizations.of(context).details,
          style: TextStyle(color: KyboColors.textPrimary),
        ),
      ),
      body: plan == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).protectedContent,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      AppLocalizations.of(context).contentUnavailable,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: orderedDays.map((day) {
                if (!plan.containsKey(day)) return const SizedBox.shrink();

                final meals = plan[day] as Map<String, dynamic>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: meals.entries.map((mEntry) {
                      final mealName = mEntry.key;
                      final dishes = mEntry.value as List<dynamic>;
                      return ListTile(
                        title: Text(
                          mealName,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: dishes
                              .map(
                                (d) => Text(
                                  "• ${d['name'] ?? '-'} ${d['qty'] ?? ''}",
                                ),
                              )
                              .toList(),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _ParserConfigScreen extends StatefulWidget {
  final String targetUid;
  const _ParserConfigScreen({required this.targetUid});

  @override
  State<_ParserConfigScreen> createState() => _ParserConfigScreenState();
}

class _ParserConfigScreenState extends State<_ParserConfigScreen> {
  final AdminRepository _repo = AdminRepository();
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPrompt();
  }

  Future<void> _loadExistingPrompt() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(widget.targetUid).get();
      if (doc.exists) {
        final data = doc.data();
        _promptController.text = data?['custom_parser_prompt'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("${AppLocalizations.of(context).userParserLoadError}: ${ErrorMapper.toUserMessage(e)}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPrompt() async {
    final l10n = AppLocalizations.of(context);
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userParserPromptRequired)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bytes = utf8.encode(_promptController.text);

      await _repo.uploadParserConfig(
        widget.targetUid,
        PlatformFile(
          name: 'custom_prompt.txt',
          size: bytes.length,
          bytes: Uint8List.fromList(bytes),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.userParserSaved)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ErrorMapper.toUserMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background,
      appBar: AppBar(
        backgroundColor: KyboColors.surface,
        iconTheme: IconThemeData(color: KyboColors.textPrimary),
        title: Text(
          AppLocalizations.of(context).userParserCustom,
          style: TextStyle(color: KyboColors.textPrimary),
        ),
        actions: [
          if (!_isLoading)
            IconButton(icon: const Icon(Icons.save), onPressed: _uploadPrompt),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).parserInstructionsTitle,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).parserInstructionsBody,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText:
                            AppLocalizations.of(context).parserInstructionsHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}

class _DietUploadProgressDialog extends StatefulWidget {
  const _DietUploadProgressDialog();

  @override
  State<_DietUploadProgressDialog> createState() =>
      _DietUploadProgressDialogState();
}

class _DietUploadProgressDialogState extends State<_DietUploadProgressDialog> {
  int _currentStep = 0;
  static const int _stepCount = 3;

  // [L10N] Le etichette si risolvono in build (serve il context per l10n).
  List<String> _steps(AppLocalizations l10n) => [
        l10n.progressUploadingPdf,
        l10n.progressReadingDoc,
        l10n.progressAiExtracting,
      ];

  @override
  void initState() {
    super.initState();
    _simulateProgress();
  }

  void _simulateProgress() async {
    for (int i = 0; i < _stepCount - 1; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _currentStep = i + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = _steps(l10n);
    final bool isFinalStep = _currentStep == _stepCount - 1;
    // [UX R4] Le prime fasi avanzano su timer (feedback immediato), ma
    // l'ultima — il parsing AI vero, che può durare minuti — passa a
    // indicatore INDETERMINATO: una percentuale finta ferma al 100%
    // comunica "bloccato" peggio di un anello che gira.
    final double? progress =
        isFinalStep ? null : (_currentStep + 1) / _stepCount;

    return AlertDialog(
      backgroundColor: KyboColors.surface,
      shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: KyboColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(KyboColors.primary),
                ),
              ),
              if (progress != null)
                Text(
                  "${(progress * 100).toInt()}%",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: KyboColors.textPrimary,
                  ),
                )
              else
                Icon(Icons.auto_awesome_rounded,
                    color: KyboColors.primary, size: 28),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            steps[_currentStep],
            style: TextStyle(fontSize: 16, color: KyboColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          if (isFinalStep) ...[
            const SizedBox(height: 8),
            Text(
              l10n.progressLongPdfWarning,
              style: TextStyle(fontSize: 12, color: KyboColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: KyboColors.border,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.stepOf(_currentStep + 1, _stepCount),
            style: TextStyle(fontSize: 12, color: KyboColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CLIENT NOTES SCREEN
// ══════════════════════════════════════════════════════════════════════════

class _ClientNotesScreen extends StatefulWidget {
  final String clientUid;
  final String clientName;

  const _ClientNotesScreen({
    required this.clientUid,
    required this.clientName,
  });

  @override
  State<_ClientNotesScreen> createState() => _ClientNotesScreenState();
}

class _ClientNotesScreenState extends State<_ClientNotesScreen> {
  final AdminRepository _repo = AdminRepository();
  late Future<List<dynamic>> _notesFuture;
  bool _isLoading = false;

  static const _categories = [
    {'value': 'general', 'label': 'Generale', 'icon': Icons.notes_rounded, 'color': Colors.blue},
    {'value': 'medical', 'label': 'Medico', 'icon': Icons.medical_services_rounded, 'color': Colors.red},
    {'value': 'dietary', 'label': 'Alimentare', 'icon': Icons.restaurant_rounded, 'color': Colors.green},
    {'value': 'follow-up', 'label': 'Follow-up', 'icon': Icons.event_note_rounded, 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _notesFuture = _repo.getClientNotes(widget.clientUid);
  }

  void _refreshNotes() {
    setState(() {
      _notesFuture = _repo.getClientNotes(widget.clientUid);
    });
  }

  Map<String, dynamic> _getCategoryInfo(String category) {
    return _categories.firstWhere(
      (c) => c['value'] == category,
      orElse: () => _categories.first,
    );
  }

  Future<void> _showAddNoteDialog() async {
    final contentCtrl = TextEditingController();
    String selectedCategory = 'general';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: KyboColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppLocalizations.of(context).noteNew,
            style: TextStyle(color: KyboColors.textPrimary),
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).locale.languageCode == 'it'
                      ? "Categoria"
                      : "Category",
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = selectedCategory == cat['value'];
                    return ChoiceChip(
                      label: Text(cat['label'] as String),
                      avatar: Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : cat['color'] as Color,
                      ),
                      selected: isSelected,
                      selectedColor: cat['color'] as Color,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : KyboColors.textPrimary,
                      ),
                      onSelected: (_) {
                        setDialogState(() => selectedCategory = cat['value'] as String);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  style: TextStyle(color: KyboColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).locale.languageCode == 'it'
                        ? "Scrivi la nota..."
                        : "Write the note...",
                    hintStyle: TextStyle(color: KyboColors.textMuted),
                    filled: true,
                    fillColor: KyboColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KyboColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KyboColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KyboColors.primary, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).cancel, style: TextStyle(color: KyboColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                if (contentCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _repo.createClientNote(
                    clientUid: widget.clientUid,
                    content: contentCtrl.text.trim(),
                    category: selectedCategory,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context).noteCreated)),
                    );
                    _refreshNotes();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ErrorMapper.toUserMessage(e)), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(Map<String, dynamic> note) async {
    final contentCtrl = TextEditingController(text: note['content'] ?? '');
    String selectedCategory = note['category'] ?? 'general';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: KyboColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppLocalizations.of(ctx).edit,
            style: TextStyle(color: KyboColors.textPrimary),
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).locale.languageCode == 'it'
                      ? "Categoria"
                      : "Category",
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = selectedCategory == cat['value'];
                    return ChoiceChip(
                      label: Text(cat['label'] as String),
                      avatar: Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : cat['color'] as Color,
                      ),
                      selected: isSelected,
                      selectedColor: cat['color'] as Color,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : KyboColors.textPrimary,
                      ),
                      onSelected: (_) {
                        setDialogState(() => selectedCategory = cat['value'] as String);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  style: TextStyle(color: KyboColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).locale.languageCode == 'it'
                        ? "Scrivi la nota..."
                        : "Write the note...",
                    hintStyle: TextStyle(color: KyboColors.textMuted),
                    filled: true,
                    fillColor: KyboColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KyboColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KyboColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KyboColors.primary, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).cancel, style: TextStyle(color: KyboColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                if (contentCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _repo.updateClientNote(
                    clientUid: widget.clientUid,
                    noteId: note['id'],
                    content: contentCtrl.text.trim(),
                    category: selectedCategory,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context).noteUpdated)),
                    );
                    _refreshNotes();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ErrorMapper.toUserMessage(e)), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNote(String noteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(AppLocalizations.of(c).noteDeleteTitle),
        content: Text(AppLocalizations.of(c).noteDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(AppLocalizations.of(c).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: Text(AppLocalizations.of(c).delete),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await _repo.deleteClientNote(
        clientUid: widget.clientUid,
        noteId: noteId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).noteDeleted)),
        );
        _refreshNotes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMapper.toUserMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePin(Map<String, dynamic> note) async {
    try {
      await _repo.updateClientNote(
        clientUid: widget.clientUid,
        noteId: note['id'],
        pinned: !(note['pinned'] == true),
      );
      _refreshNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMapper.toUserMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background,
      appBar: AppBar(
        backgroundColor: KyboColors.surface,
        iconTheme: IconThemeData(color: KyboColors.textPrimary),
        title: Text(
          AppLocalizations.of(context).noteForClient(widget.clientName),
          style: TextStyle(color: KyboColors.textPrimary),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: AppLocalizations.of(context).noteNew,
              onPressed: _showAddNoteDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _notesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonUserList(itemCount: 4);
                }
                if (snapshot.hasError) {
                  // [UX R5] Niente snapshot.error grezzo: messaggio mappato
                  // + retry in-page.
                  return KyboErrorView.fromError(
                    snapshot.error!,
                    onRetry: () => setState(() {
                      _notesFuture = _repo.getClientNotes(widget.clientUid);
                    }),
                  );
                }

                final notes = snapshot.data ?? [];
                if (notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).noInternalNotes,
                          style: const TextStyle(
                              fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _showAddNoteDialog,
                          icon: const Icon(Icons.add),
                          label: Text(AppLocalizations.of(context).noteAdd),
                        ),
                      ],
                    ),
                  );
                }

                final sorted = List<dynamic>.from(notes);
                sorted.sort((a, b) {
                  final aPinned = a['pinned'] == true ? 0 : 1;
                  final bPinned = b['pinned'] == true ? 0 : 1;
                  if (aPinned != bPinned) return aPinned.compareTo(bPinned);
                  return 0;
                });

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final note = sorted[i] as Map<String, dynamic>;
                    final catInfo = _getCategoryInfo(note['category'] ?? 'general');
                    final isPinned = note['pinned'] == true;

                    String dateStr = '';
                    if (note['updated_at'] != null) {
                      try {
                        final d = DateTime.tryParse(note['updated_at'].toString());
                        if (d != null) dateStr = DateFormat('dd MMM yyyy HH:mm').format(d);
                      } catch (_) {
                        // Data cosmetica della nota: fallback stringa vuota.
                      }
                    }

                    return Card(
                      elevation: isPinned ? 3 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isPinned
                            ? BorderSide(color: KyboColors.warning, width: 2)
                            : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  catInfo['icon'] as IconData,
                                  size: 18,
                                  color: catInfo['color'] as Color,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (catInfo['color'] as Color).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    catInfo['label'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: catInfo['color'] as Color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isPinned) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.push_pin, size: 14, color: KyboColors.warning),
                                ],
                                const Spacer(),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              note['content'] ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                    size: 18,
                                  ),
                                  color: isPinned ? KyboColors.warning : Colors.grey,
                                  tooltip: isPinned ? "Rimuovi pin" : "Fissa",
                                  onPressed: () => _togglePin(note),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  color: KyboColors.primary,
                                  tooltip: AppLocalizations.of(context).edit,
                                  onPressed: () => _editNote(note),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                  color: Colors.red,
                                  tooltip: AppLocalizations.of(context).delete,
                                  onPressed: () => _deleteNote(note['id']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini badge "7gg" per la card utente: legge gli ultimi 7 documenti
/// di workout_completions e mostra una timeline con emoji feedback.
/// Errori e lista vuota → SizedBox.shrink (silenzioso, opzionale).
class _WorkoutActivityRow extends StatelessWidget {
  final String uid;
  const _WorkoutActivityRow({required this.uid});

  static const _ratingEmoji = {
    'easy': '😅',
    'ok': '👌',
    'hard': '🔥',
  };

  Future<List<Map<String, dynamic>>> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('workout_completions')
        .orderBy('completed_at', descending: true)
        .limit(7)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'feedback': data['feedback'],
        'completed_at': data['completed_at'],
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final items = snapshot.data!;
        if (items.isEmpty) return const SizedBox.shrink();

        // Ultimo feedback (primo della lista, ordinata desc)
        final lastFeedback = items
            .firstWhere(
              (e) => e['feedback'] != null,
              orElse: () => <String, dynamic>{},
            )['feedback'] as String?;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: KyboColors.primary.withValues(alpha: 0.06),
            borderRadius: KyboBorderRadius.medium,
          ),
          child: Row(
            children: [
              Icon(
                Icons.fitness_center_rounded,
                size: 16,
                color: KyboColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                "${items.length}/7 allenamenti",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KyboColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              if (lastFeedback != null) ...[
                Text(
                  _ratingEmoji[lastFeedback] ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  "ultimo",
                  style: TextStyle(
                    fontSize: 10,
                    color: KyboColors.textMuted,
                  ),
                ),
              ] else
                Text(
                  "nessun feedback",
                  style: TextStyle(
                    fontSize: 10,
                    color: KyboColors.textMuted,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Pannello dettaglio user mostrato a destra in modalità split-view (>1100px).
// Mostra avatar grande, info base, badge e azioni rapide. Per dati GDPR-sensibili
// (storico diete, note) ci sono pulsanti "Apri" che riusano i dialog esistenti.
class _UserDetailPane extends StatelessWidget {
  final Map<String, dynamic> user;
  final Color roleColor;
  final VoidCallback onClose;
  final VoidCallback onOpenChat;
  final VoidCallback onShowHistory;

  const _UserDetailPane({
    required this.user,
    required this.roleColor,
    required this.onClose,
    required this.onOpenChat,
    required this.onShowHistory,
  });

  @override
  Widget build(BuildContext context) {
    final name = "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim();
    final email = (user['email'] ?? '').toString();
    final role = (user['role'] ?? 'user').toString();
    final uid = (user['uid'] ?? '').toString();
    final createdAt = user['created_at']?.toString();
    final lastSeen = (user['last_seen'] ?? user['last_login'])?.toString();
    final lastDiet = user['last_diet_update']?.toString();

    return PillCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, color: roleColor, size: 22),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).clientDetailTitle,
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              PillIconButton(
                icon: Icons.close_rounded,
                color: KyboColors.textSecondary,
                tooltip: AppLocalizations.of(context).close,
                onPressed: onClose,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar grande + nome
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: KyboBorderRadius.medium,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty
                          ? AppLocalizations.of(context).clientUnnamed
                          : name,
                      style: TextStyle(
                        color: KyboColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: KyboColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    PillBadge.role(role),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: KyboColors.border, height: 1),
          const SizedBox(height: 12),

          // Info table
          _detailRow('UID', uid.isEmpty ? '-' : uid, mono: true),
          _detailRow(
              AppLocalizations.of(context).clientCreated, _fmtDate(createdAt)),
          _detailRow(AppLocalizations.of(context).clientLastActivity,
              _fmtDate(lastSeen)),
          _detailRow(
              AppLocalizations.of(context).clientLastDiet, _fmtDate(lastDiet)),

          const SizedBox(height: 16),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: AppLocalizations.of(context).clientHistory,
                  icon: Icons.history_rounded,
                  backgroundColor: KyboColors.primary,
                  textColor: Colors.white,
                  height: 38,
                  onPressed: onShowHistory,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PillButton(
                  label: AppLocalizations.of(context).closeUpper,
                  icon: Icons.close_rounded,
                  backgroundColor: KyboColors.background,
                  textColor: KyboColors.textPrimary,
                  height: 38,
                  onPressed: onOpenChat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: KyboColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontSize: 12,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy HH:mm').format(dt);
  }
}
