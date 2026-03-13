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
"""

import logging
import os
from typing import Optional

import numpy as np
import torch

from app.cv.pose_detector import PoseFrame
from app.analysis.base import ExerciseResult
from app.analysis.features import extract_sequence_features
from app.analysis.bilstm_model import ExerciseBiLSTM, CLASSES
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

# Module-level model cache (loaded once, reused for every request)
_model: Optional[ExerciseBiLSTM] = None
_device: torch.device = torch.device("cpu")


def preload_model() -> None:
    """
    Load the BiLSTM weights into memory.
    Call this at application startup to avoid latency on the first request.
    """
    global _model, _device
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
    model = ExerciseBiLSTM()
    model.load_state_dict(torch.load(WEIGHTS_PATH, map_location=_device, weights_only=True))
    model.eval()
    model.to(_device)
    _model = model
    logger.info("BiLSTM classifier loaded from %s (device=%s)", WEIGHTS_PATH, _device)


def _physics_check(bilstm_pred: str, feats: np.ndarray) -> tuple[bool, str]:
    """
    Validate a BiLSTM prediction against hard motion-physics constraints.

    Real MediaPipe 2D projections differ from idealized synthetic angles:
    - Front-view squat knee angle at bottom ~130–140° (not ~80°)
    - Jumping jack knees stay nearly straight throughout (>155°)

    Feature indices (all normalised by /180 or in [0,1]):
      0  left_knee_angle    2  left_elbow_angle
      1  right_knee_angle   3  right_elbow_angle
      8  arm_spread        13  wrist_rel_hip

    Returns (is_valid, reason_if_invalid).
    """
    # Feature stats across the sequence
    f_min  = feats.min(axis=0)   # (14,)
    f_max  = feats.max(axis=0)   # (14,)
    f_range = f_max - f_min      # (14,)

    knee_range   = float(max(f_range[0], f_range[1]))   # max of left/right
    elbow_range  = float(max(f_range[2], f_range[3]))
    knee_min     = float(min(f_min[0], f_min[1]))       # smallest (most bent) knee angle
    wrist_max    = float(f_max[13])                     # highest wrist above hip

    logger.info(
        "Physics features | knee_min=%.3f(%.0f°) knee_range=%.3f(%.0f°) "
        "elbow_range=%.3f(%.0f°) wrist_max=%.3f",
        knee_min, knee_min * 180, knee_range, knee_range * 180,
        elbow_range, elbow_range * 180, wrist_max,
    )

    if bilstm_pred == "jumping_jack":
        # JJ: legs stay nearly straight. If knees bend > 18° range OR
        # minimum knee angle < 153°, this is NOT a jumping jack.
        if knee_range > 0.10 or knee_min < 0.85:
            return False, (
                f"jumping_jack rejected: knee_range={knee_range:.3f}({knee_range*180:.0f}°) "
                f"knee_min={knee_min:.3f}({knee_min*180:.0f}°) — knees bent too much for JJ"
            )
        # JJ: wrists must reach above hips at some point (arms go overhead)
        if wrist_max < 0.10:
            return False, (
                f"jumping_jack rejected: wrist_max={wrist_max:.3f} — wrists never reach above hips"
            )

    elif bilstm_pred == "plank":
        # Plank: almost no motion at all
        if knee_range > 0.15 or elbow_range > 0.20:
            return False, (
                f"plank rejected: knee_range={knee_range:.3f}({knee_range*180:.0f}°) "
                f"elbow_range={elbow_range:.3f}({elbow_range*180:.0f}°) — too much motion for plank"
            )

    elif bilstm_pred == "bicep_curl":
        # Bicep curl: elbows must flex significantly
        if elbow_range < 0.15:
            return False, (
                f"bicep_curl rejected: elbow_range={elbow_range:.3f}({elbow_range*180:.0f}°) — not enough elbow flex"
            )
        # Bicep curl: knees should barely move
        if knee_range > 0.15:
            return False, (
                f"bicep_curl rejected: knee_range={knee_range:.3f}({knee_range*180:.0f}°) — too much knee movement"
            )

    return True, ""


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
    feats = extract_sequence_features(detected)          # (T, 14)
    x = torch.from_numpy(feats).unsqueeze(0).to(_device) # (1, T, 14)

    with torch.no_grad():
        logits = _model(x)                                # (1, 5)
        probs  = torch.softmax(logits, dim=1)[0]
        pred   = int(logits.argmax(dim=1).item())

    exercise   = CLASSES[pred]
    confidence = float(probs[pred])
    logger.info(
        "BiLSTM classification: %s (confidence=%.1f%%) | probs=%s",
        exercise,
        confidence * 100,
        {CLASSES[i]: f"{float(probs[i]):.2f}" for i in range(len(CLASSES))},
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

    Returns a list of ExerciseResult (one entry per detected exercise set).
    """
    logger.info("Classifying exercise from %d pose frames (BiLSTM)...", len(pose_frames))
    exercise_type = classify_exercise(pose_frames)
    logger.info("Final classification: %s", exercise_type)

    analyser = ANALYSERS[exercise_type]
    result = analyser.analyse(pose_frames, fps)
    logger.info(
        "Analyser result | reps=%d correct=%d form_score=%.1f duration=%.1fs errors=%s",
        result.rep_count, result.correct_reps, result.form_score, result.duration_s,
        [e.error_type for e in result.posture_errors],
    )
    return [result]
