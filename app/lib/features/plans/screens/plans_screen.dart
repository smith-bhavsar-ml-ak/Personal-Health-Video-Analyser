import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/models/workout_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/exercise_helpers.dart';
import '../providers/plans_provider.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync   = ref.watch(plansProvider);
    final generateState = ref.watch(generatePlanProvider);
    final isGenerating  = generateState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Plans'),
        actions: [
          FilledButton.icon(
            onPressed: isGenerating
                ? null
                : () async {
                    final plan = await ref
                        .read(generatePlanProvider.notifier)
                        .generate(ref);
                    if (plan != null && context.mounted) {
                      context.push('/plans/${plan.id}');
                    }
                  },
            icon: isGenerating
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(isGenerating ? 'Generating…' : 'Generate AI Plan'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No plans yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Tap "Generate AI Plan" to create a personalised\nworkout programme based on your profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(plansProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _PlanCard(plan: plans[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final progress  = plan.weekProgress;
    final completed = plan.completedExercises;
    final total     = plan.totalExercises;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/plans/${plan.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(plan.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ]),
          if (plan.description != null) ...[
            const SizedBox(height: 4),
            Text(plan.description!,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            _Chip(label: '${plan.durationWeeks}w', icon: Icons.calendar_today_outlined),
            const SizedBox(width: 8),
            _Chip(label: '$total exercises', icon: Icons.fitness_center_outlined),
          ]),
          const SizedBox(height: 12),
          // Progress bar
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: cs.outline.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(AppColors.health),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$completed/$total',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

// ── Plan detail screen ────────────────────────────────────────────────────────

class PlanDetailScreen extends ConsumerWidget {
  final String planId;
  const PlanDetailScreen({required this.planId, super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planProvider(planId));
    final cs        = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Detail'),
        actions: [
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete plan',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete plan?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ApiService.instance.deletePlan(planId);
                ref.invalidate(plansProvider);
                // ignore: use_build_context_synchronously
                context.pop();
              }
            },
          ),
        ],
      ),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (plan) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(planProvider(planId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Text(plan.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              if (plan.description != null) ...[
                const SizedBox(height: 6),
                Text(plan.description!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                _Chip(label: '${plan.durationWeeks} weeks', icon: Icons.calendar_today_outlined),
                const SizedBox(width: 8),
                _Chip(label: '${plan.completedExercises}/${plan.totalExercises} done',
                    icon: Icons.check_circle_outline),
              ]),
              const SizedBox(height: 16),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: plan.weekProgress,
                  minHeight: 8,
                  backgroundColor: cs.outline.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(AppColors.health),
                ),
              ),
              const SizedBox(height: 20),

              // Day-by-day schedule
              for (int day = 0; day < 7; day++) ...[
                if (plan.byDay.containsKey(day)) ...[
                  _DayHeader(dayName: _days[day], exerciseCount: plan.byDay[day]!.length),
                  const SizedBox(height: 6),
                  ...plan.byDay[day]!.map((ex) => _ExerciseItem(
                    planId: planId, exercise: ex,
                  )),
                  const SizedBox(height: 12),
                ] else ...[
                  _RestDayRow(dayName: _days[day]),
                ],
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String dayName;
  final int exerciseCount;
  const _DayHeader({required this.dayName, required this.exerciseCount});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(dayName,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
      ),
      const SizedBox(width: 10),
      Text('$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ]);
  }
}

class _RestDayRow extends StatelessWidget {
  final String dayName;
  const _RestDayRow({required this.dayName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(dayName,
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13,
                  color: cs.onSurfaceVariant)),
        ),
        const SizedBox(width: 10),
        Text('Rest day', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
      ]),
    );
  }
}

class _ExerciseItem extends ConsumerWidget {
  final String planId;
  final PlanExercise exercise;
  const _ExerciseItem({required this.planId, required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs        = Theme.of(context).colorScheme;
    final isDone    = exercise.isCompleted;
    final color     = getExerciseColor(exercise.exerciseType);
    final label     = getExerciseLabel(exercise.exerciseType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 52),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: isDone
            ? Border.all(color: AppColors.health.withValues(alpha: 0.4))
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(isDone ? Icons.check : Icons.fitness_center,
              size: 14, color: isDone ? AppColors.health : color),
        ),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13,
                decoration: isDone ? TextDecoration.lineThrough : null,
                color: isDone ? cs.onSurfaceVariant : null)),
        subtitle: Text(
          exercise.durationTargetS != null
              ? '${exercise.setsTarget} sets · ${exercise.durationTargetS}s hold'
              : '${exercise.setsTarget} sets × ${exercise.repsTarget} reps',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: GestureDetector(
          onTap: () => ref.read(planExerciseToggleProvider.notifier)
              .toggle(planId, exercise.id, ref),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.health.withValues(alpha: 0.15)
                  : cs.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone ? AppColors.health : cs.outline,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check, size: 16, color: AppColors.health)
                : null,
          ),
        ),
      ),
    );
  }
}
