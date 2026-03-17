"""
Unit tests for the _physics_check function in bilstm_analyser.

Tests operate purely on numpy feature arrays — no model weights, no PoseFrames.
The function is imported directly from the private namespace (Python has no true private).
"""

import math
import numpy as np
import pytest

from app.analysis.bilstm_analyser import _physics_check
from app.analysis.bilstm_model import NUM_FEATURES


# ── Helper ────────────────────────────────────────────────────────────────────

def _make_feats(knee_lo=0.92, knee_hi=0.97, elbow_lo=0.85, elbow_hi=0.95, wrist_max=0.40):
    """
    Build a (60, 14) feature array with controlled knee, elbow, and wrist values.

    Feature indices:
      0, 1  = left/right knee angle
      2, 3  = left/right elbow angle
      13    = wrist_rel_hip (positive = wrist above hip)
    """
    T = 60
    arr = np.full((T, NUM_FEATURES), 0.5, dtype=np.float32)
    t = np.linspace(0, 1, T, dtype=np.float32)
    knee_cycle = knee_lo + (knee_hi - knee_lo) * 0.5 * (1 - np.cos(2 * math.pi * 3 * t))
    elbow_cycle = elbow_lo + (elbow_hi - elbow_lo) * 0.5 * (1 - np.cos(2 * math.pi * 3 * t))
    arr[:, 0] = knee_cycle
    arr[:, 1] = knee_cycle
    arr[:, 2] = elbow_cycle
    arr[:, 3] = elbow_cycle
    arr[:, 13] = -0.20   # baseline: wrist below hip
    arr[0, 13] = wrist_max  # peak frame
    return arr


# ── jumping_jack tests ────────────────────────────────────────────────────────

def test_jj_valid_passes():
    feats = _make_feats(knee_lo=0.92, knee_hi=0.97, wrist_max=0.30)
    valid, reason = _physics_check("jumping_jack", feats)
    assert valid is True
    assert reason == ""


def test_jj_high_knee_range_still_passes():
    """Real video shows knee_range=0.47 on valid JJ — knee constraints removed."""
    feats = _make_feats(knee_lo=0.50, knee_hi=0.97, wrist_max=0.30)
    valid, reason = _physics_check("jumping_jack", feats)
    assert valid is True, f"High knee range should pass after real-data calibration: {reason}"


def test_jj_low_knee_min_still_passes():
    """Real video shows knee_min=0.53 on valid JJ — knee_min constraint removed."""
    feats = _make_feats(knee_lo=0.53, knee_hi=0.97, wrist_max=0.30)
    valid, reason = _physics_check("jumping_jack", feats)
    assert valid is True, f"Low knee_min should pass after real-data calibration: {reason}"


def test_jj_fails_wrists_never_overhead():
    """wrist_max = 0.05 < 0.10 threshold → must reject."""
    feats = _make_feats(knee_lo=0.92, knee_hi=0.97, wrist_max=0.05)
    valid, reason = _physics_check("jumping_jack", feats)
    assert valid is False
    assert "wrist" in reason.lower()


@pytest.mark.parametrize("knee_range", [0.09, 0.10, 0.20, 0.47, 0.50])
def test_jj_any_knee_range_passes_if_wrist_ok(knee_range):
    """Knee range no longer constrained — any value passes as long as wrist is overhead."""
    knee_hi = 0.97
    knee_lo = max(0.0, knee_hi - knee_range)
    feats = _make_feats(knee_lo=knee_lo, knee_hi=knee_hi, wrist_max=0.30)
    valid, reason = _physics_check("jumping_jack", feats)
    assert valid is True, \
        f"knee_range={knee_range:.3f} should pass (knee constraint removed): {reason}"


# ── plank tests ───────────────────────────────────────────────────────────────

def test_plank_valid_passes():
    feats = _make_feats(knee_lo=0.92, knee_hi=0.96, elbow_lo=0.48, elbow_hi=0.52)
    valid, reason = _physics_check("plank", feats)
    assert valid is True


def test_plank_fails_knee_range_too_large():
    """knee_range = 0.17 > 0.15 → reject."""
    feats = _make_feats(knee_lo=0.80, knee_hi=0.97)
    valid, reason = _physics_check("plank", feats)
    assert valid is False
    assert "knee_range" in reason or "knee" in reason.lower()


def test_plank_fails_elbow_range_too_large():
    """elbow_range = 0.25 > 0.20 → reject."""
    feats = _make_feats(knee_lo=0.92, knee_hi=0.96, elbow_lo=0.40, elbow_hi=0.65)
    valid, reason = _physics_check("plank", feats)
    assert valid is False
    assert "elbow_range" in reason or "elbow" in reason.lower()


# ── bicep_curl tests ──────────────────────────────────────────────────────────

def test_bicep_valid_passes():
    feats = _make_feats(knee_lo=0.92, knee_hi=0.96, elbow_lo=0.25, elbow_hi=0.94)
    valid, reason = _physics_check("bicep_curl", feats)
    assert valid is True


def test_bicep_fails_insufficient_elbow_flex():
    """elbow_range = 0.10 < 0.15 → reject."""
    feats = _make_feats(knee_lo=0.92, knee_hi=0.96, elbow_lo=0.80, elbow_hi=0.90)
    valid, reason = _physics_check("bicep_curl", feats)
    assert valid is False
    assert "elbow_range" in reason or "elbow" in reason.lower()


def test_bicep_fails_too_much_knee_motion():
    """knee_range = 0.18 > 0.15 → reject."""
    feats = _make_feats(knee_lo=0.78, knee_hi=0.96, elbow_lo=0.25, elbow_hi=0.94)
    valid, reason = _physics_check("bicep_curl", feats)
    assert valid is False
    assert "knee_range" in reason or "knee" in reason.lower()


# ── Unconstrained classes ─────────────────────────────────────────────────────

@pytest.mark.parametrize("class_name", ["squat", "lunge"])
def test_unconstrained_classes_always_pass(class_name, physics_vectors):
    """squat and lunge have no physics constraints — any features must pass."""
    feats = physics_vectors["neutral"]
    valid, reason = _physics_check(class_name, feats)
    assert valid is True, f"{class_name} should always pass physics check, got: {reason}"


# ── Reason string quality ─────────────────────────────────────────────────────

@pytest.mark.parametrize("class_name,feats_key", [
    ("jumping_jack", "jj_fail_wrist_low"),   # only remaining JJ constraint is wrist elevation
    ("plank",        "plank_fail_knee"),
    ("bicep_curl",   "bicep_fail_no_flex"),
])
def test_reason_string_non_empty_on_failure(class_name, feats_key, physics_vectors):
    feats = physics_vectors[feats_key]
    valid, reason = _physics_check(class_name, feats)
    assert valid is False
    assert len(reason) > 0, "Failure reason string must not be empty"
    assert class_name in reason, f"Reason should mention the class name '{class_name}'"


# ── Fixture-based comprehensive checks ───────────────────────────────────────

def test_jj_valid_via_fixture(physics_vectors):
    valid, _ = _physics_check("jumping_jack", physics_vectors["jj_valid"])
    assert valid is True


def test_plank_valid_via_fixture(physics_vectors):
    valid, _ = _physics_check("plank", physics_vectors["plank_valid"])
    assert valid is True


def test_bicep_valid_via_fixture(physics_vectors):
    valid, _ = _physics_check("bicep_curl", physics_vectors["bicep_valid"])
    assert valid is True
