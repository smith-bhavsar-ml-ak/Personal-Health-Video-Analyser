import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../core/models/session_result.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/exercise_helpers.dart';

/// Renders an off-screen branded share card then shares it as PNG.
Future<void> shareSessionCard(BuildContext context, SessionResult session) async {
  final boundary = GlobalKey();
  final overlay = OverlayEntry(
    builder: (_) => Positioned(
      left: -4000, top: -4000,
      child: RepaintBoundary(
        key: boundary,
        child: _ShareCardWidget(session: session),
      ),
    ),
  );

  // Capture overlay state before any async gap
  final overlayState = Overlay.of(context);
  overlayState.insert(overlay);

  // Wait for the overlay to be fully laid out (one microtask is not enough on web)
  await WidgetsBinding.instance.endOfFrame;

  try {
    final ctx = boundary.currentContext;
    if (ctx == null) {
      overlay.remove();
      return;
    }
    final render = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (render == null) {
      overlay.remove();
      return;
    }
    // Web canvas has a lower pixel ratio limit; use 2× on web, 3× elsewhere
    final pixelRatio = kIsWeb ? 2.0 : 3.0;
    final image = await render.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final date = DateFormat('MMM d yyyy').format(
      DateTime.tryParse(session.createdAt) ?? DateTime.now(),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: 'workout_$date.png', mimeType: 'image/png')],
        subject: 'My Workout — $date',
      ),
    );
  } finally {
    overlay.remove();
  }
}

class _ShareCardWidget extends StatelessWidget {
  final SessionResult session;
  const _ShareCardWidget({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, MMMM d, yyyy').format(
      DateTime.tryParse(session.createdAt) ?? DateTime.now(),
    );
    final exercises = session.exerciseSets
        .map((e) => getExerciseLabel(e.exerciseType))
        .toSet()
        .join(' · ');

    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // slate-900
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fitness_center, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'PHVA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Score
          Row(
            children: [
              Text(
                '${session.avgFormScore.round()}%',
                style: const TextStyle(
                  color: AppColors.health,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Form Score',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${session.totalReps} reps',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Divider
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 16),

          // Exercise list
          if (exercises.isNotEmpty) ...[
            Text(exercises,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
          ],

          // Per-exercise stats
          for (final s in session.exerciseSets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      getExerciseLabel(s.exerciseType),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  Text(
                    '${s.repCount} reps',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _scoreColor(s.formScore).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${s.formScore.round()}%',
                      style: TextStyle(
                        color: _scoreColor(s.formScore),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 12),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const Text('Personal Health Video Analyzer',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  static Color _scoreColor(double score) {
    if (score >= 80) return AppColors.health;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }
}
