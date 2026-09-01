import 'dart:convert';
import 'dart:io';

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
import 'package:res_quill/src/paste/paste.dart';
import 'package:res_quill/src/stats/stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKeyForT37 = 'resquill.theme';
const _seenGuideScreensPreferenceKeyForT37 = 'resquill.guide.seenScreens';
const _allSeenGuideScreensForT37 = [
  'compare',
  'input',
  'report',
  'start',
  'validation',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T38 genuine R Welch reaches the report after missing SD entry', (
    tester,
  ) async {
    final input = _fixtureInput('R_IND01_WELCH_FLOOR');
    final parsed = TTestPasteParser.parse(input);
    expect(parsed.status, PasteParseStatus.needsConfirmation);
    final candidate = parsed.candidates.single;
    expect(candidate.kind, TTestKind.independentWelch);
    expect(candidate.reportedPValueTail, ReportedPValueTail.twoTailed);
    expect(
      candidate.missingRequiredFields().map((field) => field.key).toList(),
      [
        PasteFieldKey.primaryN,
        PasteFieldKey.primaryStandardDeviation,
        PasteFieldKey.secondaryN,
        PasteFieldKey.secondaryStandardDeviation,
      ],
    );

    final validationInput = _completedWelchInput(candidate);
    final appStats = TTestValidator.resultFromInput(validationInput);
    final scipy = _scipyFrom(validationInput);
    expect(appStats.t, closeTo(scipy.t, 1e-9));
    expect(appStats.degreesOfFreedom, closeTo(scipy.df, 1e-9));
    expect(appStats.pTwoTailed, closeTo(scipy.p, 1e-12));

    await _pumpApp(tester);
    await _pasteAndReview(tester, input);
    expect(find.text('Check what was found'), findsOneWidget);
    expect(find.text('Find this value in Group Statistics.'), findsNWidgets(4));

    await _enterField(tester, 'Group 1 n', '20');
    await _enterField(tester, 'Group 1 SD', '2.03000');
    await _enterField(tester, 'Group 2 n', '20');
    await _enterField(tester, 'Group 2 SD', '4.35000');
    await tester.ensureVisible(
      find.byKey(const Key('validate-entered-values')),
    );
    await tester.tap(find.byKey(const Key('validate-entered-values')));
    await _settle(tester);
    expect(find.text('Check the numbers.'), findsOneWidget);

    final failures = TTestValidator.validate(
      validationInput,
    ).where((check) => check.status == ValidationStatus.fail).toList();
    expect(
      failures,
      isEmpty,
      reason: failures.map((check) => check.explanation).join('\n'),
    );

    await tester.ensureVisible(find.byKey(const Key('generate-report')));
    await tester.tap(find.byKey(const Key('generate-report')));
    await _settle(tester);
    expect(find.text('Copy your report.'), findsOneWidget);
    final reportText = _visibleText(tester);
    expect(reportText, contains('t(26.90) = -20.80'));
    expect(reportText, contains('p < .001'));

    final outDir = Directory('build/qa_sweep');
    outDir.createSync(recursive: true);
    File('${outDir.path}/t37_r_app.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'fixture': 'R_IND01_WELCH_FLOOR',
        'uiStop': 'report_generated',
        'format': candidate.format,
        'completedFields': [
          'primary.n',
          'primary.sd',
          'secondary.n',
          'secondary.sd',
        ],
        'app': _statsJson(appStats),
        'scipy': scipy.toJson(),
      }),
    );
  });
}

String _visibleText(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '');
  final richText = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText());
  return [...text, ...richText].join('\n');
}

String _fixtureInput(String id) {
  final file = File('test/paste/fixtures/paste_fixtures.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final fixtures = decoded['fixtures']! as List<Object?>;
  final fixture = fixtures.cast<Map<String, Object?>>().singleWhere(
    (item) => item['id'] == id,
  );
  return fixture['input']! as String;
}

_ScipyResult _scipyFrom(TTestValidationInput input) {
  final result = Process.runSync('python', [
    'tool/verify/scipy_paste_fixture_check.py',
    jsonEncode(_payload(input)),
  ]);
  if (result.exitCode != 0) {
    fail(
      'scipy fixture helper failed with exit ${result.exitCode}\n'
      'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  }
  return _ScipyResult.fromJson(
    jsonDecode(result.stdout as String) as Map<String, Object?>,
  );
}

Map<String, Object?> _payload(TTestValidationInput input) {
  return {
    'kind': input.kind.name,
    'tail': input.reportedPValueTail.name,
    'confidenceLevel': input.confidenceLevel,
    if (input.first != null) 'first': _descriptives(input.first!),
    if (input.second != null) 'second': _descriptives(input.second!),
    if (input.referenceMean != null) 'referenceMean': input.referenceMean,
    if (input.paired != null) 'paired': _paired(input.paired!),
  };
}

Map<String, Object?> _descriptives(ReportedDescriptives item) {
  return {
    'n': item.n,
    'mean': item.mean,
    'standardDeviation': item.standardDeviation,
  };
}

Map<String, Object?> _paired(ReportedPairedDescriptives item) {
  return {
    'first': _descriptives(item.first),
    'second': _descriptives(item.second),
    if (item.meanDifference != null) 'meanDifference': item.meanDifference,
    if (item.differenceStandardDeviation != null)
      'differenceStandardDeviation': item.differenceStandardDeviation,
    if (item.correlation != null) 'correlation': item.correlation,
  };
}

Map<String, Object?> _statsJson(TTestResult result) {
  return {
    't': result.t,
    'df': result.degreesOfFreedom,
    'p': result.pTwoTailed,
    'ciLower': result.confidenceInterval.lower,
    'ciUpper': result.confidenceInterval.upper,
  };
}

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    _themePreferenceKeyForT37: 'dark',
    _seenGuideScreensPreferenceKeyForT37: _allSeenGuideScreensForT37,
  });
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MainApp());
  await _settle(tester);
}

Future<void> _pasteAndReview(WidgetTester tester, String paste) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
  await _settle(tester);
  await tester.enterText(find.byKey(const Key('paste-output-box')), paste);
  await tester.ensureVisible(find.byKey(const Key('review-detected-fields')));
  await tester.tap(find.byKey(const Key('review-detected-fields')));
  await _settle(tester);
}

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final finder = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

TTestValidationInput _completedWelchInput(PasteTTestCandidate candidate) {
  ReportedValue? reported(PasteFieldKey key) =>
      candidate.number(key)?.toReportedValue();
  return TTestValidationInput(
    kind: TTestKind.independentWelch,
    first: ReportedDescriptives(
      label: candidate.text(PasteFieldKey.primaryLabel),
      n: 20,
      mean: candidate.number(PasteFieldKey.primaryMean)!.value,
      standardDeviation: 2.03000,
    ),
    second: ReportedDescriptives(
      label: candidate.text(PasteFieldKey.secondaryLabel),
      n: 20,
      mean: candidate.number(PasteFieldKey.secondaryMean)!.value,
      standardDeviation: 4.35000,
    ),
    reportedT: reported(PasteFieldKey.reportedT),
    reportedDegreesOfFreedom: reported(PasteFieldKey.reportedDegreesOfFreedom),
    reportedP: reported(PasteFieldKey.reportedP),
    reportedPValueTail: candidate.reportedPValueTail!,
    reportedMeanDifference: reported(PasteFieldKey.reportedMeanDifference),
    reportedStandardError: reported(PasteFieldKey.reportedStandardError),
    reportedCiLower: reported(PasteFieldKey.ciLower),
    reportedCiUpper: reported(PasteFieldKey.ciUpper),
    confidenceLevel: candidate.number(PasteFieldKey.confidenceLevel)!.value,
  );
}

class _ScipyResult {
  const _ScipyResult({required this.t, required this.df, required this.p});

  factory _ScipyResult.fromJson(Map<String, Object?> json) {
    return _ScipyResult(
      t: (json['t']! as num).toDouble(),
      df: (json['df']! as num).toDouble(),
      p: (json['p']! as num).toDouble(),
    );
  }

  final double t;
  final double df;
  final double p;

  Map<String, Object?> toJson() {
    return {'t': t, 'df': df, 'p': p};
  }
}
