"""
Train the BiLSTM exercise classifier using synthetic data.

Run from the repo root:
    python -m app.analysis.train_bilstm

Or from the backend/ directory:
    python -m app.analysis.train_bilstm

Saves weights to:
    backend/app/analysis/weights/bilstm_classifier.pt
"""

import os
import math
import logging
import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset, random_split

from app.analysis.bilstm_model import ExerciseBiLSTM, CLASSES, NUM_CLASSES, NUM_FEATURES

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

WEIGHTS_DIR = os.path.join(os.path.dirname(__file__), "weights")
WEIGHTS_PATH = os.path.join(WEIGHTS_DIR, "bilstm_classifier.pt")

# Training hyper-parameters
SEQ_LEN       = 60      # frames (~2 s at 30 fps)
SAMPLES_PER_CLASS = 300
BATCH_SIZE    = 32
EPOCHS        = 60
LR            = 1e-3
NOISE_STD     = 0.02

# ── Synthetic motion templates ────────────────────────────────────────────────
# Feature indices (see features.py):
#  0 l_knee  1 r_knee  2 l_elbow  3 r_elbow  4 l_hip  5 r_hip
#  6 l_sho   7 r_sho   8 arm_spread  9 hip_spread
# 10 l_hip_h 11 r_hip_h 12 torso_incl  13 wrist_rel_hip


def _sin_cycle(t: np.ndarray, lo: float, hi: float, cycles: float) -> np.ndarray:
    """Oscillate between lo and hi, completing `cycles` full cycles over [0,1] t."""
    return lo + (hi - lo) * 0.5 * (1 - np.cos(2 * math.pi * cycles * t))


def _generate_squat(seq_len: int) -> np.ndarray:
    t = np.linspace(0, 1, seq_len)
    x = np.zeros((seq_len, NUM_FEATURES), dtype=np.float32)
    reps = np.random.uniform(3, 6)
    depth = np.random.uniform(0.40, 0.55)   # knee angle at bottom / 180
    # Realistic 2D front-view knee angles: bottom of squat ~130–145° (not ~80°).
    # From the FRONT, the knee appears less bent because depth axis is collapsed.
    # depth = 0.40 → 0.55 normalized = 72° → 99° which is too extreme for 2D
    # Realistic 2D range: ~0.72–0.94 (130°–170°)
    knee_bottom = np.random.uniform(0.72, 0.82)  # bottom: 130–148°
    x[:, 0] = _sin_cycle(t, knee_bottom, 0.94, reps)
    x[:, 1] = _sin_cycle(t, knee_bottom, 0.94, reps)
    # elbows mostly straight (arms forward for balance)
    x[:, 2] = _sin_cycle(t, 0.82, 0.96, reps)
    x[:, 3] = _sin_cycle(t, 0.82, 0.96, reps)
    # hip angle opens/closes with squat
    x[:, 4] = _sin_cycle(t, 0.52, 0.80, reps)
    x[:, 5] = _sin_cycle(t, 0.52, 0.80, reps)
    # shoulder angle relatively stable
    x[:, 6] = np.full(seq_len, 0.72)
    x[:, 7] = np.full(seq_len, 0.72)
    # arm spread moderate (arms forward / wide for balance)
    x[:, 8] = np.full(seq_len, np.random.uniform(0.30, 0.50))
    x[:, 9] = np.full(seq_len, np.random.uniform(0.15, 0.25))
    # hips drop during squat
    x[:, 10] = _sin_cycle(t, 0.54, 0.66, reps)
    x[:, 11] = _sin_cycle(t, 0.54, 0.66, reps)
    x[:, 12] = _sin_cycle(t, 0.05, 0.20, reps)   # slight torso lean
    # Wrists stay low (at hip or chest level, NOT overhead — key vs jumping_jack)
    x[:, 13] = _sin_cycle(t, -0.30, 0.05, reps)  # never goes high above hip
    return x


def _generate_jumping_jack(seq_len: int) -> np.ndarray:
    t = np.linspace(0, 1, seq_len)
    x = np.zeros((seq_len, NUM_FEATURES), dtype=np.float32)
    reps = np.random.uniform(4, 8)
    # Legs stay nearly STRAIGHT — this is the key discriminator vs squat.
    # Tight knee range: 0.94–0.97 = 0.03 range.
    # Even at noise_std=0.02, max-min inflation ≈ 0.04 → total ≤ 0.07 < physics threshold 0.10.
    x[:, 0] = _sin_cycle(t, 0.94, 0.97, reps)   # 169–175°, very small range
    x[:, 1] = _sin_cycle(t, 0.94, 0.97, reps)
    # Arms swing overhead — elbow angle cycles
    arm_phase = _sin_cycle(t, 0.62, 0.96, reps)
    x[:, 2] = arm_phase
    x[:, 3] = arm_phase
    # hip angle minimal change
    x[:, 4] = np.full(seq_len, 0.87)
    x[:, 5] = np.full(seq_len, 0.87)
    # shoulder angle changes a lot (arms raise overhead)
    x[:, 6] = _sin_cycle(t, 0.18, 0.82, reps)
    x[:, 7] = _sin_cycle(t, 0.18, 0.82, reps)
    # arm spread: feet/arms go wide but shoulder x-spread is moderate
    x[:, 8] = _sin_cycle(t, 0.12, 0.55, reps)
    # hip spread stays stable
    x[:, 9] = np.full(seq_len, 0.18)
    x[:, 10] = np.full(seq_len, 0.54)
    x[:, 11] = np.full(seq_len, 0.54)
    x[:, 12] = np.full(seq_len, 0.03)   # upright torso
    # KEY: wrists go WELL ABOVE hips when arms raise overhead.
    # wrist_rel_hip = hip_y - wrist_y; positive = wrist above hip.
    # At top of JJ with arms overhead: wrist near top of frame (~0.1),
    # hip at ~0.55 → wrist_rel_hip ≈ 0.45
    x[:, 13] = _sin_cycle(t, -0.35, 0.45, reps)  # large positive peak = overhead
    return x


def _generate_bicep_curl(seq_len: int) -> np.ndarray:
    t = np.linspace(0, 1, seq_len)
    x = np.zeros((seq_len, NUM_FEATURES), dtype=np.float32)
    reps = np.random.uniform(4, 8)
    # knees nearly straight, minimal range
    x[:, 0] = np.full(seq_len, np.random.uniform(0.90, 0.97))
    x[:, 1] = np.full(seq_len, np.random.uniform(0.90, 0.97))
    # elbows cycle a lot: 170° → 40°
    curl_lo = np.random.uniform(0.22, 0.32)
    x[:, 2] = _sin_cycle(t, curl_lo, 0.94, reps)
    x[:, 3] = _sin_cycle(t, curl_lo, 0.94, reps)
    # hip angle stable
    x[:, 4] = np.full(seq_len, 0.90)
    x[:, 5] = np.full(seq_len, 0.90)
    # shoulder stable
    x[:, 6] = np.full(seq_len, 0.75)
    x[:, 7] = np.full(seq_len, 0.75)
    # arm spread narrow (arms hang at sides)
    x[:, 8] = np.full(seq_len, np.random.uniform(0.18, 0.28))
    x[:, 9] = np.full(seq_len, 0.16)
    # hip height stable
    x[:, 10] = np.full(seq_len, 0.54)
    x[:, 11] = np.full(seq_len, 0.54)
    x[:, 12] = np.full(seq_len, 0.04)
    # wrist cycles up to shoulder level
    x[:, 13] = _sin_cycle(t, -0.30, 0.05, reps)
    return x


def _generate_lunge(seq_len: int) -> np.ndarray:
    t = np.linspace(0, 1, seq_len)
    x = np.zeros((seq_len, NUM_FEATURES), dtype=np.float32)
    reps = np.random.uniform(3, 6)
    lunge_depth = np.random.uniform(0.70, 0.80)   # realistic 2D front-view: 126–144°
    # KEY: ASYMMETRIC legs — front knee bends, rear knee stays stable
    x[:, 0] = _sin_cycle(t, lunge_depth, 0.93, reps)           # front knee cycles
    x[:, 1] = np.full(seq_len, np.random.uniform(0.72, 0.82))  # rear knee: barely moves
    # elbows relatively straight (hands on hips or by side)
    x[:, 2] = np.full(seq_len, np.random.uniform(0.86, 0.94))
    x[:, 3] = np.full(seq_len, np.random.uniform(0.86, 0.94))
    # hip angle: front side cycles, rear side stays open — asymmetric
    x[:, 4] = _sin_cycle(t, 0.38, 0.75, reps)                  # front hip angle varies
    x[:, 5] = np.full(seq_len, np.random.uniform(0.82, 0.90))  # rear hip stable/open
    # shoulder angle stable
    x[:, 6] = np.full(seq_len, 0.72)
    x[:, 7] = np.full(seq_len, 0.72)
    # arm spread narrow (hands at sides, not forward like squat)
    x[:, 8] = np.full(seq_len, np.random.uniform(0.18, 0.28))
    # hip spread wider (one leg forward, one back) — key vs squat
    x[:, 9] = np.full(seq_len, np.random.uniform(0.28, 0.42))
    # hip drops on lunge side only — so left/right differ
    x[:, 10] = _sin_cycle(t, 0.56, 0.70, reps)                 # front hip drops
    x[:, 11] = np.full(seq_len, np.random.uniform(0.52, 0.58)) # rear hip stable
    x[:, 12] = _sin_cycle(t, 0.04, 0.14, reps)                 # slight torso lean
    x[:, 13] = np.full(seq_len, np.random.uniform(-0.38, -0.22))
    return x


def _generate_plank(seq_len: int) -> np.ndarray:
    t = np.linspace(0, 1, seq_len)
    x = np.zeros((seq_len, NUM_FEATURES), dtype=np.float32)
    # plank: minimal motion — body horizontal, knees straight
    x[:, 0] = np.full(seq_len, np.random.uniform(0.88, 0.97))
    x[:, 1] = np.full(seq_len, np.random.uniform(0.88, 0.97))
    # elbow at ~90° (forearm plank) or straight (~170° for high plank)
    elbow_angle = np.random.choice([0.50, 0.94])
    x[:, 2] = np.full(seq_len, elbow_angle + np.random.uniform(-0.02, 0.02))
    x[:, 3] = np.full(seq_len, elbow_angle + np.random.uniform(-0.02, 0.02))
    # hip angle: torso nearly horizontal → ~180°
    x[:, 4] = np.full(seq_len, np.random.uniform(0.88, 0.96))
    x[:, 5] = np.full(seq_len, np.random.uniform(0.88, 0.96))
    x[:, 6] = np.full(seq_len, 0.50)
    x[:, 7] = np.full(seq_len, 0.50)
    x[:, 8] = np.full(seq_len, np.random.uniform(0.28, 0.40))
    x[:, 9] = np.full(seq_len, 0.16)
    # hip height is low and STABLE (key discriminator from squat)
    hip_y = np.random.uniform(0.55, 0.65)
    micro_drift = np.random.uniform(-0.005, 0.005, seq_len).astype(np.float32)
    x[:, 10] = hip_y + micro_drift
    x[:, 11] = hip_y + micro_drift
    # torso nearly horizontal
    x[:, 12] = np.full(seq_len, np.random.uniform(0.45, 0.60))
    x[:, 13] = np.full(seq_len, np.random.uniform(-0.50, -0.20))
    return x


_GENERATORS = [
    _generate_squat,
    _generate_jumping_jack,
    _generate_bicep_curl,
    _generate_lunge,
    _generate_plank,
]


def generate_synthetic_dataset(
    samples_per_class: int = SAMPLES_PER_CLASS,
    seq_len: int = SEQ_LEN,
    noise_std: float = NOISE_STD,
) -> tuple[np.ndarray, np.ndarray]:
    """
    Returns (X, y):
      X shape: (N, seq_len, NUM_FEATURES)
      y shape: (N,)  — integer class labels
    """
    X_parts, y_parts = [], []
    for class_idx, gen_fn in enumerate(_GENERATORS):
        seqs = []
        for _ in range(samples_per_class):
            seq = gen_fn(seq_len)
            seq += np.random.normal(0, noise_std, seq.shape).astype(np.float32)
            seq = np.clip(seq, 0.0, 1.0)
            seqs.append(seq)
        X_parts.append(np.stack(seqs, axis=0))
        y_parts.append(np.full(samples_per_class, class_idx, dtype=np.int64))
    return np.concatenate(X_parts, axis=0), np.concatenate(y_parts, axis=0)


def train(
    samples_per_class: int = SAMPLES_PER_CLASS,
    seq_len: int = SEQ_LEN,
    batch_size: int = BATCH_SIZE,
    epochs: int = EPOCHS,
    lr: float = LR,
) -> None:
    os.makedirs(WEIGHTS_DIR, exist_ok=True)

    logger.info("Generating synthetic training data (%d samples/class × %d classes)...",
                samples_per_class, NUM_CLASSES)
    X_np, y_np = generate_synthetic_dataset(samples_per_class, seq_len)
    logger.info("Dataset shape: X=%s  y=%s", X_np.shape, y_np.shape)

    X = torch.from_numpy(X_np)
    y = torch.from_numpy(y_np)

    dataset = TensorDataset(X, y)
    n_val = max(1, int(0.15 * len(dataset)))
    n_train = len(dataset) - n_val
    train_ds, val_ds = random_split(dataset, [n_train, n_val],
                                    generator=torch.Generator().manual_seed(42))

    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True)
    val_loader   = DataLoader(val_ds,   batch_size=batch_size)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    logger.info("Training on %s", device)

    model = ExerciseBiLSTM().to(device)
    criterion = nn.CrossEntropyLoss()
    optimiser = torch.optim.Adam(model.parameters(), lr=lr)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimiser, T_max=epochs, eta_min=1e-5)

    best_val_acc = 0.0
    for epoch in range(1, epochs + 1):
        model.train()
        total_loss = 0.0
        for xb, yb in train_loader:
            xb, yb = xb.to(device), yb.to(device)
            optimiser.zero_grad()
            logits = model(xb)
            loss = criterion(logits, yb)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimiser.step()
            total_loss += loss.item() * len(xb)
        scheduler.step()

        if epoch % 10 == 0 or epoch == epochs:
            model.eval()
            correct = total = 0
            with torch.no_grad():
                for xb, yb in val_loader:
                    xb, yb = xb.to(device), yb.to(device)
                    preds = model(xb).argmax(dim=1)
                    correct += (preds == yb).sum().item()
                    total += len(yb)
            val_acc = correct / total * 100
            logger.info(
                "Epoch %3d/%d | train_loss=%.4f | val_acc=%.1f%%",
                epoch, epochs, total_loss / n_train, val_acc,
            )
            if val_acc > best_val_acc:
                best_val_acc = val_acc
                torch.save(model.state_dict(), WEIGHTS_PATH)
                logger.info("  ✓ Saved best weights (val_acc=%.1f%%)", val_acc)

    logger.info("Training complete. Best val accuracy: %.1f%%", best_val_acc)
    logger.info("Weights saved to: %s", WEIGHTS_PATH)


if __name__ == "__main__":
    train()
