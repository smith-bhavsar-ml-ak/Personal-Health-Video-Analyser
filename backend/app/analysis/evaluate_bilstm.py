"""
Standalone BiLSTM evaluation script.

Generates a comprehensive report covering:
  [1] Model info (params, device)
  [2] Overall accuracy on clean synthetic data
  [3] Per-class metrics + confusion matrix
  [4] Noise robustness curve
  [5] Sequence length sensitivity
  [6] Physics check override rate
  [7] Inference speed (latency + throughput)

Run from backend/ directory:
    python -m app.analysis.evaluate_bilstm

Optional flags:
    --samples N          samples per class (default 200)
    --output PATH        file to write report (default eval_report.txt)
    --noise-levels ...   space-separated floats (default 0.0 0.01 0.02 0.05 0.10)
    --seq-lengths ...    space-separated ints   (default 15 30 60 120)
"""

import argparse
import os
import sys
import time
import numpy as np
import torch

# ── Bootstrap imports ─────────────────────────────────────────────────────────

from app.analysis.bilstm_model import ExerciseBiLSTM, CLASSES, NUM_CLASSES, NUM_FEATURES
from app.analysis.bilstm_analyser import preload_model, _physics_check, WEIGHTS_PATH
import app.analysis.bilstm_analyser as _mod
from app.analysis.train_bilstm import generate_synthetic_dataset, _GENERATORS, SEQ_LEN


# ── Tee: write to stdout and file simultaneously ──────────────────────────────

class _Tee:
    def __init__(self, path: str):
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        self._file = open(path, "w", encoding="utf-8")

    def write(self, text: str):
        print(text, end="")
        self._file.write(text)

    def line(self, text: str = ""):
        self.write(text + "\n")

    def close(self):
        self._file.close()


# ── Inference helper ──────────────────────────────────────────────────────────

@torch.no_grad()
def _run_inference(model, X_np: np.ndarray, batch_size: int = 64):
    """
    Run forward passes on (N, T, F) numpy array.
    Returns predicted class indices (N,) and raw probs (N, C).
    """
    N = X_np.shape[0]
    preds, probs_list = [], []
    for start in range(0, N, batch_size):
        batch = torch.from_numpy(X_np[start:start + batch_size])
        logits = model(batch)
        p = torch.softmax(logits, dim=1)
        preds.append(logits.argmax(dim=1).cpu().numpy())
        probs_list.append(p.cpu().numpy())
    return np.concatenate(preds), np.concatenate(probs_list, axis=0)


# ── Report sections ───────────────────────────────────────────────────────────

def _section_model_info(out: _Tee, model: ExerciseBiLSTM) -> None:
    total = sum(p.numel() for p in model.parameters())
    device = next(model.parameters()).device
    out.line("=" * 60)
    out.line("  BiLSTM Exercise Classifier — Evaluation Report")
    out.line("=" * 60)
    out.line(f"  Weights : {WEIGHTS_PATH}")
    out.line(f"  Device  : {device}")
    out.line(f"  Params  : {total:,}")
    out.line(f"  Classes : {CLASSES}")
    out.line("")


def _accuracy(y_true, y_pred) -> float:
    return float(np.mean(y_true == y_pred)) * 100


def _section_overall_accuracy(out: _Tee, model: ExerciseBiLSTM, samples: int) -> tuple:
    out.line("[1]  Overall Accuracy  (noise=0.000, seq_len=60)")
    out.line("-" * 50)
    X, y = generate_synthetic_dataset(samples, SEQ_LEN, noise_std=0.0)
    preds, probs = _run_inference(model, X)
    acc = _accuracy(y, preds)
    out.line(f"     {samples * NUM_CLASSES} samples ({samples}/class)  →  Accuracy: {acc:.1f}%")
    out.line("")
    return X, y, preds, probs


def _section_confusion_matrix(out: _Tee, y_true, y_pred) -> None:
    out.line("[2]  Confusion Matrix  (rows=actual, cols=predicted)")
    out.line("-" * 50)
    # Build 5×5 matrix
    mat = np.zeros((NUM_CLASSES, NUM_CLASSES), dtype=int)
    for t, p in zip(y_true, y_pred):
        mat[t, p] += 1

    col_w = 13
    header = " " * 20 + "".join(c[:col_w].rjust(col_w) for c in CLASSES)
    out.line(header)
    for i, cls in enumerate(CLASSES):
        row = cls[:18].ljust(20) + "".join(str(v).rjust(col_w) for v in mat[i])
        out.line(row)
    out.line("")

    # Per-class precision / recall / f1
    out.line("     Per-Class Metrics:")
    header2 = f"     {'class':<16} {'precision':>10} {'recall':>8} {'f1':>8} {'support':>9}"
    out.line(header2)
    out.line("     " + "-" * 55)
    for i, cls in enumerate(CLASSES):
        tp = mat[i, i]
        fp = mat[:, i].sum() - tp
        fn = mat[i, :].sum() - tp
        prec = tp / (tp + fp + 1e-9)
        rec  = tp / (tp + fn + 1e-9)
        f1   = 2 * prec * rec / (prec + rec + 1e-9)
        sup  = int(mat[i].sum())
        out.line(f"     {cls:<16} {prec:>10.3f} {rec:>8.3f} {f1:>8.3f} {sup:>9}")
    out.line("")


def _section_noise_robustness(out: _Tee, model: ExerciseBiLSTM, samples: int, noise_levels: list) -> None:
    out.line("[3]  Noise Robustness  (seq_len=60)")
    out.line("-" * 50)
    accs = []
    for noise in noise_levels:
        X, y = generate_synthetic_dataset(samples, SEQ_LEN, noise_std=noise)
        preds, _ = _run_inference(model, X)
        acc = _accuracy(y, preds)
        accs.append(acc)
        out.line(f"     noise={noise:.3f}  →  {acc:.1f}%")
    degradation = accs[-1] - accs[0]
    out.line(f"     Degradation ({noise_levels[0]:.3f}→{noise_levels[-1]:.3f}): {degradation:+.1f}pp")
    out.line("")


def _section_seqlen_sensitivity(out: _Tee, model: ExerciseBiLSTM, samples: int, seq_lengths: list) -> None:
    out.line("[4]  Sequence Length Sensitivity  (noise=0.020)")
    out.line("-" * 50)
    for seq_len in seq_lengths:
        X, y = generate_synthetic_dataset(samples, seq_len, noise_std=0.02)
        preds, _ = _run_inference(model, X)
        acc = _accuracy(y, preds)
        out.line(f"     seq_len={seq_len:4d}  →  {acc:.1f}%")
    out.line("")


def _section_physics_override_rate(out: _Tee, model: ExerciseBiLSTM, samples: int) -> None:
    out.line("[5]  Physics Check Override Rate  (noise=0.000, seq_len=60)")
    out.line("-" * 50)
    total_overrides = 0
    total_samples = 0
    for i, cls in enumerate(CLASSES):
        overrides = 0
        for _ in range(samples):
            feats = _GENERATORS[i](SEQ_LEN)  # (T, 14) clean
            x = torch.from_numpy(feats).unsqueeze(0)
            with torch.no_grad():
                logits = model(x)
                pred_idx = int(logits.argmax(dim=1).item())
            pred_cls = CLASSES[pred_idx]
            valid, _ = _physics_check(pred_cls, feats)
            if not valid:
                overrides += 1
        pct = overrides / samples * 100
        out.line(f"     {cls:<16} {overrides:4d} / {samples}  ({pct:.1f}%)")
        total_overrides += overrides
        total_samples += samples
    total_pct = total_overrides / total_samples * 100
    out.line(f"     {'TOTAL':<16} {total_overrides:4d} / {total_samples}  ({total_pct:.1f}%)")
    out.line("")


def _section_inference_speed(out: _Tee, model: ExerciseBiLSTM, n_runs: int = 1000) -> None:
    out.line(f"[6]  Inference Speed  ({n_runs} samples, seq_len=60, device=cpu)")
    out.line("-" * 50)
    # Warmup
    dummy = torch.randn(1, SEQ_LEN, NUM_FEATURES)
    with torch.no_grad():
        for _ in range(20):
            model(dummy)

    latencies = []
    with torch.no_grad():
        for _ in range(n_runs):
            x = torch.randn(1, SEQ_LEN, NUM_FEATURES)
            t0 = time.perf_counter()
            model(x)
            latencies.append((time.perf_counter() - t0) * 1000)  # ms

    latencies = np.array(latencies)
    median = float(np.median(latencies))
    p95    = float(np.percentile(latencies, 95))
    p99    = float(np.percentile(latencies, 99))
    throughput = 1000.0 / median  # samples/sec

    out.line(f"     Median latency : {median:.2f} ms/sample")
    out.line(f"     P95 latency    : {p95:.2f} ms/sample")
    out.line(f"     P99 latency    : {p99:.2f} ms/sample")
    out.line(f"     Throughput     : {throughput:.0f} samples/sec")
    out.line("")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Evaluate the BiLSTM exercise classifier")
    parser.add_argument("--samples",      type=int,   default=200,
                        help="Samples per class for evaluation (default 200)")
    parser.add_argument("--output",       type=str,   default="eval_report.txt",
                        help="Output file path (default eval_report.txt)")
    parser.add_argument("--noise-levels", type=float, nargs="+",
                        default=[0.0, 0.01, 0.02, 0.05, 0.10])
    parser.add_argument("--seq-lengths",  type=int,   nargs="+",
                        default=[15, 30, 60, 120])
    args = parser.parse_args()

    # Load model
    if not os.path.exists(WEIGHTS_PATH):
        print(f"ERROR: Weights not found at {WEIGHTS_PATH}")
        print("Run:  python -m app.analysis.train_bilstm")
        sys.exit(1)

    preload_model()
    model = _mod._model
    if model is None:
        print("ERROR: preload_model() failed.")
        sys.exit(1)

    out = _Tee(args.output)

    _section_model_info(out, model)
    _, y, preds, _ = _section_overall_accuracy(out, model, args.samples)
    _section_confusion_matrix(out, y, preds)
    _section_noise_robustness(out, model, args.samples, args.noise_levels)
    _section_seqlen_sensitivity(out, model, args.samples, args.seq_lengths)
    _section_physics_override_rate(out, model, args.samples)
    _section_inference_speed(out, model)

    out.line("=" * 60)
    out.line(f"  Report saved to: {os.path.abspath(args.output)}")
    out.line("=" * 60)
    out.close()


if __name__ == "__main__":
    main()
