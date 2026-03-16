import asyncio
import logging
import os
import tempfile
import time
from fastapi import UploadFile

from app.cv.frame_extractor import extract_frames, VideoMeta
from app.cv.pose_detector import detect_poses, PoseFrame

logger = logging.getLogger(__name__)


def _run_cv_sync(tmp_path: str) -> tuple[list[PoseFrame], VideoMeta]:
    """Synchronous CV work — safe to run in a thread pool."""
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
    return pose_frames, meta


async def run_cv_pipeline_from_bytes(content: bytes, filename: str) -> tuple[list[PoseFrame], VideoMeta]:
    """
    CV pipeline that accepts raw bytes — used by background tasks.
    Heavy CV work runs in a thread pool so the event loop stays free.
    """
    suffix = os.path.splitext(filename)[1] or ".mp4"
    logger.info("Writing %d bytes to temp file (suffix=%s)...", len(content), suffix)
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(content)
        tmp_path = tmp.name
    try:
        return await asyncio.to_thread(_run_cv_sync, tmp_path)
    finally:
        os.unlink(tmp_path)
        logger.info("Temp file deleted: %s", tmp_path)


async def run_cv_pipeline(video_file: UploadFile) -> tuple[list[PoseFrame], VideoMeta]:
    """Convenience wrapper that reads an UploadFile then delegates to run_cv_pipeline_from_bytes."""
    content = await video_file.read()
    filename = video_file.filename or "video.mp4"
    return await run_cv_pipeline_from_bytes(content, filename)
