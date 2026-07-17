// Vista analytics: overview KPI, trend upload diete (grafico lineare), attività nutrizionisti e utenti inattivi.
// _loadAllData — carica tutti i dati in parallelo; _buildLineChart — grafico fl_chart con tooltip e assi localizzati.
// [COERENZA 2026-07-07] Le chiamate passano da AdminRepository (prima erano
// http.get diretti: bypassavano il signOut su 401 e duplicavano token/decode).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../core/error_mapper.dart';
import '../providers/user_provider.dart';
import '../widgets/design_system.dart';
import '../widgets/skeleton_loaders.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  final AdminRepository _repo = AdminRepository();

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

  // [UX R9/R10] Errore per-sezione: la sezione fallita mostra il SUO errore
  // con retry locale, le altre restano visibili coi loro dati.
  Object? _overviewError;
  Object? _trendError;
  Object? _activityError;
  Object? _inactiveError;

  @override
  void initState() {
    super.initState();
    // Ruolo dal UserProvider condiviso (niente più lettura Firestore per-view).
    _userRole = context.read<UserProvider>().role;
    _loadAllData();
  }

  Future<bool> _guard(
    Future<void> Function() loader,
    void Function(Object?) setErr,
  ) async {
    try {
      setErr(null);
      await loader();
      return true;
    } catch (e) {
      setErr(e);
      return false;
    }
  }

  /// Ricarica una singola sezione (retry locale dal suo error-widget).
  Future<void> _retrySection(
    Future<void> Function() loader,
    void Function(Object?) setErr,
  ) async {
    await _guard(loader, setErr);
    if (mounted) setState(() {});
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // [COERENZA] Sezioni indipendenti: un endpoint fallito non butta più in
    // errore l'intera pagina (prima Future.wait propagava il primo errore).
    // Errore full-page solo se falliscono TUTTE e quattro le chiamate.
    final results = await Future.wait([
      _guard(_loadOverview, (e) => _overviewError = e),
      _guard(_loadDietTrend, (e) => _trendError = e),
      _guard(_loadNutritionistActivity, (e) => _activityError = e),
      _guard(_loadInactiveUsers, (e) => _inactiveError = e),
    ]);

    if (mounted) {
      setState(() {
        if (!results.contains(true)) {
          _error = ErrorMapper.toUserMessage(
              _overviewError ?? Exception('load failed'));
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOverview() async {
    _overview = await _repo.getAnalyticsOverview();
  }

  Future<void> _loadDietTrend() async {
    _trendData = await _repo.getDietTrend(period: _trendPeriod);
  }

  Future<void> _loadNutritionistActivity() async {
    _nutritionists = await _repo.getNutritionistActivity();
  }

  Future<void> _loadInactiveUsers() async {
    _inactiveUsers = await _repo.getInactiveUsers(days: _inactiveDays);
  }

  /// Errore compatto di sezione: la card fallita mostra il proprio errore
  /// con retry LOCALE, senza toccare il resto della dashboard (R9/R10).
  Widget _sectionError(Object error, Future<void> Function() retry) {
    return PillCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: KyboColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ErrorMapper.toUserMessage(error),
              style: TextStyle(color: KyboColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          PillButton(
            label: AppLocalizations.of(context).retry,
            icon: Icons.refresh_rounded,
            height: 36,
            onPressed: retry,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // [UX R3] Skeleton al posto dello spinner full-page.
      return const SkeletonUserList(itemCount: 6);
    }

    final l10n = AppLocalizations.of(context);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: KyboColors.error),
            const SizedBox(height: 16),
            Text(
              l10n.analyticsLoadError,
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
              label: l10n.retry,
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
                l10n.analyticsDashboard,
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              PillButton(
                label: l10n.refresh,
                icon: Icons.refresh_rounded,
                height: 40,
                onPressed: _loadAllData,
              ),
            ],
          ),

          const SizedBox(height: 24),
          _overviewError != null
              ? _sectionError(
                  _overviewError!,
                  () => _retrySection(
                      _loadOverview, (e) => _overviewError = e))
              : _buildOverviewCards(),
          const SizedBox(height: 24),
          _trendError != null
              ? _sectionError(
                  _trendError!,
                  () =>
                      _retrySection(_loadDietTrend, (e) => _trendError = e))
              : _buildDietTrendSection(),
          const SizedBox(height: 24),
          _activityError != null
              ? _sectionError(
                  _activityError!,
                  () => _retrySection(
                      _loadNutritionistActivity, (e) => _activityError = e))
              : _buildNutritionistActivitySection(),
          const SizedBox(height: 24),
          _inactiveError != null
              ? _sectionError(
                  _inactiveError!,
                  () => _retrySection(
                      _loadInactiveUsers, (e) => _inactiveError = e))
              : _buildInactiveUsersSection(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    final l10n = AppLocalizations.of(context);
    final isItalian = l10n.locale.languageCode == 'it';
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
            title: l10n.analyticsTotalUsers,
            value: "$totalUsers",
            icon: Icons.people_alt_rounded,
            color: KyboColors.accent,
            subtitle: isItalian
                ? "$activeLast30 attivi (30gg)"
                : "$activeLast30 active (30d)",
          ),
          StatCard(
            title: l10n.analyticsDietsUploaded,
            value: "$totalDiets",
            icon: Icons.restaurant_menu_rounded,
            color: KyboColors.primary,
            subtitle: isItalian
                ? "+$dietsLast30 ultimo mese"
                : "+$dietsLast30 last month",
          ),
          StatCard(
            title: l10n.analyticsChatMessages,
            value: "$totalMessages",
            icon: Icons.chat_bubble_rounded,
            color: KyboColors.warning,
            subtitle: isItalian
                ? "$totalChats conversazioni"
                : "$totalChats conversations",
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
                AppLocalizations.of(context).analyticsDietTrend,
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
                      AppLocalizations.of(context).noDataAvailable,
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _periodPill(l10n.analyticsPeriodDaily, "daily"),
          _periodPill(l10n.analyticsPeriodWeekly, "weekly"),
          _periodPill(l10n.analyticsPeriodMonthly, "monthly"),
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
          // Guarded: un errore qui finisce nell'error-widget della sezione
          // (prima era un Future non gestito → eccezione silenziosa).
          _retrySection(_loadDietTrend, (e) => _trendError = e);
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

      final dateStr = item['date'] as String;
      String label;
      if (_trendPeriod == 'monthly') {
        try {
          final parts = dateStr.split('-');
          label = DateFormat.MMM('it').format(DateTime(int.parse(parts[0]), int.parse(parts[1])));
        } catch (_) {
          label = dateStr;
        }
      } else {
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

  Widget _buildNutritionistActivitySection() {
    final l10n = AppLocalizations.of(context);
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
                _userRole == 'admin'
                    ? l10n.analyticsNutritionistActivity
                    : l10n.analyticsYourActivity,
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
                  l10n.chatNoNutritionists,
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
                    AppLocalizations.of(context).clientsLowercase,
                    style: TextStyle(color: KyboColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

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
                AppLocalizations.of(context).analyticsInactiveUsers,
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
                      AppLocalizations.of(context).analyticsAllActive,
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
    final isItalian =
        AppLocalizations.of(context).locale.languageCode == 'it';
    final suffix = isItalian ? 'gg' : 'd';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _daysPill("7$suffix", 7),
          _daysPill("30$suffix", 30),
          _daysPill("90$suffix", 90),
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
          // Guarded: un errore qui finisce nell'error-widget della sezione.
          _retrySection(_loadInactiveUsers, (e) => _inactiveError = e);
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
    final l10n = AppLocalizations.of(context);
    final name = user['name'] ?? 'N/A';
    final email = user['email'] ?? '';
    final rawLastLogin = user['last_login'] ?? 'Mai';
    final role = user['role'] ?? '';

    // Sentinelle dal backend (sempre IT) → traduciamo per la UI.
    final isNeverLogin = rawLastLogin == 'Mai';
    final isInvalidLogin = rawLastLogin == 'Non valido';

    String lastLoginDisplay;
    if (isNeverLogin) {
      lastLoginDisplay = l10n.analyticsNever;
    } else if (isInvalidLogin) {
      lastLoginDisplay = l10n.analyticsInvalidDate;
    } else {
      try {
        final dt = DateTime.parse(rawLastLogin);
        lastLoginDisplay = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        lastLoginDisplay = rawLastLogin;
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
                l10n.analyticsLastLogin,
                style: TextStyle(color: KyboColors.textMuted, fontSize: 10),
              ),
              Text(
                lastLoginDisplay,
                style: TextStyle(
                  color: isNeverLogin
                      ? KyboColors.error
                      : KyboColors.textSecondary,
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
