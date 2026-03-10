from app.analysis.base import ExerciseAnalyser, ExerciseResult, PostureError
from app.cv.pose_detector import PoseFrame, calculate_angle, get_landmark


class SquatAnalyser(ExerciseAnalyser):
    # Rep state thresholds (knee angle degrees)
    DOWN_THRESHOLD = 110   # entering down position
    UP_THRESHOLD = 160     # returning to standing

    # Posture thresholds
    KNEE_FORWARD_RATIO = 0.05   # knee x > foot x + ratio → knee over toes
    BACK_LEAN_ANGLE = 45        # torso angle from vertical

    def analyse(self, pose_frames: list[PoseFrame], fps: float) -> ExerciseResult:
        detected = [f for f in pose_frames if f.detected]
        if not detected:
            return ExerciseResult("squat", 0, 0, 0, 0.0, [])

        state = "up"
        rep_count = 0
        rep_scores: list[float] = []
        current_rep_errors: list[str] = []
        error_counts: dict[str, int] = {}

        for frame in detected:
            try:
                l_hip = get_landmark(frame, "left_hip")
                l_knee = get_landmark(frame, "left_knee")
                l_ankle = get_landmark(frame, "left_ankle")
                r_hip = get_landmark(frame, "right_hip")
                r_knee = get_landmark(frame, "right_knee")
                r_ankle = get_landmark(frame, "right_ankle")
                l_shoulder = get_landmark(frame, "left_shoulder")
            except Exception:
                continue

            # Average left/right knee angle
            left_angle = calculate_angle(l_hip, l_knee, l_ankle)
            right_angle = calculate_angle(r_hip, r_knee, r_ankle)
            knee_angle = (left_angle + right_angle) / 2

            # Rep state machine
            if state == "up" and knee_angle < self.DOWN_THRESHOLD:
                state = "down"
                current_rep_errors = []

            elif state == "down" and knee_angle > self.UP_THRESHOLD:
                state = "up"
                rep_count += 1
                # Score this rep (deduct 15 per error)
                score = max(0.0, 100.0 - len(set(current_rep_errors)) * 15)
                rep_scores.append(score)

            # Posture checks (during down phase)
            if state == "down":
                # Knee over toes: knee x should not exceed foot x significantly
                if l_knee[0] > l_ankle[0] + self.KNEE_FORWARD_RATIO:
                    current_rep_errors.append("knees_forward")
                    error_counts["knees_forward"] = error_counts.get("knees_forward", 0) + 1

                # Back lean: shoulder should be roughly above hip
                torso_angle = abs(l_shoulder[0] - l_hip[0]) / (abs(l_shoulder[1] - l_hip[1]) + 1e-6) * 90
                if torso_angle > self.BACK_LEAN_ANGLE:
                    current_rep_errors.append("back_lean")
                    error_counts["back_lean"] = error_counts.get("back_lean", 0) + 1

        form_score = float(sum(rep_scores) / len(rep_scores)) if rep_scores else 0.0
        correct_reps = sum(1 for s in rep_scores if s >= 80)
        duration_s = int(len(detected) / fps) if fps > 0 else 0

        posture_errors = [
            PostureError(
                error_type=k,
                occurrences=v,
                severity="high" if v > 10 else "medium" if v > 4 else "low",
            )
            for k, v in error_counts.items()
        ]

        return ExerciseResult(
            exercise_type="squat",
            rep_count=rep_count,
            correct_reps=correct_reps,
            duration_s=duration_s,
            form_score=round(form_score, 1),
            rep_scores=rep_scores,
            posture_errors=posture_errors,
            start_frame=detected[0].frame_idx,
            end_frame=detected[-1].frame_idx,
        )
