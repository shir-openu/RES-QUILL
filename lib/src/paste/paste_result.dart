import '../report/report.dart';
import '../stats/stats.dart';

enum PasteParseStatus { confident, needsConfirmation, cannotParse }

enum PasteFieldKey {
  primaryLabel,
  primaryN,
  primaryMean,
  primaryStandardDeviation,
  secondaryLabel,
  secondaryN,
  secondaryMean,
  secondaryStandardDeviation,
  pairedMeanDifference,
  pairedDifferenceStandardDeviation,
  pairedCorrelation,
  referenceMean,
  reportedT,
  reportedDegreesOfFreedom,
  reportedP,
  reportedMeanDifference,
  reportedStandardError,
  ciLower,
  ciUpper,
  confidenceLevel,
  leveneF,
  leveneP,
}

extension PasteFieldKeyPath on PasteFieldKey {
  String get path {
    return switch (this) {
      PasteFieldKey.primaryLabel => 'primary.label',
      PasteFieldKey.primaryN => 'primary.n',
      PasteFieldKey.primaryMean => 'primary.mean',
      PasteFieldKey.primaryStandardDeviation => 'primary.standardDeviation',
      PasteFieldKey.secondaryLabel => 'secondary.label',
      PasteFieldKey.secondaryN => 'secondary.n',
      PasteFieldKey.secondaryMean => 'secondary.mean',
      PasteFieldKey.secondaryStandardDeviation => 'secondary.standardDeviation',
      PasteFieldKey.pairedMeanDifference => 'paired.meanDifference',
      PasteFieldKey.pairedDifferenceStandardDeviation =>
        'paired.differenceStandardDeviation',
      PasteFieldKey.pairedCorrelation => 'paired.correlation',
      PasteFieldKey.referenceMean => 'referenceMean',
      PasteFieldKey.reportedT => 'reported.t',
      PasteFieldKey.reportedDegreesOfFreedom => 'reported.df',
      PasteFieldKey.reportedP => 'reported.p',
      PasteFieldKey.reportedMeanDifference => 'reported.meanDifference',
      PasteFieldKey.reportedStandardError => 'reported.standardError',
      PasteFieldKey.ciLower => 'reported.ciLower',
      PasteFieldKey.ciUpper => 'reported.ciUpper',
      PasteFieldKey.confidenceLevel => 'reported.confidenceLevel',
      PasteFieldKey.leveneF => 'levene.f',
      PasteFieldKey.leveneP => 'levene.p',
    };
  }

  String get label {
    return switch (this) {
      PasteFieldKey.primaryLabel => 'primary label',
      PasteFieldKey.primaryN => 'primary n',
      PasteFieldKey.primaryMean => 'primary mean',
      PasteFieldKey.primaryStandardDeviation => 'primary SD',
      PasteFieldKey.secondaryLabel => 'secondary label',
      PasteFieldKey.secondaryN => 'secondary n',
      PasteFieldKey.secondaryMean => 'secondary mean',
      PasteFieldKey.secondaryStandardDeviation => 'secondary SD',
      PasteFieldKey.pairedMeanDifference => 'paired mean difference',
      PasteFieldKey.pairedDifferenceStandardDeviation => 'paired difference SD',
      PasteFieldKey.pairedCorrelation => 'paired correlation',
      PasteFieldKey.referenceMean => 'reference mean',
      PasteFieldKey.reportedT => 'reported t',
      PasteFieldKey.reportedDegreesOfFreedom => 'reported df',
      PasteFieldKey.reportedP => 'reported p',
      PasteFieldKey.reportedMeanDifference => 'reported mean difference',
      PasteFieldKey.reportedStandardError => 'reported standard error',
      PasteFieldKey.ciLower => 'reported CI lower',
      PasteFieldKey.ciUpper => 'reported CI upper',
      PasteFieldKey.confidenceLevel => 'reported confidence level',
      PasteFieldKey.leveneF => "Levene's F",
      PasteFieldKey.leveneP => "Levene's p",
    };
  }
}

class PasteNumber {
  const PasteNumber({
    required this.value,
    required this.decimalPlaces,
    this.relation = ReportedRelation.equalRounded,
    this.spssRoundedZeroP = false,
  });

  final double value;
  final int decimalPlaces;
  final ReportedRelation relation;
  final bool spssRoundedZeroP;

  ReportedValue toReportedValue() {
    return ReportedValue(
      value: value,
      decimalPlaces: decimalPlaces,
      relation: relation,
    );
  }

  String get relationSymbol {
    return switch (relation) {
      ReportedRelation.equalRounded => '=',
      ReportedRelation.lessThan => '<',
      ReportedRelation.lessThanOrEqual => '<=',
      ReportedRelation.greaterThan => '>',
      ReportedRelation.greaterThanOrEqual => '>=',
    };
  }

  @override
  String toString() => '$relationSymbol ${_formatPasteNumber(this)}';
}

class PasteExtractedField<T extends Object> {
  const PasteExtractedField({
    required this.key,
    required this.value,
    required this.sourceText,
    required this.start,
    required this.end,
    required this.confidence,
  });

  final PasteFieldKey key;
  final T value;
  final String sourceText;
  final int start;
  final int end;
  final double confidence;

  String get keyPath => key.path;

  String describeValue() {
    final value = this.value;
    if (value is PasteNumber) {
      final prefix = value.relation == ReportedRelation.equalRounded
          ? ''
          : '${value.relationSymbol} ';
      return '$prefix${_formatPasteNumber(value)}';
    }
    return value.toString();
  }
}

String _formatPasteNumber(PasteNumber number) {
  final decimals = number.decimalPlaces.clamp(0, 6);
  return number.value.toStringAsFixed(decimals);
}

class PasteAmbiguity {
  const PasteAmbiguity({
    required this.id,
    required this.message,
    this.fieldKeys = const [],
    this.candidateLabels = const [],
  });

  final String id;
  final String message;
  final List<PasteFieldKey> fieldKeys;
  final List<String> candidateLabels;
}

class PasteMissingField {
  const PasteMissingField({required this.key, required this.reason});

  final PasteFieldKey? key;
  final String reason;

  String get label => key?.label ?? reason;
}

class PasteParseException implements Exception {
  PasteParseException(this.message);

  final String message;

  @override
  String toString() => 'PasteParseException: $message';
}

class PasteTTestCandidate {
  PasteTTestCandidate({
    required this.kind,
    required this.label,
    required List<PasteExtractedField<Object>> fields,
    this.reportedPValueTail,
    this.selectedByText = false,
    this.format = 'unknown',
    this.confidence = 0.80,
  }) : fields = List.unmodifiable(fields);

  final TTestKind kind;
  final String label;
  final List<PasteExtractedField<Object>> fields;
  final ReportedPValueTail? reportedPValueTail;
  final bool selectedByText;
  final String format;
  final double confidence;

  PasteExtractedField<Object>? field(PasteFieldKey key) {
    for (final field in fields) {
      if (field.key == key) {
        return field;
      }
    }
    return null;
  }

  PasteNumber? number(PasteFieldKey key) {
    final value = field(key)?.value;
    if (value is PasteNumber) {
      return value;
    }
    return null;
  }

  String? text(PasteFieldKey key) {
    final value = field(key)?.value;
    if (value is String) {
      return value;
    }
    return null;
  }

  List<PasteMissingField> missingRequiredFields({
    ReportedPValueTail? confirmedPValueTail,
  }) {
    final missing = <PasteMissingField>[];
    for (final key in _requiredKeys(kind)) {
      if (field(key) == null) {
        missing.add(
          PasteMissingField(key: key, reason: '${key.label} missing'),
        );
      }
    }
    return missing;
  }

  bool canBuildValidationInput({ReportedPValueTail? confirmedPValueTail}) {
    final pTail = confirmedPValueTail ?? reportedPValueTail;
    if (field(PasteFieldKey.reportedP) != null &&
        (pTail == null ||
            pTail == ReportedPValueTail.oneTailedObservedDirection)) {
      return false;
    }
    return missingRequiredFields().isEmpty;
  }

  TTestValidationInput toValidationInput({
    ReportedPValueTail? confirmedPValueTail,
  }) {
    final missing = missingRequiredFields(
      confirmedPValueTail: confirmedPValueTail,
    );
    if (missing.isNotEmpty) {
      throw PasteParseException(
        'Cannot build validation input: '
        '${missing.map((field) => field.label).join(', ')}.',
      );
    }

    final pTail =
        confirmedPValueTail ??
        reportedPValueTail ??
        (throw PasteParseException('reported p tail is unknown.'));
    if (pTail == ReportedPValueTail.oneTailedObservedDirection) {
      throw PasteParseException('one-sided p direction requires confirmation.');
    }
    final confidenceLevel =
        number(PasteFieldKey.confidenceLevel)?.value ??
        (throw PasteParseException('confidence level is missing.'));

    switch (kind) {
      case TTestKind.independentStudent:
      case TTestKind.independentWelch:
        return TTestValidationInput(
          kind: kind,
          first: _reportedDescriptives(
            labelKey: PasteFieldKey.primaryLabel,
            nKey: PasteFieldKey.primaryN,
            meanKey: PasteFieldKey.primaryMean,
            sdKey: PasteFieldKey.primaryStandardDeviation,
            fallbackLabel: 'Group 1',
          ),
          second: _reportedDescriptives(
            labelKey: PasteFieldKey.secondaryLabel,
            nKey: PasteFieldKey.secondaryN,
            meanKey: PasteFieldKey.secondaryMean,
            sdKey: PasteFieldKey.secondaryStandardDeviation,
            fallbackLabel: 'Group 2',
          ),
          reportedT: number(PasteFieldKey.reportedT)?.toReportedValue(),
          reportedDegreesOfFreedom: number(
            PasteFieldKey.reportedDegreesOfFreedom,
          )?.toReportedValue(),
          reportedP: number(PasteFieldKey.reportedP)?.toReportedValue(),
          reportedPValueTail: pTail,
          reportedMeanDifference: number(
            PasteFieldKey.reportedMeanDifference,
          )?.toReportedValue(),
          reportedStandardError: number(
            PasteFieldKey.reportedStandardError,
          )?.toReportedValue(),
          reportedCiLower: number(PasteFieldKey.ciLower)?.toReportedValue(),
          reportedCiUpper: number(PasteFieldKey.ciUpper)?.toReportedValue(),
          confidenceLevel: confidenceLevel,
        );
      case TTestKind.pairedSamples:
        final first = _reportedDescriptives(
          labelKey: PasteFieldKey.primaryLabel,
          nKey: PasteFieldKey.primaryN,
          meanKey: PasteFieldKey.primaryMean,
          sdKey: PasteFieldKey.primaryStandardDeviation,
          fallbackLabel: 'First measurement',
        );
        final second = _reportedDescriptives(
          labelKey: PasteFieldKey.secondaryLabel,
          nKey: PasteFieldKey.secondaryN,
          meanKey: PasteFieldKey.secondaryMean,
          sdKey: PasteFieldKey.secondaryStandardDeviation,
          fallbackLabel: 'Second measurement',
        );
        return TTestValidationInput(
          kind: kind,
          paired: ReportedPairedDescriptives(
            first: first,
            second: second,
            meanDifference: number(PasteFieldKey.pairedMeanDifference)!.value,
            differenceStandardDeviation: number(
              PasteFieldKey.pairedDifferenceStandardDeviation,
            )!.value,
            correlation: number(PasteFieldKey.pairedCorrelation)?.value,
          ),
          reportedT: number(PasteFieldKey.reportedT)?.toReportedValue(),
          reportedDegreesOfFreedom: number(
            PasteFieldKey.reportedDegreesOfFreedom,
          )?.toReportedValue(),
          reportedP: number(PasteFieldKey.reportedP)?.toReportedValue(),
          reportedPValueTail: pTail,
          reportedMeanDifference: number(
            PasteFieldKey.reportedMeanDifference,
          )?.toReportedValue(),
          reportedStandardError: number(
            PasteFieldKey.reportedStandardError,
          )?.toReportedValue(),
          reportedCiLower: number(PasteFieldKey.ciLower)?.toReportedValue(),
          reportedCiUpper: number(PasteFieldKey.ciUpper)?.toReportedValue(),
          confidenceLevel: confidenceLevel,
        );
      case TTestKind.oneSample:
        return TTestValidationInput(
          kind: kind,
          first: _reportedDescriptives(
            labelKey: PasteFieldKey.primaryLabel,
            nKey: PasteFieldKey.primaryN,
            meanKey: PasteFieldKey.primaryMean,
            sdKey: PasteFieldKey.primaryStandardDeviation,
            fallbackLabel: 'Sample',
          ),
          referenceMean: number(PasteFieldKey.referenceMean)!.value,
          reportedT: number(PasteFieldKey.reportedT)?.toReportedValue(),
          reportedDegreesOfFreedom: number(
            PasteFieldKey.reportedDegreesOfFreedom,
          )?.toReportedValue(),
          reportedP: number(PasteFieldKey.reportedP)?.toReportedValue(),
          reportedPValueTail: pTail,
          reportedMeanDifference: number(
            PasteFieldKey.reportedMeanDifference,
          )?.toReportedValue(),
          reportedStandardError: number(
            PasteFieldKey.reportedStandardError,
          )?.toReportedValue(),
          reportedCiLower: number(PasteFieldKey.ciLower)?.toReportedValue(),
          reportedCiUpper: number(PasteFieldKey.ciUpper)?.toReportedValue(),
          confidenceLevel: confidenceLevel,
        );
    }
  }

  TTestReportContext reportContext() {
    return TTestReportContext(
      primaryLabel: text(PasteFieldKey.primaryLabel) ?? 'Group 1',
      secondaryLabel: text(PasteFieldKey.secondaryLabel),
      referenceLabel: number(PasteFieldKey.referenceMean) == null
          ? 'the reference value'
          : 'the reference value',
    );
  }

  TTestReportOptions? reportOptions({ReportedPValueTail? confirmedPValueTail}) {
    final tail = confirmedPValueTail ?? reportedPValueTail;
    final reportTail = switch (tail) {
      ReportedPValueTail.twoTailed => ReportTail.twoTailed,
      ReportedPValueTail.less => ReportTail.less,
      ReportedPValueTail.greater => ReportTail.greater,
      ReportedPValueTail.oneTailedObservedDirection => null,
      null => null,
    };
    if (reportTail == null) {
      return null;
    }
    return TTestReportOptions(tail: reportTail);
  }

  EvidenceSourceRegistry evidenceSources() {
    final sources = <String, EvidenceSource>{};
    void add(PasteFieldKey key, String sourceKey) {
      final extracted = field(key);
      if (extracted == null) {
        return;
      }
      sources[sourceKey] = EvidenceSource(
        field: 'paste.${key.path}@${extracted.start}-${extracted.end}',
        provenance: EvidenceProvenance.reportedByUser,
        note: 'source: ${extracted.sourceText}',
      );
    }

    add(PasteFieldKey.primaryN, 'primary.n');
    add(PasteFieldKey.primaryMean, 'primary.mean');
    add(PasteFieldKey.primaryStandardDeviation, 'primary.standardDeviation');
    add(PasteFieldKey.secondaryN, 'secondary.n');
    add(PasteFieldKey.secondaryMean, 'secondary.mean');
    add(
      PasteFieldKey.secondaryStandardDeviation,
      'secondary.standardDeviation',
    );
    add(PasteFieldKey.pairedMeanDifference, 'pairedDifferences.mean');
    add(
      PasteFieldKey.pairedDifferenceStandardDeviation,
      'pairedDifferences.standardDeviation',
    );
    add(PasteFieldKey.primaryN, 'pairedDifferences.n');
    add(PasteFieldKey.referenceMean, 'referenceMean');
    return EvidenceSourceRegistry(sources);
  }

  ReportedDescriptives _reportedDescriptives({
    required PasteFieldKey labelKey,
    required PasteFieldKey nKey,
    required PasteFieldKey meanKey,
    required PasteFieldKey sdKey,
    required String fallbackLabel,
  }) {
    return ReportedDescriptives(
      label: text(labelKey) ?? fallbackLabel,
      n: number(nKey)!.value.round(),
      mean: number(meanKey)!.value,
      standardDeviation: number(sdKey)!.value,
    );
  }

  static List<PasteFieldKey> _requiredKeys(TTestKind kind) {
    final common = <PasteFieldKey>[
      PasteFieldKey.primaryN,
      PasteFieldKey.primaryMean,
      PasteFieldKey.primaryStandardDeviation,
      PasteFieldKey.reportedT,
      PasteFieldKey.reportedDegreesOfFreedom,
      PasteFieldKey.reportedP,
      PasteFieldKey.confidenceLevel,
    ];
    return switch (kind) {
      TTestKind.independentStudent || TTestKind.independentWelch => [
        ...common,
        PasteFieldKey.secondaryN,
        PasteFieldKey.secondaryMean,
        PasteFieldKey.secondaryStandardDeviation,
      ],
      TTestKind.pairedSamples => [
        ...common,
        PasteFieldKey.secondaryN,
        PasteFieldKey.secondaryMean,
        PasteFieldKey.secondaryStandardDeviation,
        PasteFieldKey.pairedMeanDifference,
        PasteFieldKey.pairedDifferenceStandardDeviation,
      ],
      TTestKind.oneSample => [...common, PasteFieldKey.referenceMean],
    };
  }
}

class TTestPasteParseResult {
  TTestPasteParseResult({
    required this.input,
    required this.status,
    required this.detectedTestKind,
    required List<PasteTTestCandidate> candidates,
    required List<PasteExtractedField<Object>> fields,
    required List<PasteAmbiguity> ambiguities,
    required List<PasteMissingField> missingRequiredFields,
    required List<String> refusalReasons,
  }) : candidates = List.unmodifiable(candidates),
       fields = List.unmodifiable(fields),
       ambiguities = List.unmodifiable(ambiguities),
       missingRequiredFields = List.unmodifiable(missingRequiredFields),
       refusalReasons = List.unmodifiable(refusalReasons);

  final String input;
  final PasteParseStatus status;
  final TTestKind? detectedTestKind;
  final List<PasteTTestCandidate> candidates;
  final List<PasteExtractedField<Object>> fields;
  final List<PasteAmbiguity> ambiguities;
  final List<PasteMissingField> missingRequiredFields;
  final List<String> refusalReasons;

  PasteTTestCandidate? get selectedCandidate {
    if (status != PasteParseStatus.confident) {
      return null;
    }
    final selected = candidates.where((candidate) => candidate.selectedByText);
    if (selected.length == 1) {
      return selected.single;
    }
    if (candidates.length == 1) {
      return candidates.single;
    }
    return null;
  }
}
