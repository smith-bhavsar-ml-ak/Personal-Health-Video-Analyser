from app.analysis.base import ExerciseAnalyser, ExerciseResult, PostureError
from app.cv.pose_detector import PoseFrame, calculate_angle, get_landmark


class BicepCurlAnalyser(ExerciseAnalyser):
    CURL_UP_THRESHOLD = 60     # elbow angle when curled
    CURL_DOWN_THRESHOLD = 150  # elbow angle when extended

    def analyse(self, pose_frames: list[PoseFrame], fps: float) -> ExerciseResult:
        detected = [f for f in pose_frames if f.detected]
        if not detected:
            return ExerciseResult("bicep_curl", 0, 0, 0, 0.0, [])

        state = "down"
        rep_count = 0
        rep_scores: list[float] = []
        error_counts: dict[str, int] = {}
        current_rep_errors: list[str] = []

        for frame in detected:
            try:
                l_shoulder = get_landmark(frame, "left_shoulder")
                l_elbow = get_landmark(frame, "left_elbow")
                l_wrist = get_landmark(frame, "left_wrist")
                r_shoulder = get_landmark(frame, "right_shoulder")
                r_elbow = get_landmark(frame, "right_elbow")
                r_wrist = get_landmark(frame, "right_wrist")
            except Exception:
                continue

            left_angle = calculate_angle(l_shoulder, l_elbow, l_wrist)
            right_angle = calculate_angle(r_shoulder, r_elbow, r_wrist)
            avg_angle = (left_angle + right_angle) / 2

            if state == "down" and avg_angle < self.CURL_UP_THRESHOLD:
                state = "up"
                current_rep_errors = []

            elif state == "up" and avg_angle > self.CURL_DOWN_THRESHOLD:
                state = "down"
                rep_count += 1
                score = max(0.0, 100.0 - len(set(current_rep_errors)) * 15)
                rep_scores.append(score)

            # Elbow drift: elbow should not move forward significantly
            if state == "up":
                elbow_drift = abs(l_elbow[0] - l_shoulder[0])
                if elbow_drift > 0.08:
                    current_rep_errors.append("elbow_drift")
                    error_counts["elbow_drift"] = error_counts.get("elbow_drift", 0) + 1

        form_score = float(sum(rep_scores) / len(rep_scores)) if rep_scores else 0.0
        correct_reps = sum(1 for s in rep_scores if s >= 80)
        duration_s = int(len(detected) / fps) if fps > 0 else 0

        posture_errors = [
            PostureError(error_type=k, occurrences=v, severity="medium" if v > 3 else "low")
            for k, v in error_counts.items()
        ]

        return ExerciseResult(
            exercise_type="bicep_curl",
            rep_count=rep_count,
            correct_reps=correct_reps,
            duration_s=duration_s,
            form_score=round(form_score, 1),
            rep_scores=rep_scores,
            posture_errors=posture_errors,
            start_frame=detected[0].frame_idx,
            end_frame=detected[-1].frame_idx,
        )
