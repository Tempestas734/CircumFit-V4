from types import SimpleNamespace

import numpy as np
import pytest

try:
    from measure import app as server
except ImportError:
    import app as server


class FakePose:
    def __init__(self, results):
        self._results = results

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def process(self, _image):
        return self._results


@pytest.mark.parametrize(
    "measure_function",
    [server.mesurer_profondeur_taille, server.mesurer_largeur_taille],
)
def test_measurement_uses_median_width_over_multiple_lines(
    monkeypatch, measure_function
):
    landmarks = [SimpleNamespace(x=0.5, y=0.5) for _ in range(33)]
    landmark_values = {
        server.mp_pose.PoseLandmark.NOSE: (0.5, 0.2),
        server.mp_pose.PoseLandmark.LEFT_SHOULDER: (0.4, 0.35),
        server.mp_pose.PoseLandmark.RIGHT_SHOULDER: (0.6, 0.35),
        server.mp_pose.PoseLandmark.LEFT_HIP: (0.48, 0.6),
        server.mp_pose.PoseLandmark.RIGHT_HIP: (0.52, 0.6),
        server.mp_pose.PoseLandmark.LEFT_HEEL: (0.45, 0.9),
        server.mp_pose.PoseLandmark.RIGHT_HEEL: (0.55, 0.9),
    }
    for landmark, (x, y) in landmark_values.items():
        landmarks[int(landmark)] = SimpleNamespace(x=x, y=y)
    segmentation_mask = np.full((128, 100), 0.8, dtype=np.float32)
    results = SimpleNamespace(
        pose_landmarks=SimpleNamespace(landmark=landmarks),
        segmentation_mask=segmentation_mask,
    )
    monkeypatch.setattr(
        server.mp_pose,
        "Pose",
        lambda **_kwargs: FakePose(results),
    )
    calls = []

    def median_measure(image, mask, waist_y, hip_x, band):
        calls.append((image, mask, waist_y, hip_x, band))
        return SimpleNamespace(largeur_px=40.0)

    monkeypatch.setattr(server, "mesurer_multilignes", median_measure)
    monkeypatch.setattr(
        server,
        "details_multilignes",
        lambda _result: {"methode": "masque", "lignes": {"n_valides": 9}},
    )
    details = {}

    measured_width = measure_function(
        np.zeros((128, 100, 3), dtype=np.uint8),
        175,
        details,
    )

    assert measured_width == pytest.approx(40 * 175 / 99)
    assert len(calls) == 1
    _, supplied_mask, _, hip_x, half_band = calls[0]
    assert supplied_mask is segmentation_mask
    assert hip_x == 50
    assert half_band == 2
    assert details["lignes"]["n_valides"] == 9
