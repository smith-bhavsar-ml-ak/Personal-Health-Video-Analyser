import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../../../core/models/session_result.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/sessions_provider.dart';
import '../../../widgets/ai_feedback_panel.dart';
import '../../../widgets/exercise_card.dart';

void _shareSession(BuildContext context, SessionResult s) {
  final date = DateFormat('MMM d, yyyy').format(
      DateTime.tryParse(s.createdAt) ?? DateTime.now());
  final exercises = s.exerciseSets
      .map((e) => e.exerciseType.replaceAll('_', ' '))
      .toSet()
      .join(', ');
  final lines = [
    'Workout — $date',
    'Form Score: ${s.avgFormScore.toStringAsFixed(0)}%',
    'Total Reps: ${s.totalReps}',
    if (exercises.isNotEmpty) 'Exercises: $exercises',
    if (s.durationS != null)
      'Duration: ${s.durationS! ~/ 60}m ${s.durationS! % 60}s',
    '',
    'Tracked with Personal Health Video Analyzer',
  ];
  Share.share(lines.join('\n'));
}

class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;
  const SessionDetailScreen({required this.sessionId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(sessionResultProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        leading: BackButton(onPressed: () => context.go('/history')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share session',
            onPressed: () {
              result.whenData((s) => _shareSession(context, s));
            },
          ),
          IconButton(
            icon: const Icon(Icons.mic_outlined),
            tooltip: 'Ask AI Coach',
            onPressed: () => context.go('/assistant?session=$sessionId'),
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load session: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(sessionResultProvider(sessionId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (session) => _SessionDetailBody(session: session),
      ),
    );
  }
}

class _SessionDetailBody extends StatelessWidget {
  final SessionResult session;
  const _SessionDetailBody({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, MMMM d, yyyy · HH:mm')
        .format(DateTime.tryParse(session.createdAt) ?? DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Meta
        Text(date, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),

        // Stats grid
        Row(
          children: [
            _StatCard(
              label: 'Total Reps',
              value: '${session.totalReps}',
              icon: Icons.repeat,
              color: AppColors.health,
            ),
            const SizedBox(width: 10),
            _StatCard(
              label: 'Form Score',
              value: '${session.avgFormScore.round()}%',
              icon: Icons.grade_outlined,
              color: session.avgFormScore >= 80
                  ? AppColors.health
                  : session.avgFormScore >= 50
                      ? AppColors.warning
                      : AppColors.error,
            ),
            const SizedBox(width: 10),
            _StatCard(
              label: 'Duration',
              value: session.durationS != null
                  ? _dur(session.durationS!)
                  : '—',
              icon: Icons.timer_outlined,
              color: AppColors.info,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Exercise sets
        if (session.exerciseSets.isNotEmpty) ...[
          Text('Exercises',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final s in session.exerciseSets) ...[
            ExerciseCard(set: s, repScores: s.formScore > 0 ? null : null),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
        ],

        // AI Feedback
        if (session.aiFeedback != null) ...[
          Text('AI Coaching',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          AIFeedbackPanel(feedback: session.aiFeedback!),
          const SizedBox(height: 24),
        ],

        // Voice query history
        if (session.voiceQueries.isNotEmpty) ...[
          Text('Q&A History',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final q in session.voiceQueries) ...[
            _VoiceQueryTile(query: q),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  static String _dur(int s) {
    final m = s ~/ 60;
    return m > 0 ? '${m}m ${s % 60}s' : '${s}s';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(color: color)),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class _VoiceQueryTile extends StatelessWidget {
  final dynamic query;
  const _VoiceQueryTile({required this.query});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    query.queryText as String,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    query.responseText as String,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
