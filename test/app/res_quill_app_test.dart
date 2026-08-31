import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';

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
    expect(find.text('Fail'), findsWidgets);
    final generateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate report'),
    );
    expect(generateButton.onPressed, isNull);

    expect(find.text('Copy your report.'), findsNothing);
  });

  testWidgets('paste ambiguity cannot proceed until resolved', (tester) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await _pasteAndReview(tester, ambiguousApaPaste);

    expect(find.text('Choose p-value direction'), findsOneWidget);
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
