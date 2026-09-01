import 'dart:io';

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKeyForCapture = 'resquill.theme';
const _seenGuideScreensPreferenceKeyForCapture = 'resquill.guide.seenScreens';
const _allSeenGuideScreensForCapture = [
  'compare',
  'input',
  'report',
  'start',
  'validation',
];

const _failingApaPaste =
    'Retrieval practice (n = 20, M = 81.40, SD = 5.5378) and '
    'Restudy (n = 31, M = 72.40, SD = 9.2616) were compared using a '
    'two-tailed Welch independent-samples t test, t(48.80) = 1.00, '
    'p = .999, mean difference = 9.00, SE = 2.0737, '
    '95% CI [4.83, 13.17].';

final _captureKey = GlobalKey();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadCaptureFonts);

  testWidgets('capture T46 validation value cards', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final configs = [
      _CaptureConfig(
        't46_bright_desktop_1440x1000_validation',
        const Size(1440, 1000),
        light: true,
      ),
      _CaptureConfig(
        't46_dark_desktop_1440x1000_validation',
        const Size(1440, 1000),
        light: false,
      ),
      _CaptureConfig(
        't46_bright_mobile_390x900_validation',
        const Size(390, 900),
        light: true,
      ),
      _CaptureConfig(
        't46_dark_mobile_390x900_validation',
        const Size(390, 900),
        light: false,
      ),
    ];

    for (final config in configs) {
      await _pumpApp(tester, config);
      await _pasteAndReview(tester, _failingApaPaste);
      await _pressButtonKey(tester, const Key('confirm-detected-values'));
      await tester.ensureVisible(find.byKey(const Key('validation-summary-t')));
      await _settle(tester);
      await _save(tester, config.name);
    }
  });
}

Future<void> _loadCaptureFonts() async {
  final uiFontPaths = _uiCaptureFontPaths();
  if (uiFontPaths.isEmpty) {
    throw StateError(
      'No local font found for readable captures. Install Segoe UI, Arial, '
      'or DejaVu Sans, then rerun this test.',
    );
  }

  await _loadFontFamily('Ahem', uiFontPaths);
  await _loadFontFamily('Segoe UI', uiFontPaths);
  await _loadFontFamily('Roboto', uiFontPaths);
  await _loadFontFamily('Consolas', _monoCaptureFontPaths(uiFontPaths));
}

Future<void> _loadFontFamily(String family, List<String> fontPaths) async {
  final loader = FontLoader(family);
  for (final path in fontPaths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

List<String> _uiCaptureFontPaths() {
  final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
  final candidates = [
    '$windir\\Fonts\\segoeui.ttf',
    '$windir\\Fonts\\seguisb.ttf',
    '$windir\\Fonts\\segoeuib.ttf',
    '$windir\\Fonts\\arial.ttf',
    '$windir\\Fonts\\arialbd.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    '/Library/Fonts/Arial.ttf',
    '/Library/Fonts/Arial Bold.ttf',
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
  ];
  return candidates.where((path) => File(path).existsSync()).toList();
}

List<String> _monoCaptureFontPaths(List<String> fallback) {
  final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
  final candidates = [
    '$windir\\Fonts\\consola.ttf',
    '$windir\\Fonts\\consolab.ttf',
    '$windir\\Fonts\\cour.ttf',
    '$windir\\Fonts\\courbd.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',
    '/System/Library/Fonts/Menlo.ttc',
  ];
  final paths = candidates.where((path) => File(path).existsSync()).toList();
  return paths.isEmpty ? fallback : paths;
}

Future<void> _pumpApp(WidgetTester tester, _CaptureConfig config) async {
  SharedPreferences.setMockInitialValues({
    _themePreferenceKeyForCapture: config.light ? 'light' : 'dark',
    _seenGuideScreensPreferenceKeyForCapture: _allSeenGuideScreensForCapture,
  });
  tester.view.physicalSize = config.size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester);
  await tester.pumpWidget(
    RepaintBoundary(key: _captureKey, child: const MainApp()),
  );
  await _settle(tester);
}

Future<void> _pasteAndReview(WidgetTester tester, String paste) async {
  await _tapButtonText(tester, 'Paste output');
  await tester.enterText(find.byKey(const Key('paste-output-box')), paste);
  await _pressButtonKey(tester, const Key('review-detected-fields'));
}

Future<void> _tapButtonText(WidgetTester tester, String text) async {
  final button = find.widgetWithText(FilledButton, text).first;
  await tester.ensureVisible(button);
  await tester.tap(button);
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
