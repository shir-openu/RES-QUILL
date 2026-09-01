import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
import 'package:res_quill/src/app/sample_folder_opener.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKeyForTest = 'resquill.theme';
const _seenGuideScreensPreferenceKeyForTest = 'resquill.guide.seenScreens';
const _allSeenGuideScreensForTest = [
  'compare',
  'input',
  'report',
  'start',
  'validation',
];

const _newFormatSourceAssets = [
  (
    sourcePath:
        r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\CLAUDE_NEW_FORMATS\claude_r_welch.txt',
    assetPath: 'assets/examples/paste_text/r_welch.txt',
  ),
  (
    sourcePath:
        r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\CLAUDE_NEW_FORMATS\claude_r_one_sample.txt',
    assetPath: 'assets/examples/paste_text/r_one_sample.txt',
  ),
  (
    sourcePath:
        r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\CLAUDE_NEW_FORMATS\claude_jamovi_welch.txt',
    assetPath: 'assets/examples/paste_text/jamovi_welch.txt',
  ),
  (
    sourcePath:
        r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\CLAUDE_NEW_FORMATS\claude_excel_toolpak_student.txt',
    assetPath: 'assets/examples/paste_text/excel_toolpak_student.txt',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ambiguousApaPaste =
      'Retrieval practice (n = 20, M = 81.40, SD = 5.5378) and '
      'Restudy (n = 31, M = 72.40, SD = 9.2616) were compared using a '
      'Welch independent-samples t test, t(48.80) = 4.34, p < .001, '
      'mean difference = 9.00, SE = 2.0737, 95% CI [4.83, 13.17].';

  const failingApaPaste =
      'Retrieval practice (n = 20, M = 81.40, SD = 5.5378) and '
      'Restudy (n = 31, M = 72.40, SD = 9.2616) were compared using a '
      'two-tailed Welch independent-samples t test, t(48.80) = 1.00, '
      'p = .999, mean difference = 9.00, SE = 2.0737, '
      '95% CI [4.83, 13.17].';

  const reportApaPaste =
      'Retrieval practice (n = 20, M = 81.40, SD = 5.5378) and '
      'Restudy (n = 31, M = 72.40, SD = 9.2616) were compared using a '
      'two-tailed Welch independent-samples t test, t(48.80) = 4.34, '
      'p < .001, mean difference = 9.00, SE = 2.0737, '
      '95% CI [4.83, 13.17].';

  const invalidPApaPaste =
      'Retrieval practice (n = 20, M = 81.40, SD = 5.5378) and '
      'Restudy (n = 31, M = 72.40, SD = 9.2616) were compared using a '
      'two-tailed Welch independent-samples t test, t(48.80) = 4.34, '
      'p = 1.20, mean difference = 9.00, SE = 2.0737, '
      '95% CI [4.83, 13.17].';

  const badDfApaPaste =
      'Retrieval practice (n = 20, M = 81.40, SD = 5.5378) and '
      'Restudy (n = 31, M = 72.40, SD = 9.2616) were compared using a '
      'two-tailed Welch independent-samples t test, t(40) = 4.34, '
      'p < .001, mean difference = 9.00, SE = 2.0737, '
      '95% CI [4.83, 13.17].';

  const badCiApaPaste =
      'Retrieval practice (n = 20, M = 81.40, SD = 5.5378) and '
      'Restudy (n = 31, M = 72.40, SD = 9.2616) were compared using a '
      'two-tailed Welch independent-samples t test, t(48.80) = 4.34, '
      'p < .001, mean difference = 9.00, SE = 2.0737, '
      '95% CI [1.00, 2.00].';

  setUp(_mockAllGuideScreensSeen);

  testWidgets('new bundled example assets match source bytes', (tester) async {
    for (final pair in _newFormatSourceAssets) {
      final source = File(pair.sourcePath);
      expect(
        source.existsSync(),
        isTrue,
        reason: 'Missing source file ${pair.sourcePath}',
      );
      final asset = await rootBundle.load(pair.assetPath);
      final assetBytes = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      expect(
        assetBytes,
        orderedEquals(source.readAsBytesSync()),
        reason: '${pair.assetPath} differs from ${pair.sourcePath}',
      );
    }
  });

  testWidgets('sample text folder export writes bundled files', (tester) async {
    final temp = Directory.systemTemp.createTempSync('resquill-samples-');
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });
    final directoryPath = await tester.runAsync(
      () => writeSamplePasteFiles(
        bundle: rootBundle,
        assetPaths: _newFormatSourceAssets.map((pair) => pair.assetPath),
        appDataPath: temp.path,
      ),
    );

    for (final pair in _newFormatSourceAssets) {
      final fileName = Uri.parse(pair.assetPath).pathSegments.last;
      final exported = File('$directoryPath${Platform.pathSeparator}$fileName');
      expect(exported.existsSync(), isTrue);
      expect(
        exported.readAsBytesSync(),
        orderedEquals(File(pair.assetPath).readAsBytesSync()),
      );
    }
  });

  testWidgets('disabled analysis cards are not tappable', (tester) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({
      _themePreferenceKeyForTest: 'light',
      _seenGuideScreensPreferenceKeyForTest: _allSeenGuideScreensForTest,
    });
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());

    expect(
      tester.getSemantics(find.byKey(const Key('area-relationships'))),
      matchesSemantics(
        label:
            'Relationships & prediction. Correlations and regression. Later.',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );

    await tester.tap(find.byKey(const Key('area-relationships')));
    await tester.pumpAndSettle();

    expect(
      find.text('Turn statistical output into a clear, report-ready result.'),
      findsOneWidget,
    );
    expect(
      find.text('Use this only when typing values by hand.'),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('start screen states current product limits', (tester) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());

    expect(
      find.text(
        'Today: Student, Welch, paired, and one-sample t-tests only. Paste SPSS, R, JASP, jamovi, Excel ToolPak, or APA output. No raw CSV/Excel data computation. No cloud. No accounts.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a validation fail blocks the report screen', (tester) async {
    final semantics = tester.ensureSemantics();
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await _pasteAndReview(tester, failingApaPaste);

    await tester.ensureVisible(
      find.byKey(const Key('confirm-detected-values')),
    );
    await tester.tap(find.byKey(const Key('confirm-detected-values')));
    await tester.pumpAndSettle();

    expect(find.text('Check the numbers.'), findsOneWidget);
    expect(
      find.text('Fix failed rows before generating the report.'),
      findsOneWidget,
    );
    expect(find.text('Fail'), findsWidgets);
    final generateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate report'),
    );
    expect(generateButton.onPressed, isNull);
    expect(
      tester.getSemantics(find.widgetWithText(FilledButton, 'Generate report')),
      matchesSemantics(
        label: 'Generate report',
        hint:
            'Disabled because validation failed: Reported t matches the descriptive statistics. Fix failed rows before generating a report.',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );

    expect(find.text('Copy your report.'), findsNothing);
    semantics.dispose();
  });

  testWidgets('validation rows do not expose raw check ids', (tester) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await _pasteAndReview(tester, failingApaPaste);

    await tester.ensureVisible(
      find.byKey(const Key('confirm-detected-values')),
    );
    await tester.tap(find.byKey(const Key('confirm-detected-values')));
    await tester.pumpAndSettle();
    final allChecksButton = find.widgetWithText(
      FilledButton,
      'Show all checks',
    );
    await tester.ensureVisible(allChecksButton);
    await tester.tap(allChecksButton);
    await tester.pumpAndSettle();

    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join('\n');
    final rawCheckId = RegExp(
      r'\b(?:alpha\.domain|calculation\.input|ci\.(?:diff_se|lower|upper)|'
      r'df\.plausibility|domain\.[a-z0-9_]+|grim\.[a-z0-9_]+|'
      r'p\.t_df|t\.descriptives)\b',
    );
    expect(rawCheckId.hasMatch(visibleText), isFalse, reason: visibleText);
    expect(
      find.text('Reported t matches the descriptive statistics'),
      findsWidgets,
    );
    expect(find.text('Reported p matches t and df'), findsWidgets);
  });

  testWidgets('value cards distinguish failed and related checks', (
    tester,
  ) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await _pasteAndReview(tester, failingApaPaste);

    await tester.ensureVisible(
      find.byKey(const Key('confirm-detected-values')),
    );
    await tester.tap(find.byKey(const Key('confirm-detected-values')));
    await tester.pumpAndSettle();

    final pTile = find.byKey(const Key('validation-summary-p'));
    expect(
      find.descendant(of: pTile, matching: find.text('Error')),
      findsOneWidget,
    );
    expect(find.descendant(of: pTile, matching: find.text('OK')), findsNothing);
    expect(
      find.descendant(
        of: pTile,
        matching: find.text('Does not fit t and df. Calculated: 0.322.'),
      ),
      findsOneWidget,
    );

    final dfTile = find.byKey(const Key('validation-summary-df'));
    expect(
      find.descendant(of: dfTile, matching: find.text('Warning')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dfTile, matching: find.text('Error')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: dfTile,
        matching: find.text('Used in failed check: p against t and df.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('validation value cards are compact and equal height', (
    tester,
  ) async {
    const surfaceSizes = [Size(1440, 1000), Size(390, 900)];

    for (final surfaceSize in surfaceSizes) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _setSurface(tester, surfaceSize);
      await tester.pumpWidget(const MainApp());
      await _pasteAndReview(tester, failingApaPaste);

      await tester.ensureVisible(
        find.byKey(const Key('confirm-detected-values')),
      );
      await tester.tap(find.byKey(const Key('confirm-detected-values')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('validation-summary-t')));
      await tester.pumpAndSettle();

      final heights = [
        for (final key in _validationSummaryCardKeys)
          tester.getSize(find.byKey(key)).height,
      ];
      for (final height in heights) {
        expect(height, lessThan(220));
      }
    }
  });

  testWidgets(
    'warning and error value cards do not use affirmative matches copy',
    (tester) async {
      final cases = [
        failingApaPaste,
        invalidPApaPaste,
        badDfApaPaste,
        badCiApaPaste,
      ];

      for (final paste in cases) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await _setDesktop(tester);
        await tester.pumpWidget(const MainApp());
        await _pasteAndReview(tester, paste);

        await tester.ensureVisible(
          find.byKey(const Key('confirm-detected-values')),
        );
        await tester.tap(find.byKey(const Key('confirm-detected-values')));
        await tester.pumpAndSettle();

        for (final key in _validationSummaryCardKeys) {
          _expectNoAffirmativeMatchesUnderWarningOrError(tester, key);
        }
      }
    },
  );

  testWidgets('paste ambiguity cannot proceed until resolved', (tester) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await _pasteAndReview(tester, ambiguousApaPaste);

    expect(find.text('Choose p-value direction'), findsOneWidget);
    expect(find.text('Use SPSS Sig. (2-tailed).'), findsOneWidget);
    expect(
      find.text('Use only if the assignment predicts lower values.'),
      findsOneWidget,
    );
    expect(
      find.text('Use only if the assignment predicts higher values.'),
      findsOneWidget,
    );
    var confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Use these values'),
    );
    expect(confirmButton.onPressed, isNull);

    expect(find.text('Check the numbers.'), findsNothing);

    await tester.tap(find.byKey(const Key('paste-tail-two-tailed')));
    await tester.pumpAndSettle();
    confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Use these values'),
    );
    expect(confirmButton.onPressed, isNotNull);

    await tester.ensureVisible(
      find.byKey(const Key('confirm-detected-values')),
    );
    await tester.tap(find.byKey(const Key('confirm-detected-values')));
    await tester.pumpAndSettle();
    expect(find.text('Check the numbers.'), findsOneWidget);
  });

  testWidgets('real sample paste displays harness-matching detected values', (
    tester,
  ) async {
    final sample = await tester.runAsync(
      () => rootBundle.loadString(
        'assets/examples/paste_text/spss_independent_samples.txt',
      ),
    );
    expect(sample, isNotNull);

    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await _pasteAndReview(tester, sample!);

    expect(
      find.text('SPSS has both rows. Choose the row your assignment uses.'),
      findsOneWidget,
    );
    expect(find.text('SPSS row: Equal variances assumed'), findsOneWidget);
    expect(find.text('SPSS row: Equal variances not assumed'), findsWidgets);
    expect(
      find.text(
        "Student row. Levene's Sig. = 0.675; with .05 rule, SPSS points to this row.",
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        "Welch row. Levene's Sig. = 0.675; with .05 rule, use this only if assigned.",
      ),
      findsOneWidget,
    );
    expect(find.text('CI confidence level'), findsOneWidget);
    expect(find.text('Enter the CI level, usually .95.'), findsOneWidget);
    expect(
      find.text('Look for 95% before Confidence Interval; type .95.'),
      findsOneWidget,
    );
    final details = find.widgetWithText(FilledButton, 'Show all found values');
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.textContaining('primary.mean = 82.7975'), findsOneWidget);
    expect(find.textContaining('secondary.mean = 72.026'), findsOneWidget);
    expect(find.textContaining('levene.p = 0.675'), findsOneWidget);
    expect(find.textContaining('reported.df = 38'), findsOneWidget);
    expect(find.textContaining('reported.df = 37.543'), findsOneWidget);
    expect(find.textContaining('reported.p = 0.021'), findsWidgets);
  });

  testWidgets('bundled examples load through the real input controls', (
    tester,
  ) async {
    const examples = [
      (
        'spss-independent',
        'SPSS has both rows. Choose the row your assignment uses.',
        'reported.df = 38',
      ),
      ('spss-one-sample', 'Check what was found', 'reported.df = 30'),
      ('spss-p-rounded-zero', 'Check what was found', 'reported.p = < 0.001'),
      (
        'apa-sentence-ci',
        'Choose whether the p-value is one-tailed or two-tailed.',
        'reported.df = 47.57',
      ),
      (
        'r-welch',
        'R prints means only; fill highlighted N and SD.',
        'reported.df = 47.514',
      ),
      (
        'r-one-sample',
        'R prints means only; fill highlighted N and SD.',
        'referenceMean = 100',
      ),
      ('jamovi-welch', 'Check what was found', 'reported.df = 47.514'),
      (
        'excel-toolpak-student',
        'Enter the CI level, usually .95.',
        'primary.standardDeviation = 10.361928',
      ),
      (
        'intentional-mistake',
        'Choose whether the p-value is one-tailed or two-tailed.',
        'reported.t = 4.34',
      ),
    ];

    for (final example in examples) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _setDesktop(tester);
      await tester.pumpWidget(const MainApp());
      await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
      await tester.pumpAndSettle();
      final loadButton = find.descendant(
        of: find.byKey(Key('paste-example-${example.$1}')),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(loadButton);
      final button = tester.widget<FilledButton>(loadButton);
      expect(button.onPressed, isNotNull);
      await tester.runAsync(() async {
        button.onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('paste-output-box')))
            .controller!
            .text,
        isNotEmpty,
      );
      expect(find.text(example.$2), findsOneWidget);
      final details = find.widgetWithText(
        FilledButton,
        'Show all found values',
      );
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.textContaining(example.$3), findsWidgets);
    }
  });

  testWidgets('intentional bundled mistake blocks report generation', (
    tester,
  ) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
    await tester.pumpAndSettle();
    final loadButton = find.descendant(
      of: find.byKey(const Key('paste-example-intentional-mistake')),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(loadButton);
    final button = tester.widget<FilledButton>(loadButton);
    expect(button.onPressed, isNotNull);
    await tester.runAsync(() async {
      button.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(
      find.text('Choose whether the p-value is one-tailed or two-tailed.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('paste-tail-two-tailed')));
    await tester.tap(find.byKey(const Key('paste-tail-two-tailed')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('confirm-detected-values')),
    );
    await tester.tap(find.byKey(const Key('confirm-detected-values')));
    await tester.pumpAndSettle();

    expect(find.text('Check the numbers.'), findsOneWidget);
    expect(
      find.text('Fix failed rows before generating the report.'),
      findsOneWidget,
    );
    expect(find.text('Fail'), findsWidgets);
    final generateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate report'),
    );
    expect(generateButton.onPressed, isNull);
  });

  testWidgets('spreadsheet help states the raw-data boundary', (tester) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paste-spreadsheet-help')));
    await tester.pumpAndSettle();

    expect(find.text('CSV and Excel files'), findsOneWidget);
    expect(
      find.text(
        'CSV files and raw Excel sheets contain raw rows. Res-Quill checks t-test output from SPSS, R, JASP, jamovi, Excel ToolPak, or APA-style reports. Paste that output instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('desktop paste input exposes sample text folder control', (
    tester,
  ) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paste-open-sample-folder')), findsOneWidget);
    expect(find.text('Open sample text folder'), findsWidgets);
  });

  testWidgets('pasted raw spreadsheet rows are refused clearly', (
    tester,
  ) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await _pasteAndReview(tester, 'Before\tAfter\n63\t69\n65\t65\n56\t62\n');

    expect(find.text('Cannot use this paste'), findsOneWidget);
    expect(
      find.text(
        'This looks like raw spreadsheet rows. Paste t-test output instead.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'CSV files and raw Excel sheets contain raw rows. Res-Quill checks t-test output from SPSS, R, JASP, jamovi, Excel ToolPak, or APA-style reports. Paste that output instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('input labels tell students what to paste and type', (
    tester,
  ) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
    await tester.pumpAndSettle();
    expect(
      find.text('Paste SPSS, R, JASP, jamovi, Excel ToolPak, or APA output.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Back to start'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Type values'));
    await tester.pumpAndSettle();
    expect(find.text('SPSS row: Equal variances assumed'), findsOneWidget);
    expect(find.text('SPSS row: Equal variances not assumed'), findsOneWidget);
    expect(find.text('Student t-test'), findsOneWidget);
    expect(find.text('Welch t-test'), findsOneWidget);

    await tester.tap(find.text('Student t-test').first);
    await tester.pumpAndSettle();

    expect(find.text('Type values from one output row.'), findsOneWidget);
    expect(find.text('SPSS row: Equal variances assumed'), findsOneWidget);
    expect(find.text('Student t-test'), findsOneWidget);
    expect(find.text('Alpha (course, usually .05)'), findsOneWidget);
    expect(find.text('p direction'), findsOneWidget);
    expect(find.text('CI level (usually .95)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manual-kind-field')));
    await tester.pumpAndSettle();
    expect(find.text('Student t-test'), findsWidgets);
    expect(find.text('Welch t-test'), findsWidgets);
    expect(find.text('SPSS row: Equal variances assumed'), findsWidgets);
    expect(find.text('SPSS row: Equal variances not assumed'), findsOneWidget);
  });

  testWidgets('the start guide does not auto-advance', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('guide-bubble')), findsOneWidget);
    expect(find.text('1 of 8'), findsOneWidget);
    expect(find.text('Paste copied output'), findsOneWidget);
    expect(
      find.text(
        'Paste supported t-test output when copied. Then confirm detected values.',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('1 of 8'), findsOneWidget);
    expect(find.text('Paste copied output'), findsOneWidget);
    expect(
      find.text(
        'Paste supported t-test output when copied. Then confirm detected values.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('first-run start guide does not cover heading or controls', (
    tester,
  ) async {
    for (final surfaceSize in const [Size(1440, 1000), Size(390, 900)]) {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester, surfaceSize);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const MainApp());
      await _pumpGuideMeasurement(tester);

      expect(find.byKey(const Key('guide-bubble')), findsOneWidget);
      expect(find.text('Paste copied output'), findsOneWidget);

      final bubble = tester.getRect(find.byKey(const Key('guide-bubble')));
      final viewport = Offset.zero & surfaceSize;
      final guardedTargets = [
        (find.byKey(const Key('start-headline')), 'start headline'),
        (find.byKey(const Key('guide-replay')), 'guide replay'),
        (find.widgetWithText(FilledButton, 'BRIGHT VIEW'), 'theme switch'),
        (find.byKey(const Key('open-settings')), 'settings'),
        if (surfaceSize.width >= 720)
          (find.byKey(const Key('analysis-area-title')), 'analysis heading'),
      ];

      for (final (finder, label) in guardedTargets) {
        final rect = tester.getRect(finder);
        expect(
          viewport.contains(rect.topLeft) &&
              viewport.contains(rect.bottomRight),
          isTrue,
          reason: '$label is outside the $surfaceSize viewport: $rect',
        );
        expect(
          bubble.overlaps(rect),
          isFalse,
          reason:
              'Guide bubble overlaps $label at $surfaceSize: $bubble / $rect',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpGuideMeasurement(tester);
    }
  });

  testWidgets('guide geometry avoids protected content on every step', (
    tester,
  ) async {
    final guideTargetsByScreen = resQuillGuideStepTargetsForTesting();
    const screenIds = ['start', 'compare', 'input', 'validation', 'report'];
    const surfaceSizes = [Size(1440, 1000), Size(390, 900)];

    expect(guideTargetsByScreen.keys, unorderedEquals(screenIds));
    expect(
      guideTargetsByScreen.values.fold<int>(
        0,
        (total, steps) => total + steps.length,
      ),
      19,
    );

    final covered = <String>{};
    for (final surfaceSize in surfaceSizes) {
      for (final screenId in screenIds) {
        await _pumpGuideGeometryScreen(
          tester,
          surfaceSize,
          screenId,
          failingPaste: failingApaPaste,
          reportPaste: reportApaPaste,
        );
        await _openGuide(tester);

        final stepTargets = guideTargetsByScreen[screenId]!;
        for (var index = 0; index < stepTargets.length; index += 1) {
          await _pumpGuideMeasurement(tester);
          _expectGuideGeometryClean(
            tester,
            surfaceSize,
            stepTargets[index],
            '$screenId step ${index + 1} target ${stepTargets[index]}',
          );
          covered.add('$surfaceSize:$screenId:$index');

          if (index != stepTargets.length - 1) {
            await tester.tap(find.byKey(const Key('guide-next')));
            await _pumpGuideMeasurement(tester);
          }
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }

    expect(covered.length, 19 * surfaceSizes.length);
  });

  testWidgets('guide traps keyboard focus and Escape closes it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('guide-bubble')), findsOneWidget);
    expect(_focusedInsideGuide(), isTrue);

    for (var i = 0; i < 5; i += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusedInsideGuide(), isTrue);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guide-bubble')), findsNothing);
  });

  testWidgets('guide button blink fires once per screen visit', (tester) async {
    SharedPreferences.setMockInitialValues({
      _seenGuideScreensPreferenceKeyForTest: ['start'],
    });
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Type values'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(_guideButtonIsPulsing(tester, 'student_test_path'), isTrue);

    await tester.pump(const Duration(milliseconds: 1750));
    expect(_guideButtonIsPulsing(tester, 'student_test_path'), isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Back to start'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Type values'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(_guideButtonIsPulsing(tester, 'student_test_path'), isFalse);
  });

  testWidgets('guide seen state survives a restart', (tester) async {
    SharedPreferences.setMockInitialValues({
      _seenGuideScreensPreferenceKeyForTest: ['start'],
    });
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Type values'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(_guideButtonIsPulsing(tester, 'student_test_path'), isTrue);

    await tester.pump(const Duration(milliseconds: 1750));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.widgetWithText(FilledButton, 'Type values'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(_guideButtonIsPulsing(tester, 'student_test_path'), isFalse);
  });
}

void _mockAllGuideScreensSeen() {
  SharedPreferences.setMockInitialValues({
    _themePreferenceKeyForTest: 'dark',
    _seenGuideScreensPreferenceKeyForTest: _allSeenGuideScreensForTest,
  });
}

Future<void> _setDesktop(WidgetTester tester) async {
  await _setSurface(tester, const Size(1280, 900));
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpGuideMeasurement(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> _pumpGuideGeometryScreen(
  WidgetTester tester,
  Size surfaceSize,
  String screenId, {
  required String failingPaste,
  required String reportPaste,
}) async {
  SharedPreferences.setMockInitialValues({
    _themePreferenceKeyForTest: 'dark',
    _seenGuideScreensPreferenceKeyForTest: _allSeenGuideScreensForTest,
  });
  await _setSurface(tester, surfaceSize);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.pumpWidget(const MainApp());
  await _pumpGuideMeasurement(tester);

  switch (screenId) {
    case 'start':
      return;
    case 'compare':
      final typeValues = find.widgetWithText(FilledButton, 'Type values').first;
      await tester.ensureVisible(typeValues);
      await tester.tap(typeValues);
      await tester.pumpAndSettle();
      return;
    case 'input':
      final pasteOutput = find
          .widgetWithText(FilledButton, 'Paste output')
          .first;
      await tester.ensureVisible(pasteOutput);
      await tester.tap(pasteOutput);
      await tester.pumpAndSettle();
      await _loadDefaultExample(tester);
      await _jumpToTop(tester);
      return;
    case 'validation':
      await _pasteAndReview(tester, failingPaste);
      await tester.ensureVisible(
        find.byKey(const Key('confirm-detected-values')),
      );
      await tester.tap(find.byKey(const Key('confirm-detected-values')));
      await tester.pumpAndSettle();
      return;
    case 'report':
      await _pasteAndReview(tester, reportPaste);
      await tester.ensureVisible(
        find.byKey(const Key('confirm-detected-values')),
      );
      await tester.tap(find.byKey(const Key('confirm-detected-values')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('generate-report')));
      await tester.tap(find.byKey(const Key('generate-report')));
      await tester.pumpAndSettle();
      return;
    default:
      fail('Unknown guide screen id $screenId');
  }
}

Future<void> _openGuide(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('guide-replay')));
  await _pumpGuideMeasurement(tester);
}

Future<void> _loadDefaultExample(WidgetTester tester) async {
  final loadButton = find.descendant(
    of: find.byKey(const Key('paste-example-spss-independent')),
    matching: find.byType(FilledButton),
  );
  await tester.ensureVisible(loadButton);
  final button = tester.widget<FilledButton>(loadButton);
  expect(button.onPressed, isNotNull);
  await tester.runAsync(() async {
    button.onPressed!();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

Future<void> _jumpToTop(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  scrollable.position.jumpTo(scrollable.position.minScrollExtent);
  await _pumpGuideMeasurement(tester);
}

void _expectGuideGeometryClean(
  WidgetTester tester,
  Size surfaceSize,
  String targetId,
  String label,
) {
  final bubble = tester.getRect(find.byKey(const Key('guide-bubble')));
  final highlight = tester.getRect(find.byKey(const Key('guide-highlight')));
  final targetFinder = find.byKey(ValueKey('guide-target-$targetId'));

  expect(targetFinder, findsOneWidget, reason: '$label target is missing');
  final target = tester.getRect(targetFinder);
  final visibleTarget = _visibleTargetRect(target, surfaceSize, targetId);

  expect(visibleTarget, isNotNull, reason: '$label target is not visible');
  final checkedTarget = visibleTarget!;
  expect(
    _rectsOverlap(highlight, checkedTarget),
    isTrue,
    reason: '$label highlight misses target: $highlight / $checkedTarget',
  );

  expect(
    _rectsOverlap(bubble, highlight),
    isFalse,
    reason: '$label bubble overlaps highlighted target: $bubble / $highlight',
  );

  final protectedElements = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('guide-protected-');
  }).evaluate();
  var checked = 0;
  for (final element in protectedElements) {
    final key = (element.widget.key! as ValueKey<String>).value;
    final renderObject = element.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      continue;
    }
    final rawRect = MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      Offset.zero & renderObject.size,
    );
    final visibleRect = _visibleProtectedRect(rawRect, surfaceSize, key);
    if (visibleRect == null) {
      continue;
    }
    checked += 1;
    expect(
      _rectsOverlap(bubble, visibleRect),
      isFalse,
      reason: '$label bubble overlaps $key: $bubble / $visibleRect',
    );
  }

  expect(
    _rectsOverlap(bubble, checkedTarget),
    isFalse,
    reason: '$label bubble overlaps target: $bubble / $checkedTarget',
  );
  expect(checked, greaterThan(0), reason: '$label checked no protected zones');
}

Rect? _visibleTargetRect(Rect rect, Size surfaceSize, String targetId) {
  final viewport = Offset.zero & surfaceSize;
  final contentClip = Rect.fromLTRB(
    0,
    resQuillTopControlsReservedExtentForTesting,
    surfaceSize.width,
    surfaceSize.height - resQuillGuideDockExtentForTesting(surfaceSize),
  );
  final clip = _isTopControlTarget(targetId) ? viewport : contentClip;
  return _rectIntersection(rect, clip);
}

Rect? _visibleProtectedRect(Rect rect, Size surfaceSize, String key) {
  final viewport = Offset.zero & surfaceSize;
  final contentClip = Rect.fromLTRB(
    0,
    resQuillTopControlsReservedExtentForTesting,
    surfaceSize.width,
    surfaceSize.height - resQuillGuideDockExtentForTesting(surfaceSize),
  );
  final clip = _isTopControlProtected(key) ? viewport : contentClip;
  return _rectIntersection(rect, clip);
}

bool _isTopControlProtected(String key) {
  return key.endsWith('-guide-replay') ||
      key.endsWith('-open-settings') ||
      key.contains('BRIGHT_VIEW') ||
      key.contains('DARK_VIEW');
}

bool _isTopControlTarget(String targetId) {
  return targetId == 'guide_replay' || targetId == 'theme_toggle';
}

bool _rectsOverlap(Rect a, Rect b) => _rectIntersection(a, b) != null;

Rect? _rectIntersection(Rect a, Rect b) {
  const tolerance = 0.5;
  final left = a.left > b.left ? a.left : b.left;
  final top = a.top > b.top ? a.top : b.top;
  final right = a.right < b.right ? a.right : b.right;
  final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;
  if (right - left <= tolerance || bottom - top <= tolerance) {
    return null;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

const _validationSummaryCardKeys = [
  Key('validation-summary-t'),
  Key('validation-summary-df'),
  Key('validation-summary-p'),
  Key('validation-summary-fails'),
];

void _expectNoAffirmativeMatchesUnderWarningOrError(
  WidgetTester tester,
  Key key,
) {
  final card = find.byKey(key);
  expect(card, findsOneWidget);
  final hasWarningOrError =
      find
          .descendant(of: card, matching: find.text('Warning'))
          .evaluate()
          .isNotEmpty ||
      find
          .descendant(of: card, matching: find.text('Error'))
          .evaluate()
          .isNotEmpty;
  if (!hasWarningOrError) {
    return;
  }

  final cardText = tester
      .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .join('\n');
  expect(
    RegExp(r'\bmatches\b', caseSensitive: false).hasMatch(cardText),
    isFalse,
    reason: cardText,
  );
}

Future<void> _pasteAndReview(WidgetTester tester, String paste) async {
  final pasteOutput = find.widgetWithText(FilledButton, 'Paste output').first;
  await tester.ensureVisible(pasteOutput);
  await tester.tap(pasteOutput);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('paste-output-box')), paste);
  await tester.ensureVisible(find.byKey(const Key('review-detected-fields')));
  await tester.tap(find.byKey(const Key('review-detected-fields')));
  await tester.pumpAndSettle();
}

bool _guideButtonIsPulsing(WidgetTester tester, String targetId) {
  final dynamic widget = tester.widget(
    find.byKey(Key('guide-button-$targetId')),
  );
  return widget.isPulsing as bool;
}

bool _focusedInsideGuide() {
  final primaryFocus = FocusManager.instance.primaryFocus;
  return primaryFocus?.debugLabel == 'Guide overlay focus scope' ||
      primaryFocus?.nearestScope?.debugLabel == 'Guide overlay focus scope';
}
