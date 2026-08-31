import 'dart:convert';
import 'dart:io';

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:res_quill/src/app/res_quill_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKeyForQa = 'resquill.theme';
const _seenGuideScreensPreferenceKeyForQa = 'resquill.guide.seenScreens';
const _allSeenGuideScreensForQa = [
  'compare',
  'input',
  'report',
  'start',
  'validation',
];

const _sampleDir =
    r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\PASTE_TEXT';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA sweep records tab order for major screens', (tester) async {
    final audit = <String, Object?>{};

    await _pumpApp(tester);
    audit['start'] = await _tabOrder(tester);

    await _pumpApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Type values'));
    await _settle(tester);
    audit['selection'] = await _tabOrder(tester);

    await _pumpApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Paste output'));
    await _settle(tester);
    final sample = File(
      '$_sampleDir${Platform.pathSeparator}spss_independent_samples.txt',
    ).readAsStringSync();
    await tester.enterText(find.byKey(const Key('paste-output-box')), sample);
    await tester.ensureVisible(find.byKey(const Key('review-detected-fields')));
    await tester.tap(find.byKey(const Key('review-detected-fields')));
    await _settle(tester);
    audit['input'] = await _tabOrder(tester, maxTabs: 34);

    await _pumpApp(tester);
    await _pasteAndReview(tester, _failingApaPaste);
    await tester.ensureVisible(
      find.byKey(const Key('confirm-detected-values')),
    );
    await tester.tap(find.byKey(const Key('confirm-detected-values')));
    await _settle(tester);
    audit['validation'] = await _tabOrder(tester, maxTabs: 18);

    await _pumpApp(tester);
    await _pasteAndReview(tester, _reportApaPaste);
    await tester.ensureVisible(
      find.byKey(const Key('confirm-detected-values')),
    );
    await tester.tap(find.byKey(const Key('confirm-detected-values')));
    await _settle(tester);
    await tester.ensureVisible(find.byKey(const Key('generate-report')));
    await tester.tap(find.byKey(const Key('generate-report')));
    await _settle(tester);
    audit['report'] = await _tabOrder(tester, maxTabs: 24);

    await _pumpApp(tester);
    await tester.tap(find.byKey(const Key('guide-replay')));
    await _settle(tester);
    final guideOrder = await _tabOrder(tester, maxTabs: 8);
    audit['guideOpen'] = {
      'order': guideOrder,
      'focusStayedInGuide': guideOrder.every(
        (item) => item.contains('Guide overlay focus scope'),
      ),
    };
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byKey(const Key('guide-bubble')), findsNothing);
    audit['escapeClosesGuide'] = true;

    final outDir = Directory('build/qa_sweep');
    outDir.createSync(recursive: true);
    File(
      '${outDir.path}/keyboard.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(audit));
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

Future<List<String>> _tabOrder(WidgetTester tester, {int maxTabs = 20}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final order = <String>[];
  for (var i = 0; i < maxTabs; i += 1) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final label = _describeFocusedElement();
    if (label == 'none') {
      continue;
    }
    if (order.contains(label)) {
      break;
    }
    order.add(label);
  }
  return order;
}

String _describeFocusedElement() {
  final node = FocusManager.instance.primaryFocus;
  final context = node?.context;
  if (node == null || context == null) {
    return 'none';
  }
  final labels = <String>[
    if (node.debugLabel != null) 'focus:${node.debugLabel}',
    if (node.nearestScope?.debugLabel != null)
      'scope:${node.nearestScope!.debugLabel}',
  ];
  final element = context as Element;
  _collectElementLabels(element, labels);
  element.visitAncestorElements((ancestor) {
    _collectWidgetLabel(ancestor.widget, labels);
    return true;
  });
  return labels.toSet().take(5).join(' | ');
}

void _collectElementLabels(Element element, List<String> labels) {
  _collectWidgetLabel(element.widget, labels);
  element.visitChildElements((child) {
    if (labels.length < 8) {
      _collectElementLabels(child, labels);
    }
  });
}

void _collectWidgetLabel(Widget widget, List<String> labels) {
  final key = widget.key;
  if (key != null) {
    labels.add('key:$key');
  }
  if (widget is Text) {
    final text = widget.data ?? widget.textSpan?.toPlainText();
    if (text != null && text.trim().isNotEmpty) {
      labels.add('text:${text.trim()}');
    }
  }
  if (widget is TextField) {
    final label = widget.decoration?.labelText;
    if (label != null) {
      labels.add('field:$label');
    }
  }
  if (widget is Semantics) {
    final properties = widget.properties;
    if (properties.label != null && properties.label!.trim().isNotEmpty) {
      labels.add('semantics:${properties.label!.trim()}');
    }
    if (properties.hint != null && properties.hint!.trim().isNotEmpty) {
      labels.add('hint:${properties.hint!.trim()}');
    }
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}
