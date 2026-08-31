import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';

const _failingApaPaste =
    'Retrieval practice (n = 20, M = 81.40, SD = 5.5378) and '
    'Restudy (n = 31, M = 72.40, SD = 9.2616) were compared using a '
    'two-tailed Welch independent-samples t test, t(48.80) = 1.00, '
    'p = .999, mean difference = 9.00, SE = 2.0737, '
    '95% CI [4.83, 13.17].';

const _reportApaPaste =
    'Retrieval practice (n = 20, M = 81.40, SD = 5.5378) and '
    'Restudy (n = 31, M = 72.40, SD = 9.2616) were compared using a '
    'two-tailed Welch independent-samples t test, t(48.80) = 4.34, '
    'p < .001, mean difference = 9.00, SE = 2.0737, '
    '95% CI [4.83, 13.17].';

final _captureKey = GlobalKey();

void main() {
  testWidgets('capture current app screens', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final configs = [
      _CaptureConfig('desktop_dark', const Size(1280, 900), light: false),
      _CaptureConfig('desktop_light', const Size(1280, 900), light: true),
      _CaptureConfig('phone390_dark', const Size(390, 900), light: false),
      _CaptureConfig('phone390_light', const Size(390, 900), light: true),
    ];

    for (final config in configs) {
      await _pumpApp(tester, config);
      await _save(tester, '${config.name}_01_start');

      await _pumpApp(tester, config);
      await tester.tap(find.widgetWithText(FilledButton, 'Type values'));
      await _settle(tester);
      await _save(tester, '${config.name}_02_selection');

      await _pumpApp(tester, config);
      await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
      await _settle(tester);
      await _loadDefaultExample(tester);
      await _jumpToTop(tester);
      await _save(tester, '${config.name}_03_input_spss_independent');

      await _pumpApp(tester, config);
      await _pasteAndReview(tester, _failingApaPaste);
      await _pressButtonKey(tester, const Key('confirm-detected-values'));
      await tester.ensureVisible(find.text('Fail').first);
      await _save(tester, '${config.name}_04_validation_failing');

      await _pumpApp(tester, config);
      await _pasteAndReview(tester, _reportApaPaste);
      await _pressButtonKey(tester, const Key('confirm-detected-values'));
      await _pressButtonKey(tester, const Key('generate-report'));
      await _save(tester, '${config.name}_05_report');
    }
  });
}

Future<void> _pumpApp(WidgetTester tester, _CaptureConfig config) async {
  tester.view.physicalSize = config.size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester);
  await tester.pumpWidget(
    RepaintBoundary(key: _captureKey, child: const MainApp()),
  );
  await _settle(tester);
  if (config.light) {
    await tester.tap(find.widgetWithText(FilledButton, 'BRIGHT VIEW'));
    await _settle(tester);
  }
}

Future<void> _loadDefaultExample(WidgetTester tester) async {
  final loadButton = find.descendant(
    of: find.byKey(const Key('paste-load-example')),
    matching: find.byType(FilledButton),
  );
  await tester.ensureVisible(loadButton);
  final button = tester.widget<FilledButton>(loadButton);
  await tester.runAsync(() async {
    button.onPressed!();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await _settle(tester);
}

Future<void> _pasteAndReview(WidgetTester tester, String paste) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
  await _settle(tester);
  await tester.enterText(find.byKey(const Key('paste-output-box')), paste);
  await _pressButtonKey(tester, const Key('review-detected-fields'));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _jumpToTop(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  scrollable.position.jumpTo(scrollable.position.minScrollExtent);
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

Future<void> _save(WidgetTester tester, String name) async {
  final exception = tester.takeException();
  if (exception != null) {
    fail('Flutter exception before $name: $exception');
  }
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile('../../captures/$name.png'),
  );
}

class _CaptureConfig {
  const _CaptureConfig(this.name, this.size, {required this.light});

  final String name;
  final Size size;
  final bool light;
}
