import 'package:res_quill/src/stats/stats.dart';
import 'package:test/test.dart';

void main() {
  group('edge cases', () {
    test(
      'n=2 one-sample returns t and leaves exact Hedges correction undefined',
      () {
        final result = TTests.oneSampleFromRaw(
          values: [1, 3],
          referenceMean: 1,
        );

        expect(result.t, closeTo(1, 1e-14));
        expect(result.degreesOfFreedom, 1);
        expect(result.pTwoTailed, closeTo(0.5, 1e-14));
        expect(
          result.effectSize.cohensD,
          closeTo(1 / 1.4142135623730951, 1e-14),
        );
        expect(result.effectSize.correction, isNull);
        expect(result.effectSize.hedgesG, isNull);
      },
    );

    test('zero standard error throws a StatsException instead of NaN', () {
      expect(
        () => TTests.oneSampleFromRaw(values: [2, 2, 2], referenceMean: 2),
        throwsA(isA<StatsException>()),
      );
      expect(
        () => TTests.independentStudentFromSummary(
          first: SummaryStats(n: 3, mean: 2, standardDeviation: 0),
          second: SummaryStats(n: 3, mean: 2, standardDeviation: 0),
        ),
        throwsA(isA<StatsException>()),
      );
    });

    test('hugely unequal ns produce finite Welch output', () {
      final result = TTests.independentWelchFromSummary(
        first: SummaryStats(n: 2, mean: 10, standardDeviation: 3),
        second: SummaryStats(n: 100000, mean: 9, standardDeviation: 1),
      );

      expect(result.t.isFinite, isTrue);
      expect(result.degreesOfFreedom.isFinite, isTrue);
      expect(result.degreesOfFreedom, greaterThan(1));
      expect(result.pTwoTailed, inInclusiveRange(0, 1));
    });

    test('hugely unequal variances produce non-integer Welch df', () {
      final result = TTests.independentWelchFromSummary(
        first: SummaryStats(n: 8, mean: 5, standardDeviation: 100),
        second: SummaryStats(n: 40, mean: 1, standardDeviation: 1),
      );

      expect(result.degreesOfFreedom, closeTo(7.000280002297417, 1e-10));
      expect(result.degreesOfFreedom % 1, isNot(closeTo(0, 1e-8)));
    });

    test('very large n remains finite', () {
      final result = TTests.oneSampleFromSummary(
        sample: SummaryStats(n: 1000000, mean: 0.01, standardDeviation: 1),
        referenceMean: 0,
      );

      expect(result.t, closeTo(10, 1e-14));
      expect(result.degreesOfFreedom, 999999);
      expect(result.pTwoTailed.isNaN, isFalse);
      expect(result.pTwoTailed, inInclusiveRange(0, 1));
    });

    test('p below 1e-10 is small, finite, and not silently NaN', () {
      final result = TTests.oneSampleFromSummary(
        sample: SummaryStats(n: 100, mean: 1, standardDeviation: 1),
        referenceMean: 0,
      );

      expect(result.t, closeTo(10, 1e-14));
      expect(result.pTwoTailed, lessThan(1e-10));
      expect(result.pTwoTailed.isNaN, isFalse);
    });

    test('negative t has the same two-tailed p as its positive mirror', () {
      final positive = TTests.independentWelchFromSummary(
        first: SummaryStats(n: 20, mean: 10, standardDeviation: 2),
        second: SummaryStats(n: 18, mean: 8, standardDeviation: 2.5),
      );
      final negative = TTests.independentWelchFromSummary(
        first: SummaryStats(n: 18, mean: 8, standardDeviation: 2.5),
        second: SummaryStats(n: 20, mean: 10, standardDeviation: 2),
      );

      expect(negative.t, closeTo(-positive.t, 1e-14));
      expect(negative.pTwoTailed, closeTo(positive.pTwoTailed, 1e-14));
      expect(negative.pLess, closeTo(positive.pGreater, 1e-14));
    });
  });
}
