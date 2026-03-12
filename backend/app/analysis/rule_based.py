import logging
import numpy as np
from app.cv.pose_detector import PoseFrame, calculate_angle, get_landmark, LANDMARK
from app.analysis.base import ExerciseResult

logger = logging.getLogger(__name__)
from app.analysis.exercises.squat import SquatAnalyser
from app.analysis.exercises.jumping_jack import JumpingJackAnalyser
from app.analysis.exercises.bicep_curl import BicepCurlAnalyser
from app.analysis.exercises.lunge import LungeAnalyser
from app.analysis.exercises.plank import PlankAnalyser

ANALYSERS = {
    "squat": SquatAnalyser(),
    "jumping_jack": JumpingJackAnalyser(),
    "bicep_curl": BicepCurlAnalyser(),
    "lunge": LungeAnalyser(),
    "plank": PlankAnalyser(),
}


def detect_exercise_type(pose_frames: list[PoseFrame]) -> str:
    """
    Rule-based exercise classification using pose heuristics.
    Analyses the dominant motion pattern across all frames.
    """
    detected = [f for f in pose_frames if f.detected]
    if not detected:
        return "squat"  # fallback

    # Collect per-frame feature vectors
    knee_angles, elbow_angles, arm_spreads, hip_heights = [], [], [], []

    for frame in detected:
        try:
            l_hip = get_landmark(frame, "left_hip")
            l_knee = get_landmark(frame, "left_knee")
            l_ankle = get_landmark(frame, "left_ankle")
            l_shoulder = get_landmark(frame, "left_shoulder")
            l_elbow = get_landmark(frame, "left_elbow")
            l_wrist = get_landmark(frame, "left_wrist")
            r_shoulder = get_landmark(frame, "right_shoulder")
            r_elbow = get_landmark(frame, "right_elbow")

            knee_angles.append(calculate_angle(l_hip, l_knee, l_ankle))
            elbow_angles.append(calculate_angle(l_shoulder, l_elbow, l_wrist))
            arm_spreads.append(abs(l_shoulder[0] - r_shoulder[0]))
            hip_heights.append(l_hip[1])
        except Exception:
            continue

    if not knee_angles:
        logger.warning("No valid knee angles computed, falling back to squat")
        return "squat"

    knee_range = max(knee_angles) - min(knee_angles)
    elbow_range = max(elbow_angles) - min(elbow_angles)
    arm_spread_range = max(arm_spreads) - min(arm_spreads)
    hip_range = max(hip_heights) - min(hip_heights)
    mean_knee = np.mean(knee_angles)
    mean_elbow = np.mean(elbow_angles)

    logger.info(
        "Classification features | knee_range=%.1f elbow_range=%.1f arm_spread_range=%.3f "
        "hip_range=%.3f mean_knee=%.1f mean_elbow=%.1f",
        knee_range, elbow_range, arm_spread_range, hip_range, mean_knee, mean_elbow,
    )

    # Plank: minimal movement, body near horizontal
    if knee_range < 20 and hip_range < 0.05 and mean_knee > 150:
        logger.info("Classified as: plank")
        return "plank"

    # Jumping jack: arms swing wide AND legs stay mostly straight (mean_knee high, knee_range moderate)
    # Squats also have high arm_spread (arms raised for balance) but have deep knee bend:
    #   knee_range > 100 and mean_knee < 155 — both conditions reject squats
    if arm_spread_range > 0.15 and knee_range < 100 and mean_knee > 155:
        logger.info("Classified as: jumping_jack")
        return "jumping_jack"

    # Bicep curl: large elbow range, minimal knee/hip movement
    if elbow_range > 60 and knee_range < 30 and hip_range < 0.08:
        logger.info("Classified as: bicep_curl")
        return "bicep_curl"

    # Lunge: asymmetric leg loading, moderate knee range
    if 40 < knee_range < 90:
        logger.info("Classified as: lunge")
        return "lunge"

    # Default: squat (large knee range, hip drops significantly)
    logger.info("Classified as: squat (default)")
    return "squat"


def run_analysis(pose_frames: list[PoseFrame], fps: float) -> list[ExerciseResult]:
    """
    Detect exercise type and run the appropriate analyser.
    Returns a list of ExerciseResult (one per detected exercise set).
    """
    logger.info("Detecting exercise type from %d pose frames...", len(pose_frames))
    exercise_type = detect_exercise_type(pose_frames)
    logger.info("Running analyser for: %s", exercise_type)
    analyser = ANALYSERS[exercise_type]
    result = analyser.analyse(pose_frames, fps)
    logger.info(
        "Analyser result | reps=%d correct=%d form_score=%.1f duration=%.1fs errors=%s",
        result.rep_count, result.correct_reps, result.form_score, result.duration_s,
        [e.error_type for e in result.posture_errors],
    )
    return [result]
