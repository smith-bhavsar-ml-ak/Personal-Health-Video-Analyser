from app.analysis.base import ExerciseResult


def aggregate_results(exercise_results: list[ExerciseResult]) -> dict:
    """
    Convert a list of ExerciseResult into the structured dict
    expected by the DB crud layer.
    """
    sets = []
    for result in exercise_results:
        sets.append({
            "exercise_type": result.exercise_type,
            "rep_count": result.rep_count,
            "correct_reps": result.correct_reps,
            "duration_s": result.duration_s,
            "form_score": result.form_score,
            "start_frame": result.start_frame,
            "end_frame": result.end_frame,
            "rep_scores": [round(s, 1) for s in result.rep_scores] if result.rep_scores else [],
            "posture_errors": [
                {
                    "error_type": e.error_type,
                    "occurrences": e.occurrences,
                    "severity": e.severity,
                }
                for e in result.posture_errors
            ],
        })
    return {"exercise_sets": sets}


def build_feedback_context(exercise_results: list[ExerciseResult]) -> str:
    """
    Build a structured text summary of workout results to send to the LLM.
    """
    lines = ["Workout Analysis Results:"]
    for r in exercise_results:
        lines.append(f"\nExercise: {r.exercise_type.replace('_', ' ').title()}")
        lines.append(f"  Reps: {r.rep_count} total, {r.correct_reps} correct form")
        lines.append(f"  Duration: {r.duration_s}s")
        lines.append(f"  Form Score: {r.form_score:.0f}/100")
        if r.posture_errors:
            lines.append("  Issues detected:")
            for err in r.posture_errors:
                lines.append(f"    - {err.error_type.replace('_', ' ')}: {err.occurrences} times ({err.severity} severity)")
    return "\n".join(lines)
