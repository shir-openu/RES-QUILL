import 'package:res_quill/src/report/report.dart';
import 'package:res_quill/src/stats/stats.dart';
import 'package:test/test.dart';

void main() {
  group('near-boundary t-test report wording', () {
    test('keeps significant and non-significant prose distinct', () {
      final cases = [
        _Case(
          name: 'R Welch',
          input: _welchInput(),
          context: const TTestReportContext(
            primaryLabel: 'Practice',
            secondaryLabel: 'Control',
          ),
          expectedFormal:
              'A two-tailed Welch independent-samples t test did not provide '
              'evidence of a difference in scores between Practice and '
              'Control, t(48.16) = 2.01, p = .051, 95% CI [-0.02, 14.46].',
          significant: false,
        ),
        _Case(
          name: 'R Student',
          input: _studentInput(),
          context: const TTestReportContext(
            primaryLabel: 'Practice',
            secondaryLabel: 'Control',
          ),
          expectedFormal:
              'A two-tailed independent-samples Student t test did not provide '
              'evidence of a difference in scores between Practice and '
              'Control, t(49) = 1.98, p = .054, 95% CI [-0.10, 11.18].',
          significant: false,
        ),
        _Case(
          name: 'R paired',
          input: _pairedInput(),
          context: const TTestReportContext(
            primaryLabel: 'Before',
            secondaryLabel: 'After',
          ),
          expectedFormal:
              'A two-tailed paired-samples t test showed a statistically '
              'significant difference in scores between Before and After, '
              't(17) = 4.09, p < .001, 95% CI [2.80, 8.76].',
          significant: true,
        ),
        _Case(
          name: 'R one',
          input: _oneSampleInput(),
          context: const TTestReportContext(
            primaryLabel: 'Sample',
            referenceLabel: 'the reference value',
          ),
          expectedFormal:
              'A two-tailed one-sample t test did not provide evidence of a '
              'difference in scores between Sample and the reference value, '
              't(32) = 0.39, p = .700, 95% CI [-2.87, 4.22].',
          significant: false,
        ),
      ];

      for (final item in cases) {
        final report = _reportFor(item.input, item.context);
        expect(
          report.isBlocked,
          isFalse,
          reason: '${item.name} should pass validation',
        );
        expect(report.formalResult!.plainText, item.expectedFormal);

        final wording = _allReportText(report).toLowerCase();
        expect(wording, isNot(contains('marginally significant')));
        expect(wording, isNot(contains('approaching significance')));
        expect(wording, isNot(contains('trend towards')));
        expect(wording, isNot(contains('trend toward')));

        if (item.significant) {
          expect(
            report.formalResult!.plainText,
            contains('showed a statistically significant difference'),
          );
          expect(
            report.plainLanguageMeaning,
            startsWith('The sample data provided statistical evidence'),
          );
        } else {
          expect(
            report.formalResult!.plainText,
            contains('did not provide evidence of a difference'),
          );
          expect(
            report.plainLanguageMeaning,
            startsWith('The sample data did not provide evidence'),
          );
        }
      }
    });
  });
}

TTestReportOutput _reportFor(
  TTestValidationInput input,
  TTestReportContext context,
) {
  return TTestReportGenerator.generate(
    result: TTestValidator.resultFromInput(input),
    validationChecks: TTestValidator.validate(input),
    context: context,
    evidenceSources: EvidenceSourceRegistry.fromValidationInput(input),
  );
}

String _allReportText(TTestReportOutput report) {
  return [
    report.formalResult?.plainText,
    report.descriptivesSentence,
    report.plainLanguageMeaning,
    report.effectSizeSentence,
    ...report.roundingCautions,
    ...report.supportedClaims,
    ...report.unsupportedClaims,
  ].whereType<String>().join('\n');
}

TTestValidationInput _welchInput() {
  return TTestValidationInput(
    kind: TTestKind.independentWelch,
    first: ReportedDescriptives(
      label: 'Practice',
      n: 24,
      mean: 57.2205,
      standardDeviation: 12.907592557866561,
    ),
    second: ReportedDescriptives(
      label: 'Control',
      n: 27,
      mean: 50,
      standardDeviation: 12.753858230198336,
    ),
    reportedT: ReportedValue(value: 2.0052, decimalPlaces: 4),
    reportedDegreesOfFreedom: ReportedValue(value: 48.158, decimalPlaces: 3),
    reportedP: ReportedValue(value: 0.050583, decimalPlaces: 6),
    reportedMeanDifference: ReportedValue(value: 7.2205, decimalPlaces: 4),
    reportedStandardError: ReportedValue(value: 3.6009, decimalPlaces: 4),
    reportedCiLower: ReportedValue(value: -0.019, decimalPlaces: 3),
    reportedCiUpper: ReportedValue(value: 14.460, decimalPlaces: 3),
  );
}

TTestValidationInput _studentInput() {
  return TTestValidationInput(
    kind: TTestKind.independentStudent,
    first: ReportedDescriptives(
      label: 'Practice',
      n: 24,
      mean: 55.54182279312235,
      standardDeviation: 10,
    ),
    second: ReportedDescriptives(
      label: 'Control',
      n: 27,
      mean: 50,
      standardDeviation: 10,
    ),
    reportedT: ReportedValue(value: 1.9754, decimalPlaces: 4),
    reportedDegreesOfFreedom: ReportedValue(value: 49, decimalPlaces: 0),
    reportedP: ReportedValue(value: 0.053869, decimalPlaces: 6),
    reportedMeanDifference: ReportedValue(value: 5.5418, decimalPlaces: 4),
    reportedStandardError: ReportedValue(value: 2.8054, decimalPlaces: 4),
    reportedCiLower: ReportedValue(value: -0.096, decimalPlaces: 3),
    reportedCiUpper: ReportedValue(value: 11.180, decimalPlaces: 3),
  );
}

TTestValidationInput _pairedInput() {
  return TTestValidationInput(
    kind: TTestKind.pairedSamples,
    paired: ReportedPairedDescriptives(
      first: ReportedDescriptives(
        label: 'Before',
        n: 18,
        mean: 60,
        standardDeviation: 10,
      ),
      second: ReportedDescriptives(
        label: 'After',
        n: 18,
        mean: 54.21996774922492,
        standardDeviation: 10,
      ),
      meanDifference: 5.780032250775077,
      differenceStandardDeviation: 6,
    ),
    reportedT: ReportedValue(value: 4.0871, decimalPlaces: 4),
    reportedDegreesOfFreedom: ReportedValue(value: 17, decimalPlaces: 0),
    reportedP: ReportedValue(value: 0.000768, decimalPlaces: 6),
    reportedMeanDifference: ReportedValue(value: 5.7800, decimalPlaces: 4),
    reportedStandardError: ReportedValue(value: 1.4142, decimalPlaces: 4),
    reportedCiLower: ReportedValue(value: 2.796, decimalPlaces: 3),
    reportedCiUpper: ReportedValue(value: 8.764, decimalPlaces: 3),
  );
}

TTestValidationInput _oneSampleInput() {
  return TTestValidationInput(
    kind: TTestKind.oneSample,
    first: ReportedDescriptives(
      label: 'Sample',
      n: 33,
      mean: 50.676813926355756,
      standardDeviation: 10,
    ),
    referenceMean: 50,
    reportedT: ReportedValue(value: 0.3888, decimalPlaces: 4),
    reportedDegreesOfFreedom: ReportedValue(value: 32, decimalPlaces: 0),
    reportedP: ReportedValue(value: 0.699989, decimalPlaces: 6),
    reportedMeanDifference: ReportedValue(value: 0.6768, decimalPlaces: 4),
    reportedStandardError: ReportedValue(value: 1.7408, decimalPlaces: 4),
    reportedCiLower: ReportedValue(value: -2.869, decimalPlaces: 3),
    reportedCiUpper: ReportedValue(value: 4.223, decimalPlaces: 3),
  );
}

class _Case {
  const _Case({
    required this.name,
    required this.input,
    required this.context,
    required this.expectedFormal,
    required this.significant,
  });

  final String name;
  final TTestValidationInput input;
  final TTestReportContext context;
  final String expectedFormal;
  final bool significant;
}
