import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Horizontal form score bar used in history list items.
class ScoreBar extends StatelessWidget {
  final double score; // 0–100
  const ScoreBar(this.score, {super.key});

  Color _color() {
    if (score >= 80) return AppColors.health;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(_color()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${score.round()}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _color(),
          ),
        ),
      ],
    );
  }
}
