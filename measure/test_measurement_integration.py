"""Integration tests for the two view measurements and multi-line median."""

from types import SimpleNamespace

import numpy as np
import pytest

try:
    from measure import app as server
except ImportError:
    import app as server


class _FakePose:
    def __init__(self, **_kwargs):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def process(self, _image):
        height, width = 400, 300
        landmarks = [
            SimpleNamespace(x=0.5, y=0.5)
            for _ in range(server.mp_pose.PoseLandmark.RIGHT_FOOT_INDEX + 1)
        ]
        points = {
            "NOSE": (0.50, 0.20),
            "LEFT_SHOULDER": (0.44, 0.35),
            "RIGHT_SHOULDER": (0.56, 0.35),
            "LEFT_HIP": (0.47, 0.60),
            "RIGHT_HIP": (0.53, 0.60),
            "LEFT_HEEL": (0.47, 0.90),
            "RIGHT_HEEL": (0.53, 0.90),
        }
        for name, (x, y) in points.items():
            landmarks[getattr(server.mp_pose.PoseLandmark, name)] = (
                SimpleNamespace(x=x, y=y)
            )
        mask = np.zeros((height, width), dtype=np.float32)
        mask[50:350, 100:200] = 0.95
        return SimpleNamespace(
            pose_landmarks=SimpleNamespace(landmark=landmarks),
            segmentation_mask=mask,
        )


@pytest.mark.parametrize(
    "measurement",
    [server.mesurer_largeur_taille, server.mesurer_profondeur_taille],
)
def test_view_measurement_uses_multi_line_median(monkeypatch, measurement):
    monkeypatch.setattr(server.mp_pose, "Pose", _FakePose)
    image = np.full((400, 300, 3), 200, dtype=np.uint8)
    details = {}

    result = measurement(image, 170, details)

    assert result is not None
    assert result == pytest.approx(100 * 170 / 308)
    assert details["lignes"]["n_valides"] == 9
    assert details["lignes"]["n_total"] == 9
    assert details["methode"] == "masque"