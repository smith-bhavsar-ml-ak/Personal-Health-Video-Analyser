import mediapipe as mp
import numpy as np
import cv2
from dataclasses import dataclass

mp_pose = mp.solutions.pose

# MediaPipe landmark indices
LANDMARK = {
    "nose": 0,
    "left_shoulder": 11, "right_shoulder": 12,
    "left_elbow": 13, "right_elbow": 14,
    "left_wrist": 15, "right_wrist": 16,
    "left_hip": 23, "right_hip": 24,
    "left_knee": 25, "right_knee": 26,
    "left_ankle": 27, "right_ankle": 28,
    "left_heel": 29, "right_heel": 30,
    "left_foot_index": 31, "right_foot_index": 32,
}


@dataclass
class PoseFrame:
    landmarks: np.ndarray   # shape (33, 4): x, y, z, visibility
    frame_idx: int
    detected: bool


def calculate_angle(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    """Calculate angle at point b given three 2D points a, b, c."""
    ba = a[:2] - b[:2]
    bc = c[:2] - b[:2]
    cosine = np.dot(ba, bc) / (np.linalg.norm(ba) * np.linalg.norm(bc) + 1e-8)
    angle = np.degrees(np.arccos(np.clip(cosine, -1.0, 1.0)))
    return float(angle)


def detect_poses(frames: list[np.ndarray]) -> list[PoseFrame]:
    """Run MediaPipe Pose on a list of frames. Returns one PoseFrame per input frame."""
    pose_frames: list[PoseFrame] = []

    with mp_pose.Pose(
        static_image_mode=False,
        model_complexity=1,
        smooth_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    ) as pose:
        for idx, frame in enumerate(frames):
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = pose.process(rgb)

            if results.pose_landmarks:
                landmarks = np.array(
                    [[lm.x, lm.y, lm.z, lm.visibility] for lm in results.pose_landmarks.landmark],
                    dtype=np.float32,
                )
                pose_frames.append(PoseFrame(landmarks=landmarks, frame_idx=idx, detected=True))
            else:
                pose_frames.append(PoseFrame(
                    landmarks=np.zeros((33, 4), dtype=np.float32),
                    frame_idx=idx,
                    detected=False,
                ))

    return pose_frames


def get_landmark(pose_frame: PoseFrame, name: str) -> np.ndarray:
    """Return (x, y, z, visibility) for a named landmark."""
    return pose_frame.landmarks[LANDMARK[name]]
