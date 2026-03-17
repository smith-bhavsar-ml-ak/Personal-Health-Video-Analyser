import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Known labels for the original 5 exercises.
/// New exercises discovered from BiLSTM weights get auto-generated labels.
const _knownLabels = <String, String>{
  'squat':        'Squat',
  'jumping_jack': 'Jumping Jack',
  'bicep_curl':   'Bicep Curl',
  'lunge':        'Lunge',
  'plank':        'Plank',
};

const _knownColors = <String, Color>{
  'squat':        AppColors.chart1,
  'jumping_jack': AppColors.chart2,
  'bicep_curl':   AppColors.chart3,
  'lunge':        AppColors.chart4,
  'plank':        AppColors.chart5,
};

/// Human-readable label for any exercise type, including dynamic classes.
String getExerciseLabel(String type) {
  return _knownLabels[type] ??
      type
          .split('_')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
}

/// Chart / badge color for any exercise type. Unknown classes get textSecondary.
Color getExerciseColor(String type) {
  return _knownColors[type] ?? AppColors.textSecondary;
}
