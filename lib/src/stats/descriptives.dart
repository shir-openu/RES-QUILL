import 'dart:math' as math;

import 'numeric.dart';

class SummaryStats {
  SummaryStats({
    required this.n,
    required this.mean,
    required this.standardDeviation,
  }) {
    if (n < 2) {
      throw StatsException('n must be at least 2.');
    }
    requireFinite(mean, 'mean');
    requireFinite(standardDeviation, 'standardDeviation');
    if (standardDeviation < 0) {
      throw StatsException('standardDeviation must be non-negative.');
    }
  }

  factory SummaryStats.fromValues(Iterable<num> values) {
    final data = values.map((value) => value.toDouble()).toList();
    if (data.length < 2) {
      throw StatsException('At least two raw values are required.');
    }
    for (final value in data) {
      requireFinite(value, 'raw value');
    }

    final n = data.length;
    final mean = data.reduce((a, b) => a + b) / n;
    var sumSquares = 0.0;
    for (final value in data) {
      final centered = value - mean;
      sumSquares += centered * centered;
    }

    return SummaryStats(
      n: n,
      mean: mean,
      standardDeviation: math.sqrt(sumSquares / (n - 1)),
    );
  }

  final int n;
  final double mean;
  final double standardDeviation;

  double get variance => standardDeviation * standardDeviation;

  @override
  String toString() {
    return 'SummaryStats(n: $n, mean: $mean, sd: $standardDeviation)';
  }
}

class PairedSummaryStats {
  PairedSummaryStats({
    required this.n,
    required this.firstMean,
    required this.firstStandardDeviation,
    required this.secondMean,
    required this.secondStandardDeviation,
    required this.meanDifference,
    required this.differenceStandardDeviation,
    this.correlation,
  }) : first = SummaryStats(
         n: n,
         mean: firstMean,
         standardDeviation: firstStandardDeviation,
       ),
       second = SummaryStats(
         n: n,
         mean: secondMean,
         standardDeviation: secondStandardDeviation,
       ),
       differences = SummaryStats(
         n: n,
         mean: meanDifference,
         standardDeviation: differenceStandardDeviation,
       ) {
    if (correlation != null) {
      requireFinite(correlation!, 'correlation');
      if (correlation! < -1 || correlation! > 1) {
        throw StatsException('correlation must be in [-1, 1].');
      }
    }
  }

  factory PairedSummaryStats.fromMarginalsAndCorrelation({
    required int n,
    required double firstMean,
    required double firstStandardDeviation,
    required double secondMean,
    required double secondStandardDeviation,
    required double correlation,
  }) {
    final variance =
        firstStandardDeviation * firstStandardDeviation +
        secondStandardDeviation * secondStandardDeviation -
        2 * correlation * firstStandardDeviation * secondStandardDeviation;
    if (variance < -1e-12) {
      throw StatsException(
        'The supplied paired marginal SDs and correlation imply a negative '
        'difference variance.',
      );
    }

    return PairedSummaryStats(
      n: n,
      firstMean: firstMean,
      firstStandardDeviation: firstStandardDeviation,
      secondMean: secondMean,
      secondStandardDeviation: secondStandardDeviation,
      meanDifference: firstMean - secondMean,
      differenceStandardDeviation: math.sqrt(math.max(0, variance)),
      correlation: correlation,
    );
  }

  factory PairedSummaryStats.fromRawValues(
    Iterable<num> firstValues,
    Iterable<num> secondValues,
  ) {
    final firstData = firstValues.map((value) => value.toDouble()).toList();
    final secondData = secondValues.map((value) => value.toDouble()).toList();
    if (firstData.length != secondData.length) {
      throw StatsException('Paired raw value lists must have the same length.');
    }
    if (firstData.length < 2) {
      throw StatsException('At least two pairs are required.');
    }

    final differences = <double>[];
    for (var i = 0; i < firstData.length; i += 1) {
      differences.add(firstData[i] - secondData[i]);
    }

    final correlation = _sampleCorrelation(firstData, secondData);
    return PairedSummaryStats(
      n: firstData.length,
      firstMean: SummaryStats.fromValues(firstData).mean,
      firstStandardDeviation: SummaryStats.fromValues(
        firstData,
      ).standardDeviation,
      secondMean: SummaryStats.fromValues(secondData).mean,
      secondStandardDeviation: SummaryStats.fromValues(
        secondData,
      ).standardDeviation,
      meanDifference: SummaryStats.fromValues(differences).mean,
      differenceStandardDeviation: SummaryStats.fromValues(
        differences,
      ).standardDeviation,
      correlation: correlation.isFinite ? correlation : null,
    );
  }

  final int n;
  final double firstMean;
  final double firstStandardDeviation;
  final double secondMean;
  final double secondStandardDeviation;
  final double meanDifference;
  final double differenceStandardDeviation;
  final double? correlation;
  final SummaryStats first;
  final SummaryStats second;
  final SummaryStats differences;
}

double _sampleCorrelation(List<double> first, List<double> second) {
  final firstSummary = SummaryStats.fromValues(first);
  final secondSummary = SummaryStats.fromValues(second);
  final denominator =
      (first.length - 1) *
      firstSummary.standardDeviation *
      secondSummary.standardDeviation;
  if (denominator == 0) {
    return double.nan;
  }

  var covarianceNumerator = 0.0;
  for (var i = 0; i < first.length; i += 1) {
    covarianceNumerator +=
        (first[i] - firstSummary.mean) * (second[i] - secondSummary.mean);
  }
  return covarianceNumerator / denominator;
}
