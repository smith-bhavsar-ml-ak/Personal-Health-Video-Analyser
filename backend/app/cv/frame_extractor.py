import cv2
import numpy as np
from dataclasses import dataclass


@dataclass
class VideoMeta:
    total_frames: int
    fps: float
    duration_s: float
    width: int
    height: int


def extract_frames(video_path: str, target_fps: int = 15) -> tuple[list[np.ndarray], VideoMeta]:
    """
    Extract frames from a video file at target_fps sampling rate.
    Returns list of BGR frames and video metadata.
    """
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise ValueError(f"Cannot open video: {video_path}")

    source_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    duration_s = total_frames / source_fps if source_fps > 0 else 0

    meta = VideoMeta(
        total_frames=total_frames,
        fps=source_fps,
        duration_s=duration_s,
        width=width,
        height=height,
    )

    # Sample every N frames to achieve target_fps
    sample_every = max(1, int(source_fps / target_fps))

    frames: list[np.ndarray] = []
    frame_idx = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        if frame_idx % sample_every == 0:
            frames.append(frame)
        frame_idx += 1

    cap.release()
    return frames, meta
