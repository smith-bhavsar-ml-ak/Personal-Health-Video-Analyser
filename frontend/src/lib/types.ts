export type ExerciseType = "squat" | "jumping_jack" | "bicep_curl" | "lunge" | "plank";

export interface PostureError {
  id: string;
  error_type: string;
  occurrences: number;
  severity: "low" | "medium" | "high";
}

export interface ExerciseSet {
  id: string;
  exercise_type: ExerciseType;
  rep_count: number;
  correct_reps: number;
  duration_s: number;
  form_score: number;
  posture_errors: PostureError[];
}

export interface AIFeedback {
  feedback_text: string;
  generated_at: string;
}

export interface VoiceQuery {
  id: string;
  query_text: string;
  response_text: string;
  created_at: string;
}

export interface SessionSummary {
  id: string;
  created_at: string;
  duration_s: number | null;
  status: "processing" | "completed" | "failed";
  total_reps: number;
  avg_form_score: number;
  exercise_types: ExerciseType[];
}

export interface SessionResult {
  id: string;
  created_at: string;
  duration_s: number | null;
  status: "processing" | "completed" | "failed";
  exercise_sets: ExerciseSet[];
  ai_feedback: AIFeedback | null;
  voice_queries: VoiceQuery[];
}

export interface VoiceQueryRequest {
  query_text?: string;
  audio_b64?: string;
}

export interface VoiceQueryResponse {
  query_text: string;
  response_text: string;
  audio_b64: string | null;
}

export const EXERCISE_LABELS: Record<ExerciseType, string> = {
  squat: "Squat",
  jumping_jack: "Jumping Jack",
  bicep_curl: "Bicep Curl",
  lunge: "Lunge",
  plank: "Plank",
};

export const EXERCISE_COLORS: Record<ExerciseType, string> = {
  squat:        "#6366F1",
  jumping_jack: "#10B981",
  bicep_curl:   "#38BDF8",
  lunge:        "#F59E0B",
  plank:        "#EC4899",
};
