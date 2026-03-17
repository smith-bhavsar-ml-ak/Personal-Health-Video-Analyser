class PlanExercise {
  final String id;
  final int dayOfWeek;
  final String dayName;
  final String exerciseType;
  final int setsTarget;
  final int repsTarget;
  final int? durationTargetS;
  final String? notes;
  final DateTime? completedAt;

  const PlanExercise({
    required this.id,
    required this.dayOfWeek,
    required this.dayName,
    required this.exerciseType,
    required this.setsTarget,
    required this.repsTarget,
    this.durationTargetS,
    this.notes,
    this.completedAt,
  });

  bool get isCompleted => completedAt != null;

  factory PlanExercise.fromJson(Map<String, dynamic> j) => PlanExercise(
        id: j['id'] as String,
        dayOfWeek: j['day_of_week'] as int,
        dayName: j['day_name'] as String,
        exerciseType: j['exercise_type'] as String,
        setsTarget: j['sets_target'] as int,
        repsTarget: j['reps_target'] as int,
        durationTargetS: j['duration_target_s'] as int?,
        notes: j['notes'] as String?,
        completedAt: j['completed_at'] != null
            ? DateTime.parse(j['completed_at'] as String)
            : null,
      );

  PlanExercise copyWith({DateTime? completedAt, bool clearCompleted = false}) =>
      PlanExercise(
        id: id,
        dayOfWeek: dayOfWeek,
        dayName: dayName,
        exerciseType: exerciseType,
        setsTarget: setsTarget,
        repsTarget: repsTarget,
        durationTargetS: durationTargetS,
        notes: notes,
        completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
      );
}

class WorkoutPlan {
  final String id;
  final String title;
  final String? description;
  final int durationWeeks;
  final DateTime createdAt;
  final List<PlanExercise> exercises;

  const WorkoutPlan({
    required this.id,
    required this.title,
    this.description,
    required this.durationWeeks,
    required this.createdAt,
    required this.exercises,
  });

  int get totalExercises => exercises.length;
  int get completedExercises => exercises.where((e) => e.isCompleted).length;
  double get weekProgress =>
      totalExercises > 0 ? completedExercises / totalExercises : 0;

  /// Exercises grouped by day of week.
  Map<int, List<PlanExercise>> get byDay {
    final map = <int, List<PlanExercise>>{};
    for (final ex in exercises) {
      map.putIfAbsent(ex.dayOfWeek, () => []).add(ex);
    }
    return map;
  }

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) => WorkoutPlan(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        durationWeeks: j['duration_weeks'] as int,
        createdAt: DateTime.parse(j['created_at'] as String),
        exercises: (j['exercises'] as List)
            .map((e) => PlanExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
