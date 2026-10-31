import math

import pytest

try:
    from measure.circumference import (
        DEFAULT_WAIST_SHAPE_FACTOR,
        calibrate_waist_shape_factor,
        calculate_body_roundness_index,
        estimate_waist_circumference,
    )
except ImportError:
    from circumference import (
        DEFAULT_WAIST_SHAPE_FACTOR,
        calibrate_waist_shape_factor,
        calculate_body_roundness_index,
        estimate_waist_circumference,
    )


def test_ramanujan_circle_matches_exact_circumference():
    radius = 12.5

    result = estimate_waist_circumference(2 * radius, 2 * radius)

    assert result == pytest.approx(2 * math.pi * radius)


def test_ramanujan_ellipse_uses_full_widths_and_shape_factor():
    frontal_width, side_depth = 30.0, 20.0
    r1, r2 = frontal_width / 2, side_depth / 2
    expected = math.pi * (
        3 * (r1 + r2) - math.sqrt((3 * r1 + r2) * (r1 + 3 * r2))
    )

    result = estimate_waist_circumference(frontal_width, side_depth)

    assert result == pytest.approx(expected)
    assert estimate_waist_circumference(
        frontal_width, side_depth, shape_factor=1.08
    ) == pytest.approx(expected * 1.08)
    assert DEFAULT_WAIST_SHAPE_FACTOR == 1.0


def test_bri_uses_thomas_square_root_equation():
    circumference_cm = 80.0
    height_cm = 175.0
    ratio = circumference_cm / (math.pi * height_cm)
    expected = 364.2 - 365.5 * math.sqrt(1 - ratio**2)

    assert calculate_body_roundness_index(circumference_cm, height_cm) == pytest.approx(
        expected
    )


@pytest.mark.parametrize(
    "circumference, height",
    [
        (0, 175),
        (80, 0),
        (-1, 175),
        (80, math.inf),
        (math.nan, 175),
        (550, 175),
    ],
)
def test_bri_rejects_invalid_or_out_of_domain_inputs(circumference, height):
    with pytest.raises(ValueError):
        calculate_body_roundness_index(circumference, height)


@pytest.mark.parametrize(
    "front, side, factor",
    [
        (0, 20, 1),
        (20, -1, 1),
        (20, 10, 0),
        (math.inf, 10, 1),
        (20, math.nan, 1),
        (20, 10, math.inf),
    ],
)
def test_rejects_non_positive_or_non_finite_inputs(front, side, factor):
    with pytest.raises(ValueError):
        estimate_waist_circumference(front, side, factor)


def test_calibration_recovers_multiplicative_shape_factor():
    expected_factor = 1.075
    fronts = [80.0, 92.0, 104.0]
    sides = [24.0, 29.0, 35.0]
    references = [
        estimate_waist_circumference(front, side) * expected_factor
        for front, side in zip(fronts, sides)
    ]

    result = calibrate_waist_shape_factor(fronts, sides, references)

    assert result == pytest.approx(expected_factor)


@pytest.mark.parametrize(
    "fronts, sides, references",
    [
        ([], [], []),
        ([80], [], [75]),
        ([80], [25], [0]),
        ([80], [25], [math.inf]),
    ],
)
def test_calibration_rejects_missing_or_invalid_reference_data(
    fronts, sides, references
):
    with pytest.raises(ValueError):
        calibrate_waist_shape_factor(fronts, sides, references)
