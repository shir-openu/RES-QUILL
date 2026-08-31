import 'dart:math' as math;

import 'descriptives.dart';
import 'distributions.dart';
import 'numeric.dart';
import 't_tests.dart';

enum ValidationStatus { pass, fail, notApplicable }

enum ReportedRelation {
  equalRounded,
  lessThan,
  lessThanOrEqual,
  greaterThan,
  greaterThanOrEqual,
}

enum ReportedPValueTail { twoTailed, oneTailedObservedDirection, less, greater }

class ReportedValue {
  ReportedValue({
    required this.value,
    required this.decimalPlaces,
    this.relation = ReportedRelation.equalRounded,
  }) {
    requireFinite(value, 'reported value');
    if (decimalPlaces < 0) {
      throw StatsException('decimalPlaces must be non-negative.');
    }
  }

  final double value;
  final int decimalPlaces;
  final ReportedRelation relation;

  double get tolerance => 0.5 * math.pow(10, -decimalPlaces).toDouble() + 1e-12;

  double effectiveTolerance({double minimumTolerance = 0}) {
    return math.max(tolerance, minimumTolerance);
  }

  String toleranceDescription({double minimumTolerance = 0}) {
    if (relation == ReportedRelation.equalRounded) {
      final effective = effectiveTolerance(minimumTolerance: minimumTolerance);
      if (effective > tolerance) {
        return 'reported inputs were rounded, so tolerance is +/- '
            '${_formatFixed(effective, decimalPlaces + 1)}';
      }
      return 'value was rounded to ${_decimalPlacesText(decimalPlaces)}, '
          'so tolerance is +/- ${_formatFixed(effective, decimalPlaces + 1)}';
    }
    final formattedValue = _formatFixed(value, decimalPlaces);
    return 'reported as ${_relationSymbol(relation)} $formattedValue; '
        'calculated value must be ${_relationSymbol(relation)} $formattedValue';
  }

  bool accepts(double recomputed, {double minimumTolerance = 0}) {
    requireFinite(recomputed, 'recomputed value');
    switch (relation) {
      case ReportedRelation.equalRounded:
        return (recomputed - value).abs() <=
            effectiveTolerance(minimumTolerance: minimumTolerance);
      case ReportedRelation.lessThan:
        return recomputed < value;
      case ReportedRelation.lessThanOrEqual:
        return recomputed <= value;
      case ReportedRelation.greaterThan:
        return recomputed > value;
      case ReportedRelation.greaterThanOrEqual:
        return recomputed >= value;
    }
  }
}

class ValidationCheck {
  ValidationCheck({
    required this.id,
    required this.title,
    required this.status,
    required this.explanation,
    this.recomputed,
    this.reported,
    this.tolerance,
  });

  final String id;
  final String title;
  final ValidationStatus status;
  final String explanation;
  final double? recomputed;
  final double? reported;
  final String? tolerance;
}

class ReportedDescriptives {
  ReportedDescriptives({
    required this.n,
    required this.mean,
    required this.standardDeviation,
    this.label,
  });

  final int? n;
  final double? mean;
  final double? standardDeviation;
  final String? label;

  SummaryStats toSummaryStats() {
    if (n == null || mean == null || standardDeviation == null) {
      throw StatsException('${label ?? 'Group'} descriptives are incomplete.');
    }
    return SummaryStats(
      n: n!,
      mean: mean!,
      standardDeviation: standardDeviation!,
    );
  }
}

class ReportedPairedDescriptives {
  ReportedPairedDescriptives({
    required this.first,
    required this.second,
    this.meanDifference,
    this.differenceStandardDeviation,
    this.correlation,
  });

  final ReportedDescriptives first;
  final ReportedDescriptives second;
  final double? meanDifference;
  final double? differenceStandardDeviation;
  final double? correlation;

  PairedSummaryStats toPairedSummaryStats() {
    if (first.n == null || second.n == null) {
      throw StatsException('Paired descriptives are missing n.');
    }
    if (first.n != second.n) {
      throw StatsException('Paired descriptives must have the same n.');
    }
    if (meanDifference != null && differenceStandardDeviation != null) {
      return PairedSummaryStats(
        n: first.n!,
        firstMean: first.mean!,
        firstStandardDeviation: first.standardDeviation!,
        secondMean: second.mean!,
        secondStandardDeviation: second.standardDeviation!,
        meanDifference: meanDifference!,
        differenceStandardDeviation: differenceStandardDeviation!,
        correlation: correlation,
      );
    }
    if (correlation != null) {
      return PairedSummaryStats.fromMarginalsAndCorrelation(
        n: first.n!,
        firstMean: first.mean!,
        firstStandardDeviation: first.standardDeviation!,
        secondMean: second.mean!,
        secondStandardDeviation: second.standardDeviation!,
        correlation: correlation!,
      );
    }
    throw StatsException(
      'Paired summary validation needs the SD of pairwise differences or the '
      'within-pair correlation; marginal SDs alone are insufficient.',
    );
  }
}

class GrimConfig {
  GrimConfig({
    required this.reportedMean,
    required this.n,
    required this.decimalPlaces,
    this.quantum = 1,
    this.label = 'mean',
  }) {
    requireFinite(reportedMean, 'reported mean');
    requirePositive(quantum, 'quantum');
    if (n < 1) {
      throw StatsException('GRIM n must be positive.');
    }
    if (decimalPlaces < 0) {
      throw StatsException('GRIM decimalPlaces must be non-negative.');
    }
  }

  final double reportedMean;
  final int n;
  final int decimalPlaces;
  final double quantum;
  final String label;
}

class TTestValidationInput {
  TTestValidationInput({
    required this.kind,
    this.first,
    this.second,
    this.paired,
    this.referenceMean,
    this.reportedT,
    this.reportedDegreesOfFreedom,
    this.reportedP,
    this.reportedPValueTail = ReportedPValueTail.twoTailed,
    this.reportedMeanDifference,
    this.reportedStandardError,
    this.reportedCiLower,
    this.reportedCiUpper,
    this.confidenceLevel = 0.95,
    this.grimChecks = const [],
  });

  final TTestKind kind;
  final ReportedDescriptives? first;
  final ReportedDescriptives? second;
  final ReportedPairedDescriptives? paired;
  final double? referenceMean;
  final ReportedValue? reportedT;
  final ReportedValue? reportedDegreesOfFreedom;
  final ReportedValue? reportedP;
  final ReportedPValueTail reportedPValueTail;
  final ReportedValue? reportedMeanDifference;
  final ReportedValue? reportedStandardError;
  final ReportedValue? reportedCiLower;
  final ReportedValue? reportedCiUpper;
  final double confidenceLevel;
  final List<GrimConfig> grimChecks;
}

class TTestValidator {
  TTestValidator._();

  static TTestResult resultFromInput(TTestValidationInput input) {
    switch (input.kind) {
      case TTestKind.independentStudent:
        if (input.first == null || input.second == null) {
          throw StatsException('Two independent groups are required.');
        }
        return TTests.independentStudentFromSummary(
          first: input.first!.toSummaryStats(),
          second: input.second!.toSummaryStats(),
          confidenceLevel: input.confidenceLevel,
        );
      case TTestKind.independentWelch:
        if (input.first == null || input.second == null) {
          throw StatsException('Two independent groups are required.');
        }
        return TTests.independentWelchFromSummary(
          first: input.first!.toSummaryStats(),
          second: input.second!.toSummaryStats(),
          confidenceLevel: input.confidenceLevel,
        );
      case TTestKind.pairedSamples:
        if (input.paired == null) {
          throw StatsException('Paired descriptives are required.');
        }
        return TTests.pairedFromSummary(
          summary: input.paired!.toPairedSummaryStats(),
          confidenceLevel: input.confidenceLevel,
        );
      case TTestKind.oneSample:
        if (input.first == null || input.referenceMean == null) {
          throw StatsException('A sample and reference mean are required.');
        }
        return TTests.oneSampleFromSummary(
          sample: input.first!.toSummaryStats(),
          referenceMean: input.referenceMean!,
          confidenceLevel: input.confidenceLevel,
        );
    }
  }

  static List<ValidationCheck> validate(TTestValidationInput input) {
    final checks = <ValidationCheck>[
      ..._domainChecks(input),
      _dfPlausibility(input),
      _tMatchesDescriptives(input),
      _pMatchesTAndDf(input),
      ..._ciMatchesDifferenceAndSe(input),
      ...input.grimChecks.map(_grimCheck),
    ];
    return checks;
  }

  static List<ValidationCheck> _domainChecks(TTestValidationInput input) {
    final checks = <ValidationCheck>[];
    final descriptives = <ReportedDescriptives>[
      if (input.first != null) input.first!,
      if (input.second != null) input.second!,
      if (input.paired != null) input.paired!.first,
      if (input.paired != null) input.paired!.second,
    ];

    for (final descriptive in descriptives) {
      final label = descriptive.label ?? 'Group';
      var valid = true;
      final messages = <String>[];
      if (descriptive.n == null || descriptive.n! < 2) {
        valid = false;
        messages.add('n must be an integer at least 2');
      }
      if (descriptive.mean == null || !descriptive.mean!.isFinite) {
        valid = false;
        messages.add('mean must be finite');
      }
      if (descriptive.standardDeviation == null ||
          !descriptive.standardDeviation!.isFinite ||
          descriptive.standardDeviation! < 0) {
        valid = false;
        messages.add('SD must be finite and non-negative');
      }
      checks.add(
        ValidationCheck(
          id: 'domain.${label.toLowerCase().replaceAll(' ', '_')}',
          title: '$label values are usable',
          status: valid ? ValidationStatus.pass : ValidationStatus.fail,
          explanation: valid
              ? '$label has usable n, mean, and SD.'
              : '$label is invalid: ${messages.join('; ')}.',
        ),
      );
    }

    if (input.reportedP != null) {
      final p = input.reportedP!.value;
      checks.add(
        ValidationCheck(
          id: 'domain.p',
          title: 'Reported p is between 0 and 1',
          status: p >= 0 && p <= 1
              ? ValidationStatus.pass
              : ValidationStatus.fail,
          reported: p,
          tolerance: '[0, 1]',
          explanation: p >= 0 && p <= 1
              ? 'The reported p-value is inside [0, 1].'
              : 'A p-value must be between 0 and 1.',
        ),
      );
    }

    return checks;
  }

  static ValidationCheck _dfPlausibility(TTestValidationInput input) {
    if (input.reportedDegreesOfFreedom == null) {
      return ValidationCheck(
        id: 'df.plausibility',
        title: 'Reported df matches the selected test',
        status: ValidationStatus.notApplicable,
        explanation: 'No reported df was supplied.',
      );
    }

    try {
      final recomputed = resultFromInput(input).degreesOfFreedom;
      return _compare(
        id: 'df.plausibility',
        title: 'Reported df matches the selected test',
        recomputed: recomputed,
        reported: input.reportedDegreesOfFreedom!,
        passExplanation:
            'The reported df matches the stated test and sample sizes.',
        failExplanation:
            'The reported df does not match the stated test and sample sizes.',
      );
    } on StatsException catch (error) {
      return ValidationCheck(
        id: 'df.plausibility',
        title: 'Reported df matches the selected test',
        status: ValidationStatus.notApplicable,
        reported: input.reportedDegreesOfFreedom!.value,
        explanation: error.message,
      );
    }
  }

  static ValidationCheck _tMatchesDescriptives(TTestValidationInput input) {
    if (input.reportedT == null) {
      return ValidationCheck(
        id: 't.descriptives',
        title: 'Reported t matches the descriptive statistics',
        status: ValidationStatus.notApplicable,
        explanation: 'No reported t statistic was supplied.',
      );
    }

    try {
      final recomputed = resultFromInput(input).t;
      return _compare(
        id: 't.descriptives',
        title: 'Reported t matches the descriptive statistics',
        recomputed: recomputed,
        reported: input.reportedT!,
        minimumTolerance: 0.005,
        passExplanation:
            'The reported t matches the means, SDs, ns, and stated test.',
        failExplanation:
            'The reported t does not match the means, SDs, ns, and stated test.',
      );
    } on StatsException catch (error) {
      return ValidationCheck(
        id: 't.descriptives',
        title: 'Reported t matches the descriptive statistics',
        status: ValidationStatus.notApplicable,
        reported: input.reportedT!.value,
        explanation: error.message,
      );
    }
  }

  static ValidationCheck _pMatchesTAndDf(TTestValidationInput input) {
    if (input.reportedP == null) {
      return ValidationCheck(
        id: 'p.t_df',
        title: 'Reported p matches t and df',
        status: ValidationStatus.notApplicable,
        explanation: 'No reported p-value was supplied.',
      );
    }
    if (input.reportedT == null || input.reportedDegreesOfFreedom == null) {
      return ValidationCheck(
        id: 'p.t_df',
        title: 'Reported p matches t and df',
        status: ValidationStatus.notApplicable,
        reported: input.reportedP!.value,
        explanation: 'A reported t and df are required to validate p.',
      );
    }

    try {
      final distribution = TDistribution(input.reportedDegreesOfFreedom!.value);
      final cdf = distribution.cdf(input.reportedT!.value);
      final recomputed = switch (input.reportedPValueTail) {
        ReportedPValueTail.twoTailed => clampProbability(
          2 * math.min(cdf, 1 - cdf),
        ),
        ReportedPValueTail.oneTailedObservedDirection => math.min(cdf, 1 - cdf),
        ReportedPValueTail.less => cdf,
        ReportedPValueTail.greater => clampProbability(1 - cdf),
      };
      return _compare(
        id: 'p.t_df',
        title: 'Reported p matches t and df',
        recomputed: recomputed,
        reported: input.reportedP!,
        passExplanation: 'The reported p matches the reported t and df.',
        failExplanation: 'The reported p does not match the reported t and df.',
      );
    } on StatsException catch (error) {
      return ValidationCheck(
        id: 'p.t_df',
        title: 'Reported p matches t and df',
        status: ValidationStatus.notApplicable,
        reported: input.reportedP!.value,
        explanation: error.message,
      );
    }
  }

  static List<ValidationCheck> _ciMatchesDifferenceAndSe(
    TTestValidationInput input,
  ) {
    if (input.reportedMeanDifference == null ||
        input.reportedStandardError == null ||
        input.reportedDegreesOfFreedom == null ||
        input.reportedCiLower == null ||
        input.reportedCiUpper == null) {
      return [
        ValidationCheck(
          id: 'ci.diff_se',
          title: 'Confidence interval has enough values to check',
          status: ValidationStatus.notApplicable,
          explanation:
              'Mean difference, SE, df, and both CI bounds are required to validate CI.',
        ),
      ];
    }

    try {
      final level = input.confidenceLevel;
      if (level <= 0 || level >= 1) {
        throw StatsException('confidence level must be inside (0, 1).');
      }
      final critical = TDistribution(
        input.reportedDegreesOfFreedom!.value,
      ).quantile(1 - (1 - level) / 2);
      final margin = critical * input.reportedStandardError!.value;
      final recomputedLower = input.reportedMeanDifference!.value - margin;
      final recomputedUpper = input.reportedMeanDifference!.value + margin;
      return [
        _compare(
          id: 'ci.lower',
          title: 'Lower CI bound matches the reported difference and SE',
          recomputed: recomputedLower,
          reported: input.reportedCiLower!,
          minimumTolerance: 0.001,
          passExplanation:
              'The lower CI bound matches the reported mean difference, SE, df, and confidence level.',
          failExplanation:
              'The lower CI bound does not match the reported mean difference, SE, df, and confidence level.',
        ),
        _compare(
          id: 'ci.upper',
          title: 'Upper CI bound matches the reported difference and SE',
          recomputed: recomputedUpper,
          reported: input.reportedCiUpper!,
          minimumTolerance: 0.001,
          passExplanation:
              'The upper CI bound matches the reported mean difference, SE, df, and confidence level.',
          failExplanation:
              'The upper CI bound does not match the reported mean difference, SE, df, and confidence level.',
        ),
      ];
    } on StatsException catch (error) {
      return [
        ValidationCheck(
          id: 'ci.diff_se',
          title: 'Confidence interval has enough values to check',
          status: ValidationStatus.notApplicable,
          reported: input.reportedCiLower!.value,
          explanation: error.message,
        ),
      ];
    }
  }

  static ValidationCheck _grimCheck(GrimConfig config) {
    final step = math.pow(10, -config.decimalPlaces).toDouble();
    final lower = config.reportedMean - step / 2 - 1e-12;
    final upper = config.reportedMean + step / 2 + 1e-12;
    final minSum = (lower * config.n / config.quantum).ceil();
    final maxSum = ((upper * config.n / config.quantum) - 1e-12).floor();
    final attainable = minSum <= maxSum;
    final nearest = (config.reportedMean * config.n / config.quantum).round();
    final nearestMean = nearest * config.quantum / config.n;

    return ValidationCheck(
      id: 'grim.${config.label.toLowerCase().replaceAll(' ', '_')}',
      title: 'Rounded mean is possible for ${config.label}',
      status: attainable ? ValidationStatus.pass : ValidationStatus.fail,
      recomputed: nearestMean,
      reported: config.reportedMean,
      tolerance: 'rounded integer-data mean at n=${config.n}',
      explanation: attainable
          ? '${config.label} is attainable as a rounded mean of integer-valued data.'
          : '${config.label} is not attainable as a rounded mean of integer-valued data at this n.',
    );
  }

  static ValidationCheck _compare({
    required String id,
    required String title,
    required double recomputed,
    required ReportedValue reported,
    double minimumTolerance = 0,
    required String passExplanation,
    required String failExplanation,
  }) {
    final pass = reported.accepts(
      recomputed,
      minimumTolerance: minimumTolerance,
    );
    return ValidationCheck(
      id: id,
      title: title,
      status: pass ? ValidationStatus.pass : ValidationStatus.fail,
      recomputed: recomputed,
      reported: reported.value,
      tolerance: reported.toleranceDescription(
        minimumTolerance: minimumTolerance,
      ),
      explanation: pass ? passExplanation : failExplanation,
    );
  }
}

String _decimalPlacesText(int decimalPlaces) {
  return decimalPlaces == 1 ? '1 decimal' : '$decimalPlaces decimals';
}

String _formatFixed(double value, int decimals) {
  final fixed = value.toStringAsFixed(math.max(0, decimals));
  if (!fixed.contains('.')) {
    return fixed;
  }
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _relationSymbol(ReportedRelation relation) {
  return switch (relation) {
    ReportedRelation.equalRounded => '=',
    ReportedRelation.lessThan => '<',
    ReportedRelation.lessThanOrEqual => '<=',
    ReportedRelation.greaterThan => '>',
    ReportedRelation.greaterThanOrEqual => '>=',
  };
}
