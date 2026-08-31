import 'dart:math' as math;

import 'numeric.dart';

class SpecialFunctions {
  SpecialFunctions._();

  static const _lanczosCoefficients = <double>[
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];

  static double logGamma(double z) {
    requirePositive(z, 'z');
    if (z < 0.5) {
      return math.log(math.pi) -
          math.log(math.sin(math.pi * z)) -
          logGamma(1 - z);
    }

    var x = 0.99999999999980993;
    final shifted = z - 1;
    for (var i = 0; i < _lanczosCoefficients.length; i += 1) {
      x += _lanczosCoefficients[i] / (shifted + i + 1);
    }
    final t = shifted + _lanczosCoefficients.length - 0.5;
    return 0.5 * math.log(2 * math.pi) +
        (shifted + 0.5) * math.log(t) -
        t +
        math.log(x);
  }

  static double logBeta(double a, double b) {
    requirePositive(a, 'a');
    requirePositive(b, 'b');
    return logGamma(a) + logGamma(b) - logGamma(a + b);
  }
}

class RegularizedIncompleteBeta {
  RegularizedIncompleteBeta._();

  static const _epsilon = 3e-14;
  static const _fpMin = 1e-300;
  static const _maxIterations = 300;

  static double evaluate(double x, double a, double b) {
    requireProbability(x, 'x');
    requirePositive(a, 'a');
    requirePositive(b, 'b');

    if (x == 0) {
      return 0;
    }
    if (x == 1) {
      return 1;
    }

    final front = math.exp(
      a * math.log(x) + b * _log1p(-x) - SpecialFunctions.logBeta(a, b),
    );
    final threshold = (a + 1) / (a + b + 2);
    final result = x < threshold
        ? front * _continuedFraction(a, b, x) / a
        : 1 - front * _continuedFraction(b, a, 1 - x) / b;
    return clampProbability(result);
  }

  static double inverse(double probability, double a, double b) {
    requireProbability(probability, 'probability');
    requirePositive(a, 'a');
    requirePositive(b, 'b');
    if (probability == 0) {
      return 0;
    }
    if (probability == 1) {
      return 1;
    }

    var lower = 0.0;
    var upper = 1.0;
    var x = _initialGuess(probability, a, b).clamp(1e-15, 1 - 1e-15).toDouble();

    for (var i = 0; i < 160; i += 1) {
      final value = evaluate(x, a, b);
      final error = value - probability;

      if (error == 0 || (upper - lower) <= 2e-15 * math.max(1, x.abs())) {
        return x.clamp(0, 1).toDouble();
      }

      if (error < 0) {
        lower = x;
      } else {
        upper = x;
      }

      final densityLog =
          (a - 1) * math.log(x) +
          (b - 1) * _log1p(-x) -
          SpecialFunctions.logBeta(a, b);
      final density = math.exp(densityLog);
      final newton = density.isFinite && density > 0
          ? x - error / density
          : double.nan;

      if (newton.isFinite && newton > lower && newton < upper) {
        x = newton;
      } else {
        x = 0.5 * (lower + upper);
      }
    }

    return x.clamp(0, 1).toDouble();
  }

  static double _continuedFraction(double a, double b, double x) {
    final qab = a + b;
    final qap = a + 1;
    final qam = a - 1;
    var c = 1.0;
    var d = 1 - qab * x / qap;
    if (d.abs() < _fpMin) {
      d = _fpMin;
    }
    d = 1 / d;
    var h = d;

    for (var m = 1; m <= _maxIterations; m += 1) {
      final m2 = 2 * m;
      var aa = m * (b - m) * x / ((qam + m2) * (a + m2));
      d = 1 + aa * d;
      if (d.abs() < _fpMin) {
        d = _fpMin;
      }
      c = 1 + aa / c;
      if (c.abs() < _fpMin) {
        c = _fpMin;
      }
      d = 1 / d;
      h *= d * c;

      aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
      d = 1 + aa * d;
      if (d.abs() < _fpMin) {
        d = _fpMin;
      }
      c = 1 + aa / c;
      if (c.abs() < _fpMin) {
        c = _fpMin;
      }
      d = 1 / d;
      final delta = d * c;
      h *= delta;

      if ((delta - 1).abs() < _epsilon) {
        return h;
      }
    }

    throw StatsException(
      'Incomplete beta continued fraction did not converge.',
    );
  }

  static double _initialGuess(double probability, double a, double b) {
    final mean = a / (a + b);
    final variance = a * b / ((a + b) * (a + b) * (a + b + 1));
    final sd = math.sqrt(variance);
    final normalApprox = mean + _inverseStandardNormal(probability) * sd;
    if (normalApprox.isFinite && normalApprox > 0 && normalApprox < 1) {
      return normalApprox;
    }
    return mean;
  }

  static double _inverseStandardNormal(double p) {
    const a = <double>[
      -3.969683028665376e+01,
      2.209460984245205e+02,
      -2.759285104469687e+02,
      1.383577518672690e+02,
      -3.066479806614716e+01,
      2.506628277459239e+00,
    ];
    const b = <double>[
      -5.447609879822406e+01,
      1.615858368580409e+02,
      -1.556989798598866e+02,
      6.680131188771972e+01,
      -1.328068155288572e+01,
    ];
    const c = <double>[
      -7.784894002430293e-03,
      -3.223964580411365e-01,
      -2.400758277161838e+00,
      -2.549732539343734e+00,
      4.374664141464968e+00,
      2.938163982698783e+00,
    ];
    const d = <double>[
      7.784695709041462e-03,
      3.224671290700398e-01,
      2.445134137142996e+00,
      3.754408661907416e+00,
    ];
    const pLow = 0.02425;
    const pHigh = 1 - pLow;

    if (p < pLow) {
      final q = math.sqrt(-2 * math.log(p));
      return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
              c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }
    if (p <= pHigh) {
      final q = p - 0.5;
      final r = q * q;
      return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r +
              a[5]) *
          q /
          (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    }

    final q = math.sqrt(-2 * _log1p(-p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
            c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
}

double _log1p(double x) => math.log(1 + x);

class TDistribution {
  TDistribution(this.degreesOfFreedom) {
    requirePositive(degreesOfFreedom, 'degreesOfFreedom');
  }

  final double degreesOfFreedom;

  double cdf(double t) {
    requireFinite(t, 't');
    if (t == 0) {
      return 0.5;
    }
    final x = degreesOfFreedom / (degreesOfFreedom + t * t);
    final ibeta = RegularizedIncompleteBeta.evaluate(
      x,
      degreesOfFreedom / 2,
      0.5,
    );
    return t > 0
        ? clampProbability(1 - 0.5 * ibeta)
        : clampProbability(0.5 * ibeta);
  }

  double quantile(double probability) {
    requireProbability(probability, 'probability');
    if (probability == 0) {
      return double.negativeInfinity;
    }
    if (probability == 1) {
      return double.infinity;
    }
    if (probability == 0.5) {
      return 0;
    }

    final lowerTail = probability < 0.5;
    final betaProbability = lowerTail ? 2 * probability : 2 * (1 - probability);
    final x = RegularizedIncompleteBeta.inverse(
      betaProbability,
      degreesOfFreedom / 2,
      0.5,
    );
    if (x <= 0) {
      return lowerTail ? double.negativeInfinity : double.infinity;
    }
    final magnitude = math.sqrt(degreesOfFreedom * (1 - x) / x);
    return lowerTail ? -magnitude : magnitude;
  }
}
