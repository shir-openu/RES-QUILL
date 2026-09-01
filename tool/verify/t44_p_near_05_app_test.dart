// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKeyForT44 = 'resquill.theme';
const _seenGuideScreensPreferenceKeyForT44 = 'resquill.guide.seenScreens';
const _allSeenGuideScreensForT44 = [
  'compare',
  'input',
  'report',
  'start',
  'validation',
];

void main() {
  testWidgets('T44 p-near-.05 R cases reach generated app reports', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;

    final cases = [
      _Case(
        name: 'R Welch',
        paste: _rWelchPaste,
        expectedParagraphs: const [
          'A two-tailed Welch independent-samples t test did not provide '
              'evidence of a difference in scores between Practice and '
              'Control, t(48.16) = 2.01, p = .051, 95% CI [-0.02, 14.46].',
          'Practice had a mean of 57.22 (SD = 12.91, n = 24), and Control had '
              'a mean of 50.00 (SD = 12.75, n = 27).',
          'The sample data did not provide evidence of a difference at the '
              'selected threshold. The observed sample pattern was that the '
              'mean for Practice was higher than the mean for Control.',
          "The effect size was Cohen's d = 0.56 using unweighted root mean of "
              "group variances (Welch d_s convention); Hedges' g = 0.55 after "
              'small-sample correction; Cohen (1988) would classify this as a '
              'medium effect.',
          'The 95% confidence interval includes zero.',
        ],
      ),
      _Case(
        name: 'R Student',
        paste: _rStudentPaste,
        expectedParagraphs: const [
          'A two-tailed independent-samples Student t test did not provide '
              'evidence of a difference in scores between Practice and '
              'Control, t(49) = 1.98, p = .054, 95% CI [-0.10, 11.18].',
          'Practice had a mean of 55.54 (SD = 10.00, n = 24), and Control had '
              'a mean of 50.00 (SD = 10.00, n = 27).',
          'The sample data did not provide evidence of a difference at the '
              'selected threshold. The observed sample pattern was that the '
              'mean for Practice was higher than the mean for Control.',
          "The effect size was Cohen's d = 0.55 using pooled sample SD "
              "(Student equal-variance convention); Hedges' g = 0.55 after "
              'small-sample correction; Cohen (1988) would classify this as a '
              'medium effect.',
          'The 95% confidence interval includes zero.',
        ],
      ),
      _Case(
        name: 'R paired',
        paste: _rPairedPaste,
        expectedParagraphs: const [
          'A two-tailed paired-samples t test showed a statistically '
              'significant difference in scores between Before and After, '
              't(17) = 4.09, p < .001, 95% CI [2.80, 8.76].',
          'Before scores had M = 60.00 (SD = 10.00, n = 18), and After scores '
              'had M = 54.22 (SD = 10.00, n = 18); the mean paired difference '
              'was 5.78 (SD = 6.00, n = 18).',
          'The sample data provided statistical evidence that the mean for '
              'Before was higher than the mean for After. This comparison does '
              'not explain why the pattern occurred.',
          "The effect size was Cohen's d = 0.96 using sample SD of paired "
              "differences (Cohen dz convention); Hedges' g = 0.92 after "
              'small-sample correction; Cohen (1988) would classify this as a '
              'large effect.',
          'The 95% confidence interval excludes zero.',
        ],
      ),
      _Case(
        name: 'R one',
        paste: _rOnePaste,
        expectedParagraphs: const [
          'A two-tailed one-sample t test did not provide evidence of a '
              'difference in scores between Sample and the reference value, '
              't(32) = 0.39, p = .700, 95% CI [-2.87, 4.22].',
          'Sample had M = 50.68 (SD = 10.00, n = 33), compared with the '
              'reference value (50.00).',
          'The sample data did not provide evidence of a difference at the '
              'selected threshold. The observed sample pattern was that the '
              'sample mean for Sample was higher than the reference value.',
          "The effect size was Cohen's d = 0.07 using sample SD (one-sample "
              "standardized mean difference); Hedges' g = 0.07 after "
              'small-sample correction; Cohen (1988) would classify this as '
              'below the small benchmark.',
          'The 95% confidence interval includes zero.',
        ],
      ),
    ];

    for (final item in cases) {
      await _pumpApp(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Paste output').first);
      await _settle(tester);
      await tester.enterText(
        find.byKey(const Key('paste-output-box')),
        item.paste,
      );
      await _pressButtonKey(tester, const Key('review-detected-fields'));
      await _pressButtonKey(tester, const Key('confirm-detected-values'));
      await _pressButtonKey(tester, const Key('generate-report'));

      for (final paragraph in item.expectedParagraphs) {
        expect(
          find.text(paragraph, findRichText: true),
          findsOneWidget,
          reason: '${item.name}: $paragraph',
        );
      }
    }
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    _themePreferenceKeyForT44: 'dark',
    _seenGuideScreensPreferenceKeyForT44: _allSeenGuideScreensForT44,
  });
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester);
  await tester.pumpWidget(const MainApp());
  await _settle(tester);
}

Future<void> _pressButtonKey(WidgetTester tester, Key key) async {
  final buttonFinder = find.descendant(
    of: find.byKey(key),
    matching: find.byType(FilledButton),
  );
  await tester.ensureVisible(buttonFinder);
  final button = tester.widget<FilledButton>(buttonFinder);
  expect(button.onPressed, isNotNull);
  button.onPressed!();
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

class _Case {
  const _Case({
    required this.name,
    required this.paste,
    required this.expectedParagraphs,
  });

  final String name;
  final String paste;
  final List<String> expectedParagraphs;
}

const _rWelchPaste = '''
Welch Two Sample t-test

data: Practice and Control
t = 2.0052, df = 48.158, p-value = 0.050583
alternative hypothesis: true difference in means is not equal to 0
95 percent confidence interval:
 -0.019 14.460
sample estimates:
mean in group Practice mean in group Control
57.2205 50.0000

descriptives
group n mean sd
Practice 24 57.2205 12.907592557866561
Control 27 50.0000 12.753858230198336
''';

const _rStudentPaste = '''
Two Sample t-test

data: Practice and Control
t = 1.9754, df = 49, p-value = 0.053869
alternative hypothesis: true difference in means is not equal to 0
95 percent confidence interval:
 -0.0958758267 11.1795214130
sample estimates:
mean in group Practice mean in group Control
55.54182279312235 50.0000

descriptives
group n mean sd
Practice 24 55.54182279312235 10.0000
Control 27 50.0000 10.0000
''';

const _rPairedPaste = '''
Paired t-test

data: Before and After
t = 4.0871, df = 17, p-value = 0.000768
alternative hypothesis: true mean difference is not equal to 0
95 percent confidence interval:
 2.7963024465 8.7637620551
sample estimates:
mean difference
5.780032250775077

paired differences
pair mean sd se
1 5.780032250775077 6.0000 1.4142135624

descriptives
group n mean sd
Before 18 60.0000 10.0000
After 18 54.21996774922492 10.0000
''';

const _rOnePaste = '''
One Sample t-test

data: Sample
t = 0.3888, df = 32, p-value = 0.699989
alternative hypothesis: true mean is not equal to 50
95 percent confidence interval:
 -2.8690318913 4.2226597440
sample estimates:
mean of x
50.676813926355756

descriptives
group n mean sd
Sample 33 50.676813926355756 10.0000
''';
