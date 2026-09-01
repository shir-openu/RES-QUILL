import json
import math
import sys

from scipy import stats


def _summary(item):
    return {
        "n": int(item["n"]),
        "mean": float(item["mean"]),
        "sd": float(item["standardDeviation"]),
    }


def _p_value(t, df, tail):
    cdf = stats.t.cdf(t, df)
    if tail == "less":
        return cdf
    if tail == "greater":
        return 1 - cdf
    return 2 * min(cdf, 1 - cdf)


def _independent_student(data):
    first = _summary(data["first"])
    second = _summary(data["second"])
    df = first["n"] + second["n"] - 2
    pooled = (
        (first["n"] - 1) * first["sd"] ** 2
        + (second["n"] - 1) * second["sd"] ** 2
    ) / df
    se = math.sqrt(pooled * (1 / first["n"] + 1 / second["n"]))
    t = (first["mean"] - second["mean"]) / se
    return t, float(df), se, first["mean"] - second["mean"]


def _independent_welch(data):
    first = _summary(data["first"])
    second = _summary(data["second"])
    first_component = first["sd"] ** 2 / first["n"]
    second_component = second["sd"] ** 2 / second["n"]
    se = math.sqrt(first_component + second_component)
    df = (first_component + second_component) ** 2 / (
        first_component**2 / (first["n"] - 1)
        + second_component**2 / (second["n"] - 1)
    )
    t = (first["mean"] - second["mean"]) / se
    return t, df, se, first["mean"] - second["mean"]


def _one_sample(data):
    first = _summary(data["first"])
    reference = float(data["referenceMean"])
    df = first["n"] - 1
    se = first["sd"] / math.sqrt(first["n"])
    t = (first["mean"] - reference) / se
    return t, float(df), se, first["mean"] - reference


def _paired(data):
    paired = data["paired"]
    first = _summary(paired["first"])
    second = _summary(paired["second"])
    n = first["n"]
    mean_difference = paired.get("meanDifference")
    if mean_difference is None:
        mean_difference = first["mean"] - second["mean"]
    else:
        mean_difference = float(mean_difference)
    difference_sd = paired.get("differenceStandardDeviation")
    if difference_sd is None:
        correlation = float(paired["correlation"])
        difference_variance = (
            first["sd"] ** 2
            + second["sd"] ** 2
            - 2 * correlation * first["sd"] * second["sd"]
        )
        difference_sd = math.sqrt(difference_variance)
    else:
        difference_sd = float(difference_sd)
    df = n - 1
    se = difference_sd / math.sqrt(n)
    t = mean_difference / se
    return t, float(df), se, mean_difference


def main():
    if len(sys.argv) > 1:
        data = json.loads(sys.argv[1])
    else:
        data = json.load(sys.stdin)
    kind = data["kind"]
    if kind == "independentStudent":
        t, df, se, mean_difference = _independent_student(data)
    elif kind == "independentWelch":
        t, df, se, mean_difference = _independent_welch(data)
    elif kind == "oneSample":
        t, df, se, mean_difference = _one_sample(data)
    elif kind == "pairedSamples":
        t, df, se, mean_difference = _paired(data)
    else:
        raise ValueError(f"unsupported kind {kind}")

    p = _p_value(t, df, data.get("tail", "twoTailed"))
    json.dump(
        {
            "t": t,
            "df": df,
            "p": p,
            "standardError": se,
            "meanDifference": mean_difference,
        },
        sys.stdout,
        sort_keys=True,
    )


if __name__ == "__main__":
    main()
