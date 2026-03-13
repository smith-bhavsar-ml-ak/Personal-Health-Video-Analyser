"""
Tests for ExerciseBiLSTM model architecture and weight loading.

No PoseFrames or feature extraction needed — tests operate at the tensor level.
"""

import pytest
import torch
import torch.nn as nn

from app.analysis.bilstm_model import ExerciseBiLSTM, CLASSES, NUM_FEATURES, NUM_CLASSES


# ── Architecture tests (no weights needed) ────────────────────────────────────

def test_output_shape_standard():
    model = ExerciseBiLSTM()
    model.eval()
    x = torch.randn(1, 60, NUM_FEATURES)
    with torch.no_grad():
        out = model(x)
    assert out.shape == (1, NUM_CLASSES), f"Expected (1, {NUM_CLASSES}), got {out.shape}"


@pytest.mark.parametrize("seq_len", [15, 30, 60, 120])
def test_output_shape_variable_seqlen(seq_len):
    """BiLSTM + mean-pool handles any sequence length."""
    model = ExerciseBiLSTM()
    model.eval()
    x = torch.randn(1, seq_len, NUM_FEATURES)
    with torch.no_grad():
        out = model(x)
    assert out.shape == (1, NUM_CLASSES)


def test_output_is_logits_not_probs():
    """forward() must return raw logits, not softmax probabilities."""
    model = ExerciseBiLSTM()
    model.eval()
    x = torch.randn(4, 60, NUM_FEATURES)
    with torch.no_grad():
        out = model(x)
    row_sums = out.sum(dim=1)
    # If softmax were applied, all row sums would equal 1.0
    assert not torch.allclose(row_sums, torch.ones(4), atol=1e-3), \
        "Output looks like probabilities (sums to 1) — forward() should return logits"


def test_batch_inference():
    model = ExerciseBiLSTM()
    model.eval()
    x = torch.randn(32, 60, NUM_FEATURES)
    with torch.no_grad():
        out = model(x)
    assert out.shape == (32, NUM_CLASSES)
    assert torch.isfinite(out).all(), "Output contains NaN or Inf"


def test_eval_mode_deterministic():
    """In eval mode, dropout is off — same input must produce same output."""
    model = ExerciseBiLSTM()
    model.eval()
    x = torch.randn(1, 60, NUM_FEATURES)
    with torch.no_grad():
        out1 = model(x)
        out2 = model(x)
    assert torch.allclose(out1, out2), "eval() mode output is not deterministic"


def test_train_mode_stochastic():
    """In train mode, dropout is active — same input should produce different outputs."""
    torch.manual_seed(0)
    model = ExerciseBiLSTM()
    model.train()
    x = torch.randn(1, 60, NUM_FEATURES)
    # Run multiple times; at least one pair should differ due to dropout
    outputs = [model(x).detach() for _ in range(10)]
    all_same = all(torch.allclose(outputs[0], o) for o in outputs[1:])
    assert not all_same, "train() mode output is always identical — dropout may be disabled"


def test_parameter_count():
    """Total parameter count should match the expected architecture."""
    model = ExerciseBiLSTM()
    total = sum(p.numel() for p in model.parameters())
    # BiLSTM(in=14, hidden=128, layers=2, bidir=True) + FC(256→128→5)
    # Rough expected range; assert it's within ±20% of a known-good count
    assert 400_000 < total < 900_000, \
        f"Unexpected parameter count: {total:,} — architecture may have changed"


# ── Weight-loading tests (require trained weights) ────────────────────────────

def test_weights_load(loaded_model):
    assert loaded_model is not None
    assert isinstance(loaded_model, ExerciseBiLSTM)
    # Should be in eval mode after preload_model()
    assert not loaded_model.training, "Model should be in eval() mode after loading"


def test_trained_model_finite_output(loaded_model, make_synthetic_tensor):
    x = make_synthetic_tensor("squat")  # (1, 60, 14)
    with torch.no_grad():
        out = loaded_model(x)
    assert torch.isfinite(out).all()
    pred = out.argmax(dim=1).item()
    assert 0 <= pred < NUM_CLASSES, f"Prediction {pred} out of class range"


def test_trained_model_all_classes_reachable(loaded_model, make_synthetic_tensor):
    """
    Each class should be the top BiLSTM prediction for at least one deterministic sample.
    Tests across 3 seeds per class to avoid lucky failures.
    """
    predicted = set()
    for cls in CLASSES:
        for seed in range(3):
            x = make_synthetic_tensor(cls, seed=seed)
            with torch.no_grad():
                pred = loaded_model(x).argmax(dim=1).item()
            predicted.add(pred)
    assert len(predicted) == NUM_CLASSES, \
        f"Only {len(predicted)}/{NUM_CLASSES} classes were ever the top prediction: {predicted}"
