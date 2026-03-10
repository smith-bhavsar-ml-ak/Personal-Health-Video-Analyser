import os
import tempfile
from fastapi import UploadFile

from app.cv.frame_extractor import extract_frames, VideoMeta
from app.cv.pose_detector import detect_poses, PoseFrame


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

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = await video_file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        frames, meta = extract_frames(tmp_path, target_fps=15)
        pose_frames = detect_poses(frames)
    finally:
        os.unlink(tmp_path)  # delete video immediately after processing

    return pose_frames, meta
