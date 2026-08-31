import json
import math
import os
import subprocess
import sys
from collections import Counter
from pathlib import Path

import numpy as np
import scipy
from scipy import stats


ROOT = Path(__file__).resolve().parents[2]
DART = Path(os.environ.get("DART_EXE", r"C:\flutter\bin\cache\dart-sdk\bin\dart.exe"))
RUNNER = ROOT / "tool" / "verify" / "dart_stats_crosscheck_runner.dart"
OUTPUT = ROOT / "tool" / "verify" / "stats_crosscheck_output.txt"


def summary(values):
    values = np.asarray(values, dtype=float)
    return {
        "n": int(values.size),
        "mean": float(values.mean()),
        "sd": float(values.std(ddof=1)),
    }


def paired_summary(first, second):
    first_summary = summary(first)
    second_summary = summary(second)
    diff_summary = summary(np.asarray(first) - np.asarray(second))
    return {
        "n": first_summary["n"],
        "firstMean": first_summary["mean"],
        "firstSd": first_summary["sd"],
        "secondMean": second_summary["mean"],
        "secondSd": second_summary["sd"],
        "meanDifference": diff_summary["mean"],
        "differenceSd": diff_summary["sd"],
    }


def generate_cases(seed=20260830, per_kind=75):
    rng = np.random.default_rng(seed)
    cases = []

    def confidence():
        return float(rng.choice([0.90, 0.95, 0.99]))

    for i in range(per_kind):
        n1 = int(rng.integers(2, 160))
        n2 = int(rng.integers(2, 180))
        mean1 = float(rng.uniform(-30, 30))
        mean2 = float(rng.uniform(-30, 30))
        sd1 = float(np.exp(rng.uniform(math.log(0.15), math.log(25))))
        sd2 = float(np.exp(rng.uniform(math.log(0.15), math.log(25))))
        first = rng.normal(mean1, sd1, n1)
        second = rng.normal(mean2, sd2, n2)
        level = confidence()
        first_summary = summary(first)
        second_summary = summary(second)

        cases.append(
            {
                "id": f"student_summary_{i:03d}",
                "kind": "student",
                "mode": "summary",
                "confidenceLevel": level,
                "first": first_summary,
                "second": second_summary,
            }
        )
        cases.append(
            {
                "id": f"student_raw_{i:03d}",
                "kind": "student",
                "mode": "raw",
                "confidenceLevel": level,
                "firstValues": first.tolist(),
                "secondValues": second.tolist(),
            }
        )
        cases.append(
            {
                "id": f"welch_summary_{i:03d}",
                "kind": "welch",
                "mode": "summary",
                "confidenceLevel": level,
                "first": first_summary,
                "second": second_summary,
            }
        )
        cases.append(
            {
                "id": f"welch_raw_{i:03d}",
                "kind": "welch",
                "mode": "raw",
                "confidenceLevel": level,
                "firstValues": first.tolist(),
                "secondValues": second.tolist(),
            }
        )

    for i in range(per_kind):
        n = int(rng.integers(2, 180))
        mean = float(rng.uniform(-15, 15))
        sd = float(np.exp(rng.uniform(math.log(0.2), math.log(12))))
        values = rng.normal(mean, sd, n)
        reference = float(rng.uniform(-10, 10))
        level = confidence()
        sample_summary = summary(values)

        cases.append(
            {
                "id": f"one_summary_{i:03d}",
                "kind": "one_sample",
                "mode": "summary",
                "confidenceLevel": level,
                "sample": sample_summary,
                "referenceMean": reference,
            }
        )
        cases.append(
            {
                "id": f"one_raw_{i:03d}",
                "kind": "one_sample",
                "mode": "raw",
                "confidenceLevel": level,
                "values": values.tolist(),
                "referenceMean": reference,
            }
        )

    for i in range(per_kind):
        n = int(rng.integers(2, 160))
        baseline = rng.normal(float(rng.uniform(-20, 20)), float(rng.uniform(1, 10)), n)
        shift = float(rng.uniform(-8, 8))
        noise = rng.normal(shift, float(np.exp(rng.uniform(math.log(0.2), math.log(10)))), n)
        second = baseline + noise
        level = confidence()
        pair_summary = paired_summary(baseline, second)

        cases.append(
            {
                "id": f"paired_summary_{i:03d}",
                "kind": "paired",
                "mode": "summary",
                "confidenceLevel": level,
                "paired": pair_summary,
            }
        )
        cases.append(
            {
                "id": f"paired_raw_{i:03d}",
                "kind": "paired",
                "mode": "raw",
                "confidenceLevel": level,
                "firstValues": baseline.tolist(),
                "secondValues": second.tolist(),
            }
        )

    return cases


def expected(case):
    level = case["confidenceLevel"]
    alpha = 1 - level
    kind = case["kind"]

    if kind in {"student", "welch"}:
        first = case.get("first") or summary(case["firstValues"])
        second = case.get("second") or summary(case["secondValues"])
        n1, n2 = first["n"], second["n"]
        m1, m2 = first["mean"], second["mean"]
        s1, s2 = first["sd"], second["sd"]
        mean_difference = m1 - m2
        if kind == "student":
            df = n1 + n2 - 2
            sp = math.sqrt(((n1 - 1) * s1**2 + (n2 - 1) * s2**2) / df)
            se = sp * math.sqrt(1 / n1 + 1 / n2)
            standardizer = sp
        else:
            a = s1**2 / n1
            b = s2**2 / n2
            se = math.sqrt(a + b)
            df = (a + b) ** 2 / (a**2 / (n1 - 1) + b**2 / (n2 - 1))
            standardizer = math.sqrt((s1**2 + s2**2) / 2)
        df_correction = n1 + n2 - 2
    elif kind == "one_sample":
        sample = case.get("sample") or summary(case["values"])
        n = sample["n"]
        mean_difference = sample["mean"] - case["referenceMean"]
        se = sample["sd"] / math.sqrt(n)
        df = n - 1
        standardizer = sample["sd"]
        df_correction = df
    elif kind == "paired":
        pair = case.get("paired")
        if pair is None:
            pair = paired_summary(case["firstValues"], case["secondValues"])
        n = pair["n"]
        mean_difference = pair["meanDifference"]
        se = pair["differenceSd"] / math.sqrt(n)
        df = n - 1
        standardizer = pair["differenceSd"]
        df_correction = df
    else:
        raise ValueError(kind)

    t_value = mean_difference / se
    cdf = stats.t.cdf(t_value, df)
    p_less = cdf
    p_greater = 1 - cdf
    p_one = min(p_less, p_greater)
    p_two = min(1.0, 2 * p_one)
    critical = stats.t.ppf(1 - alpha / 2, df)
    margin = critical * se
    d_value = mean_difference / standardizer
    hedges_g = None
    if df_correction > 1:
        correction = math.exp(
            math.lgamma(df_correction / 2)
            - 0.5 * math.log(df_correction / 2)
            - math.lgamma((df_correction - 1) / 2)
        )
        hedges_g = d_value * correction

    return {
        "t": t_value,
        "df": float(df),
        "pTwoTailed": p_two,
        "pOneTailed": p_one,
        "pLess": p_less,
        "pGreater": p_greater,
        "meanDifference": mean_difference,
        "standardError": se,
        "ciLower": mean_difference - margin,
        "ciUpper": mean_difference + margin,
        "cohensD": d_value,
        "hedgesG": hedges_g,
    }


def run_dart(cases):
    if not DART.exists():
        raise RuntimeError(f"Dart executable not found: {DART}")
    proc = subprocess.run(
        [str(DART), "run", str(RUNNER)],
        cwd=ROOT,
        input=json.dumps(cases),
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"Dart runner failed\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}")
    return json.loads(proc.stdout)


def rel_diff(actual, expected_value):
    diff = abs(actual - expected_value)
    scale = max(abs(expected_value), 1e-300)
    return diff / scale


def main():
    cases = generate_cases()
    dart_results = run_dart(cases)
    by_id = {case["id"]: case for case in cases}
    metrics = [
        "t",
        "df",
        "pTwoTailed",
        "pOneTailed",
        "pLess",
        "pGreater",
        "ciLower",
        "ciUpper",
        "meanDifference",
        "standardError",
        "cohensD",
    ]
    max_abs = {metric: (0.0, None) for metric in metrics}
    max_rel = {metric: (0.0, None) for metric in metrics}
    errors = []

    for dart in dart_results:
        case = by_id[dart["id"]]
        if "error" in dart:
            errors.append((dart["id"], dart["error"]))
            continue
        exp = expected(case)
        for metric in metrics:
            actual = float(dart[metric])
            expected_value = float(exp[metric])
            abs_delta = abs(actual - expected_value)
            if abs_delta > max_abs[metric][0]:
                max_abs[metric] = (abs_delta, dart["id"])
            relative = rel_diff(actual, expected_value)
            if relative > max_rel[metric][0]:
                max_rel[metric] = (relative, dart["id"])

    counts = Counter((case["kind"], case["mode"]) for case in cases)
    lines = [
        "Res-Quill statistics engine SciPy cross-check",
        f"scipy_version: {scipy.__version__}",
        f"numpy_version: {np.__version__}",
        f"dart_executable: {DART}",
        f"cases_total: {len(cases)}",
        "cases_by_kind_mode:",
    ]
    for (kind, mode), count in sorted(counts.items()):
        lines.append(f"  {kind}/{mode}: {count}")
    lines.append(f"errors: {len(errors)}")
    for case_id, error in errors[:10]:
        lines.append(f"  {case_id}: {error}")

    lines.append("max_absolute_differences:")
    for metric in metrics:
        value, case_id = max_abs[metric]
        lines.append(f"  {metric}: {value:.17g} at {case_id}")

    lines.append("max_relative_differences:")
    for metric in metrics:
        value, case_id = max_rel[metric]
        lines.append(f"  {metric}: {value:.17g} at {case_id}")

    max_p_dev = max(
        max_abs["pTwoTailed"][0],
        max_abs["pOneTailed"][0],
        max_abs["pLess"][0],
        max_abs["pGreater"][0],
    )
    lines.append(f"max_p_deviation: {max_p_dev:.17g}")
    text = "\n".join(lines) + "\n"
    OUTPUT.write_text(text, encoding="utf-8")
    print(text, end="")


if __name__ == "__main__":
    main()
