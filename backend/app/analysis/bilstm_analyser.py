"""
BiLSTM-based exercise analyser.

Drop-in replacement for rule_based.run_analysis().

The module:
1. Lazily loads the trained BiLSTM weights on first call (or at startup via
   preload_model()).
2. Classifies the exercise type from the full pose sequence using the BiLSTM,
   then applies physics-based sanity checks to catch domain-gap errors.
3. Falls back to rule-based classification if weights are unavailable or a
   physics constraint is violated.
4. Delegates rep-counting and form-scoring to the existing rule-based analysers.
5. Supports dynamic exercise classes — class list is embedded in the weights
   checkpoint, so new exercises require only retraining, not code changes.
"""

import logging
import os
from typing import Optional

import numpy as np
import torch

from app.cv.pose_detector import PoseFrame
from app.analysis.base import ExerciseResult
from app.analysis.features import extract_sequence_features
from app.analysis.bilstm_model import ExerciseBiLSTM, CLASSES as _FALLBACK_CLASSES
from app.analysis.exercises.squat import SquatAnalyser
from app.analysis.exercises.jumping_jack import JumpingJackAnalyser
from app.analysis.exercises.bicep_curl import BicepCurlAnalyser
from app.analysis.exercises.lunge import LungeAnalyser
from app.analysis.exercises.plank import PlankAnalyser

logger = logging.getLogger(__name__)

WEIGHTS_PATH = os.path.join(os.path.dirname(__file__), "weights", "bilstm_classifier.pt")

ANALYSERS = {
    "squat":        SquatAnalyser(),
    "jumping_jack": JumpingJackAnalyser(),
    "bicep_curl":   BicepCurlAnalyser(),
    "lunge":        LungeAnalyser(),
    "plank":        PlankAnalyser(),
}

# Physics constraints per exercise — dict-based, extensible.
# Keys match the constraint feature stats; exercises with no entry always pass.
PHYSICS_CONSTRAINTS: dict[str, dict] = {
    "jumping_jack": {
        # Real 2D MediaPipe video shows wide knee-angle variation even during standard
        # jumping jacks (observed knee_range=0.47, knee_min=0.53 on a valid JJ clip).
        # Knee constraints are removed — the only reliable discriminator is wrist
        # elevation (arms must go overhead at some point during the movement).
        "wrist_max_min": 0.10,
    },
    "plank": {
        "knee_range_max":  0.15,
        "elbow_range_max": 0.20,
    },
    "bicep_curl": {
        "elbow_range_min": 0.15,
        "knee_range_max":  0.15,
    },
}

# Module-level model cache (loaded once, reused for every request)
_model: Optional[ExerciseBiLSTM] = None
_device: torch.device = torch.device("cpu")
# Class list resolved from weights checkpoint; falls back to bilstm_model.CLASSES
_classes: list[str] = list(_FALLBACK_CLASSES)


def preload_model() -> None:
    """
    Load the BiLSTM weights into memory.
    Call this at application startup to avoid latency on the first request.
    """
    global _model, _device, _classes
    if _model is not None:
        return  # already loaded

    if not os.path.exists(WEIGHTS_PATH):
        logger.warning(
            "BiLSTM weights not found at %s. "
            "Run `python -m app.analysis.train_bilstm` to train. "
            "Falling back to rule-based classification.",
            WEIGHTS_PATH,
        )
        return

    _device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    checkpoint = torch.load(WEIGHTS_PATH, map_location=_device, weights_only=False)

    if isinstance(checkpoint, dict) and "state_dict" in checkpoint:
        # New format: {'state_dict': ..., 'classes': [...]}
        _classes = checkpoint["classes"]
        model = ExerciseBiLSTM(num_classes=len(_classes))
        model.load_state_dict(checkpoint["state_dict"])
    else:
        # Backward compat: old flat state_dict (synthetic-only weights)
        _classes = list(_FALLBACK_CLASSES)
        model = ExerciseBiLSTM(num_classes=len(_FALLBACK_CLASSES))
        model.load_state_dict(checkpoint)

    model.eval()
    model.to(_device)
    _model = model
    logger.info(
        "BiLSTM classifier loaded from %s (device=%s, classes=%s)",
        WEIGHTS_PATH, _device, _classes,
    )


def _physics_check(bilstm_pred: str, feats: np.ndarray) -> tuple[bool, str]:
    """
    Validate a BiLSTM prediction against hard motion-physics constraints.

    Uses PHYSICS_CONSTRAINTS dict — exercises with no entry always pass.
    Returns (is_valid, reason_if_invalid).
    """
    constraints = PHYSICS_CONSTRAINTS.get(bilstm_pred)
    if constraints is None:
        return True, ""

    f_min   = feats.min(axis=0)
    f_max   = feats.max(axis=0)
    f_range = f_max - f_min

    knee_range  = float(max(f_range[0], f_range[1]))
    elbow_range = float(max(f_range[2], f_range[3]))
    knee_min    = float(min(f_min[0], f_min[1]))
    wrist_max   = float(f_max[13])

    logger.info(
        "Physics features | knee_min=%.3f(%.0f°) knee_range=%.3f(%.0f°) "
        "elbow_range=%.3f(%.0f°) wrist_max=%.3f",
        knee_min, knee_min * 180, knee_range, knee_range * 180,
        elbow_range, elbow_range * 180, wrist_max,
    )

    if "knee_range_max" in constraints and knee_range > constraints["knee_range_max"]:
        return False, (
            f"{bilstm_pred} rejected: knee_range={knee_range:.3f}({knee_range*180:.0f}°) "
            f"> max {constraints['knee_range_max']}"
        )
    if "knee_min_min" in constraints and knee_min < constraints["knee_min_min"]:
        return False, (
            f"{bilstm_pred} rejected: knee_min={knee_min:.3f}({knee_min*180:.0f}°) "
            f"< min {constraints['knee_min_min']}"
        )
    if "wrist_max_min" in constraints and wrist_max < constraints["wrist_max_min"]:
        return False, (
            f"{bilstm_pred} rejected: wrist_max={wrist_max:.3f} "
            f"< min {constraints['wrist_max_min']}"
        )
    if "elbow_range_max" in constraints and elbow_range > constraints["elbow_range_max"]:
        return False, (
            f"{bilstm_pred} rejected: elbow_range={elbow_range:.3f}({elbow_range*180:.0f}°) "
            f"> max {constraints['elbow_range_max']}"
        )
    if "elbow_range_min" in constraints and elbow_range < constraints["elbow_range_min"]:
        return False, (
            f"{bilstm_pred} rejected: elbow_range={elbow_range:.3f}({elbow_range*180:.0f}°) "
            f"< min {constraints['elbow_range_min']}"
        )

    return True, ""


def _minimal_result(exercise_type: str, pose_frames: list[PoseFrame], fps: float) -> ExerciseResult:
    """Fallback ExerciseResult for exercises not in ANALYSERS (new dynamic classes)."""
    duration = len(pose_frames) / fps if fps > 0 else 0.0
    return ExerciseResult(
        exercise_type=exercise_type,
        rep_count=0,
        correct_reps=0,
        duration_s=duration,
        form_score=0.0,
        rep_scores=[],
        posture_errors=[],
    )


def classify_exercise(pose_frames: list[PoseFrame]) -> str:
    """
    Classify exercise type using the BiLSTM model with physics sanity checks.
    Falls back to rule-based heuristics if the model is unavailable or a
    physics constraint is violated.
    """
    detected = [f for f in pose_frames if f.detected]
    if not detected:
        return "squat"

    # Lazy-load on first inference call
    if _model is None:
        preload_model()

    if _model is None:
        logger.info("Using rule-based fallback (BiLSTM weights unavailable)")
        from app.analysis.rule_based import detect_exercise_type
        return detect_exercise_type(pose_frames)

    # Extract features once — used for both BiLSTM and physics check
    feats = extract_sequence_features(detected)           # (T, 14)
    x = torch.from_numpy(feats).unsqueeze(0).to(_device)  # (1, T, 14)

    with torch.no_grad():
        logits = _model(x)                                # (1, num_classes)
        probs  = torch.softmax(logits, dim=1)[0]
        pred   = int(logits.argmax(dim=1).item())

    exercise   = _classes[pred]
    confidence = float(probs[pred])
    logger.info(
        "BiLSTM classification: %s (confidence=%.1f%%) | probs=%s",
        exercise,
        confidence * 100,
        {_classes[i]: f"{float(probs[i]):.2f}" for i in range(len(_classes))},
    )

    # Physics sanity check — catches domain-gap errors from synthetic training data
    valid, reason = _physics_check(exercise, feats)
    if not valid:
        logger.warning("Physics check failed: %s — falling back to rule-based", reason)
        from app.analysis.rule_based import detect_exercise_type
        rule_result = detect_exercise_type(pose_frames)
        logger.info("Rule-based override: %s", rule_result)
        return rule_result

    if confidence < 0.40:
        logger.warning(
            "Low-confidence BiLSTM prediction (%.1f%%) — falling back to rule-based",
            confidence * 100,
        )
        from app.analysis.rule_based import detect_exercise_type
        return detect_exercise_type(pose_frames)

    return exercise


def run_analysis(pose_frames: list[PoseFrame], fps: float) -> list[ExerciseResult]:
    """
    Classify exercise type via BiLSTM (with physics validation), then delegate
    to the appropriate rule-based analyser for rep-counting and form scoring.

    For new/dynamic exercise classes not in ANALYSERS, returns a minimal result
    with the correct classification but rep_count=0 (no domain-specific analyser).
    """
    logger.info("Classifying exercise from %d pose frames (BiLSTM)...", len(pose_frames))
    exercise_type = classify_exercise(pose_frames)
    logger.info("Final classification: %s", exercise_type)

    analyser = ANALYSERS.get(exercise_type)
    if analyser is None:
        logger.info(
            "No rule-based analyser for '%s' (dynamic class) — returning minimal result",
            exercise_type,
        )
        return [_minimal_result(exercise_type, pose_frames, fps)]

    result = analyser.analyse(pose_frames, fps)
    logger.info(
        "Analyser result | reps=%d correct=%d form_score=%.1f duration=%.1fs errors=%s",
        result.rep_count, result.correct_reps, result.form_score, result.duration_s,
        [e.error_type for e in result.posture_errors],
    )
    return [result]
