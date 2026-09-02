import 'dart:io';

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fixes 3 and 4 from SHIR_FEEDBACK_2026-09-01_FIRST_LIVE_USE_EN.md. Fix 3 is
// the input heading naming the screen instead of one of its two panels; fix 4
// is a refusal that shows a shape that works instead of only what is wrong.

const _themePreferenceKeyForCapture = 'resquill.theme';
const _seenGuideScreensPreferenceKeyForCapture = 'resquill.guide.seenScreens';
const _allSeenGuideScreensForCapture = [
  'compare',
  'input',
  'report',
  'start',
  'validation',
];

final _captureKey = GlobalKey();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadCaptureFonts);

  testWidgets('capture the refusal with a supported shape', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final configs = [
      _CaptureConfig(
        'refusal_dark_desktop_1440x1200_input',
        const Size(1440, 1200),
        light: false,
      ),
      _CaptureConfig(
        'refusal_bright_mobile_390x900_input',
        const Size(390, 900),
        light: true,
      ),
    ];

    for (final config in configs) {
      await _pumpApp(tester, config);
      await _tapButtonText(tester, 'Paste output');
      // Exactly what Shir typed on the live site.
      await tester.enterText(
        find.byKey(const Key('paste-output-box')),
        '1 2 3 4 5 6 7 8',
      );
      await _tapButtonText(tester, 'Review output');
      expect(find.text('Cannot use this paste'), findsOneWidget);
      expect(find.text('What a supported paste looks like'), findsOneWidget);
      // Scroll to the refusal itself, not past it - the reasons above the
      // shapes are half of what has to be read.
      await tester.ensureVisible(find.text('Cannot use this paste'));
      await _settle(tester);
      await _save(tester, config.name);
    }
  });

  testWidgets('capture the input heading in manual mode', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final configs = [
      _CaptureConfig(
        'heading_dark_desktop_1440x1000_manual',
        const Size(1440, 1000),
        light: false,
      ),
      _CaptureConfig(
        'heading_bright_mobile_390x900_manual',
        const Size(390, 900),
        light: true,
      ),
    ];

    for (final config in configs) {
      await _pumpApp(tester, config);
      await _tapButtonText(tester, 'Type values');
      await _tapText(tester, 'Student t-test');
      expect(find.text('Enter your t-test result.'), findsOneWidget);
      await _save(tester, config.name);
    }
  });
}

Future<void> _loadCaptureFonts() async {
  final uiFontPaths = _uiCaptureFontPaths();
  if (uiFontPaths.isEmpty) {
    throw StateError('No local font found for readable captures.');
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
  ];
  return candidates.where((path) => File(path).existsSync()).toList();
}

List<String> _monoCaptureFontPaths(List<String> fallback) {
  final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
  final candidates = [
    '$windir\\Fonts\\consola.ttf',
    '$windir\\Fonts\\consolab.ttf',
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

Future<void> _tapButtonText(WidgetTester tester, String text) async {
  final button = find.widgetWithText(FilledButton, text).first;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _settle(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
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
