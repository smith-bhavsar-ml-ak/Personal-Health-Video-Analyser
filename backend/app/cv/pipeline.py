import logging
import os
import tempfile
import time
from fastapi import UploadFile

from app.cv.frame_extractor import extract_frames, VideoMeta
from app.cv.pose_detector import detect_poses, PoseFrame

logger = logging.getLogger(__name__)


async def run_cv_pipeline(video_file: UploadFile) -> tuple[list[PoseFrame], VideoMeta]:
    """
    Full CV pipeline:
    1. Save upload to temp file
    2. Extract frames at 15fps
    3. Run MediaPipe pose detection
    4. Return pose sequence + video metadata
    Temp file is deleted after processing.
    """
    suffix = os.path.splitext(video_file.filename or "video.mp4")[1] or ".mp4"

    logger.info("Saving upload to temp file (suffix=%s)...", suffix)
    t = time.perf_counter()
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = await video_file.read()
        tmp.write(content)
        tmp_path = tmp.name
    logger.info("Saved %d bytes to %s in %.2fs", len(content), tmp_path, time.perf_counter() - t)

    try:
        logger.info("Extracting frames at target_fps=15...")
        t = time.perf_counter()
        frames, meta = extract_frames(tmp_path, target_fps=15)
        logger.info(
            "Extracted %d frames in %.2fs (source=%.1ffps, sample_every=%d)",
            len(frames), time.perf_counter() - t, meta.fps,
            max(1, int(meta.fps / 15)),
        )

        logger.info("Running MediaPipe pose detection on %d frames...", len(frames))
        t = time.perf_counter()
        pose_frames = detect_poses(frames)
        detected = sum(1 for f in pose_frames if f.detected)
        logger.info(
            "Pose detection done in %.2fs | detected=%d/%d frames (%.0f%%)",
            time.perf_counter() - t, detected, len(pose_frames),
            100 * detected / len(pose_frames) if pose_frames else 0,
        )
    finally:
        os.unlink(tmp_path)
        logger.info("Temp file deleted: %s", tmp_path)

    return pose_frames, meta
