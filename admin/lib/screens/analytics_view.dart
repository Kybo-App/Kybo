import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/env.dart';
import '../widgets/design_system.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  String get _baseUrl => Env.isProd
      ? "https://kybo-prod.onrender.com"
      : "https://kybo-test.onrender.com";

  bool _isLoading = true;
  String? _error;
  String _userRole = '';

  // Overview data
  Map<String, dynamic> _overview = {};

  // Diet trend data
  List<Map<String, dynamic>> _trendData = [];
  String _trendPeriod = 'weekly';

  // Nutritionist activity
  List<Map<String, dynamic>> _nutritionists = [];

  // Inactive users
  List<Map<String, dynamic>> _inactiveUsers = [];
  int _inactiveDays = 30;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        _userRole = (doc.data() as Map<String, dynamic>)['role'] ?? '';
      }
    }
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadOverview(),
        _loadDietTrend(),
        _loadNutritionistActivity(),
        _loadInactiveUsers(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadOverview() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/analytics/overview'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      _overview = jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Errore overview: ${response.statusCode}');
    }
  }

  Future<void> _loadDietTrend() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/analytics/diet-trend?period=$_trendPeriod&months=3'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      _trendData = List<Map<String, dynamic>>.from(data['trend'] ?? []);
    } else {
      throw Exception('Errore trend: ${response.statusCode}');
    }
  }

  Future<void> _loadNutritionistActivity() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/analytics/nutritionist-activity'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      _nutritionists = List<Map<String, dynamic>>.from(data['nutritionists'] ?? []);
    } else {
      throw Exception('Errore attività: ${response.statusCode}');
    }
  }

  Future<void> _loadInactiveUsers() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/analytics/inactive-users?days=$_inactiveDays'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      _inactiveUsers = List<Map<String, dynamic>>.from(data['users'] ?? []);
    } else {
      throw Exception('Errore inattivi: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: KyboColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: KyboColors.error),
            const SizedBox(height: 16),
            Text(
              "Errore nel caricamento",
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: KyboColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PillButton(
              label: "Riprova",
              icon: Icons.refresh_rounded,
              onPressed: _loadAllData,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: KyboColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: KyboColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                "Analytics Dashboard",
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              PillButton(
                label: "Aggiorna",
                icon: Icons.refresh_rounded,
                height: 40,
                onPressed: _loadAllData,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════════════
          // OVERVIEW CARDS
          // ═══════════════════════════════════════════════════════════════════
          _buildOverviewCards(),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════════════
          // DIET TREND CHART
          // ═══════════════════════════════════════════════════════════════════
          _buildDietTrendSection(),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════════════
          // NUTRITIONIST ACTIVITY (admin vede tutti, nutritionist solo sé)
          // ═══════════════════════════════════════════════════════════════════
          _buildNutritionistActivitySection(),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════════════
          // INACTIVE USERS
          // ═══════════════════════════════════════════════════════════════════
          _buildInactiveUsersSection(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // OVERVIEW CARDS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildOverviewCards() {
    final totalUsers = _overview['total_users'] ?? 0;
    final activeLast30 = _overview['active_last_30_days'] ?? 0;
    final totalDiets = _overview['total_diets'] ?? 0;
    final dietsLast30 = _overview['diets_last_30_days'] ?? 0;
    final totalMessages = _overview['total_messages'] ?? 0;
    final totalChats = _overview['total_chats'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final cards = [
          StatCard(
            title: "Utenti Totali",
            value: "$totalUsers",
            icon: Icons.people_alt_rounded,
            color: KyboColors.accent,
            subtitle: "$activeLast30 attivi (30gg)",
          ),
          StatCard(
            title: "Diete Caricate",
            value: "$totalDiets",
            icon: Icons.restaurant_menu_rounded,
            color: KyboColors.primary,
            subtitle: "+$dietsLast30 ultimo mese",
          ),
          StatCard(
            title: "Messaggi Chat",
            value: "$totalMessages",
            icon: Icons.chat_bubble_rounded,
            color: KyboColors.warning,
            subtitle: "$totalChats conversazioni",
          ),
        ];

        if (isWide) {
          return Row(
            children: cards
                .map((card) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: card,
                      ),
                    ))
                .toList(),
          );
        }
        return Column(
          children: cards
              .map((card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  ))
              .toList(),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // DIET TREND CHART
  // ─────────────────────────────────────────────────────────────────
  Widget _buildDietTrendSection() {
    return PillCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: KyboColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                "Trend Upload Diete",
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildPeriodSelector(),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: _trendData.isEmpty
                ? Center(
                    child: Text(
                      "Nessun dato disponibile",
                      style: TextStyle(color: KyboColors.textMuted, fontSize: 14),
                    ),
                  )
                : _buildLineChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _periodPill("Giornaliero", "daily"),
          _periodPill("Settimanale", "weekly"),
          _periodPill("Mensile", "monthly"),
        ],
      ),
    );
  }

  Widget _periodPill(String label, String value) {
    final isSelected = _trendPeriod == value;
    return GestureDetector(
      onTap: () {
        if (_trendPeriod != value) {
          setState(() => _trendPeriod = value);
          _loadDietTrend().then((_) {
            if (mounted) setState(() {});
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? KyboColors.primary : Colors.transparent,
          borderRadius: KyboBorderRadius.pill,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : KyboColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = <FlSpot>[];
    final labels = <int, String>{};

    for (int i = 0; i < _trendData.length; i++) {
      final item = _trendData[i];
      spots.add(FlSpot(i.toDouble(), (item['count'] as num).toDouble()));

      // Label per asse X
      final dateStr = item['date'] as String;
      String label;
      if (_trendPeriod == 'monthly') {
        // "2026-01" → "Gen"
        try {
          final parts = dateStr.split('-');
          label = DateFormat.MMM('it').format(DateTime(int.parse(parts[0]), int.parse(parts[1])));
        } catch (_) {
          label = dateStr;
        }
      } else {
        // "2026-01-15" → "15/01"
        try {
          final dt = DateTime.parse(dateStr);
          label = DateFormat('dd/MM').format(dt);
        } catch (_) {
          label = dateStr;
        }
      }
      labels[i] = label;
    }

    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble().clamp(1, double.infinity) : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: KyboColors.border,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(color: KyboColors.textMuted, fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: _trendData.length > 10 ? (_trendData.length / 6).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (labels.containsKey(idx)) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[idx]!,
                      style: TextStyle(color: KyboColors.textMuted, fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: KyboColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length <= 15,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: KyboColors.primary,
                    strokeWidth: 2,
                    strokeColor: KyboColors.surface,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: KyboColors.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => KyboColors.surfaceElevated,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final dateLabel = labels[idx] ?? '';
                return LineTooltipItem(
                  '$dateLabel\n${spot.y.toInt()} diete',
                  TextStyle(
                    color: KyboColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // NUTRITIONIST ACTIVITY
  // ─────────────────────────────────────────────────────────────────
  Widget _buildNutritionistActivitySection() {
    return PillCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: KyboColors.roleNutritionist, size: 22),
              const SizedBox(width: 10),
              Text(
                _userRole == 'admin' ? "Attività Nutrizionisti" : "La Tua Attività",
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_nutritionists.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Nessun nutrizionista trovato",
                  style: TextStyle(color: KyboColors.textMuted, fontSize: 14),
                ),
              ),
            )
          else
            ..._nutritionists.map(_buildNutritionistCard),
        ],
      ),
    );
  }

  Widget _buildNutritionistCard(Map<String, dynamic> nut) {
    final name = nut['name'] ?? 'N/A';
    final email = nut['email'] ?? '';
    final clients = nut['client_count'] ?? 0;
    final maxClients = nut['max_clients'] ?? 50;
    final diets = nut['diet_count'] ?? 0;
    final messages = nut['message_count'] ?? 0;
    final clientRatio = maxClients > 0 ? clients / maxClients : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(color: KyboColors.border, width: 1),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KyboColors.roleNutritionist.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: KyboColors.roleNutritionist,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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
                      name,
                      style: TextStyle(
                        color: KyboColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          color: KyboColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // Client capacity indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$clients / $maxClients",
                    style: TextStyle(
                      color: clientRatio > 0.9 ? KyboColors.error : KyboColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "clienti",
                    style: TextStyle(color: KyboColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Client capacity bar
          ClipRRect(
            borderRadius: KyboBorderRadius.pill,
            child: LinearProgressIndicator(
              value: clientRatio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: KyboColors.border,
              valueColor: AlwaysStoppedAnimation(
                clientRatio > 0.9
                    ? KyboColors.error
                    : clientRatio > 0.7
                        ? KyboColors.warning
                        : KyboColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _miniStat(Icons.restaurant_menu_rounded, "$diets", "diete", KyboColors.primary),
              const SizedBox(width: 24),
              _miniStat(Icons.chat_bubble_outline_rounded, "$messages", "messaggi", KyboColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            color: KyboColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: KyboColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // INACTIVE USERS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildInactiveUsersSection() {
    return PillCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_off_rounded, color: KyboColors.error, size: 22),
              const SizedBox(width: 10),
              Text(
                "Utenti Inattivi",
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              PillBadge(
                label: "${_inactiveUsers.length}",
                color: _inactiveUsers.isNotEmpty ? KyboColors.error : KyboColors.success,
              ),
              const Spacer(),
              _buildDaysSelector(),
            ],
          ),
          const SizedBox(height: 16),
          if (_inactiveUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: KyboColors.success,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Tutti gli utenti sono attivi!",
                      style: TextStyle(
                        color: KyboColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _inactiveUsers.length,
                itemBuilder: (context, index) =>
                    _buildInactiveUserRow(_inactiveUsers[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _daysPill("7gg", 7),
          _daysPill("30gg", 30),
          _daysPill("90gg", 90),
        ],
      ),
    );
  }

  Widget _daysPill(String label, int days) {
    final isSelected = _inactiveDays == days;
    return GestureDetector(
      onTap: () {
        if (_inactiveDays != days) {
          setState(() => _inactiveDays = days);
          _loadInactiveUsers().then((_) {
            if (mounted) setState(() {});
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? KyboColors.error : Colors.transparent,
          borderRadius: KyboBorderRadius.pill,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : KyboColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInactiveUserRow(Map<String, dynamic> user) {
    final name = user['name'] ?? 'N/A';
    final email = user['email'] ?? '';
    final lastLogin = user['last_login'] ?? 'Mai';
    final role = user['role'] ?? '';

    String lastLoginDisplay;
    if (lastLogin == 'Mai' || lastLogin == 'Non valido') {
      lastLoginDisplay = lastLogin;
    } else {
      try {
        final dt = DateTime.parse(lastLogin);
        lastLoginDisplay = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        lastLoginDisplay = lastLogin;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.small,
        border: Border.all(color: KyboColors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KyboColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: KyboColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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
                  name,
                  style: TextStyle(
                    color: KyboColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: TextStyle(color: KyboColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (role.isNotEmpty) ...[
            PillBadge.role(role),
            const SizedBox(width: 12),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Ultimo accesso",
                style: TextStyle(color: KyboColors.textMuted, fontSize: 10),
              ),
              Text(
                lastLoginDisplay,
                style: TextStyle(
                  color: lastLogin == 'Mai' ? KyboColors.error : KyboColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
