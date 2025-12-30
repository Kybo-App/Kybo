import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserId = user.uid;
          _currentUserRole = data['role'] ?? 'user';
          _isDataLoaded = true;
        });
      }
    }
  }

  Stream<QuerySnapshot> _getUsersStream() {
    final usersRef = FirebaseFirestore.instance.collection('users');
    if (_currentUserRole == 'admin') {
      return usersRef.snapshots();
    } else if (_currentUserRole == 'nutritionist') {
      return usersRef
          .where('created_by', isEqualTo: _currentUserId)
          .snapshots();
    } else {
      return const Stream.empty();
    }
  }

  // --- ACTIONS ---

  Future<void> _syncUsers() async {
    setState(() => _isLoading = true);
    try {
      String msg = await _repo.syncUsers();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.blue),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
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
            content: const Text("Sei sicuro? L'azione è irreversibile."),
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
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Utente eliminato.")));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Errore: $e")));
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
      setState(() => _isLoading = true);
      try {
        await _repo.uploadDietForUser(targetUid, result.files.single);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Dieta caricata!"),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Errore upload: $e"),
              backgroundColor: Colors.red,
            ),
          );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadParser(String targetUid) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() => _isLoading = true);
      try {
        await _repo.uploadParserConfig(targetUid, result.files.single);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Parser caricato!"),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Errore parser: $e"),
              backgroundColor: Colors.red,
            ),
          );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
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
        builder: (context, setDialogState) => AlertDialog(
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(
                      labelText: "Password Temp",
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: role,
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
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Utente creato!")),
                    );
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Errore: $e")));
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

  // --- HELPERS ---

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

  // --- BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // --- TOP TOOLBAR ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: "Cerca utente...",
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
              if (_currentUserRole == 'admin') ...[
                const VerticalDivider(),
                DropdownButton<String>(
                  value: _roleFilter,
                  underline: const SizedBox(),
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
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.sync, color: Colors.blue),
                tooltip: "Sync DB",
                onPressed: _isLoading ? null : _syncUsers,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isLoading ? null : _showCreateUserDialog,
                icon: const Icon(Icons.add),
                label: const Text("NUOVO UTENTE"),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        if (_isLoading) const LinearProgressIndicator(),
        const SizedBox(height: 20),

        // --- CONTENT ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getUsersStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Err: ${snapshot.error}');
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              var allDocs = snapshot.data!.docs;

              // Pre-calculate Nutritionist Names for Headers
              final nutNameMap = <String, String>{};
              for (var doc in allDocs) {
                final d = doc.data() as Map<String, dynamic>;
                if (d['role'] == 'nutritionist') {
                  nutNameMap[doc.id] =
                      "${d['first_name'] ?? ''} ${d['last_name'] ?? ''}".trim();
                  if (nutNameMap[doc.id]!.isEmpty)
                    nutNameMap[doc.id] = d['email'] ?? 'Unknown';
                }
              }

              // Filter Logic
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final role = (data['role'] ?? 'user').toString().toLowerCase();
                final name =
                    "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}"
                        .toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();

                if (_currentUserRole == 'admin' &&
                    _roleFilter != 'all' &&
                    role != _roleFilter)
                  return false;
                if (_searchQuery.isNotEmpty) {
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }
                return true;
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Text(
                    "Nessun utente trovato.",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              // Conditional Rendering based on Role
              if (_currentUserRole == 'admin') {
                return _buildAdminGroupedLayout(filteredDocs, nutNameMap);
              } else {
                return _buildUserGrid(filteredDocs);
              }
            },
          ),
        ),
      ],
    );
  }

  /// Original Grid Layout (Used for Nutritionists to see their own clients)
  Widget _buildUserGrid(List<DocumentSnapshot> docs) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 230,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        return _UserCard(
          doc: docs[index],
          onDelete: _deleteUser,
          onUploadDiet: _uploadDiet,
          onUploadParser: _uploadParser,
          currentUserRole: _currentUserRole,
          roleColor: _getRoleColor(
            (docs[index].data() as Map<String, dynamic>)['role'] ?? 'user',
          ),
        );
      },
    );
  }

  /// Grouped List Layout for Admins
  Widget _buildAdminGroupedLayout(
    List<DocumentSnapshot> docs,
    Map<String, String> nutNameMap,
  ) {
    // Grouping Collections
    final admins = <DocumentSnapshot>[];
    final independents = <DocumentSnapshot>[];
    final nutritionistGroups = <String, List<DocumentSnapshot>>{};
    final nutritionistDocs =
        <String, DocumentSnapshot>{}; // The nutritionist themselves

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final role = (data['role'] ?? 'user').toString().toLowerCase();
      final createdBy = data['created_by'] as String?;

      if (role == 'admin') {
        admins.add(doc);
      } else if (role == 'independent') {
        independents.add(doc);
      } else if (role == 'nutritionist') {
        // Add the nutritionist to the map so we can show them or just use them as header
        nutritionistDocs[doc.id] = doc;
        // Ensure their group exists in the map
        if (!nutritionistGroups.containsKey(doc.id)) {
          nutritionistGroups[doc.id] = [];
        }
      } else if (role == 'user') {
        // Client logic
        if (createdBy != null &&
            (nutNameMap.containsKey(createdBy) ||
                nutritionistDocs.containsKey(createdBy))) {
          // It's assigned to a known nutritionist
          if (!nutritionistGroups.containsKey(createdBy)) {
            nutritionistGroups[createdBy] = [];
          }
          nutritionistGroups[createdBy]!.add(doc);
        } else {
          // Unassigned client -> treat as independent
          independents.add(doc);
        }
      }
    }

    return ListView(
      children: [
        // 1. NUTRITIONIST GROUPS
        ...nutritionistGroups.entries.map((entry) {
          final nutId = entry.key;
          final clients = entry.value;
          final nutName = nutNameMap[nutId] ?? "Nutritionist ID: $nutId";
          final nutDoc = nutritionistDocs[nutId]; // The doc itself if visible

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.2),
                child: const Icon(Icons.health_and_safety, color: Colors.blue),
              ),
              title: Text(
                nutName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("${clients.length} Clients"),
              children: [
                if (nutDoc != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _UserCard(
                      doc: nutDoc,
                      onDelete: _deleteUser,
                      onUploadDiet: _uploadDiet,
                      onUploadParser: _uploadParser,
                      currentUserRole: _currentUserRole,
                      roleColor: _getRoleColor('nutritionist'),
                    ),
                  ),
                if (clients.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisExtent: 230,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: clients.length,
                    padding: const EdgeInsets.all(10),
                    itemBuilder: (ctx, idx) => _UserCard(
                      doc: clients[idx],
                      onDelete: _deleteUser,
                      onUploadDiet: _uploadDiet,
                      onUploadParser: _uploadParser,
                      currentUserRole: _currentUserRole,
                      roleColor: _getRoleColor('user'),
                    ),
                  ),
                if (clients.isEmpty && nutDoc == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("No visible clients or nutritionist data."),
                  ),
              ],
            ),
          );
        }),

        // 2. INDEPENDENT USERS CARD
        if (independents.isNotEmpty)
          Card(
            color: Colors.orange.shade50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(
                Icons.person_outline,
                color: Colors.orange,
                size: 32,
              ),
              title: const Text(
                "Independent Users",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                "${independents.length} Users unassigned or independent",
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IndependentUsersScreen(
                      users: independents,
                      onDelete: _deleteUser,
                      onUploadDiet: _uploadDiet,
                      onUploadParser: _uploadParser,
                      currentUserRole: _currentUserRole,
                      roleColor: _getRoleColor('independent'),
                    ),
                  ),
                );
              },
            ),
          ),

        // 3. ADMINS
        if (admins.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Administrators",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 230,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: admins.length,
            itemBuilder: (ctx, idx) => _UserCard(
              doc: admins[idx],
              onDelete: _deleteUser,
              onUploadDiet: _uploadDiet,
              onUploadParser: _uploadParser,
              currentUserRole: _currentUserRole,
              roleColor: _getRoleColor('admin'),
            ),
          ),
        ],
      ],
    );
  }
}

/// A separate screen to list independent users when the card is clicked
class IndependentUsersScreen extends StatelessWidget {
  final List<DocumentSnapshot> users;
  final Function(String) onDelete;
  final Function(String) onUploadDiet;
  final Function(String) onUploadParser;
  final String currentUserRole;
  final Color roleColor;

  const IndependentUsersScreen({
    super.key,
    required this.users,
    required this.onDelete,
    required this.onUploadDiet,
    required this.onUploadParser,
    required this.currentUserRole,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Independent Users")),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisExtent: 230,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: users.length,
        itemBuilder: (context, index) {
          return _UserCard(
            doc: users[index],
            onDelete: onDelete,
            onUploadDiet: onUploadDiet,
            onUploadParser: onUploadParser,
            currentUserRole: currentUserRole,
            roleColor: roleColor,
          );
        },
      ),
    );
  }
}

/// Refactored User Card Component
class _UserCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final Function(String) onDelete;
  final Function(String) onUploadDiet;
  final Function(String) onUploadParser;
  final String currentUserRole;
  final Color roleColor;

  const _UserCard({
    required this.doc,
    required this.onDelete,
    required this.onUploadDiet,
    required this.onUploadParser,
    required this.currentUserRole,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final role = data['role'] ?? 'user';
    final name = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}";
    final date = data['created_at'] != null
        ? DateFormat(
            'dd MMM yyyy',
          ).format((data['created_at'] as Timestamp).toDate())
        : '-';

    bool showParser = role == 'nutritionist';
    bool showDiet = role == 'user' || role == 'independent';
    bool canDelete = currentUserRole == 'admin' || role == 'user';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: roleColor.withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        data['email'] ?? 'No Email',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: roleColor,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showDiet)
                  IconButton(
                    icon: const Icon(Icons.upload_file, color: Colors.blueGrey),
                    tooltip: "Carica Dieta",
                    onPressed: () => onUploadDiet(data['uid']),
                  ),
                if (showParser)
                  IconButton(
                    icon: const Icon(
                      Icons.settings_applications,
                      color: Colors.orange,
                    ),
                    tooltip: "Configura Parser",
                    onPressed: () => onUploadParser(data['uid']),
                  ),
                const SizedBox(width: 8),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: "Elimina",
                    onPressed: () => onDelete(data['uid']),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Creato il: $date",
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
