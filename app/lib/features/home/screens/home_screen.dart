import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/session_summary.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/exercise_helpers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sessions/providers/sessions_provider.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/exercise_badge.dart';
import '../../../widgets/score_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth     = ref.watch(authProvider);
    final sessions = ref.watch(sessionsProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, ${_firstName(auth.email)}'),
            Text(
              'Your fitness dashboard',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (isMobile) const ProfileIconButton(),
        ],
      ),
      body: sessions.when(
        loading: () => const _Skeleton(),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(sessionsProvider.notifier).refresh(),
        ),
        data: (list) {
          final completed = list.where((s) => s.isCompleted).toList();
          return RefreshIndicator(
            onRefresh: () => ref.read(sessionsProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ── Stats row ─────────────────────────────────────────────
                _StatsRow(sessions: completed),
                const SizedBox(height: 20),

                // ── Charts (2-col on desktop, stacked on mobile) ──────────
                if (completed.isNotEmpty) ...[
                  if (isMobile) ...[
                    _ExerciseBreakdown(sessions: completed),
                    const SizedBox(height: 20),
                    _WeeklyActivity(sessions: completed),
                    const SizedBox(height: 20),
                    if (completed.length >= 3) ...[
                      _FormScoreTrend(sessions: completed),
                      const SizedBox(height: 20),
                    ],
                  ] else ...[
                    // Exercise breakdown | Weekly activity side-by-side
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _ExerciseBreakdown(sessions: completed)),
                          const SizedBox(width: 16),
                          Expanded(child: _WeeklyActivity(sessions: completed)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Form score trend — half width on desktop
                    if (completed.length >= 3) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _FormScoreTrend(sessions: completed),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ],

                // ── Recent sessions ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Sessions',
                        style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () => context.go('/history'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (completed.isEmpty)
                  _EmptyState(
                    message: 'No sessions yet.\nUpload a workout video to get started.',
                    icon: Icons.fitness_center_outlined,
                    actionLabel: 'Analyze Video',
                    onAction: () => context.go('/analyze'),
                  )
                else
                  for (final s in completed.take(3)) ...[
                    _SessionCard(session: s),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _firstName(String? email) {
    if (email == null) return 'there';
    final local = email.split('@').first;
    return local[0].toUpperCase() + local.substring(1);
  }
}

// ── Stats row (3 cards) ───────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<SessionSummary> sessions;
  const _StatsRow({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeek  = sessions
        .where((s) => (DateTime.tryParse(s.createdAt) ?? now).isAfter(weekStart))
        .length;
    final avgScore = sessions.isEmpty
        ? 0.0
        : sessions.fold(0.0, (s, v) => s + v.avgFormScore) / sessions.length;

    return Row(
      children: [
        _StatCard(
          label: 'This Week',
          value: '$thisWeek',
          sub: 'sessions',
          icon: Icons.calendar_today_outlined,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'All Time',
          value: '${sessions.length}',
          sub: 'sessions',
          icon: Icons.fitness_center_outlined,
          color: AppColors.health,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Avg Score',
          value: '${avgScore.round()}%',
          sub: 'form quality',
          icon: Icons.grade_outlined,
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label, required this.value, required this.sub,
    required this.icon,  required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontSize: 22, color: color)),
            Text(sub,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

// ── Exercise breakdown (horizontal bars per exercise type) ────────────────────

class _ExerciseBreakdown extends StatelessWidget {
  final List<SessionSummary> sessions;
  const _ExerciseBreakdown({required this.sessions});

  @override
  Widget build(BuildContext context) {
    // Count sessions per exercise type
    final freq = <String, int>{};
    for (final s in sessions) {
      for (final t in s.exerciseTypes) {
        freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    if (freq.isEmpty) return const SizedBox.shrink();

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.first.value.toDouble();
    final cs  = Theme.of(context).colorScheme;

    return _Card(
      title: 'Exercise Breakdown',
      subtitle: 'Sessions per exercise type',
      icon: Icons.bar_chart_outlined,
      child: Column(
        children: sorted.map((e) {
          final color   = getExerciseColor(e.key);
          final frac    = e.value / max;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExerciseBadge(e.key),
                    const Spacer(),
                    Text(
                      '${e.value} session${e.value == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 8,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Weekly activity bar chart (last 7 days) ───────────────────────────────────

class _WeeklyActivity extends StatelessWidget {
  final List<SessionSummary> sessions;
  const _WeeklyActivity({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final now  = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    final counts = <int>[];
    for (final day in days) {
      final c = sessions.where((s) {
        final d = DateTime.tryParse(s.createdAt);
        return d != null &&
            d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;
      counts.add(c);
    }

    final maxVal = counts.fold(0, (a, b) => a > b ? a : b).toDouble();
    final cs = Theme.of(context).colorScheme;

    return _Card(
      title: 'Weekly Activity',
      subtitle: 'Sessions in the last 7 days',
      icon: Icons.event_outlined,
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            maxY: (maxVal < 3 ? 3 : maxVal + 1).toDouble(),
            gridData: FlGridData(
              show: true,
              horizontalInterval: 1,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: cs.outline,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final day = days[v.toInt()];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('E').format(day)[0],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(7, (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: counts[i].toDouble(),
                  color: counts[i] > 0
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.12),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }
}

// ── Form score trend (line chart) ─────────────────────────────────────────────

class _FormScoreTrend extends StatelessWidget {
  final List<SessionSummary> sessions;
  const _FormScoreTrend({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final recent = sessions.take(10).toList().reversed.toList();
    final cs     = Theme.of(context).colorScheme;

    final spots = <FlSpot>[];
    for (var i = 0; i < recent.length; i++) {
      spots.add(FlSpot(i.toDouble(), recent[i].avgFormScore));
    }

    return _Card(
      title: 'Form Score Trend',
      subtitle: 'Last ${recent.length} sessions',
      icon: Icons.show_chart_outlined,
      child: SizedBox(
        height: 120,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 25,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: cs.outline, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 25,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppColors.health,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.health,
                    strokeWidth: 1.5,
                    strokeColor: cs.surface,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.health.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final SessionSummary session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, HH:mm')
        .format(DateTime.tryParse(session.createdAt) ?? DateTime.now());
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => context.go('/sessions/${session.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(date, style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                if (session.durationS != null)
                  Text(_duration(session.durationS!),
                      style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: session.exerciseTypes.map(ExerciseBadge.new).toList(),
            ),
            const SizedBox(height: 10),
            ScoreBar(session.avgFormScore),
          ],
        ),
      ),
    );
  }

  static String _duration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return m > 0 ? '${m}m ${sec}s' : '${s}s';
  }
}

// ── Reusable card wrapper ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Widget child;
  const _Card({
    required this.title, required this.subtitle,
    required this.icon,  required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: List.generate(3, (_) => const Expanded(child: _Block(height: 88, mr: 10)))),
          const SizedBox(height: 20),
          const _Block(height: 160),
          const SizedBox(height: 20),
          const _Block(height: 140),
          const SizedBox(height: 20),
          const _Block(height: 20, width: 140),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) ...[
            const _Block(height: 90),
            const SizedBox(height: 10),
          ],
        ],
      );
}

class _Block extends StatelessWidget {
  final double height;
  final double? width;
  final double mr;
  const _Block({required this.height, this.width, this.mr = 0});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(right: mr),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;
  const _EmptyState({
    required this.message, required this.icon,
    required this.actionLabel, required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
