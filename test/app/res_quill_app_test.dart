import 'dart:io';

import 'package:flutter/material.dart';
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
            'Relationships & prediction. Correlations and regression models. Coming later.',
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
      find.text(
        'Select the t-test path when you are entering values manually.',
      ),
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

    expect(find.text('Validation review'), findsOneWidget);
    expect(find.text('Fail'), findsWidgets);
    final generateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate report'),
    );
    expect(generateButton.onPressed, isNull);

    expect(find.text('Report draft'), findsNothing);
  });

  testWidgets('paste ambiguity cannot proceed until resolved', (tester) async {
    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await _pasteAndReview(tester, ambiguousApaPaste);

    expect(find.text('Resolve the p-value tail'), findsOneWidget);
    var confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm detected values'),
    );
    expect(confirmButton.onPressed, isNull);

    expect(find.text('Validation review'), findsNothing);

    await tester.tap(find.byKey(const Key('paste-tail-two-tailed')));
    await tester.pumpAndSettle();
    confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm detected values'),
    );
    expect(confirmButton.onPressed, isNotNull);

    await tester.ensureVisible(
      find.byKey(const Key('confirm-detected-values')),
    );
    await tester.tap(find.byKey(const Key('confirm-detected-values')));
    await tester.pumpAndSettle();
    expect(find.text('Validation review'), findsOneWidget);
  });

  testWidgets('real sample paste displays harness-matching detected values', (
    tester,
  ) async {
    final sampleFile = File(
      r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\PASTE_TEXT\spss_independent_samples.txt',
    );
    expect(sampleFile.existsSync(), isTrue);

    await _setDesktop(tester);
    await tester.pumpWidget(const MainApp());
    await _pasteAndReview(tester, sampleFile.readAsStringSync());

    expect(
      find.text(
        'SPSS reported both equal-variance rows; Student versus Welch must be chosen by the user.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('primary.mean = 82.7975'), findsOneWidget);
    expect(find.textContaining('secondary.mean = 72.026'), findsOneWidget);
    expect(find.textContaining('levene.p = 0.525'), findsOneWidget);
    expect(find.textContaining('reported.df = 38'), findsOneWidget);
    expect(find.textContaining('reported.df = 37.114'), findsOneWidget);
    expect(find.textContaining('reported.p = 0.031'), findsWidgets);
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
