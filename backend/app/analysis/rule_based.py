import numpy as np
from app.cv.pose_detector import PoseFrame, calculate_angle, get_landmark, LANDMARK
from app.analysis.base import ExerciseResult
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
        return "squat"

    knee_range = max(knee_angles) - min(knee_angles)
    elbow_range = max(elbow_angles) - min(elbow_angles)
    arm_spread_range = max(arm_spreads) - min(arm_spreads)
    hip_range = max(hip_heights) - min(hip_heights)
    mean_knee = np.mean(knee_angles)
    mean_elbow = np.mean(elbow_angles)

    # Plank: minimal movement, body near horizontal
    if knee_range < 20 and hip_range < 0.05 and mean_knee > 150:
        return "plank"

    # Jumping jack: large arm spread variation with minimal knee change
    if arm_spread_range > 0.15 and knee_range < 40:
        return "jumping_jack"

    # Bicep curl: large elbow range, minimal knee/hip movement
    if elbow_range > 60 and knee_range < 30 and hip_range < 0.08:
        return "bicep_curl"

    # Lunge: asymmetric leg loading, moderate knee range
    if 40 < knee_range < 90:
        return "lunge"

    # Default: squat (large knee range, hip drops significantly)
    return "squat"


def run_analysis(pose_frames: list[PoseFrame], fps: float) -> list[ExerciseResult]:
    """
    Detect exercise type and run the appropriate analyser.
    Returns a list of ExerciseResult (one per detected exercise set).
    """
    exercise_type = detect_exercise_type(pose_frames)
    analyser = ANALYSERS[exercise_type]
    result = analyser.analyse(pose_frames, fps)
    return [result]
