import 'dart:convert';
import 'dart:io';

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
import 'package:res_quill/src/paste/paste.dart';
import 'package:res_quill/src/stats/stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKeyForT39 = 'resquill.theme';
const _seenGuideScreensPreferenceKeyForT39 = 'resquill.guide.seenScreens';
const _allSeenGuideScreensForT39 = [
  'compare',
  'input',
  'report',
  'start',
  'validation',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T39 bundled R Welch reaches report after N and SD entry', (
    tester,
  ) async {
    final sample = await rootBundle.loadString(
      'assets/examples/paste_text/r_welch.txt',
    );
    final parsed = TTestPasteParser.parse(sample);
    expect(parsed.status, PasteParseStatus.needsConfirmation);
    final candidate = parsed.candidates.single;
    expect(candidate.kind, TTestKind.independentWelch);
    expect(candidate.missingRequiredFields().map((missing) => missing.key), [
      PasteFieldKey.primaryN,
      PasteFieldKey.primaryStandardDeviation,
      PasteFieldKey.secondaryN,
      PasteFieldKey.secondaryStandardDeviation,
    ]);

    final validationInput = _completedBundledRWelchInput(candidate);
    final appStats = TTestValidator.resultFromInput(validationInput);
    final scipy = _scipyFrom(validationInput);
    expect(appStats.t, closeTo(scipy.t, 1e-9));
    expect(appStats.degreesOfFreedom, closeTo(scipy.df, 1e-9));
    expect(appStats.pTwoTailed, closeTo(scipy.p, 1e-12));

    await _pumpApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
    await _settle(tester);
    final loadButton = find.descendant(
      of: find.byKey(const Key('paste-example-r-welch')),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(loadButton);
    final button = tester.widget<FilledButton>(loadButton);
    expect(button.onPressed, isNotNull);
    await tester.runAsync(() async {
      button.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await _settle(tester);

    expect(
      find.text('R prints means only; fill highlighted N and SD.'),
      findsOneWidget,
    );
    await _enterField(tester, 'Group 1 n', '24');
    await _enterField(tester, 'Group 1 SD', '10.361928');
    await _enterField(tester, 'Group 2 n', '27');
    await _enterField(tester, 'Group 2 SD', '14.005195');
    await tester.ensureVisible(
      find.byKey(const Key('validate-entered-values')),
    );
    await tester.tap(find.byKey(const Key('validate-entered-values')));
    await _settle(tester);

    expect(find.text('Check the numbers.'), findsOneWidget);
    expect(find.text('Fail'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('generate-report')));
    await tester.tap(find.byKey(const Key('generate-report')));
    await _settle(tester);

    expect(find.text('Copy your report.'), findsOneWidget);
    final reportText = _visibleText(tester);
    expect(reportText, contains('t(47.51) = 3.29'));
    expect(reportText, contains('p = .002'));

    final outDir = Directory('build/qa_sweep');
    outDir.createSync(recursive: true);
    File('${outDir.path}/t39_r_asset_app.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'asset': 'assets/examples/paste_text/r_welch.txt',
        'uiStop': 'report_generated',
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

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    _themePreferenceKeyForT39: 'dark',
    _seenGuideScreensPreferenceKeyForT39: _allSeenGuideScreensForT39,
  });
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MainApp());
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

String _visibleText(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '');
  final richText = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText());
  return [...text, ...richText].join('\n');
}

TTestValidationInput _completedBundledRWelchInput(
  PasteTTestCandidate candidate,
) {
  ReportedValue? reported(PasteFieldKey key) {
    return candidate.number(key)?.toReportedValue();
  }

  return TTestValidationInput(
    kind: TTestKind.independentWelch,
    first: ReportedDescriptives(
      label: candidate.text(PasteFieldKey.primaryLabel),
      n: 24,
      mean: candidate.number(PasteFieldKey.primaryMean)!.value,
      standardDeviation: 10.361928,
    ),
    second: ReportedDescriptives(
      label: candidate.text(PasteFieldKey.secondaryLabel),
      n: 27,
      mean: candidate.number(PasteFieldKey.secondaryMean)!.value,
      standardDeviation: 14.005195,
    ),
    reportedT: reported(PasteFieldKey.reportedT),
    reportedDegreesOfFreedom: reported(PasteFieldKey.reportedDegreesOfFreedom),
    reportedP: reported(PasteFieldKey.reportedP),
    reportedPValueTail: ReportedPValueTail.twoTailed,
    reportedMeanDifference: reported(PasteFieldKey.reportedMeanDifference),
    reportedStandardError: reported(PasteFieldKey.reportedStandardError),
    reportedCiLower: reported(PasteFieldKey.ciLower),
    reportedCiUpper: reported(PasteFieldKey.ciUpper),
    confidenceLevel: candidate.number(PasteFieldKey.confidenceLevel)!.value,
  );
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
