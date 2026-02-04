import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/tracking_service.dart';
import '../models/tracking_models.dart';

/// Screen per visualizzare statistiche e progressi
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final TrackingService _trackingService = TrackingService();
  final TextEditingController _weightController = TextEditingController();
  final List<StreamSubscription> _subscriptions = [];

  WeeklyStats? _weeklyStats;
  List<WeightEntry> _weightHistory = [];
  List<UserGoal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final stats = await _trackingService.calculateWeeklyStats();

    // Weight history stream
    _subscriptions.add(
      _trackingService.getWeightHistory(days: 30).listen((history) {
        if (mounted) {
          setState(() => _weightHistory = history);
        }
      }),
    );

    // Goals stream
    _subscriptions.add(
      _trackingService.getGoals().listen((goals) {
        if (mounted) {
          setState(() => _goals = goals);
        }
      }),
    );

    if (mounted) {
      setState(() {
        _weeklyStats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeeklyOverview(),
              const SizedBox(height: 24),
              _buildGoalsSection(),
              const SizedBox(height: 24),
              _buildWeightSection(),
              const SizedBox(height: 24),
              _buildWeightChart(),
              const SizedBox(height: 24),
              _buildStreakCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    final stats = _weeklyStats!;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Riepilogo Settimanale',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    'Aderenza',
                    '${stats.weeklyAdherencePercent.toStringAsFixed(0)}%',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    'Pasti',
                    '${stats.totalMealsConsumed}/${stats.totalMealsPlanned}',
                    Icons.restaurant,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    'Giorni 100%',
                    '${stats.daysWithFullAdherence}/7',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: stats.weeklyAdherencePercent / 100,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  stats.weeklyAdherencePercent >= 80
                      ? Colors.green
                      : stats.weeklyAdherencePercent >= 50
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildWeightSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Tracking Peso',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Peso (kg)',
                      border: OutlineInputBorder(),
                      suffixText: 'kg',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saveWeight,
                  icon: const Icon(Icons.add),
                  label: const Text('Salva'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ],
            ),
            if (_weightHistory.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Ultimo: ${_weightHistory.first.weightKg.toStringAsFixed(1)} kg',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeightChart() {
    if (_weightHistory.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Registra almeno 2 pesi per vedere il grafico',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final spots = _weightHistory.reversed.toList().asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightKg);
    }).toList();

    final minWeight = _weightHistory.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b);
    final maxWeight = _weightHistory.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Andamento Peso',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: minWeight - 2,
                  maxY: maxWeight + 2,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    final streak = _weeklyStats?.currentStreak ?? 0;
    
    return Card(
      elevation: 2,
      color: streak >= 3 ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: streak >= 3 ? Colors.green : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department,
                color: streak >= 3 ? Colors.white : Colors.grey[600],
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Streak: $streak giorni',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: streak >= 3 ? Colors.green[800] : Colors.grey[800],
                    ),
                  ),
                  Text(
                    streak >= 7
                        ? '🔥 Incredibile! Una settimana perfetta!'
                        : streak >= 3
                            ? '💪 Ottimo lavoro! Continua così!'
                            : 'Completa tutti i pasti per iniziare uno streak!',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Obiettivi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: _showAddGoalDialog,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_goals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Nessun obiettivo. Tocca + per aggiungere!',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              ...(_goals.map((goal) => _buildGoalTile(goal)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalTile(UserGoal goal) {
    final progress = goal.progressPercent / 100;
    final color = goal.isCompleted
        ? Colors.green
        : progress >= 0.7
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: goal.isCompleted ? Colors.grey : null,
                    decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    '${goal.currentValue.toStringAsFixed(0)}/${goal.targetValue.toStringAsFixed(0)} ${goal.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (!goal.isCompleted) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _incrementGoal(goal),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, size: 18, color: color),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _incrementGoal(UserGoal goal) async {
    final newValue = goal.currentValue + 1;
    await _trackingService.updateGoalProgress(goal.id, newValue);
    
    if (newValue >= goal.targetValue && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Obiettivo "${goal.title}" completato!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showAddGoalDialog() async {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    String selectedUnit = 'L';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuovo Obiettivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titolo',
                  hintText: 'es. Bevi acqua',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Obiettivo',
                        hintText: '2',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: selectedUnit,
                    items: ['L', 'kg', 'km', 'min', 'pasti', 'porzioni']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedUnit = v!),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crea'),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      final target = double.tryParse(targetController.text) ?? 1;
      final goal = UserGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: titleController.text,
        targetValue: target,
        currentValue: 0,
        unit: selectedUnit,
      );
      await _trackingService.saveGoal(goal);
    }
  }


  Future<void> _saveWeight() async {
    final text = _weightController.text.trim();
    if (text.isEmpty) return;

    final weight = double.tryParse(text.replaceAll(',', '.'));
    if (weight == null || weight < 20 || weight > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un peso valido (20-300 kg)')),
      );
      return;
    }

    await _trackingService.saveWeight(weight);
    _weightController.clear();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Peso salvato: ${weight.toStringAsFixed(1)} kg')),
      );
    }
  }

}
