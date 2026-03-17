import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/session_summary.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/sessions_provider.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/exercise_badge.dart';
import '../../../widgets/score_bar.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [if (isMobile) const ProfileIconButton()],
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No sessions yet',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/analyze'),
                    child: const Text('Analyze a Video'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(sessionsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _SessionTile(
                session: list[i],
                onDelete: () => _confirmDelete(context, ref, list[i]),
                onTap: () => context.go('/sessions/${list[i].id}'),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, SessionSummary s) async {
    final cs      = Theme.of(context).colorScheme;
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Delete Session?',
                style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('This will permanently remove the session and all its data.',
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) await ref.read(sessionsProvider.notifier).delete(s.id);
  }
}

// ── Session tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _SessionTile({
    required this.session, required this.onTap, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final date = DateFormat('EEE, MMM d · HH:mm')
        .format(DateTime.tryParse(session.createdAt) ?? DateTime.now());

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      confirmDismiss: (_) async { onDelete(); return false; },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(date, style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  if (!session.isCompleted) _StatusChip(status: session.status),
                  if (session.durationS != null)
                    Text(_dur(session.durationS!),
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              if (session.exerciseTypes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children:
                      session.exerciseTypes.map(ExerciseBadge.new).toList(),
                ),
              ],
              if (session.isCompleted) ...[
                const SizedBox(height: 10),
                Text('${session.totalReps} reps',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                ScoreBar(session.avgFormScore),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _dur(int s) {
    final m = s ~/ 60;
    return m > 0 ? '${m}m ${s % 60}s' : '${s}s';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isProcessing = status == 'processing';
    final color = isProcessing ? AppColors.warning : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
