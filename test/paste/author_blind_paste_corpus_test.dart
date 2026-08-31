import 'dart:io';

import 'package:res_quill/src/paste/paste.dart';
import 'package:res_quill/src/stats/stats.dart';
import 'package:test/test.dart';

const _authorBlindDir =
    r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\PASTE_TEXT';

void main() {
  group('author-blind SAMPLE_UPLOADS paste corpus', () {
    test('spss_independent_samples asks for the variance row', () {
      final result = _parseSample('spss_independent_samples.txt');

      expect(result.status, PasteParseStatus.needsConfirmation);
      expect(result.detectedTestKind, isNull);
      expect(result.candidates.map((candidate) => candidate.kind).toList(), [
        TTestKind.independentStudent,
        TTestKind.independentWelch,
      ]);
      expect(
        result.candidates.any((candidate) => candidate.selectedByText),
        isFalse,
      );
      expect(_ambiguityIds(result), ['independent.variance_row']);
      _expectNoNullMissingKeys(result);
      expect(result.missingRequiredFields.map((field) => field.key).toList(), [
        PasteFieldKey.confidenceLevel,
      ]);

      final student = _candidate(result, TTestKind.independentStudent);
      final welch = _candidate(result, TTestKind.independentWelch);
      for (final candidate in [student, welch]) {
        expect(candidate.reportedPValueTail, ReportedPValueTail.twoTailed);
        _expectText(candidate.fields, PasteFieldKey.primaryLabel, 'Treatment');
        _expectNumber(candidate.fields, PasteFieldKey.primaryN, 20);
        _expectNumber(candidate.fields, PasteFieldKey.primaryMean, 82.7975);
        _expectNumber(
          candidate.fields,
          PasteFieldKey.primaryStandardDeviation,
          13.30169,
        );
        _expectText(candidate.fields, PasteFieldKey.secondaryLabel, 'Control');
        _expectNumber(candidate.fields, PasteFieldKey.secondaryN, 20);
        _expectNumber(candidate.fields, PasteFieldKey.secondaryMean, 72.0260);
        _expectNumber(
          candidate.fields,
          PasteFieldKey.secondaryStandardDeviation,
          14.86025,
        );
        _expectNumber(candidate.fields, PasteFieldKey.leveneF, 0.412);
        _expectNumber(candidate.fields, PasteFieldKey.leveneP, 0.525);
      }

      _expectNumber(student.fields, PasteFieldKey.reportedT, 2.245);
      _expectNumber(student.fields, PasteFieldKey.reportedDegreesOfFreedom, 38);
      _expectNumber(student.fields, PasteFieldKey.reportedP, 0.031);
      _expectNumber(
        student.fields,
        PasteFieldKey.reportedMeanDifference,
        10.77150,
      );
      _expectNumber(welch.fields, PasteFieldKey.reportedT, 2.245);
      _expectNumber(
        welch.fields,
        PasteFieldKey.reportedDegreesOfFreedom,
        37.114,
      );
      _expectNumber(welch.fields, PasteFieldKey.reportedP, 0.031);
      _expectNumber(
        welch.fields,
        PasteFieldKey.reportedMeanDifference,
        10.77150,
      );
    });

    test('spss_one_sample parses cleanly', () {
      final result = _parseSample('spss_one_sample.txt');

      expect(result.status, PasteParseStatus.confident);
      expect(result.detectedTestKind, TTestKind.oneSample);
      _expectNoNullMissingKeys(result);
      final candidate = result.selectedCandidate!;
      _expectText(candidate.fields, PasteFieldKey.primaryLabel, 'protein');
      _expectNumber(candidate.fields, PasteFieldKey.primaryN, 31);
      _expectNumber(candidate.fields, PasteFieldKey.primaryMean, 21.4);
      _expectNumber(
        candidate.fields,
        PasteFieldKey.primaryStandardDeviation,
        2.54,
      );
      _expectNumber(candidate.fields, PasteFieldKey.referenceMean, 20);
      _expectNumber(candidate.fields, PasteFieldKey.reportedT, 3.066);
      _expectNumber(
        candidate.fields,
        PasteFieldKey.reportedDegreesOfFreedom,
        30,
      );
      _expectNumber(candidate.fields, PasteFieldKey.reportedP, 0.005);
      _expectNumber(
        candidate.fields,
        PasteFieldKey.reportedMeanDifference,
        1.4,
      );
      _expectNumber(candidate.fields, PasteFieldKey.ciLower, 0.4674);
      _expectNumber(candidate.fields, PasteFieldKey.ciUpper, 2.3320);
      _expectNumber(candidate.fields, PasteFieldKey.confidenceLevel, 0.95);
    });

    test('spss_one_sample_p_is_000 converts rounded zero p safely', () {
      final result = _parseSample('spss_one_sample_p_is_000.txt');

      expect(result.status, PasteParseStatus.needsConfirmation);
      expect(result.detectedTestKind, TTestKind.oneSample);
      _expectNoNullMissingKeys(result);
      final candidate = _candidate(result, TTestKind.oneSample);
      _expectNumber(candidate.fields, PasteFieldKey.referenceMean, 100);
      _expectNumber(candidate.fields, PasteFieldKey.reportedT, 12.418);
      _expectNumber(
        candidate.fields,
        PasteFieldKey.reportedDegreesOfFreedom,
        326,
      );
      final p = _number(candidate.fields, PasteFieldKey.reportedP);
      expect(p.value, 0.001);
      expect(p.relation, ReportedRelation.lessThan);
      expect(p.spssRoundedZeroP, isTrue);
      _expectNumber(
        candidate.fields,
        PasteFieldKey.reportedMeanDifference,
        -10.34,
      );
      expect(
        result.missingRequiredFields.map((field) => field.key),
        isNot(
          containsAll([
            PasteFieldKey.reportedT,
            PasteFieldKey.reportedDegreesOfFreedom,
            PasteFieldKey.reportedP,
          ]),
        ),
      );
    });

    test('apa_sentence_welch keeps df, strict p, CI, and tail ambiguity', () {
      final result = _parseSample('apa_sentence_welch.txt');

      expect(result.status, PasteParseStatus.needsConfirmation);
      expect(result.detectedTestKind, TTestKind.independentWelch);
      expect(_ambiguityIds(result), ['p.tail.unknown']);
      _expectNoNullMissingKeys(result);
      final candidate = _candidate(result, TTestKind.independentWelch);
      _expectText(
        candidate.fields,
        PasteFieldKey.primaryLabel,
        'treatment group',
      );
      _expectNumber(candidate.fields, PasteFieldKey.primaryN, 25);
      _expectNumber(candidate.fields, PasteFieldKey.primaryMean, 81.40);
      _expectNumber(
        candidate.fields,
        PasteFieldKey.primaryStandardDeviation,
        11.20,
      );
      _expectText(
        candidate.fields,
        PasteFieldKey.secondaryLabel,
        'control group',
      );
      _expectNumber(candidate.fields, PasteFieldKey.secondaryN, 26);
      _expectNumber(candidate.fields, PasteFieldKey.secondaryMean, 72.40);
      _expectNumber(
        candidate.fields,
        PasteFieldKey.secondaryStandardDeviation,
        13.90,
      );
      _expectNumber(candidate.fields, PasteFieldKey.reportedT, 4.34);
      _expectNumber(
        candidate.fields,
        PasteFieldKey.reportedDegreesOfFreedom,
        48.80,
      );
      final p = _number(candidate.fields, PasteFieldKey.reportedP);
      expect(p.value, 0.001);
      expect(p.relation, ReportedRelation.lessThan);
      expect(p.spssRoundedZeroP, isFalse);
      _expectNumber(candidate.fields, PasteFieldKey.ciLower, 4.83);
      _expectNumber(candidate.fields, PasteFieldKey.ciUpper, 13.17);
    });

    test('refuse_anova_table refuses ANOVA explicitly', () {
      final result = _parseSample('refuse_anova_table.txt');

      expect(result.status, PasteParseStatus.cannotParse);
      expect(result.refusalReasons, contains('ANOVA output is not supported.'));
      _expectNoNullMissingKeys(result);
    });

    test('refuse_empty refuses empty input explicitly', () {
      final result = _parseSample('refuse_empty.txt');

      expect(result.status, PasteParseStatus.cannotParse);
      expect(result.refusalReasons, contains('Input is empty.'));
      _expectNoNullMissingKeys(result);
    });

    test('refuse_prose refuses unsupported prose', () {
      final result = _parseSample('refuse_prose.txt');

      expect(result.status, PasteParseStatus.cannotParse);
      expect(
        result.refusalReasons,
        contains('No supported t-test output shape was found.'),
      );
      _expectNoNullMissingKeys(result);
    });
  });

  group('realistic SPSS independent-samples variants', () {
    for (final variant in _spssIndependentVariants) {
      test('${variant.name} asks for the variance row', () {
        final result = TTestPasteParser.parse(variant.input);

        expect(result.status, PasteParseStatus.needsConfirmation);
        expect(result.detectedTestKind, isNull);
        expect(_ambiguityIds(result), ['independent.variance_row']);
        _expectNoNullMissingKeys(result);
        final student = _candidate(result, TTestKind.independentStudent);
        final welch = _candidate(result, TTestKind.independentWelch);
        for (final candidate in [student, welch]) {
          expect(candidate.selectedByText, isFalse);
          _expectText(
            candidate.fields,
            PasteFieldKey.primaryLabel,
            'Treatment',
          );
          _expectNumber(candidate.fields, PasteFieldKey.primaryN, 20);
          _expectNumber(candidate.fields, PasteFieldKey.primaryMean, 82.7975);
          _expectNumber(
            candidate.fields,
            PasteFieldKey.primaryStandardDeviation,
            13.30169,
          );
          _expectText(
            candidate.fields,
            PasteFieldKey.secondaryLabel,
            'Control',
          );
          _expectNumber(candidate.fields, PasteFieldKey.secondaryN, 20);
          _expectNumber(candidate.fields, PasteFieldKey.secondaryMean, 72.0260);
          _expectNumber(
            candidate.fields,
            PasteFieldKey.secondaryStandardDeviation,
            14.86025,
          );
          _expectNumber(candidate.fields, PasteFieldKey.leveneF, 0.412);
          _expectNumber(candidate.fields, PasteFieldKey.leveneP, 0.525);
          _expectNumber(candidate.fields, PasteFieldKey.reportedT, 2.245);
          _expectNumber(candidate.fields, PasteFieldKey.reportedP, 0.031);
        }
        _expectNumber(
          student.fields,
          PasteFieldKey.reportedDegreesOfFreedom,
          38,
        );
        _expectNumber(
          welch.fields,
          PasteFieldKey.reportedDegreesOfFreedom,
          37.114,
        );
      });
    }
  });
}

TTestPasteParseResult _parseSample(String name) {
  final file = File('$_authorBlindDir\\$name');
  expect(file.existsSync(), isTrue, reason: 'Missing author-blind file $name');
  return TTestPasteParser.parse(file.readAsStringSync());
}

List<String> _ambiguityIds(TTestPasteParseResult result) {
  return result.ambiguities.map((ambiguity) => ambiguity.id).toList();
}

PasteTTestCandidate _candidate(TTestPasteParseResult result, TTestKind kind) {
  return result.candidates.singleWhere((candidate) => candidate.kind == kind);
}

void _expectNoNullMissingKeys(TTestPasteParseResult result) {
  expect(
    result.missingRequiredFields.where((field) => field.key == null),
    isEmpty,
  );
}

void _expectText(
  List<PasteExtractedField<Object>> fields,
  PasteFieldKey key,
  String expected,
) {
  expect(_field(fields, key).value, expected);
}

void _expectNumber(
  List<PasteExtractedField<Object>> fields,
  PasteFieldKey key,
  double expected,
) {
  expect(_number(fields, key).value, closeTo(expected, _tolerance(expected)));
}

PasteNumber _number(
  List<PasteExtractedField<Object>> fields,
  PasteFieldKey key,
) {
  return _field(fields, key).value as PasteNumber;
}

PasteExtractedField<Object> _field(
  List<PasteExtractedField<Object>> fields,
  PasteFieldKey key,
) {
  return fields.singleWhere((field) => field.key == key);
}

double _tolerance(double expected) {
  return expected.abs() < 1 ? 1e-9 : expected.abs() * 1e-9;
}

const _spssIndependentVariants = [
  _Variant('loose spacing separated sections', '''
Group Statistics

group              N      Mean       Std. Deviation     Std. Error Mean
score       Treatment     20     82.7975       13.30169          2.97435
            Control       20     72.0260       14.86025          3.32285

Independent Samples Test

Levene's Test for Equality of Variances
F       Sig.
score     Equal variances assumed       0.412       0.525
          Equal variances not assumed

t-test for Equality of Means
t       df       Sig. (2-tailed)       Mean Difference
score     Equal variances assumed       2.245       38       .031       10.77150
          Equal variances not assumed   2.245       37.114   .031       10.77150
'''),
  _Variant('tab separated copy', '''
Group Statistics
group\tN\tMean\tStd. Deviation\tStd. Error Mean
score\tTreatment\t20\t82.7975\t13.30169\t2.97435
\tControl\t20\t72.0260\t14.86025\t3.32285

Independent Samples Test
Levene's Test for Equality of Variances
F\tSig.
score\tEqual variances assumed\t0.412\t0.525
\tEqual variances not assumed

t-test for Equality of Means
t\tdf\tSig. (2-tailed)\tMean Difference
score\tEqual variances assumed\t2.245\t38\t.031\t10.77150
\tEqual variances not assumed\t2.245\t37.114\t.031\t10.77150
'''),
  _Variant('wrapped headers', '''
Group Statistics
              group        N       Mean
                          Std. Deviation   Std. Error Mean
score         Treatment   20    82.7975      13.30169          2.97435
              Control     20    72.0260      14.86025          3.32285

Independent Samples Test
Levene's Test for Equality
of Variances
                                      F        Sig.
score   Equal variances assumed     0.412     0.525
        Equal variances not assumed

t-test for Equality
of Means
                                      t        df
                                      Sig. (2-tailed)   Mean Difference
score   Equal variances assumed     2.245     38       .031              10.77150
        Equal variances not assumed 2.245     37.114   .031              10.77150
'''),
  _Variant('decimal commas', '''
Group Statistics

              group        N       Mean    Std. Deviation   Std. Error Mean
score         Treatment   20    82,7975      13,30169          2,97435
              Control     20    72,0260      14,86025          3,32285

Independent Samples Test
Levene's Test for Equality of Variances
                                      F        Sig.
score   Equal variances assumed     0,412     0,525
        Equal variances not assumed

t-test for Equality of Means
                                      t        df      Sig. (2-tailed)   Mean Difference
score   Equal variances assumed     2,245     38       ,031              10,77150
        Equal variances not assumed 2,245     37,114   ,031              10,77150
'''),
  _Variant('tables in reverse order', '''
Independent Samples Test

Levene's Test for Equality of Variances
                                      F        Sig.
score   Equal variances assumed     0.412     0.525
        Equal variances not assumed

t-test for Equality of Means
                                      t        df      Sig. (2-tailed)   Mean Difference
score   Equal variances assumed     2.245     38       .031              10.77150
        Equal variances not assumed 2.245     37.114   .031              10.77150

Group Statistics
              group        N       Mean    Std. Deviation   Std. Error Mean
score         Treatment   20    82.7975      13.30169          2.97435
              Control     20    72.0260      14.86025          3.32285
'''),
];

class _Variant {
  const _Variant(this.name, this.input);

  final String name;
  final String input;
}
