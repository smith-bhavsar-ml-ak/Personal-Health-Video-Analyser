import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/models/progress.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/progress_provider.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  final _weightCtrl = TextEditingController();
  bool _loggingWeight = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _logWeight() async {
    final kg = double.tryParse(_weightCtrl.text.trim());
    if (kg == null || kg <= 0) return;
    setState(() => _loggingWeight = true);
    final ok = await ref.read(logWeightProvider.notifier).log(kg, ref);
    setState(() => _loggingWeight = false);
    if (ok && mounted) {
      _weightCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Weight ${kg.toStringAsFixed(1)} kg logged')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(progressSummaryProvider);
          ref.invalidate(formTrendProvider);
          ref.invalidate(exerciseStatsProvider);
          ref.invalidate(weightHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── KPI summary ────────────────────────────────────────────────
            _SummaryCards(ref: ref),
            const SizedBox(height: 20),

            // ── Log weight ────────────────────────────────────────────────
            _SectionTitle('Log Today\'s Weight'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 78.5',
                    suffixText: 'kg',
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _loggingWeight ? null : _logWeight,
                child: _loggingWeight
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Log'),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Charts: 2-col on desktop, stacked on mobile ───────────────
            if (isDesktop) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _SectionTitle('Weight Over Time'),
                        const SizedBox(height: 8),
                        Expanded(child: _WeightChart(ref: ref)),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _SectionTitle('Form Score Trend'),
                        const SizedBox(height: 8),
                        Expanded(child: _FormTrendChart(ref: ref)),
                      ]),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _SectionTitle('Weight Over Time'),
              const SizedBox(height: 8),
              _WeightChart(ref: ref),
              const SizedBox(height: 20),
              _SectionTitle('Form Score Trend'),
              const SizedBox(height: 8),
              _FormTrendChart(ref: ref),
            ],
            const SizedBox(height: 20),

            // ── Exercise breakdown ────────────────────────────────────────
            _SectionTitle('Exercise Breakdown'),
            const SizedBox(height: 8),
            _ExerciseBreakdown(ref: ref),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── KPI Summary cards ─────────────────────────────────────────────────────────

class _SummaryCards extends ConsumerWidget {
  final WidgetRef ref;
  const _SummaryCards({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(progressSummaryProvider);
    return async.when(
      loading: () => const _SkeletonRow(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) => Row(children: [
        _KpiCard(label: 'Sessions',  value: '${s.totalSessions}',        icon: Icons.fitness_center, color: AppColors.primary),
        const SizedBox(width: 10),
        _KpiCard(label: 'Total Reps', value: '${s.totalReps}',           icon: Icons.repeat_rounded,  color: AppColors.health),
        const SizedBox(width: 10),
        _KpiCard(label: 'Avg Score',  value: '${s.avgFormScore.toStringAsFixed(0)}%', icon: Icons.star_outline, color: AppColors.warning),
      ]),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

// ── Weight chart ──────────────────────────────────────────────────────────────

class _WeightChart extends ConsumerWidget {
  final WidgetRef ref;
  const _WeightChart({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weightHistoryProvider);
    return async.when(
      loading: () => const _ChartSkeleton(),
      error: (_, __) => const _ChartEmpty(message: 'No weight data yet'),
      data: (points) {
        if (points.isEmpty) return const _ChartEmpty(message: 'No weight logged yet.\nUse the field above to start tracking.');
        return _LineChartCard(
          points: points.map((p) => FlSpot(
            p.date.millisecondsSinceEpoch.toDouble(),
            p.weightKg,
          )).toList(),
          color: AppColors.info,
          yLabel: (v) => '${v.toStringAsFixed(0)} kg',
          xLabel: (v) => DateFormat('d MMM').format(
            DateTime.fromMillisecondsSinceEpoch(v.toInt()),
          ),
          minY: points.map((p) => p.weightKg).reduce((a, b) => a < b ? a : b) - 2,
          maxY: points.map((p) => p.weightKg).reduce((a, b) => a > b ? a : b) + 2,
        );
      },
    );
  }
}

// ── Form trend chart ──────────────────────────────────────────────────────────

class _FormTrendChart extends ConsumerWidget {
  final WidgetRef ref;
  const _FormTrendChart({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(formTrendProvider);
    return async.when(
      loading: () => const _ChartSkeleton(),
      error: (_, __) => const _ChartEmpty(message: 'No form data yet'),
      data: (points) {
        if (points.isEmpty) return const _ChartEmpty(message: 'Complete a workout to see your form trend.');
        return _LineChartCard(
          points: points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.avgFormScore)).toList(),
          color: AppColors.primary,
          yLabel: (v) => '${v.toStringAsFixed(0)}%',
          xLabel: (v) {
            final idx = v.toInt();
            if (idx < 0 || idx >= points.length) return '';
            return DateFormat('d MMM').format(points[idx].date);
          },
          minY: 0,
          maxY: 100,
        );
      },
    );
  }
}

// ── Shared line chart ─────────────────────────────────────────────────────────

class _LineChartCard extends StatelessWidget {
  final List<FlSpot> points;
  final Color color;
  final String Function(double) yLabel;
  final String Function(double) xLabel;
  final double minY, maxY;

  const _LineChartCard({
    required this.points,
    required this.color,
    required this.yLabel,
    required this.xLabel,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: cs.outline.withValues(alpha: 0.4), strokeWidth: 0.8),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (v, _) => Text(yLabel(v),
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: points.length <= 10,
                reservedSize: 22,
                interval: points.length > 1 ? (points.last.x - points.first.x) / 4 : 1,
                getTitlesWidget: (v, _) => Text(xLabel(v),
                    style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(
                show: points.length <= 15,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3, color: color, strokeWidth: 1.5,
                  strokeColor: cs.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.10),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.surfaceContainerHigh,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                yLabel(s.y),
                TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Exercise breakdown ────────────────────────────────────────────────────────

class _ExerciseBreakdown extends ConsumerWidget {
  final WidgetRef ref;
  const _ExerciseBreakdown({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final async = ref.watch(exerciseStatsProvider);
    return async.when(
      loading: () => const _ChartSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.isEmpty) return const _ChartEmpty(message: 'No exercise data yet.');
        if (!isDesktop) {
          return Column(
            children: stats.map((s) => _ExerciseStatRow(stat: s)).toList(),
          );
        }
        // Desktop: 3-column grid
        final rows = <Widget>[];
        for (var i = 0; i < stats.length; i += 3) {
          final chunk = stats.skip(i).take(3).toList();
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = 0; j < 3; j++) ...[
                    Expanded(
                      child: j < chunk.length
                          ? _ExerciseStatRow(stat: chunk[j], noBottomMargin: true)
                          : const SizedBox.shrink(),
                    ),
                    if (j < 2) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _ExerciseStatRow extends StatelessWidget {
  final ExerciseStat stat;
  final bool noBottomMargin;
  const _ExerciseStatRow({required this.stat, this.noBottomMargin = false});

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final label = stat.exerciseType.replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return Container(
      margin: noBottomMargin ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          Text('${stat.totalReps} reps · ${stat.setCount} sets',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 8),
        // Form score bar
        Row(children: [
          Text('Form ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stat.avgFormScore / 100,
                minHeight: 6,
                backgroundColor: cs.outline.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(_scoreColor(stat.avgFormScore)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${stat.avgFormScore.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _scoreColor(stat.avgFormScore))),
        ]),
        const SizedBox(height: 4),
        // Accuracy bar
        Row(children: [
          Text('Acc  ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stat.accuracy,
                minHeight: 6,
                backgroundColor: cs.outline.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(AppColors.info),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(stat.accuracy * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.info)),
        ]),
      ]),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.health;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }
}

// ── Utility widgets ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      );
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => Row(children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(child: Container(height: 90, decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ))),
          if (i < 2) const SizedBox(width: 10),
        ],
      ]);
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
      );
}

class _ChartEmpty extends StatelessWidget {
  final String message;
  const _ChartEmpty({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      );
}
