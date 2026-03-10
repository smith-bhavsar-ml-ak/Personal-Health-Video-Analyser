from app.analysis.base import ExerciseAnalyser, ExerciseResult, PostureError
from app.cv.pose_detector import PoseFrame, calculate_angle, get_landmark


class JumpingJackAnalyser(ExerciseAnalyser):
    ARM_OPEN_THRESHOLD = 130   # arms open (degrees at shoulder)
    ARM_CLOSE_THRESHOLD = 40   # arms closed

    def analyse(self, pose_frames: list[PoseFrame], fps: float) -> ExerciseResult:
        detected = [f for f in pose_frames if f.detected]
        if not detected:
            return ExerciseResult("jumping_jack", 0, 0, 0, 0.0, [])

        state = "closed"
        rep_count = 0
        rep_scores: list[float] = []
        error_counts: dict[str, int] = {}

        for frame in detected:
            try:
                l_shoulder = get_landmark(frame, "left_shoulder")
                r_shoulder = get_landmark(frame, "right_shoulder")
                l_elbow = get_landmark(frame, "left_elbow")
                r_elbow = get_landmark(frame, "right_elbow")
                l_hip = get_landmark(frame, "left_hip")
                r_hip = get_landmark(frame, "right_hip")
            except Exception:
                continue

            # Arm spread: angle at shoulder between elbow and hip
            left_arm_angle = calculate_angle(l_elbow, l_shoulder, l_hip)
            right_arm_angle = calculate_angle(r_elbow, r_shoulder, r_hip)
            arm_angle = (left_arm_angle + right_arm_angle) / 2

            if state == "closed" and arm_angle > self.ARM_OPEN_THRESHOLD:
                state = "open"
            elif state == "open" and arm_angle < self.ARM_CLOSE_THRESHOLD:
                state = "closed"
                rep_count += 1

                # Check symmetry
                asymmetry = abs(left_arm_angle - right_arm_angle)
                errors_this_rep = []
                if asymmetry > 25:
                    errors_this_rep.append("arm_asymmetry")
                    error_counts["arm_asymmetry"] = error_counts.get("arm_asymmetry", 0) + 1

                score = max(0.0, 100.0 - len(set(errors_this_rep)) * 15)
                rep_scores.append(score)

        form_score = float(sum(rep_scores) / len(rep_scores)) if rep_scores else 0.0
        correct_reps = sum(1 for s in rep_scores if s >= 80)
        duration_s = int(len(detected) / fps) if fps > 0 else 0

        posture_errors = [
            PostureError(error_type=k, occurrences=v, severity="medium" if v > 3 else "low")
            for k, v in error_counts.items()
        ]

        return ExerciseResult(
            exercise_type="jumping_jack",
            rep_count=rep_count,
            correct_reps=correct_reps,
            duration_s=duration_s,
            form_score=round(form_score, 1),
            rep_scores=rep_scores,
            posture_errors=posture_errors,
            start_frame=detected[0].frame_idx,
            end_frame=detected[-1].frame_idx,
        )
