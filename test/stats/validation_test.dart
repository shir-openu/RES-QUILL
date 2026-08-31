import 'package:res_quill/src/stats/stats.dart';
import 'package:test/test.dart';

void main() {
  group('validator known-bad controls', () {
    TTestValidationInput validStudentInput({
      ReportedValue? t,
      ReportedValue? df,
      ReportedValue? p,
      ReportedValue? ciLower,
      ReportedValue? ciUpper,
    }) {
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
        reportedT: t ?? ReportedValue(value: 2.80, decimalPlaces: 2),
        reportedDegreesOfFreedom:
            df ?? ReportedValue(value: 21, decimalPlaces: 0),
        reportedP: p ?? ReportedValue(value: 0.011, decimalPlaces: 3),
        reportedMeanDifference: ReportedValue(value: 7.34, decimalPlaces: 2),
        reportedStandardError: ReportedValue(value: 2.622, decimalPlaces: 3),
        reportedCiLower:
            ciLower ?? ReportedValue(value: 1.89, decimalPlaces: 2),
        reportedCiUpper:
            ciUpper ?? ReportedValue(value: 12.79, decimalPlaces: 2),
      );
    }

    ValidationCheck checkById(List<ValidationCheck> checks, String id) {
      return checks.singleWhere((check) => check.id == id);
    }

    test('passes rounded consistent student output', () {
      final checks = TTestValidator.validate(validStudentInput());
      expect(
        checks.where((check) => check.status == ValidationStatus.fail),
        isEmpty,
      );
    });

    test('flags t mismatched with descriptives', () {
      final checks = TTestValidator.validate(
        validStudentInput(t: ReportedValue(value: 1.25, decimalPlaces: 2)),
      );
      expect(checkById(checks, 't.descriptives').status, ValidationStatus.fail);
    });

    test('flags p mismatched with reported t and df', () {
      final checks = TTestValidator.validate(
        validStudentInput(p: ReportedValue(value: 0.900, decimalPlaces: 3)),
      );
      expect(checkById(checks, 'p.t_df').status, ValidationStatus.fail);
    });

    test('flags CI mismatched with mean difference and SE', () {
      final checks = TTestValidator.validate(
        validStudentInput(
          ciLower: ReportedValue(value: -10.00, decimalPlaces: 2),
        ),
      );
      expect(checkById(checks, 'ci.lower').status, ValidationStatus.fail);
      expect(checkById(checks, 'ci.upper').status, ValidationStatus.pass);
    });

    test('flags implausible df for stated test and ns', () {
      final checks = TTestValidator.validate(
        validStudentInput(df: ReportedValue(value: 18, decimalPlaces: 0)),
      );
      expect(
        checkById(checks, 'df.plausibility').status,
        ValidationStatus.fail,
      );
    });

    test('flags invalid SD and invalid p domains', () {
      final checks = TTestValidator.validate(
        TTestValidationInput(
          kind: TTestKind.independentWelch,
          first: ReportedDescriptives(
            label: 'A',
            n: 10,
            mean: 1,
            standardDeviation: -1,
          ),
          second: ReportedDescriptives(
            label: 'B',
            n: 10,
            mean: 2,
            standardDeviation: 1,
          ),
          reportedP: ReportedValue(value: 1.20, decimalPlaces: 2),
        ),
      );

      expect(checkById(checks, 'domain.a').status, ValidationStatus.fail);
      expect(checkById(checks, 'domain.p').status, ValidationStatus.fail);
    });

    test('flags invalid n domain', () {
      final checks = TTestValidator.validate(
        TTestValidationInput(
          kind: TTestKind.oneSample,
          first: ReportedDescriptives(
            label: 'Sample',
            n: 1,
            mean: 1,
            standardDeviation: 1,
          ),
          referenceMean: 0,
        ),
      );

      expect(checkById(checks, 'domain.sample').status, ValidationStatus.fail);
    });

    test('flags impossible GRIM mean and passes attainable one', () {
      final checks = TTestValidator.validate(
        TTestValidationInput(
          kind: TTestKind.oneSample,
          first: ReportedDescriptives(
            label: 'Integer scale',
            n: 3,
            mean: 1.23,
            standardDeviation: 1,
          ),
          referenceMean: 0,
          grimChecks: [
            GrimConfig(
              label: 'Impossible mean',
              reportedMean: 1.23,
              n: 3,
              decimalPlaces: 2,
            ),
            GrimConfig(
              label: 'Attainable mean',
              reportedMean: 1.33,
              n: 3,
              decimalPlaces: 2,
            ),
          ],
        ),
      );

      expect(
        checkById(checks, 'grim.impossible_mean').status,
        ValidationStatus.fail,
      );
      expect(
        checkById(checks, 'grim.attainable_mean').status,
        ValidationStatus.pass,
      );
    });

    test('marks paired summary without difference SD as not applicable', () {
      final checks = TTestValidator.validate(
        TTestValidationInput(
          kind: TTestKind.pairedSamples,
          paired: ReportedPairedDescriptives(
            first: ReportedDescriptives(
              label: 'Before',
              n: 10,
              mean: 20,
              standardDeviation: 3,
            ),
            second: ReportedDescriptives(
              label: 'After',
              n: 10,
              mean: 22,
              standardDeviation: 4,
            ),
          ),
          reportedT: ReportedValue(value: -1, decimalPlaces: 2),
        ),
      );

      expect(
        checkById(checks, 't.descriptives').status,
        ValidationStatus.notApplicable,
      );
    });

    test('accepts threshold p reporting', () {
      final checks = TTestValidator.validate(
        validStudentInput(
          p: ReportedValue(
            value: 0.05,
            decimalPlaces: 2,
            relation: ReportedRelation.lessThan,
          ),
        ),
      );
      expect(checkById(checks, 'p.t_df').status, ValidationStatus.pass);
    });
  });
}
