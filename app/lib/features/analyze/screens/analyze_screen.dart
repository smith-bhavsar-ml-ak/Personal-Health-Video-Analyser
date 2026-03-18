import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/analyze_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/ai_feedback_panel.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/exercise_card.dart';
import '../../../widgets/score_ring.dart';

class AnalyzeScreen extends ConsumerStatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  ConsumerState<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends ConsumerState<AnalyzeScreen> {
  final _picker = ImagePicker();

  Future<void> _pickGallery() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.read(analyzeProvider.notifier).upload(
            bytes:    bytes,
            fileName: file.name,
          );
    } else {
      await ref
          .read(analyzeProvider.notifier)
          .upload(filePath: file.path, fileName: file.name);
    }
  }

  Future<void> _recordCamera() async {
    final file = await _picker.pickVideo(source: ImageSource.camera);
    if (file == null) return;
    await ref
        .read(analyzeProvider.notifier)
        .upload(filePath: file.path, fileName: file.name);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyzeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyze Workout'),
        actions: [
          if (state.phase != AnalyzePhase.idle)
            TextButton(
              onPressed: () => ref.read(analyzeProvider.notifier).reset(),
              child: const Text('New'),
            ),
          if (MediaQuery.of(context).size.width < 768)
            const ProfileIconButton(),
        ],
      ),
      body: _body(state),
    );
  }

  Widget _body(AnalyzeState state) => switch (state.phase) {
        AnalyzePhase.idle    => _PickerView(
            onGallery: _pickGallery,
            onCamera:  kIsWeb ? null : _recordCamera,
          ),
        AnalyzePhase.uploading   => const _ProgressView(
            step: 1, label: 'Uploading video…'),
        AnalyzePhase.processing  => const _ProgressView(
            step: 2, label: 'Analysing your workout…'),
        AnalyzePhase.done        => _ResultsView(session: state.session!),
        AnalyzePhase.failed      => _FailView(
            message: state.error ?? 'Unknown error',
            onRetry: () => ref.read(analyzeProvider.notifier).reset(),
          ),
      };
}

// ── Picker ────────────────────────────────────────────────────────────────────

class _PickerView extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback? onCamera;
  const _PickerView({required this.onGallery, this.onCamera});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.video_library_outlined,
                        size: 48, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Analyze your workout',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Upload or record a short exercise video.\n'
                      'MediaPipe will detect your pose and the AI will '
                      'score your form.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 20),
                      label: const Text('Choose from Gallery'),
                    ),
                    if (onCamera != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onCamera,
                        icon: const Icon(Icons.videocam_outlined, size: 20),
                        label: const Text('Record Video'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tips for best results',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    for (final tip in [
                      'Film in landscape, full body visible',
                      'Keep the camera still',
                      '15–60 seconds per exercise',
                      'Good lighting, uncluttered background',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 14, color: AppColors.health),
                            const SizedBox(width: 6),
                            Text(tip,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
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

// ── Progress ──────────────────────────────────────────────────────────────────

class _ProgressView extends StatelessWidget {
  final int step;   // 1 = uploading, 2 = processing (3 = backend cv, 4 = llm)
  final String label;
  const _ProgressView({required this.step, required this.label});

  static const _steps = [
    'Uploading',
    'Extracting Frames',
    'Pose Detection',
    'Generating Feedback',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 24),
              Text(label,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              // Step indicator
              for (var i = 0; i < _steps.length; i++) ...[
                _StepRow(
                  index: i + 1,
                  label: _steps[i],
                  state: i + 1 < step
                      ? _StepState.done
                      : i + 1 == step
                          ? _StepState.active
                          : _StepState.pending,
                ),
                if (i < _steps.length - 1)
                  Container(
                    width: 2, height: 18, margin: const EdgeInsets.only(left: 14),
                    color: i + 1 < step
                        ? AppColors.health
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  final int index;
  final String label;
  final _StepState state;
  const _StepRow({required this.index, required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final color = state == _StepState.done    ? AppColors.health
                : state == _StepState.active  ? AppColors.primary
                : AppColors.textMuted;
    final icon  = state == _StepState.done
        ? const Icon(Icons.check_circle, size: 20, color: AppColors.health)
        : state == _StepState.active
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              )
            : const Icon(Icons.radio_button_unchecked, size: 20, color: AppColors.textMuted);

    return Row(
      children: [
        SizedBox(width: 28, height: 28, child: Center(child: icon)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 14, color: color,
            fontWeight: state == _StepState.active ? FontWeight.w600 : FontWeight.w400)),
      ],
    );
  }
}

// ── Results ───────────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final dynamic session;
  const _ResultsView({required this.session});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary row
        Row(
          children: [
            ScoreRing(score: (session.avgFormScore as double), size: 72, strokeWidth: 6),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analysis Complete',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${session.totalReps} total reps · ${session.exerciseSets.length} exercise(s)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Full Detail'),
              onPressed: () => context.go('/sessions/${session.id}?from=/analyze'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Exercise cards
        for (final s in session.exerciseSets as List) ...[
          ExerciseCard(set: s),
          const SizedBox(height: 10),
        ],

        // AI feedback
        if (session.aiFeedback != null) ...[
          const SizedBox(height: 8),
          AIFeedbackPanel(feedback: session.aiFeedback!),
        ],
      ],
    );
  }
}

// ── Fail ──────────────────────────────────────────────────────────────────────

class _FailView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FailView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Analysis failed',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
}
