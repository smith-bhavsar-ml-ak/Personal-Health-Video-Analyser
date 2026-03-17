import 'package:flutter/material.dart';
import '../core/theme/exercise_helpers.dart';

/// Colored chip showing an exercise type label.
class ExerciseBadge extends StatelessWidget {
  final String type;
  const ExerciseBadge(this.type, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = getExerciseColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        getExerciseLabel(type),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
