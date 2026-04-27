// Schermata Workout: mostra la scheda allenamento assegnata dal Personal Trainer.
// Usa tab per i giorni e mostra gli esercizi con sets/reps/rest.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/workout_provider.dart';
import '../models/workout_model.dart';
import '../widgets/design_system.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutProvider>().loadPlan();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        backgroundColor: KyboColors.surface(context),
        elevation: 0,
        title: Text(
          'Scheda Allenamento',
          style: TextStyle(
            color: KyboColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: KyboColors.textPrimary(context)),
      ),
      body: provider.isLoading
          ? Center(
              child: CircularProgressIndicator(color: KyboColors.primary))
          : !provider.hasPlan
              ? _buildNoPlan(context)
              : _buildPlanContent(context, provider.plan!, isDark),
    );
  }

  Widget _buildNoPlan(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KyboColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                size: 64,
                color: KyboColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nessuna scheda assegnata',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: KyboColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Il tuo Personal Trainer non ti ha ancora assegnato\nuna scheda allenamento.',
              style: TextStyle(
                fontSize: 14,
                color: KyboColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanContent(
      BuildContext context, WorkoutPlan plan, bool isDark) {
    // Rebuild tab controller when plan changes
    if (_tabController == null || _tabController!.length != plan.days.length) {
      _tabController?.dispose();
      _tabController = TabController(
        length: plan.days.length,
        vsync: this,
      );
    }

    return Column(
      children: [
        // Plan header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A237E), const Color(0xFF283593)]
                  : [const Color(0xFF5C6BC0), const Color(0xFF3949AB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: KyboBorderRadius.large,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3949AB).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.planName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.days.length} giorni di allenamento',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Day tabs
        if (plan.days.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: KyboColors.surface(context),
              borderRadius: KyboBorderRadius.pill,
              border: Border.all(color: KyboColors.border(context)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: plan.days.length > 4,
              labelColor: Colors.white,
              unselectedLabelColor: KyboColors.textSecondary(context),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: KyboColors.primary,
                borderRadius: KyboBorderRadius.pill,
              ),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: plan.days
                  .map((d) => Tab(text: d.dayName))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Exercises + Complete button
          Expanded(
            child: Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: plan.days
                      .map((day) => _buildDayContent(context, day))
                      .toList(),
                ),
                Positioned(
                  bottom: 16,
                  left: 24,
                  right: 24,
                  child: FilledButton.icon(
                    onPressed: () => _completeWorkout(context),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'Completa Allenamento Oggi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: KyboColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: KyboBorderRadius.pill,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _completeWorkout(BuildContext context) async {
    try {
      final provider = context.read<WorkoutProvider>();
      final xp = await provider.completeDay();
      if (!context.mounted) return;
      HapticFeedback.mediumImpact();
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          title: const Text('💪 Ottimo lavoro!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hai completato l\'allenamento di oggi e guadagnato +$xp XP!',
                style: TextStyle(color: KyboColors.textPrimary(context)),
              ),
              const SizedBox(height: 20),
              Text(
                'Come è andata?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: KyboColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _FeedbackEmoji(
                    emoji: '😅',
                    label: 'Facile',
                    onTap: () {
                      provider.submitFeedback('easy');
                      Navigator.pop(dialogCtx);
                    },
                  ),
                  _FeedbackEmoji(
                    emoji: '👌',
                    label: 'Ok',
                    onTap: () {
                      provider.submitFeedback('ok');
                      Navigator.pop(dialogCtx);
                    },
                  ),
                  _FeedbackEmoji(
                    emoji: '🔥',
                    label: 'Duro',
                    onTap: () {
                      provider.submitFeedback('hard');
                      Navigator.pop(dialogCtx);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Salta',
                style: TextStyle(color: KyboColors.textMuted(context)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: KyboColors.error,
        ),
      );
    }
  }

  Widget _buildDayContent(BuildContext context, WorkoutDay day) {
    if (day.exercises.isEmpty) {
      return Center(
        child: Text(
          'Nessun esercizio per questo giorno',
          style: TextStyle(
            color: KyboColors.textSecondary(context),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: day.exercises.length + (day.notes != null ? 1 : 0),
      itemBuilder: (context, index) {
        // Show notes at the top if present
        if (day.notes != null && index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KyboColors.warning.withValues(alpha: 0.1),
              borderRadius: KyboBorderRadius.medium,
              border: Border.all(
                  color: KyboColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: KyboColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    day.notes!,
                    style: TextStyle(
                      color: KyboColors.textPrimary(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final exIndex = day.notes != null ? index - 1 : index;
        final exercise = day.exercises[exIndex];
        return _buildExerciseCard(context, exercise, exIndex);
      },
    );
  }

  Widget _buildExerciseCard(
      BuildContext context, WorkoutExercise exercise, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: KyboBorderRadius.large,
        border: Border.all(color: KyboColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Exercise number
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KyboColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Exercise info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: KyboColors.textPrimary(context),
                  ),
                ),
                if (exercise.notes != null &&
                    exercise.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      exercise.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: KyboColors.textSecondary(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Sets x Reps
          if (exercise.sets != null || exercise.reps != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: KyboColors.primary.withValues(alpha: 0.1),
                borderRadius: KyboBorderRadius.pill,
              ),
              child: Text(
                [
                  if (exercise.sets != null) '${exercise.sets}x',
                  if (exercise.reps != null) exercise.reps,
                ].join(''),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.primary,
                ),
              ),
            ),

          // Rest
          if (exercise.restSeconds != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: KyboColors.accent.withValues(alpha: 0.1),
                borderRadius: KyboBorderRadius.pill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 14, color: KyboColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    '${exercise.restSeconds}s',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: KyboColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackEmoji extends StatelessWidget {
  const _FeedbackEmoji({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: KyboColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
