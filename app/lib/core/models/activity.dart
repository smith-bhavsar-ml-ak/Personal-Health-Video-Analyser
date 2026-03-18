class DailySteps {
  final int steps;
  final int goal;
  final double caloriesBurned;
  final int activeMinutes;
  final int currentStreak;
  final int longestStreak;

  const DailySteps({
    required this.steps,
    required this.goal,
    required this.caloriesBurned,
    required this.activeMinutes,
    required this.currentStreak,
    required this.longestStreak,
  });

  double get progress => goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;
  bool get goalReached => steps >= goal;

  factory DailySteps.fromJson(Map<String, dynamic> json) => DailySteps(
        steps: json['steps'] as int? ?? 0,
        goal: json['goal'] as int? ?? 8000,
        caloriesBurned: (json['calories_burned'] as num?)?.toDouble() ?? 0.0,
        activeMinutes: json['active_minutes'] as int? ?? 0,
        currentStreak: json['current_streak'] as int? ?? 0,
        longestStreak: json['longest_streak'] as int? ?? 0,
      );
}

class StepHistoryPoint {
  final DateTime date;
  final int steps;
  final int goal;
  final double caloriesBurned;

  const StepHistoryPoint({
    required this.date,
    required this.steps,
    required this.goal,
    required this.caloriesBurned,
  });

  factory StepHistoryPoint.fromJson(Map<String, dynamic> json) => StepHistoryPoint(
        date: DateTime.parse(json['date'] as String),
        steps: json['steps'] as int? ?? 0,
        goal: json['goal'] as int? ?? 8000,
        caloriesBurned: (json['calories_burned'] as num?)?.toDouble() ?? 0.0,
      );
}

class ActivitySessionSummary {
  final String id;
  final String activityType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationS;
  final int steps;
  final double distanceM;
  final double caloriesBurned;
  final double? avgPaceSPerKm;

  const ActivitySessionSummary({
    required this.id,
    required this.activityType,
    required this.startedAt,
    this.endedAt,
    this.durationS,
    required this.steps,
    required this.distanceM,
    required this.caloriesBurned,
    this.avgPaceSPerKm,
  });

  String get distanceLabel {
    if (distanceM >= 1000) return '${(distanceM / 1000).toStringAsFixed(2)} km';
    return '${distanceM.round()} m';
  }

  String get paceLabel {
    if (avgPaceSPerKm == null) return '—';
    final m = (avgPaceSPerKm! ~/ 60);
    final s = (avgPaceSPerKm! % 60).round();
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }

  factory ActivitySessionSummary.fromJson(Map<String, dynamic> json) =>
      ActivitySessionSummary(
        id: json['id'] as String,
        activityType: json['activity_type'] as String? ?? 'walk',
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] != null
            ? DateTime.tryParse(json['ended_at'] as String)
            : null,
        durationS: json['duration_s'] as int?,
        steps: json['steps'] as int? ?? 0,
        distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0.0,
        caloriesBurned: (json['calories_burned'] as num?)?.toDouble() ?? 0.0,
        avgPaceSPerKm: (json['avg_pace_s_per_km'] as num?)?.toDouble(),
      );
}
