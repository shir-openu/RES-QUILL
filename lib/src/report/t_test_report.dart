import '../stats/stats.dart';
import 'evidence_map.dart';
import 'formatted_text.dart';

enum ReportGenerationStatus { generated, blocked }

enum ReportTail { twoTailed, less, greater }

enum DirectionalClaim { none, primaryGreater, primaryLess }

class UserClaimContext {
  const UserClaimContext({
    this.text,
    this.direction = DirectionalClaim.none,
    this.impliesCausation = false,
  });

  final String? text;
  final DirectionalClaim direction;
  final bool impliesCausation;

  bool get hasCausalFraming {
    return impliesCausation || _causalPattern.hasMatch(text ?? '');
  }

  static final RegExp _causalPattern = RegExp(
    r'\b(causal|causation|caused|because of|due to|leads? to|'
    r'results? in|resulted in|impact(?:s|ed)?|influence(?:s|d)?)\b',
    caseSensitive: false,
  );
}

class EffectSizeBand {
  const EffectSizeBand({
    required this.minimumInclusive,
    required this.maximumExclusive,
    required this.label,
  });

  final double minimumInclusive;
  final double maximumExclusive;
  final String label;

  bool accepts(double value) {
    return value >= minimumInclusive && value < maximumExclusive;
  }
}

class EffectSizeBenchmark {
  EffectSizeBenchmark({required this.sourceLabel, required this.bands});

  factory EffectSizeBenchmark.cohenBehavioralScience() {
    return EffectSizeBenchmark(
      sourceLabel: 'Cohen (1988)',
      bands: const [
        EffectSizeBand(
          minimumInclusive: 0,
          maximumExclusive: 0.2,
          label: 'below the small benchmark',
        ),
        EffectSizeBand(
          minimumInclusive: 0.2,
          maximumExclusive: 0.5,
          label: 'small',
        ),
        EffectSizeBand(
          minimumInclusive: 0.5,
          maximumExclusive: 0.8,
          label: 'medium',
        ),
        EffectSizeBand(
          minimumInclusive: 0.8,
          maximumExclusive: double.infinity,
          label: 'large',
        ),
      ],
    );
  }

  final String sourceLabel;
  final List<EffectSizeBand> bands;

  String labelFor(double value) {
    final magnitude = value.abs();
    return bands.singleWhere((band) => band.accepts(magnitude)).label;
  }

  String classificationFor(double value) {
    final label = labelFor(value);
    if (label == 'small' || label == 'medium' || label == 'large') {
      return 'a $label effect';
    }
    return label;
  }
}

class TTestReportOptions {
  TTestReportOptions({
    this.tail = ReportTail.twoTailed,
    this.alpha = 0.05,
    this.descriptiveDecimals = 2,
    this.testStatisticDecimals = 2,
    this.effectDecimals = 2,
    this.pDecimals = 3,
    EffectSizeBenchmark? effectSizeBenchmark,
  }) : effectSizeBenchmark =
           effectSizeBenchmark ?? EffectSizeBenchmark.cohenBehavioralScience() {
    requireProbability(alpha, 'alpha');
    if (alpha <= 0 || alpha >= 1) {
      throw StatsException('alpha must be inside (0, 1).');
    }
    if (descriptiveDecimals < 0 ||
        testStatisticDecimals < 0 ||
        effectDecimals < 0 ||
        pDecimals < 0) {
      throw StatsException('decimal counts must be non-negative.');
    }
    if (pDecimals != 2 && pDecimals != 3) {
      throw StatsException('APA p-value decimals must be 2 or 3.');
    }
  }

  final ReportTail tail;
  final double alpha;
  final int descriptiveDecimals;
  final int testStatisticDecimals;
  final int effectDecimals;
  final int pDecimals;
  final EffectSizeBenchmark? effectSizeBenchmark;
}

class TTestReportContext {
  const TTestReportContext({
    this.outcomeLabel = 'scores',
    this.primaryLabel = 'Group 1',
    this.secondaryLabel,
    this.referenceLabel = 'the reference value',
    this.userClaim = const UserClaimContext(),
  });

  final String outcomeLabel;
  final String primaryLabel;
  final String? secondaryLabel;
  final String referenceLabel;
  final UserClaimContext userClaim;
}

class TTestReportOutput {
  TTestReportOutput._({
    required this.status,
    required this.validationChecks,
    required this.evidenceMap,
    this.refusalReason,
    this.formalResult,
    this.descriptivesSentence,
    this.plainLanguageMeaning,
    this.effectSizeSentence,
    this.roundingCautions = const [],
    this.supportedClaims = const [],
    this.unsupportedClaims = const [],
  });

  factory TTestReportOutput.blocked({
    required String refusalReason,
    required List<ValidationCheck> validationChecks,
  }) {
    return TTestReportOutput._(
      status: ReportGenerationStatus.blocked,
      refusalReason: refusalReason,
      validationChecks: List.unmodifiable(validationChecks),
      evidenceMap: const EvidenceMap([]),
    );
  }

  factory TTestReportOutput.generated({
    required ReportText formalResult,
    required String descriptivesSentence,
    required String plainLanguageMeaning,
    required String effectSizeSentence,
    required EvidenceMap evidenceMap,
    required List<ValidationCheck> validationChecks,
    required List<String> roundingCautions,
    required List<String> supportedClaims,
    required List<String> unsupportedClaims,
  }) {
    return TTestReportOutput._(
      status: ReportGenerationStatus.generated,
      formalResult: formalResult,
      descriptivesSentence: descriptivesSentence,
      plainLanguageMeaning: plainLanguageMeaning,
      effectSizeSentence: effectSizeSentence,
      evidenceMap: evidenceMap,
      validationChecks: List.unmodifiable(validationChecks),
      roundingCautions: List.unmodifiable(roundingCautions),
      supportedClaims: List.unmodifiable(supportedClaims),
      unsupportedClaims: List.unmodifiable(unsupportedClaims),
    );
  }

  final ReportGenerationStatus status;
  final String? refusalReason;
  final ReportText? formalResult;
  final String? descriptivesSentence;
  final String? plainLanguageMeaning;
  final String? effectSizeSentence;
  final EvidenceMap evidenceMap;
  final List<ValidationCheck> validationChecks;
  final List<String> roundingCautions;
  final List<String> supportedClaims;
  final List<String> unsupportedClaims;

  bool get isBlocked => status == ReportGenerationStatus.blocked;
}

class TTestReportGenerator {
  const TTestReportGenerator._();

  static TTestReportOutput generate({
    required TTestResult result,
    required List<ValidationCheck> validationChecks,
    TTestReportContext context = const TTestReportContext(),
    TTestReportOptions? options,
    EvidenceSourceRegistry? evidenceSources,
  }) {
    final failedChecks = validationChecks
        .where((check) => check.status == ValidationStatus.fail)
        .toList();
    if (failedChecks.isNotEmpty) {
      return TTestReportOutput.blocked(
        refusalReason: _refusalReason(failedChecks),
        validationChecks: validationChecks,
      );
    }

    final resolvedOptions = options ?? TTestReportOptions();
    final resolvedSources = evidenceSources ?? EvidenceSourceRegistry();
    final evidence = _EvidenceBuilder(resolvedSources);
    final formal = _formalResult(
      result: result,
      context: context,
      options: resolvedOptions,
      evidence: evidence,
    );
    final descriptives = _descriptivesSentence(
      result: result,
      context: context,
      options: resolvedOptions,
      evidence: evidence,
    );
    final plainLanguage = _plainLanguageMeaning(
      result: result,
      context: context,
      options: resolvedOptions,
    );
    final effectSize = _effectSizeSentence(
      result: result,
      options: resolvedOptions,
      evidence: evidence,
    );
    final roundingCautions = _roundingCautions(
      result: result,
      options: resolvedOptions,
      evidence: evidence,
    );
    final claims = _claimLists(
      result: result,
      context: context,
      options: resolvedOptions,
    );

    return TTestReportOutput.generated(
      formalResult: formal,
      descriptivesSentence: descriptives,
      plainLanguageMeaning: plainLanguage,
      effectSizeSentence: effectSize,
      evidenceMap: EvidenceMap(List.unmodifiable(evidence.entries)),
      validationChecks: validationChecks,
      roundingCautions: roundingCautions,
      supportedClaims: claims.supported,
      unsupportedClaims: claims.unsupported,
    );
  }

  static String _refusalReason(List<ValidationCheck> failedChecks) {
    final details = failedChecks
        .map((check) => '${check.id}: ${check.explanation}')
        .join(' ');
    return 'Wording blocked because validation failed. $details';
  }

  static ReportText _formalResult({
    required TTestResult result,
    required TTestReportContext context,
    required TTestReportOptions options,
    required _EvidenceBuilder evidence,
  }) {
    final builder = ReportTextBuilder();
    final p = _pForTail(result, options.tail);
    final formattedP = ApaNumberFormat.pValue(
      p.value,
      decimals: options.pDecimals,
    );
    final formattedDf = ApaNumberFormat.df(
      result.degreesOfFreedom,
      welch: result.kind == TTestKind.independentWelch,
    );
    final formattedT = ApaNumberFormat.value(
      result.t,
      decimals: options.testStatisticDecimals,
    );
    final ciLevel = ApaNumberFormat.percent(result.confidenceInterval.level);
    final ciLower = ApaNumberFormat.value(
      result.confidenceInterval.lower,
      decimals: options.descriptiveDecimals,
    );
    final ciUpper = ApaNumberFormat.value(
      result.confidenceInterval.upper,
      decimals: options.descriptiveDecimals,
    );

    evidence.add(
      id: 'formal.df',
      section: 'formalResult',
      label: 'df',
      value: result.degreesOfFreedom,
      formatted: formattedDf,
      sourceKey: 'degreesOfFreedom',
      fallbackField: 'result.degreesOfFreedom',
    );
    evidence.add(
      id: 'formal.t',
      section: 'formalResult',
      label: 't',
      value: result.t,
      formatted: formattedT,
      sourceKey: 't',
      fallbackField: 'result.t',
    );
    evidence.add(
      id: 'formal.p',
      section: 'formalResult',
      label: p.label,
      value: p.value,
      formatted: formattedP.text,
      relation: formattedP.relation,
      sourceKey: p.sourceKey,
      fallbackField: 'result.${p.sourceKey}',
    );
    evidence.add(
      id: 'formal.ciLevel',
      section: 'formalResult',
      label: 'CI level',
      value: result.confidenceInterval.level,
      formatted: ciLevel,
      sourceKey: 'confidenceInterval.level',
      fallbackField: 'result.confidenceInterval.level',
    );
    evidence.add(
      id: 'formal.ciLower',
      section: 'formalResult',
      label: 'CI lower',
      value: result.confidenceInterval.lower,
      formatted: ciLower,
      sourceKey: 'confidenceInterval.lower',
      fallbackField: 'result.confidenceInterval.lower',
    );
    evidence.add(
      id: 'formal.ciUpper',
      section: 'formalResult',
      label: 'CI upper',
      value: result.confidenceInterval.upper,
      formatted: ciUpper,
      sourceKey: 'confidenceInterval.upper',
      fallbackField: 'result.confidenceInterval.upper',
    );

    builder.add(
      'A ${_tailAdjective(options.tail)} ${_testLabel(result.kind)} ',
    );
    builder.italic('t');
    builder.add(' test ${_findingPhrase(result, context, options)}, ');
    builder.italic('t');
    builder.add('($formattedDf) = $formattedT, ');
    builder.italic('p');
    builder.add(' ${formattedP.display}, $ciLevel CI [$ciLower, $ciUpper].');
    return builder.build();
  }

  static String _descriptivesSentence({
    required TTestResult result,
    required TTestReportContext context,
    required TTestReportOptions options,
    required _EvidenceBuilder evidence,
  }) {
    final primary = _groupStats(
      result.primary,
      prefix: 'primary',
      sectionPrefix: 'descriptives.primary',
      options: options,
      evidence: evidence,
    );

    switch (result.kind) {
      case TTestKind.independentStudent:
      case TTestKind.independentWelch:
        final secondary = _groupStats(
          result.secondary!,
          prefix: 'secondary',
          sectionPrefix: 'descriptives.secondary',
          options: options,
          evidence: evidence,
        );
        return '${_label(context.primaryLabel, 'Group 1')} had a mean '
            'of ${primary.mean} (SD = ${primary.sd}, n = ${primary.n}), and '
            '${_label(context.secondaryLabel, 'Group 2')} had a mean of '
            '${secondary.mean} (SD = ${secondary.sd}, n = ${secondary.n}).';
      case TTestKind.pairedSamples:
        final secondary = _groupStats(
          result.secondary!,
          prefix: 'secondary',
          sectionPrefix: 'descriptives.secondary',
          options: options,
          evidence: evidence,
        );
        final differences = _groupStats(
          result.pairedDifferences!,
          prefix: 'pairedDifferences',
          sectionPrefix: 'descriptives.pairedDifference',
          options: options,
          evidence: evidence,
        );
        return '${_label(context.primaryLabel, 'First measurement')} scores '
            'had M = ${primary.mean} (SD = ${primary.sd}, n = ${primary.n}), '
            'and ${_label(context.secondaryLabel, 'second measurement')} '
            'scores had M = ${secondary.mean} (SD = ${secondary.sd}, '
            'n = ${secondary.n}); the mean paired difference was '
            '${differences.mean} (SD = ${differences.sd}, n = '
            '${differences.n}).';
      case TTestKind.oneSample:
        final reference = ApaNumberFormat.value(
          result.referenceMean!,
          decimals: options.descriptiveDecimals,
        );
        evidence.add(
          id: 'descriptives.referenceMean',
          section: 'descriptives',
          label: 'reference mean',
          value: result.referenceMean!,
          formatted: reference,
          sourceKey: 'referenceMean',
          fallbackField: 'result.referenceMean',
        );
        return '${_label(context.primaryLabel, 'The sample')} had M = '
            '${primary.mean} (SD = ${primary.sd}, n = ${primary.n}), compared '
            'with ${_label(context.referenceLabel, 'the reference value')} '
            '($reference).';
    }
  }

  static String _plainLanguageMeaning({
    required TTestResult result,
    required TTestReportContext context,
    required TTestReportOptions options,
  }) {
    final p = _pForTail(result, options.tail).value;
    final significant = p < options.alpha;
    final direction = _observedDirection(result, context);
    if (significant) {
      return 'The sample data provided statistical evidence that $direction. '
          'This comparison does not explain why the pattern occurred.';
    }
    if (options.tail == ReportTail.twoTailed) {
      return 'The sample data did not provide evidence of a difference at the '
          'selected threshold. The observed sample pattern was that '
          '$direction.';
    }
    return 'The sample data did not provide evidence in the tested one-tailed '
        'direction at the selected threshold. The observed sample pattern was '
        'that $direction.';
  }

  static String _effectSizeSentence({
    required TTestResult result,
    required TTestReportOptions options,
    required _EvidenceBuilder evidence,
  }) {
    final d = ApaNumberFormat.value(
      result.effectSize.cohensD,
      decimals: options.effectDecimals,
    );
    evidence.add(
      id: 'effect.cohensD',
      section: 'effectSize',
      label: "Cohen's d",
      value: result.effectSize.cohensD,
      formatted: d,
      sourceKey: 'effectSize.cohensD',
      fallbackField: 'result.effectSize.cohensD',
    );

    final buffer = StringBuffer(
      "The effect size was Cohen's d = $d using "
      '${result.effectSize.standardizer}',
    );
    if (result.effectSize.hedgesG != null) {
      final g = ApaNumberFormat.value(
        result.effectSize.hedgesG!,
        decimals: options.effectDecimals,
      );
      evidence.add(
        id: 'effect.hedgesG',
        section: 'effectSize',
        label: "Hedges' g",
        value: result.effectSize.hedgesG!,
        formatted: g,
        sourceKey: 'effectSize.hedgesG',
        fallbackField: 'result.effectSize.hedgesG',
      );
      buffer.write("; Hedges' g = $g after small-sample correction");
    } else {
      buffer.write("; Hedges' g is unavailable for this degrees of freedom");
    }

    final benchmark = options.effectSizeBenchmark;
    if (benchmark != null) {
      buffer.write(
        '; ${benchmark.sourceLabel} would classify this as '
        '${benchmark.classificationFor(result.effectSize.cohensD)}',
      );
    }
    buffer.write('.');
    return buffer.toString();
  }

  static List<String> _roundingCautions({
    required TTestResult result,
    required TTestReportOptions options,
    required _EvidenceBuilder evidence,
  }) {
    final p = _pForTail(result, options.tail).value;
    final rounded = double.parse(p.toStringAsFixed(options.pDecimals));
    final roundedAlpha = double.parse(
      options.alpha.toStringAsFixed(options.pDecimals),
    );
    final exactDecision = p < options.alpha;
    final roundedDecision = rounded < roundedAlpha;
    final sameRoundedValue = rounded == roundedAlpha;
    if (!sameRoundedValue && exactDecision == roundedDecision) {
      return const [];
    }

    final exactP = ApaNumberFormat.probability(p, decimals: 4);
    evidence.add(
      id: 'rounding.pExact',
      section: 'roundingCautions',
      label: 'unrounded p',
      value: p,
      formatted: exactP,
      sourceKey: _pForTail(result, options.tail).sourceKey,
      fallbackField: 'result.${_pForTail(result, options.tail).sourceKey}',
    );
    return [
      'The unrounded p-value is close to the decision boundary; use '
          'p = $exactP, not the rounded display alone.',
    ];
  }

  static _ClaimLists _claimLists({
    required TTestResult result,
    required TTestReportContext context,
    required TTestReportOptions options,
  }) {
    final p = _pForTail(result, options.tail).value;
    final significant = p < options.alpha;
    final sign = result.meanDifference.compareTo(0);
    final supported = <String>[
      'The output can describe the observed sample mean difference.',
      significant
          ? 'The selected-tail p-value is below the selected threshold.'
          : 'The selected-tail p-value is not below the selected threshold.',
      if (sign > 0) _claimDirectionSentence(result, context),
      if (sign < 0) _claimDirectionSentence(result, context),
      if (sign == 0)
        'The observed sample mean difference is zero in the supplied data.',
    ];

    final unsupported = <String>[
      'A causal conclusion from this t test alone.',
      'A conclusion that the null hypothesis is true when the result is not statistically significant.',
      'Generalization beyond the sampled population without a defensible sampling design.',
      'Practical importance from p alone; inspect effect size and context.',
    ];

    if (context.userClaim.hasCausalFraming) {
      unsupported.add(
        "The user's framing sounds causal; rewrite it as an association or "
        'mean-difference claim.',
      );
    }

    if (_directionConflicts(context.userClaim.direction, sign)) {
      unsupported.add(
        'The supplied directional claim conflicts with the observed '
        'mean-difference sign.',
      );
    }

    if (_tailConflicts(options.tail, sign)) {
      unsupported.add(
        'The selected one-tailed direction conflicts with the observed '
        'mean-difference sign.',
      );
    }

    return _ClaimLists(
      supported: List.unmodifiable(supported),
      unsupported: List.unmodifiable(unsupported),
    );
  }

  static String _claimDirectionSentence(
    TTestResult result,
    TTestReportContext context,
  ) {
    final phrase = result.meanDifference > 0
        ? _positiveDirection(result, context)
        : _negativeDirection(result, context);
    return '${phrase.substring(0, 1).toUpperCase()}${phrase.substring(1)}.';
  }

  static _FormattedGroupStats _groupStats(
    SummaryStats stats, {
    required String prefix,
    required String sectionPrefix,
    required TTestReportOptions options,
    required _EvidenceBuilder evidence,
  }) {
    final mean = ApaNumberFormat.value(
      stats.mean,
      decimals: options.descriptiveDecimals,
    );
    final sd = ApaNumberFormat.value(
      stats.standardDeviation,
      decimals: options.descriptiveDecimals,
    );
    final n = stats.n.toString();
    evidence
      ..add(
        id: '$sectionPrefix.mean',
        section: 'descriptives',
        label: '$prefix mean',
        value: stats.mean,
        formatted: mean,
        sourceKey: '$prefix.mean',
      )
      ..add(
        id: '$sectionPrefix.sd',
        section: 'descriptives',
        label: '$prefix SD',
        value: stats.standardDeviation,
        formatted: sd,
        sourceKey: '$prefix.standardDeviation',
      )
      ..add(
        id: '$sectionPrefix.n',
        section: 'descriptives',
        label: '$prefix n',
        value: stats.n.toDouble(),
        formatted: n,
        sourceKey: '$prefix.n',
      );
    return _FormattedGroupStats(mean: mean, sd: sd, n: n);
  }

  static _SelectedP _pForTail(TTestResult result, ReportTail tail) {
    return switch (tail) {
      ReportTail.twoTailed => _SelectedP(
        value: result.pTwoTailed,
        sourceKey: 'pTwoTailed',
        label: 'two-tailed p',
      ),
      ReportTail.less => _SelectedP(
        value: result.pLess,
        sourceKey: 'pLess',
        label: 'lower-tail p',
      ),
      ReportTail.greater => _SelectedP(
        value: result.pGreater,
        sourceKey: 'pGreater',
        label: 'upper-tail p',
      ),
    };
  }

  static String _findingPhrase(
    TTestResult result,
    TTestReportContext context,
    TTestReportOptions options,
  ) {
    final p = _pForTail(result, options.tail).value;
    final significant = p < options.alpha;
    final comparison = _comparisonLabel(result, context);
    if (options.tail == ReportTail.twoTailed) {
      return significant
          ? 'showed a statistically significant difference in '
                '${_label(context.outcomeLabel, 'scores')} between $comparison'
          : 'did not provide evidence of a difference in '
                '${_label(context.outcomeLabel, 'scores')} between $comparison';
    }

    final direction = options.tail == ReportTail.greater
        ? _positiveDirection(result, context)
        : _negativeDirection(result, context);
    return significant
        ? 'showed evidence in the tested direction that $direction'
        : 'did not provide evidence in the tested direction that $direction';
  }

  static String _observedDirection(
    TTestResult result,
    TTestReportContext context,
  ) {
    if (result.meanDifference > 0) {
      return _positiveDirection(result, context);
    }
    if (result.meanDifference < 0) {
      return _negativeDirection(result, context);
    }
    return 'the observed mean difference was zero';
  }

  static String _positiveDirection(
    TTestResult result,
    TTestReportContext context,
  ) {
    final primary = _label(context.primaryLabel, 'Group 1');
    if (result.kind == TTestKind.oneSample) {
      return 'the sample mean for $primary was higher than '
          '${_label(context.referenceLabel, 'the reference value')}';
    }
    return 'the mean for $primary was higher than the mean for '
        '${_label(context.secondaryLabel, 'Group 2')}';
  }

  static String _negativeDirection(
    TTestResult result,
    TTestReportContext context,
  ) {
    final primary = _label(context.primaryLabel, 'Group 1');
    if (result.kind == TTestKind.oneSample) {
      return 'the sample mean for $primary was lower than '
          '${_label(context.referenceLabel, 'the reference value')}';
    }
    return 'the mean for $primary was lower than the mean for '
        '${_label(context.secondaryLabel, 'Group 2')}';
  }

  static String _comparisonLabel(
    TTestResult result,
    TTestReportContext context,
  ) {
    if (result.kind == TTestKind.oneSample) {
      return '${_label(context.primaryLabel, 'the sample')} and '
          '${_label(context.referenceLabel, 'the reference value')}';
    }
    return '${_label(context.primaryLabel, 'Group 1')} and '
        '${_label(context.secondaryLabel, 'Group 2')}';
  }

  static String _tailAdjective(ReportTail tail) {
    return switch (tail) {
      ReportTail.twoTailed => 'two-tailed',
      ReportTail.less => 'one-tailed less-than',
      ReportTail.greater => 'one-tailed greater-than',
    };
  }

  static String _testLabel(TTestKind kind) {
    return switch (kind) {
      TTestKind.independentStudent => 'independent-samples Student',
      TTestKind.independentWelch => 'Welch independent-samples',
      TTestKind.pairedSamples => 'paired-samples',
      TTestKind.oneSample => 'one-sample',
    };
  }

  static bool _directionConflicts(DirectionalClaim claim, int sign) {
    return switch (claim) {
      DirectionalClaim.none => false,
      DirectionalClaim.primaryGreater => sign <= 0,
      DirectionalClaim.primaryLess => sign >= 0,
    };
  }

  static bool _tailConflicts(ReportTail tail, int sign) {
    return switch (tail) {
      ReportTail.twoTailed => false,
      ReportTail.greater => sign < 0,
      ReportTail.less => sign > 0,
    };
  }

  static String _label(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }
}

class _EvidenceBuilder {
  _EvidenceBuilder(this.sources);

  final EvidenceSourceRegistry sources;
  final List<EvidenceMapEntry> entries = [];

  void add({
    required String id,
    required String section,
    required String label,
    required double value,
    required String formatted,
    required String sourceKey,
    String relation = '=',
    String? fallbackField,
  }) {
    entries.add(
      EvidenceMapEntry(
        id: id,
        section: section,
        label: label,
        value: value,
        formatted: formatted,
        relation: relation,
        source: sources.sourceFor(sourceKey, fallbackField: fallbackField),
      ),
    );
  }
}

class _SelectedP {
  const _SelectedP({
    required this.value,
    required this.sourceKey,
    required this.label,
  });

  final double value;
  final String sourceKey;
  final String label;
}

class _FormattedGroupStats {
  const _FormattedGroupStats({
    required this.mean,
    required this.sd,
    required this.n,
  });

  final String mean;
  final String sd;
  final String n;
}

class _ClaimLists {
  const _ClaimLists({required this.supported, required this.unsupported});

  final List<String> supported;
  final List<String> unsupported;
}
