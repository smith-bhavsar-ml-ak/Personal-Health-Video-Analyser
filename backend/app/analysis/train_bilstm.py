"""
Train the BiLSTM exercise classifier.

Modes:
  synthetic (default) — train on generated synthetic data only
  real                — train on real sequences extracted by preprocess_real_data.py
  mixed               — real + synthetic fill (min 200/class)

Run from the backend/ directory:
    python -m app.analysis.train_bilstm                        # synthetic
    python -m app.analysis.train_bilstm --mode real --real-data-dir data/real/sequences
    python -m app.analysis.train_bilstm --mode mixed --real-data-dir data/real/sequences

Saves weights to:
    backend/app/analysis/weights/bilstm_classifier.pt

Weights format (new): {'state_dict': ..., 'classes': [...]}
  — class list is embedded so adding new exercises requires only retraining.
"""

import argparse
import os
import math
import logging
from pathlib import Path

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
SEQ_LEN           = 60      # frames (~2 s at 30 fps)
SAMPLES_PER_CLASS = 500     # increased from 300 — augmented samples are more diverse
BATCH_SIZE        = 32
EPOCHS            = 60
LR                = 1e-3
NOISE_STD         = 0.02

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
    # Realistic 2D front-view knee angles: bottom of squat ~130–148°
    knee_bottom = np.random.uniform(0.72, 0.82)
    x[:, 0] = _sin_cycle(t, knee_bottom, 0.94, reps)
    x[:, 1] = _sin_cycle(t, knee_bottom, 0.94, reps)
    x[:, 2] = _sin_cycle(t, 0.82, 0.96, reps)
    x[:, 3] = _sin_cycle(t, 0.82, 0.96, reps)
    x[:, 4] = _sin_cycle(t, 0.52, 0.80, reps)
    x[:, 5] = _sin_cycle(t, 0.52, 0.80, reps)
    x[:, 6] = np.full(seq_len, 0.72)
    x[:, 7] = np.full(seq_len, 0.72)
    x[:, 8] = np.full(seq_len, np.random.uniform(0.30, 0.50))
    x[:, 9] = np.full(seq_len, np.random.uniform(0.15, 0.25))
    x[:, 10] = _sin_cycle(t, 0.54, 0.66, reps)
    x[:, 11] = _sin_cycle(t, 0.54, 0.66, reps)
    x[:, 12] = _sin_cycle(t, 0.05, 0.20, reps)
    x[:, 13] = _sin_cycle(t, -0.30, 0.05, reps)
    return x


def _generate_jumping_jack(seq_len: int) -> np.ndarray:
    t = np.linspace(0, 1, seq_len)
    x = np.zeros((seq_len, NUM_FEATURES), dtype=np.float32)
    reps = np.random.uniform(4, 8)
    x[:, 0] = _sin_cycle(t, 0.94, 0.97, reps)
    x[:, 1] = _sin_cycle(t, 0.94, 0.97, reps)
    arm_phase = _sin_cycle(t, 0.62, 0.96, reps)
    x[:, 2] = arm_phase
    x[:, 3] = arm_phase
    x[:, 4] = np.full(seq_len, 0.87)
    x[:, 5] = np.full(seq_len, 0.87)
    x[:, 6] = _sin_cycle(t, 0.18, 0.82, reps)
    x[:, 7] = _sin_cycle(t, 0.18, 0.82, reps)
    x[:, 8] = _sin_cycle(t, 0.12, 0.55, reps)
    x[:, 9] = np.full(seq_len, 0.18)
    x[:, 10] = np.full(seq_len, 0.54)
    x[:, 11] = np.full(seq_len, 0.54)
    x[:, 12] = np.full(seq_len, 0.03)
    x[:, 13] = _sin_cycle(t, -0.35, 0.45, reps)
    return x


def _generate_bicep_curl(seq_len: int) -> np.ndarray:
    t = np.linspace(0, 1, seq_len)
    x = np.zeros((seq_len, NUM_FEATURES), dtype=np.float32)
    reps = np.random.uniform(4, 8)
    x[:, 0] = np.full(seq_len, np.random.uniform(0.90, 0.97))
    x[:, 1] = np.full(seq_len, np.random.uniform(0.90, 0.97))
    curl_lo = np.random.uniform(0.22, 0.32)
    x[:, 2] = _sin_cycle(t, curl_lo, 0.94, reps)
    x[:, 3] = _sin_cycle(t, curl_lo, 0.94, reps)
    x[:, 4] = np.full(seq_len, 0.90)
    x[:, 5] = np.full(seq_len, 0.90)
    x[:, 6] = np.full(seq_len, 0.75)
    x[:, 7] = np.full(seq_len, 0.75)
    x[:, 8] = np.full(seq_len, np.random.uniform(0.18, 0.28))
    x[:, 9] = np.full(seq_len, 0.16)
    x[:, 10] = np.full(seq_len, 0.54)
    x[:, 11] = np.full(seq_len, 0.54)
    x[:, 12] = np.full(seq_len, 0.04)
    x[:, 13] = _sin_cycle(t, -0.30, 0.05, reps)
    return x


def _generate_lunge(seq_len: int) -> np.ndarray:
    t = np.linspace(0, 1, seq_len)
    x = np.zeros((seq_len, NUM_FEATURES), dtype=np.float32)
    reps = np.random.uniform(3, 6)
    lunge_depth = np.random.uniform(0.70, 0.80)
    x[:, 0] = _sin_cycle(t, lunge_depth, 0.93, reps)
    x[:, 1] = np.full(seq_len, np.random.uniform(0.72, 0.82))
    x[:, 2] = np.full(seq_len, np.random.uniform(0.86, 0.94))
    x[:, 3] = np.full(seq_len, np.random.uniform(0.86, 0.94))
    x[:, 4] = _sin_cycle(t, 0.38, 0.75, reps)
    x[:, 5] = np.full(seq_len, np.random.uniform(0.82, 0.90))
    x[:, 6] = np.full(seq_len, 0.72)
    x[:, 7] = np.full(seq_len, 0.72)
    x[:, 8] = np.full(seq_len, np.random.uniform(0.18, 0.28))
    x[:, 9] = np.full(seq_len, np.random.uniform(0.28, 0.42))
    x[:, 10] = _sin_cycle(t, 0.56, 0.70, reps)
    x[:, 11] = np.full(seq_len, np.random.uniform(0.52, 0.58))
    x[:, 12] = _sin_cycle(t, 0.04, 0.14, reps)
    x[:, 13] = np.full(seq_len, np.random.uniform(-0.38, -0.22))
    return x


def _generate_plank(seq_len: int) -> np.ndarray:
    t = np.linspace(0, 1, seq_len)
    x = np.zeros((seq_len, NUM_FEATURES), dtype=np.float32)
    x[:, 0] = np.full(seq_len, np.random.uniform(0.88, 0.97))
    x[:, 1] = np.full(seq_len, np.random.uniform(0.88, 0.97))
    elbow_angle = np.random.choice([0.50, 0.94])
    x[:, 2] = np.full(seq_len, elbow_angle + np.random.uniform(-0.02, 0.02))
    x[:, 3] = np.full(seq_len, elbow_angle + np.random.uniform(-0.02, 0.02))
    x[:, 4] = np.full(seq_len, np.random.uniform(0.88, 0.96))
    x[:, 5] = np.full(seq_len, np.random.uniform(0.88, 0.96))
    x[:, 6] = np.full(seq_len, 0.50)
    x[:, 7] = np.full(seq_len, 0.50)
    x[:, 8] = np.full(seq_len, np.random.uniform(0.28, 0.40))
    x[:, 9] = np.full(seq_len, 0.16)
    hip_y = np.random.uniform(0.55, 0.65)
    micro_drift = np.random.uniform(-0.005, 0.005, seq_len).astype(np.float32)
    x[:, 10] = hip_y + micro_drift
    x[:, 11] = hip_y + micro_drift
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

# Left/right feature index pairs for mirror augmentation
_LR_PAIRS = [(0, 1), (2, 3), (4, 5), (6, 7), (10, 11)]


def _augment_sequence(seq: np.ndarray) -> np.ndarray:
    """
    Apply random domain-randomization transforms to a (T, 14) feature sequence.

    These augmentations close the domain gap between synthetic sine-wave data and
    real MediaPipe output by simulating the kinds of variation seen in real video:
    - different body laterality (mirror)
    - different rep speeds (time warp)
    - sequences captured mid-rep (phase offset)
    - partial occlusion (feature dropout)
    """
    seq = seq.copy()
    T = seq.shape[0]

    # 1. Mirror / left-right flip (50% chance)
    #    Swaps L/R feature pairs: knee, elbow, hip, shoulder, hip_y
    if np.random.random() < 0.5:
        for l, r in _LR_PAIRS:
            seq[:, l], seq[:, r] = seq[:, r].copy(), seq[:, l].copy()

    # 2. Time warp — resample to random speed then interpolate back to T
    #    Simulates fast vs. slow reps and camera FPS variation (±30%)
    warp = np.random.uniform(0.7, 1.4)
    new_T = max(30, int(T * warp))
    orig_t = np.linspace(0, 1, T)
    new_t  = np.linspace(0, 1, new_T)
    # Step 1: stretch/compress original T-point signal to new_T
    warped = np.stack(
        [np.interp(new_t, orig_t, seq[:, i]) for i in range(NUM_FEATURES)], axis=1
    )
    # Step 2: resample warped new_T-point signal back to T for model input
    seq = np.stack(
        [np.interp(orig_t, new_t, warped[:, i]) for i in range(NUM_FEATURES)], axis=1
    ).astype(np.float32)

    # 3. Temporal phase offset — roll sequence so it starts mid-rep
    offset = np.random.randint(0, max(1, T // 4))
    seq = np.roll(seq, offset, axis=0)

    # 4. Feature dropout — zero out 1–2 features to simulate occlusion (30% chance)
    if np.random.random() < 0.30:
        n_drop = np.random.randint(1, 3)
        drop_idx = np.random.choice(NUM_FEATURES, n_drop, replace=False)
        seq[:, drop_idx] = 0.5  # 0.5 = neutral (same as undetected-frame default)

    return np.clip(seq, 0.0, 1.0)


def generate_synthetic_dataset(
    samples_per_class: int = SAMPLES_PER_CLASS,
    seq_len: int = SEQ_LEN,
    noise_std: float = NOISE_STD,
    augment: bool = True,
    classes: list[str] | None = None,
    all_classes: list[str] | None = None,
) -> tuple[np.ndarray, np.ndarray]:
    """
    Returns (X, y):
      X shape: (N, seq_len, NUM_FEATURES)
      y shape: (N,)  — integer class labels

    Args:
        augment: apply domain-randomization augmentations (mirror, time-warp, etc.)
        classes: subset of CLASSES to generate synthetic data for (default: all 5)
        all_classes: full class list used for label indices (default: same as classes)
    """
    if classes is None:
        classes = list(CLASSES)
    if all_classes is None:
        all_classes = classes

    X_parts, y_parts = [], []
    for label in classes:
        if label not in CLASSES:
            continue  # no synthetic generator for new exercises
        gen_fn = _GENERATORS[CLASSES.index(label)]
        cls_idx = all_classes.index(label)
        seqs = []
        for _ in range(samples_per_class):
            seq = gen_fn(seq_len)
            seq += np.random.normal(0, noise_std, seq.shape).astype(np.float32)
            seq = np.clip(seq, 0.0, 1.0)
            if augment:
                seq = _augment_sequence(seq)
            seqs.append(seq)
        X_parts.append(np.stack(seqs, axis=0))
        y_parts.append(np.full(samples_per_class, cls_idx, dtype=np.int64))
    return np.concatenate(X_parts, axis=0), np.concatenate(y_parts, axis=0)


def load_real_sequences(sequences_dir: str) -> tuple[np.ndarray, np.ndarray, list[str]]:
    """
    Load labeled .npy sequences saved by preprocess_real_data.py.

    Discovers class labels from filenames ({label}_{index:04d}.npy).
    Returns (X, y, classes) where classes is sorted list of discovered labels.
    """
    seq_dir = Path(sequences_dir)
    # Discover unique class labels from filenames
    label_set = sorted({f.stem.rsplit("_", 1)[0] for f in seq_dir.glob("*.npy")})
    if not label_set:
        raise FileNotFoundError(f"No .npy sequences found in {sequences_dir}")

    logger.info("Discovered classes in %s: %s", sequences_dir, label_set)
    X, y = [], []
    for cls_idx, label in enumerate(label_set):
        files = sorted(seq_dir.glob(f"{label}_*.npy"))
        for f in files:
            seq = np.load(f).astype(np.float32)
            X.append(seq[:SEQ_LEN])   # trim to SEQ_LEN if longer
            y.append(cls_idx)
        logger.info("  %s: %d sequences", label, len(files))

    return np.array(X, dtype=np.float32), np.array(y, dtype=np.int64), label_set


def _run_training(
    X_np: np.ndarray,
    y_np: np.ndarray,
    training_classes: list[str],
    batch_size: int = BATCH_SIZE,
    epochs: int = EPOCHS,
    lr: float = LR,
) -> None:
    """Core training loop — shared by all modes."""
    os.makedirs(WEIGHTS_DIR, exist_ok=True)
    num_classes = len(training_classes)

    logger.info(
        "Dataset shape: X=%s  y=%s  classes=%s",
        X_np.shape, y_np.shape, training_classes,
    )

    X = torch.from_numpy(X_np)
    y = torch.from_numpy(y_np)

    dataset = TensorDataset(X, y)
    n_val = max(1, int(0.15 * len(dataset)))
    n_train = len(dataset) - n_val
    train_ds, val_ds = random_split(
        dataset, [n_train, n_val], generator=torch.Generator().manual_seed(42)
    )

    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True)
    val_loader   = DataLoader(val_ds,   batch_size=batch_size)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    logger.info("Training on %s", device)

    model = ExerciseBiLSTM(num_classes=num_classes).to(device)
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
                torch.save(
                    {"state_dict": model.state_dict(), "classes": training_classes},
                    WEIGHTS_PATH,
                )
                logger.info("  Saved best weights (val_acc=%.1f%%)", val_acc)

    logger.info("Training complete. Best val accuracy: %.1f%%", best_val_acc)
    logger.info("Weights saved to: %s", WEIGHTS_PATH)
    logger.info("Embedded classes: %s", training_classes)


def train(
    mode: str = "synthetic",
    real_data_dir: str = "data/real/sequences",
    samples_per_class: int = SAMPLES_PER_CLASS,
    seq_len: int = SEQ_LEN,
    batch_size: int = BATCH_SIZE,
    epochs: int = EPOCHS,
    lr: float = LR,
) -> None:
    if mode == "synthetic":
        logger.info(
            "Mode: synthetic — generating %d samples/class × %d classes",
            samples_per_class, NUM_CLASSES,
        )
        X_np, y_np = generate_synthetic_dataset(samples_per_class, seq_len)
        training_classes = list(CLASSES)

    elif mode == "real":
        logger.info("Mode: real — loading sequences from %s", real_data_dir)
        X_np, y_np, training_classes = load_real_sequences(real_data_dir)

    elif mode == "mixed":
        logger.info("Mode: mixed — real + synthetic fill from %s", real_data_dir)
        X_real, y_real, training_classes = load_real_sequences(real_data_dir)

        counts = [int(np.sum(y_real == i)) for i in range(len(training_classes))]
        fill = max(50, 200 - min(counts))
        logger.info(
            "Real counts per class: %s — synthetic fill: %d/class",
            dict(zip(training_classes, counts)), fill,
        )

        # Generate synthetic data only for classes that have generators
        synth_classes = [c for c in training_classes if c in CLASSES]
        if synth_classes:
            X_syn, y_syn = generate_synthetic_dataset(
                samples_per_class=fill,
                seq_len=seq_len,
                classes=synth_classes,
                all_classes=training_classes,
            )
            X_np = np.concatenate([X_real, X_syn])
            y_np = np.concatenate([y_real, y_syn])
        else:
            X_np, y_np = X_real, y_real

    else:
        raise ValueError(f"Unknown mode: {mode!r}. Choose synthetic, real, or mixed.")

    _run_training(X_np, y_np, training_classes, batch_size, epochs, lr)


def main() -> None:
    parser = argparse.ArgumentParser(description="Train the BiLSTM exercise classifier")
    parser.add_argument(
        "--mode",
        choices=["synthetic", "real", "mixed"],
        default="synthetic",
        help="Training data mode (default: synthetic)",
    )
    parser.add_argument(
        "--real-data-dir",
        default="data/real/sequences",
        help="Directory containing .npy sequences from preprocess_real_data.py",
    )
    parser.add_argument("--samples-per-class", type=int, default=SAMPLES_PER_CLASS)
    parser.add_argument("--epochs",            type=int, default=EPOCHS)
    parser.add_argument("--batch-size",        type=int, default=BATCH_SIZE)
    parser.add_argument("--lr",                type=float, default=LR)
    args = parser.parse_args()

    train(
        mode=args.mode,
        real_data_dir=args.real_data_dir,
        samples_per_class=args.samples_per_class,
        seq_len=SEQ_LEN,
        batch_size=args.batch_size,
        epochs=args.epochs,
        lr=args.lr,
    )


if __name__ == "__main__":
    main()
