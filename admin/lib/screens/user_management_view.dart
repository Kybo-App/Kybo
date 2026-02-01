import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin_repository.dart';
import '../widgets/design_system.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final AdminRepository _repo = AdminRepository();
  bool _isLoading = false;

  // UI Filters
  String _searchQuery = "";
  String _roleFilter = "all";
  final TextEditingController _searchCtrl = TextEditingController();

  // Current User Data
  String _currentUserId = '';
  String _currentUserRole = '';
  bool _isDataLoaded = false;

  // DATI UTENTI (Ora scaricati via API Secure)
  Future<List<dynamic>>? _usersFuture;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  // UPDATED: Usa i claims del token, zero letture DB!
  Future<void> _checkCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Forza il refresh del token per avere i claims aggiornati
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
        // Fallback in caso di errore di rete
        if (mounted) setState(() => _isDataLoaded = true);
      }
    }
  }

  void _refreshList() {
    setState(() {
      _usersFuture = _repo.getSecureUsersList();
    });
  }

  // --- ACTIONS ---

  Future<void> _syncUsers() async {
    setState(() => _isLoading = true);
    try {
      String msg = await _repo.syncUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.blue),
        );
        _refreshList(); // Ricarica lista dopo sync
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync Error: $e"),
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
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Elimina Utente"),
            content: const Text(
              "Sei sicuro? L'azione è irreversibile e verrà loggata.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Annulla"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(c, true),
                child: const Text("Elimina"),
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
          ).showSnackBar(const SnackBar(content: Text("Utente eliminato.")));
          _refreshList(); // Ricarica lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Errore: $e")));
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
      // Mostra dialog con progress
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _DietUploadProgressDialog(),
      );

      try {
        await _repo.uploadDietForUser(targetUid, result.files.single);
        if (mounted) {
          Navigator.of(context).pop(); // Chiudi dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Dieta caricata!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Chiudi dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Errore upload: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  Future<void> _editUser(
    String uid,
    String currentEmail,
    String currentFirst,
    String currentLast,
  ) async {
    final emailCtrl = TextEditingController(text: currentEmail);
    final firstCtrl = TextEditingController(text: currentFirst);
    final lastCtrl = TextEditingController(text: currentLast);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifica Account"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstCtrl,
              decoration: const InputDecoration(labelText: "Nome"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lastCtrl,
              decoration: const InputDecoration(labelText: "Cognome"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Email"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annulla"),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _repo.updateUser(
                  uid,
                  email: emailCtrl.text,
                  firstName: firstCtrl.text,
                  lastName: lastCtrl.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Utente aggiornato")),
                  );
                  _refreshList(); // Ricarica
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Errore: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("Salva"),
          ),
        ],
      ),
    );
  }

  // --- ASSIGNMENT LOGIC ---

  Future<void> _assignUser(
    String targetUid,
    Map<String, String> nutritionists,
  ) async {
    String? selectedNutId;
    if (nutritionists.isNotEmpty) selectedNutId = nutritionists.keys.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text("Assegna a Nutrizionista"),
          content: DropdownButtonFormField<String>(
            initialValue: selectedNutId,
            isExpanded: true,
            items: nutritionists.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setDialogState(() => selectedNutId = v),
            decoration: const InputDecoration(
              labelText: "Seleziona Nutrizionista",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annulla"),
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
                      const SnackBar(content: Text("Utente assegnato!")),
                    );
                    _refreshList(); // Ricarica
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Errore: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text("Assegna"),
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

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text("Gestisci Assegnazione"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Sposta utente ad un altro nutrizionista:",
                style: TextStyle(fontWeight: FontWeight.bold),
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
                decoration: const InputDecoration(
                  labelText: "Nuovo Nutrizionista",
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_off, color: Colors.red),
                label: const Text(
                  "Rimuovi Assegnazione",
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  try {
                    await _repo.unassignUser(targetUid);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Assegnazione rimossa.")),
                      );
                      _refreshList(); // Ricarica
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Errore: $e")));
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
              child: const Text("Annulla"),
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
                      const SnackBar(content: Text("Utente trasferito!")),
                    );
                    _refreshList(); // Ricarica
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Errore: $e")));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text("Sposta"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateUserDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    String role = 'user';

    List<DropdownMenuItem<String>> allowedRoles = [
      const DropdownMenuItem(value: 'user', child: Text("Cliente")),
    ];

    if (_currentUserRole == 'admin') {
      allowedRoles.addAll([
        const DropdownMenuItem(
          value: 'nutritionist',
          child: Text("Nutrizionista"),
        ),
        const DropdownMenuItem(
          value: 'independent',
          child: Text("Indipendente"),
        ),
        const DropdownMenuItem(value: 'admin', child: Text("Admin")),
      ]);
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text("Nuovo Utente"),
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
                          decoration: const InputDecoration(labelText: "Nome"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: surnameCtrl,
                          decoration: const InputDecoration(
                            labelText: "Cognome",
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(
                      labelText: "Password Temp",
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: "Ruolo"),
                    items: allowedRoles,
                    onChanged: (v) => setDialogState(() => role = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annulla"),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _repo.createUser(
                    email: emailCtrl.text,
                    password: passCtrl.text,
                    role: role,
                    firstName: nameCtrl.text,
                    lastName: surnameCtrl.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Utente creato!")),
                    );
                    _refreshList(); // Ricarica
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Errore: $e")));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text("Crea"),
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
      case 'independent':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return Center(
        child: CircularProgressIndicator(color: KyboColors.primary),
      );
    }

    return Column(
      children: [
        // ═══════════════════════════════════════════════════════════════════
        // TOP TOOLBAR - Pill-shaped container
        // ═══════════════════════════════════════════════════════════════════
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
              // 1. BARRA DI RICERCA (Per Tutti)
              Expanded(
                flex: 2,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: KyboColors.background,
                    borderRadius: KyboBorderRadius.pill,
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                    style: TextStyle(color: KyboColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Cerca utente per nome o email...",
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 2. FILTRO RUOLI (Solo Admin)
              if (_currentUserRole == 'admin') ...[
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: KyboColors.background,
                    borderRadius: KyboBorderRadius.pill,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _roleFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text("Tutti i Ruoli"),
                        ),
                        DropdownMenuItem(value: 'user', child: Text("Clienti")),
                        DropdownMenuItem(
                          value: 'nutritionist',
                          child: Text("Nutrizionisti"),
                        ),
                        DropdownMenuItem(
                          value: 'independent',
                          child: Text("Indipendenti"),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text("Admin")),
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

              // 3. REFRESH (Per Tutti)
              PillIconButton(
                icon: Icons.refresh_rounded,
                color: KyboColors.primary,
                tooltip: "Ricarica Lista",
                onPressed: _refreshList,
              ),

              // 4. SYNC DB (Solo Admin)
              if (_currentUserRole == 'admin') ...[
                const SizedBox(width: 4),
                PillIconButton(
                  icon: Icons.sync_rounded,
                  color: KyboColors.accent,
                  tooltip: "Sync DB",
                  onPressed: _isLoading ? null : _syncUsers,
                ),
              ],

              const SizedBox(width: 12),

              // 5. TASTO NUOVO UTENTE (Admin E Nutrizionista)
              if (_currentUserRole == 'admin' ||
                  _currentUserRole == 'nutritionist')
                PillButton(
                  label: "NUOVO UTENTE",
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

        // Loading indicator
        if (_isLoading)
          LinearProgressIndicator(
            backgroundColor: KyboColors.background,
            valueColor: AlwaysStoppedAnimation(KyboColors.primary),
          ),

        const SizedBox(height: 16),

        // --- CONTENT ---
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Errore Caricamento: ${snapshot.error}',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    "Nessun utente trovato.",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              var allUsers = snapshot.data!;
              final nutNameMap = <String, String>{};
              for (var u in allUsers) {
                if (u['role'] == 'nutritionist') {
                  nutNameMap[u['uid']] =
                      "${u['first_name'] ?? ''} ${u['last_name'] ?? ''}".trim();
                  if (nutNameMap[u['uid']]!.isEmpty) {
                    nutNameMap[u['uid']] = u['email'] ?? 'Unknown';
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
                return const Center(
                  child: Text(
                    "Nessun utente corrisponde alla ricerca.",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              if (_currentUserRole == 'admin') {
                return _buildAdminGroupedLayout(filteredUsers, nutNameMap);
              } else {
                return _buildUserGrid(filteredUsers);
              }
            },
          ),
        ),
      ],
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
        return _UserCard(
          user: users[index],
          onDelete: (uid) => _deleteUser(uid),
          onUploadDiet: _uploadDiet,
          onUploadParser: _uploadParser,
          onHistory: (uid) =>
              _showUserHistory(uid, users[index]['first_name'] ?? 'User'),
          onEdit: _editUser,
          onAssign: null,
          currentUserRole: _currentUserRole,
          currentUserId: _currentUserId,
          roleColor: _getRoleColor(users[index]['role'] ?? 'user'),
        );
      },
    );
  }

  Widget _buildAdminGroupedLayout(
    List<dynamic> users,
    Map<String, String> nutNameMap,
  ) {
    final admins = <dynamic>[];
    final independents = <dynamic>[];
    final nutritionistGroups = <String, List<dynamic>>{};
    final nutritionistDocs = <String, dynamic>{};

    for (var user in users) {
      final role = (user['role'] ?? 'user').toString().toLowerCase();
      final parentId =
          user['parent_id'] as String? ?? user['created_by'] as String?;
      final uid = user['uid'] as String;

      if (role == 'admin') {
        admins.add(user);
      } else if (role == 'independent') {
        independents.add(user);
      } else if (role == 'nutritionist') {
        nutritionistDocs[uid] = user;
        if (!nutritionistGroups.containsKey(uid)) nutritionistGroups[uid] = [];
      } else if (role == 'user') {
        if (parentId != null &&
            (nutNameMap.containsKey(parentId) ||
                nutritionistDocs.containsKey(parentId))) {
          if (!nutritionistGroups.containsKey(parentId)) {
            nutritionistGroups[parentId] = [];
          }
          nutritionistGroups[parentId]!.add(user);
        } else {
          independents.add(user);
        }
      }
    }

    return ListView(
      children: [
        ...nutritionistGroups.entries.map((entry) {
          final nutId = entry.key;
          final clients = entry.value;
          final nutName = nutNameMap[nutId] ?? "Nutritionist ID: $nutId";
          final nutDoc = nutritionistDocs[nutId];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PillExpansionTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KyboColors.roleNutritionist.withValues(alpha: 0.15),
                  borderRadius: KyboBorderRadius.medium,
                ),
                child: Icon(
                  Icons.health_and_safety,
                  color: KyboColors.roleNutritionist,
                ),
              ),
              title: nutName,
              subtitle: "${clients.length} Clienti",
              children: [
                if (nutDoc != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      height: 240,
                      child: _UserCard(
                        user: nutDoc,
                        onDelete: _deleteUser,
                        onUploadDiet: _uploadDiet,
                        onUploadParser: _uploadParser,
                        onHistory: (_) {},
                        onEdit: _editUser,
                        onAssign: null,
                        currentUserRole: _currentUserRole,
                        currentUserId: _currentUserId,
                        roleColor: _getRoleColor('nutritionist'),
                      ),
                    ),
                  ),
                if (clients.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisExtent: 240,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: clients.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (ctx, idx) => _UserCard(
                      user: clients[idx],
                      onDelete: _deleteUser,
                      onUploadDiet: _uploadDiet,
                      onUploadParser: _uploadParser,
                      onHistory: (uid) => _showUserHistory(
                        uid,
                        clients[idx]['first_name'] ?? 'Client',
                      ),
                      onEdit: _editUser,
                      onAssign: (uid) =>
                          _showManageAssignmentDialog(uid, nutNameMap),
                      currentUserRole: _currentUserRole,
                      currentUserId: _currentUserId,
                      roleColor: _getRoleColor('user'),
                    ),
                  ),
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
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 240,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: independents.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (ctx, idx) => _UserCard(
                    user: independents[idx],
                    onDelete: _deleteUser,
                    onUploadDiet: _uploadDiet,
                    onUploadParser: _uploadParser,
                    onHistory: (uid) => _showUserHistory(
                      uid,
                      independents[idx]['first_name'] ?? 'User',
                    ),
                    onEdit: _editUser,
                    onAssign: (uid) => _assignUser(uid, nutNameMap),
                    currentUserRole: _currentUserRole,
                    currentUserId: _currentUserId,
                    roleColor: _getRoleColor('independent'),
                  ),
                ),
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
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 240,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: admins.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (ctx, idx) => _UserCard(
                    user: admins[idx],
                    onDelete: _deleteUser,
                    onUploadDiet: _uploadDiet,
                    onUploadParser: _uploadParser,
                    onHistory: (_) {},
                    onEdit: _editUser,
                    onAssign: null,
                    currentUserRole: _currentUserRole,
                    currentUserId: _currentUserId,
                    roleColor: _getRoleColor('admin'),
                  ),
                ),
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
  final Function(String) onUploadParser;
  final Function(String) onHistory;
  final Function(String, String, String, String) onEdit;
  final Function(String)? onAssign;
  final String currentUserRole;
  final String currentUserId;
  final Color roleColor;

  const _UserCard({
    required this.user,
    required this.onDelete,
    required this.onUploadDiet,
    required this.onUploadParser,
    required this.onHistory,
    required this.onEdit,
    this.onAssign,
    required this.currentUserRole,
    required this.currentUserId,
    required this.roleColor,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _isUnlocked = false;
  bool _isUnlocking = false;
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
          const SnackBar(
            content: Text("Dati sbloccati."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossibile sbloccare: $e"),
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

    // Privacy Logic
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
    bool showDiet = (role == 'user' || role == 'independent');
    bool canDelete =
        isAdmin ||
        (role == 'user' && data['parent_id'] == widget.currentUserId);
    bool canEdit =
        requiresPassChange &&
        (isAdmin || data['created_by'] == widget.currentUserId);
    bool canAssign =
        (role == 'independent' || role == 'user') && widget.onAssign != null;

    String dateStr = '-';
    if (data['created_at'] != null) {
      try {
        final d = DateTime.tryParse(data['created_at'].toString());
        if (d != null) dateStr = DateFormat('dd MMM yyyy').format(d);
      } catch (e) {
        debugPrint("Date parse error: $e");
      }
    }

    return PillCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─────────────────────────────────────────────────────────────────
          // HEADER: Avatar + Info + Badge
          // ─────────────────────────────────────────────────────────────────
          Row(
            children: [
              // Avatar
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

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty ? displayName : "Utente",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: KyboColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                  ],
                ),
              ),

              // Lock button
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
                        tooltip: "Sblocca Dati",
                        onPressed: _unlockData,
                        size: 36,
                      ),

              const SizedBox(width: 8),

              // Role Badge
              PillBadge.role(role.toString()),
            ],
          ),

          const Spacer(),

          // ─────────────────────────────────────────────────────────────────
          // STATUS BADGES
          // ─────────────────────────────────────────────────────────────────
          if (requiresPassChange)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: PillBadge(
                label: "Password da cambiare",
                color: KyboColors.warning,
                icon: Icons.warning_amber_rounded,
                small: true,
              ),
            ),

          // ─────────────────────────────────────────────────────────────────
          // ACTIONS ROW
          // ─────────────────────────────────────────────────────────────────
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
                if (canAssign)
                  PillIconButton(
                    icon: role == 'user'
                        ? Icons.manage_accounts_rounded
                        : Icons.person_add_rounded,
                    color: KyboColors.accent,
                    tooltip: "Assegna",
                    onPressed: () => widget.onAssign!(uid),
                    size: 36,
                  ),
                if (showDiet) ...[
                  PillIconButton(
                    icon: Icons.history_rounded,
                    color: KyboColors.primary,
                    tooltip: "Storico Diete",
                    onPressed: () => widget.onHistory(uid),
                    size: 36,
                  ),
                  PillIconButton(
                    icon: Icons.upload_file_rounded,
                    color: KyboColors.textSecondary,
                    tooltip: "Carica Dieta",
                    onPressed: () => widget.onUploadDiet(uid),
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
                    tooltip: "Modifica",
                    onPressed: () => widget.onEdit(
                      uid,
                      realEmail,
                      data['first_name'] ?? '',
                      data['last_name'] ?? '',
                    ),
                    size: 36,
                  ),
                if (canDelete)
                  PillIconButton(
                    icon: Icons.delete_outline_rounded,
                    color: KyboColors.error,
                    tooltip: "Elimina",
                    onPressed: () => widget.onDelete(uid),
                    size: 36,
                  ),
              ],
            ),
          ),

          // ─────────────────────────────────────────────────────────────────
          // FOOTER
          // ─────────────────────────────────────────────────────────────────
          Text(
            "Creato il: $dateStr",
            style: TextStyle(fontSize: 11, color: KyboColors.textMuted),
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

  // UPDATED: Usa l'API sicura per cancellare
  void _deleteDiet(BuildContext context, String dietId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Elimina Dieta"),
            content: const Text("Questa azione è irreversibile. Confermi?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Annulla"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(c, true),
                child: const Text("Elimina"),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _repo.deleteDiet(dietId); // <--- API CALL
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Dieta eliminata")));
          setState(
            () => _historyFuture = _repo.getSecureUserHistory(widget.targetUid),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Errore: $e")));
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
      appBar: AppBar(title: Text("Storico (Secure): ${widget.userName}")),
      body: FutureBuilder<List<dynamic>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Errore Audit Log: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text("Nessuna dieta presente."));
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
                  "Caricato il: ${DateFormat('dd MMM yyyy HH:mm').format(date)}",
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

    // Lista ordinata per forzare la sequenza corretta
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
      appBar: AppBar(title: Text(data['fileName'] ?? "Dettaglio")),
      body: plan == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.security, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Contenuto Protetto",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Il contenuto non è disponibile o è stato rimosso.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: orderedDays.map((day) {
                // Se il giorno non esiste nel piano (es. dieta di 5 giorni), lo saltiamo
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
        ).showSnackBar(SnackBar(content: Text("Errore caricamento: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPrompt() async {
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inserisci un prompt personalizzato")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bytes = utf8.encode(_promptController.text);

      // Upload tramite repository (direttamente dai bytes, senza file temporanei)
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
          const SnackBar(content: Text("Parser personalizzato salvato!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Errore: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parser Personalizzato"),
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
                  const Text(
                    "Istruzioni per Gemini AI",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Definisci come Gemini deve interpretare i PDF di questo nutrizionista. "
                    "Esempio: 'I pasti sono sempre indicati con emoji 🍽️' oppure 'Le quantità sono in once invece che grammi'.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Inserisci le istruzioni personalizzate...",
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
  final List<String> _steps = [
    "Caricamento PDF...",
    "Analisi documento...",
    "Estrazione dati...",
    "Elaborazione finale...",
  ];

  @override
  void initState() {
    super.initState();
    _simulateProgress();
  }

  void _simulateProgress() async {
    for (int i = 0; i < _steps.length - 1; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _currentStep = i + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_currentStep + 1) / _steps.length;

    return AlertDialog(
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
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _steps[_currentStep],
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
          ),
          const SizedBox(height: 8),
          Text(
            "Step ${_currentStep + 1} di ${_steps.length}",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
