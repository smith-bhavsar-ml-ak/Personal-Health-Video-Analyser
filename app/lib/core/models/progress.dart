class ProgressSummary {
  final int totalSessions;
  final int totalReps;
  final double avgFormScore;

  const ProgressSummary({
    required this.totalSessions,
    required this.totalReps,
    required this.avgFormScore,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> j) => ProgressSummary(
        totalSessions: j['total_sessions'] as int,
        totalReps: j['total_reps'] as int,
        avgFormScore: (j['avg_form_score'] as num).toDouble(),
      );
}

class FormScorePoint {
  final DateTime date;
  final double avgFormScore;

  const FormScorePoint({required this.date, required this.avgFormScore});

  factory FormScorePoint.fromJson(Map<String, dynamic> j) => FormScorePoint(
        date: DateTime.parse(j['date'] as String),
        avgFormScore: (j['avg_form_score'] as num).toDouble(),
      );
}

class WeightPoint {
  final String id;
  final DateTime date;
  final double weightKg;

  const WeightPoint({required this.id, required this.date, required this.weightKg});

  factory WeightPoint.fromJson(Map<String, dynamic> j) => WeightPoint(
        id: j['id'] as String,
        date: DateTime.parse(j['logged_at'] as String),
        weightKg: (j['weight_kg'] as num).toDouble(),
      );
}

class ExerciseStat {
  final String exerciseType;
  final int totalReps;
  final int correctReps;
  final double avgFormScore;
  final int setCount;

  const ExerciseStat({
    required this.exerciseType,
    required this.totalReps,
    required this.correctReps,
    required this.avgFormScore,
    required this.setCount,
  });

  factory ExerciseStat.fromJson(Map<String, dynamic> j) => ExerciseStat(
        exerciseType: j['exercise_type'] as String,
        totalReps: j['total_reps'] as int,
        correctReps: j['correct_reps'] as int,
        avgFormScore: (j['avg_form_score'] as num).toDouble(),
        setCount: j['set_count'] as int,
      );

  double get accuracy => totalReps > 0 ? correctReps / totalReps : 0;
}
