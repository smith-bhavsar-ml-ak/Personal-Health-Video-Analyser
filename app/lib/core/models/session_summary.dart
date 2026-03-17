class SessionSummary {
  final String id;
  final String createdAt;
  final int? durationS;
  final String status; // processing | completed | failed
  final int totalReps;
  final double avgFormScore;
  final List<String> exerciseTypes;

  const SessionSummary({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.totalReps,
    required this.avgFormScore,
    required this.exerciseTypes,
    this.durationS,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        id:            json['id']              as String,
        createdAt:     json['created_at']      as String,
        durationS:     json['duration_s']      as int?,
        status:        json['status']          as String,
        totalReps:     (json['total_reps']     as int?   ) ?? 0,
        avgFormScore:  ((json['avg_form_score'] as num?)   )?.toDouble() ?? 0.0,
        exerciseTypes: (json['exercise_types'] as List<dynamic>?)
                ?.map((e) => e as String).toList() ??
            [],
      );

  bool get isProcessing => status == 'processing';
  bool get isCompleted  => status == 'completed';
  bool get isFailed     => status == 'failed';
}
