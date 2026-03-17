class PostureError {
  final String id;
  final String errorType;
  final int occurrences;
  final String severity; // low | medium | high

  const PostureError({
    required this.id,
    required this.errorType,
    required this.occurrences,
    required this.severity,
  });

  factory PostureError.fromJson(Map<String, dynamic> json) => PostureError(
        id:          json['id']          as String,
        errorType:   json['error_type']  as String,
        occurrences: json['occurrences'] as int,
        severity:    json['severity']    as String,
      );
}

class ExerciseSet {
  final String id;
  final String exerciseType;
  final int repCount;
  final int correctReps;
  final int durationS;
  final double formScore;
  final List<PostureError> postureErrors;

  const ExerciseSet({
    required this.id,
    required this.exerciseType,
    required this.repCount,
    required this.correctReps,
    required this.durationS,
    required this.formScore,
    required this.postureErrors,
  });

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
        id:           json['id']            as String,
        exerciseType: json['exercise_type'] as String,
        repCount:     json['rep_count']     as int,
        correctReps:  json['correct_reps']  as int,
        durationS:    json['duration_s']    as int,
        formScore:    (json['form_score']   as num).toDouble(),
        postureErrors: (json['posture_errors'] as List<dynamic>)
            .map((e) => PostureError.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
