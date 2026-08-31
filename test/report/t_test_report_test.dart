import 'dart:math' as math;

import 'package:res_quill/src/report/report.dart';
import 'package:res_quill/src/stats/stats.dart';
import 'package:test/test.dart';

void main() {
  group('APA number formatting', () {
    test(
      'formats p and r without leading zeros but keeps means with zeros',
      () {
        expect(ApaNumberFormat.p(0.032), '= .032');
        expect(ApaNumberFormat.p(0.0007), '< .001');
        expect(ApaNumberFormat.correlation(-0.14), '-.14');
        expect(ApaNumberFormat.value(0.24), '0.24');
      },
    );
  });

  group('t-test report wording', () {
    test('generates APA formal, descriptive, effect, and evidence output', () {
      final input = _studentBodyFatInput();
      final result = TTestValidator.resultFromInput(input);
      final report = TTestReportGenerator.generate(
        result: result,
        validationChecks: TTestValidator.validate(input),
        context: const TTestReportContext(
          outcomeLabel: 'body-fat percentage',
          primaryLabel: 'Women',
          secondaryLabel: 'Men',
        ),
        evidenceSources: EvidenceSourceRegistry.fromValidationInput(input),
      );

      expect(report.isBlocked, isFalse);
      expect(
        report.formalResult!.plainText,
        'A two-tailed independent-samples Student t test showed a '
        'statistically significant difference in body-fat percentage between '
        'Women and Men, t(21) = 2.80, p = .011, 95% CI [1.89, 12.79].',
      );
      expect(
        report.formalResult!.markedUpText,
        contains('<i>t</i> test showed'),
      );
      expect(report.formalResult!.markedUpText, contains('<i>p</i> = .011'));
      expect(
        report.descriptivesSentence,
        'Women had a mean of 22.29 (SD = 5.32, n = 10), and Men had a '
        'mean of 14.95 (SD = 6.84, n = 13).',
      );
      expect(report.effectSizeSentence, contains("Cohen's d = 1.18"));
      expect(report.effectSizeSentence, contains("Hedges' g = 1.13"));
      expect(
        report.effectSizeSentence,
        contains("Cohen's Statistical Power Analysis benchmarks"),
      );

      final primaryMean = report.evidenceMap.entries.singleWhere(
        (entry) => entry.id == 'descriptives.primary.mean',
      );
      expect(primaryMean.source.field, 'input.first.mean');
      expect(primaryMean.source.provenance, EvidenceProvenance.reportedByUser);

      final t = report.evidenceMap.entries.singleWhere(
        (entry) => entry.id == 'formal.t',
      );
      expect(t.source.field, 'result.t');
      expect(t.source.provenance, EvidenceProvenance.recomputedByUs);
    });

    test(
      'formats Welch df to two decimals and small p as p less than .001',
      () {
        final input = TTestValidationInput(
          kind: TTestKind.independentWelch,
          first: ReportedDescriptives(
            label: 'Retrieval practice',
            n: 20,
            mean: 81.40,
            standardDeviation: 5.537781765425369,
          ),
          second: ReportedDescriptives(
            label: 'Restudy',
            n: 31,
            mean: 72.40,
            standardDeviation: 9.261614190057113,
          ),
          reportedT: ReportedValue(value: 4.34, decimalPlaces: 2),
          reportedDegreesOfFreedom: ReportedValue(
            value: 48.80,
            decimalPlaces: 2,
          ),
          reportedP: ReportedValue(
            value: 0.001,
            decimalPlaces: 3,
            relation: ReportedRelation.lessThan,
          ),
        );
        final report = _reportForInput(
          input,
          context: const TTestReportContext(
            outcomeLabel: 'test scores',
            primaryLabel: 'Retrieval practice',
            secondaryLabel: 'Restudy',
          ),
        );

        expect(report.isBlocked, isFalse);
        expect(report.formalResult!.plainText, contains('t(48.80) = 4.34'));
        expect(report.formalResult!.plainText, contains('p < .001'));
        final p = report.evidenceMap.entries.singleWhere(
          (entry) => entry.id == 'formal.p',
        );
        expect(p.relation, '<');
        expect(p.formatted, '.001');
      },
    );

    test('supports paired-samples descriptives and paired differences', () {
      final input = TTestValidationInput(
        kind: TTestKind.pairedSamples,
        paired: ReportedPairedDescriptives(
          first: ReportedDescriptives(
            label: 'Before',
            n: 15,
            mean: 56.6,
            standardDeviation: 12.35920755375577,
          ),
          second: ReportedDescriptives(
            label: 'After',
            n: 15,
            mean: 48.6,
            standardDeviation: 11.628781881530575,
          ),
          meanDifference: 8,
          differenceStandardDeviation: 11.026807475045327,
        ),
        reportedT: ReportedValue(value: 2.81, decimalPlaces: 2),
        reportedDegreesOfFreedom: ReportedValue(value: 14, decimalPlaces: 0),
        reportedP: ReportedValue(value: 0.014, decimalPlaces: 3),
      );
      final report = _reportForInput(
        input,
        context: const TTestReportContext(
          outcomeLabel: 'scores',
          primaryLabel: 'Before',
          secondaryLabel: 'After',
        ),
      );

      expect(report.isBlocked, isFalse);
      expect(report.formalResult!.plainText, contains('paired-samples'));
      expect(
        report.descriptivesSentence,
        contains('the mean paired difference was 8.00'),
      );
      final difference = report.evidenceMap.entries.singleWhere(
        (entry) => entry.id == 'descriptives.pairedDifference.mean',
      );
      expect(difference.source.field, 'input.paired.meanDifference');
      expect(difference.source.provenance, EvidenceProvenance.reportedByUser);
    });

    test('states one-tailed direction explicitly', () {
      final input = TTestValidationInput(
        kind: TTestKind.oneSample,
        first: ReportedDescriptives(
          label: 'Mice',
          n: 10,
          mean: 20.14,
          standardDeviation: 1.8963130888294555,
        ),
        referenceMean: 25,
        reportedT: ReportedValue(value: -8.10, decimalPlaces: 2),
        reportedDegreesOfFreedom: ReportedValue(value: 9, decimalPlaces: 0),
        reportedP: ReportedValue(
          value: 0.001,
          decimalPlaces: 3,
          relation: ReportedRelation.lessThan,
        ),
        reportedPValueTail: ReportedPValueTail.less,
      );
      final report = _reportForInput(
        input,
        options: TTestReportOptions(tail: ReportTail.less),
        context: const TTestReportContext(
          outcomeLabel: 'weight',
          primaryLabel: 'Mice',
          referenceLabel: 'the reference value',
        ),
      );

      expect(report.isBlocked, isFalse);
      expect(
        report.formalResult!.plainText,
        startsWith('A one-tailed less-than one-sample t test'),
      );
      expect(
        report.formalResult!.plainText,
        contains('the mean for Mice was lower than the reference value'),
      );
      expect(
        report.plainLanguageMeaning,
        contains(
          'statistical evidence that the mean for Mice was lower than '
          'the reference value',
        ),
      );
    });

    test('blocks polished wording when validation has any failed check', () {
      final input = _studentBodyFatInput(
        p: ReportedValue(value: 0.900, decimalPlaces: 3),
      );
      final result = TTestValidator.resultFromInput(input);
      final report = TTestReportGenerator.generate(
        result: result,
        validationChecks: TTestValidator.validate(input),
        evidenceSources: EvidenceSourceRegistry.fromValidationInput(input),
      );

      expect(report.isBlocked, isTrue);
      expect(report.refusalReason, contains('p.t_df'));
      expect(report.formalResult, isNull);
      expect(report.evidenceMap.entries, isEmpty);
    });

    test('warns when rounded p display hides a boundary decision', () {
      final targetP = 0.0498;
      final df = 30.0;
      final t = TDistribution(df).quantile(1 - targetP / 2);
      final input = TTestValidationInput(
        kind: TTestKind.oneSample,
        first: ReportedDescriptives(
          label: 'Boundary sample',
          n: 31,
          mean: t / math.sqrt(31),
          standardDeviation: 1,
        ),
        referenceMean: 0,
      );
      final report = _reportForInput(
        input,
        context: const TTestReportContext(primaryLabel: 'Boundary sample'),
      );

      expect(report.isBlocked, isFalse);
      expect(report.formalResult!.plainText, contains('p = .050'));
      expect(report.roundingCautions.single, contains('p = .0498'));
      expect(
        report.evidenceMap.entries
            .singleWhere((entry) => entry.id == 'rounding.pExact')
            .formatted,
        '.0498',
      );
    });

    test('flags causal framing and unsupported directional claims', () {
      final input = TTestValidationInput(
        kind: TTestKind.independentWelch,
        first: ReportedDescriptives(
          label: 'Women',
          n: 20,
          mean: 63.49867,
          standardDeviation: 2.027610249697214,
        ),
        second: ReportedDescriptives(
          label: 'Men',
          n: 20,
          mean: 85.82612,
          standardDeviation: 4.353620418858437,
        ),
      );
      final report = _reportForInput(
        input,
        context: const TTestReportContext(
          primaryLabel: 'Women',
          secondaryLabel: 'Men',
          userClaim: UserClaimContext(
            text: 'The program resulted in higher scores for Women.',
            direction: DirectionalClaim.primaryGreater,
          ),
        ),
      );

      expect(report.isBlocked, isFalse);
      expect(
        report.unsupportedClaims,
        contains(
          "The user's framing sounds causal; rewrite it as an association or "
          'mean-difference claim.',
        ),
      );
      expect(
        report.unsupportedClaims,
        contains(
          'The supplied directional claim conflicts with the observed '
          'mean-difference sign.',
        ),
      );
    });

    test('generated wording avoids common overclaiming phrases', () {
      final report = _reportForInput(_studentBodyFatInput());
      final generatedText = [
        report.formalResult!.plainText,
        report.descriptivesSentence!,
        report.plainLanguageMeaning!,
        report.effectSizeSentence!,
        ...report.roundingCautions,
        ...report.supportedClaims,
        ...report.unsupportedClaims,
      ].join('\n').toLowerCase();

      final bannedPhrases = [
        String.fromCharCodes([112, 114, 111, 118, 101, 115]),
        String.fromCharCodes([99, 97, 117, 115, 101, 115]),
        String.fromCharCodes([
          99,
          111,
          110,
          102,
          105,
          114,
          109,
          115,
          32,
          116,
          104,
          101,
          32,
          104,
          121,
          112,
          111,
          116,
          104,
          101,
          115,
          105,
          115,
        ]),
        String.fromCharCodes([
          110,
          111,
          32,
          100,
          105,
          102,
          102,
          101,
          114,
          101,
          110,
          99,
          101,
          32,
          101,
          120,
          105,
          115,
          116,
          115,
        ]),
      ];
      for (final phrase in bannedPhrases) {
        expect(generatedText, isNot(contains(phrase)));
      }
    });
  });
}

TTestReportOutput _reportForInput(
  TTestValidationInput input, {
  TTestReportContext context = const TTestReportContext(),
  TTestReportOptions? options,
}) {
  return TTestReportGenerator.generate(
    result: TTestValidator.resultFromInput(input),
    validationChecks: TTestValidator.validate(input),
    context: context,
    options: options,
    evidenceSources: EvidenceSourceRegistry.fromValidationInput(input),
  );
}

TTestValidationInput _studentBodyFatInput({ReportedValue? p}) {
  return TTestValidationInput(
    kind: TTestKind.independentStudent,
    first: ReportedDescriptives(
      label: 'Women',
      n: 10,
      mean: 22.29,
      standardDeviation: 5.32,
    ),
    second: ReportedDescriptives(
      label: 'Men',
      n: 13,
      mean: 14.95,
      standardDeviation: 6.84,
    ),
    reportedT: ReportedValue(value: 2.80, decimalPlaces: 2),
    reportedDegreesOfFreedom: ReportedValue(value: 21, decimalPlaces: 0),
    reportedP: p ?? ReportedValue(value: 0.011, decimalPlaces: 3),
    reportedMeanDifference: ReportedValue(value: 7.34, decimalPlaces: 2),
    reportedStandardError: ReportedValue(value: 2.622, decimalPlaces: 3),
    reportedCiLower: ReportedValue(value: 1.89, decimalPlaces: 2),
    reportedCiUpper: ReportedValue(value: 12.79, decimalPlaces: 2),
  );
}
