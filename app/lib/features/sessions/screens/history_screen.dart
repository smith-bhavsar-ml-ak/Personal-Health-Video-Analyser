import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/session_summary.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/sessions_provider.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/exercise_badge.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final width    = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    // Desktop: 4 cards per row (3/12 grid), tablet: 2, mobile: 1
    final crossAxisCount = isMobile ? 1 : (width < 1100 ? 2 : 4);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [if (isMobile) const ProfileIconButton()],
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) return _EmptyState();
          return RefreshIndicator(
            onRefresh: () => ref.read(sessionsProvider.notifier).refresh(),
            child: isMobile
                ? _MobileList(
                    sessions: list,
                    onDelete: (s) => _confirmDelete(context, ref, s),
                  )
                : _DesktopGrid(
                    sessions:      list,
                    crossAxisCount: crossAxisCount,
                    onDelete: (s) => _confirmDelete(context, ref, s),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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

// ── Desktop grid ──────────────────────────────────────────────────────────────

class _DesktopGrid extends StatelessWidget {
  final List<SessionSummary> sessions;
  final int crossAxisCount;
  final void Function(SessionSummary) onDelete;

  const _DesktopGrid({
    required this.sessions,
    required this.crossAxisCount,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing:  14,
        childAspectRatio: 1.55, // wide-ish compact card
      ),
      itemCount:   sessions.length,
      itemBuilder: (context, i) => _GridCard(
        session:  sessions[i],
        onDelete: () => onDelete(sessions[i]),
        onTap:    () => context.go('/sessions/${sessions[i].id}'),
      ),
    );
  }
}

// ── Mobile list ───────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final List<SessionSummary> sessions;
  final void Function(SessionSummary) onDelete;

  const _MobileList({required this.sessions, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding:           const EdgeInsets.all(16),
      itemCount:         sessions.length,
      separatorBuilder:  (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _MobileTile(
        session:  sessions[i],
        onDelete: () => onDelete(sessions[i]),
        onTap:    () => context.go('/sessions/${sessions[i].id}'),
      ),
    );
  }
}

// ── Desktop grid card ─────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GridCard({required this.session, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final dt     = DateTime.tryParse(session.createdAt) ?? DateTime.now();
    final date   = DateFormat('MMM d').format(dt);
    final time   = DateFormat('HH:mm').format(dt);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: date + status + delete ───────────────────────────
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Text(time,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  if (!session.isCompleted)
                    _MiniChip(status: session.status),
                  _DeleteBtn(onDelete: onDelete),
                ],
              ),

              const SizedBox(height: 10),

              // ── Row 2: exercise badges ───────────────────────────────────
              Expanded(
                child: Wrap(
                  spacing: 5, runSpacing: 5,
                  children: session.exerciseTypes
                      .map(ExerciseBadge.new)
                      .toList(),
                ),
              ),

              const SizedBox(height: 8),

              // ── Row 3: stats chips ───────────────────────────────────────
              if (session.isCompleted)
                Row(
                  children: [
                    _StatChip(
                      icon:  Icons.repeat_rounded,
                      label: '${session.totalReps} reps',
                    ),
                    if (session.durationS != null) ...[
                      const SizedBox(width: 6),
                      _StatChip(
                        icon:  Icons.timer_outlined,
                        label: _dur(session.durationS!),
                      ),
                    ],
                    const Spacer(),
                    _FormLabel(score: session.avgFormScore),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile tile (unchanged design, slightly polished) ─────────────────────────

class _MobileTile extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MobileTile({required this.session, required this.onTap, required this.onDelete});

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(date,
                            style: Theme.of(context).textTheme.bodySmall),
                        const Spacer(),
                        if (!session.isCompleted)
                          _MiniChip(status: session.status),
                        if (session.durationS != null)
                          Text(_dur(session.durationS!),
                              style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 4),
                        _DeleteBtn(onDelete: onDelete),
                      ],
                    ),
                    if (session.exerciseTypes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: session.exerciseTypes
                            .map(ExerciseBadge.new)
                            .toList(),
                      ),
                    ],
                    if (session.isCompleted) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatChip(
                            icon:  Icons.repeat_rounded,
                            label: '${session.totalReps} reps',
                          ),
                          const Spacer(),
                          _FormLabel(score: session.avgFormScore),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  final double score;
  const _FormLabel({required this.score});

  Color _color() {
    if (score >= 80) return AppColors.health;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Form ${score.round()}%',
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String status;
  const _MiniChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isProcessing = status == 'processing';
    final color = isProcessing ? AppColors.warning : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DeleteBtn extends StatelessWidget {
  final VoidCallback onDelete;
  const _DeleteBtn({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDelete,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(Icons.delete_outline,
            size: 16, color: AppColors.error.withValues(alpha: 0.7)),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () => GoRouter.of(context).go('/analyze'),
              child: const Text('Analyze a Video'),
            ),
          ),
        ],
      ),
    );
  }
}

String _dur(int s) {
  final m = s ~/ 60;
  return m > 0 ? '${m}m ${s % 60}s' : '${s}s';
}
