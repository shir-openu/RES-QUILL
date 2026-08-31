import 'package:res_quill/src/stats/stats.dart';
import 'package:test/test.dart';

void main() {
  group('one-sample worked examples', () {
    test('NIST wafer particle-count example', () {
      // NIST Engineering Statistics Handbook, section 7.2.2.
      final result = TTests.oneSampleFromRaw(
        values: [50, 48, 44, 56, 61, 52, 53, 55, 67, 51],
        referenceMean: 50,
      );

      expect(result.t, closeTo(1.782, 0.001));
      expect(result.degreesOfFreedom, 9);
      expect(result.pTwoTailed, closeTo(0.10847290878263133, 1e-12));
      expect(
        result.confidenceInterval.lower,
        closeTo(-0.9975708697063332, 1e-12),
      );
      expect(
        result.confidenceInterval.upper,
        closeTo(8.397570869706339, 1e-12),
      );
    });

    test('JMP energy-bar protein example', () {
      // JMP one-sample t-test tutorial, energy-bar table.
      final result = TTests.oneSampleFromRaw(
        values: [
          20.69,
          27.46,
          22.15,
          19.85,
          21.29,
          24.75,
          20.75,
          22.91,
          25.34,
          20.33,
          21.54,
          21.08,
          22.14,
          19.56,
          21.10,
          18.04,
          24.12,
          19.95,
          19.72,
          18.28,
          16.26,
          17.46,
          20.53,
          22.12,
          25.06,
          22.44,
          19.08,
          19.88,
          21.39,
          22.33,
          25.79,
        ],
        referenceMean: 20,
      );

      expect(result.t, closeTo(3.07, 0.005));
      expect(result.degreesOfFreedom, 30);
      expect(result.pTwoTailed, closeTo(0.0046, 0.0001));
    });

    test('Datanovia mice one-sample example', () {
      // Datanovia/datarium mice output. SD reconstructed from printed mean and t.
      final result = TTests.oneSampleFromSummary(
        sample: SummaryStats(
          n: 10,
          mean: 20.14,
          standardDeviation: 1.8963130888294555,
        ),
        referenceMean: 25,
      );

      expect(result.t, closeTo(-8.1045, 1e-10));
      expect(result.degreesOfFreedom, 9);
      expect(result.pTwoTailed, closeTo(1.995e-05, 1e-8));
      expect(
        result.confidenceInterval.lower,
        closeTo(-6.216540663976713, 1e-10),
      );
      expect(
        result.confidenceInterval.upper,
        closeTo(-3.503459336023286, 1e-10),
      );
    });
  });

  group('independent Student worked examples', () {
    test('NIST AUTO83B equal-variance example', () {
      final result = TTests.independentStudentFromSummary(
        first: SummaryStats(n: 249, mean: 20.14458, standardDeviation: 6.41470),
        second: SummaryStats(n: 79, mean: 30.48101, standardDeviation: 6.10771),
      );

      expect(result.t, closeTo(-12.62059, 0.00001));
      expect(result.degreesOfFreedom, 326);
      expect(result.effectSize.standardizerValue, closeTo(6.34260, 0.00001));
      expect(result.pTwoTailed, lessThan(1e-25));
    });

    test('JMP body-fat equal-variance example', () {
      final result = TTests.independentStudentFromSummary(
        first: SummaryStats(n: 10, mean: 22.29, standardDeviation: 5.32),
        second: SummaryStats(n: 13, mean: 14.95, standardDeviation: 6.84),
      );

      expect(result.t, closeTo(2.79996, 0.001));
      expect(result.degreesOfFreedom, 21);
      expect(result.pTwoTailed, closeTo(0.0107, 0.0001));
    });

    test('Datanovia genderweight Student example', () {
      final result = TTests.independentStudentFromSummary(
        first: SummaryStats(
          n: 20,
          mean: 63.49867,
          standardDeviation: 2.027610249697214,
        ),
        second: SummaryStats(
          n: 20,
          mean: 85.82612,
          standardDeviation: 4.353620418858437,
        ),
      );

      expect(result.t, closeTo(-20.8, 0.01));
      expect(result.degreesOfFreedom, 38);
      expect(result.pTwoTailed, closeTo(2.33e-22, 1e-23));
    });
  });

  group('independent Welch worked examples', () {
    test('StatsCodes simple Welch example', () {
      final result = TTests.independentWelchFromRaw(
        first: [
          19.1,
          21.0,
          17.5,
          22.1,
          17.0,
          19.2,
          19.1,
          22.7,
          21.2,
          23.3,
          18.2,
          19.1,
          22.2,
          20.0,
          19.3,
        ],
        second: [17.9, 18.8, 19.1, 21.4, 18.1, 22.6, 16.0, 19.9, 15.8, 22.3],
      );

      expect(result.t, closeTo(0.96948, 0.00001));
      expect(result.degreesOfFreedom, closeTo(16.488, 0.001));
      expect(result.pTwoTailed, closeTo(0.3463, 0.0001));
      expect(result.confidenceInterval.lower, closeTo(-1.035682, 0.000001));
      expect(result.confidenceInterval.upper, closeTo(2.789015, 0.000001));
    });

    test('JMP body-fat unequal-variance example', () {
      final result = TTests.independentWelchFromSummary(
        first: SummaryStats(n: 10, mean: 22.29, standardDeviation: 5.32),
        second: SummaryStats(n: 13, mean: 14.95, standardDeviation: 6.84),
      );

      expect(result.t, closeTo(2.8948, 0.0001));
      expect(result.degreesOfFreedom, closeTo(20.9888, 0.001));
      expect(result.pTwoTailed, closeTo(0.0086, 0.0001));
    });

    test('Datanovia genderweight Welch example', () {
      final result = TTests.independentWelchFromSummary(
        first: SummaryStats(
          n: 20,
          mean: 63.49867,
          standardDeviation: 2.027610249697214,
        ),
        second: SummaryStats(
          n: 20,
          mean: 85.82612,
          standardDeviation: 4.353620418858437,
        ),
      );

      expect(result.t, closeTo(-20.791, 1e-10));
      expect(result.degreesOfFreedom, closeTo(26.872, 1e-10));
      expect(result.pTwoTailed, closeTo(4.30e-18, 1e-20));
      expect(result.confidenceInterval.lower, closeTo(-24.53135, 0.0001));
      expect(result.confidenceInterval.upper, closeTo(-20.12353, 0.0001));
    });

    test('Res-Quill mock Welch example', () {
      final result = TTests.independentWelchFromSummary(
        first: SummaryStats(
          n: 20,
          mean: 81.40,
          standardDeviation: 5.537781765425369,
        ),
        second: SummaryStats(
          n: 31,
          mean: 72.40,
          standardDeviation: 9.261614190057113,
        ),
      );

      expect(result.t, closeTo(4.34, 1e-12));
      expect(result.degreesOfFreedom, closeTo(48.80, 1e-10));
      expect(result.pTwoTailed, lessThan(0.001));
      expect(result.confidenceInterval.lower, closeTo(4.83, 0.01));
      expect(result.confidenceInterval.upper, closeTo(13.17, 0.01));
    });
  });

  group('paired worked examples', () {
    test('NIST Bowker and Lieberman paired example', () {
      final result = TTests.pairedFromRaw(
        first: [73, 43, 47, 53, 58, 47, 52, 38, 61, 56, 56, 34, 55, 65, 75],
        second: [51, 41, 43, 41, 47, 32, 24, 43, 53, 52, 57, 44, 57, 40, 68],
      );

      expect(result.t, closeTo(2.81008, 0.00001));
      expect(result.degreesOfFreedom, 14);
      expect(result.pTwoTailed, closeTo(0.01390, 0.00001));
      expect(result.standardError, closeTo(2.84688, 0.00001));
    });

    test('JMP paired exam-score example', () {
      final result = TTests.pairedFromRaw(
        first: [
          63,
          65,
          56,
          100,
          88,
          83,
          77,
          92,
          90,
          84,
          68,
          74,
          87,
          64,
          71,
          88,
        ],
        second: [
          69,
          65,
          62,
          91,
          78,
          87,
          79,
          88,
          85,
          92,
          69,
          81,
          84,
          75,
          84,
          82,
        ],
      );

      expect(result.t, closeTo(-0.750, 0.001));
      expect(result.degreesOfFreedom, 15);
      expect(result.pTwoTailed, closeTo(0.4650, 0.0001));
    });

    test('Datanovia mice2 paired example', () {
      final result = TTests.pairedFromRaw(
        first: [
          187.2,
          194.2,
          231.7,
          200.5,
          201.7,
          235.0,
          208.7,
          172.4,
          184.6,
          189.6,
        ],
        second: [
          429.5,
          404.4,
          405.6,
          397.2,
          377.9,
          445.8,
          408.4,
          337.0,
          414.3,
          380.3,
        ],
      );

      expect(result.t, closeTo(-25.546, 0.001));
      expect(result.degreesOfFreedom, 9);
      expect(result.pTwoTailed, closeTo(1.039e-09, 1e-12));
      expect(result.confidenceInterval.lower, closeTo(-217.1442, 0.0001));
      expect(result.confidenceInterval.upper, closeTo(-181.8158, 0.0001));
    });
  });
}
