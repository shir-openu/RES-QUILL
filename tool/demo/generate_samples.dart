import 'dart:io';

import 'package:res_quill/src/report/report.dart';
import 'package:res_quill/src/stats/stats.dart';

const outputPath =
    r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\REPORT_SAMPLES_2026-08-30_EN.html';

void main() {
  final cases = _demoCases();
  final rendered = <_RenderedCase>[];
  for (final demoCase in cases) {
    rendered.add(_renderCase(demoCase));
  }

  final html = _page(rendered);
  File(outputPath).writeAsStringSync(html);
  final blocked = rendered.where((caseOutput) => caseOutput.report.isBlocked);
  stdout.writeln('Wrote $outputPath');
  stdout.writeln('Cases: ${rendered.length}');
  stdout.writeln('Blocked cases shown: ${blocked.length}');
}

_RenderedCase _renderCase(DemoCase demoCase) {
  final result = demoCase.compute();
  final validationInput = demoCase.validationInput(result);
  final checks = TTestValidator.validate(validationInput);
  final report = TTestReportGenerator.generate(
    result: result,
    validationChecks: checks,
    context: demoCase.context,
    options: demoCase.options,
    evidenceSources: demoCase.evidenceSources,
  );
  return _RenderedCase(
    demoCase: demoCase,
    result: result,
    checks: checks,
    report: report,
  );
}

List<DemoCase> _demoCases() {
  return [
    _rawCase(
      id: 'W01',
      title: 'One-sample: NIST wafer particle counts',
      source: 'https://www.itl.nist.gov/div898/handbook/prc/section2/prc22.htm',
      inputSummary:
          'values = [50, 48, 44, 56, 61, 52, 53, 55, 67, 51]\nreferenceMean = 50',
      compute: () => TTests.oneSampleFromRaw(
        values: [50, 48, 44, 56, 61, 52, 53, 55, 67, 51],
        referenceMean: 50,
      ),
      validationInput: (result) => TTestValidationInput(
        kind: TTestKind.oneSample,
        first: _reported(result.primary, 'Wafer counts'),
        referenceMean: 50,
        reportedT: ReportedValue(value: 1.782, decimalPlaces: 3),
        reportedDegreesOfFreedom: ReportedValue(value: 9, decimalPlaces: 0),
        reportedP: ReportedValue(value: 0.108, decimalPlaces: 3),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'particle counts',
        primaryLabel: 'Wafer counts',
        referenceLabel: 'the reference value',
      ),
      evidenceSources: EvidenceSourceRegistry.oneSampleRaw(),
    ),
    _rawCase(
      id: 'W02',
      title: 'One-sample: JMP energy-bar protein',
      source:
          'https://www.jmp.com/en/statistics-knowledge-portal/inferential-statistics/hypothesis-testing/one-sample-t-test',
      inputSummary:
          'values = [20.69, 27.46, 22.15, 19.85, 21.29, 24.75, 20.75, 22.91, 25.34, 20.33, 21.54, 21.08, 22.14, 19.56, 21.10, 18.04, 24.12, 19.95, 19.72, 18.28, 16.26, 17.46, 20.53, 22.12, 25.06, 22.44, 19.08, 19.88, 21.39, 22.33, 25.79]\nreferenceMean = 20',
      compute: () => TTests.oneSampleFromRaw(
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
      ),
      validationInput: (result) => TTestValidationInput(
        kind: TTestKind.oneSample,
        first: _reported(result.primary, 'Protein'),
        referenceMean: 20,
        reportedT: ReportedValue(value: 3.066, decimalPlaces: 3),
        reportedDegreesOfFreedom: ReportedValue(value: 30, decimalPlaces: 0),
        reportedP: ReportedValue(value: 0.0046, decimalPlaces: 4),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'protein grams',
        primaryLabel: 'Energy bars',
        referenceLabel: 'the reference value',
      ),
      evidenceSources: EvidenceSourceRegistry.oneSampleRaw(),
    ),
    _summaryCase(
      id: 'W03',
      title: 'One-sample: Datanovia mice',
      source: 'https://rpkgs.datanovia.com/datarium/reference/mice.html',
      input: TTestValidationInput(
        kind: TTestKind.oneSample,
        first: ReportedDescriptives(
          label: 'Mice',
          n: 10,
          mean: 20.14,
          standardDeviation: 1.8963130888294555,
        ),
        referenceMean: 25,
        reportedT: ReportedValue(value: -8.1045, decimalPlaces: 4),
        reportedDegreesOfFreedom: ReportedValue(value: 9, decimalPlaces: 0),
        reportedP: ReportedValue(
          value: 0.001,
          decimalPlaces: 3,
          relation: ReportedRelation.lessThan,
        ),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'weight',
        primaryLabel: 'Mice',
        referenceLabel: 'the reference value',
      ),
    ),
    _summaryCase(
      id: 'W04',
      title: 'Student independent: NIST AUTO83B',
      source:
          'https://www.itl.nist.gov/div898/handbook/eda/section3/eda353.htm',
      input: TTestValidationInput(
        kind: TTestKind.independentStudent,
        first: ReportedDescriptives(
          label: 'U.S. cars',
          n: 249,
          mean: 20.14458,
          standardDeviation: 6.41470,
        ),
        second: ReportedDescriptives(
          label: 'Japanese cars',
          n: 79,
          mean: 30.48101,
          standardDeviation: 6.10771,
        ),
        reportedT: ReportedValue(value: -12.62059, decimalPlaces: 5),
        reportedDegreesOfFreedom: ReportedValue(value: 326, decimalPlaces: 0),
        reportedP: ReportedValue(
          value: 1e-25,
          decimalPlaces: 25,
          relation: ReportedRelation.lessThan,
        ),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'miles per gallon',
        primaryLabel: 'U.S. cars',
        secondaryLabel: 'Japanese cars',
      ),
    ),
    _summaryCase(
      id: 'W05',
      title: 'Student independent: JMP body fat',
      source:
          'https://www.jmp.com/en/statistics-knowledge-portal/inferential-statistics/hypothesis-testing/two-sample-t-test',
      input: _studentBodyFatInput(TTestKind.independentStudent),
      context: const TTestReportContext(
        outcomeLabel: 'body-fat percentage',
        primaryLabel: 'Women',
        secondaryLabel: 'Men',
      ),
    ),
    _summaryCase(
      id: 'W06',
      title: 'Student independent: Datanovia genderweight',
      source:
          'https://www.datanovia.com/learn/biostatistics/two-groups/t-test-in-r',
      input: TTestValidationInput(
        kind: TTestKind.independentStudent,
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
        reportedT: ReportedValue(value: -20.8, decimalPlaces: 1),
        reportedDegreesOfFreedom: ReportedValue(value: 38, decimalPlaces: 0),
        reportedP: ReportedValue(
          value: 0.001,
          decimalPlaces: 3,
          relation: ReportedRelation.lessThan,
        ),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'weight',
        primaryLabel: 'Women',
        secondaryLabel: 'Men',
      ),
    ),
    _rawCase(
      id: 'W07',
      title: 'Welch independent: StatsCodes raw example',
      source:
          'https://www.statscodes.com/tests-and-intervals/welchs-two-sample-t-tests-in-r/',
      inputSummary:
          'first = [19.1, 21.0, 17.5, 22.1, 17.0, 19.2, 19.1, 22.7, 21.2, 23.3, 18.2, 19.1, 22.2, 20.0, 19.3]\nsecond = [17.9, 18.8, 19.1, 21.4, 18.1, 22.6, 16.0, 19.9, 15.8, 22.3]',
      compute: () => TTests.independentWelchFromRaw(
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
      ),
      validationInput: (result) => TTestValidationInput(
        kind: TTestKind.independentWelch,
        first: _reported(result.primary, 'First group'),
        second: _reported(result.secondary!, 'Second group'),
        reportedT: ReportedValue(value: 0.96948, decimalPlaces: 5),
        reportedDegreesOfFreedom: ReportedValue(
          value: result.degreesOfFreedom,
          decimalPlaces: 12,
        ),
        reportedP: ReportedValue(value: 0.3463, decimalPlaces: 4),
        reportedMeanDifference: ReportedValue(
          value: result.meanDifference,
          decimalPlaces: 12,
        ),
        reportedStandardError: ReportedValue(
          value: result.standardError,
          decimalPlaces: 12,
        ),
        reportedCiLower: ReportedValue(
          value: result.confidenceInterval.lower,
          decimalPlaces: 12,
        ),
        reportedCiUpper: ReportedValue(
          value: result.confidenceInterval.upper,
          decimalPlaces: 12,
        ),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'scores',
        primaryLabel: 'First group',
        secondaryLabel: 'Second group',
      ),
      evidenceSources: EvidenceSourceRegistry.independentRaw(),
    ),
    _summaryCase(
      id: 'W08',
      title: 'Welch independent: JMP body fat',
      source:
          'https://www.jmp.com/en/statistics-knowledge-portal/inferential-statistics/hypothesis-testing/two-sample-t-test',
      input: TTestValidationInput(
        kind: TTestKind.independentWelch,
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
        reportedT: ReportedValue(value: 2.89, decimalPlaces: 2),
        reportedDegreesOfFreedom: ReportedValue(value: 20.99, decimalPlaces: 2),
        reportedP: ReportedValue(value: 0.009, decimalPlaces: 3),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'body-fat percentage',
        primaryLabel: 'Women',
        secondaryLabel: 'Men',
      ),
    ),
    _summaryCase(
      id: 'W09',
      title: 'Welch independent: Datanovia genderweight',
      source:
          'https://rpkgs.datanovia.com/datarium/reference/genderweight.html',
      input: TTestValidationInput(
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
        reportedT: ReportedValue(value: -20.791, decimalPlaces: 3),
        reportedDegreesOfFreedom: ReportedValue(
          value: 26.872,
          decimalPlaces: 3,
        ),
        reportedP: ReportedValue(
          value: 2.2e-16,
          decimalPlaces: 16,
          relation: ReportedRelation.lessThan,
        ),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'weight',
        primaryLabel: 'Women',
        secondaryLabel: 'Men',
      ),
    ),
    _summaryCase(
      id: 'W10',
      title: 'Welch independent: Res-Quill mock',
      source: 'Res-Quill task prompt',
      input: TTestValidationInput(
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
        reportedDegreesOfFreedom: ReportedValue(value: 48.80, decimalPlaces: 2),
        reportedP: ReportedValue(
          value: 0.001,
          decimalPlaces: 3,
          relation: ReportedRelation.lessThan,
        ),
        reportedMeanDifference: ReportedValue(value: 9, decimalPlaces: 0),
        reportedStandardError: ReportedValue(
          value: 2.073732718894009,
          decimalPlaces: 12,
        ),
        reportedCiLower: ReportedValue(value: 4.83, decimalPlaces: 2),
        reportedCiUpper: ReportedValue(value: 13.17, decimalPlaces: 2),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'test scores',
        primaryLabel: 'Retrieval practice',
        secondaryLabel: 'Restudy',
      ),
    ),
    _rawCase(
      id: 'W11',
      title: 'Paired samples: NIST Bowker and Lieberman',
      source:
          'https://www.itl.nist.gov/div898/software/dataplot/refman1/auxillar/t_test.htm',
      inputSummary:
          'first = [73, 43, 47, 53, 58, 47, 52, 38, 61, 56, 56, 34, 55, 65, 75]\nsecond = [51, 41, 43, 41, 47, 32, 24, 43, 53, 52, 57, 44, 57, 40, 68]',
      compute: () => TTests.pairedFromRaw(
        first: [73, 43, 47, 53, 58, 47, 52, 38, 61, 56, 56, 34, 55, 65, 75],
        second: [51, 41, 43, 41, 47, 32, 24, 43, 53, 52, 57, 44, 57, 40, 68],
      ),
      validationInput: (result) => TTestValidationInput(
        kind: TTestKind.pairedSamples,
        paired: _reportedPaired(result, 'First time', 'Second time'),
        reportedT: ReportedValue(value: 2.81009, decimalPlaces: 5),
        reportedDegreesOfFreedom: ReportedValue(value: 14, decimalPlaces: 0),
        reportedP: ReportedValue(value: 0.01390, decimalPlaces: 5),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'scores',
        primaryLabel: 'First time',
        secondaryLabel: 'Second time',
      ),
      evidenceSources: EvidenceSourceRegistry.pairedRaw(),
    ),
    _rawCase(
      id: 'W12',
      title: 'Paired samples: JMP exam scores',
      source:
          'https://www.jmp.com/en/statistics-knowledge-portal/inferential-statistics/hypothesis-testing/paired-t-test',
      inputSummary:
          'first = [63, 65, 56, 100, 88, 83, 77, 92, 90, 84, 68, 74, 87, 64, 71, 88]\nsecond = [69, 65, 62, 91, 78, 87, 79, 88, 85, 92, 69, 81, 84, 75, 84, 82]',
      compute: () => TTests.pairedFromRaw(
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
      ),
      validationInput: (result) => TTestValidationInput(
        kind: TTestKind.pairedSamples,
        paired: _reportedPaired(result, 'Before', 'After'),
        reportedT: ReportedValue(value: -0.750, decimalPlaces: 3),
        reportedDegreesOfFreedom: ReportedValue(value: 15, decimalPlaces: 0),
        reportedP: ReportedValue(value: 0.465, decimalPlaces: 3),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'exam scores',
        primaryLabel: 'Before',
        secondaryLabel: 'After',
      ),
      evidenceSources: EvidenceSourceRegistry.pairedRaw(),
    ),
    _rawCase(
      id: 'W13',
      title: 'Paired samples: Datanovia mice2',
      source: 'https://rpkgs.datanovia.com/datarium/reference/mice2.html',
      inputSummary:
          'first = [187.2, 194.2, 231.7, 200.5, 201.7, 235.0, 208.7, 172.4, 184.6, 189.6]\nsecond = [429.5, 404.4, 405.6, 397.2, 377.9, 445.8, 408.4, 337.0, 414.3, 380.3]',
      compute: () => TTests.pairedFromRaw(
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
      ),
      validationInput: (result) => TTestValidationInput(
        kind: TTestKind.pairedSamples,
        paired: _reportedPaired(result, 'Before', 'After'),
        reportedT: ReportedValue(value: -25.546, decimalPlaces: 3),
        reportedDegreesOfFreedom: ReportedValue(value: 9, decimalPlaces: 0),
        reportedP: ReportedValue(
          value: 0.001,
          decimalPlaces: 3,
          relation: ReportedRelation.lessThan,
        ),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'weight',
        primaryLabel: 'Before',
        secondaryLabel: 'After',
      ),
      evidenceSources: EvidenceSourceRegistry.pairedRaw(),
    ),
    _summaryCase(
      id: 'B01',
      title: 'Blocked: t does not match descriptives',
      source: 'Deliberately inconsistent control',
      input: _studentBodyFatInput(
        TTestKind.independentStudent,
        reportedT: ReportedValue(value: 1.25, decimalPlaces: 2),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'body-fat percentage',
        primaryLabel: 'Women',
        secondaryLabel: 'Men',
      ),
    ),
    _summaryCase(
      id: 'B02',
      title: 'Blocked: p does not match t and df',
      source: 'Deliberately inconsistent control',
      input: _studentBodyFatInput(
        TTestKind.independentWelch,
        reportedT: ReportedValue(value: 2.89, decimalPlaces: 2),
        reportedDegreesOfFreedom: ReportedValue(value: 20.99, decimalPlaces: 2),
        reportedP: ReportedValue(value: 0.900, decimalPlaces: 3),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'body-fat percentage',
        primaryLabel: 'Women',
        secondaryLabel: 'Men',
      ),
    ),
    _summaryCase(
      id: 'B03',
      title: 'Blocked: df does not match sample size',
      source: 'Deliberately inconsistent control',
      input: TTestValidationInput(
        kind: TTestKind.oneSample,
        first: ReportedDescriptives(
          label: 'Wafer counts',
          n: 10,
          mean: 53.7,
          standardDeviation: 6.562637297207353,
        ),
        referenceMean: 50,
        reportedT: ReportedValue(value: 1.78, decimalPlaces: 2),
        reportedDegreesOfFreedom: ReportedValue(value: 8, decimalPlaces: 0),
        reportedP: ReportedValue(value: 0.108, decimalPlaces: 3),
      ),
      context: const TTestReportContext(
        outcomeLabel: 'particle counts',
        primaryLabel: 'Wafer counts',
        referenceLabel: 'the reference value',
      ),
    ),
  ];
}

DemoCase _summaryCase({
  required String id,
  required String title,
  required String source,
  required TTestValidationInput input,
  required TTestReportContext context,
}) {
  return DemoCase(
    id: id,
    title: title,
    source: source,
    inputSummary: _inputSummary(input),
    compute: () => TTestValidator.resultFromInput(input),
    validationInput: (_) => input,
    context: context,
    evidenceSources: EvidenceSourceRegistry.fromValidationInput(input),
  );
}

DemoCase _rawCase({
  required String id,
  required String title,
  required String source,
  required String inputSummary,
  required TTestResult Function() compute,
  required TTestValidationInput Function(TTestResult result) validationInput,
  required TTestReportContext context,
  required EvidenceSourceRegistry evidenceSources,
}) {
  return DemoCase(
    id: id,
    title: title,
    source: source,
    inputSummary: inputSummary,
    compute: compute,
    validationInput: validationInput,
    context: context,
    evidenceSources: evidenceSources,
  );
}

TTestValidationInput _studentBodyFatInput(
  TTestKind kind, {
  ReportedValue? reportedT,
  ReportedValue? reportedDegreesOfFreedom,
  ReportedValue? reportedP,
}) {
  return TTestValidationInput(
    kind: kind,
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
    reportedT:
        reportedT ??
        ReportedValue(
          value: kind == TTestKind.independentWelch ? 2.8948 : 2.80,
          decimalPlaces: kind == TTestKind.independentWelch ? 4 : 2,
        ),
    reportedDegreesOfFreedom:
        reportedDegreesOfFreedom ??
        ReportedValue(
          value: kind == TTestKind.independentWelch ? 20.9888 : 21,
          decimalPlaces: kind == TTestKind.independentWelch ? 4 : 0,
        ),
    reportedP:
        reportedP ??
        ReportedValue(
          value: kind == TTestKind.independentWelch ? 0.0086 : 0.0107,
          decimalPlaces: 4,
        ),
  );
}

ReportedDescriptives _reported(SummaryStats stats, String label) {
  return ReportedDescriptives(
    label: label,
    n: stats.n,
    mean: stats.mean,
    standardDeviation: stats.standardDeviation,
  );
}

ReportedPairedDescriptives _reportedPaired(
  TTestResult result,
  String firstLabel,
  String secondLabel,
) {
  return ReportedPairedDescriptives(
    first: _reported(result.primary, firstLabel),
    second: _reported(result.secondary!, secondLabel),
    meanDifference: result.pairedDifferences!.mean,
    differenceStandardDeviation: result.pairedDifferences!.standardDeviation,
  );
}

String _inputSummary(TTestValidationInput input) {
  final buffer = StringBuffer()
    ..writeln('kind = ${input.kind.name}')
    ..write(_descriptiveInput('first', input.first));
  if (input.second != null) {
    buffer.write(_descriptiveInput('second', input.second));
  }
  if (input.paired != null) {
    buffer
      ..write(_descriptiveInput('paired.first', input.paired!.first))
      ..write(_descriptiveInput('paired.second', input.paired!.second))
      ..writeln('paired.meanDifference = ${input.paired!.meanDifference}')
      ..writeln(
        'paired.differenceStandardDeviation = '
        '${input.paired!.differenceStandardDeviation}',
      );
  }
  if (input.referenceMean != null) {
    buffer.writeln('referenceMean = ${input.referenceMean}');
  }
  if (input.reportedT != null) {
    buffer.writeln('reportedT = ${input.reportedT!.value}');
  }
  if (input.reportedDegreesOfFreedom != null) {
    buffer.writeln('reportedDf = ${input.reportedDegreesOfFreedom!.value}');
  }
  if (input.reportedP != null) {
    buffer.writeln(
      'reportedP = ${input.reportedP!.relation.name} '
      '${input.reportedP!.value}',
    );
  }
  return buffer.toString().trim();
}

String _descriptiveInput(String prefix, ReportedDescriptives? values) {
  if (values == null) {
    return '';
  }
  return '$prefix.label = ${values.label}\n'
      '$prefix.n = ${values.n}\n'
      '$prefix.mean = ${values.mean}\n'
      '$prefix.sd = ${values.standardDeviation}\n';
}

String _page(List<_RenderedCase> cases) {
  final buffer = StringBuffer()
    ..write('''
<!doctype html>
<html lang="en" data-theme="dark">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Res-Quill Report Samples</title>
<style>
:root {
  color-scheme: dark;
  --bg: #0F172A;
  --surface: #1E293B;
  --surface-2: #111827;
  --text: #E5E7EB;
  --muted: #CBD5E1;
  --line: #334155;
  --title: #FFFFFF;
  --accent: #38BDF8;
  --blocked: #FCA5A5;
  --pass: #A7F3D0;
}
:root[data-theme="light"] {
  color-scheme: light;
  --bg: #F8FAFC;
  --surface: #FFFFFF;
  --surface-2: #E2E8F0;
  --text: #0F172A;
  --muted: #334155;
  --line: #CBD5E1;
  --title: #FFFFFF;
  --accent: #0369A1;
  --blocked: #991B1B;
  --pass: #047857;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font: 14px/1.5 Arial, Helvetica, sans-serif;
}
.topbar {
  position: sticky;
  top: 0;
  z-index: 2;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  padding: 16px 24px;
  background: #0F172A;
  border-bottom: 1px solid var(--line);
}
.topbar h1 {
  margin: 0;
  color: #FFFFFF;
  font-size: 18px;
  letter-spacing: 0;
}
button {
  min-width: 132px;
  border: 1px solid #94A3B8;
  background: #1E293B;
  color: #FFFFFF;
  padding: 9px 12px;
  border-radius: 6px;
  font-weight: 700;
  letter-spacing: 0;
  cursor: pointer;
}
main {
  width: min(1440px, 100%);
  margin: 0 auto;
  padding: 24px;
}
.case {
  margin: 0 0 18px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: var(--surface);
  overflow: hidden;
}
.case-title {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: flex-start;
  padding: 14px 16px;
  background: #0F172A;
}
.case-title h2 {
  margin: 0;
  color: #FFFFFF;
  font-size: 16px;
  letter-spacing: 0;
}
.verdict {
  white-space: nowrap;
  font-weight: 800;
  color: var(--pass);
}
.verdict.blocked { color: var(--blocked); }
.content {
  display: grid;
  grid-template-columns: minmax(260px, 0.9fr) minmax(320px, 1.1fr);
  gap: 18px;
  padding: 16px;
}
section {
  min-width: 0;
}
h3 {
  margin: 0 0 8px;
  font-size: 12px;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
pre, .wording, table {
  width: 100%;
  margin: 0 0 14px;
}
pre {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  padding: 12px;
  border: 1px solid var(--line);
  border-radius: 6px;
  background: var(--surface-2);
  color: var(--text);
}
.wording p {
  margin: 0 0 10px;
}
.note {
  margin: -2px 0 8px;
  color: var(--muted);
  font-size: 12px;
}
.claims {
  margin: 0 0 10px;
}
.claims strong {
  display: block;
  margin: 0 0 4px;
}
.claims ul {
  margin: 4px 0 10px 20px;
  padding: 0;
}
.claims li {
  margin: 0 0 4px;
}
.blocked-reason {
  color: var(--blocked);
  font-weight: 700;
}
table {
  border-collapse: collapse;
  table-layout: fixed;
  font-size: 13px;
}
th, td {
  border: 1px solid var(--line);
  padding: 7px 8px;
  text-align: left;
  vertical-align: top;
  overflow-wrap: anywhere;
}
th {
  color: var(--muted);
  background: var(--surface-2);
}
.source {
  color: var(--accent);
}
@media (max-width: 860px) {
  .content { grid-template-columns: 1fr; }
  main { padding: 14px; }
  .topbar { padding: 12px 14px; }
}
</style>
</head>
<body>
<div class="topbar">
  <h1>RES-QUILL REPORT SAMPLES</h1>
  <button id="themeToggle" type="button">BRIGHT VIEW</button>
</div>
<main>
''');

  for (final caseOutput in cases) {
    buffer.write(_caseHtml(caseOutput));
  }

  buffer.write('''
</main>
<script>
const root = document.documentElement;
const button = document.getElementById('themeToggle');
function setTheme(theme) {
  root.setAttribute('data-theme', theme);
  button.textContent = theme === 'dark' ? 'BRIGHT VIEW' : 'DARK VIEW';
  try { localStorage.setItem('resQuillReportTheme', theme); } catch (_) {}
}
let saved = 'dark';
try { saved = localStorage.getItem('resQuillReportTheme') || 'dark'; } catch (_) {}
setTheme(saved);
button.addEventListener('click', () => {
  setTheme(root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark');
});
</script>
</body>
</html>
''');
  return buffer.toString();
}

String _caseHtml(_RenderedCase caseOutput) {
  final report = caseOutput.report;
  final verdict = report.isBlocked ? 'BLOCKED' : _verdict(caseOutput.checks);
  final verdictClass = report.isBlocked ? 'verdict blocked' : 'verdict';
  return '''
<article class="case">
  <div class="case-title">
    <h2>${_h(caseOutput.demoCase.id)} | ${_h(caseOutput.demoCase.title)}</h2>
    <div class="$verdictClass">${_h(verdict)}</div>
  </div>
  <div class="content">
    <section>
      <h3>Inputs</h3>
      <pre>${_h(caseOutput.demoCase.inputSummary)}</pre>
      <h3>Computed Values</h3>
      <p class="note">Raw engine values are shown at full precision for verification; generated wording uses APA rounding.</p>
      ${_computedTable(caseOutput.result)}
      <h3>Validation</h3>
      ${_validationTable(caseOutput.checks)}
    </section>
    <section>
      <h3>Generated Wording</h3>
      ${_wordingHtml(report)}
      <h3>Evidence Map</h3>
      ${_evidenceTable(report.evidenceMap)}
      <h3>Source</h3>
      <pre class="source">${_h(caseOutput.demoCase.source)}</pre>
    </section>
  </div>
</article>
''';
}

String _wordingHtml(TTestReportOutput report) {
  if (report.isBlocked) {
    return '<div class="wording"><p class="blocked-reason">'
        '${_h(report.refusalReason ?? 'Wording blocked.')}</p></div>';
  }

  final cautions = report.roundingCautions.isEmpty
      ? ''
      : '<p><strong>Rounding caution:</strong> '
            '${_h(report.roundingCautions.join(' '))}</p>';
  return '''
<div class="wording">
  <p><strong>Formal plain:</strong> ${_h(report.formalResult!.plainText)}</p>
  <p><strong>Formal marked:</strong> ${_styled(report.formalResult!)}</p>
  <p><strong>Descriptives:</strong> ${_h(report.descriptivesSentence!)}</p>
  <p><strong>Plain language:</strong> ${_h(report.plainLanguageMeaning!)}</p>
  <p><strong>Effect size:</strong> ${_h(report.effectSizeSentence!)}</p>
  $cautions
  ${_claimsHtml('Supported', report.supportedClaims)}
  ${_claimsHtml('Unsupported', report.unsupportedClaims)}
</div>
''';
}

String _claimsHtml(String title, List<String> claims) {
  final items = claims.map((claim) => '<li>${_h(claim)}</li>').join();
  return '<div class="claims"><strong>${_h(title)}:</strong><ul>$items</ul></div>';
}

String _computedTable(TTestResult result) {
  final rows = {
    'meanDifference': result.meanDifference,
    'standardError': result.standardError,
    't': result.t,
    'df': result.degreesOfFreedom,
    'pTwoTailed': result.pTwoTailed,
    'pOneTailed': result.pOneTailed,
    'pLess': result.pLess,
    'pGreater': result.pGreater,
    'ciLower': result.confidenceInterval.lower,
    'ciUpper': result.confidenceInterval.upper,
    'cohensD': result.effectSize.cohensD,
    'hedgesG': result.effectSize.hedgesG,
  };
  final buffer = StringBuffer('<table><tr><th>Field</th><th>Value</th></tr>');
  rows.forEach((field, value) {
    buffer.write(
      '<tr><td>${_h(field)}</td><td>${_h(_number(value))}</td></tr>',
    );
  });
  buffer.write('</table>');
  return buffer.toString();
}

String _validationTable(List<ValidationCheck> checks) {
  final buffer = StringBuffer(
    '<table><tr><th>Check</th><th>Status</th><th>Explanation</th></tr>',
  );
  for (final check in checks) {
    buffer.write(
      '<tr><td>${_h(check.id)}</td><td>${_h(check.status.name.toUpperCase())}'
      '</td><td>${_h(check.explanation)}</td></tr>',
    );
  }
  buffer.write('</table>');
  return buffer.toString();
}

String _evidenceTable(EvidenceMap map) {
  if (map.entries.isEmpty) {
    return '<pre>Wording blocked before evidence mapping.</pre>';
  }
  final buffer = StringBuffer(
    '<table><tr><th>ID</th><th>Shown</th><th>Source Field</th>'
    '<th>Provenance</th></tr>',
  );
  for (final entry in map.entries) {
    final shown = entry.relation == '='
        ? entry.formatted
        : '${entry.relation} ${entry.formatted}';
    buffer.write(
      '<tr><td>${_h(entry.id)}</td><td>${_h(shown)}</td>'
      '<td>${_h(entry.source.field)}</td>'
      '<td>${_h(entry.source.provenance.label)}</td></tr>',
    );
  }
  buffer.write('</table>');
  return buffer.toString();
}

String _styled(ReportText text) {
  return text.runs
      .map((run) => run.italic ? '<i>${_h(run.text)}</i>' : _h(run.text))
      .join();
}

String _verdict(List<ValidationCheck> checks) {
  if (checks.any((check) => check.status == ValidationStatus.fail)) {
    return 'FAIL';
  }
  if (checks.any((check) => check.status == ValidationStatus.notApplicable)) {
    return 'PASS WITH LIMITED CHECKS';
  }
  return 'PASS';
}

String _number(double? value) {
  if (value == null) {
    return 'UNKNOWN';
  }
  if (value == 0) {
    return '0';
  }
  final absolute = value.abs();
  if (absolute >= 100000 || absolute < 0.0001) {
    return value.toStringAsExponential(8);
  }
  return value.toStringAsPrecision(10);
}

String _h(Object? value) {
  return (value ?? '').toString().replaceAllMapped(
    RegExp(
      r'[&<>"'
      ']',
    ),
    (match) => switch (match.group(0)) {
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '"' => '&quot;',
      "'" => '&#39;',
      _ => '',
    },
  );
}

class DemoCase {
  DemoCase({
    required this.id,
    required this.title,
    required this.source,
    required this.inputSummary,
    required this.compute,
    required this.validationInput,
    required this.context,
    required this.evidenceSources,
    TTestReportOptions? options,
  }) : options = options ?? TTestReportOptions();

  final String id;
  final String title;
  final String source;
  final String inputSummary;
  final TTestResult Function() compute;
  final TTestValidationInput Function(TTestResult result) validationInput;
  final TTestReportContext context;
  final TTestReportOptions options;
  final EvidenceSourceRegistry evidenceSources;
}

class _RenderedCase {
  const _RenderedCase({
    required this.demoCase,
    required this.result,
    required this.checks,
    required this.report,
  });

  final DemoCase demoCase;
  final TTestResult result;
  final List<ValidationCheck> checks;
  final TTestReportOutput report;
}
