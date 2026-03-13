"""
Shared pytest fixtures for BiLSTM test suite.

Fixtures:
  loaded_model        — session-scoped; loads weights, skips if missing
  make_pose_frame     — factory: landmark_dict → PoseFrame
  make_synthetic_tensor — factory: (class_name, seq_len, noise_std, seed) → Tensor
  physics_vectors     — pre-built (60,14) arrays for physics check scenarios
"""

import math
import numpy as np
import pytest
import torch

from app.cv.pose_detector import PoseFrame, LANDMARK
from app.analysis.bilstm_model import ExerciseBiLSTM, CLASSES, NUM_FEATURES
from app.analysis.train_bilstm import _GENERATORS


# ── Helpers ───────────────────────────────────────────────────────────────────

def _rotation_2d(angle_deg: float) -> np.ndarray:
    """2×2 rotation matrix for the given angle in degrees."""
    r = math.radians(angle_deg)
    return np.array([[math.cos(r), -math.sin(r)],
                     [math.sin(r),  math.cos(r)]])


def _make_landmarks_for_angle(
    joint_name: str,
    vertex_name: str,
    end_name: str,
    vertex_pos: tuple,
    from_pos: tuple,
    angle_deg: float,
    limb_len: float = 0.15,
) -> dict:
    """
    Returns a partial landmark dict with three points placed so that
    calculate_angle(from_pos, vertex_pos, end_pos) == angle_deg.

    - vertex is the joint (e.g. knee)
    - from_pos is the proximal point (e.g. hip)
    - end_pos is computed by rotating the vector (vertex→from) by angle_deg
    """
    vx, vy = vertex_pos
    fx, fy = from_pos
    direction = np.array([fx - vx, fy - vy], dtype=float)
    norm = np.linalg.norm(direction)
    if norm > 1e-8:
        direction = direction / norm
    end_vec = _rotation_2d(angle_deg) @ direction * limb_len
    end_pos = (vx + end_vec[0], vy + end_vec[1])
    return {
        vertex_name: vertex_pos,
        joint_name: from_pos,
        end_name: end_pos,
    }


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def loaded_model():
    """
    Load the trained BiLSTM weights once per test session.
    Skips all dependent tests if the weights file is missing.
    """
    import os
    from app.analysis.bilstm_analyser import preload_model, WEIGHTS_PATH
    import app.analysis.bilstm_analyser as _mod

    if not os.path.exists(WEIGHTS_PATH):
        pytest.skip(f"BiLSTM weights not found at {WEIGHTS_PATH}. Run train_bilstm.py first.")

    preload_model()
    if _mod._model is None:
        pytest.skip("preload_model() failed — check weights file.")

    return _mod._model


@pytest.fixture
def make_pose_frame():
    """
    Factory fixture.  Usage::

        frame = make_pose_frame({"left_hip": (0.45, 0.50), "left_knee": (0.45, 0.65), ...})

    Landmarks NOT listed default to (0.5, 0.5, 0.0, 1.0).
    """
    def _factory(landmark_positions: dict, frame_idx: int = 0, detected: bool = True) -> PoseFrame:
        arr = np.zeros((33, 4), dtype=np.float32)
        # Fill all landmarks with a neutral "center of frame" default
        arr[:, 0] = 0.5   # x
        arr[:, 1] = 0.5   # y
        arr[:, 3] = 1.0   # visibility = fully visible
        for name, pos in landmark_positions.items():
            idx = LANDMARK[name]
            x, y = pos
            arr[idx] = [x, y, 0.0, 1.0]
        return PoseFrame(landmarks=arr, frame_idx=frame_idx, detected=detected)

    return _factory


@pytest.fixture
def make_synthetic_tensor():
    """
    Factory fixture.  Usage::

        x = make_synthetic_tensor("squat", seq_len=60, noise_std=0.01, seed=7)
        # x.shape == (1, 60, 14)
    """
    def _factory(
        class_name: str,
        seq_len: int = 60,
        noise_std: float = 0.0,
        seed: int = 42,
    ) -> torch.Tensor:
        idx = CLASSES.index(class_name)
        gen = _GENERATORS[idx]
        # Seed numpy global state so the generator's np.random.uniform calls
        # are deterministic. Save and restore to avoid polluting other tests.
        saved_state = np.random.get_state()
        np.random.seed(seed)
        seq = gen(seq_len)
        np.random.set_state(saved_state)
        if noise_std > 0:
            rng = np.random.default_rng(seed + 1)
            seq = seq + rng.normal(0, noise_std, seq.shape).astype(np.float32)
            seq = np.clip(seq, 0.0, 1.0)
        return torch.from_numpy(seq).unsqueeze(0)  # (1, T, 14)

    return _factory


@pytest.fixture(scope="session")
def physics_vectors():
    """
    Pre-built (60, 14) feature arrays for every physics check scenario.

    Feature index reference:
      0  left_knee_angle   1  right_knee_angle
      2  left_elbow_angle  3  right_elbow_angle
      13 wrist_rel_hip
    """
    T = 60

    def _make(knee_vals=None, elbow_vals=None, wrist_max=0.5):
        """Build a (T, 14) array with specific knee / elbow / wrist patterns."""
        arr = np.full((T, NUM_FEATURES), 0.5, dtype=np.float32)
        if knee_vals is not None:
            lo, hi = knee_vals
            t = np.linspace(0, 1, T)
            cycle = lo + (hi - lo) * 0.5 * (1 - np.cos(2 * math.pi * 3 * t))
            arr[:, 0] = cycle.astype(np.float32)
            arr[:, 1] = cycle.astype(np.float32)
        if elbow_vals is not None:
            lo, hi = elbow_vals
            t = np.linspace(0, 1, T)
            cycle = lo + (hi - lo) * 0.5 * (1 - np.cos(2 * math.pi * 3 * t))
            arr[:, 2] = cycle.astype(np.float32)
            arr[:, 3] = cycle.astype(np.float32)
        # wrist_rel_hip: set the maximum by placing one frame high
        arr[:, 13] = -0.20
        arr[0, 13] = float(wrist_max)
        return arr

    return {
        # jumping_jack scenarios
        "jj_valid":            _make(knee_vals=(0.92, 0.97), elbow_vals=(0.65, 0.95), wrist_max=0.30),
        "jj_fail_knee_range":  _make(knee_vals=(0.80, 0.97), wrist_max=0.30),   # range=0.17 > 0.10
        "jj_fail_knee_min":    _make(knee_vals=(0.80, 0.93), wrist_max=0.30),   # min=0.80 < 0.85
        "jj_fail_wrist_low":   _make(knee_vals=(0.92, 0.97), wrist_max=0.05),   # max=0.05 < 0.10
        "jj_boundary_010":     _make(knee_vals=(0.87, 0.97), wrist_max=0.30),   # range=exactly 0.10
        "jj_boundary_011":     _make(knee_vals=(0.869, 0.97), wrist_max=0.30),  # range=0.101 > 0.10
        # plank scenarios
        "plank_valid":         _make(knee_vals=(0.92, 0.96), elbow_vals=(0.48, 0.52)),
        "plank_fail_knee":     _make(knee_vals=(0.80, 0.97)),   # range=0.17 > 0.15
        "plank_fail_elbow":    _make(knee_vals=(0.92, 0.96), elbow_vals=(0.40, 0.65)),  # range=0.25 > 0.20
        # bicep_curl scenarios
        "bicep_valid":         _make(knee_vals=(0.92, 0.96), elbow_vals=(0.25, 0.94)),
        "bicep_fail_no_flex":  _make(knee_vals=(0.92, 0.96), elbow_vals=(0.80, 0.90)),  # range=0.10 < 0.15
        "bicep_fail_knee":     _make(knee_vals=(0.78, 0.96), elbow_vals=(0.25, 0.94)),  # range=0.18 > 0.15
        # generic
        "neutral":             _make(knee_vals=(0.88, 0.95), elbow_vals=(0.85, 0.95), wrist_max=0.0),
    }
