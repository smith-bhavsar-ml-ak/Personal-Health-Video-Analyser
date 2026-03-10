from app.analysis.base import ExerciseAnalyser, ExerciseResult, PostureError
from app.cv.pose_detector import PoseFrame, calculate_angle, get_landmark


class LungeAnalyser(ExerciseAnalyser):
    DOWN_THRESHOLD = 100   # front knee angle (lunge down)
    UP_THRESHOLD = 160     # standing

    def analyse(self, pose_frames: list[PoseFrame], fps: float) -> ExerciseResult:
        detected = [f for f in pose_frames if f.detected]
        if not detected:
            return ExerciseResult("lunge", 0, 0, 0, 0.0, [])

        state = "up"
        rep_count = 0
        rep_scores: list[float] = []
        error_counts: dict[str, int] = {}
        current_rep_errors: list[str] = []

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

            # Use front leg (smaller knee angle = more bent = front leg)
            left_angle = calculate_angle(l_hip, l_knee, l_ankle)
            right_angle = calculate_angle(r_hip, r_knee, r_ankle)
            front_knee_angle = min(left_angle, right_angle)

            if state == "up" and front_knee_angle < self.DOWN_THRESHOLD:
                state = "down"
                current_rep_errors = []

            elif state == "down" and front_knee_angle > self.UP_THRESHOLD:
                state = "up"
                rep_count += 1
                score = max(0.0, 100.0 - len(set(current_rep_errors)) * 15)
                rep_scores.append(score)

            if state == "down":
                # Knee caving inward: knee x should track over ankle x
                if abs(l_knee[0] - l_ankle[0]) > 0.07:
                    current_rep_errors.append("knee_cave")
                    error_counts["knee_cave"] = error_counts.get("knee_cave", 0) + 1

                # Torso upright
                torso_lean = abs(l_shoulder[0] - l_hip[0]) / (abs(l_shoulder[1] - l_hip[1]) + 1e-6) * 90
                if torso_lean > 40:
                    current_rep_errors.append("torso_lean")
                    error_counts["torso_lean"] = error_counts.get("torso_lean", 0) + 1

        form_score = float(sum(rep_scores) / len(rep_scores)) if rep_scores else 0.0
        correct_reps = sum(1 for s in rep_scores if s >= 80)
        duration_s = int(len(detected) / fps) if fps > 0 else 0

        posture_errors = [
            PostureError(error_type=k, occurrences=v, severity="high" if v > 8 else "medium" if v > 3 else "low")
            for k, v in error_counts.items()
        ]

        return ExerciseResult(
            exercise_type="lunge",
            rep_count=rep_count,
            correct_reps=correct_reps,
            duration_s=duration_s,
            form_score=round(form_score, 1),
            rep_scores=rep_scores,
            posture_errors=posture_errors,
            start_frame=detected[0].frame_idx,
            end_frame=detected[-1].frame_idx,
        )
