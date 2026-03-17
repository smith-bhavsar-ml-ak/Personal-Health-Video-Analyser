import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/assistant_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/exercise_badge.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with SingleTickerProviderStateMixin {
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? prefill]) async {
    final text = prefill ?? _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await ref.read(assistantProvider.notifier).sendText(text);
    _scrollToBottom();
  }

  Future<void> _toggleMic() async {
    await ref.read(assistantProvider.notifier).toggleRecording();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(assistantProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (state.messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Coach'),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              icon:    const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear conversation',
              onPressed: () =>
                  ref.read(assistantProvider.notifier).clearConversation(),
            ),
          if (isMobile) const ProfileIconButton(),
        ],
      ),
      body: Column(
        children: [
          // ── Today's workout context banner ──────────────────────────────
          if (state.sessions.isNotEmpty)
            _TodayBanner(state: state),

          // ── Speaking indicator ──────────────────────────────────────────
          if (state.isPlayingAudio)
            _SpeakingBar(),

          // ── Main content area ───────────────────────────────────────────
          Expanded(
            child: state.sessions.isEmpty
                ? const _NoSessionView()
                : state.isRecording
                    ? _RecordingOverlay(pulseCtrl: _pulseCtrl)
                    : _ChatList(
                        messages:   state.messages,
                        isLoading:  state.isLoading,
                        controller: _scrollCtrl,
                        onSuggest:  _send,
                      ),
          ),

          // ── Error ───────────────────────────────────────────────────────
          if (state.error != null) _ErrorBanner(message: state.error!),

          // ── Input bar ───────────────────────────────────────────────────
          if (state.sessions.isNotEmpty)
            _InputBar(
              controller:  _textCtrl,
              isLoading:   state.isLoading,
              isRecording: state.isRecording,
              onSend:      () => _send(),
              onRecord:    _toggleMic,
            ),
        ],
      ),
    );
  }
}

// ── Today's session context banner ─────────────────────────────────────────────

class _TodayBanner extends StatelessWidget {
  final AssistantState state;
  const _TodayBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Earliest session of the latest day for the date label
    final latestSession = state.todaySessions.isNotEmpty
        ? state.todaySessions.first
        : state.activeSession;
    if (latestSession == null) return const SizedBox.shrink();

    final date = DateFormat('EEE, MMM d').format(
      DateTime.tryParse(latestSession.createdAt) ?? DateTime.now(),
    );
    final exercises = state.todayExercises;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: cs.primary),
          const SizedBox(width: 7),
          Text(date,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final ex in exercises) ...[
                    ExerciseBadge(ex),
                    const SizedBox(width: 4),
                  ],
                  if (exercises.isEmpty)
                    Text('No exercises',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${state.todaySessions.length} session${state.todaySessions.length == 1 ? "" : "s"}',
              style: TextStyle(
                  fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Speaking indicator bar ─────────────────────────────────────────────────────

class _SpeakingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.health.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.volume_up_outlined, size: 16, color: AppColors.health),
          const SizedBox(width: 8),
          Text(
            'AI is speaking…',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.health, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 20, height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.health,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-screen recording overlay ─────────────────────────────────────────────

class _RecordingOverlay extends ConsumerWidget {
  final AnimationController pulseCtrl;
  const _RecordingOverlay({required this.pulseCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amplitude = ref.watch(
        assistantProvider.select((s) => s.amplitude)); // 0–1

    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (context, child) {
              // Scale: base pulse + amplitude boost
              final pulse = 0.10 * pulseCtrl.value;
              final voice = 0.25 * amplitude;
              final scale = 1.0 + pulse + voice;
              final alpha = 0.12 + 0.18 * pulseCtrl.value + 0.20 * amplitude;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring (voice-reactive)
                  Container(
                    width:  100 * scale,
                    height: 100 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error.withValues(alpha: alpha * 0.5),
                    ),
                  ),
                  // Inner ring
                  Container(
                    width:  76 * scale,
                    height: 76 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error.withValues(alpha: alpha),
                    ),
                  ),
                  // Mic icon
                  Container(
                    width: 56, height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 28),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Listening…',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Auto-stops when you pause · or tap mic to stop',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Chat list ─────────────────────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final ScrollController controller;
  final ValueChanged<String> onSuggest;
  const _ChatList({
    required this.messages,
    required this.isLoading,
    required this.controller,
    required this.onSuggest,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isLoading) {
      return _SuggestedQuestions(onTap: onSuggest);
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (isLoading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == messages.length) return const _TypingIndicator();
        return _MessageBubble(message: messages[i]);
      },
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? AppColors.primary.withValues(alpha: 0.12)
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(14),
              topRight:    const Radius.circular(14),
              bottomLeft:  Radius.circular(isUser ? 14 : 4),
              bottomRight: Radius.circular(isUser ? 4  : 14),
            ),
            border: Border.all(
              color: isUser
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : cs.outline,
            ),
          ),
          child: Text(message.text,
              style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
            ),
            const SizedBox(width: 8),
            Text('Thinking…', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Suggested questions ───────────────────────────────────────────────────────

class _SuggestedQuestions extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _SuggestedQuestions({required this.onTap});

  static const _questions = [
    'How was my workout today?',
    'What should I focus on improving?',
    'How was my form for each exercise?',
    'How many reps did I complete correctly?',
    'Give me tips to improve my technique.',
    'Which exercise needs the most work?',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 28, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text('AI Fitness Coach',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Tap a question or use the mic to ask.\n'
                'I use all of today\'s workout sessions as context.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Try asking…',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        for (final q in _questions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onTap(q),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(q,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.onSurface)),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 13, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Voice-first input bar ──────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onRecord;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.isRecording,
    required this.onSend,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Text input (secondary)
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                enabled: !isRecording,
                onSubmitted: isLoading || isRecording ? null : (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isRecording
                      ? 'Listening…'
                      : 'Ask about your workout…',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button (visible when text present and not recording)
            if (!isRecording)
              _SmallBtn(
                icon:    Icons.send_rounded,
                color:   AppColors.primary,
                tooltip: 'Send',
                onTap:   isLoading ? null : onSend,
              ),
            const SizedBox(width: 8),
            // Mic button — PRIMARY (large round)
            _MicButton(
              isRecording: isRecording,
              isLoading:   isLoading,
              onTap:       isLoading ? null : onRecord,
            ),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isRecording;
  final bool isLoading;
  final VoidCallback? onTap;
  const _MicButton({
    required this.isRecording,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? AppColors.error : AppColors.primary;
    return Tooltip(
      message: isRecording ? 'Stop recording' : 'Voice message',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null
                ? color.withValues(alpha: 0.35)
                : color,
            boxShadow: isRecording
                ? [BoxShadow(color: AppColors.error.withValues(alpha: 0.4),
                    blurRadius: 12, spreadRadius: 2)]
                : [],
          ),
          child: Icon(
            isRecording ? Icons.stop_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  const _SmallBtn({
    required this.icon, required this.color,
    required this.tooltip, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 44, height: 44,
            child: Icon(icon,
                color: onTap == null ? cs.onSurfaceVariant : color, size: 22),
          ),
        ),
      ),
    );
  }
}

// ── No session view ────────────────────────────────────────────────────────────

class _NoSessionView extends StatelessWidget {
  const _NoSessionView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center_outlined,
                size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No completed sessions yet.',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Analyze a workout video first, then come back to chat with your AI coach.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.error.withValues(alpha: 0.10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 13, color: AppColors.error)),
            ),
          ],
        ),
      );
}
