import numpy as np
from app.analysis.base import ExerciseAnalyser, ExerciseResult, PostureError
from app.cv.pose_detector import PoseFrame, get_landmark


class PlankAnalyser(ExerciseAnalyser):
    """
    Plank is duration-based (no reps).
    Checks body linearity: shoulder, hip, and ankle should be collinear.
    """
    LINEARITY_THRESHOLD = 0.06   # max deviation from straight line (normalised coords)
    MIN_FRAMES_HELD = 10         # minimum frames to count as holding plank

    def analyse(self, pose_frames: list[PoseFrame], fps: float) -> ExerciseResult:
        detected = [f for f in pose_frames if f.detected]
        if not detected:
            return ExerciseResult("plank", 0, 0, 0, 0.0, [])

        error_counts: dict[str, int] = {}
        good_frames = 0

        for frame in detected:
            try:
                l_shoulder = get_landmark(frame, "left_shoulder")
                l_hip = get_landmark(frame, "left_hip")
                l_ankle = get_landmark(frame, "left_ankle")
            except Exception:
                continue

            # Body linearity: hip y should be between shoulder y and ankle y
            # and close to the line connecting shoulder and ankle
            shoulder_pt = l_shoulder[:2]
            ankle_pt = l_ankle[:2]
            hip_pt = l_hip[:2]

            # Distance from hip to line shoulder-ankle
            line_vec = ankle_pt - shoulder_pt
            line_len = np.linalg.norm(line_vec) + 1e-8
            hip_offset = abs(np.cross(line_vec, shoulder_pt - hip_pt)) / line_len

            if hip_offset > self.LINEARITY_THRESHOLD:
                if hip_pt[1] < (shoulder_pt[1] + ankle_pt[1]) / 2:
                    error_counts["hips_too_high"] = error_counts.get("hips_too_high", 0) + 1
                else:
                    error_counts["hips_too_low"] = error_counts.get("hips_too_low", 0) + 1
            else:
                good_frames += 1

        duration_s = int(len(detected) / fps) if fps > 0 else 0
        form_score = (good_frames / len(detected) * 100) if detected else 0.0

        posture_errors = [
            PostureError(error_type=k, occurrences=v, severity="high" if v > len(detected) * 0.4 else "medium" if v > len(detected) * 0.2 else "low")
            for k, v in error_counts.items()
        ]

        # For plank: rep_count = 1 if held for minimum duration, else 0
        rep_count = 1 if len(detected) >= self.MIN_FRAMES_HELD else 0
        correct_reps = 1 if form_score >= 80 else 0

        return ExerciseResult(
            exercise_type="plank",
            rep_count=rep_count,
            correct_reps=correct_reps,
            duration_s=duration_s,
            form_score=round(form_score, 1),
            rep_scores=[form_score],
            posture_errors=posture_errors,
            start_frame=detected[0].frame_idx,
            end_frame=detected[-1].frame_idx,
        )
