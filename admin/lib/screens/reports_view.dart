import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_repository.dart';
import '../widgets/design_system.dart';

/// Report Nutrizionisti View
/// Visualizza report mensili per admin e nutrizionisti
class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final AdminRepository _repo = AdminRepository();

  bool _isLoading = true;
  bool _isAdmin = false;
  String? _currentUserId;
  String? _error;

  // Report list
  List<dynamic> _reports = [];

  // Selected report
  Map<String, dynamic>? _selectedReport;
  bool _loadingReport = false;

  // Filters
  String? _selectedNutritionistId;
  List<Map<String, dynamic>> _nutritionists = [];

  // Month picker
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _isAdmin = data['role'] == 'admin';
      }
    }

    if (_isAdmin) {
      await _loadNutritionists();
    } else {
      _selectedNutritionistId = _currentUserId;
    }

    await _loadReports();
  }

  Future<void> _loadNutritionists() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'nutritionist')
          .get();

      setState(() {
        _nutritionists = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'uid': doc.id,
            'name': "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim(),
            'email': data['email'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      // Ignore error, just won't have nutritionist filter
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reports = await _repo.listReports(
        nutritionistId: _selectedNutritionistId,
        limit: 24,
      );

      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReport(String nutritionistId, String month) async {
    setState(() {
      _loadingReport = true;
      _selectedReport = null;
    });

    try {
      final report = await _repo.getMonthlyReport(
        nutritionistId: nutritionistId,
        month: month,
      );

      if (mounted) {
        setState(() {
          _selectedReport = report;
          _loadingReport = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: KyboColors.error,
          ),
        );
        setState(() => _loadingReport = false);
      }
    }
  }

  Future<void> _generateReport() async {
    final nutritionistId = _selectedNutritionistId ?? _currentUserId;
    if (nutritionistId == null) return;

    setState(() => _loadingReport = true);

    try {
      await _repo.generateReport(
        nutritionistId: nutritionistId,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
        forceRegenerate: true,
      );

      final month = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
      await _loadReport(nutritionistId, month);
      await _loadReports();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Report generato con successo"),
            backgroundColor: KyboColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: KyboColors.error,
          ),
        );
        setState(() => _loadingReport = false);
      }
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: KyboColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: KyboColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: KyboColors.textSecondary)),
            const SizedBox(height: 16),
            PillButton(
              label: "Riprova",
              icon: Icons.refresh,
              onPressed: _loadReports,
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Left panel - Report list and generator
        Expanded(
          flex: 2,
          child: _buildLeftPanel(),
        ),

        // Divider
        Container(
          width: 1,
          color: KyboColors.textMuted.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),

        // Right panel - Report details
        Expanded(
          flex: 3,
          child: _buildRightPanel(),
        ),
      ],
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          "Report Mensili",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: KyboColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Filters (admin only)
        if (_isAdmin && _nutritionists.isNotEmpty) ...[
          Text(
            "Nutrizionista",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: KyboColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: KyboColors.surface,
              borderRadius: KyboBorderRadius.small,
              border: Border.all(color: KyboColors.textMuted.withValues(alpha: 0.3)),
            ),
            child: DropdownButton<String?>(
              value: _selectedNutritionistId,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text("Tutti i nutrizionisti"),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text("Tutti i nutrizionisti"),
                ),
                ..._nutritionists.map((n) => DropdownMenuItem(
                  value: n['uid'] as String,
                  child: Text(n['name'] as String),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedNutritionistId = value);
                _loadReports();
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Month picker & generate
        Row(
          children: [
            Expanded(
              child: PillButton(
                label: DateFormat('MMMM yyyy').format(_selectedMonth),
                icon: Icons.calendar_today_rounded,
                onPressed: _pickMonth,
              ),
            ),
            const SizedBox(width: 8),
            PillButton(
              label: "Genera",
              icon: Icons.add_chart_rounded,
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              onPressed: (_selectedNutritionistId != null || !_isAdmin)
                  ? _generateReport
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Report list
        Text(
          "Storico Report",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: KyboColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assessment_rounded,
                        size: 48,
                        color: KyboColors.textMuted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Nessun report disponibile",
                        style: TextStyle(color: KyboColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index] as Map<String, dynamic>;
                    return _buildReportTile(report);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportTile(Map<String, dynamic> report) {
    final month = report['month'] ?? '';
    final name = report['nutritionist_name'] ?? '';
    final clients = report['total_clients'] ?? 0;
    final diets = report['diets_uploaded'] ?? 0;
    final isSelected = _selectedReport?['month'] == month &&
        _selectedReport?['nutritionist_id'] == report['nutritionist_id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _loadReport(
          report['nutritionist_id'] as String,
          month,
        ),
        borderRadius: KyboBorderRadius.small,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? KyboColors.primary.withValues(alpha: 0.1)
                : KyboColors.surface,
            borderRadius: KyboBorderRadius.small,
            border: Border.all(
              color: isSelected
                  ? KyboColors.primary
                  : KyboColors.textMuted.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KyboColors.roleNutritionist.withValues(alpha: 0.1),
                  borderRadius: KyboBorderRadius.small,
                ),
                child: Center(
                  child: Text(
                    month.split('-').last,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: KyboColors.roleNutritionist,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMonth(month),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: KyboColors.textPrimary,
                      ),
                    ),
                    if (_isAdmin && name.isNotEmpty)
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 12,
                          color: KyboColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$clients clienti",
                    style: TextStyle(
                      fontSize: 12,
                      color: KyboColors.textSecondary,
                    ),
                  ),
                  Text(
                    "$diets diete",
                    style: TextStyle(
                      fontSize: 12,
                      color: KyboColors.textSecondary,
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

  Widget _buildRightPanel() {
    if (_loadingReport) {
      return const Center(
        child: CircularProgressIndicator(color: KyboColors.primary),
      );
    }

    if (_selectedReport == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_rounded,
              size: 64,
              color: KyboColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              "Seleziona un report",
              style: TextStyle(
                fontSize: 18,
                color: KyboColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Oppure genera un nuovo report",
              style: TextStyle(
                fontSize: 14,
                color: KyboColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return _buildReportDetails();
  }

  Widget _buildReportDetails() {
    final report = _selectedReport!;
    final month = report['month'] ?? '';
    final name = report['nutritionist_name'] ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Report ${_formatMonth(month)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: KyboColors.textPrimary,
                      ),
                    ),
                    if (name.isNotEmpty)
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          color: KyboColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              PillIconButton(
                icon: Icons.refresh_rounded,
                tooltip: "Rigenera Report",
                onPressed: _generateReport,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: "Clienti Totali",
                  value: "${report['total_clients'] ?? 0}",
                  icon: Icons.people_rounded,
                  color: KyboColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: "Nuovi Clienti",
                  value: "${report['new_clients'] ?? 0}",
                  icon: Icons.person_add_rounded,
                  color: KyboColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: "Clienti Attivi",
                  value: "${report['active_clients'] ?? 0}",
                  icon: Icons.trending_up_rounded,
                  color: KyboColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: "Diete Caricate",
                  value: "${report['diets_uploaded'] ?? 0}",
                  icon: Icons.restaurant_menu_rounded,
                  color: KyboColors.roleNutritionist,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: "Messaggi Inviati",
                  value: "${report['total_messages_sent'] ?? 0}",
                  icon: Icons.send_rounded,
                  color: KyboColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: "Tempo Risposta",
                  value: _formatResponseTime(report['average_response_time_hours']),
                  icon: Icons.timer_rounded,
                  color: KyboColors.roleAdmin,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Diet breakdown
          if ((report['diets_by_client'] as Map<String, dynamic>?)?.isNotEmpty ?? false) ...[
            Text(
              "Diete per Cliente",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: KyboColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildDietsByClient(report['diets_by_client'] as Map<String, dynamic>),
          ],
        ],
      ),
    );
  }

  Widget _buildDietsByClient(Map<String, dynamic> dietsByClient) {
    final entries = dietsByClient.entries.toList();
    entries.sort((a, b) => (b.value as int).compareTo(a.value as int));

    return PillCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: entries.take(10).map((entry) {
          final clientId = entry.key;
          final count = entry.value as int;
          final maxCount = entries.first.value as int;
          final progress = maxCount > 0 ? count / maxCount : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clientId.substring(0, 8) + "...",
                        style: TextStyle(
                          fontSize: 13,
                          color: KyboColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      "$count diete",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: KyboColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: KyboBorderRadius.small,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: KyboColors.textMuted.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(KyboColors.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatMonth(String month) {
    try {
      final parts = month.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return month;
    }
  }

  String _formatResponseTime(dynamic hours) {
    if (hours == null) return "N/A";
    final h = hours as double;
    if (h < 1) {
      return "${(h * 60).round()} min";
    } else if (h < 24) {
      return "${h.toStringAsFixed(1)} ore";
    } else {
      return "${(h / 24).toStringAsFixed(1)} giorni";
    }
  }
}
