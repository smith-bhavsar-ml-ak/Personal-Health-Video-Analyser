"""
BiLSTM exercise classifier.

Architecture:
  Input  : (batch, seq_len, NUM_FEATURES=14)
  BiLSTM : hidden=128, num_layers=2, dropout=0.3, bidirectional=True
  Pool   : mean over time dimension
  FC     : 256 → 128 → num_classes=5
  Output : (batch, num_classes)  — raw logits

Class index mapping:
  0 squat
  1 jumping_jack
  2 bicep_curl
  3 lunge
  4 plank
"""

import torch
import torch.nn as nn

# Must match the output dimension of features.extract_frame_features()
NUM_FEATURES = 14
CLASSES = ["squat", "jumping_jack", "bicep_curl", "lunge", "plank"]
NUM_CLASSES = len(CLASSES)

HIDDEN_SIZE  = 128
NUM_LAYERS   = 2
DROPOUT      = 0.3


class ExerciseBiLSTM(nn.Module):
    def __init__(
        self,
        input_size: int = NUM_FEATURES,
        hidden_size: int = HIDDEN_SIZE,
        num_layers: int = NUM_LAYERS,
        num_classes: int = NUM_CLASSES,
        dropout: float = DROPOUT,
    ):
        super().__init__()
        self.lstm = nn.LSTM(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            bidirectional=True,
            dropout=dropout if num_layers > 1 else 0.0,
        )
        lstm_out = hidden_size * 2  # bidirectional doubles the output
        self.classifier = nn.Sequential(
            nn.Linear(lstm_out, 128),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(128, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: (batch, seq_len, input_size)
        out, _ = self.lstm(x)            # (batch, seq_len, lstm_out)
        pooled = out.mean(dim=1)         # (batch, lstm_out) — mean-pool over time
        return self.classifier(pooled)  # (batch, num_classes)
