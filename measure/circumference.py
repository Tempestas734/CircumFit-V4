"""Ellipse-based waist circumference estimates and shape-factor calibration."""

import math
from typing import Sequence


DEFAULT_WAIST_SHAPE_FACTOR = 1.0


def estimate_waist_circumference(
    frontal_width_cm: float,
    side_depth_cm: float,
    shape_factor: float = DEFAULT_WAIST_SHAPE_FACTOR,
) -> float:
    """Estimate circumference with Ramanujan's second ellipse approximation.

    Widths are full measurements in centimeters; the approximation uses their
    half-widths as the ellipse semi-axes.
    """
    values = (frontal_width_cm, side_depth_cm, shape_factor)
    if any(not math.isfinite(value) or value <= 0 for value in values):
        raise ValueError("Widths and shape factor must be positive and finite.")

    a = frontal_width_cm / 2.0
    b = side_depth_cm / 2.0
    circumference = math.pi * (
        3.0 * (a + b) - math.sqrt((3.0 * a + b) * (a + 3.0 * b))
    )
    return circumference * shape_factor


def calibrate_waist_shape_factor(
    frontal_widths_cm: Sequence[float],
    side_depths_cm: Sequence[float],
    reference_circumferences_cm: Sequence[float],
) -> float:
    """Fit one multiplicative factor by least squares to reference measurements."""
    if not frontal_widths_cm:
        raise ValueError("At least one reference measurement is required.")
    if not (
        len(frontal_widths_cm)
        == len(side_depths_cm)
        == len(reference_circumferences_cm)
    ):
        raise ValueError("All calibration measurements must have the same length.")

    estimates = [
        estimate_waist_circumference(front, side)
        for front, side in zip(frontal_widths_cm, side_depths_cm)
    ]
    references = []
    for reference in reference_circumferences_cm:
        if not math.isfinite(reference) or reference <= 0:
            raise ValueError("Reference circumferences must be positive and finite.")
        references.append(reference)

    factor = math.fsum(
        estimate * reference
        for estimate, reference in zip(estimates, references)
    ) / math.fsum(estimate * estimate for estimate in estimates)
    if not math.isfinite(factor) or factor <= 0:
        raise ValueError("Calibration did not produce a positive finite factor.")
    return factor
