class AIFeedback {
  final String feedbackText;
  final String generatedAt;

  const AIFeedback({required this.feedbackText, required this.generatedAt});

  factory AIFeedback.fromJson(Map<String, dynamic> json) => AIFeedback(
        feedbackText: json['feedback_text'] as String,
        generatedAt:  json['generated_at']  as String,
      );
}
