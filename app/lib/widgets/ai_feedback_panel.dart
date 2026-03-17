import 'package:flutter/material.dart';
import '../core/models/ai_feedback.dart';
import '../core/theme/app_theme.dart';

class AIFeedbackPanel extends StatelessWidget {
  final AIFeedback feedback;
  const AIFeedbackPanel({required this.feedback, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI Coaching Feedback',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(feedback.feedbackText,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
