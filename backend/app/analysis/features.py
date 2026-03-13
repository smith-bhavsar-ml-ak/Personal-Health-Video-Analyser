"""
Feature extraction from PoseFrame sequences for BiLSTM classification.

Produces a 14-dimensional feature vector per frame:
  0  left_knee_angle        (hip-knee-ankle)
  1  right_knee_angle       (hip-knee-ankle)
  2  left_elbow_angle       (shoulder-elbow-wrist)
  3  right_elbow_angle      (shoulder-elbow-wrist)
  4  left_hip_angle         (shoulder-hip-knee)
  5  right_hip_angle        (shoulder-hip-knee)
  6  left_shoulder_angle    (elbow-shoulder-hip)
  7  right_shoulder_angle   (elbow-shoulder-hip)
  8  arm_spread             (|l_shoulder_x - r_shoulder_x|)
  9  hip_spread             (|l_hip_x - r_hip_x|)
 10  left_hip_height        (l_hip_y, lower y = higher in image for MediaPipe)
 11  right_hip_height       (r_hip_y)
 12  torso_inclination      (angle of shoulder-midpoint → hip-midpoint vector, degrees from vertical)
 13  left_wrist_rel_hip     (l_hip_y - l_wrist_y; positive when wrist is above hip)

All angles are in degrees and normalised to [0, 1] by dividing by 180.
Distances and heights are already in [0, 1] as MediaPipe uses normalised coords.
"""

import numpy as np
from app.cv.pose_detector import PoseFrame, calculate_angle, get_landmark
from app.analysis.bilstm_model import NUM_FEATURES


def _safe_angle(a, b, c) -> float:
    try:
        return calculate_angle(a, b, c) / 180.0
    except Exception:
        return 0.5  # neutral fallback


def extract_frame_features(frame: PoseFrame) -> np.ndarray:
    """Return a (14,) float32 feature vector for a single PoseFrame."""
    feats = np.full(NUM_FEATURES, 0.5, dtype=np.float32)
    if not frame.detected:
        return feats

    try:
        l_shoulder = get_landmark(frame, "left_shoulder")
        r_shoulder = get_landmark(frame, "right_shoulder")
        l_elbow    = get_landmark(frame, "left_elbow")
        r_elbow    = get_landmark(frame, "right_elbow")
        l_wrist    = get_landmark(frame, "left_wrist")
        r_wrist    = get_landmark(frame, "right_wrist")
        l_hip      = get_landmark(frame, "left_hip")
        r_hip      = get_landmark(frame, "right_hip")
        l_knee     = get_landmark(frame, "left_knee")
        r_knee     = get_landmark(frame, "right_knee")
        l_ankle    = get_landmark(frame, "left_ankle")
        r_ankle    = get_landmark(frame, "right_ankle")

        feats[0]  = _safe_angle(l_hip,     l_knee,   l_ankle)      # left knee
        feats[1]  = _safe_angle(r_hip,     r_knee,   r_ankle)      # right knee
        feats[2]  = _safe_angle(l_shoulder, l_elbow, l_wrist)      # left elbow
        feats[3]  = _safe_angle(r_shoulder, r_elbow, r_wrist)      # right elbow
        feats[4]  = _safe_angle(l_shoulder, l_hip,   l_knee)       # left hip
        feats[5]  = _safe_angle(r_shoulder, r_hip,   r_knee)       # right hip
        feats[6]  = _safe_angle(l_elbow,   l_shoulder, l_hip)      # left shoulder
        feats[7]  = _safe_angle(r_elbow,   r_shoulder, r_hip)      # right shoulder
        feats[8]  = float(abs(l_shoulder[0] - r_shoulder[0]))      # arm spread
        feats[9]  = float(abs(l_hip[0] - r_hip[0]))                # hip spread
        feats[10] = float(l_hip[1])                                 # left hip height (y)
        feats[11] = float(r_hip[1])                                 # right hip height (y)

        # torso inclination: angle of vector from hip-mid to shoulder-mid vs vertical
        hip_mid  = (l_hip[:2] + r_hip[:2]) / 2
        sho_mid  = (l_shoulder[:2] + r_shoulder[:2]) / 2
        torso_vec = sho_mid - hip_mid
        vertical  = np.array([0.0, -1.0])  # pointing upward in image coords
        norm = np.linalg.norm(torso_vec)
        if norm > 1e-6:
            cos_a = np.dot(torso_vec / norm, vertical)
            feats[12] = float(np.degrees(np.arccos(np.clip(cos_a, -1.0, 1.0)))) / 180.0
        else:
            feats[12] = 0.0

        feats[13] = float(l_hip[1] - l_wrist[1])   # positive = wrist above hip

    except Exception:
        pass  # return partially-filled or neutral feats

    return feats


def extract_sequence_features(pose_frames: list[PoseFrame]) -> np.ndarray:
    """
    Extract features for an entire sequence.
    Returns shape (T, 14) where T = len(pose_frames).
    """
    return np.stack([extract_frame_features(f) for f in pose_frames], axis=0).astype(np.float32)
