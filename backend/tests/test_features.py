"""
Unit tests for the 14-dimensional feature extractor.

Tests use synthetic PoseFrames built via the make_pose_frame fixture —
no mediapipe, no real video, no model weights required.
"""

import math
import numpy as np
import pytest

from app.cv.pose_detector import PoseFrame
from app.analysis.features import extract_frame_features, extract_sequence_features, NUM_FEATURES


# ── Helpers ───────────────────────────────────────────────────────────────────

def _place_angled_joint(vertex, proximal, angle_deg, limb_len=0.15):
    """
    Given a vertex (joint) and proximal point, compute the distal point such that
    calculate_angle(proximal, vertex, distal) == angle_deg.
    """
    vx, vy = vertex
    px, py = proximal
    direction = np.array([px - vx, py - vy], dtype=float)
    norm = np.linalg.norm(direction)
    if norm > 1e-8:
        direction /= norm
    r = math.radians(angle_deg)
    rot = np.array([[math.cos(r), -math.sin(r)],
                    [math.sin(r),  math.cos(r)]])
    distal_vec = rot @ direction * limb_len
    return (vx + distal_vec[0], vy + distal_vec[1])


# ── Output contract tests ─────────────────────────────────────────────────────

def test_output_shape(make_pose_frame):
    frame = make_pose_frame({})  # all landmarks at default (0.5, 0.5)
    feats = extract_frame_features(frame)
    assert feats.shape == (NUM_FEATURES,), f"Expected ({NUM_FEATURES},), got {feats.shape}"


def test_output_dtype(make_pose_frame):
    frame = make_pose_frame({})
    feats = extract_frame_features(frame)
    assert feats.dtype == np.float32


def test_values_finite_for_valid_landmarks(make_pose_frame):
    """Well-placed landmarks must produce finite (non-NaN, non-Inf) features."""
    frame = make_pose_frame({
        "left_hip":      (0.40, 0.50),
        "left_knee":     (0.38, 0.65),
        "left_ankle":    (0.40, 0.82),
        "right_hip":     (0.55, 0.50),
        "right_knee":    (0.57, 0.65),
        "right_ankle":   (0.55, 0.82),
        "left_shoulder": (0.38, 0.32),
        "right_shoulder":(0.57, 0.32),
        "left_elbow":    (0.30, 0.42),
        "right_elbow":   (0.65, 0.42),
        "left_wrist":    (0.28, 0.55),
        "right_wrist":   (0.67, 0.55),
    })
    feats = extract_frame_features(frame)
    assert np.isfinite(feats).all(), f"Non-finite features: {feats}"


def test_undetected_frame_returns_neutral():
    """A frame with detected=False must return all 0.5 (neutral fallback)."""
    import numpy as _np
    frame = PoseFrame(
        landmarks=_np.zeros((33, 4), dtype=_np.float32),
        frame_idx=0,
        detected=False,
    )
    feats = extract_frame_features(frame)
    assert np.all(feats == 0.5), f"Expected all 0.5, got {feats}"


# ── Angle feature tests ───────────────────────────────────────────────────────

def test_knee_angle_90_degrees(make_pose_frame):
    """
    Place hip-knee-ankle such that the knee angle is exactly 90°.
    Feature 0 (left_knee_angle / 180) should equal 0.5 ± 1e-3.
    """
    hip = (0.50, 0.40)
    knee = (0.50, 0.60)
    ankle = _place_angled_joint(knee, hip, 90.0, limb_len=0.15)
    frame = make_pose_frame({
        "left_hip": hip, "left_knee": knee, "left_ankle": ankle,
        # right side far from left to avoid interference
        "right_hip": (0.80, 0.40), "right_knee": (0.80, 0.60), "right_ankle": (0.80, 0.80),
    })
    feats = extract_frame_features(frame)
    assert abs(feats[0] - 0.5) < 1e-2, f"Expected ~0.5 for 90° knee, got {feats[0]:.4f}"


def test_elbow_angle_180_degrees(make_pose_frame):
    """
    Fully extended elbow (180°) → feature 2 should equal 1.0 ± 0.01.
    """
    shoulder = (0.40, 0.30)
    elbow = (0.30, 0.45)
    wrist = _place_angled_joint(elbow, shoulder, 180.0, limb_len=0.15)
    frame = make_pose_frame({
        "left_shoulder": shoulder, "left_elbow": elbow, "left_wrist": wrist,
        "right_shoulder":(0.60, 0.30), "right_elbow":(0.70, 0.45), "right_wrist":(0.72, 0.60),
    })
    feats = extract_frame_features(frame)
    assert abs(feats[2] - 1.0) < 0.02, f"Expected ~1.0 for 180° elbow, got {feats[2]:.4f}"


# ── wrist_rel_hip (feature 13) tests ─────────────────────────────────────────

def test_wrist_above_hip_gives_positive(make_pose_frame):
    """
    Wrist at y=0.20, hip at y=0.60 → wrist_rel_hip = 0.60 - 0.20 = 0.40 (positive).
    """
    frame = make_pose_frame({
        "left_hip":   (0.40, 0.60),
        "left_wrist": (0.35, 0.20),
    })
    feats = extract_frame_features(frame)
    assert feats[13] > 0, f"Expected positive wrist_rel_hip, got {feats[13]:.4f}"
    assert abs(feats[13] - 0.40) < 0.02, f"Expected ~0.40, got {feats[13]:.4f}"


def test_wrist_below_hip_gives_negative(make_pose_frame):
    """
    Wrist at y=0.80, hip at y=0.60 → wrist_rel_hip = 0.60 - 0.80 = -0.20 (negative).
    """
    frame = make_pose_frame({
        "left_hip":   (0.40, 0.60),
        "left_wrist": (0.35, 0.80),
    })
    feats = extract_frame_features(frame)
    assert feats[13] < 0, f"Expected negative wrist_rel_hip, got {feats[13]:.4f}"
    assert abs(feats[13] - (-0.20)) < 0.02, f"Expected ~-0.20, got {feats[13]:.4f}"


# ── torso_inclination (feature 12) tests ─────────────────────────────────────

def test_torso_vertical_gives_zero_inclination(make_pose_frame):
    """
    Shoulder midpoint directly above hip midpoint (same x) → inclination ≈ 0° → feature ≈ 0.
    """
    frame = make_pose_frame({
        "left_shoulder":  (0.40, 0.20),
        "right_shoulder": (0.60, 0.20),
        "left_hip":       (0.40, 0.55),
        "right_hip":      (0.60, 0.55),
    })
    feats = extract_frame_features(frame)
    # Vertical torso = 0 degrees inclination → feature 12 = 0 / 180 = 0
    assert feats[12] < 0.05, f"Expected ~0 for vertical torso, got {feats[12]:.4f}"


def test_torso_horizontal_gives_large_inclination(make_pose_frame):
    """
    Shoulder midpoint to the right of hip midpoint (same y) → ~90° inclination → feature ≈ 0.5.
    """
    frame = make_pose_frame({
        "left_shoulder":  (0.60, 0.50),
        "right_shoulder": (0.80, 0.50),
        "left_hip":       (0.20, 0.50),
        "right_hip":      (0.40, 0.50),
    })
    feats = extract_frame_features(frame)
    assert 0.40 < feats[12] < 0.60, f"Expected ~0.5 for horizontal torso, got {feats[12]:.4f}"


# ── Sequence extraction tests ─────────────────────────────────────────────────

def test_extract_sequence_shape(make_pose_frame):
    frames = [make_pose_frame({}, frame_idx=i) for i in range(30)]
    result = extract_sequence_features(frames)
    assert result.shape == (30, NUM_FEATURES)


def test_extract_sequence_dtype(make_pose_frame):
    frames = [make_pose_frame({}, frame_idx=i) for i in range(5)]
    result = extract_sequence_features(frames)
    assert result.dtype == np.float32


def test_extract_sequence_stacks_correctly(make_pose_frame):
    """Each row of the sequence result should match the single-frame result."""
    positions = [
        {"left_hip": (0.40 + i * 0.01, 0.50)} for i in range(5)
    ]
    frames = [make_pose_frame(pos, frame_idx=i) for i, pos in enumerate(positions)]
    seq = extract_sequence_features(frames)
    for i, frame in enumerate(frames):
        expected = extract_frame_features(frame)
        np.testing.assert_array_equal(seq[i], expected, err_msg=f"Mismatch at frame {i}")


# ── Exception safety tests ────────────────────────────────────────────────────

def test_exception_safety_degenerate_landmarks(make_pose_frame):
    """
    Landmarks all at (0,0) cause degenerate vectors — must not raise, must return finite values.
    """
    # Landmark dict with all critical joints at origin — causes zero-length vectors
    all_at_origin = {name: (0.0, 0.0) for name in [
        "left_hip", "left_knee", "left_ankle",
        "right_hip", "right_knee", "right_ankle",
        "left_shoulder", "right_shoulder",
        "left_elbow", "right_elbow",
        "left_wrist", "right_wrist",
    ]}
    frame = make_pose_frame(all_at_origin)
    feats = extract_frame_features(frame)  # must not raise
    assert feats.shape == (NUM_FEATURES,)
    assert np.isfinite(feats).all(), "Degenerate landmarks produced non-finite features"


def test_exception_safety_collinear_landmarks(make_pose_frame):
    """
    Collinear hip-knee-ankle (all on the same vertical line) — angle is 180°, should not crash.
    """
    frame = make_pose_frame({
        "left_hip":   (0.50, 0.30),
        "left_knee":  (0.50, 0.55),
        "left_ankle": (0.50, 0.80),
    })
    feats = extract_frame_features(frame)
    assert np.isfinite(feats).all()
