from dataclasses import dataclass, field
from abc import ABC, abstractmethod

from app.cv.pose_detector import PoseFrame


@dataclass
class PostureError:
    error_type: str
    occurrences: int
    severity: str  # low | medium | high


@dataclass
class RepResult:
    rep_count: int
    correct_reps: int
    rep_scores: list[float]  # form score per rep (0-100)


@dataclass
class ExerciseResult:
    exercise_type: str
    rep_count: int
    correct_reps: int
    duration_s: int
    form_score: float
    rep_scores: list[float]
    posture_errors: list[PostureError] = field(default_factory=list)
    start_frame: int = 0
    end_frame: int = 0


class ExerciseAnalyser(ABC):
    """Strategy interface — same API for rule-based and future ML engine."""

    @abstractmethod
    def analyse(self, pose_frames: list[PoseFrame], fps: float) -> ExerciseResult:
        """Run full analysis on a pose sequence for this exercise."""
        ...
