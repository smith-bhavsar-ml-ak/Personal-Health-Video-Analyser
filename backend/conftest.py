"""
Root-level conftest.py — loaded by pytest before any test collection.

Stubs out heavy CV dependencies (mediapipe, cv2) that are only available
inside the Docker container. The tests never call detect_poses() or any
OpenCV/MediaPipe function — they only use PoseFrame, LANDMARK, and
calculate_angle from pose_detector.py, which are pure Python/numpy.
"""

import sys
from unittest.mock import MagicMock

_STUB_MODULES = [
    "mediapipe",
    "mediapipe.solutions",
    "mediapipe.solutions.pose",
    "cv2",
]

for _mod in _STUB_MODULES:
    if _mod not in sys.modules:
        sys.modules[_mod] = MagicMock()
