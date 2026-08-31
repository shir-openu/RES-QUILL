import 'dart:convert';
import 'dart:io';

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
import 'package:res_quill/src/paste/paste.dart';
import 'package:res_quill/src/report/report.dart';
import 'package:res_quill/src/stats/stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sampleDir =
    r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\PASTE_TEXT';
const _themePreferenceKeyForQa = 'resquill.theme';
const _seenGuideScreensPreferenceKeyForQa = 'resquill.guide.seenScreens';
const _allSeenGuideScreensForQa = [
  'compare',
  'input',
  'report',
  'start',
  'validation',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA sweep drives every paste sample through the real app', (
    tester,
  ) async {
    final files = Directory(_sampleDir).listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final results = <Map<String, Object?>>[];

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      // Printed intentionally so a failed QA run identifies the current sample.
      // ignore: avoid_print
      print('QA_SWEEP_SAMPLE $name');
      final text = file.readAsStringSync();
      final parsed = TTestPasteParser.parse(text);
      await _pumpApp(tester);
      // ignore: avoid_print
      print('QA_SWEEP_PUMPED $name');
      await _pasteAndReview(tester, text);
      // ignore: avoid_print
      print('QA_SWEEP_REVIEWED $name');

      final sample = <String, Object?>{
        'file': name,
        'detectedStatus': parsed.status.name,
        'detectedKind': _kindName(parsed.detectedTestKind),
        'detectedFields': [
          for (final field in parsed.fields)
            {
              'key': field.key.path,
              'value': field.describeValue(),
              'source': field.sourceText.trim(),
            },
        ],
        'confirmationsShown': [
          for (final ambiguity in parsed.ambiguities) ambiguity.message,
          for (final missing in parsed.missingRequiredFields)
            '${missing.label}: ${missing.reason}',
        ],
        'refusalTextShown': <String>[],
        'uiStop': null,
        'final': null,
        'validationFailures': <String>[],
      };

      if (parsed.status == PasteParseStatus.cannotParse) {
        expect(find.text('Cannot use this paste'), findsOneWidget);
        for (final reason in parsed.refusalReasons) {
          expect(find.text(reason), findsOneWidget);
        }
        sample['refusalTextShown'] = parsed.refusalReasons;
        sample['uiStop'] = 'parse_refusal';
        results.add(sample);
        _checkNoFlutterException(tester, name);
        continue;
      }

      expect(find.text('Check what was found'), findsOneWidget);
      for (final ambiguity in parsed.ambiguities) {
        expect(find.text(ambiguity.message), findsOneWidget);
      }

      final resolution = _resolutionFor(name, parsed);
      if (resolution == null) {
        sample['uiStop'] = 'blocked_missing_required_fields';
        if (parsed.fields.any(
          (field) =>
              field.key == PasteFieldKey.reportedP &&
              field.describeValue() == '< 0.001',
        )) {
          final details = find.widgetWithText(
            FilledButton,
            'Show all found values',
          );
          await tester.ensureVisible(details);
          await tester.tap(details);
          await _settle(tester);
          expect(find.textContaining('reported.p = < 0.001'), findsOneWidget);
        }
        results.add(sample);
        _checkNoFlutterException(tester, name);
        continue;
      }

      if (parsed.candidates.length > 1) {
        final row = find.widgetWithText(
          RadioListTile<PasteTTestCandidate>,
          resolution.candidate.label,
        );
        await tester.ensureVisible(row);
        await tester.tap(row);
        await _settle(tester);
      }
      if (resolution.tailWasUserConfirmed) {
        await tester.ensureVisible(
          find.byKey(const Key('paste-tail-two-tailed')),
        );
        await tester.tap(find.byKey(const Key('paste-tail-two-tailed')));
        await _settle(tester);
      }

      if (resolution.usePasteConfirm) {
        await tester.ensureVisible(
          find.byKey(const Key('confirm-detected-values')),
        );
        await tester.tap(find.byKey(const Key('confirm-detected-values')));
      } else {
        await tester.ensureVisible(
          find.byKey(const Key('validate-entered-values')),
        );
        await tester.tap(find.byKey(const Key('validate-entered-values')));
      }
      await _settle(tester);
      expect(find.text('Check the numbers.'), findsOneWidget);

      final checks = [
        ...TTestValidator.validate(resolution.validationInput),
        ValidationCheck(
          id: 'alpha.domain',
          title: 'Alpha is between 0 and 1',
          status: ValidationStatus.pass,
          explanation: 'Alpha is a usable decision threshold.',
          reported: 0.05,
          tolerance: '(0, 1)',
        ),
      ];
      final failures = checks
          .where((check) => check.status == ValidationStatus.fail)
          .toList();
      sample['validationFailures'] = [
        for (final check in failures) '${check.title}: ${check.explanation}',
      ];
      final result = TTestValidator.resultFromInput(resolution.validationInput);
      sample['final'] = _finalStats(result, resolution.reportTail);

      if (failures.isEmpty) {
        await tester.ensureVisible(find.byKey(const Key('generate-report')));
        await tester.tap(find.byKey(const Key('generate-report')));
        await _settle(tester);
        expect(find.text('Copy your report.'), findsOneWidget);
        sample['uiStop'] = 'report_generated';
      } else {
        expect(
          find.text('Fix failed rows before generating a report.'),
          findsOneWidget,
        );
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Generate report'),
        );
        expect(button.onPressed, isNull);
        sample['uiStop'] = 'validation_blocked_report';
      }

      results.add(sample);
      _checkNoFlutterException(tester, name);
    }

    final outDir = Directory('build/qa_sweep');
    outDir.createSync(recursive: true);
    File(
      '${outDir.path}/app_samples.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    _themePreferenceKeyForQa: 'dark',
    _seenGuideScreensPreferenceKeyForQa: _allSeenGuideScreensForQa,
  });
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester);
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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

_QaResolution? _resolutionFor(String fileName, TTestPasteParseResult parsed) {
  if (parsed.candidates.isEmpty) {
    return null;
  }

  final candidate = switch (fileName) {
    'spss_independent_samples.txt' => parsed.candidates.singleWhere(
      (item) => item.kind == TTestKind.independentStudent,
    ),
    _ => parsed.candidates.length == 1 ? parsed.candidates.single : null,
  };
  if (candidate == null) {
    return null;
  }

  final tail = candidate.reportedPValueTail ?? ReportedPValueTail.twoTailed;
  if (!candidate.canBuildValidationInput(confirmedPValueTail: tail) &&
      fileName != 'spss_independent_samples.txt') {
    return null;
  }

  final input = fileName == 'spss_independent_samples.txt'
      ? _independentInputWithDefaultConfidence(candidate, tail)
      : candidate.toValidationInput(confirmedPValueTail: tail);
  return _QaResolution(
    candidate: candidate,
    tail: tail,
    validationInput: input,
    usePasteConfirm: fileName != 'spss_independent_samples.txt',
    tailWasUserConfirmed:
        candidate.reportedPValueTail == null &&
        parsed.ambiguities.any((item) => item.id.startsWith('p.tail')),
  );
}

TTestValidationInput _independentInputWithDefaultConfidence(
  PasteTTestCandidate candidate,
  ReportedPValueTail tail,
) {
  ReportedValue? reported(PasteFieldKey key) =>
      candidate.number(key)?.toReportedValue();
  ReportedDescriptives group({
    required PasteFieldKey label,
    required PasteFieldKey n,
    required PasteFieldKey mean,
    required PasteFieldKey sd,
    required String fallback,
  }) {
    return ReportedDescriptives(
      label: candidate.text(label) ?? fallback,
      n: candidate.number(n)!.value.round(),
      mean: candidate.number(mean)!.value,
      standardDeviation: candidate.number(sd)!.value,
    );
  }

  return TTestValidationInput(
    kind: candidate.kind,
    first: group(
      label: PasteFieldKey.primaryLabel,
      n: PasteFieldKey.primaryN,
      mean: PasteFieldKey.primaryMean,
      sd: PasteFieldKey.primaryStandardDeviation,
      fallback: 'Group 1',
    ),
    second: group(
      label: PasteFieldKey.secondaryLabel,
      n: PasteFieldKey.secondaryN,
      mean: PasteFieldKey.secondaryMean,
      sd: PasteFieldKey.secondaryStandardDeviation,
      fallback: 'Group 2',
    ),
    reportedT: reported(PasteFieldKey.reportedT),
    reportedDegreesOfFreedom: reported(PasteFieldKey.reportedDegreesOfFreedom),
    reportedP: reported(PasteFieldKey.reportedP),
    reportedPValueTail: tail,
    reportedMeanDifference: reported(PasteFieldKey.reportedMeanDifference),
    reportedStandardError: reported(PasteFieldKey.reportedStandardError),
    reportedCiLower: reported(PasteFieldKey.ciLower),
    reportedCiUpper: reported(PasteFieldKey.ciUpper),
    confidenceLevel: 0.95,
  );
}

Map<String, Object?> _finalStats(TTestResult result, ReportTail tail) {
  final p = switch (tail) {
    ReportTail.twoTailed => result.pTwoTailed,
    ReportTail.less => result.pLess,
    ReportTail.greater => result.pGreater,
  };
  return {
    't': result.t,
    'df': result.degreesOfFreedom,
    'p': p,
    'ciLower': result.confidenceInterval.lower,
    'ciUpper': result.confidenceInterval.upper,
    'cohensD': result.effectSize.cohensD,
    'hedgesG': result.effectSize.hedgesG,
  };
}

void _checkNoFlutterException(WidgetTester tester, String name) {
  final exception = tester.takeException();
  if (exception != null) {
    fail('Flutter exception while driving $name: $exception');
  }
}

String _kindName(TTestKind? kind) {
  return switch (kind) {
    TTestKind.independentStudent => 'independentStudent',
    TTestKind.independentWelch => 'independentWelch',
    TTestKind.pairedSamples => 'pairedSamples',
    TTestKind.oneSample => 'oneSample',
    null => 'null',
  };
}

class _QaResolution {
  const _QaResolution({
    required this.candidate,
    required this.tail,
    required this.validationInput,
    required this.usePasteConfirm,
    required this.tailWasUserConfirmed,
  });

  final PasteTTestCandidate candidate;
  final ReportedPValueTail tail;
  final TTestValidationInput validationInput;
  final bool usePasteConfirm;
  final bool tailWasUserConfirmed;

  ReportTail get reportTail {
    return switch (tail) {
      ReportedPValueTail.twoTailed => ReportTail.twoTailed,
      ReportedPValueTail.less => ReportTail.less,
      ReportedPValueTail.greater => ReportTail.greater,
      ReportedPValueTail.oneTailedObservedDirection => ReportTail.twoTailed,
    };
  }
}
