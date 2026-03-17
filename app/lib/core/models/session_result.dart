import 'exercise_set.dart';
import 'ai_feedback.dart';
import 'voice_query.dart';

class SessionResult {
  final String id;
  final String createdAt;
  final int? durationS;
  final String status; // processing | completed | failed
  final List<ExerciseSet> exerciseSets;
  final AIFeedback? aiFeedback;
  final List<VoiceQuery> voiceQueries;

  const SessionResult({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.exerciseSets,
    required this.voiceQueries,
    this.durationS,
    this.aiFeedback,
  });

  factory SessionResult.fromJson(Map<String, dynamic> json) => SessionResult(
        id:           json['id']         as String,
        createdAt:    json['created_at'] as String,
        durationS:    json['duration_s'] as int?,
        status:       json['status']     as String,
        exerciseSets: (json['exercise_sets'] as List<dynamic>)
            .map((e) => ExerciseSet.fromJson(e as Map<String, dynamic>))
            .toList(),
        aiFeedback: json['ai_feedback'] == null
            ? null
            : AIFeedback.fromJson(json['ai_feedback'] as Map<String, dynamic>),
        voiceQueries: (json['voice_queries'] as List<dynamic>)
            .map((e) => VoiceQuery.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isProcessing => status == 'processing';
  bool get isCompleted  => status == 'completed';
  bool get isFailed     => status == 'failed';

  int get totalReps =>
      exerciseSets.fold(0, (sum, s) => sum + s.repCount);

  double get avgFormScore {
    if (exerciseSets.isEmpty) return 0.0;
    return exerciseSets.fold(0.0, (sum, s) => sum + s.formScore) /
        exerciseSets.length;
  }
}
