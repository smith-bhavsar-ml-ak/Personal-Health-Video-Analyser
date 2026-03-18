import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/models/exercise_set.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/exercise_helpers.dart';
import 'exercise_badge.dart';
import 'score_ring.dart';

class ExerciseCard extends StatefulWidget {
  final ExerciseSet set;
  final List<double>? repScores; // optional per-rep form scores (0–100)

  const ExerciseCard({required this.set, this.repScores, super.key});

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.set;
    final color = getExerciseColor(s.exerciseType);

    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          // Header row (always visible)
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  ExerciseBadge(s.exerciseType),
                  const Spacer(),
                  _StatChip(
                    icon: Icons.repeat,
                    label: '${s.repCount} reps',
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  ScoreRing(score: s.formScore, size: 44, strokeWidth: 4),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (_expanded) ...[
            Divider(height: 1, color: cs.outline),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _StatTile(label: 'Correct Reps', value: '${s.correctReps}/${s.repCount}', color: AppColors.health),
                      const SizedBox(width: 12),
                      _StatTile(label: 'Duration',     value: '${s.durationS}s'),
                      const SizedBox(width: 12),
                      _StatTile(label: 'Form Score',   value: '${s.formScore.round()}%',
                          color: s.formScore >= 80 ? AppColors.health
                               : s.formScore >= 50 ? AppColors.warning
                               : AppColors.error),
                    ],
                  ),

                  // Rep score chart — use persisted scores from model
                  if (s.repScores.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      Text('Rep-by-Rep', style: Theme.of(context).textTheme.labelLarge),
                      const Spacer(),
                      _RepLegend(),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: _RepScoreChart(scores: s.repScores, color: color),
                    ),
                    const SizedBox(height: 8),
                    // Rep quality pills
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: s.repScores.asMap().entries.map((e) {
                        final good = e.value >= 80;
                        final clr  = good ? AppColors.health : AppColors.warning;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: clr.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: clr.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            'R${e.key + 1}  ${e.value.round()}%',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: clr),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Posture errors
                  if (s.postureErrors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Form Issues',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    for (final err in s.postureErrors)
                      _PostureErrorRow(error: err),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      );
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatTile({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color ?? cs.onSurface,
                )),
          ],
        ),
      ),
    );
  }
}

class _PostureErrorRow extends StatelessWidget {
  final PostureError error;
  const _PostureErrorRow({required this.error});

  Color _severityColor() => switch (error.severity) {
        'high'   => AppColors.error,
        'medium' => AppColors.warning,
        _        => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    final color = _severityColor();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.errorType.replaceAll('_', ' '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${error.occurrences}× · ${error.severity} severity',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepLegend extends StatelessWidget {
  const _RepLegend();

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _Dot(AppColors.health),
        const SizedBox(width: 4),
        Text('Good ≥80%', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(width: 10),
        _Dot(AppColors.warning),
        const SizedBox(width: 4),
        Text('Needs work', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]);
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _RepScoreChart extends StatelessWidget {
  final List<double> scores;
  final Color color;
  const _RepScoreChart({required this.scores, required this.color});

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barGroups: scores.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: color.withOpacity(0.8),
                width: 10,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (v, _) => Text(
                'R${v.toInt() + 1}',
                style: TextStyle(fontSize: 10, color: mutedColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
