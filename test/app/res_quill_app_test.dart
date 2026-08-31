import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
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

void main() {
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

  setUp(_mockAllGuideScreensSeen);

  testWidgets('disabled analysis cards are not tappable', (tester) async {
    final semantics = tester.ensureSemantics();
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

    expect(find.text('Paste t-test output. Get APA wording.'), findsOneWidget);
    expect(
      find.text('Use this only when typing values by hand.'),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('a validation fail blocks the report screen', (tester) async {
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

    expect(find.text('Copy your report.'), findsNothing);
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

  testWidgets('a value with a failing check does not render a pass badge', (
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
        matching: find.text('Problem row: Reported p matches t and df.'),
      ),
      findsOneWidget,
    );
  });

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
    expect(
      find.text(
        "Student row. Levene's Sig. = 0.525; with .05 rule, SPSS points to this row.",
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        "Welch row. Levene's Sig. = 0.525; with .05 rule, use this only if assigned.",
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
    expect(find.textContaining('levene.p = 0.525'), findsOneWidget);
    expect(find.textContaining('reported.df = 38'), findsOneWidget);
    expect(find.textContaining('reported.df = 37.114'), findsOneWidget);
    expect(find.textContaining('reported.p = 0.031'), findsWidgets);
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
        'reported.df = 48.8',
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
        'CSV and Excel files contain raw rows. Res-Quill checks t-test output after SPSS, JASP, jamovi, or APA has already computed it. Paste that output instead.',
      ),
      findsOneWidget,
    );
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
        'CSV and Excel files contain raw rows. Res-Quill checks t-test output after SPSS, JASP, jamovi, or APA has already computed it. Paste that output instead.',
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
      find.text('Paste SPSS, JASP, jamovi, or APA output.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Back to start'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Type values'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equal variances assumed').first);
    await tester.pumpAndSettle();

    expect(find.text('Type values from one output row.'), findsOneWidget);
    expect(find.text('Alpha (course, usually .05)'), findsOneWidget);
    expect(find.text('p direction'), findsOneWidget);
    expect(find.text('CI level (usually .95)'), findsOneWidget);
  });

  testWidgets('the start guide does not auto-advance', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('guide-bubble')), findsOneWidget);
    expect(find.text('1 of 10'), findsOneWidget);
    expect(
      find.text('Change colors here. Your values stay the same.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('1 of 10'), findsOneWidget);
    expect(
      find.text('Change colors here. Your values stay the same.'),
      findsOneWidget,
    );
  });

  testWidgets('Escape closes the guide', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('guide-bubble')), findsOneWidget);

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
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pasteAndReview(WidgetTester tester, String paste) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
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
