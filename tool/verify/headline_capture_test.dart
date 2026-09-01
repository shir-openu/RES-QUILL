import 'dart:io';

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Captures the start screen on first run so the brief's headline can be read
// at both widths and in both themes.

const _themePreferenceKeyForCapture = 'resquill.theme';

final _captureKey = GlobalKey();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadCaptureFonts);

  testWidgets('capture start headline', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final configs = [
      _CaptureConfig(
        'headline_bright_desktop_1440x1000_start',
        const Size(1440, 1000),
        light: true,
      ),
      _CaptureConfig(
        'headline_dark_desktop_1440x1000_start',
        const Size(1440, 1000),
        light: false,
      ),
      _CaptureConfig(
        'headline_bright_mobile_390x900_start',
        const Size(390, 900),
        light: true,
      ),
      _CaptureConfig(
        'headline_dark_mobile_390x900_start',
        const Size(390, 900),
        light: false,
      ),
    ];

    for (final config in configs) {
      await _pumpApp(tester, config);
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
    '/System/Library/Fonts/Supplemental/Arial.ttf',
  ];
  return candidates.where((path) => File(path).existsSync()).toList();
}

List<String> _monoCaptureFontPaths(List<String> fallback) {
  final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
  final candidates = [
    '$windir\\Fonts\\consola.ttf',
    '$windir\\Fonts\\consolab.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
  ];
  final paths = candidates.where((path) => File(path).existsSync()).toList();
  return paths.isEmpty ? fallback : paths;
}

Future<void> _pumpApp(WidgetTester tester, _CaptureConfig config) async {
  SharedPreferences.setMockInitialValues({
    _themePreferenceKeyForCapture: config.light ? 'light' : 'dark',
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
