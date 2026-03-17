"""
Preprocess real exercise videos into labeled .npy sequence files for BiLSTM training.

Directory structure expected:
    data/real/videos/
        <label>/           ← subdirectory name becomes the class label
            clip_01.mp4
            clip_02.mp4
            ...

Output:
    data/real/sequences/
        <label>_0000.npy   ← (60, 14) float32 feature arrays
        <label>_0001.npy
        ...
        manifest.json      ← class list + per-class counts

Run from the backend/ directory:
    python -m app.analysis.preprocess_real_data
    python -m app.analysis.preprocess_real_data --data-dir data/real/videos --out-dir data/real/sequences
    python -m app.analysis.preprocess_real_data --window 60 --stride 15 --min-detect 0.80
"""

import argparse
import asyncio
import json
import logging
import os
from pathlib import Path

import numpy as np

from app.cv.pipeline import run_cv_pipeline_from_bytes
from app.analysis.features import extract_sequence_features

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)


async def process_video(
    video_path: Path,
    label: str,
    out_dir: Path,
    global_idx: int,
    window: int,
    stride: int,
    min_detect: float,
) -> int:
    """
    Process a single video file: extract pose features, apply sliding window,
    save qualifying windows as .npy files.

    Returns the number of sequences saved from this video.
    """
    logger.info("Processing %s...", video_path.name)
    content = video_path.read_bytes()

    try:
        pose_frames, _ = await run_cv_pipeline_from_bytes(content, video_path.name)
    except Exception as e:
        logger.error("Failed to process %s: %s", video_path.name, e)
        return 0

    if not pose_frames:
        logger.warning("No frames extracted from %s", video_path.name)
        return 0

    # Extract full feature sequence for this clip
    feats = extract_sequence_features(pose_frames)  # (T, 14)
    T = len(feats)

    if T < window:
        logger.warning(
            "Video %s too short (%d frames < window %d) — skipping",
            video_path.name, T, window,
        )
        return 0

    saved = 0
    for start in range(0, T - window + 1, stride):
        end = start + window
        window_frames = pose_frames[start:end]
        detected_ratio = sum(1 for f in window_frames if f.detected) / window

        if detected_ratio < min_detect:
            logger.debug(
                "Skipping window [%d:%d] of %s — detect ratio %.2f < %.2f",
                start, end, video_path.name, detected_ratio, min_detect,
            )
            continue

        window_feats = feats[start:end]  # (window, 14)
        out_path = out_dir / f"{label}_{global_idx + saved:04d}.npy"
        np.save(out_path, window_feats.astype(np.float32))
        saved += 1

    logger.info(
        "  %s → %d sequences saved (T=%d, detect=%.0f%%)",
        video_path.name, saved, T,
        sum(1 for f in pose_frames if f.detected) / len(pose_frames) * 100,
    )
    return saved


async def preprocess(
    data_dir: str,
    out_dir: str,
    window: int,
    stride: int,
    min_detect: float,
) -> None:
    data_path = Path(data_dir)
    out_path  = Path(out_dir)

    if not data_path.exists():
        raise FileNotFoundError(f"Data directory not found: {data_dir}")

    # Discover class labels from subdirectory names
    class_dirs = sorted(d for d in data_path.iterdir() if d.is_dir())
    if not class_dirs:
        raise ValueError(f"No subdirectories found in {data_dir}. "
                         "Create one subdirectory per exercise class.")

    discovered_classes = [d.name for d in class_dirs]
    logger.info("Discovered classes: %s", discovered_classes)

    out_path.mkdir(parents=True, exist_ok=True)

    video_extensions = {".mp4", ".avi", ".mov", ".mkv", ".webm"}
    class_counts: dict[str, int] = {}

    for class_dir in class_dirs:
        label = class_dir.name
        videos = sorted(
            f for f in class_dir.iterdir()
            if f.suffix.lower() in video_extensions
        )

        if not videos:
            logger.warning("No video files found in %s — skipping", class_dir)
            class_counts[label] = 0
            continue

        logger.info("--- Class: %s (%d videos) ---", label, len(videos))
        global_idx = 0
        for video_path in videos:
            n = await process_video(
                video_path, label, out_path,
                global_idx, window, stride, min_detect,
            )
            global_idx += n

        class_counts[label] = global_idx
        logger.info("Class %s: %d total sequences saved", label, global_idx)

    # Print summary table
    print("\n" + "=" * 50)
    print("Preprocessing Summary")
    print("=" * 50)
    print(f"{'Class':<20} {'Sequences':>10}")
    print("-" * 50)
    total = 0
    for label, count in class_counts.items():
        print(f"{label:<20} {count:>10}")
        total += count
    print("-" * 50)
    print(f"{'TOTAL':<20} {total:>10}")
    print("=" * 50)
    print(f"\nOutput directory: {out_path.resolve()}")

    # Write manifest
    manifest = {
        "classes":      discovered_classes,
        "class_counts": class_counts,
        "total_sequences": total,
        "window":       window,
        "stride":       stride,
        "min_detect":   min_detect,
        "num_features": 14,
    }
    manifest_path = out_path / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2))
    logger.info("Manifest written to %s", manifest_path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extract labeled feature sequences from exercise videos"
    )
    parser.add_argument(
        "--data-dir",
        default="data/real/videos",
        help="Root directory with subdirectories named by exercise class",
    )
    parser.add_argument(
        "--out-dir",
        default="data/real/sequences",
        help="Output directory for .npy sequence files",
    )
    parser.add_argument(
        "--window",
        type=int,
        default=60,
        help="Sliding window size in frames (default: 60 ≈ 2s at 30fps)",
    )
    parser.add_argument(
        "--stride",
        type=int,
        default=15,
        help="Stride between windows in frames (default: 15)",
    )
    parser.add_argument(
        "--min-detect",
        type=float,
        default=0.80,
        help="Minimum fraction of detected frames per window (default: 0.80)",
    )
    args = parser.parse_args()

    asyncio.run(
        preprocess(
            data_dir=args.data_dir,
            out_dir=args.out_dir,
            window=args.window,
            stride=args.stride,
            min_detect=args.min_detect,
        )
    )


if __name__ == "__main__":
    main()
