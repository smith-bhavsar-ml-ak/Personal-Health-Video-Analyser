import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Circular form score indicator.
class ScoreRing extends StatelessWidget {
  final double score; // 0–100
  final double size;
  final double strokeWidth;

  const ScoreRing({
    required this.score,
    this.size = 64,
    this.strokeWidth = 5,
    super.key,
  });

  Color _color() {
    if (score >= 80) return AppColors.health;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: strokeWidth,
            backgroundColor: AppColors.surfaceElevated,
            valueColor: AlwaysStoppedAnimation(_color()),
          ),
          Text(
            '${score.round()}',
            style: TextStyle(
              fontSize: size * 0.24,
              fontWeight: FontWeight.w700,
              color: _color(),
            ),
          ),
        ],
      ),
    );
  }
}
