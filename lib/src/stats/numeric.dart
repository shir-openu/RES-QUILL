import 'dart:math' as math;

class StatsException implements Exception {
  StatsException(this.message);

  final String message;

  @override
  String toString() => 'StatsException: $message';
}

void requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw StatsException('$name must be finite.');
  }
}

void requirePositive(double value, String name) {
  requireFinite(value, name);
  if (value <= 0) {
    throw StatsException('$name must be greater than zero.');
  }
}

void requireProbability(double value, String name) {
  requireFinite(value, name);
  if (value < 0 || value > 1) {
    throw StatsException('$name must be in [0, 1].');
  }
}

double clampProbability(double value) {
  if (value.isNaN) {
    throw StatsException('Probability calculation produced NaN.');
  }
  if (value <= 0) {
    return 0;
  }
  if (value >= 1) {
    return 1;
  }
  return value;
}

double checkedStandardError(double value, String context) {
  requireFinite(value, '$context standard error');
  if (value <= 0) {
    throw StatsException(
      '$context standard error is zero; the t statistic is undefined.',
    );
  }
  return value;
}

double relativeDifference(double a, double b) {
  final scale = math.max(a.abs(), b.abs());
  if (scale == 0) {
    return 0;
  }
  return (a - b).abs() / scale;
}

bool nearlyEqual(double a, double b, double tolerance) {
  return (a - b).abs() <= tolerance;
}
