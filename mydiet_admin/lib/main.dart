import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  // [NEW] Maintenance State
  bool _maintenanceMode = false;

  String? _myUid;
  String? _myRole;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    // [NEW] Check Maintenance Status on Startup
    _checkMaintenance();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _myUid = user.uid;
          _myRole = doc.data()?['role'] ?? 'user';
        });
        // Re-check maintenance if we just confirmed we are admin
        if (_myRole == 'admin') _checkMaintenance();
      }
    }
  }

  // [NEW] Check Status from Backend
  Future<void> _checkMaintenance() async {
    // Only check if we are admin (or we don't know role yet, safe to fail silently)
    try {
      bool status = await _repo.getMaintenanceStatus();
      if (mounted) setState(() => _maintenanceMode = status);
    } catch (e) {
      debugPrint("Maintenance Check Error: $e");
    }
  }

  // [NEW] Toggle Status Logic
  Future<void> _toggleMaintenance(bool value) async {
    // Optimistic Update (Switch visual updates immediately)
    setState(() => _maintenanceMode = value);

    try {
      await _repo.setMaintenanceStatus(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? "🚨 SYSTEM IN MAINTENANCE MODE" : "✅ System Live",
            ),
            backgroundColor: value ? Colors.red : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert switch if backend fails
      if (mounted) {
        setState(() => _maintenanceMode = !value);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _performSync() async {
    setState(() => _isUploading = true);
    try {
      String msg = await _repo.syncUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
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
      if (mounted) setState(() => _isUploading = false);
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
                      value: 'independent',
                      child: Text("Independent"),
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
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("User Created!")),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("Error: $e")));
                        }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Diet Saved!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _openHistory(String uid, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(uid: uid, userName: userName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_myRole == 'admin' ? "God Mode" : "Nutritionist Panel"),
        actions: [
          // [NEW] MAINTENANCE TOGGLE (Admin Only)
          if (_myRole == 'admin') ...[
            const Text(
              "Maint: ",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Switch(
              value: _maintenanceMode,
              activeColor: Colors.red,
              // Use MaterialStateProperty to show icon only when selected (Red Alert)
              thumbIcon: MaterialStateProperty.resolveWith<Icon?>((states) {
                if (states.contains(MaterialState.selected)) {
                  return const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                  );
                }
                return null;
              }),
              onChanged: _isUploading ? null : _toggleMaintenance,
            ),
            const SizedBox(width: 12), // Spacer
          ],

          if (_myRole == 'admin')
            IconButton(
              icon: const Icon(Icons.cloud_sync, color: Colors.blue),
              tooltip: "Sync DB Users",
              onPressed: _isUploading ? null : _performSync,
            ),
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
              // Filters
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
                          children: [
                            const SizedBox(width: 8),
                            const Text(
                              "Role: ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ToggleButtons(
                                  constraints: const BoxConstraints(
                                    minHeight: 40,
                                    minWidth: 70,
                                  ),
                                  isSelected: [
                                    _filterRole == 'All',
                                    _filterRole == 'user',
                                    _filterRole == 'independent',
                                    _filterRole == 'nutritionist',
                                    _filterRole == 'admin',
                                  ],
                                  onPressed: (idx) {
                                    setState(() {
                                      if (idx == 0) _filterRole = 'All';
                                      if (idx == 1) _filterRole = 'user';
                                      if (idx == 2) _filterRole = 'independent';
                                      if (idx == 3)
                                        _filterRole = 'nutritionist';
                                      if (idx == 4) _filterRole = 'admin';
                                    });
                                  },
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text("All"),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text("Clients"),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text("Indep"),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text("Nutri"),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text("Admin"),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // User List
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _repo.getAllUsers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    var users = snapshot.data!;

                    if (_myRole == 'nutritionist') {
                      users = users
                          .where((u) => u['parent_id'] == _myUid)
                          .toList();
                    }

                    if (_myRole == 'admin' && _filterRole != 'All') {
                      users = users
                          .where((u) => u['role'] == _filterRole)
                          .toList();
                    }

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
                        final String uid = user['uid'] ?? '';
                        final String email = user['email'] ?? 'No Email';
                        final String role = user['role'] ?? 'user';
                        final String firstName = user['first_name'] ?? '';
                        final String lastName = user['last_name'] ?? '';
                        final bool isActive = user['is_active'] ?? true;

                        if (uid.isEmpty) return const SizedBox.shrink();

                        final String fullName = firstName.isEmpty
                            ? "Unknown"
                            : "$firstName $lastName";

                        IconData roleIcon = Icons.person;
                        if (role == 'admin') roleIcon = Icons.security;
                        if (role == 'nutritionist')
                          roleIcon = Icons.medical_services;
                        if (role == 'independent')
                          roleIcon = Icons.accessibility_new;

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
                              child: Icon(
                                roleIcon,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              "$fullName ($email)",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text("Role: $role | UID: $uid"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // UPLOAD PARSER (Nutritionist + Admin only)
                                if (role == 'nutritionist' &&
                                    _myRole == 'admin')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.settings_suggest,
                                      color: Colors.orange,
                                    ),
                                    tooltip: "Upload Custom AI Parser",
                                    onPressed: () async {
                                      FilePickerResult? result =
                                          await FilePicker.platform.pickFiles(
                                            type: FileType.custom,
                                            allowedExtensions: [
                                              'txt',
                                            ], // Only Text Files
                                            withData: true,
                                          );

                                      if (result != null) {
                                        try {
                                          await _repo.uploadParserConfig(
                                            uid,
                                            result.files.single,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Custom Parser Instructions Saved!",
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text("Error: $e"),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),

                                // HISTORY BUTTON
                                if (role == 'user' || role == 'independent')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.history,
                                      color: Colors.purple,
                                    ),
                                    tooltip: "View History",
                                    onPressed: () =>
                                        _openHistory(uid, fullName),
                                  ),

                                // UPLOAD DIET BUTTON
                                if (role == 'user' || role == 'independent')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.upload_file,
                                      color: Colors.blue,
                                    ),
                                    onPressed: _isUploading
                                        ? null
                                        : () => _uploadDiet(uid),
                                  ),

                                // DELETE BUTTON
                                if (_myRole == 'admin' ||
                                    _myRole == 'nutritionist')
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
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
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
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text("User Deleted"),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text("Error: $e"),
                                              ),
                                            );
                                          }
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
} // SCREEN: History of Diets

class HistoryScreen extends StatelessWidget {
  final String uid;
  final String userName;
  final AdminRepository _repo = AdminRepository();

  HistoryScreen({super.key, required this.uid, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("History: $userName")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _repo.getDietHistory(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final diets = snapshot.data!;
          if (diets.isEmpty)
            return const Center(child: Text("No diets uploaded yet."));

          return ListView.builder(
            itemCount: diets.length,
            itemBuilder: (ctx, i) {
              final diet = diets[i];
              // Safety fallback for old diets without fileName
              final String fileName = diet['fileName'] ?? 'Unknown File';
              final Timestamp? ts = diet['uploadedAt'];
              final String dateStr = ts != null
                  ? DateFormat('dd MMM yyyy - HH:mm').format(ts.toDate())
                  : "Unknown Date";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.description,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Uploaded: $dateStr"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DietDetailScreen(dietData: diet, title: fileName),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// SCREEN: Detailed Diet View
class DietDetailScreen extends StatelessWidget {
  final Map<String, dynamic> dietData;
  final String title;

  const DietDetailScreen({
    super.key,
    required this.dietData,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Prepare Plan Data
    final Map<String, dynamic> plan = dietData['plan'] ?? {};

    // Sort Days Order
    final List<String> orderedDays = [
      "Lunedì",
      "Martedì",
      "Mercoledì",
      "Giovedì",
      "Venerdì",
      "Sabato",
      "Domenica",
    ];
    final sortedKeys = plan.keys.toList()
      ..sort((a, b) {
        int idxA = orderedDays.indexOf(a);
        int idxB = orderedDays.indexOf(b);
        if (idxA == -1) idxA = 99;
        if (idxB == -1) idxB = 99;
        return idxA.compareTo(idxB);
      });

    // 2. Prepare Substitutions Data
    final Map<String, dynamic> substitutions = dietData['substitutions'] ?? {};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.calendar_month), text: "Plan"),
              Tab(icon: Icon(Icons.swap_horiz), text: "Substitutions"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Weekly Plan
            plan.isEmpty
                ? const Center(child: Text("Empty Plan Data"))
                : ListView(
                    children: sortedKeys.map((dayName) {
                      Map<String, dynamic> meals = plan[dayName];
                      return ExpansionTile(
                        initiallyExpanded: true,
                        title: Text(
                          dayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: meals.entries.map((mealEntry) {
                          String mealType = mealEntry.key;
                          List<dynamic> dishes = mealEntry.value;

                          return ListTile(
                            title: Text(
                              mealType,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: dishes.map((d) {
                                String dName = d['name'] ?? 'Dish';
                                String dQty = d['qty'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text("• $dName $dQty"),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),

            // Tab 2: Substitutions
            substitutions.isEmpty
                ? const Center(child: Text("No Substitutions Available"))
                : ListView.builder(
                    itemCount: substitutions.length,
                    itemBuilder: (ctx, i) {
                      String key = substitutions.keys.elementAt(i);
                      var group = substitutions[key];
                      String groupName = group['name'] ?? 'Group $key';
                      List<dynamic> options = group['options'] ?? [];

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ExpansionTile(
                          title: Text(
                            groupName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("CAD Code: $key"),
                          children: options.map((opt) {
                            return ListTile(
                              leading: const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                              ),
                              title: Text(opt['name']),
                              trailing: Text(opt['qty']?.toString() ?? ''),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
