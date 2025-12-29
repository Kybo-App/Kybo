import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'admin_repository.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyDiet Control',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const AuthGate(),
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
        return const RoleCheckScreen();
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

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "MyDiet Command",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ENTER"),
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'];

      if (role == 'admin' || role == 'nutritionist') {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Access Denied: Not an Admin")),
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AdminRepository _repo = AdminRepository();
  String _filterRole = 'All';
  String _searchQuery = '';
  bool _isUploading = false;

  String? _myUid;
  String? _myRole;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _myUid = user.uid;
        _myRole = doc.data()?['role'] ?? 'user';
      });
    }
  }

  void _showCreateUserDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    String selectedRole = 'user';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Create New Account"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstCtrl,
                        decoration: const InputDecoration(labelText: "Name"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lastCtrl,
                        decoration: const InputDecoration(labelText: "Surname"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: "Password"),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: selectedRole,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'user',
                      child: Text("Client (User)"),
                    ),
                    DropdownMenuItem(
                      value: 'nutritionist',
                      child: Text("Nutritionist"),
                    ),
                    DropdownMenuItem(value: 'admin', child: Text("Admin")),
                  ],
                  onChanged: (v) => setState(() => selectedRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {
                        await _repo.createUser(
                          email: emailCtrl.text.trim(),
                          password: passCtrl.text.trim(),
                          role: selectedRole,
                          firstName: firstCtrl.text.trim(),
                          lastName: lastCtrl.text.trim(),
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("User Created!")),
                        );
                      } catch (e) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDiet(String uid) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      setState(() => _isUploading = true);
      try {
        await _repo.uploadDietForUser(uid, result.files.single);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Diet Saved!"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_myRole == 'admin' ? "God Mode" : "Nutritionist Panel"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _showCreateUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text("Add Client"),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Search Bar & Filters
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: "Search by Name or Email...",
                          border: InputBorder.none,
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.toLowerCase()),
                      ),
                      if (_myRole == 'admin') ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Role: "),
                            ToggleButtons(
                              isSelected: [
                                _filterRole == 'All',
                                _filterRole == 'nutritionist',
                                _filterRole == 'user',
                              ],
                              onPressed: (idx) {
                                setState(() {
                                  if (idx == 0) _filterRole = 'All';
                                  if (idx == 1) _filterRole = 'nutritionist';
                                  if (idx == 2) _filterRole = 'user';
                                });
                              },
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text("All"),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text("Nutri"),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text("Client"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 2. User List
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _repo.getAllUsers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    var users = snapshot.data!;

                    // --- FILTERING LOGIC ---

                    // A. Nutritionist Limit: Only see MY clients
                    if (_myRole == 'nutritionist') {
                      users = users
                          .where((u) => u['parent_id'] == _myUid)
                          .toList();
                    }

                    // B. Role Filter (Admin only)
                    if (_myRole == 'admin' && _filterRole != 'All') {
                      users = users
                          .where((u) => u['role'] == _filterRole)
                          .toList();
                    }

                    // C. Search Filter (Name or Email)
                    if (_searchQuery.isNotEmpty) {
                      users = users.where((u) {
                        final email = (u['email'] ?? '')
                            .toString()
                            .toLowerCase();
                        final first = (u['first_name'] ?? '')
                            .toString()
                            .toLowerCase();
                        final last = (u['last_name'] ?? '')
                            .toString()
                            .toLowerCase();
                        return email.contains(_searchQuery) ||
                            first.contains(_searchQuery) ||
                            last.contains(_searchQuery);
                      }).toList();
                    }

                    if (users.isEmpty)
                      return const Center(child: Text("No users found."));

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (ctx, i) {
                        final user = users[i];
                        final bool isActive = user['is_active'] ?? true;
                        final String role = user['role'] ?? 'user';
                        final String email = user['email'] ?? 'No Email';
                        final String firstName = user['first_name'] ?? '';
                        final String lastName = user['last_name'] ?? '';
                        final String fullName = firstName.isEmpty
                            ? "Unknown"
                            : "$firstName $lastName";
                        final String uid = user['uid'];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isActive
                                  ? Colors.green
                                  : Colors.grey,
                              child: Text(
                                firstName.isNotEmpty
                                    ? firstName[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              "$fullName ($email)",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text("Role: $role"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Action: Upload Diet
                                IconButton(
                                  icon: const Icon(
                                    Icons.upload_file,
                                    color: Colors.blue,
                                  ),
                                  onPressed: _isUploading
                                      ? null
                                      : () => _uploadDiet(uid),
                                ),
                                // Action: Delete
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Delete User?"),
                                        content: Text("Delete $fullName?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text("Cancel"),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await _repo.deleteUser(uid);
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text("Error: $e")),
                                        );
                                      }
                                    }
                                  },
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

          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
