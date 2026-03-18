import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/activity_provider.dart';
import '../../../core/models/activity.dart';
import '../../../widgets/responsive_grid.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  StreamSubscription<StepCount>? _stepSub;
  int _sessionSteps = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _startPedometer();
  }

  void _startPedometer() {
    _stepSub = Pedometer.stepCountStream.listen(
      (event) {
        setState(() => _sessionSteps = event.steps);
        // Sync to backend every 50 steps to avoid too many requests
        if (_sessionSteps % 50 == 0) {
          ref.read(todayStepsProvider.notifier).syncSteps(_sessionSteps);
        }
      },
      onError: (_) {}, // silently ignore sensor errors
    );
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepsAsync = ref.watch(todayStepsProvider);
    final historyAsync = ref.watch(stepHistoryProvider);
    final sessionsAsync = ref.watch(activitySessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(todayStepsProvider);
              ref.invalidate(stepHistoryProvider);
              ref.invalidate(activitySessionsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayStepsProvider);
          ref.invalidate(stepHistoryProvider);
          ref.invalidate(activitySessionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ResponsiveGrid(
              children: [
                stepsAsync.when(
                  loading: () => const _LoadingCard(),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                  data: (steps) => _TodayStepsCard(steps: steps),
                ),
                historyAsync.when(
                  loading: () => const _LoadingCard(),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                  data: (history) => _WeekHistoryCard(history: history),
                ),
                sessionsAsync.when(
                  loading: () => const _LoadingCard(),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                  data: (sessions) => _SessionsList(sessions: sessions),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today's Steps Card ────────────────────────────────────────────────────────

class _TodayStepsCard extends StatelessWidget {
  final DailySteps steps;
  const _TodayStepsCard({required this.steps});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = steps.goalReached ? AppColors.health : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Text('Today', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: steps.progress,
                  strokeWidth: 10,
                  color: color,
                  backgroundColor: cs.surfaceContainerHigh,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt(steps.steps),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('/ ${_fmt(steps.goal)} steps',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StepStat(
                icon: Icons.local_fire_department_outlined,
                color: AppColors.warning,
                label: 'Calories',
                value: '${steps.caloriesBurned.round()} kcal',
              ),
              _StepStat(
                icon: Icons.timer_outlined,
                color: AppColors.info,
                label: 'Active',
                value: '${steps.activeMinutes} min',
              ),
              _StepStat(
                icon: Icons.local_fire_department,
                color: AppColors.error,
                label: 'Streak',
                value: '${steps.currentStreak} days',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _StepStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StepStat({
    required this.icon, required this.color,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onSurface)),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

// ── Week History Chart ────────────────────────────────────────────────────────

class _WeekHistoryCard extends StatelessWidget {
  final List<StepHistoryPoint> history;
  const _WeekHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline),
        ),
        child: Center(
          child: Text('No step data yet — start walking!',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    final maxSteps = history.map((h) => h.steps).reduce((a, b) => a > b ? a : b);
    final barMax = maxSteps > 0 ? maxSteps * 1.2 : 10000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 Days', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in history)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: (point.steps / barMax).clamp(0.02, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: point.steps >= point.goal
                                        ? AppColors.health
                                        : AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('E').format(point.date),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Past Sessions List ────────────────────────────────────────────────────────

class _SessionsList extends StatelessWidget {
  final List<ActivitySessionSummary> sessions;
  const _SessionsList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline),
            ),
            child: Center(
              child: Text('No activity sessions yet.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          )
        else
          for (final s in sessions) ...[
            _ActivityTile(session: s),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivitySessionSummary session;
  const _ActivityTile({required this.session});

  static const _icons = {
    'walk': Icons.directions_walk,
    'run': Icons.directions_run,
    'hike': Icons.terrain,
    'cycle': Icons.directions_bike,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _icons[session.activityType] ?? Icons.fitness_center;
    final date = DateFormat('MMM d · HH:mm').format(session.startedAt.toLocal());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.activityType[0].toUpperCase() +
                      session.activityType.substring(1),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(session.distanceLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.health,
                  )),
              Text('${session.steps} steps',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message,
            style: const TextStyle(color: AppColors.error),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      );
}
