import 'dart:math' as math;

import 'descriptives.dart';
import 'distributions.dart';
import 'numeric.dart';

enum TTestKind {
  independentStudent,
  independentWelch,
  pairedSamples,
  oneSample,
}

class ConfidenceInterval {
  ConfidenceInterval({
    required this.level,
    required this.lower,
    required this.upper,
  }) {
    requireProbability(level, 'confidence level');
    if (level <= 0 || level >= 1) {
      throw StatsException('confidence level must be inside (0, 1).');
    }
    requireFinite(lower, 'confidence interval lower bound');
    requireFinite(upper, 'confidence interval upper bound');
    if (lower > upper) {
      throw StatsException(
        'confidence interval lower bound exceeds upper bound.',
      );
    }
  }

  final double level;
  final double lower;
  final double upper;
}

class EffectSize {
  EffectSize({
    required this.cohensD,
    required this.hedgesG,
    required this.correction,
    required this.standardizer,
    required this.standardizerValue,
  }) {
    requireFinite(cohensD, "Cohen's d");
    if (hedgesG != null) {
      requireFinite(hedgesG!, "Hedges' g");
    }
    if (correction != null) {
      requireFinite(correction!, "Hedges' correction");
    }
    requireFinite(standardizerValue, 'effect-size standardizer');
  }

  final double cohensD;
  final double? hedgesG;
  final double? correction;
  final String standardizer;
  final double standardizerValue;
}

class TTestResult {
  TTestResult({
    required this.kind,
    required this.meanDifference,
    required this.standardError,
    required this.t,
    required this.degreesOfFreedom,
    required this.pTwoTailed,
    required this.pOneTailed,
    required this.pLess,
    required this.pGreater,
    required this.confidenceInterval,
    required this.effectSize,
    required this.primary,
    this.secondary,
    this.pairedDifferences,
    this.referenceMean,
  });

  final TTestKind kind;
  final double meanDifference;
  final double standardError;
  final double t;
  final double degreesOfFreedom;
  final double pTwoTailed;
  final double pOneTailed;
  final double pLess;
  final double pGreater;
  final ConfidenceInterval confidenceInterval;
  final EffectSize effectSize;
  final SummaryStats primary;
  final SummaryStats? secondary;
  final SummaryStats? pairedDifferences;
  final double? referenceMean;
}

class TTests {
  TTests._();

  static TTestResult independentStudentFromSummary({
    required SummaryStats first,
    required SummaryStats second,
    double confidenceLevel = 0.95,
  }) {
    _validateConfidenceLevel(confidenceLevel);
    final df = (first.n + second.n - 2).toDouble();
    final pooledVariance =
        ((first.n - 1) * first.variance + (second.n - 1) * second.variance) /
        df;
    final pooledSd = math.sqrt(pooledVariance);
    final meanDifference = first.mean - second.mean;
    final standardError = checkedStandardError(
      pooledSd * math.sqrt(1 / first.n + 1 / second.n),
      'independent Student',
    );
    final t = meanDifference / standardError;
    return _finish(
      kind: TTestKind.independentStudent,
      meanDifference: meanDifference,
      standardError: standardError,
      t: t,
      degreesOfFreedom: df,
      confidenceLevel: confidenceLevel,
      effectSize: _effectSize(
        d: meanDifference / _checkedStandardizer(pooledSd, 'pooled SD'),
        dfForCorrection: df,
        standardizer: 'pooled sample SD (Student equal-variance convention)',
        standardizerValue: pooledSd,
      ),
      primary: first,
      secondary: second,
    );
  }

  static TTestResult independentStudentFromRaw({
    required Iterable<num> first,
    required Iterable<num> second,
    double confidenceLevel = 0.95,
  }) {
    return independentStudentFromSummary(
      first: SummaryStats.fromValues(first),
      second: SummaryStats.fromValues(second),
      confidenceLevel: confidenceLevel,
    );
  }

  static TTestResult independentWelchFromSummary({
    required SummaryStats first,
    required SummaryStats second,
    double confidenceLevel = 0.95,
  }) {
    _validateConfidenceLevel(confidenceLevel);
    final firstComponent = first.variance / first.n;
    final secondComponent = second.variance / second.n;
    final meanDifference = first.mean - second.mean;
    final standardError = checkedStandardError(
      math.sqrt(firstComponent + secondComponent),
      'independent Welch',
    );
    final dfDenominator =
        firstComponent * firstComponent / (first.n - 1) +
        secondComponent * secondComponent / (second.n - 1);
    if (dfDenominator <= 0 || !dfDenominator.isFinite) {
      throw StatsException('Welch-Satterthwaite df is undefined.');
    }
    final df =
        math.pow(firstComponent + secondComponent, 2).toDouble() /
        dfDenominator;
    final unweightedSd = math.sqrt((first.variance + second.variance) / 2);
    final t = meanDifference / standardError;
    return _finish(
      kind: TTestKind.independentWelch,
      meanDifference: meanDifference,
      standardError: standardError,
      t: t,
      degreesOfFreedom: df,
      confidenceLevel: confidenceLevel,
      effectSize: _effectSize(
        d: meanDifference / _checkedStandardizer(unweightedSd, 'unweighted SD'),
        dfForCorrection: (first.n + second.n - 2).toDouble(),
        standardizer:
            'unweighted root mean of group variances (Welch d_s convention)',
        standardizerValue: unweightedSd,
      ),
      primary: first,
      secondary: second,
    );
  }

  static TTestResult independentWelchFromRaw({
    required Iterable<num> first,
    required Iterable<num> second,
    double confidenceLevel = 0.95,
  }) {
    return independentWelchFromSummary(
      first: SummaryStats.fromValues(first),
      second: SummaryStats.fromValues(second),
      confidenceLevel: confidenceLevel,
    );
  }

  static TTestResult pairedFromSummary({
    required PairedSummaryStats summary,
    double confidenceLevel = 0.95,
  }) {
    _validateConfidenceLevel(confidenceLevel);
    final df = (summary.n - 1).toDouble();
    final meanDifference = summary.meanDifference;
    final standardError = checkedStandardError(
      summary.differenceStandardDeviation / math.sqrt(summary.n),
      'paired samples',
    );
    final t = meanDifference / standardError;
    return _finish(
      kind: TTestKind.pairedSamples,
      meanDifference: meanDifference,
      standardError: standardError,
      t: t,
      degreesOfFreedom: df,
      confidenceLevel: confidenceLevel,
      effectSize: _effectSize(
        d:
            meanDifference /
            _checkedStandardizer(
              summary.differenceStandardDeviation,
              'difference SD',
            ),
        dfForCorrection: df,
        standardizer: 'sample SD of paired differences (Cohen dz convention)',
        standardizerValue: summary.differenceStandardDeviation,
      ),
      primary: summary.first,
      secondary: summary.second,
      pairedDifferences: summary.differences,
    );
  }

  static TTestResult pairedFromRaw({
    required Iterable<num> first,
    required Iterable<num> second,
    double confidenceLevel = 0.95,
  }) {
    return pairedFromSummary(
      summary: PairedSummaryStats.fromRawValues(first, second),
      confidenceLevel: confidenceLevel,
    );
  }

  static TTestResult oneSampleFromSummary({
    required SummaryStats sample,
    required double referenceMean,
    double confidenceLevel = 0.95,
  }) {
    _validateConfidenceLevel(confidenceLevel);
    requireFinite(referenceMean, 'reference mean');
    final df = (sample.n - 1).toDouble();
    final meanDifference = sample.mean - referenceMean;
    final standardError = checkedStandardError(
      sample.standardDeviation / math.sqrt(sample.n),
      'one sample',
    );
    final t = meanDifference / standardError;
    return _finish(
      kind: TTestKind.oneSample,
      meanDifference: meanDifference,
      standardError: standardError,
      t: t,
      degreesOfFreedom: df,
      confidenceLevel: confidenceLevel,
      effectSize: _effectSize(
        d:
            meanDifference /
            _checkedStandardizer(sample.standardDeviation, 'sample SD'),
        dfForCorrection: df,
        standardizer: 'sample SD (one-sample standardized mean difference)',
        standardizerValue: sample.standardDeviation,
      ),
      primary: sample,
      referenceMean: referenceMean,
    );
  }

  static TTestResult oneSampleFromRaw({
    required Iterable<num> values,
    required double referenceMean,
    double confidenceLevel = 0.95,
  }) {
    return oneSampleFromSummary(
      sample: SummaryStats.fromValues(values),
      referenceMean: referenceMean,
      confidenceLevel: confidenceLevel,
    );
  }

  static TTestResult _finish({
    required TTestKind kind,
    required double meanDifference,
    required double standardError,
    required double t,
    required double degreesOfFreedom,
    required double confidenceLevel,
    required EffectSize effectSize,
    required SummaryStats primary,
    SummaryStats? secondary,
    SummaryStats? pairedDifferences,
    double? referenceMean,
  }) {
    requireFinite(t, 't');
    requirePositive(degreesOfFreedom, 'degrees of freedom');
    final distribution = TDistribution(degreesOfFreedom);
    final cdf = distribution.cdf(t);
    final pLess = cdf;
    final pGreater = clampProbability(1 - cdf);
    final pOneTailed = math.min(pLess, pGreater);
    final pTwoTailed = clampProbability(2 * pOneTailed);
    final alpha = 1 - confidenceLevel;
    final critical = distribution.quantile(1 - alpha / 2);
    final margin = critical * standardError;

    return TTestResult(
      kind: kind,
      meanDifference: meanDifference,
      standardError: standardError,
      t: t,
      degreesOfFreedom: degreesOfFreedom,
      pTwoTailed: pTwoTailed,
      pOneTailed: pOneTailed,
      pLess: pLess,
      pGreater: pGreater,
      confidenceInterval: ConfidenceInterval(
        level: confidenceLevel,
        lower: meanDifference - margin,
        upper: meanDifference + margin,
      ),
      effectSize: effectSize,
      primary: primary,
      secondary: secondary,
      pairedDifferences: pairedDifferences,
      referenceMean: referenceMean,
    );
  }

  static EffectSize _effectSize({
    required double d,
    required double dfForCorrection,
    required String standardizer,
    required double standardizerValue,
  }) {
    final correction = dfForCorrection > 1
        ? hedgesCorrection(dfForCorrection)
        : null;
    return EffectSize(
      cohensD: d,
      hedgesG: correction == null ? null : d * correction,
      correction: correction,
      standardizer: standardizer,
      standardizerValue: standardizerValue,
    );
  }

  static double hedgesCorrection(double degreesOfFreedom) {
    requirePositive(degreesOfFreedom, 'Hedges correction df');
    if (degreesOfFreedom <= 1) {
      throw StatsException("Hedges' correction requires df > 1.");
    }
    return math.exp(
      SpecialFunctions.logGamma(degreesOfFreedom / 2) -
          0.5 * math.log(degreesOfFreedom / 2) -
          SpecialFunctions.logGamma((degreesOfFreedom - 1) / 2),
    );
  }

  static double _checkedStandardizer(double value, String label) {
    requireFinite(value, label);
    if (value <= 0) {
      throw StatsException('$label is zero; effect size is undefined.');
    }
    return value;
  }

  static void _validateConfidenceLevel(double confidenceLevel) {
    requireProbability(confidenceLevel, 'confidence level');
    if (confidenceLevel <= 0 || confidenceLevel >= 1) {
      throw StatsException('confidence level must be inside (0, 1).');
    }
  }
}
